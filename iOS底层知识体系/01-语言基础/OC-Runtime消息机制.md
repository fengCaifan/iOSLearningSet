# OC Runtime 消息机制

> 一句话总结：**Runtime 是 OC 的运行时系统，通过消息发送机制实现动态调用，让程序在运行时可以创建类、添加方法、修改方法实现，是 OC 动态特性的核心。**

---

## 📚 学习地图

- **预计学习时间**：45 分钟
- **前置知识**：OC 基础、面向对象
- **学习目标**：理解 Runtime → 掌握消息机制 → 应用 Method Swizzling

---

## 1. 核心概念

### 1.1 什么是 Runtime？

**Runtime** 是一个纯 C 语言编写的运行时库，为 OC 提供运行时支持，使 OC 成为一种动态语言。

**工作模式**：
- **编译时**：OC 代码转换为 Runtime C 函数调用
- **运行时**：动态决定调用哪个方法实现

**关键特性**：

| 特性 | 说明 |
|------|------|
| **动态类型** | 运行时确定对象类型（id 类型） |
| **动态绑定** | 运行时确定调用哪个方法 |
| **动态加载** | 运行时添加类、方法、协议 |

### 1.2 Runtime 的作用

| 作用 | 说明 |
|------|------|
| **消息派发** | 通过 objc_msgSend 实现方法调用 |
| **动态方法** | 运行时添加、修改、交换方法 |
| **反射机制** | 获取类、方法、属性信息 |
| **内存管理** | ARC 的底层实现 |
| **KVO/KVC** | 键值观察和键值编码的底层实现 |

### 1.3 OC 与 C 的转换

```objective-c
// OC 代码
[obj method];

// 转换为 Runtime C 代码
objc_msgSend(obj, @selector(method));
```

---

## 2. 底层原理

### 2.1 类与对象的结构

#### objc_class 源码（objc2.0 简化版）

```c
struct objc_class {
    Class _Nonnull isa;                // isa 指针

#if !__OBJC2__
    Class _Nullable super_class;       // 父类
    const char * _Nonnull name;        // 类名
    long version;                      // 版本
    long info;                         // 信息位
    long instance_size;                // 实例大小
    struct objc_ivar_list * _Nullable ivars;        // 成员变量列表
    struct objc_method_list * _Nullable * _Nullable methodLists; // 方法列表
    struct objc_cache * _Nonnull cache;            // 方法缓存
    struct objc_protocol_list * _Nullable protocols;// 协议列表
#endif
};

struct objc_object {
    Class _Nonnull isa;
};

typedef struct objc_class *Class;
typedef struct objc_object *id;
```

#### isa 指针走向图

```
实例对象 isa ────────────────> 类对象 isa ───────────────> 元类 isa
                                │                             │
                                ↓                             ↓
                           元类 isa ────────────────> 根元类 isa
                                                           │
                                                           ↓
                                                      根元类自身
```

**isa 指向规则**：

| 对象类型 | isa 指向 |
|----------|----------|
| **实例对象** | 类对象 |
| **类对象** | 元类 |
| **元类** | 根元类 |
| **根元类** | 根元类自身 |

#### super_class 指向

| 对象类型 | super_class 指向 |
|----------|-----------------|
| **类对象** | 父类的类对象 |
| **元类** | 父类的元类 |
| **根元类** | 根类（NSObject） |
| **根类（NSObject）** | nil |

#### 类、元类、对象的关系

```
NSObject (类对象) ←────── 元类 ←────── 根元类 ←────── 根元类自身
    ↓                         ↑             ↑             ↑
  实例对象 ──isa───>        元类 ISA       元类 ISA        元类 ISA
```

**核心结论**：

| 结论 | 说明 |
|------|------|
| **实例方法** | 存储在类对象的方法列表中 |
| **类方法** | 存储在元类的方法列表中 |
| **一切皆对象** | 类也是对象，是元类的实例 |

### 2.2 方法与成员

#### Method 结构

