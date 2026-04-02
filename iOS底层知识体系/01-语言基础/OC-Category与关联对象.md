# OC Category 与关联对象

> 一句话总结：Category 是在**运行时**将方法/属性/协议附加到已有类的机制；关联对象是 Runtime 通过全局哈希表为**任意对象**动态绑定键值数据的独立机制。两者常配合使用，但本质上是两个独立的知识点。

---

## 一、Category（分类）

### 1.1 本质与作用

Category 最直接的作用是**给已有类添加方法**，其他用途包括：
- 拆分单个过大的文件，便于多人同时开发一个类
- 声明私有方法
- 将功能相近的方法归组，提高可读性

Category 是**运行时决议**的：OC 初始化时调用 `_read_images`，此时会加载所有类、协议和 Category，并将 Category 的内容合并进宿主类。

底层结构体 `category_t`：

```c
struct category_t {
    const char *name;                  // 分类名称
    classref_t cls;                    // 宿主类
    struct method_list_t *instanceMethods;  // 实例方法列表
    struct method_list_t *classMethods;     // 类方法列表
    struct protocol_list_t *protocols;      // 协议列表
    struct property_list_t *instanceProperties; // 属性列表
};
```

**注意**：`category_t` 中有 `instanceProperties`，但这只是属性的 getter/setter 方法的**声明**，没有对应的 `ivar`（成员变量）。Category **不能为已有类添加成员变量**，因为运行时类的内存布局已经确定，无法再插入新的 ivar。

> `属性 = getter + setter + ivar`，Category 里只能实现前两者，缺少 ivar。

---

### 1.2 Category 的加载流程

```
APP 启动
  → dyld 加载 image
  → _objc_init
  → map_images
  → _read_images           ← 加载所有类、协议、Category
      → attachCategories   ← 将 Category 的方法/属性/协议合并进宿主类
```

**合并方式：头插法**

Category 的方法是**插入到宿主类方法列表的最前面**，而不是追加到末尾。所以：
- 宿主类和 Category 有同名方法时，Category 的方法会被**优先找到**（不是真正的覆盖，宿主类的方法仍然存在，只是排在后面找不到了）
- 多个 Category 有同名方法时，**最后编译**的 Category 的方法排在最前面，会被优先调用

> 编译顺序可在 Xcode → Build Phases → Compile Sources 中查看和调整。

---

### 1.3 +load 与 +initialize

`+load` 和 `+initialize` 都是类的特殊方法，但行为完全不同：

| 对比项 | `+load` | `+initialize` |
|-------|--------|--------------|
| 调用时机 | APP 启动，`main` 函数**之前** | 类**第一次接收到消息**时（懒加载） |
| 调用方式 | 直接通过函数地址调用，**不走消息发送** | 通过 `objc_msgSend` 调用 |
| 是否每个类都调用 | ✅ 每个类和分类的 `+load` **都会被调用** | ❌ 只调用一次，懒加载 |
| 父子类顺序 | 先父类后子类，先宿主类后分类 | 先父类后子类 |
| 分类同名处理 | 宿主类和所有分类的 `+load` **全部执行** | 只执行**最后编译**的分类的 `+initialize`（其余被覆盖） |
| 是否需要调用 super | ❌ 不需要（系统已处理顺序） | ❌ 不需要（系统自动调用父类） |

**为什么行为不同？**

- `+initialize` 本质是 `objc_msgSend` 消息调用，遵循分类覆盖规则，所以只有排在最前面的版本会被调用
- `+load` 不走消息发送，而是在 `_read_images` 阶段直接**通过函数指针地址**调用，所以每一个都能被执行，不会被覆盖

```objc
// +load 的典型用途：执行 Method Swizzling（只在这里做最安全）
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 方法交换...
    });
}
```

---

### 1.4 Category vs Extension

| 对比项 | Category（分类） | Extension（扩展） |
|-------|--------------|----------------|
| 决议时机 | **运行时** | **编译时** |
| 生命周期 | 独立于宿主类 | 依附于宿主类，随之一起编译 |
| 能否有实现 | 有声明有实现 | 只有声明，实现写在宿主类 `.m` 中 |
| 能否为系统类添加 | ✅ 能 | ❌ 不能（无法修改系统类的 .m） |
| 能否添加成员变量 | ❌ 不能 | ✅ 能 |
| 主要用途 | 添加方法、拆分功能 | 声明私有属性、私有方法、私有成员变量 |

