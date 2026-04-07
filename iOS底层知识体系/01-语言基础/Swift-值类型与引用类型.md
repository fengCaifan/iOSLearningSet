# Swift-值类型与引用类型

> 一句话总结：**Swift 用 struct/class 区分值语义与引用语义；理解栈堆分布、写时复制与生命周期，决定建模方式与性能。**

---

## 📚 学习地图

- **预计学习时间**：40 分钟
- **前置知识**：基本 Swift 语法
- **学习目标**：值/引用存储差异 → COW → 选型

---

### 6.1 值类型 vs 引用类型

#### 6.1.1 基本区别

| 特性 | 值类型（Struct/Enum） | 引用类型（Class） |
|------|---------------------|------------------|
| **存储位置** | 栈（小对象）或堆（大对象） | 堆 |
| **赋值行为** | 拷贝（值语义） | 引用（引用语义） |
| **线程安全** | 值类型天然线程安全 | 需要考虑线程安全 |
| **内存管理** | 栈自动释放 / ARC（堆） | ARC |
| **性能** | 栈分配快，无需引用计数 | 堆分配慢，需要引用计数 |
| **身份标识** | 无标识（值相等即相同） | 有标识（=== 判断） |
| **继承** | 不支持（通过协议扩展） | 支持 |

**基本示例**：

```swift
// 值类型
struct Point {
    var x: Int
    var y: Int
}

var p1 = Point(x: 10, y: 20)
var p2 = p1         // 拷贝
p2.x = 30
print(p1.x)         // 10（不受影响）

// 引用类型
class Person {
    var name: String
}

var person1 = Person(name: "Tom")
var person2 = person1 // 引用
person2.name = "Jerry"
print(person1.name)   // Jerry（同时改变）
```

#### 6.1.2 底层内存布局

**Class（引用类型）的内存布局**：

```
┌─────────────────────────────────┐
│ HeapObject (堆对象)              │
├─────────────────────────────────┤
│ isa (8 字节)                    │ → 类型元数据
│ refCounts (8 字节)              │ → 强引用/弱引用计数
│ inlineValue (可选)              │ → 小值直接存储
│ ┌─────────────────────────────┐ │
│ │ iVar1 (实例变量)             │ │
│ │ iVar2                        │ │
│ │ ...                          │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘

变量存储的是堆对象的地址（指针）
```

**Struct（值类型）的内存布局**：

```
情况 1：小 Struct（<= 16 字节）
┌──────────────────────────────┐
│ 直接存储在栈上                │
├──────────────────────────────┤
│ [member1][member2][member3]  │
└──────────────────────────────┘

情况 2：大 Struct（> 16 字节）
┌──────────────────────────────┐
│ 存储在堆上，栈上持有指针       │
└──────────────────────────────┘

优化：编译器可能使用"栈提升"（Stack Promotion）
将堆分配的值类型优化为栈分配
```

**协议类型（Protocol）的内存布局 - Existential Container**：

```
┌─────────────────────────────────┐
│ Existential Container (栈上)    │
├─────────────────────────────────┤
│ value buffer (3 个指针大小)     │ → 存储小值或指针
│ vwt (Value Witness Table)        │ → 值操作函数表
│ pwt (Protocol Witness Table)      │ → 协议操作函数表
└─────────────────────────────────┘

如果值超过 buffer 大小，会存储到堆上
```

#### 6.1.3 值类型中包含引用类型

**重要概念**：值类型中的引用类型字段仍持有引用

```swift
struct ImageWrapper {
    let image: UIImage  // UIImage 是 Class（引用类型）
}

var wrapper1 = ImageWrapper(image: UIImage(named: "photo")!)
var wrapper2 = wrapper1  // 拷贝 wrapper，但 image 字段仍指向同一对象

// 内存布局：
// wrapper1.image 和 wrapper2.image 指向同一个 UIImage 对象
```

**性能影响**：

