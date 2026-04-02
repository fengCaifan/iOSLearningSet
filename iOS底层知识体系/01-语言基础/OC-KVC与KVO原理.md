# OC KVC 与 KVO 原理

> 一句话总结：KVC 是通过**字符串 key** 间接访问属性的机制，底层按固定顺序搜索 accessor / 成员变量；KVO 基于 **isa-swizzling** 动态生成子类并重写 setter，实现属性变化的自动通知。

---

## 一、KVC（Key-Value Coding）

### 1.1 什么是 KVC

KVC 是 NSKeyValueCoding 协议定义的一套机制，允许通过**字符串 key** 来间接读写对象的属性，而不需要直接调用 getter / setter。

核心 API：

```objc
// 取值
- (id)valueForKey:(NSString *)key;
- (id)valueForKeyPath:(NSString *)keyPath;  // 支持嵌套路径，如 @"address.city"

// 赋值
- (void)setValue:(id)value forKey:(NSString *)key;
- (void)setValue:(id)value forKeyPath:(NSString *)keyPath;
```

KVC 的强大之处在于它可以**访问私有属性**，因为底层直接查找 ivar，不受访问控制限制：

```objc
// 即使 name 是私有属性，KVC 仍然能访问
[person setValue:@"Tom" forKey:@"name"];
NSString *name = [person valueForKey:@"name"];
```

---

### 1.2 KVC 赋值（setValue:forKey:）的搜索路径

调用 `setValue:forKey:` 时，Runtime 按以下顺序查找：

```
setValue:forKey:@"name"
  │
  ├── 1. 按顺序查找 setter 方法：
  │      setName: → _setName: → setIsName:
  │      找到 → 调用 setter，结束
  │
  ├── 2. 没有 setter，检查 accessInstanceVariablesDirectly
  │      返回 NO → 抛出 NSUnknownKeyException
  │      返回 YES → 继续查找成员变量 ↓
  │
  ├── 3. 按顺序查找成员变量：
  │      _name → _isName → name → isName
  │      找到 → 直接赋值，结束
  │
  └── 4. 都没找到 → 调用 setValue:forUndefinedKey:
         默认实现抛出 NSUnknownKeyException
```

> `accessInstanceVariablesDirectly` 默认返回 `YES`，子类可以重写为 `NO` 来禁止直接访问成员变量。

---

### 1.3 KVC 取值（valueForKey:）的搜索路径

调用 `valueForKey:` 时，搜索顺序如下：

```
valueForKey:@"name"
  │
  ├── 1. 按顺序查找 getter 方法：
  │      getName → name → isName → _name
  │      找到 → 调用 getter 并返回值
  │
  ├── 2. 没有 getter，查找集合类方法（NSArray / NSSet 代理）：
  │      countOfName + objectInNameAtIndex: / nameAtIndexes:
  │      → 返回 NSKeyValueArray 代理对象
  │
  ├── 3. 检查 accessInstanceVariablesDirectly
  │      返回 NO → 抛出 NSUnknownKeyException
  │      返回 YES → 继续查找成员变量 ↓
  │
  ├── 4. 按顺序查找成员变量：
  │      _name → _isName → name → isName
  │      找到 → 直接取值并返回
  │
  └── 5. 都没找到 → 调用 valueForUndefinedKey:
         默认实现抛出 NSUnknownKeyException
```

---

### 1.4 KVC 与类型转换

KVC 只能传递 `id` 类型（OC 对象），对于基础数据类型会**自动装箱 / 拆箱**：

```objc
// 赋值：int → NSNumber（自动拆箱后赋给 ivar）
[person setValue:@(18) forKey:@"age"];

// 取值：int → NSNumber（自动装箱后返回）
NSNumber *age = [person valueForKey:@"age"];
```

对于结构体类型，KVC 会自动包装为 `NSValue`：

```objc
[view setValue:[NSValue valueWithCGRect:CGRectMake(0, 0, 100, 100)] forKey:@"frame"];
```

**特殊情况**：对基础数据类型的属性调用 `setValue:nil` 会触发 `setNilValueForKey:`，默认实现抛出 `NSInvalidArgumentException`。可以重写该方法来处理：

```objc
- (void)setNilValueForKey:(NSString *)key {
    if ([key isEqualToString:@"age"]) {
        _age = 0;
    } else {
        [super setNilValueForKey:key];
    }
}
```

---

### 1.5 KVC 集合操作符

