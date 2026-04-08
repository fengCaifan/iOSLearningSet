# OC Block 底层实现

> 一句话总结：Block 是对**函数及其执行上下文**封装起来的 OC 对象，本质是带有 `isa` 指针的结构体，能截获外部变量，支持在堆栈间拷贝。

---

## 1. 核心概念

### 1.1 Block 的本质

Block 最终被编译之后得到的是一个**结构体**，结构体内部有一个 `__block_impl` 的成员结构体，它内部包含一个 `isa` 指针和一个 `FuncPtr` 函数指针。所以说：

- **Block 是一个对象**，Block 调用就是函数调用
- 可以通过打印 Block 的继承链来验证，最终会得到 `NSObject`

```objc
void (^block)(void) = ^{
    NSLog(@"xxxxxx");
};
NSLog(@"%@", [block class]);                                         // __NSGlobalBlock__
NSLog(@"%@", [[block class] superclass]);                            // __NSGlobalBlock
NSLog(@"%@", [[[block class] superclass] superclass]);               // NSBlock
NSLog(@"%@", [[[[block class] superclass] superclass] superclass]);  // NSObject
```

用 `clang -rewrite-objc main.m` 可以将 Block 转为 C++ 查看底层结构：

```objc
int age = 10;
void (^block)(void) = ^{
    NSLog(@"age = %d", age);
};
block();
```

编译后等价于：

```c
// Block 的执行函数
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    int age = __cself->age;
    NSLog(@"age = %d", age);
}

// Block 的结构体
struct __main_block_impl_0 {
    struct __block_impl impl;         // 公共部分（isa、Flags、FuncPtr）
    struct __main_block_desc_0 *Desc; // 描述信息（大小、copy/dispose 函数）
    int age;                          // 截获的外部变量
};
```

---

### 1.2 三种 Block 类型

Block 分为 `NSGlobalBlock`、`NSMallocBlock`、`NSStackBlock`，分别存在于**全局数据区、堆区、栈区**，在 ARC 和 MRC 中有所区别：

| 类型 | 所在内存区域 | 产生条件 |
|------|------------|---------|
| `__NSGlobalBlock__` | 数据段（全局区） | **没有访问 auto 变量**的 Block |
| `__NSStackBlock__` | 栈 | **访问了 auto 变量**，且未发生 copy |
| `__NSMallocBlock__` | 堆 | 对 `__NSStackBlock__` 执行 copy 后 |

```objc
int age = 10;
void (^block)(void) = ^{ NSLog(@"hello"); };           // __NSGlobalBlock__（无截获）
void (^block2)(void) = ^{ NSLog(@"%d", age); };        // __NSMallocBlock__（ARC 下自动 copy）
NSLog(@"%@", [^{ NSLog(@"%d", age); } class]);         // __NSStackBlock__（匿名，未被持有）
```

**三种 Block 对 copy 操作的反应不同**：
- 对 `__NSGlobalBlock__` 执行 copy：**无任何反应**
- 对 `__NSStackBlock__` 执行 copy：**拷贝到堆上**，变成 `__NSMallocBlock__`
- 对 `__NSMallocBlock__` 执行 copy：**引用计数 +1**（浅拷贝）

**ARC 下编译器会自动将栈 Block copy 到堆上**，触发时机：
- Block 作为函数/方法**返回值**时
- 将 Block 赋值给 `__strong` 指针时
- Block 作为 **Foundation 框架 API 的 UsingBlock 参数**时
- Block 作为 **GCD API 的方法参数**时
- 手动调用 `[block copy]`（必须是栈 Block）

所以在 MRC 中，Block 属性只能使用 `copy` 关键字；在 ARC 中，`copy` 和 `strong` 均可，**但为了代码语义清晰和 MRC/ARC 兼容，推荐统一使用 `copy`**。

### 1.3 逃逸（Escaping）与 Block 生命周期

**逃逸**指的是：Block/闭包在**「包住它的那个函数已经 return 之后」**，仍然可能被调用，或仍被某处（队列、属性、网络回调等）持有。