```c
typedef struct method_t *Method;

struct method_t {
    SEL name;           // 方法名（选择子）
    const char *types;  // 参数类型和返回值类型
    IMP imp;            // 函数实现指针
};
```

#### SEL、IMP、Method 的关系

| 组成 | 说明 | 类比 |
|------|------|------|
| **SEL** | 方法名（选择子），实际上是 C 字符串 | 书名 |
| **IMP** | 函数指针，指向方法实现 | 书的内容 |
| **Method** | SEL + IMP + types，完整的方法对象 | 一本书 |

```objective-c
// 一个类持有一个方法链表
// 表中的每个元素是 Method
// Method 的 SEL 对应着 IMP
```

#### IMP 函数指针

```c
typedef void (*IMP)(void /* id, SEL, ... */);

// 对比 C 函数指针
void (*funP)(int);

// IMP 就是函数实现，函数入口
```

**获取 IMP 的方法**：

```objective-c
// 根据 SEL 获取 IMP
- (IMP)methodForSelector:(SEL)aSelector;          // 实例方法
+ (IMP)instanceMethodForSelector:(SEL)aSelector;  // 类方法

// 使用示例
IMP imp = [obj methodForSelector:@selector(testMethod)];
imp(obj, @selector(testMethod)); // 直接调用
```

#### Property（属性）

```c
typedef struct property_t * objc_property_t;

struct property_t {
    const char *name;       // 属性名
    const char *attributes; // 属性特性（strong/weak/copy 等）
};
```

**注意**：属性 = ivar + setter + getter

#### Ivar（成员变量）

- ivar 只存储成员变量，不包含方法
- **不能动态添加 ivar**（会破坏内存布局）
- 但动态创建的类可以添加 ivar

### 2.3 消息发送机制

#### objc_msgSend 原型

```objective-c
// OC 代码
[obj method];

// 转换为 Runtime
objc_msgSend(obj, @selector(method));
```

#### objc_msgSend 变体

| 函数 | 说明 |
|------|------|
| `objc_msgSend` | 标准消息发送 |
| `objc_msgSendSuper` | 发送 super 消息 |
| `objc_msgSend_fpret` | 返回浮点数 |
| `objc_msgSend_stret` | 返回结构体 |
| `objc_msgSendSuper_stret` | super 返回结构体 |

#### 消息发送流程（重点）

```
1. 判断 receiver 是否为 nil
   └─> 是：直接返回（OC 对 nil 发消息不崩溃）

2. 从方法缓存中查找 IMP
   └─> cache_getImp(cls, sel)
   └─> 找到：直接调用 IMP

3. 从当前类的方法列表中查找
   └─> 遍历 methodLists
   └─> 找到：返回 IMP 并加入缓存

4. 沿着继承链向上查找
   └─> 父类的 cache → 父类的 methodLists
   └─> 一直查到 NSObject

5. 动态方法解析
   └─> +resolveInstanceMethod: 或 +resolveClassMethod:
   └─> 可以动态添加方法实现

6. 快速消息转发
   └─> -forwardingTargetForSelector:
   └─> 可以转发给其他对象

7. 完整消息转发
   └─> -methodSignatureForSelector:
   └─> -forwardInvocation:

8. 找不到方法：崩溃
   └─> doesNotRecognizeSelector:
   └─> 抛出 NSInvalidArgumentException
```

**代码示例**：

```objective-c
// 动态方法解析
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    if (sel == @selector(resolveMethod)) {
        // 动态添加方法
        class_addMethod([self class], sel, (IMP)dynamicMethod, "v@:");
        return YES;
    }
    return [super resolveInstanceMethod:sel];
}

void dynamicMethod(id self, SEL _cmd) {
    NSLog(@"动态添加的方法");
}
```

### 2.4 消息转发机制

#### 消息转发三个阶段

```
阶段1：动态方法解析
  +resolveInstanceMethod:
  +resolveClassMethod:
        ↓ 返回 NO 或未实现
阶段2：快速消息转发
  -forwardingTargetForSelector:
        ↓ 返回 nil
阶段3：完整消息转发
  -methodSignatureForSelector:
  -forwardInvocation:
```

