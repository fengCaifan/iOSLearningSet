# Swift 核心知识点复习文档

> **适用场景**: 面试前快速复习、Swift知识体系梳理
> **涵盖内容**: 值类型与引用类型、协议与泛型、内存管理与ARC、并发模型、方法派发、底层原理
> **复习时间**: 约30-45分钟

---

## 📚 知识体系总览

### P0 核心话题（面试必考）
1. **值类型与引用类型** - Swift的基础类型系统
2. **协议与泛型** - 面向协议编程的核心
3. **内存管理与ARC** - Swift的内存管理机制
4. **并发模型(async/await/Actor)** - 现代Swift并发编程
5. **方法派发机制与VTable** - Swift性能优化的底层原理

### P1 进阶话题（加分项）
1. **Optional底层实现** - 枚举本质与内存优化
2. **闭包捕获机制** - 类实现与循环引用
3. **ARC详细原理** - weak引用与SideTable
4. **String底层实现** - 小字符串优化与Substring
5. **元类型和反射机制** - Mirror与类型信息查询
6. **Codable编解码原理** - 自动序列化机制
7. **属性包装器(Property Wrappers)** - @Published等背后的实现
8. **Lazy属性底层实现** - 延迟存储与线程安全
9. **KeyPath机制** - 类型安全的属性访问
10. **Swift Runtime** - 与ObjC Runtime的对比
11. **defer底层实现** - 延迟执行与资源管理

---

## 🎯 第一部分：值类型与引用类型

### 核心概念对比

| 特性 | 值类型（Struct/Enum） | 引用类型（Class） |
|------|---------------------|------------------|
| **存储位置** | 栈（小对象）或堆（大对象） | 堆 |
| **赋值行为** | 拷贝（值语义） | 引用（引用语义） |
| **线程安全** | 天然线程安全 | 需要考虑线程安全 |
| **内存管理** | 栈自动释放 / ARC（堆） | ARC |
| **性能** | 栈分配快，无需引用计数 | 堆分配慢，需要引用计数 |
| **身份标识** | 无标识（==判断相等） | 有标识（===判断同一性） |
| **继承** | 不支持（可通过协议扩展） | 支持 |

### 代码示例

```swift
// 值类型示例
struct Point {
    var x: Int
    var y: Int
}

var p1 = Point(x: 10, y: 20)
var p2 = p1         // 拷贝
p2.x = 30
print(p1.x)         // 10（不受影响）

// 引用类型示例
class Person {
    var name: String
    init(name: String) {
        self.name = name
    }
}

var person1 = Person(name: "Tom")
var person2 = person1 // 引用，指向同一个对象
person2.name = "Jerry"
print(person1.name)   // "Jerry"（受影响）
```

### Copy-on-Write（写时复制）

**原理**: 多个变量共享同一份数据，只有修改时才拷贝

**支持的类型**: Array、Dictionary、Set等

```swift
var arr1 = [1, 2, 3]
var arr2 = arr1          // 共享数据，不拷贝
arr1.append(4)           // 触发COW，arr1拷贝一份数据再修改
print(arr2)              // [1, 2, 3]（不受影响）
```

### Struct vs Class 选择指南

**优先选择Struct的情况**:
- 数据相对简单，主要用于存储值
- 不需要继承
- 天然线程安全很重要
- 语义上是值而非引用（如坐标、尺寸）

**优先选择Class的情况**:
- 需要继承
- 需要引用语义（多个变量共享状态）
- 需要身份标识（===判断）
- 对象生命周期复杂，需要精确控制

### 面试高频题

**Q: Swift中Array是值类型，为什么修改时不会影响其他引用？**
A: Swift的Array实现了Copy-on-Write机制。多个Array变量可以共享同一份底层数据，只有在修改时才会真正拷贝数据，确保值语义的同时优化性能。

---

## 🎯 第二部分：协议与泛型

### 核心区别

```swift
// 泛型：编译期单态化，静态派发，性能最优
func process<T>(_ value: T) -> T {
    return value  // 编译期为每个T生成专门代码
}

// 协议：运行时见证表，动态派发，灵活性高
protocol Drawable {
    func draw()
}

func render(_ shape: Drawable) {
    shape.draw()  // 运行时通过见证表查找
}
```

**底层实现差异**：
- **泛型**：编译期单态化 → 为每个类型生成专门代码 → 静态派发 → 可内联优化
- **协议**：协议见证表 + 存在容器 → 运行时动态查找 → 灵活支持异构集合

### 性能对比

| 特性 | 泛型 | 协议 |
|------|------|------|
| 派发方式 | 静态派发 | 动态派发 |
| 性能开销 | 最小（可内联） | 中等（间接调用） |
| 灵活性 | 中等 | 高（支持异构集合） |

### 类型擦除

```swift
// 问题：带关联类型的协议不能作为具体类型
protocol Processor {
    associatedtype Output
    func process() -> Output
}

// ❌ let processors: [Processor] = [...]  // 编译错误

// 解决：类型擦除包装器
struct AnyProcessor<Output>: Processor {
    private let _process: () -> Output

    init<P: Processor>(_ processor: P) where P.Output == Output {
        _process = processor.process
    }

    func process() -> Output {
        return _process()
    }
}

// ✅ let processors: [AnyProcessor<Data>] = [...]
```

### 面试速记

**Q: 泛型vs协议本质区别？**
A: **抽象维度**：泛型是类型抽象，协议是行为抽象。**底层实现**：泛型编译期单态化（静态派发），协议运行时见证表（动态派发）。

**Q: 为什么泛型性能更好？**
A: 泛型编译期为每个类型生成专门代码，可内联优化；协议需要运行时见证表查找，有间接调用开销。

**Q: 什么时候用泛型，什么时候用协议？**
A: **泛型**：性能关键、容器类型、算法实现。**协议**：需要多态、定义接口、支持异构集合。

---

## 🎯 第三部分：内存管理与ARC

### ARC 规则

Swift只管理引用类型的内存，值类型由栈自动管理

```swift
class Person {
    var name: String
    init(name: String) {
        self.name = name
    }
}

var person1 = Person(name: "Tom")
var person2 = person1     // 引用计数+1
person1 = nil             // 引用计数-1
// person2仍持有对象，不会被释放
person2 = nil             // 引用计数归零，对象被释放
```

### weak vs unowned

```swift
// weak：弱引用，对象释放后自动置nil
class ViewController {
    weak var delegate: SomeDelegate?
}

// unowned：无主引用，对象释放后不会置nil（类似unsafe_unretained）
class Person {
    unowned var bestFriend: Person
}
```

### 闭包捕获列表

```swift
class MyClass {
    var value = 10
    lazy var closure: () -> Int = {
        // 捕获列表避免循环引用
        [weak self] in
        return self?.value ?? 0
    }
}
```

### Swift vs OC 内存管理