| 对比 | 说明 |
|------|------|
| **不逃逸** | 只在当前函数调用栈上、在 **return 之前**同步执行完（例如本函数里立刻调用的内联逻辑），不会活过这次函数返回 |
| **逃逸** | 放进 `dispatch_async`、赋给 `completion` 属性、交给 `NSURLSession` 等 → 函数先结束，**以后某时刻**才执行 Block |

OC **没有** `escaping` 关键字，但概念完全适用：**一旦逃逸**，栈上的 Block 不能指望「函数返回后还存在」，所以 ARC 会在常见逃逸路径上 **自动 copy 到堆**（与上一节「传给 GCD、赋给 strong 指针」一致），否则会出现悬空或未定义行为。

典型 **事实逃逸**场景：`dispatch_async/after`、`animateWithDuration`、`performBlock:` 类 API、属性里存的 completion、`-[NSURLSession dataTaskWithRequest:completionHandler:]` 等。

**逃逸闭包（语义）与堆 Block（实现）——怎么类比、什么关系？**

| 说法 | 含义 |
|------|------|
| **逃逸** | 描述 **时间问题**：这段代码是否可能在「外层函数返回之后」才被调用或仍被持有。 |
| **堆 Block (`__NSMallocBlock__`)** | 描述 **存储位置**：Block 对象（含截获数据）是否在堆里，从而**不随栈帧销毁而失效**。 |

**关系（可当作记忆抓手，不是数学等同）：**

- **有逃逸需求 + Block 截获了 auto 变量**：仅靠栈 Block 在 return 后会「悬空」，所以 ARC 会在逃逸路径上 **`copy` 到堆**，得到 **MallocBlock** —— 这是「逃逸 → 往往需要堆」在 OC 里最常出现的一条因果链。
- **仍不等同**：无截获的 **Global Block** 既不占栈捕获区，也**无需**为逃逸单独上堆，但业务上照样可以传给 GCD（逃逸的是「调用时机」，全局一份代码仍合法）。
- **非逃逸**在 OC 里没有关键字，大致对应：**只在当前函数里同步跑完**、不把 Block 交给异步/属性 —— 往往连「栈 Block 还未 copy」的窗口都很短，风险边界比逃逸小得多。

**Swift**：`@escaping` 标注的是**语义契约**（可晚于调用者结束）；具体分配在栈/堆/对象由编译器决定。**和 OC 互操作、或做对照记忆时**，可把 **`@escaping` ≈ 「可能要像堆 Block 那样活得久」**；纯 Swift 闭包未必逐个映射到 runtime 的 `__NSMallocBlock__`，但**生命周期问题同一类**。

与 **Swift** 语法细节：见下文 **§7.5**（含与堆 Block 对照的一句小结）。

---

## 2. 底层原理

### 2.1 完整内存结构

```
┌──────────────────────────────────────┐
│            __block_impl              │
│  isa      → &_NSConcreteStackBlock   │  ← 决定 Block 类型
│  Flags    → 0                        │
│  FuncPtr  → __main_block_func_0      │  ← 函数指针（Block 执行体）
├──────────────────────────────────────┤
│         __main_block_desc_0          │
│  reserved        → 0                 │
│  Block_size      → sizeof(impl)      │
│  copy_helper     → (截获对象/byref 时存在) │  ← 管理引用计数
│  dispose_helper  → (截获对象/byref 时存在) │
├──────────────────────────────────────┤
│         截获的外部变量                  │
│  int age = 10                        │  ← 值类型：值传递
│  id obj  = __strong 指针             │  ← 对象类型：连同所有权修饰符一起截获
│  __Block_byref *byrefVar             │  ← __block 变量：指针传递
└──────────────────────────────────────┘
```

### 2.2 变量截获规则（重点）

**所谓截获，就是结构体内部会有一个专门的新成员来存储外部对应变量的值。**