KVC 支持通过 keyPath 对集合进行聚合运算：

```objc
NSArray *transactions = @[...]; // 每个元素有 amount 属性

// @avg / @count / @max / @min / @sum
NSNumber *avg = [transactions valueForKeyPath:@"@avg.amount"];
NSNumber *sum = [transactions valueForKeyPath:@"@sum.amount"];
NSNumber *count = [transactions valueForKeyPath:@"@count"];

// @distinctUnionOfObjects / @unionOfObjects
NSArray *distinct = [transactions valueForKeyPath:@"@distinctUnionOfObjects.payee"];
```

---

## 二、KVO（Key-Value Observing）

### 2.1 什么是 KVO

KVO 是基于 KVC 的**属性变化观察机制**，当被观察对象的属性值发生变化时，会自动通知观察者。

核心 API：

```objc
// 添加观察
[person addObserver:self
         forKeyPath:@"name"
            options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
            context:nil];

// 接收通知
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    NSLog(@"old: %@, new: %@", change[NSKeyValueChangeOldKey], change[NSKeyValueChangeNewKey]);
}

// 移除观察（必须在 dealloc 或之前调用，否则 crash）
[person removeObserver:self forKeyPath:@"name"];
```

**options 参数说明**：

| 选项 | 含义 |
|------|------|
| `NSKeyValueObservingOptionNew` | change 字典中包含**新值** |
| `NSKeyValueObservingOptionOld` | change 字典中包含**旧值** |
| `NSKeyValueObservingOptionInitial` | 注册时就**立即触发一次**通知 |
| `NSKeyValueObservingOptionPrior` | 值变化**前后各触发一次**（配合 `willChange` 使用） |

---

### 2.2 KVO 的底层原理：isa-swizzling

KVO 的核心实现机制是 **isa-swizzling**（isa 指针替换）。

当对对象 A 的某个属性添加 KVO 观察时，Runtime 会：

1. **动态创建** A 所属类的一个子类 `NSKVONotifying_A`
2. 将 A 的 **isa 指针**指向这个新子类
3. 在子类中**重写被观察属性的 setter**，在 setter 内部插入通知逻辑

```
添加 KVO 前：
  person.isa → FCFPerson

添加 KVO 后：
  person.isa → NSKVONotifying_FCFPerson（动态子类）
                ├── superclass → FCFPerson
                ├── 重写 setName:（内部调用 willChange / 原 setter / didChange）
                ├── 重写 class（返回 FCFPerson，伪装身份）
                ├── 重写 dealloc（清理 KVO 相关资源）
                └── 重写 _isKVOA（标记自己是 KVO 子类）
```

**重写的 setter 内部实现（伪代码）**：

```objc
// NSKVONotifying_FCFPerson 中自动生成的 setter
- (void)setName:(NSString *)name {
    [self willChangeValueForKey:@"name"];
    [super setName:name];  // 调用原类 FCFPerson 的 setter
    [self didChangeValueForKey:@"name"];
}
```

`didChangeValueForKey:` 内部会触发观察者的 `observeValueForKeyPath:ofObject:change:context:` 回调。

**验证 isa-swizzling**：

```objc
FCFPerson *p1 = [[FCFPerson alloc] init];
FCFPerson *p2 = [[FCFPerson alloc] init];

// 添加 KVO 前
NSLog(@"p1 class: %@", object_getClass(p1)); // FCFPerson
NSLog(@"p2 class: %@", object_getClass(p2)); // FCFPerson

[p1 addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:nil];

// 添加 KVO 后
NSLog(@"p1 class: %@", object_getClass(p1)); // NSKVONotifying_FCFPerson ← isa 被替换
NSLog(@"p2 class: %@", object_getClass(p2)); // FCFPerson（未添加 KVO，不受影响）

// 注意：[p1 class] 仍然返回 FCFPerson，因为 KVO 子类重写了 class 方法做伪装
NSLog(@"p1 [class]: %@", [p1 class]); // FCFPerson
```

> `object_getClass()` 返回真实的 isa 指向，`[obj class]` 返回的是 KVO 子类伪装后的结果。

---

### 2.3 NSKVONotifying_ 子类重写的方法

| 方法 | 作用 |
|------|------|
| **setter**（如 `setName:`） | 在原 setter 前后插入 `willChangeValueForKey:` / `didChangeValueForKey:` 触发通知 |
| **`class`** | 返回原类（如 FCFPerson），对外隐藏 KVO 子类的存在 |
| **`dealloc`** | 做 KVO 相关的清理工作 |
| **`_isKVOA`** | 返回 YES，标识这是一个 KVO 动态生成的子类 |