| 特性 | Swift | OC |
|------|-------|-----|
| 管理对象 | 仅引用类型 | 引用类型 |
| 值类型 | 栈自动管理/COW | 手动管理 |
| 闭包捕获 | 显式捕获列表 | 自动捕获 |
| weak/unowned | weak/unowned | weak/unsafe_unretained |

### 面试高频题

**Q: Swift中闭包什么时候会发生循环引用？**
A: 当闭包捕获了self（类实例），而self又持有闭包时形成循环引用。解决方案：使用捕获列表`[weak self]`或`[unowned self]`打破循环。

---

## 🎯 第四部分：并发模型(async/await/Actor)

### async/await基础

```swift
// 异步函数定义
func fetchUserData() async throws -> User {
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}

// 调用
Task {
    let user = try await fetchUserData()
    print(user.name)
}
```

### 结构化并发

```swift
// 并行执行
async let user1 = fetchUser(id: 1)
async let user2 = fetchUser(id: 2)
let users = await (user1, user2)  // 等待两个任务完成

// TaskGroup处理动态任务
await withTaskGroup(of: User.self) { group in
    for id in userIds {
        group.addTask {
            try await fetchUser(id: id)
        }
    }
    for try await user in group {
        print(user.name)
    }
}
```

### Actor数据隔离

```swift
// Actor确保数据访问的线程安全
actor Counter {
    private var value = 0

    func increment() { value += 1 }
    func getValue() -> Int { value }
}

// 使用
let counter = Counter()
await counter.increment()  // 自动序列化访问
```

### Swift并发vs GCD

| 特性 | Swift并发 | GCD |
|------|-----------|-----|
| 语法 | async/await | closure |
| 结构化 | ✅ 结构化 | ❌ 非结构化 |
| 类型安全 | ✅ 编译期检查 | ❌ 运行时错误 |
| 数据竞争 | ✅ Actor隔离 | ❌ 手动同步 |

### 面试速记

**Q: Swift并发相比GCD的优势？**
A: 结构化并发、编译期数据竞争检查、Actor数据隔离、取消自动传播，避免了GCD的回调地狱和非结构化任务管理。

**Q: Actor如何保证线程安全？**
A: Actor通过数据隔离确保内部状态只能通过串行方法访问，编译期保证同一时间只有一个任务能访问Actor的可变状态。

---

## 🎯 第五部分：方法派发机制与VTable

### Swift三种派发机制

```swift
// 1. 静态派发（最快，~1 CPU周期）
struct Point {
    func draw() { }  // 编译期确定，可内联
}

class Calculator {
    final func add() { }  // 强制静态派发
}

// 2. 虚函数表派发（VTable，~3-4 CPU周期）
class Animal {
    func makeSound() { }  // VTable派发
}

class Dog: Animal {
    override func makeSound() { }  // 通过VTable查找
}

// 3. 消息派发（最慢，~10+ CPU周期）
class Person: NSObject {
    @objc dynamic var age: Int = 0  // 强制消息派发
}
```

**性能排序**：静态派发 > VTable派发 > 协议见证表派发 > 消息派发

### VTable内存布局

```swift
class Dog: Animal {
    override func makeSound() { print("Bark") }
    func fetch() { print("Fetching") }
}
```

**Dog对象内存布局**：
```
堆内存:
┌─────────────────┐
│  isa指针        │ → Dog类型元数据
│  成员变量        │
└─────────────────┘

Dog类型元数据:
┌─────────────────────────────────┐
│  VTable:                        │
│  [0] makeSound → Dog_makeSound │ 函数指针
│  [1] move       → Dog_move      │
│  [2] fetch      → Dog_fetch     │
└─────────────────────────────────┘
```

**查找过程**：对象 → isa → VTable → 索引查找 → 函数执行

### @objc的三种情况

```swift
// 1. @objc - 双重派发（Swift用VTable，OC用消息派发）
@objc func normalMethod() { }

// 2. @objc dynamic - 强制消息派发
@objc dynamic var value: Int = 0  // 支持KVO

// 3. final - 强制静态派发
final func optimizedMethod() { }  // 可内联
```

### 核心原则

**派发方式取决于调用类型，不是实现类型**：
```swift
let circle = Circle()
circle.draw()           // ← 静态派发 (struct)

let shape: Drawable = circle
shape.draw()            // ← 协议见证表派发

let rect = Rectangle()
rect.draw()             // ← VTable派发 (class)
```

### 面试速记

**Q: Swift为什么比OC快？**
A: Struct默认静态派发（可内联），Class用VTable派发（比OC消息派发快），只有@objc dynamic才走OC runtime。

**Q: 什么时候需要@objc dynamic？**
A: 需要OC runtime特性时：KVO/KVC、方法交换、Core Animation代理、与OC互操作。

**Q: 协议见证表什么时候用？**
A: 只有用协议类型调用时才用协议见证表派发。具体类型调用：struct静态派发，class用VTable。

---

## 🎯 第六部分：其他底层原理（进阶补充）

### Optional的底层实现

#### 本质：泛型枚举

```swift
// Swift编译器的实际实现
enum Optional<T> {
    case none    // nil
    case some(T) // 有值
}

// String? = Optional<String>
// Int? = Optional<Int>
```

#### 内存布局

```swift
var age: Int? = 25        // 8字节
var name: String? = "Bob" // 16字节
var empty: String? = nil  // 16字节（都是0）
```

**Int?内存布局**：
```
Int? (8字节):
┌────────────────────────────────┐
│  0/1 (1字节) + 值 (7字节)     │ ← 0表示nil，1表示有值
└────────────────────────────────┘
```

**String?内存布局**：
```
String? (16字节):
┌────────────────────────────────┐
│  nil标志 + 15字节内容         │ ← 短字符串直接存储
└────────────────────────────────┘
```

#### 底层优化

```swift
// 小对象优化 - 直接在枚举内存中存储值
var small: Int? = 42

// 大对象 - 存储指针
var large: Data? = Data()
```

**面试要点**：Optional是枚举实现，通过关联值存储数据，小对象有内存优化。

### 闭包的捕获机制

#### 闭包的底层实现：编译成类

```swift
func makeIncrementer() -> () -> Int {
    var count = 0
    return {
        count += 1
        return count
    }
}
```

**编译器生成的等价类**：
```swift
class IncrementerBox {
    var count: Int = 0

    func increment() -> Int {
        count += 1
        return count
    }
}
```

#### 闭包的内存结构

```swift
struct Closure {
    let function_ptr: FunctionPointer      // 函数地址
    let captured_context: UnsafeRawPointer // 捕获的上下文
}
```

#### 捕获列表的作用

```swift
class Person {
    var name: String

    // ❌ 强引用self，可能导致循环引用
    func makeClosure() -> () -> String {
        return {
            return "Hello, \(self.name)"
        }
    }

    // ✅ 弱引用self，避免循环引用
    func makeSafeClosure() -> () -> String {
        return { [weak self] in
            return "Hello, \(self?.name ?? "Unknown")"
        }
    }
}
```

#### 闭包性能优化