| 变量类型 | 截获方式 | 能否在 Block 内修改 |
|---------|---------|------------------|
| `auto` 局部变量（基础数据类型） | **值传递**，只截获其值 | ❌ 不能（const 语义） |
| `auto` 局部变量（对象类型） | **连同所有权修饰符一起截获**（见下） | ❌ 不能重新赋值（但能改属性） |
| `static` 局部变量 | **指针传递** | ✅ 能 |
| 全局变量（含静态全局变量） | **不截获，直接访问** | ✅ 能 |
| `__block` 修饰的变量 | 包装为 `__Block_byref` 结构体，截获**其指针** | ✅ 能 |

**「连同所有权修饰符一起截获」在说什么？（与栈/堆的关系）**

这句话指的是：**编译器在 Block 结构体里为 `auto` 对象生成的捕获成员，其内存管理语义与外界的 `__strong` / `__weak` / `__unsafe_unretained` 一致**，并由（可能存在的）`copy_helper` / `dispose_helper` 在 **Block 在栈↔堆之间迁移或销毁** 时落实，而不是说「标题在描述：只要截获就立刻对对象 `retain` 一次」。

与 **知识小集00** 一致的工程理解可以拆成两层：

| 层次 | 含义 |
|------|------|
| **截获（结构体层面）** | 对象指针（及对应所有权语义）进入 Block 的 captures，便于 Block 体内通过指针找对象。 |
| **引用计数（运行时层面）** | **`__strong`**：栈 Block 阶段通常 **不再额外 `retain`**（块随栈帧结束即失效，再去 retain 无意义；小集表述为「没必要额外操作」）；**copy 到堆**时，`copy_helper` 按 `__strong` **`retain` 捕获对象**，`dispose_helper` 配对 **`release`**。 |
| | **`__weak` / `__unsafe_unretained`**：copy 到堆时按语义登记弱引用或不接管生命周期，**不是**笼统地「一律 `release` 一遍」。 |

因此：**标题讲的是「捕获语义 = 跟修饰符走」**；下面三条讲的是 **同一句口诀在栈 Block / 堆 Block 两阶段的实际簿记**，并不是标题与正文「对不上」，而是以前容易把「截获」误读成「当场 retain」。若需原文对照，可见 `读书笔记/iOS自学笔记/知识小集00——基础知识体系.md` 中「截获变量 / auto 对象类型」一节。

```objc
int a = 1;            // 值传递，Block 内无法修改
static int b = 2;     // 指针传递，可修改
__block int c = 3;    // __Block_byref 包装，可修改

void (^block)(void) = ^{
    // a = 10;        // ❌ 编译报错
    b = 20;           // ✅
    c = 30;           // ✅
    NSLog(@"%d %d %d", a, b, c);
};
```

**关于 `self` 的截获**：`self` 在方法中本质是一个**函数参数（局部变量）**，所以 Block 对 self 的截获也遵循 auto 对象类型的规则——连同所有权修饰符一起截获。

```c
// 方法编译后的 C 函数签名：
static void _I_FCFPerson_test(FCFPerson *self, SEL _cmd) { ... }

// Block 编译后的结构体：
struct __FCFPerson__test_block_impl_0 {
    struct __block_impl impl;
    struct __FCFPerson__test_block_desc_0 *Desc;
    FCFPerson *self;  // ← self 作为局部变量被截获
};
```

Block 内部访问成员变量 `_name`，实际是先截获 `self`，再通过 `self->_name` 获取。访问 `self.name` 则是编译成 `objc_msgSend` 调用 getter 方法。

---

### 2.3 `__block` 的底层实现

**什么时候需要使用 `__block`？**

**只有一种情况：需要在 Block 内部对外部的 auto 局部变量进行重新赋值。**

| 操作 | 是否需要 `__block` |
|------|-----------------|
| 在 Block 内**读取**变量 | ❌ 不需要 |
| 在 Block 内**调用对象方法**（`[obj doSomething]`） | ❌ 不需要 |
| 在 Block 内**修改对象属性**（`obj.name = @"xxx"`） | ❌ 不需要 |
| 在 Block 内**给变量重新赋值**（`count = 10` / `obj = newObj`） | ✅ 需要 |