```swift
// ❌ 避免：值类型包含大引用类型
struct HeavyStruct {
    let largeArray: NSArray  // 每次拷贝都需要更新引用计数
    let bigData: NSData
}

// ✅ 推荐：使用 @escaping closure 延迟初始化
struct OptimizedStruct {
    private var _data: NSData?
    var data: NSData {
        mutating get {
            if _data == nil {
                _data = NSData(contentsOf: url!)
            }
            return _data!
        }
    }
}
```

#### 6.1.4 编译器优化

**栈提升（Stack Promotion）**：

```swift
// 优化前：可能分配到堆上
func process() -> SomeStruct {
    var s = SomeStruct()
    s.value = 1
    return s
}

// 优化后：直接在栈上分配
// 编译器分析 s 的生命周期，发现不会逃逸
// 直接在栈上分配，无需堆分配
```

**字符串、数组的优化**：

```swift
// Array 可能直接存储在栈上（小数组）
var smallArray = [1, 2, 3]  // 优化：栈分配

// 大数组或包含引用类型的数组：堆分配
var largeArray = Array<Int>(repeating: 0, count: 10000)
```

#### 6.1.5 如何选择？

**使用 Struct 的场景**（值类型）：

```swift
// 1. 数据模型（无身份标识）
struct User {
    let id: Int
    var name: String
}

// 2. 小型数据（<= 16 字节）
struct CGSize {
    var width: CGFloat
    var height: CGFloat
}

// 3. 需要值语义（拷贝后独立修改）
struct Point {
    var x: Int
    var y: Int
}

// 4. 线程安全场景
struct ThreadSafeCounter {
    private var value = 0
    mutating func increment() {
        value += 1  // 线程安全
    }
}
```

**使用 Class 的场景**（引用类型）：

```swift
// 1. 需要身份标识
class Person {
    let id: UUID  // 每个实例唯一
    var name: String
}

// 2. 需要共享状态
class DatabaseManager {
    var connection: DatabaseConnection  // 共享连接
}

// 3. 需要继承
class Animal {
    func makeSound() { }
}

class Dog: Animal {
    override func makeSound() {
        print("Woof")
    }
}

// 4. 需要引用语义（多处同时修改）
class Document {
    var content: String  // 多处引用，同步更新
}
```

**混合使用**：

```swift
// 引用类型包含值类型
class User {
    var profile: Profile  // Struct，值语义
}

struct Profile {
    var name: String
    var age: Int
}
```


---

### 附：相关面试要点

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **weak 和 unowned 的区别？** | weak 可选自动置 nil，unowned 不可选不置 nil | ⭐⭐⭐⭐ |
| **什么时候用 unowned？** | 对象生命周期一定比当前对象长 | ⭐⭐⭐ |
| **什么是 Copy-on-Write？** | 多个变量共享数据，修改时才拷贝 | ⭐⭐⭐ |
| **Struct 和 Class 如何选择？** | 默认 Struct，需要引用语义或继承时 Class | ⭐⭐⭐ |

---

## 9. 参考资料

### 优质文章
- [YTMemoryLeakDetector iOS内存泄漏检测工具类](https://segmentfault.com/a/1190000012121342)
- [自动检测VC内存泄漏](https://www.jianshu.com/p/870318df8b47)
- [深入探索iOS内存优化](https://juejin.cn/post/6864492188404088846)
- [Mastering Swift's Memory Management: ARC, Weak, Unowned](https://medium.com/@commitstudiogs/mastering-swifts-memory-management-arc-weak-unowned-and-strong-references-74f40f069994)

### 开源项目
- [FBRetainCycleDetector](https://github.com/facebook/FBRetainCycleDetector) - Facebook 循环引用检测工具
- [MLeaksFinder](https://github.com/Tencent/MLeaksFinder) - 腾讯内存泄漏检测工具

---

**最后更新**：2026-04-07
**状态**：✅ 已完成

**Sources:**
- [Mastering Swift's Memory Management: ARC, Weak, Unowned](https://medium.com/@commitstudiogs/mastering-swifts-memory-management-arc-weak-unowned-and-strong-references-74f40f069994)
- [深入探索iOS内存优化](https://juejin.cn/post/6864492188404088846)
- [YTMemoryLeakDetector iOS内存泄漏检测工具类](https://segmentfault.com/a/1190000012121342)