```swift
// 不捕获变量 - 类似函数指针，性能最优
let simpleClosure = { print("Hello") }

// 捕获变量 - 需要分配堆内存
var count = 0
let capturingClosure = { count += 1 }
```

**面试要点**：闭包编译为类实例，捕获变量成为成员变量，有捕获列表避免循环引用。

### ARC的详细实现

#### 引用计数的存储位置

```swift
class Person {
    var name: String
    var age: Int
}
```

**对象内存布局**：
```
Person对象 (堆内存):
┌────────────────────────────────┐
│  isa指针 (8字节)               │
│  引用计数 (8字节)              │ ← ARC信息
│  成员变量...                   │
└────────────────────────────────┘
```

#### weak引用的底层实现

```swift
class Person {
    weak var friend: Person?
}
```

**weak引用结构**：
```
weak引用 → SideTable → 实际对象
```

**SideTable结构**：
```
SideTable:
├─ weak_table (哈希表)      ← 存储所有weak引用
├─ ref_count (引用计数)
└─ weak_count (弱引用计数)  ← 记录有多少weak引用
```

**关键点**：
- weak引用通过SideTable间接访问，性能开销比strong引用大
- 对象释放时，自动将所有weak引用置nil
- weak引用不影响对象的引用计数

#### ARC性能优化

```swift
// 1. 自动池优化
autoreleasepool {
    let temp = Person(name: "Temp", age: 0)
    // 使用temp
}  // 统一释放，避免频繁retain/release

// 2. 方法返回值优化
func createPerson() -> Person {
    let person = Person(name: "New", age: 0)
    return person  // 编译器优化，减少retain/release
}
```

**面试要点**：strong引用直接访问对象，weak通过SideTable间接访问，weak不影响引用计数但性能开销更大。

### String的底层实现

#### Small String Optimization

```swift
let short = "Hello"        // ≤15字符
let long = "A very long string..."  // >15字符
```

**短字符串布局（≤15字符）**：
```
String (16字节):
┌────────────────────────────────┐
│  长度 + 标志位 (1字节)         │
│  字符内容 (15字节)             │ ← 直接内联存储，避免堆分配
└────────────────────────────────┘
```

**长字符串布局（>15字符）**：
```
String (16字节):
┌────────────────────────────────┐
│  指针 (8字节)                  │ ← 指向堆内存
│  长度 + 容量 (8字节)          │
└────────────────────────────────┘
         ↓
┌────────────────────────────────┐
│  堆内存中的实际字符数据         │
└────────────────────────────────┘
```

#### Substring的内存共享

```swift
let original = "Hello, World!"
let substring = original.dropFirst(7)  // "World!"
```

**Substring结构**：
```
Substring:
┌────────────────────────────────┐
│  start_index                   │
│  end_index                     │
│  base_string指针               │ ← 指向原始String
└────────────────────────────────┘
```

**关键点**：Substring与原String共享内存，修改时触发Copy-on-Write。

#### 性能对比

```swift
// 字符串拼接性能
var result = ""
for i in 0..<100 {
    result += "test"  // 每次都创建新String，性能差
}

// 推荐：使用数组+join
var parts: [String] = []
for i in 0..<100 {
    parts.append("test")
}
let result = parts.joined()  // 性能好
```

**面试要点**：String使用小字符串优化（≤15字符内联存储），Substring共享原String内存，修改时触发COW。

### 底层原理面试总结

**Optional本质**：泛型枚举，通过关联值存储，小对象内存优化

**闭包本质**：编译为类实例，捕获变量成为成员，捕获列表避免循环引用

**ARC本质**：strong直接访问+引用计数，weak通过SideTable间接访问，不影响引用计数

**String本质**：≤15字符内联存储，Substring共享原String内存，修改时COW

---

## 🎯 第七部分：元类型和反射机制

### 元类型基础

#### .Type 和 .self

```swift
// 基础类型 vs 元类型
class Person {
    var name: String
    init(name: String) {
        self.name = name
    }
}

// Person 是类型
let personType: Person.Type = Person.self
// personType 是元类型（描述类型的类型）

// 实例类型
let person: Person = Person(name: "Tom")
// person.self 返回实例本身
let samePerson = person.self  // Person类型

// 类型元类型
let personMetaType: Person.Type = Person.self
// anyClass 类型（等价于 AnyObject.Type）
let anyClass: AnyClass = Person.self
```

#### 元类型的继承关系

```swift
// 元类型继承链
class Animal {}
class Dog: Animal {}

// 元类型转换
let dogType: Dog.Type = Dog.self
let animalType: Animal.Type = dogType as Animal.Type  // ✅ 向上转换

// 使用元类型创建实例
let dog = dogType.init()  // 等价于 Dog()
```

### Mirror 反射机制

#### 基础使用

```swift
struct Person {
    let name: String
    var age: Int
    private let secret: String = "private"
}

let person = Person(name: "Alice", age: 30)

// 创建Mirror
let mirror = Mirror(reflecting: person)

// 遍历属性
for child in mirror.children {
    print("Label: \(child.label ?? "无标签"), Value: \(child.value)")
}
// 输出:
// Label: name, Value: Alice
// Label: age, Value: 30
```

#### Mirror的底层结构

```swift
// Mirror的结构
struct Mirror {
    let children: Children  // 属性集合
    let displayStyle: DisplayStyle?  // 显示风格
    let subjectType: Any.Type  // 被反射的类型

    enumDisplayStyle {
        case struct, class, enum, tuple, optional, collection
        // ...更多显示风格
    }
}
```

#### 反射的底层实现原理

```swift
// 伪代码：Mirror的底层实现过程
func createMirror(of value: Any) -> Mirror {
    let type = type(of: value)

    // 1. 获取类型的元数据
    let metadata = swift_getTypeMetadata(type)

    // 2. 根据类型信息创建反射
    switch metadata.kind {
    case .struct:
        return reflectStruct(value, metadata)
    case .class:
        return reflectClass(value, metadata)
    case .enum:
        return reflectEnum(value, metadata)
    // ...其他类型
    }
}
```

### 类型信息的存储结构

#### Swift类型元数据

```swift
// Swift运行时的类型元数据结构（简化版）
struct TypeMetadata {
    let kind: TypeKind  // 类型种类
    let size: Int       // 类型大小
    let alignment: Int  // 内存对齐
    let stride: Int     // 步长
    let numFields: Int  // 属性数量
    let fields: FieldDescriptor[]  // 属性描述符
}

enum TypeKind {
    case struct, class, enum, tuple, optional, etc.
}
```

### 实际应用场景