```objc
// ✅ 场景1：修改基础数据类型的值
__block int count = 0;
void (^block)(void) = ^{ count++; };
block();
NSLog(@"%d", count); // 1

// ✅ 场景2：对对象指针重新赋值（换一个新对象）
__block NSMutableArray *arr = [NSMutableArray array];
void (^block2)(void) = ^{
    arr = [NSMutableArray array]; // 重新赋值指针，需要 __block
};

// ❌ 不需要 __block：改属性不是赋值操作
NSMutableArray *arr2 = [NSMutableArray array];
void (^block3)(void) = ^{
    [arr2 addObject:@"item"]; // ✅ 调用方法，不需要 __block
};
```

**为什么需要 `__block`？**

Block 对 auto 变量的截获，无论是值传递还是连同修饰符截获，**都不允许在 Block 内部修改外部变量**。原因：
- auto 基础数据类型是值传递，修改的是副本，Block 内外无法同步，编译器直接报错
- auto 对象类型，在 Block 内重新赋值相当于在堆上创建了新对象，与外部无关联，同样无法同步

`__block` 是一个**存储区域说明符**，它可以指定变量值存储到哪个区域中，从而解决 Block 内部无法修改 auto 变量的问题。

> 注意：`__block` 不能修饰**全局变量**和**静态变量**（这两种变量存储在数据区，编译完成后不能轻易改动其存储位置）。

**Swift 没有 `__block`**：Swift 闭包默认就能捕获并修改外部变量，编译器在底层自动做了和 `__block` 一样的事，对开发者完全透明。但 `let` 常量在闭包内不能修改。

```swift
var count = 0
let block = { count += 1 } // ✅ 直接改，不需要任何修饰符
block()
print(count) // 1

let fixed = 0
let block2 = { /* fixed += 1 */ } // ❌ let 常量不能修改
```

**`__block int c = 3;` 经 clang 编译后，变量 `c` 被包装为一个结构体**：

```c
struct __Block_byref_c_0 {
    void *__isa;
    __Block_byref_c_0 *__forwarding;  // ⭐ 关键：指向自身（栈上）或堆上副本
    int __flags;
    int __size;
    int c;                            // 真正的值
};
```

**`__forwarding` 指针的作用**：

```
Block 还没 copy 到堆（__block 变量和 Block 都在栈上）：
  栈上的 __Block_byref.__forwarding → 指向栈上的 __Block_byref 自身

Block 被 copy 到堆后（系统同时把 __Block_byref 也 copy 了一份到堆）：
  栈上的 __Block_byref.__forwarding → 改为指向堆上的 __Block_byref  ← 关键更新
  堆上的 __Block_byref.__forwarding → 指向堆上的 __Block_byref 自身

每次读写变量 c 的实际路径：__Block_byref.__forwarding->c
```

这样设计的好处：**无论访问的是栈上还是堆上的 `__Block_byref`，通过 `__forwarding` 最终都会指向堆上的那份数据**，保证 Block 内外看到的 `c` 永远是同一个值。

> 💡 **Tips：细节扩展**
>
> **Q：Block copy 到堆后，为什么栈上的 `__Block_byref` 还存在？不是应该只剩堆上的吗？**
>
> Block 被 copy 到堆，发生在方法**执行过程中**，此时方法的栈帧还没有结束，栈上的 `__Block_byref` 依然活着。两个结构体同时存在是正常的过渡状态：
>
> ```objc
> - (void)test {
>     __block int c = 10;                 // __Block_byref 在栈上创建
>     void (^block)(void) = ^{ c = 20; }; // Block copy 到堆，__Block_byref 也 copy 到堆
>                                         // 但此时 test 还没执行完，栈帧还在！
>     block();
>     NSLog(@"%d", c);  // 通过栈上的 __Block_byref 读 c，__forwarding 指向堆上的值
> }   // ← 方法结束，栈帧销毁，栈上的 __Block_byref 才消失
> ```
>
> 方法执行完毕后，栈上的 `__Block_byref` 消失，但堆上的还在（被 Block 持有），完全安全。`__forwarding` 的设计正是为了处理这个"过渡期"——在栈还活着时，确保通过栈上的 `__Block_byref` 访问 `c`，也能找到堆上的那份数据，不会读到已经"过时"的栈副本。