可以通过 Runtime 验证子类重写了哪些方法：

```objc
unsigned int count;
Method *methods = class_copyMethodList(object_getClass(p1), &count);
for (int i = 0; i < count; i++) {
    NSLog(@"%@", NSStringFromSelector(method_getName(methods[i])));
}
free(methods);
// 输出：setName:, class, dealloc, _isKVOA
```

---

### 2.4 手动触发 KVO

KVO 默认只在通过 **setter 方法**修改属性时触发。如果需要在其他场景手动触发，需要主动调用：

```objc
[self willChangeValueForKey:@"name"];
// 直接修改成员变量或其他操作
_name = @"newValue";
[self didChangeValueForKey:@"name"];
```

也可以通过重写 `automaticallyNotifiesObserversForKey:` 来关闭某个 key 的自动通知，改为手动控制：

```objc
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([key isEqualToString:@"name"]) {
        return NO;  // 关闭 name 的自动 KVO
    }
    return [super automaticallyNotifiesObserversForKey:key];
}

// 需要通知时手动触发
- (void)updateName:(NSString *)name {
    [self willChangeValueForKey:@"name"];
    _name = name;
    [self didChangeValueForKey:@"name"];
}
```

---

### 2.5 KVO 的依赖键

当一个属性的值**依赖于其他属性**时，可以通过 `keyPathsForValuesAffectingXxx` 声明依赖关系，使被依赖的属性变化时也能触发通知：

```objc
// fullName 依赖 firstName 和 lastName
// 当 firstName 或 lastName 变化时，自动触发 fullName 的 KVO 通知
+ (NSSet<NSString *> *)keyPathsForValuesAffectingFullName {
    return [NSSet setWithObjects:@"firstName", @"lastName", nil];
}

- (NSString *)fullName {
    return [NSString stringWithFormat:@"%@ %@", _firstName, _lastName];
}
```

通用写法（使用 `keyPathsForValuesAffectingValueForKey:`）：

```objc
+ (NSSet<NSString *> *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"fullName"]) {
        keyPaths = [keyPaths setByAddingObjectsFromSet:
                    [NSSet setWithObjects:@"firstName", @"lastName", nil]];
    }
    return keyPaths;
}
```

---

### 2.6 KVC 与 KVO 的关系

KVC 的 `setValue:forKey:` 内部会**自动触发 KVO 通知**。即使直接通过 KVC 设置的是一个没有 setter 的成员变量，KVC 也会在赋值前后插入 `willChangeValueForKey:` / `didChangeValueForKey:`，从而触发 KVO。

```objc
// 即使 _name 是直接赋值给 ivar，通过 KVC 调用也会触发 KVO
[person setValue:@"Tom" forKey:@"name"];  // ✅ 触发 KVO
person->_name = @"Tom";                  // ❌ 不触发 KVO（直接修改 ivar）
```

这是因为 KVC 的赋值流程中，即使最终是直接访问 ivar，也会包裹 `willChange` / `didChange` 调用。

---

## 三、关键问题 & 面试题

### Q1：KVO 的底层实现原理？

**答**：KVO 基于 **isa-swizzling** 实现。当对对象添加 KVO 观察时，Runtime 动态创建当前类的子类 `NSKVONotifying_ClassName`，并将对象的 isa 指针指向该子类。子类重写被观察属性的 setter，在 setter 内部调用 `willChangeValueForKey:` 和 `didChangeValueForKey:` 来触发通知。同时重写 `class` 方法返回原类，对外隐藏中间子类的存在。

### Q2：如何手动触发 KVO？

**答**：在修改值前后分别调用 `willChangeValueForKey:` 和 `didChangeValueForKey:`。通常还需要配合重写 `automaticallyNotifiesObserversForKey:` 返回 NO，关闭自动 KVO，避免重复通知。

### Q3：直接修改成员变量会触发 KVO 吗？

**答**：**不会**。KVO 是通过重写 setter 实现的，直接访问成员变量（如 `_name = @"xxx"`）绕过了 setter，自然不会触发 KVO。要触发有两种方式：
- 通过 setter 赋值：`self.name = @"xxx"`
- 手动调用 `willChangeValueForKey:` / `didChangeValueForKey:` 包裹赋值操作