```swift
// 1. JSON序列化（不使用Codable）
func toJSON(_ object: Any) -> String {
    let mirror = Mirror(reflecting: object)
    var json = "{"

    for (index, child) in mirror.children.enumerated() {
        if let label = child.label {
            json += "\"\(label)\": \"\(child.value)\""
            if index < mirror.children.count - 1 {
                json += ", "
            }
        }
    }

    json += "}"
    return json
}

// 2. 对象比较
func equal<T>(_ lhs: T, _ rhs: T) -> Bool {
    let mirror1 = Mirror(reflecting: lhs)
    let mirror2 = Mirror(reflecting: rhs)

    guard mirror1.children.count == mirror2.children.count else {
        return false
    }

    for (child1, child2) in zip(mirror1.children, mirror2.children) {
        // 简化的比较逻辑
        if String(describing: child1.value) != String(describing: child2.value) {
            return false
        }
    }

    return true
}

// 3. 调试输出
func debugPrint(_ object: Any) {
    let mirror = Mirror(reflecting: object)
    print("Type: \(mirror.subjectType)")
    print("Children count: \(mirror.children.count)")

    for child in mirror.children {
        print("  \(child.label ?? "无名"): \(child.value)")
    }
}
```

### 性能注意事项

```swift
// ❌ 避免在性能关键路径使用反射
struct SlowPerformance {
    func process<T>(_ item: T) {
        let mirror = Mirror(reflecting: item)
        // 反射有性能开销
    }
}

// ✅ 使用泛型和协议约束
struct FastPerformance<T: Encodable> {
    func process(_ item: T) {
        // 编译期确定，无运行时开销
    }
}
```

### 面试高频题

**Q: .Type和.self的区别是什么？**
A: `.self`是表达式，返回值本身或类型本身。`.Type`是元类型，用于存储类型信息。`Person.self`返回Person类型，类型是`Person.Type`（元类型）。元类型是"类型的类型"，用于运行时类型操作。

**Q: Mirror反射的底层实现原理是什么？**
A: Mirror通过Swift运行时获取类型元数据，包括类型种类、属性数量、属性偏移量等信息。遍历属性时，根据元数据中的字段描述符逐个读取属性值。反射涉及运行时类型查找，有性能开销。

**Q: 为什么反射有性能开销？**
A: 反射需要在运行时动态获取类型信息，涉及元数据查找、间接访问、类型转换等操作，这些都无法在编译期优化。相比之下，直接访问属性是编译期确定的，性能更优。

---

## 🎯 第八部分：Codable编解码原理

### Codable协议本质

```swift
// Codable是Encodable和Decodable的组合类型
typealias Codable = Encodable & Decodable

// 编码协议
protocol Encodable {
    func encode(to encoder: Encoder) throws
}

// 解码协议
protocol Decodable {
    init(from decoder: Decoder) throws
}
```

### 自动合成的实现原理

#### 编译器自动生成代码

```swift
// 原始代码
struct Person: Codable {
    let name: String
    let age: Int
}

// 编译器自动生成的等价代码（伪代码）
extension Person {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(age, forKey: .age)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        age = try container.decode(Int.self, forKey: .age)
    }
}

// 自动生成的CodingKeys
extension Person {
    enum CodingKeys: String, CodingKey {
        case name = "name"
        case age = "age"
    }
}
```

#### CodingKeys的作用

```swift
struct Person: Codable {
    let firstName: String
    let lastName: String

    // 自定义JSON键名
    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        // 不包含的属性不会被编码/解码
    }

    let ignored: String  // 没有在CodingKeys中，会被忽略
}
```

### JSON解析的性能优化

#### 底层数据流

```swift
// JSON解析流程
let jsonData = """
{
    "name": "Alice",
    "age": 30
}
""".data(using: .utf8)!

// 1. JSON解析为中间表示
let decoder = JSONDecoder()
let person = try decoder.decode(Person.self, from: jsonData)

// 内部流程：
// jsonData → 解析为JSON值 → 匹配CodingKeys → 类型转换 → 创建实例
```

#### 性能优化策略

```swift
// 1. 使用Date的ISO8601格式（最快）
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

// 2. 避免嵌套结构过深
struct BadDesign {
    let level1: Level1
}
struct Level1 {
    let level2: Level2
}
// ...层层嵌套会影响性能

// 3. 使用基础类型而非自定义类型
struct GoodDesign {
    let id: String    // ✅ 基础类型解析快
}
struct BadDesign {
    let id: CustomID  // ❌ 自定义类型需要额外解析
}
```

### 自定义编解码策略

```swift
// 1. 自定义格式化
struct Person: Codable {
    let birthDate: Date

    enum CodingKeys: String, CodingKey {
        case birthDate = "birth_date"
    }

    // 自定义编码
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: birthDate)

        try container.encode(dateString, forKey: .birthDate)
    }

    // 自定义解码
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let dateString = try container.decode(String.self, forKey: .birthDate)

        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .birthDate,
                in: container,
                debugDescription: "Date string is invalid"
            )
        }

        self.birthDate = date
    }
}

// 2. 容器类型处理
struct Group: Codable {
    let members: [Person]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 自定义数组解析逻辑
        let membersArray = try container.decode([Person].self, forKey: .members)
        members = membersArray.filter { $0.age >= 18 }  // 只保留成年人
    }
}
```

### 常见错误处理

```swift
// 错误类型
enum DecodingError: Error {
    case typeMismatch(type: Any.Type, context: Context)
    case valueNotFound(type: Any.Type, context: Context)
    case keyNotFound(key: CodingKey, context: Context)
    case dataCorrupted(context: Context)
}

// 错误处理示例
func safeDecode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
    do {
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    } catch DecodingError.keyNotFound(let key, let context) {
        print("Missing key: \(key.stringValue)")
        print("Coding path: \(context.codingPath)")
        return nil
    } catch DecodingError.typeMismatch(let type, let context) {
        print("Type mismatch for \(type)")
        print("Coding path: \(context.codingPath)")
        return nil
    } catch {
        print("Other error: \(error)")
        return nil
    }
}
```

### 面试高频题

**Q: Codable的自动合成是如何实现的？**
A: 编译器为遵循Codable的类型自动生成`encode(to:)`和`init(from:)`方法。通过反射机制获取所有存储属性，生成对应的CodingKeys枚举，在编码/解码时逐个处理属性。这个过程在编译期完成，零运行时开销。

**Q: 如何优化Codable的JSON解析性能？**
A: 1) 使用ISO8601DateFormatter等内置策略；2) 避免过深的嵌套结构；3) 优先使用基础类型而非自定义类型；4) 合理设计CodingKeys避免不必要的字段解析；5) 考虑使用Codable之外的库如CodablePlus进行优化。

**Q:什么时候需要自定义Codable实现？**
A: 1) JSON键名与属性名不一致且无法通过CodingKeys解决；2) 需要特殊的格式转换（如日期、自定义类型）；3) 需要数据验证或过滤；4) 需要处理可选值或默认值；5) 性能敏感场景需要优化解析逻辑。

---

## 🎯 第九部分：属性包装器

### 底层实现原理