**`__block` 变量自身的内存管理**：
- 当 Block 在**栈上**时：不会产生强引用（没必要）
- 当 Block **copy 到堆上**时：`__Block_byref` 结构体也会被 copy 到堆上，然后通过 copy 函数处理——因为它本身变成了结构体对象，所以和 auto 对象类型一样**连同所有权修饰符一起截获**。由于 `__block` 默认是强引用修饰，所以是一个**强引用**的过程
- 当 Block **从堆上移除**时：通过 dispose 函数释放（执行 release）

---

### 2.4 Block 中的循环引用

**产生原因**：self 持有 Block（strong），Block 截获 self（strong），形成强引用环。

```objc
// ❌ 循环引用
self.block = ^{
    NSLog(@"%@", self); // Block 强引用 self
};
// 引用链：self → _block → self（无法释放）
```

**解决方案一：`__weak` + `__strong` dance（推荐）**

```objc
__weak typeof(self) weakSelf = self;
self.block = ^{
    __strong typeof(weakSelf) strongSelf = weakSelf; // ← 在 Block 执行期间临时持有 self
    if (!strongSelf) return;
    NSLog(@"%@", strongSelf);
};
```

为什么 Block 内部需要再声明 `strongSelf`？

| 场景 | 说明 |
|------|------|
| 只用 `weakSelf` | Block 执行期间 self 可能被释放，多次访问 `weakSelf` 可能前后不一致（前半段非 nil，后半段 nil） |
| 加上 `strongSelf` | Block 开始执行时临时持有 self，整个执行过程 self 不会被释放，执行完毕自动释放，**不形成循环引用** |

**解决方案二：`__unsafe_unretained`**

```objc
__unsafe_unretained typeof(self) unsafeSelf = self;
self.block = ^{
    NSLog(@"%@", unsafeSelf);
};
```

> ⚠️ **不安全**：`__unsafe_unretained` 不会置 nil，self 被释放后 unsafeSelf 变成**野指针**，访问会 crash。实际开发不推荐使用。

**解决方案三：`__block` + 断环（了解即可）**

```objc
__block id blockSelf = self;
self.block = ^{
    NSLog(@"%@", blockSelf);
    blockSelf = nil; // ← 手动断环
};
self.block(); // ⚠️ 必须执行 block，否则永远存在循环引用
```

> 缺点：必须执行 Block，否则 `blockSelf` 永远不会置 nil，循环引用一直存在。  
> **MRC vs ARC 区别**：在 MRC 下，`__block` 修饰的变量是**弱引用**，不增加引用计数，所以 MRC 下此写法不存在循环引用；在 ARC 下，`__block` 会增加引用计数（强引用），才会引发循环引用问题。

---

## 3. 关键问题 & 面试题

### Q1：Block 为什么能截获外部变量？截获的是值还是指针？

**答**：Block 底层是结构体，编译器会将截获的外部变量作为**成员变量**存入该结构体。

- `auto` **基础数据类型**：**值传递**，Block 定义时做值的快照，之后外部修改不影响 Block 内部
- `auto` **对象类型**：**连同所有权修饰符一起截获**，ARC 下默认 `__strong`，Block 会 retain 该对象
- `static` 变量：**指针传递**（地址），能读到最新值也能修改
- 全局变量：**不截获，直接访问**

### Q2：`__block` 的作用原理是什么？

**答**：`__block` 是一个**存储区域说明符**，让编译器将该变量包装成 `__Block_byref_xxx` 结构体，Block 截获的是这个结构体的**指针**。通过结构体中的 `__forwarding` 指针间接访问真实值，从而实现在 Block 内部对外部变量的写操作。当 Block 被 copy 到堆时，`__Block_byref` 结构体也会同步 copy 到堆，栈上的 `__forwarding` 会更新指向堆上的结构体，保证访问一致性。