#### 完整代码示例

**准备代码**：

```objective-c
// TestObj.h
@interface TestObj : NSObject
- (void)resolveMethod;
@end

// TestObj.m
@implementation TestObj
- (void)resolveMethod {
    NSLog(@"TestObj 执行了方法");
}
@end
```

**阶段1：动态方法解析**

```objective-c
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    if (sel == @selector(resolveMethod)) {
        // 动态添加方法
        class_addMethod([self class],
                       sel,
                       (IMP)dynamicResolveMethod,
                       "v@:");
        return YES;
    }
    return [super resolveInstanceMethod:sel];
}

void dynamicResolveMethod(id self, SEL _cmd) {
    NSLog(@"动态添加的方法实现");
}
```

**阶段2：快速消息转发**

```objective-c
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    return NO; // 不处理，进入下一阶段
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    if (aSelector == @selector(resolveMethod)) {
        return [TestObj new]; // 转发给 TestObj
    }
    return [super forwardingTargetForSelector:aSelector];
}
```

**阶段3：完整消息转发**

```objective-c
- (id)forwardingTargetForSelector:(SEL)aSelector {
    return nil; // 不处理，进入下一阶段
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    if (aSelector == @selector(resolveMethod)) {
        return [NSMethodSignature signatureWithObjCTypes:"v@:"];
    }
    return [super methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    if (class_respondsToSelector([TestObj class], @selector(resolveMethod))) {
        [anInvocation invokeWithTarget:[TestObj new]];
    } else {
        [super forwardInvocation:anInvocation];
    }
}
```

**使用场景**：防止崩溃、实现多重继承、动态代理

### 2.5 Category 原理

#### Category vs Extension

| 特性 | Category | Extension |
|------|----------|-----------|
| **编译时机** | 运行时动态添加 | 编译期决定 |
| **添加方法** | ✅ 可以 | ✅ 可以 |
| **添加属性** | ❌ 不能添加实例变量 | ✅ 可以 |
| **声明位置** | 单独文件 | 类的 .h 文件中 |
| **命名** | 类名+分类名 | 无单独命名 |

#### Category 的数据结构

```c
struct category_t {
    const char *name;                          // 分类名
    classref_t cls;                            // 扩展的类
    struct method_list_t *instanceMethods;     // 实例方法列表
    struct method_list_t *classMethods;        // 类方法列表
    struct protocol_list_t *protocols;         // 协议列表
    struct property_list_t *instanceProperties; // 属性列表
};
```

#### Category 加载时机

```
1. 编译时：
   Category 被编译成 category_t 结构体
   └─> 包含方法列表、属性列表、协议列表

2. 运行时：
   Runtime 通过 _objc_init 初始化
   └─> map_images 加载镜像
   └─> _read_images 读取镜像
   └─> remethodizeClass 重新组织类的方法列表
   └─> attachCategories 将 Category 附加到类上

3. 方法合并：
   Category 的方法被添加到类的方法列表前面
   └─> 这就是为什么 Category 方法会"覆盖"原类方法
```

#### 多个 Category 同名方法调用顺序

**决定因素**：Build Phases → Compile Sources 中的文件顺序

```
 Compile Sources:
 ├─ A.m (Category1)
 ├─ B.m (Category2)
 └─ C.m (Category3)

调用顺序：C3 → C2 → C1 → 原类方法
```

**注意**：不是真正的覆盖，而是方法在列表前面的先被找到。

#### Category 为什么不能添加实例变量？

**原因**：
1. 实例变量的内存布局在编译时已确定
2. 运行时添加会破坏内存布局
3. Category 是动态加载的，此时实例内存已分配

**解决方案**：关联对象

#### 关联对象实现

```objective-c
// static key
static const void kAssociatedKey = &kAssociatedKey;

// setter
- (void)setName:(NSString *)name {
    objc_setAssociatedObject(self,
                            kAssociatedKey,
                            name,
                            OBJC_ASSOCIATION_COPY_NONATOMIC);
}

// getter
- (NSString *)name {
    return objc_getAssociatedObject(self, kAssociatedKey);
}
```