```swift
// Property Wrapper在编译期的转换
@propertyWrapper
struct TwelveOrLess {
    private var number: Int

    var wrappedValue: Int {
        get { return number }
        set { number = min(newValue, 12) }
    }
}

struct Rectangle {
    @TwelveOrLess var height: Int
}

// 编译器转换后的等价代码
struct Rectangle {
    private var _height = TwelveOrLess(wrappedValue: 0)

    var height: Int {
        get { _height.wrappedValue }
        set { _height.wrappedValue = newValue }
    }

    var $height: TwelveOrLess {
        get { _height }
    }
}
```

**内存布局**：包装器存储属性（_前缀）+ 计算属性访问 + 投射值（$语法）

### SwiftUI中的应用

```swift
// @State的简化实现
@propertyWrapper
struct State<Value> {
    private var _value: Value
    private var updater: ((Value) -> Void)?

    var wrappedValue: Value {
        get { _value }
        nonmutating set {
            _value = newValue
            updater?(newValue)  // 触发UI更新
        }
    }

    var projectedValue: Binding<Value> {
        Binding(get: { _value }, set: { _value = $0; updater?($0) })
    }
}

// @Published的简化实现
@propertyWrapper
struct Published<Value> {
    private var value: Value
    private var publisher: CurrentValueSubject<Value, Never>

    var wrappedValue: Value {
        get { value }
        set {
            value = newValue
            publisher.send(newValue)  // 发送新值
        }
    }

    var projectedValue: CurrentValueSubject<Value, Never> {
        publisher
    }
}
```

### 实际应用

```swift
// 线程安全包装器
@propertyWrapper
struct ThreadSafe<Value> {
    private var value: Value
    private let lock = NSLock()

    var wrappedValue: Value {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); defer { lock.unlock() }; value = newValue }
    }
}

// 使用
class Counter {
    @ThreadSafe var count = 0
}
```

### 面试速记

**Q: Property Wrapper底层实现原理？**
A: 编译期转换为包装器存储属性（_前缀）+ 计算属性访问wrappedValue。投射值（$）访问projectedValue。

**Q: @State和@Published区别？**
A: @State用于值类型局部状态管理，$投射为Binding；@Published用于引用类型，支持Combine，$投射为Publisher。

---

## 🎯 第十部分：Lazy属性的底层实现

### Lazy属性的原理

#### 基础用法

```swift
class DataProcessor {
    // 延迟属性：首次访问时才初始化
    lazy var expensiveData: [Int] = {
        print("Computing expensive data...")
        return Array(0..<1000000)
    }()

    init() {
        print("DataProcessor initialized")
        // 此时expensiveData还未计算
    }
}

let processor = DataProcessor()
print("After init")
// 首次访问时才计算
let data = processor.expensiveData  // 此时才打印"Computing..."
```

#### 底层实现原理

```swift
// 编译器将lazy属性转换为类似下面的结构
class DataProcessor {
    // 存储初始化状态
    private var _expensiveData_storage: [Int]?
    private var _expensiveData_initialized = false
    private let _expensiveData_lock = NSLock()

    var expensiveData: [Int] {
        mutating get {
            if !_expensiveData_initialized {
                _expensiveData_lock.lock()
                defer { _expensiveData_lock.unlock() }

                // 双重检查锁定
                if !_expensiveData_initialized {
                    _expensiveData_storage = {
                        print("Computing expensive data...")
                        return Array(0..<1000000)
                    }()
                    _expensiveData_initialized = true
                }
            }
            return _expensiveData_storage!
        }
        set {
            _expensiveData_storage = newValue
            _expensiveData_initialized = true
        }
    }
}
```

### 内存布局

```swift
class MyClass {
    var regular: String = "regular"
    lazy var deferred: String = "deferred"
}

// 内存布局
MyClass实例:
┌────────────────────────────────┐
│  isa指针                        │
│  regular: String (16字节)       │ ← 立即分配
│  _deferred_storage: String?     │ ← Optional<String>
│  _deferred_initialized: Bool    │ ← 初始化标志
│  _deferred_lock: NSLock         │ ← 线程安全锁
└────────────────────────────────┘
```

### 线程安全性问题

```swift
// ❌ 非线程安全的lazy
class UnsafeLazy {
    lazy var sharedResource: [Int] = {
        print("Expensive init")
        return Array(0..<1000000)
    }()
}

// 多线程环境下可能多次初始化
let unsafe = UnsafeLazy()
DispatchQueue.concurrentPerform(iterations: 10) { _ in
    print(unsafe.sharedResource.count)
}

// ✅ 线程安全的lazy（编译器保证）
// Swift的lazy属性内置了线程安全机制
// 使用双重检查锁定确保只初始化一次
```

### Lazy vs 计算属性

```swift
struct LazyVsComputed {
    // Lazy：只计算一次，之后缓存结果
    lazy var expensive1: Int = {
        print("Computing lazy...")
        return Array(0..<1000000).count
    }()

    // 计算属性：每次访问都重新计算
    var expensive2: Int {
        print("Computing computed...")
        return Array(0..<1000000).count
    }
}

var example = LazyVsComputed()

print(example.expensive1)  // 打印"Computing lazy..."
print(example.expensive1)  // 不打印，使用缓存值

print(example.expensive2)  // 打印"Computing computed..."
print(example.expensive2)  // 再次打印"Computing computed..."
```

### 性能对比

```swift
// 性能测试
struct PerformanceTest {
    lazy var lazyValue: [Int] = Array(0..<1000000)

    var computedValue: [Int] {
        Array(0..<1000000)
    }

    var storedValue: [Int] = Array(0..<1000000)
}

// 访问时间对比（首次）：
// storedValue: ~1ms  (立即初始化)
// lazyValue: ~1ms    (首次访问时初始化)
// computedValue: ~1ms (每次访问都计算)

// 访问时间对比（后续）：
// storedValue: <0.1ms (直接访问)
// lazyValue: <0.1ms   (使用缓存)
// computedValue: ~1ms (重新计算)
```

### 实际应用场景

```swift
// 1. 数据库连接
class DatabaseManager {
    lazy var connection: DatabaseConnection = {
        print("Establishing database connection...")
        return DatabaseConnection(connectionString: "...")
    }()
}

// 2. 配置加载
class AppConfig {
    lazy var config: Configuration = {
        print("Loading configuration...")
        return loadConfigurationFromFile()
    }()
}

// 3. 复杂计算缓存
class AnalyticsEngine {
    lazy var correlationMatrix: [[Double]] = {
        print("Computing correlation matrix...")
        return computeExpensiveCorrelation()
    }()
}
```

### 面试高频题

**Q: Lazy属性的底层实现原理是什么？**
A: Lazy属性通过存储初始化状态（Optional值+布尔标志）实现。首次访问时检查标志，如未初始化则执行闭包并缓存结果。Swift内置线程安全机制，使用双重检查锁定确保多线程环境下只初始化一次。

**Q: Lazy和计算属性的区别是什么？**
A: Lazy只计算一次并缓存结果，适合昂贵的初始化操作；计算属性每次访问都重新计算，适合值可能变化或计算成本低的情况。Lazy有存储开销（需要空间缓存），计算属性无存储开销但有计算开销。