但通过 KVC 的 `setValue:forKey:` 赋值**会触发** KVO，即使最终赋值的是 ivar，因为 KVC 内部会自动调用 `willChange` / `didChange`。

### Q4：KVC 的 valueForUndefinedKey 和 setValue:forUndefinedKey: 的作用？

**答**：当 KVC 按照完整的搜索路径（setter / getter → 成员变量）都找不到对应的 key 时，会分别调用这两个方法。它们的**默认实现是抛出 `NSUnknownKeyException`**。子类可以重写这两个方法来：
- 提供默认值或兜底逻辑
- 做日志记录
- 转发到其他对象

```objc
- (id)valueForUndefinedKey:(NSString *)key {
    NSLog(@"访问了未定义的 key: %@", key);
    return nil;  // 返回默认值，避免 crash
}
```

### Q5：KVO 注册和移除不匹配会怎样？

**答**：
- **只注册不移除**：对象释放时 KVO 子类可能访问已释放的观察者，导致 crash（EXC_BAD_ACCESS）
- **移除多余的**（未注册就移除）：抛出 `NSRangeException`，也会 crash
- **最佳实践**：注册和移除必须**严格配对**，通常在 `dealloc` 中移除

### Q6：KVC 会破坏面向对象的封装性吗？

**答**：会。KVC 可以绑定私有属性和成员变量，绕过了访问控制。这是把双刃剑：
- **优点**：灵活性极高，在字典转模型、UI 框架内部等场景非常有用
- **缺点**：依赖字符串 key，编译期无法检查，拼写错误只能在运行时发现

### Q7：KVO 在多线程下安全吗？

**答**：KVO 的通知是**同步的**，在哪个线程修改属性，就在哪个线程回调 `observeValueForKeyPath:`。如果在子线程修改属性，回调也在子线程，此时做 UI 更新需要手动切回主线程。KVO 本身的注册和移除操作不是线程安全的，多线程场景下需要加锁保护。

---

## 四、实战应用

### 4.1 自定义 KVO 实现（基于 Runtime）

系统 KVO 有几个痛点：需要手动移除观察、回调方法不直观、无法用 Block。可以基于 Runtime 自定义 KVO：

```objc
// NSObject+CustomKVO.h
typedef void(^KVOBlock)(id observer, NSString *keyPath, id oldValue, id newValue);

@interface NSObject (CustomKVO)
- (void)custom_addObserver:(NSObject *)observer
                forKeyPath:(NSString *)keyPath
                     block:(KVOBlock)block;
- (void)custom_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;
@end
```

实现思路：

```
1. 动态创建子类 CustomKVO_ClassName（class_allocateClassPair）
2. 重写 setter（class_addMethod），在新 setter 中：
   a. 获取旧值
   b. 调用原类的 setter（objc_msgSendSuper）
   c. 获取新值
   d. 遍历观察者列表，执行 Block 回调
3. 修改对象的 isa 指向子类（object_setClass）
4. 重写 class 方法，返回原类（伪装）
5. 用关联对象存储观察者列表
```

### 4.2 KVO 在 MVVM 数据绑定中的应用

ViewModel 属性变化时自动更新 View：

```objc
// ViewModel
@interface UserViewModel : NSObject
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *avatarURL;
@end

// ViewController 中绑定
- (void)bindViewModel {
    [self.viewModel addObserver:self
                     forKeyPath:@"displayName"
                        options:NSKeyValueObservingOptionNew
                        context:nil];
    [self.viewModel addObserver:self
                     forKeyPath:@"avatarURL"
                        options:NSKeyValueObservingOptionNew
                        context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"displayName"]) {
        self.nameLabel.text = change[NSKeyValueChangeNewKey];
    } else if ([keyPath isEqualToString:@"avatarURL"]) {
        [self.avatarView loadURL:change[NSKeyValueChangeNewKey]];
    }
}

- (void)dealloc {
    [self.viewModel removeObserver:self forKeyPath:@"displayName"];
    [self.viewModel removeObserver:self forKeyPath:@"avatarURL"];
}
```

### 4.3 FBKVOController 的设计思路