**关联对象存储**：

```
对象 (object)
    │
    └─> AssociationsHashMap
            │
            └─> ObjectAssociationMap
                    │
                    └─> key (void *) → value (objc_object)
```

**内存管理策略**：

| 策略 | 等价属性 |
|------|----------|
| `OBJC_ASSOCIATION_ASSIGN` | weak |
| `OBJC_ASSOCIATION_RETAIN_NONATOMIC` | strong, nonatomic |
| `OBJC_ASSOCIATION_COPY_NONATOMIC` | copy, nonatomic |
| `OBJC_ASSOCIATION_RETAIN` | strong |
| `OBJC_ASSOCIATION_COPY` | copy |

#### Category 中 +load 和 +initialize

| 方法 | 调用时机 | 调用次数 | 是否继承 |
|------|----------|----------|----------|
| **+load** | Runtime 加载类/分类时 | 1 次 | ❌ 不调用父类 |
| **+initialize** | 首次收到消息时 | 1 次 | ✅ 自动调用父类 |

**+load 调用顺序**：
1. 先调用类的 +load（按编译顺序）
2. 再调用 Category 的 +load（按编译顺序）

### 2.6 Method Swizzling

#### 原理

```objective-c
// 交换两个方法的实现
void method_exchangeImplementations(Method m1, Method m2);
```

**本质**：交换两个 Method 结构体中的 IMP 指针

```
交换前：
method1.imp → imp1
method2.imp → imp2

交换后：
method1.imp → imp2
method2.imp → imp1
```

#### 标准实现

```objective-c
+ (void)load {
    // 只执行一次
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];

        // 获取方法
        SEL originalSelector = @selector(viewDidLoad);
        SEL swizzledSelector = @selector(xx_viewDidLoad);

        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

        // 交换实现
        method_exchangeImplementations(originalMethod, swizzledMethod);
    });
}

- (void)xx_viewDidLoad {
    // 调用的是原来的 viewDidLoad（因为已经交换了）
    [self xx_viewDidLoad];

    // 自定义逻辑
    NSLog(@"页面加载统计：%@", NSStringFromClass([self class]));
}
```

#### 注意事项

| 注意点 | 说明 |
|--------|------|
| **在 +load 中执行** | 保证只执行一次，且在类加载时 |
| **使用 dispatch_once** | 防止重复交换 |
| **检查方法是否存在** | 使用 class_addMethod 或 class_getInstanceMethod |
| **命名规范** | 添加前缀避免冲突 |
| **交换类方法** | 使用 class_getClassMethod |

#### Method Swizzling 应用

**1. 页面统计**

```objective-c
@implementation UIViewController (XXStatistics)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];

        SEL originalSelector = @selector(viewDidLoad);
        SEL swizzledSelector = @selector(xx_viewDidLoad);

        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

        method_exchangeImplementations(originalMethod, swizzledMethod);
    });
}

- (void)xx_viewDidLoad {
    [self xx_viewDidLoad];

    // 上报页面访问
    [XXTracker trackView:NSStringFromClass([self class])];
}

@end
```

**2. 数组越界防护**

```objective-c
@implementation NSArray (XXSafe)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 类簇的真实类名
        Class arrayClass = NSClassFromString(@"__NSArrayI");

        SEL originalSelector = @selector(objectAtIndex:);
        SEL swizzledSelector = @selector(xx_objectAtIndex:);

        Method originalMethod = class_getInstanceMethod(arrayClass, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(arrayClass, swizzledSelector);

        method_exchangeImplementations(originalMethod, swizzledMethod);
    });
}

- (id)xx_objectAtIndex:(NSUInteger)index {
    if (index < self.count) {
        return [self xx_objectAtIndex:index];
    } else {
        NSLog(@"数组越界：count=%lu, index=%lu", self.count, index);
        return nil;
    }
}

@end
```