**Q: Lazy属性是线程安全的吗？**
A: 是的，Swift的lazy属性内置了线程安全机制。编译器生成的代码包含锁和双重检查锁定，确保多线程环境下只初始化一次。但这个线程安全保证只针对初始化过程，后续的读写操作仍需手动同步。

---

## 🎯 第十一部分：KeyPath机制

### KeyPath基础

#### 类型安全的属性访问

```swift
// 基础KeyPath
struct Person {
    let name: String
    var age: Int
}

// \Person.name创建KeyPath
let nameKeyPath = \Person.name
let ageKeyPath = \Person.age

let person = Person(name: "Alice", age: 30)

// 使用KeyPath读取值
let name = person[keyPath: nameKeyPath]  // "Alice"
let age = person[keyPath: ageKeyPath]    // 30
```

#### KeyPath的层次结构

```swift
// KeyPath家族
struct KeyPathHierarchy<Root, Value> {
    // KeyPath: 只读
    let nameKeyPath: KeyPath<Person, String> = \Person.name

    // WritableKeyPath: 可读写（值类型）
    let ageKeyPath: WritableKeyPath<Person, Int> = \Person.age

    // ReferenceWritableKeyPath: 可读写（引用类型）
    let classProperty: ReferenceWritableKeyPath<MyClass, String> = \MyClass.property
}

class MyClass {
    var property: String = ""
}
```

### KeyPath的内存布局

```swift
// KeyPath的内部结构（简化）
struct KeyPath<Root, Value> {
    private let _basePtr: UnsafeRawPointer  // 基础指针
    private let _offsets: [Int]             // 属性偏移量数组
    private let _metadata: TypeMetadata      // 类型元数据
}

// 嵌套KeyPath示例
struct Address {
    let street: String
    let city: String
}

struct Person {
    let name: String
    let address: Address
}

// 嵌套KeyPath: \Person.address.city
let cityKeyPath = \Person.address.city

// 内存布局：
// ┌────────────────────────────────┐
// │  Root元数据: Person            │
// │  属性路径: [address, city]     │
// │  偏移量: [16, 0]               │
// │  最终类型: String              │
// └────────────────────────────────┘
```

### 实际应用场景

#### 1. 排序算法

```swift
// 使用KeyPath进行通用排序
struct Person {
    let name: String
    let age: Int
    let salary: Double
}

let people = [
    Person(name: "Alice", age: 30, salary: 50000.0),
    Person(name: "Bob", age: 25, salary: 60000.0),
    Person(name: "Charlie", age: 35, salary: 55000.0)
]

// 按年龄排序
let sortedByAge = people.sorted(by: \Person.age)
// 等价于: people.sorted { $0.age < $1.age }

// 按工资排序
let sortedBySalary = people.sorted(by: \Person.salary)
```

#### 2. 数据绑定

```swift
// KeyPath作为数据绑定机制
class Binder<Value> {
    private let keyPath: ReferenceWritableKeyPath<Object, Value>
    private weak var object: Object?

    init(object: Object, keyPath: ReferenceWritableKeyPath<Object, Value>) {
        self.object = object
        self.keyPath = keyPath
    }

    func update(_ value: Value) {
        object?[keyPath: keyPath] = value
    }
}

class ViewModel {
    @Published var username = ""

    func setupBindings() {
        let binder = Binder(object: self, keyPath: \ViewModel.username)
        binder.update("new value")  // 更新username属性
    }
}
```

#### 3. 通用验证

```swift
// 使用KeyPath进行属性验证
struct Validator<T> {
    let keyPath: KeyPath<T, String>
    let rules: [String -> Bool]

    func validate(_ object: T) -> Bool {
        let value = object[keyPath: keyPath]
        return rules.allSatisfy { $0(value) }
    }
}

struct User {
    let email: String
    let password: String
}

let emailValidator = Validator<User>(
    keyPath: \User.email,
    rules: [
        { $0.contains("@") },
        { $0.contains(".") }
    ]
)

let user = User(email: "test@example.com", password: "123456")
print(emailValidator.validate(user))  // true
```

### KeyPath vs KVO/KVC

```swift
// Swift KeyPath的优势
class Person: NSObject {
    @objc dynamic var name: String = ""  // 支持KVO
}

// KVO方式（运行时，类型不安全）
let person = Person()
person.addObserver(person, forKeyPath: "name", options: .new, context: nil)
// 错误的keyPath只能在运行时发现

// KeyPath方式（编译期，类型安全）
let nameKeyPath = \Person.name
let value = person[keyPath: nameKeyPath]
// 错误的KeyPath在编译期就会报错
```

### 性能对比

```swift
// 性能测试
struct PerformanceTest {
    let person = Person(name: "Alice", age: 30)

    // 1. 直接访问（最快）
    func directAccess() -> String {
        return person.name  // 编译期确定，内联优化
    }

    // 2. KeyPath访问（较快）
    func keyPathAccess() -> String {
        return person[keyPath: \Person.name]  // 通过偏移量计算
    }

    // 3. KVC访问（最慢）
    func kvcAccess() -> String {
        return person.value(forKey: "name") as! String  // 运行时查找
    }
}

// 性能对比（相对时间）：
// directAccess: 1.0x
// keyPathAccess: 1.2x
// kvcAccess: 5.0x
```

### 面试高频题

**Q: KeyPath的底层实现原理是什么？**
A: KeyPath在编译期创建，存储属性在类型中的偏移量数量和元数据信息。访问时通过偏移量直接定位属性地址，避免了运行时字符串查找。KeyPath本质是编译期优化的属性访问路径，类型安全且性能优秀。

**Q: KeyPath相比KVO/KVC有什么优势？**
A: 1) 类型安全：编译期检查，避免运行时错误；2) 性能优秀：编译期确定偏移量，直接访问；3) 语法简洁：\Type.property语法；4) 支持值类型：KVO/KVC只支持NSObject子类；5) 无需@objc dynamic修饰。

---

## 🎯 第十二部分：Swift Runtime深度解析

### Swift Runtime vs ObjC Runtime

#### 本质区别

```swift
// ObjC Runtime: 消息派发，极其动态
class ObjCClass: NSObject {
    @objc dynamic method() {
        // 运行时可以动态添加、替换方法
    }
}

// Swift Runtime: 元数据驱动，类型安全
class SwiftClass {
    func method() {
        // 默认使用VTable，性能更好
        // 只有@objc dynamic才走ObjC Runtime
    }
}
```

#### 运行时结构对比

```swift
// ObjC类结构（简化）
struct objc_class {
    let isa: UnsafeMutablePointer<objc_class>
    let superclass: UnsafeMutablePointer<objc_class>
    let name: UnsafePointer<Int8>
    let methodLists: UnsafeMutablePointer<objc_method_list>
    let ivarLists: UnsafeMutablePointer<objc_ivar_list>
    // ...更多运行时可修改的信息
}

// Swift类型元数据（简化）
struct SwiftTypeMetadata {
    let kind: TypeKind  // 类型种类
    let superclass: UnsafeMutablePointer<SwiftTypeMetadata>
    let vtable: UnsafeMutablePointer<FunctionPointer>  // 虚函数表
    let size: Int       // 类型大小
    let flags: UInt32   // 类型标志
    // ...主要只读信息
}
```