Facebook 开源的 [KVOController](https://github.com/facebookarchive/KVOController) 解决了系统 KVO 的痛点：

```objc
// 使用示例
[self.KVOController observe:self.viewModel
                    keyPath:@"displayName"
                    options:NSKeyValueObservingOptionNew
                      block:^(id observer, id object, NSDictionary *change) {
    // 直接用 Block，无需实现 observeValueForKeyPath:
}];
// 无需手动移除，observer 释放时自动移除
```

核心设计：
- **中间层架构**：FBKVOController 作为中间对象，真正的 observer 是它，而不是调用方
- **关联对象绑定**：通过 Category 将 FBKVOController 实例关联到 observer 上
- **自动移除**：FBKVOController 的 dealloc 中自动移除所有观察，observer 释放时关联对象也释放，触发自动清理
- **线程安全**：内部用 `pthread_mutex` 保护观察者列表
- **去重**：用 `NSMapTable` 存储 keyPath → info 的映射，防止重复注册

```
调用方（observer）
  └── 关联对象持有 FBKVOController
        └── FBKVOController 作为 real observer 注册到被观察对象
              └── 被观察对象属性变化 → 通知 FBKVOController → 执行 Block
```

### 4.4 KVC 在字典转模型中的应用

```objc
// 简单的字典转模型（基于 KVC）
- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        [self setValuesForKeysWithDictionary:dict];
    }
    return self;
}

// 必须重写，防止字典中有模型没有的 key 导致 crash
- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    // 忽略未定义的 key
}
```

> 实际项目中更推荐使用 YYModel、MJExtension 等成熟框架，它们基于 Runtime 遍历属性列表，性能更好且功能更完善。

### 4.5 KVC 访问系统私有属性

```objc
// 修改 UITextField 的 placeholder 颜色
[textField setValue:[UIColor grayColor] forKeyPath:@"placeholderLabel.textColor"];

// 修改 UIPageControl 的指示器图片
[pageControl setValue:dotImage forKeyPath:@"_pageImages"];
[pageControl setValue:currentDotImage forKeyPath:@"_currentPageImages"];
```

> ⚠️ 访问私有 API 存在审核被拒的风险，且 Apple 随时可能修改内部实现导致 crash。生产环境慎用。

---

## 五、知识图谱总结

```
KVC（Key-Value Coding）                      KVO（Key-Value Observing）
├── 本质：通过字符串 key 间接访问属性           ├── 本质：属性变化的观察者模式
├── 赋值搜索路径：                            ├── 底层实现：isa-swizzling
│   setKey: → _setKey: → setIsKey:          │   ├── 动态创建 NSKVONotifying_ 子类
│   → ivar: _key / _isKey / key / isKey     │   ├── 重写 setter（插入 willChange/didChange）
├── 取值搜索路径：                            │   ├── 重写 class（伪装为原类）
│   getKey → key → isKey → _key             │   ├── 重写 dealloc（清理资源）
│   → 集合代理                               │   └── 重写 _isKVOA（标记位）
│   → ivar: _key / _isKey / key / isKey     ├── 手动触发：
├── 类型转换：                                │   willChangeValueForKey: + didChangeValueForKey:
│   基础类型 ↔ NSNumber（自动装拆箱）          ├── 自动通知控制：
│   结构体 ↔ NSValue                         │   automaticallyNotifiesObserversForKey:
├── 异常处理：                                ├── 依赖键：
│   valueForUndefinedKey:                    │   keyPathsForValuesAffectingXxx
│   setValue:forUndefinedKey:                ├── 注意事项：
│   setNilValueForKey:                       │   ├── 注册与移除必须配对
├── 集合操作符：                              │   ├── 通知是同步的（在修改属性的线程）
│   @avg / @sum / @count / @max / @min      │   └── 直接修改 ivar 不触发 KVO
└── 应用：                                   └── 应用：
    ├── 字典转模型                                ├── MVVM 数据绑定
    ├── 访问私有属性                              ├── FBKVOController（自动管理生命周期）
    └── 集合聚合运算                              └── 自定义 KVO（基于 Runtime）

              ↕ 联动 ↕
   KVC setValue:forKey: 会自动触发 KVO
   （即使最终赋值给 ivar，KVC 也会包裹 willChange/didChange）
```

---

## 六、参考资料

- [Apple 官方文档 - Key-Value Coding Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueCoding/)
- [Apple 官方文档 - Key-Value Observing Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueObserving/)
- [Apple 开源 objc4 源码](https://opensource.apple.com/source/objc4/)
- [FBKVOController](https://github.com/facebookarchive/KVOController)
- 《Objective-C 高级编程》
- GNUstep 开源实现（可用来辅助理解 KVC / KVO 实现逻辑）