**3. 字典 nil 值处理**

```objective-c
@implementation NSDictionary (XXSafe)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class dictClass = NSClassFromString(@"__NSDictionaryI");

        SEL originalSelector = @selector(initWithObjects:forKeys:count:);
        SEL swizzledSelector = @selector(xx_initWithObjects:forKeys:count:);

        Method originalMethod = class_getInstanceMethod(dictClass, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(dictClass, swizzledSelector);

        method_exchangeImplementations(originalMethod, swizzledMethod);
    });
}

- (instancetype)xx_initWithObjects:(const id [])objects
                          forKeys:(const id<NSCopying> [])keys
                            count:(NSUInteger)cnt {
    id validObjects[cnt];
    id<NSCopying> validKeys[cnt];
    NSUInteger validCount = 0;

    for (NSUInteger i = 0; i < cnt; i++) {
        if (objects[i] && keys[i]) {
            validObjects[validCount] = objects[i];
            validKeys[validCount] = keys[i];
            validCount++;
        }
    }

    return [self xx_initWithObjects:validObjects
                            forKeys:validKeys
                              count:validCount];
}

@end
```

### 2.7 方法缓存

#### 为什么需要缓存？

消息发送流程需要遍历方法列表，时间复杂度 O(n)。使用缓存可以将常用方法的查找降低到 O(1)。

#### cache 的数据结构

```c
struct objc_cache {
    unsigned int mask;    // 容量 - 1
    unsigned int occupied; // 已使用数量
    cache_entry *buckets; // 哈希表
};

typedef struct {
    SEL name;    // 方法名作为 key
    void *imp;   // IMP 作为 value
} cache_entry;
```

#### 缓存查找流程

```
1. 计算 hash 值：hash = SEL & mask
2. 查找 buckets[hash]
3. 如果 SEL 匹配，返回 IMP
4. 如果不匹配，线性探测下一个位置
5. 找到或遍历完整个表
```

#### 缓存更新

```
找到 IMP 后：
1. 将方法加入缓存（可能淘汰旧方法）
2. 下次直接从缓存获取
```

---

## 3. 面试题 & 常见问题

### 3.1 面试高频题

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **什么是 Runtime？** | OC 的运行时系统，实现动态特性，核心是消息发送机制 | ⭐ |
| **objc_msgSend 的流程？** | 缓存 → 方法列表 → 继承链 → 动态解析 → 消息转发 | ⭐⭐⭐⭐⭐ |
| **消息转发三个阶段？** | 动态方法解析 → 快速转发 → 完整转发 | ⭐⭐⭐⭐ |
| **isa 的指向？** | 实例→类→元类→根元类→根元类自身 | ⭐⭐⭐ |
| **类方法和实例方法存储位置？** | 实例方法在类对象，类方法在元类 | ⭐⭐⭐ |
| **[self class] vs [super class]？** | 都返回当前类，super 只是告诉编译器从父类查找 | ⭐⭐⭐⭐ |
| **Category 为什么不能添加实例变量？** | 内存布局在编译时确定，运行时添加会破坏布局 | ⭐⭐⭐ |
| **多个 Category 同名方法调用顺序？** | 取决于 Compile Sources 顺序，后面的先调用 | ⭐⭐ |
| **+load 和 +initialize 的区别？** | load 在加载时调用一次，initialize 在首次使用时调用 | ⭐⭐⭐ |
| **Method Swizzling 的原理？** | 交换两个方法的 IMP 指针 | ⭐⭐⭐ |
| **方法缓存的作用？** | 将 O(n) 的查找降低到 O(1) | ⭐⭐ |
| **isKindOfClass vs isMemberOfClass？** | isKindOfClass 判断是否是类或子类，isMember 只判断精确匹配 | ⭐⭐ |
| **如何实现动态方法添加？** | class_addMethod + resolveInstanceMethod | ⭐⭐⭐ |
| **关联对象的存储位置？** | 全局的 AssociationsHashMap | ⭐⭐ |
| **KVO 的底层实现？** | 动态生成子类，重写 setter 方法 | ⭐⭐⭐ |