### Swift类型元数据

#### 类型种类

```swift
enum TypeKind: UInt {
    case struct = 0
    case enum = 1
    case class = 2
    case optional = 13
    case opaque = 14
    // ...更多类型
}

// 获取类型信息
func getTypeInfo(_ value: Any) {
    let metadata = swift_getTypeMetadata(type(of: value))

    switch metadata.kind {
    case .struct:
        print("This is a struct")
    case .class:
        print("This is a class")
    case .enum:
        print("This is an enum")
    default:
        print("Other type")
    }
}
```

### 函数派发机制

```swift
// 派发方式总结
class DispatchExample {
    // 1. 静态派发（final）
    final func staticMethod() {
        // 编译期确定，可内联
    }

    // 2. 虚函数表派发（默认）
    func vtableMethod() {
        // 运行时通过VTable查找
    }

    // 3. 消息派发（@objc dynamic）
    @objc dynamic dynamicMethod() {
        // 运行时通过objc_msgSend查找
    }
}

// 派发性能对比（CPU周期）：
// 静态派发: ~1周期
// VTable派发: ~3-4周期
// 消息派发: ~10+周期
```

### 协议类型见证表

```swift
// 协议见证表的实现
protocol Drawable {
    func draw()
}

struct Circle: Drawable {
    func draw() { print("Drawing circle") }
}

// 协议类型的内存布局
let shape: Drawable = Circle()

// 内部结构：
struct ProtocolExistentialContainer {
    var value: Circle  // 小对象直接存储
    var witnessTable: UnsafeMutablePointer<DrawableWitnessTable>
    var typeMetadata: UnsafeMutablePointer<CircleTypeMetadata>
}

// 见证表结构
struct DrawableWitnessTable {
    let draw_ptr: FunctionPointer  // draw函数指针
    // ...其他协议要求的函数指针
}
```

### 泛型元数据

```swift
// 泛型的类型元数据
func genericFunction<T>(_ value: T) {
    let metadata = swift_getGenericMetadata(T.self)
    print("Type size: \(metadata.size)")
    print("Type alignment: \(metadata.alignment)")
}

// 编译器为每个泛型特化生成元数据
genericFunction(42)              // Int元数据
genericFunction("hello")         // String元数据
genericFunction([1, 2, 3])       // Array<Int>元数据
```

### 性能优化策略

#### 1. 避免不必要的动态派发

```swift
// ❌ 过度使用协议类型
protocol Processor {
    func process()
}

func processAll(_ items: [any Processor]) {
    items.forEach { $0.process() }  // 协议见证表派发
}

// ✅ 使用泛型约束
func processAll<P: Processor>(_ items: [P]) {
    items.forEach { $0.process() }  // 静态派发
}
```

#### 2. 合理使用final

```swift
class PerformanceCritical {
    // 热点方法用final优化
    final func hotMethod() {
        // 可被内联优化
    }
}
```

### 面试高频题

**Q: Swift Runtime相比ObjC Runtime有什么优势？**
A: 1) 性能优秀：默认使用VTable而非消息派发；2) 类型安全：编译期检查更多错误；3) 内存优化：值类型直接存储，减少堆分配；4) 泛型特化：编译期为每个类型生成专门代码。ObjC Runtime更灵活，但性能开销更大。

**Q: 什么时候需要@objc dynamic？**
A: 只有需要ObjC Runtime特性时：1) KVO/KVC；2) 方法交换；3) 运行时方法动态添加；4) Core Animation动画代理；5) 与ObjC代码的互操作。平时应避免使用，以保持Swift的性能优势。

---

## 🎯 第十三部分：defer底层实现

### 核心机制

```swift
// defer底层就是一个栈：后进先出(LIFO)
func example() {
    defer { print("1") }  // 入栈
    defer { print("2") }  // 入栈
    defer { print("3") }  // 入栈
    print("body")
}
// 输出: body -> 3 -> 2 -> 1
```

**底层原理**：
- 编译期：每个defer转为闭包对象，按LIFO顺序存入栈
- 运行期：函数退出时，依次出栈执行所有defer闭包
- 嵌套作用域：每个作用域有自己的defer栈，退出时执行

### 实际应用

```swift
// 1. 资源清理（最常用）
func processFile() {
    let file = FileHandle(forReadingAtPath: path)
    defer { file?.closeFile() }  // 无论成功失败都关闭
    // 处理文件...
}

// 2. 异常处理中的清理
func riskyOperation() throws {
    let resource = acquireResource()
    defer { releaseResource(resource) }  // throw前也会执行
    if errorCondition { throw NSError() }
}

// 3. 性能监控
func monitoredTask() {
    let startTime = Date()
    defer { print("耗时: \(Date().timeIntervalSince(startTime))") }
    // 执行任务...
}
```

### 常见陷阱

```swift
// ❌ 陷阱1：defer捕获引用而非值
var counter = 0
defer { print(counter) }  // 输出3（最新值）
counter = 3

// ✅ 解决：立即捕获需要的值
var counter = 0
let captured = counter
defer { print(captured) }  // 输出0
counter = 3

// ❌ 陷阱2：defer不能修改返回值
func getValue() -> Int {
    var value = 10
    defer { value = 20 }  // 不影响返回值
    return value  // 返回10
}
```

### 面试速记

**Q: defer执行顺序？**
A: LIFO（后进先出），底层用栈存储多个defer闭包。

**Q: defer底层原理？**
A: 编译期转为闭包对象+运行期defer栈管理，函数退出时依次出栈执行。

**Q: defer最大的优势？**
A: **执行保证** - 无论函数如何退出（正常/异常/提前），defer都会执行。

**Q: defer有性能开销吗？**
A: 有轻微开销（闭包创建+执行），热循环中避免使用。

---

**最后更新**: 2026-05-23
**适用面试**: iOS开发、Swift工程师
**配合文档**: 01-语言基础中的4个Swift专题文档

---

## 📚 Swift学习路径

### 初级（理解概念）
- 值类型vs引用类型、ARC基础、三种派发机制
- defer基本用法、协议泛型基础概念

### 中级（深入原理）
- 泛型单态化vs协议见证表
- Optional、闭包、String底层实现
- VTable内存布局、Property Wrappers机制

### 高级（底层优化）
- Swift Runtime类型元数据
- Codable自动合成、KeyPath性能优化
- Lazy线程安全、派发机制选择

### 专家（架构设计）
- 类型擦除设计、泛型协议结合使用
- 自定义Property Wrappers
- Swift/ObjC Runtime互操作边界

---

## 🔥 Swift面试速记卡（纯问答版）