> Extension 可以看作一个"**匿名的分类**"，但它不是分类。

---

### 1.5 Category 面试高频题

**Q1：Category 可以添加属性吗？可以添加成员变量吗？**

- **成员变量**：❌ 不能。Category 是运行时决议的，此时类的内存布局已经确定，无法再插入 ivar。
- **属性**：⚠️ 可以声明（`@property`），但编译器只会生成 getter/setter 的**声明**，不会生成 ivar 和对应的实现，调用时会 crash。若要真正使用，需要结合关联对象手动实现 getter/setter。

**Q2：多个 Category 有同名方法，调用顺序是什么？会覆盖原类方法吗？**

- **不是真正的覆盖**，宿主类的方法仍然存在于方法列表中，只是排在后面，正常的方法查找流程找不到它
- Category 的方法通过**头插法**插入宿主类方法列表的最前面，所以 Category 方法会被**优先调用**
- 多个 Category 有同名方法时，**最后编译**的 Category 的方法最先被找到
- `+load` 方法例外：每个类和分类的 `+load` 都会被执行，不受覆盖影响

**Q3：为什么 Method Swizzling 要在 +load 中执行，而不是 +initialize？**

- `+initialize` 是懒加载，如果该类从未被使用，`+initialize` 永远不会执行，导致交换失效
- `+load` 在 APP 启动时确保每个类都会调用，保证交换一定被执行
- 同时要配合 `dispatch_once`，防止多次调用导致方法交换来回抵消而失效

---

### 1.6 Category 实战

#### Method Swizzling 标准写法

```objc
// UIViewController+Tracking.m
@implementation UIViewController (Tracking)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];

        SEL originalSelector = @selector(viewWillAppear:);
        SEL swizzledSelector = @selector(xxx_viewWillAppear:);

        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

        // 先尝试添加方法，防止原类没有实现该方法时直接交换崩溃
        BOOL didAddMethod = class_addMethod(class,
                                            originalSelector,
                                            method_getImplementation(swizzledMethod),
                                            method_getTypeEncoding(swizzledMethod));
        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (void)xxx_viewWillAppear:(BOOL)animated {
    [self xxx_viewWillAppear:animated]; // 调用原方法（此时已交换，实际调用原 viewWillAppear:）
    NSLog(@"页面展示：%@", NSStringFromClass([self class]));
}

@end
```

> **Tips：两个 Category 同时对同一方法做 Swizzling 会怎样？**
>
> 如果两个 Category 分别将同一个原始方法（如 `viewWillAppear:`）与各自的方法交换，执行结果是：第一个 Category 交换后，第二个 Category 又把它换回来（因为拿到的 `originalMethod` 已经是第一次交换后的结果），最终效果等于没有交换。所以应避免多个 Category 对同一方法做 Swizzling。

---

## 二、关联对象（Associated Object）

### 2.1 什么是关联对象

关联对象是 OC Runtime 提供的一套机制，允许在**不修改类定义**的前提下，为**任意 OC 对象**动态绑定键值对数据。

它的核心 API 只有三个：

```objc
// 设置关联值
void objc_setAssociatedObject(id object, const void *key, id value, objc_AssociationPolicy policy);

// 获取关联值
id objc_getAssociatedObject(id object, const void *key);

// 移除对象的所有关联值（慎用）
void objc_removeAssociatedObjects(id object);
```

**关联策略（`objc_AssociationPolicy`）对照**：

| 策略常量 | 对应属性修饰符 |
|---------|------------|
| `OBJC_ASSOCIATION_ASSIGN` | `assign` |
| `OBJC_ASSOCIATION_RETAIN_NONATOMIC` | `strong, nonatomic` |
| `OBJC_ASSOCIATION_COPY_NONATOMIC` | `copy, nonatomic` |
| `OBJC_ASSOCIATION_RETAIN` | `strong, atomic` |
| `OBJC_ASSOCIATION_COPY` | `copy, atomic` |