### 3.2 经典面试题

#### Q1: [self class] vs [super class]

```objective-c
@implementation Son : Father
- (instancetype)init {
    self = [super init];
    if (self) {
        NSLog(@"%@", NSStringFromClass([self class]));   // Son
        NSLog(@"%@", NSStringFromClass([super class])); // Son
    }
    return self;
}
@end
```

**答案**：都输出 `Son`

**解析**：
- `[self class]` → `objc_msgSend(self, @selector(class))`
- `[super class]` → `objc_msgSendSuper({self, [Father class]}, @selector(class))`
- **消息接收者都是 self**，super 只是告诉编译器从父类开始查找
- class 方法的实现最终还是返回 self 的类

#### Q2: isKindOfClass vs isMemberOfClass

```objective-c
BOOL res1 = [(id)[NSObject class] isKindOfClass:[NSObject class]]; // YES
BOOL res2 = [(id)[NSObject class] isMemberOfClass:[NSObject class]]; // NO
BOOL res3 = [[NSObject new] isKindOfClass:[NSObject class]]; // YES
BOOL res4 = [[NSObject new] isMemberOfClass:[NSObject class]]; // YES
```

**解析**：
- `isKindOfClass`：判断是否是类或子类的实例
- `isMemberOfClass`：判断是否是精确匹配的类
- `[NSObject class]` 是类对象，是元类的实例
- `[[NSObject new]` 是实例对象，是 NSObject 类的实例

#### Q3: Category +load 调用顺序

```objective-c
// MyClass.m
@implementation MyClass
+ (void)load {
    NSLog(@"MyClass +load");
}
@end

// MyClass+Category1.m
@implementation MyClass (Category1)
+ (void)load {
    NSLog(@"Category1 +load");
}
@end

// MyClass+Category2.m
@implementation MyClass (Category2)
+ (void)load {
    NSLog(@"Category2 +load");
}
@end
```

**输出顺序**（假设 Compile Sources 顺序为 Category1 → Category2）：
```
MyClass +load
Category1 +load
Category2 +load
```

**规则**：
1. 先调用类的 +load
2. 再按 Compile Sources 顺序调用 Category 的 +load

#### Q4: 关联对象的内存管理

```objective-c
@property (nonatomic, strong) NSString *name;

- (void)setName:(NSString *)name {
    objc_setAssociatedObject(self,
                            @selector(name),
                            name,
                            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
```

**为什么用 @selector(name) 作为 key？**
- 保证 key 的唯一性
- 避免声明额外的 static 变量
- 使用 getter 的 SEL 作为 key 是常见做法

---

## 4. 实战应用

### 4.1 页面埋点统计

**完整实现**：

```objective-c
@implementation UIViewController (XXTracker)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzle:@selector(viewDidLoad)
            with:@selector(xx_viewDidLoad)];

        [self swizzle:@selector(viewDidAppear:)
            with:@selector(xx_viewDidAppear:)];
    });
}

+ (void)swizzle:(SEL)originalSelector with:(SEL)swizzledSelector {
    Class class = [self class];

    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

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
}

- (void)xx_viewDidLoad {
    [self xx_viewDidLoad];
    [XXTracker trackView:NSStringFromClass([self class]) event:@"viewDidLoad"];
}

- (void)xx_viewDidAppear:(BOOL)animated {
    [self xx_viewDidAppear:animated];
    [XXTracker trackView:NSStringFromClass([self class]) event:@"viewDidAppear"];
}

@end
```

### 4.2 防止数组/字典崩溃

**支持的类**：

| 类 | 真实类名 |
|------|----------|
| NSArray | `__NSArrayI` |
| NSMutableArray | `__NSArrayM` |
| NSDictionary | `__NSDictionaryI` |
| NSMutableDictionary | `__NSDictionaryM` |

**实现代码**：