### Q3：Block 的三种类型分别在什么情况下产生？

**答**：
- `__NSGlobalBlock__`：Block 内部**没有访问 auto 变量**（全局 Block，copy 无反应）
- `__NSStackBlock__`：Block 访问了 auto 变量，在未被 copy 之前存在于栈上（MRC 下常见；ARC 下赋值给 `__weak` 指针可观察到）
- `__NSMallocBlock__`：`__NSStackBlock__` 执行 copy 后（对堆 Block 执行 copy 只是引用计数 +1）

### Q4：如何避免 Block 中的循环引用？`__weak + __strong` 为什么要配合使用？

**答**：使用 `__weak` 打破强引用环，防止循环引用导致内存泄漏。但仅使用 `__weak` 存在问题：Block 执行期间 self 可能被释放，多次访问 `weakSelf` 结果可能不一致。在 Block 内部用 `__strong` 将 `weakSelf` 再持有一次，相当于临时延长 self 的生命周期，执行结束 `strongSelf` 出栈，self 的引用计数恢复，**不形成循环引用**。

### Q5：对一个 `__NSMallocBlock__` 执行 copy 会发生什么？

**答**：只是引用计数 +1（浅拷贝），不会重新分配内存，因为已经在堆上了。

### Q6：`__block` 在 MRC 和 ARC 下有什么区别？

**答**：
- **MRC 下**：`__block` 修饰的变量是**弱引用**，不增加对象的引用计数，不会导致循环引用
- **ARC 下**：`__block` 修饰的变量会增加引用计数（**强引用**），可能导致循环引用

### Q7：以下代码输出什么？

```objc
int i = 0;
void (^block)(void) = ^{ NSLog(@"%d", i); };
i = 10;
block();
```

**答**：输出 `0`。`i` 是 auto 变量，Block 定义时执行**值传递**，捕获的是 `i = 0` 时的快照，后续对 `i` 的修改不影响 Block 内部的副本。

---

## 4. 实战应用

### 4.1 Block 属性的正确声明

```objc
// ✅ 正确：使用 copy（MRC 必须；ARC 推荐，语义清晰）
@property (nonatomic, copy) void (^successBlock)(id data);

// ❌ 错误：使用 assign（栈上 Block 会被提前销毁，访问时 crash）
@property (nonatomic, assign) void (^dangerBlock)(void);
```

### 4.2 Block 回调的最佳实践

```objc
// .h 文件：定义 Block 类型别名
typedef void (^CompletionBlock)(BOOL success, NSError * _Nullable error);

@interface NetworkManager : NSObject
- (void)fetchDataWithCompletion:(CompletionBlock)completion;
@end

// .m 文件：保存到属性时，用 copy
- (void)fetchDataWithCompletion:(CompletionBlock)completion {
    self.completionBlock = [completion copy];
    // ... 网络请求 ...
}
```

### 4.3 避免循环引用的完整模板

```objc
// 标准 weak-strong dance
__weak typeof(self) weakSelf = self;
self.block = ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) return;
    [strongSelf doSomething];
};

// 使用 libextobjc 的 @weakify / @strongify 宏（推荐）
@weakify(self);
self.block = ^{
    @strongify(self);
    if (!self) return;
    [self doSomething];
};
```

### 4.4 NSTimer 循环引用的三种解决方案

NSTimer 持有 target（self），self 持有 timer，形成循环引用：

```objc
// ❌ 循环引用：self → timer → self
_timer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                          target:self
                                        selector:@selector(fire)
                                        userInfo:nil
                                         repeats:YES];
```

**方案一：使用 Block API，避免 target 强引用**

```objc
__weak typeof(self) weakSelf = self;
_timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                         repeats:YES
                                           block:^(NSTimer *timer) {
    [weakSelf fire];
}];
```

**方案二：中间类（继承自 NSObject）+ 消息转发**