> 关联对象虽然常与 Category 配合使用，但它本身是**独立于 Category 的 Runtime 能力**，可以在任何地方为任意对象绑定数据。

---

### 2.2 底层数据结构

关联对象的核心是 Runtime 维护的一套**全局嵌套哈希表**：

```
AssociationsManager（单例，管理全局锁 + 全局 map）
  └── AssociationsHashMap（全局静态 map）
        ├── key: object 指针（被关联的对象）
        └── value: ObjectAssociationMap
                    ├── key: 关联 key（void *）
                    └── value: ObjectAssociation
                                  ├── policy（内存策略）
                                  └── value（关联的值）
```

用图示表示：

```
AssociationsHashMap
  object_A  →  ObjectAssociationMap
                  @selector(name)  →  ObjectAssociation { RETAIN, @"Tom" }
                  @selector(age)   →  ObjectAssociation { ASSIGN, @18 }
  object_B  →  ObjectAssociationMap
                  @selector(tag)   →  ObjectAssociation { COPY, @"vip" }
```

**关键特性**：
- 所有对象的关联对象都存储在这**同一个全局容器**中，与被关联对象的内存布局无关
- `AssociationsManager` 内部有一把**自旋锁（spinlock）**，保证线程安全
- 关联对象**不存储在对象本身**内，而是通过对象指针在全局 map 中查找

---

### 2.3 生命周期管理

对象执行 `dealloc` 时，Runtime 会自动检查该对象是否有关联对象，如果有则自动清理——**不需要手动移除关联对象**。

`dealloc` 内部判断流程（简化）：

```
dealloc
  → 判断 nonpointer_isa 中的 has_assoc 位是否为 1
  → 是 → 调用 _object_remove_associations(self)
         → 从 AssociationsHashMap 中移除该对象对应的所有关联对象
         → 根据 policy 对 value 执行 release
```

> `isa` 的第 2 位 `has_assoc` 标记了对象是否存在关联对象，`dealloc` 正是通过这个标志位快速判断是否需要清理，避免无谓的 map 查找。

**移除方式**：
- 移除**单个**关联值：调用 `objc_setAssociatedObject` 并传入 `nil` 作为 value
- 移除**所有**关联值：`objc_removeAssociatedObjects(object)`（慎用，会清除所有关联数据，包括其他模块设置的）

```objc
// 移除单个
objc_setAssociatedObject(self, &kNameKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
```

---

### 2.4 关联对象面试高频题

**Q1：关联对象存储在哪里？对象销毁时怎么处理？**

- 存储在 Runtime 维护的**全局 `AssociationsHashMap`** 中，不在对象本身的内存里
- 对象 `dealloc` 时，Runtime 会通过 `isa` 中的 `has_assoc` 标志位检测，自动调用 `_object_remove_associations` 清理，**无需手动移除**

**Q2：关联对象是线程安全的吗？**

- `objc_setAssociatedObject` / `objc_getAssociatedObject` 内部通过 `AssociationsManager` 的自旋锁保护，读写操作本身是**原子安全**的
- 但如果对关联值的读写存在逻辑上的竞态（如先读后写的复合操作），仍需要外部加锁

**Q3：关联对象的 key 一般用什么？**

常见方式及优劣：

| 方式 | 示例 | 优点 | 缺点 |
|-----|------|------|------|
| 静态变量地址 | `static const void *kKey = &kKey;` | 唯一、稳定 | 需要声明变量 |
| `@selector` | `@selector(propertyName)` | 不需要额外声明，语义清晰 | 和方法名耦合 |
| `_cmd` | `objc_getAssociatedObject(self, _cmd)` | getter 中使用最简洁 | 仅适合 getter，setter 中 `_cmd` 不同 |

---

### 2.5 关联对象实战

#### 为 Category 属性提供存储

```objc
// UIView+Tag.h
@interface UIView (Tag)
@property (nonatomic, copy) NSString *customTag;
@end

// UIView+Tag.m
#import <objc/runtime.h>

@implementation UIView (Tag)

static const void *kCustomTagKey = &kCustomTagKey;

- (NSString *)customTag {
    return objc_getAssociatedObject(self, kCustomTagKey);
}

- (void)setCustomTag:(NSString *)customTag {
    objc_setAssociatedObject(self, kCustomTagKey, customTag, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
```