```objective-c
@implementation NSArray (XXSafe)

+ (void)load {
    [self swizzleClass:NSClassFromString(@"__NSArrayI")
          original:@selector(objectAtIndex:)
          swizzled:@selector(xx_objectAtIndex:)];
}

- (id)xx_objectAtIndex:(NSUInteger)index {
    if (index >= self.count) {
        NSLog(@"⚠️ 数组越界崩溃已拦截");
        return nil;
    }
    return [self xx_objectAtIndex:index];
}

@end
```

### 4.3 字典转模型（ORM）

**实现思路**：

```objective-c
@implementation NSObject (XXModel)

+ (instancetype)xx_modelWithDictionary:(NSDictionary *)dict {
    id model = [[self alloc] init];

    unsigned int count = 0;
    objc_property_t *properties = class_copyPropertyList([self class], &count);

    for (unsigned int i = 0; i < count; i++) {
        objc_property_t property = properties[i];
        const char *name = property_getName(property);
        NSString *key = [NSString stringWithUTF8String:name];

        id value = dict[key];
        if (value) {
            [model setValue:value forKey:key];
        }
    }

    free(properties);
    return model;
}

@end

// 使用
Person *person = [Person xx_modelWithDictionary:@{
    @"name": @"Tom",
    @"age": @18
}];
```

**注意**：
- 需要处理嵌套模型
- 需要处理类型转换
- 需要处理 key 映射

### 4.4 动态创建类

**应用场景**：KVO、动态代理、热修复

```objective-c
// 创建类
Class subclass = objc_allocateClassPair([NSObject class], "XXDynamicSubclass", 0);

// 添加方法
void dynamicMethod(id self, SEL _cmd) {
    NSLog(@"动态方法");
}

class_addMethod(subclass,
               @selector(dynamicMethod),
               (IMP)dynamicMethod,
               "v@:");

// 注册类
objc_registerClassPair(subclass);

// 创建实例
id instance = [[subclass alloc] init];
[instance performSelector:@selector(dynamicMethod)];

// 释放（iOS 8+ 不需要手动释放）
// objc_disposeClassPair(subclass);
```

### 4.5 自动归档解档

```objective-c
@implementation NSObject (XXArchive)

- (void)xx_encodeWithCoder:(NSCoder *)coder {
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList([self class], &count);

    for (unsigned int i = 0; i < count; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        NSString *key = [NSString stringWithUTF8String:name];
        id value = [self valueForKey:key];
        [coder encodeObject:value forKey:key];
    }

    free(ivars);
}

- (instancetype)xx_initWithCoder:(NSCoder *)coder {
    self = [self init];
    if (self) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList([self class], &count);

        for (unsigned int i = 0; i < count; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            NSString *key = [NSString stringWithUTF8String:name];
            id value = [coder decodeObjectForKey:key];
            [self setValue:value forKey:key];
        }

        free(ivars);
    }
    return self;
}

@end
```

---

## 5. 参考资料

### 官方文档
- [Objective-C Runtime Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/)
- [Objective-C Runtime Reference](https://developer.apple.com/library/archive/documentation/Cocoa/Reference/ObjCRuntimeRef/)

### 优质文章
- [深入理解 Runtime](https://blog.ibireme.com/2015/05/18/runloop/) (ibireme)
- [Objective-C Runtime 运行时之一：类与对象](https://www.jianshu.com/p/5f62843cf826)
- [Runtime 详解](https://www.jianshu.com/p/46ddce14843b)

### 开源项目
- [MJExtension](https://github.com/CoderMJLee/MJExtension) - 字典转模型
- [YYModel](https://github.com/ibireme/YYModel) - 高性能模型转换框架

### 相关 Demo
- [大厂常问iOS面试题--Runtime篇](https://github.com/LGBamboo/iOS-article.02/blob/main/%E5%A4%A7%E5%8E%82%E5%B8%B8%E9%97%AEiOS%E9%9D%A2%E8%AF%95%E9%A2%98--Runtime%E7%AF%87.md)

---

**最后更新**：2026-04-03
**状态**：✅ 已完成