**Q: Struct和Class的主要区别？**
A: Struct是值语义、栈分配、线程安全、无继承；Class是引用语义、堆分配、需线程安全、支持继承。

**Q: 什么是Copy-on-Write？**
A: 多个变量共享同一份数据，只有修改时才真正拷贝。Array、Dictionary、Set等支持COW机制，优化性能的同时保持值语义。

**Q: 什么时候选择Struct，什么时候选择Class？**
A: 数据简单、无继承需求、需要线程安全 → Struct；需要继承、引用语义、身份标识 → Class。

**Q: 泛型和协议的本质区别是什么？**
A: 泛型是类型抽象（编译期单态化、静态派发、性能最优），协议是行为抽象（运行时见证表、动态派发、灵活性高）。

**Q: 为什么泛型性能比协议好？**
A: 泛型在编译期为每个类型生成专门代码，可内联优化；协议需要运行时见证表查找，有额外开销。

**Q: 什么时候用泛型，什么时候用协议？**
A: 性能关键代码、容器类型 → 泛型；需要多态行为、定义接口 → 协议。

**Q: 什么是类型擦除？为什么需要它？**
A: 解决带关联类型的协议不能作为具体类型使用的问题。通过包装器结构体隐藏具体类型信息，只暴露协议接口。

**Q: ARC只管理什么类型的内存？**
A: 只管理引用类型的内存，值类型由栈自动管理。

**Q: weak和unowned的区别？**
A: weak自动置nil，通过SideTable间接访问；unowned不置nil（类似unsafe_unretained），性能更好但需确保生命周期。

**Q: 闭包什么时候会发生循环引用？**
A: 闭包捕获self（类实例），而self又持有闭包时。用捕获列表`[weak self]`打破循环。

**Q: Swift有哪几种方法派发机制？**
A: 静态派发（Struct、final，最快）、VTable派发（Class默认）、协议见证表派发（协议类型调用）、消息派发（@objc dynamic，最慢）。

**Q: 派发方式取决于什么？**
A: 取决于调用类型，不是实现类型。Struct用具体类型调用是静态派发，Class用类类型调用是VTable派发，用协议类型调用都是协议见证表派发。

**Q: 什么时候需要@objc dynamic？**
A: 需要OC runtime特性时：KVO/KVC、方法交换、Core Animation代理。

**Q: defer的执行顺序是什么？**
A: LIFO（后进先出），后定义的defer先执行。

**Q: defer的底层实现原理？**
A: 编译期转为闭包对象，运行时用defer栈管理。函数退出时按LIFO顺序执行所有defer。

**Q: defer最大的优势是什么？**
A: 执行保证。无论函数如何退出（正常返回、抛出异常、提前退出），defer都会执行。

**Q: Optional的底层实现是什么？**
A: 泛型枚举，通过关联值存储数据。小对象直接在枚举内存中存储，有内存优化。

**Q: Optional如何优化内存？**
A: 小对象（如Int?）直接在枚举内存中存储值，大对象存储指针。

**Q: 闭包的底层实现是什么？**
A: 编译为类实例，捕获的变量成为成员变量，有捕获列表避免循环引用。

**Q: 不捕获变量的闭包性能如何？**
A: 类似函数指针，性能最优。捕获变量后需要分配堆内存，有性能开销。

**Q: String的小字符串优化是什么？**
A: ≤15字符内联存储在栈上，避免堆分配。>15字符存储指针指向堆内存。

**Q: Substring和String的关系？**
A: Substring共享原String内存，修改时触发Copy-on-Write。

**Q: strong和weak引用的性能差异？**
A: strong直接访问对象，weak通过SideTable间接访问。weak不影响引用计数但性能开销更大。

**Q: Codable的自动合成机制是什么？**
A: 编译器自动生成编码/解码代码，零运行时开销。通过CodingKeys控制字段映射。

**Q: 如何优化Codable性能？**
A: 使用内置策略、避免过深嵌套、使用基础类型。

**Q: Property Wrapper的底层实现原理？**
A: 编译期转换为包装器存储属性（_前缀）+ 计算属性访问wrappedValue。投射值（$）访问projectedValue。

**Q: @State和@Published的区别？**
A: @State用于值类型局部状态，$投射为Binding；@Published用于引用类型，$投射为Publisher。

**Q: Lazy属性的底层实现？**
A: Optional值+布尔标志，双重检查锁定确保只初始化一次。

**Q: Lazy是线程安全的吗？**
A: 是的，内置双重检查锁定，确保多线程环境下只初始化一次。

**Q: Lazy和计算属性的区别？**
A: Lazy只计算一次并缓存结果；计算属性每次访问都重新计算。

**Q: KeyPath的底层实现？**
A: 编译期创建，存储属性偏移量和类型元数据，通过偏移量直接访问属性。

**Q: KeyPath相比KVO/KVC的优势？**
A: 类型安全、性能优秀、编译期检查、支持值类型。

**Q: Swift Runtime相比ObjC Runtime的优势？**
A: 默认使用VTable派发（性能更好）、类型元数据驱动、泛型特化。

**Q: 什么时候Swift会用到ObjC Runtime？**
A: @objc dynamic修饰的内容，需要KVO/KVC、方法交换等特性时。

**Q: Swift并发相比GCD的优势？**
A: 结构化并发、编译期数据竞争检查、Actor数据隔离、取消自动传播、避免回调地狱。

**Q: Actor如何保证线程安全？**
A: Actor通过数据隔离确保内部状态只能通过串行方法访问，编译期保证同一时间只有一个任务能访问可变状态。

**Q: 什么是结构化并发？**
A: async/await、TaskGroup、async let等，确保任务的生命周期明确，避免非结构化任务管理。

**Q: Swift为什么比OC快？**
A: 1. Struct默认静态派发，可内联优化 2. Class用VTable派发，比OC消息派发快 3. 值类型栈分配，无引用计数开销 4. 泛型编译期单态化，为每个类型生成专门代码

**Q: 泛型单态化是什么意思？**
A: 编译器在编译期为每个具体类型生成专门的代码，比如process<Int>生成process_Int函数。这样可以进行内联优化，函数调用是静态派发，性能最优。

**Q: 协议见证表派发什么时候使用？**
A: 只有用协议类型调用时才使用协议见证表派发。比如let shape: Drawable = circle，这里shape是协议类型，所以用协议见证表派发。如果用具体类型circle.draw()就是静态派发。

**Q: VTable的查找过程？**
A: 1. 获取对象的isa指针 2. 通过isa找到类的元数据 3. 在元数据中找到VTable 4. 根据函数在VTable中的索引获取函数指针 5. 调用函数

**Q: SideTable的作用是什么？**
A: SideTable用于存储weak引用信息，包含弱引用哈希表、引用计数、弱引用计数等。weak引用通过SideTable间接访问对象，不影响对象的引用计数。

**Q: 什么时候会出现循环引用？**
A: 1. 闭包捕获self，self持有闭包 2. 两个类实例互相持有strong引用 3. 父子实例使用strong引用（应该用unowned或weak）