#### 为 UIButton 添加 Block 回调

```objc
// UIButton+Block.h
typedef void(^ButtonActionBlock)(UIButton *button);

@interface UIButton (Block)
- (void)addActionBlock:(ButtonActionBlock)block forControlEvents:(UIControlEvents)events;
@end

// UIButton+Block.m
static const void *kActionBlockKey = &kActionBlockKey;

@implementation UIButton (Block)

- (void)addActionBlock:(ButtonActionBlock)block forControlEvents:(UIControlEvents)events {
    objc_setAssociatedObject(self, kActionBlockKey, block, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self addTarget:self action:@selector(handleAction:) forControlEvents:events];
}

- (void)handleAction:(UIButton *)sender {
    ButtonActionBlock block = objc_getAssociatedObject(self, kActionBlockKey);
    if (block) block(sender);
}

@end
```

#### 在非 Category 场景中使用关联对象

关联对象不限于 Category，任何需要"为对象临时附加数据"的场景都可以使用：

```objc
// 给 UIAlertController 关联一个回调 block，方便在 delegate 回调中取出
objc_setAssociatedObject(alertController, &kCompletionKey, completion, OBJC_ASSOCIATION_COPY_NONATOMIC);
```

---

## 三、两者的联动与对比

### 3.1 为什么经常一起讲？

Category 不能添加 ivar → 声明的 `@property` 没有实际存储 → 关联对象恰好补全了这个缺口。

这是两者最常见的配合场景，但**并不意味着关联对象只服务于 Category**。

### 3.2 对比总结

| 对比维度 | Category | 关联对象 |
|---------|----------|---------|
| **层级** | 语言机制（编译器 + Runtime 协作） | 纯 Runtime 机制 |
| **作用** | 为已有类添加方法/属性声明/协议 | 为任意对象动态绑定键值数据 |
| **存储** | 方法合并进宿主类的方法列表 | 存储在全局 `AssociationsHashMap` |
| **限制** | 不能添加 ivar | 无 ivar 限制，但只能存 OC 对象（`id`） |
| **生命周期** | 随 APP 启动时加载，永久存在 | 随对象 `dealloc` 自动清理 |
| **线程安全** | 加载过程由 Runtime 保证 | 读写由 `AssociationsManager` 自旋锁保证 |
| **使用范围** | 只能用于 OC 类 | 可用于任意 OC 对象，不限于 Category 场景 |

### 3.3 典型协作模式

```
Category 声明 @property
   ↓
编译器只生成 getter/setter 的声明
   ↓
手动实现 getter/setter
   ↓
内部用 objc_setAssociatedObject / objc_getAssociatedObject 读写数据
   ↓
对象 dealloc 时 Runtime 自动清理关联数据
```

---

## 四、知识图谱总结

```
Category（分类）                              关联对象（Associated Object）
├── 本质：category_t 结构体                    ├── 本质：Runtime 全局哈希表存储
│   （方法/属性/协议列表，无 ivar）              │   （AssociationsManager → HashMap → Map → Association）
├── 决议时机：运行时                            ├── 线程安全：自旋锁
│   （_read_images → attachCategories）       ├── 生命周期：对象 dealloc 自动清理
├── 方法合并：头插法                            │   （isa.has_assoc 标志位判断）
│   （Category 方法优先于宿主类方法）             ├── API 三件套：
├── 多 Category 同名方法：                      │   set / get / removeAll
│   最后编译的优先                              ├── key 的选择：
├── 不能添加成员变量                             │   静态变量地址 / @selector / _cmd
├── +load：启动时调用，函数地址直接调用            └── 应用场景：
├── +initialize：懒加载，objc_msgSend              ├── Category 属性存储
└── vs Extension：编译时决议                        ├── 为对象附加临时数据
                                                   └── Block 回调封装
              ↕ 联动 ↕
   Category 属性声明 + 关联对象存储实现
```

---

## 五、参考资料

- [Apple 开源 objc4 源码](https://opensource.apple.com/source/objc4/)
- 《Objective-C 高级编程》第4章 - Objective-C Runtime
- objc-runtime-new.mm：`attachCategories` 函数
- objc-references.mm：`objc_setAssociatedObject` 实现