```objc
@interface FCFProxy : NSObject
+ (instancetype)proxyWithTarget:(id)target;
@property (nonatomic, weak) id target;
@end

@implementation FCFProxy
+ (instancetype)proxyWithTarget:(id)target {
    FCFProxy *proxy = [FCFProxy new];
    proxy.target = target;
    return proxy;
}
// 将找不到的 selector 转发给 target
- (id)forwardingTargetForSelector:(SEL)aSelector {
    return self.target;
}
@end

// 使用：NSTimer 强引用中间类，中间类弱引用 self，打破循环
_timer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                          target:[FCFProxy proxyWithTarget:self]
                                        selector:@selector(fire)
                                        userInfo:nil
                                         repeats:YES];
```

**方案三：中间类（继承自 NSProxy）+ 消息转发（性能更优）**

```objc
// NSProxy 专门用于消息转发，不经过消息查找和动态解析，直接进入 methodSignatureForSelector
@interface FCFProxy : NSProxy
+ (instancetype)proxyWithTarget:(id)target;
@property (nonatomic, weak) id target;
@end

@implementation FCFProxy
+ (instancetype)proxyWithTarget:(id)target {
    FCFProxy *proxy = [FCFProxy alloc]; // NSProxy 无 init 方法
    proxy.target = target;
    return proxy;
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [self.target methodSignatureForSelector:sel];
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:self.target];
}
@end
```

> `CADisplayLink` 也存在同样的循环引用问题，可以用方案二或方案三解决。

### 4.5 循环引用排查工具

- **Xcode Memory Graph Debugger**（调试时点击内存图标）：可视化引用链，直接看到循环引用节点
- **Instruments Leaks**：检测运行时内存泄漏
- **MLeaksFinder**：运行时检测 VC/View 是否按时释放

---

## 5. 底层源码关键函数速查

| 函数 | 作用 |
|------|------|
| `_Block_copy` | 将栈 Block copy 到堆，触发 copy_helper |
| `_Block_release` | 释放堆 Block，触发 dispose_helper |
| `_Block_object_assign` | Block copy 时对截获对象/byref 执行 retain |
| `_Block_object_dispose` | Block 销毁时对截获对象/byref 执行 release |
| `__Block_byref_id_object_copy` | `__Block_byref` 结构体 copy 时的对象 retain |
| `__Block_byref_id_object_dispose` | `__Block_byref` 结构体释放时的对象 release |

源码参考：[libclosure（Block 运行时）](https://opensource.apple.com/source/libclosure/)

---

## 6. 知识图谱总结

```
Block
├── 本质：OC 对象（结构体 + isa 指针，继承自 NSObject）
├── 三种类型
│   ├── Global（全局区，无 auto 变量截获，copy 无反应）
│   ├── Stack（栈，截获 auto 变量，未 copy）
│   └── Malloc（堆，copy 后；对堆 Block copy 只是引用计数 +1）
├── 变量截获
│   ├── auto 基础类型 → 值传递（只读）
│   ├── auto 对象类型 → 连同所有权修饰符一起截获
│   │   ├── 栈 Block：不产生强引用
│   │   └── 堆 Block：根据修饰符产生强/弱引用
│   ├── static → 指针传递（可读写）
│   ├── 全局变量 → 直接访问（不截获）
│   └── __block → __Block_byref 结构体（可读写）
├── __block 原理
│   ├── 存储区域说明符，不能修饰全局/静态变量
│   ├── 包装为 __Block_byref 结构体
│   ├── __forwarding 指针保证 copy 后访问一致性
│   ├── MRC 下：弱引用，不增加引用计数
│   └── ARC 下：强引用，增加引用计数
├── copy 时机（ARC 自动触发）
│   ├── 赋给 __strong 指针
│   ├── 作为返回值
│   ├── 传入 Foundation/GCD 的 Block 参数
│   ├── 手动调用 copy
│   └── 与「逃逸」对应：宿主函数 return 后仍可能执行 → 需堆 Block / 稳定捕获
└── 循环引用
    ├── 原因：self → Block → self（strong 截获）
    ├── 方案1：__weak + __strong dance（推荐）
    ├── 方案2：__unsafe_unretained（不安全，有野指针风险）
    └── 方案3：__block + 断环（必须执行 Block，否则永远循环）
```

---

## 7. Swift Closure 与 Block 互操作

（与上文 OC `Block` 对照阅读。）

### 7.1 Closure 的基本使用

```swift
// 基本闭包
let simpleClosure = {
    print("Hello Closure")
}
simpleClosure()

// 带参数的闭包
let calculateClosure = { (a: Int, b: Int) -> Int in
    return a + b
}
let result = calculateClosure(10, 20) // 30

// 捕获外部变量
let multiplier = 3
let multiplyClosure = { (num: Int) -> Int in
    return num * multiplier
}
```

### 7.2 闭包捕获列表

```swift
var count = 0
let closure = { [count] in
    count += 1
    print("Count: \(count)")
}
```

| 捕获类型 | 说明 | 适用场景 |
|---------|------|----------|
| `[unowned self]` | 无主引用，不会增加引用计数 | `self` 不会被提前释放 |
| `[weak self]` | 弱引用 | `self` 可能被提前释放 |
| `[var variable]` | 显式捕获变量 | 需要修改变量时 |

### 7.3 Swift 闭包 vs OC Block

| 特性 | OC Block | Swift Closure |
|------|----------|---------------|
| **类型安全** | 弱类型 | 强类型 |
| **变量捕获** | 默认值捕获 | 捕获列表（可读写） |
| **内存管理** | 手动 copy | ARC 自动管理 |
| **循环引用** | `__weak` 或 `__block` | `weak`/`unowned` |
| **逃逸 vs 存储** | 事实逃逸 + 截获 auto → 常 `copy` 为 **堆 Block** | `@escaping` 标**语义**；分配策略由编译器决定（见 §1.3、§7.5） |

### 7.4 OC / Swift 互操作要点

- OC 持有 Swift 闭包时，需保证桥接类型与生命周期正确（避免过早释放）。
- Swift 调用 OC `typedef` 的 Block 时，可直接使用 trailing closure 语法赋值。

### 7.5 逃逸与非逃逸（`@escaping`）

Swift 3 起，**函数参数中的闭包类型默认是「非逃逸」（non-escaping）**：编译器假定它**只会在当前函数 `return` 之前**被调用（或同步用完），因此可以做更多优化，且在内联闭包里对 `self` 的捕获规则也更宽松。

一旦闭包需要 **活过当前函数**（异步、存属性、转交给别的对象以后再调），必须在参数上标 **`@escaping`**：

```swift
func doWorkNow(_ body: () -> Void) {
    body() // 仅同步调用 → 默认 nonescaping 即可
}

func doWorkLater(_ body: @escaping () -> Void) {
    DispatchQueue.main.async {
        body() // 本函数 return 之后才执行 → 必须 escaping
    }
}
```

**和 OC Block 的对应关系**：OC 里「丢进 GCD / 属性 / 网络回调」的 Block，本质上都是 **逃逸**；若还截获了 auto 变量，ARC 常会 **copy 成堆 Block**，与 **§1.3** 表格中的「逃逸 ↔ 堆」一条链一致。Swift 用 `@escaping` 把「会逃逸」变成一种**显式契约**，读 API 时能立刻看出来闭包可能晚于调用者结束。

**类比小结**：`@escaping` 是**语言层的「会不会活过本次调用」**；堆 Block 是 **OC runtime 里常见的一种落点**（尤其是「逃逸 + 有截获」），二者 **问题域相同（生命周期）** ，**层级不同（语义 vs 对象存在哪）**。纯 Swift 闭包不一定等价于某个 `__NSMallocBlock__`，但和 OC Block 对照复习时可以这样记。

---

## 8. 参考资料

- [Apple 开源 libclosure 源码](https://opensource.apple.com/source/libclosure/)
- [Clang Block 语言规范](https://clang.llvm.org/docs/BlockLanguageSpec.html)
- 《Objective-C 高级编程》第2章 - Blocks
- WWDC 2012 Session 712 - Adopting Automatic Reference Counting
