# Swift-协议与泛型

> 一句话总结：**协议 + 泛型 + 协议扩展构成 Swift 的组合核心；理解关联类型、不透明类型与类型擦除，才能兼顾抽象与性能。**

---

## 📚 学习地图

- **预计学习时间**：60 分钟
- **前置知识**：Swift 基础、面向对象概念
- **学习目标**：协议与泛型 → POP → 高级特性（扩展、模式匹配、错误处理等）

---

## 1. 协议（Protocol）

### 1.1 协议基础

**什么是协议？**

协议定义了一组方法和属性的蓝图，类、结构体、枚举可以遵循协议。

**基本语法**：

```swift
// 定义协议
protocol Drawable {
    var size: CGSize { get set }
    func draw()
}

// 遵循协议
struct Circle: Drawable {
    var size: CGSize
    func draw() {
        print("Drawing a circle")
    }
}
```

**协议作为类型**：

```swift
// 协议作为类型（Existential Type）
let shapes: [Drawable] = [
    Circle(size: CGSize(width: 10, height: 10)),
    Rectangle(size: CGSize(width: 20, height: 20))
]

for shape in shapes {
    shape.draw()
}
```

### 1.2 协议关联类型（Associated Type）

**定义关联类型**：

```swift
protocol Container {
    associatedtype Item
    mutating func append(_ item: Item)
    var count: Int { get }
    subscript(i: Int) -> Item { get }
}

// 遵循协议
struct IntStack: Container {
    typealias Item = Int  // 指定关联类型
    private var items = [Int]()

    mutating func append(_ item: Int) {
        items.append(item)
    }

    var count: Int {
        return items.count
    }

    subscript(i: Int) -> Int {
        return items[i]
    }
}
```

**带约束的关联类型**：

```swift
protocol Container {
    associatedtype Item: Equatable  // 约束：Item 必须遵循 Equatable
    mutating func append(_ item: Item)
    func find(_ item: Item) -> Int?
}
```

### 1.3 协议扩展（Protocol Extension）

**提供默认实现**：

```swift
extension Drawable {
    func draw() {
        print("Default drawing implementation")
    }

    func render() {
        print("Rendering...")
        draw()
    }
}

// 所有遵循 Drawable 的类型都自动获得 render() 方法
struct Square: Drawable {
    var size: CGSize
    // 不需要实现 draw()，使用默认实现
}

let square = Square(size: CGSize(width: 10, height: 10))
square.render()  // 调用扩展的方法
```

**条件扩展（where 子句）**：

```swift
extension Array where Element: Equatable {
    func allEqual() -> Bool {
        guard let first = first else { return true }
        return allSatisfy { $0 == first }
    }
}

[1, 1, 1].allEqual()  // true
[1, 2, 3].allEqual()  // false
```

### 1.4 协议组合

**使用 & 组合多个协议**：

```swift
protocol Named {
    var name: String { get }
}

protocol Aged {
    var age: Int { get }
}

// 组合协议
func greet(_ person: Named & Aged) {
    print("Hello, \(person.name), you are \(person.age) years old.")
}

struct Person: Named, Aged {
    let name: String
    let age: Int
}

let john = Person(name: "John", age: 30)
greet(john)
```

**存在类型与组合（Swift 5.7+ 常用写法）**：同时满足多个协议时，用 `&` 组合；`any` 表示「任意满足该组合的具体类型」。

```swift
func process(_ value: any Drawable & Named) {
    // value 同时遵循 Drawable 与 Named（而非「二选一」）
}
```

### 1.5 底层视角：Witness Table 与 OC 动态派发

**Swift 协议调用**在运行时往往通过 **Protocol Witness Table（PWT）** 与 **Value Witness Table（VWT）** 解析：前者对应「这份具体实现里协议要求的方法/属性落在哪」，后者对应「值类型的拷贝/销毁/缓冲搬运」等操作。把 `Drawable` 当作 `any Drawable` 使用时，常走 **existential** 路径：**动态派发 + 额外元数据**，与泛型参数上「单态化（monomorphization）」的静态路径成本不同。

**与 Objective-C 对比**（概念对齐，非一一实现等价）：

| 机制 | Objective-C | Swift |
|------|-------------|--------|
| 动态消息 | `objc_msgSend`、在 `isa` 链上查 SEL | `@objc` / `dynamic` 继承 NSObject 体系可走消息派发 |
| 协议 | `objc_protocol_t`，运行时注册 | 静态模块 + Witness Table；部分 `@objc protocol` 仍参与 ObjC 运行时 |
| 泛型 | 无等价一等公民；常靠 `id` + 约定 | 编译期单态化 + 类型元数据；类型参数不同即不同机器码路径 |

**实践含义**：性能敏感热路径上，过多 `any SomeProtocol` 可能不如「泛型 + 具体类型」或 `some` 不透明类型；与 OC 里「少用 `id`、多用具体类型」同一直觉。

### 1.6 some vs any（Opaque Type vs Existential Type）

**some（不透明类型）**：

```swift
// SwiftUI 中的典型用法
func makeView() -> some View {
    return Text("Hello")
}

// 编译器知道具体类型，但对外隐藏
// 优势：性能更好（静态分发），支持关联类型
```

**any（存在类型）**：

```swift
func process(_ view: any View) {
    // view 的类型在运行时确定
    // 劣势：动态分发，性能稍差
}
```

**对比**：

| 特性 | some | any |
|------|------|-----|
| **类型确定时间** | 编译期 | 运行期 |
| **性能** | 静态分发，性能高 | 动态分发，性能稍低 |
| **支持关联类型** | ✅ 是 | ❌ 否 |
| **存储方式** | 只能存储一种类型 | 可存储多种类型 |

**实际应用**：

```swift
// some：返回具体类型，但隐藏实现细节
protocol DataSource {
    associatedtype Item
    func getItem() -> Item
}

class IntDataSource: DataSource {
    typealias Item = Int
    func getItem() -> Int { return 42 }
}

func createDataSource() -> some DataSource {
    return IntDataSource()  // 编译器知道是 IntDataSource
}

// ❌ 不能用 some 存储多种类型
// var sources: [some DataSource] = []  // 错误

// ✅ any 可以存储多种类型
var sources: [any DataSource] = []
sources.append(IntDataSource())
sources.append(StringDataSource())
```

---

## 2. 泛型（Generics）

### 2.1 泛型基础

**泛型函数**：

```swift
// 不使用泛型
func swapInt(_ a: inout Int, _ b: inout Int) {
    let temp = a
    a = b
    b = temp
}

// 使用泛型
func swap<T>(_ a: inout T, _ b: inout T) {
    let temp = a
    a = b
    b = temp
}

var x = 1, y = 2
swap(&x, &y)
```

**泛型类型**：

```swift
struct Stack<Element> {
    private var items = [Element]()

    mutating func push(_ item: Element) {
        items.append(item)
    }

    mutating func pop() -> Element? {
        return items.popLast()
    }
}

// 使用
var intStack = Stack<Int>()
intStack.push(1)

var stringStack = Stack<String>()
stringStack.push("Hello")
```

### 2.2 类型约束

**基础约束**：

```swift
// 约束 T 必须遵循 Equatable
func findIndex<T: Equatable>(_ array: [T], valueToFind: T) -> Int? {
    for (index, value) in array.enumerated() {
        if value == valueToFind {
            return index
        }
    }
    return nil
}
```

**多个约束（使用 where）**：

```swift
func allItemsMatch<C1: Container, C2: Container>(_ c1: C1, _ c2: C2) -> Bool
    where C1.Item == C2.Item, C1.Item: Equatable {
    // C1 和 C2 的 Item 类型相同，且遵循 Equatable
    if c1.count != c2.count {
        return false
    }

    for i in 0..<c1.count {
        if c1[i] != c2[i] {
            return false
        }
    }

    return true
}
```

### 2.3 关联类型（Associated Type）vs 泛型

**使用关联类型**：

```swift
protocol Container {
    associatedtype Item
    mutating func append(_ item: Item)
    func get(_ index: Int) -> Item
}

struct IntContainer: Container {
    typealias Item = Int
    private var items = [Int]()

    mutating func append(_ item: Int) {
        items.append(item)
    }

    func get(_ index: Int) -> Int {
        return items[index]
    }
}
```

**使用泛型**：

```swift
struct Container<Item> {
    private var items = [Item]()

    mutating func append(_ item: Item) {
        items.append(item)
    }

    func get(_ index: Int) -> Item {
        return items[index]
    }
}

// 使用
let intContainer = Container<Int>()
```

**如何选择？**

| 特性 | 关联类型 | 泛型 |
|------|---------|------|
| **灵活性** | 更灵活（推断类型） | 需显式指定类型 |
| **可读性** | 需要 typealias 指明 | 类型参数清晰 |
| **适用场景** | 协议定义 | 具体 类型 |

### 2.4 泛型特化（Generic Specialization）

**编译器优化**：

```swift
// 泛型函数
func min<T: Comparable>(_ a: T, _ b: T) -> T {
    return a < b ? a : b
}

// 编译器为具体类型生成专用版本
// Int 版本
func min(_ a: Int, _ b: Int) -> Int {
    return a < b ? a : b
}

// String 版本
func min(_ a: String, _ b: String) -> String {
    return a < b ? a : b
}

// 调用时直接调用专用版本，无需类型检查
let result = min(1, 2)  // 调用 Int 版本
```

---

## 3. 高级特性

### 3.1 扩展（Extension）

**扩展计算属性**：

```swift
extension Int {
    var isEven: Bool {
        return self % 2 == 0
    }

    var isOdd: Bool {
        return !isEven
    }
}

10.isEven  // true
10.isOdd   // false
```

**扩展方法**：

```swift
extension String {
    func trimmed() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func appendIfNotEmpty(_ string: String) {
        if !string.isEmpty {
            self += string
        }
    }
}

"  hello  ".trimmed()  // "hello"
```

**扩展初始化器**：

```swift
struct Point {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

extension Point {
    init(coordinate: (Double, Double)) {
        self.x = coordinate.0
        self.y = coordinate.1
    }
}

let p1 = Point(x: 10, y: 20)
let p2 = Point(coordinate: (10, 20))
```

### 3.2 嵌套类型（Nested Types）

**枚举中嵌套类**：

```swift
enum BlackjackCard {
    case heart, diamond, club, spade

    struct Rank {
        let value: Int
        let name: String
    }

    let rank: Rank

    static func allValues() -> [BlackjackCard] {
        let ranks = [Rank(value: 1, name: "Ace"), Rank(value: 2, name: "Two")]
        return ranks.flatMap { rank in
            [.heart, .diamond, .club, .spade].map { suit in
                BlackjackCard(rank: rank, suit: suit)
            }
        }
    }
}
```

### 3.3 模式匹配（Pattern Matching）

**if case / guard case**：

```swift
enum Response {
    case success(Int)
    case failure(Error)
}

let response = Response.success(200)

if case .success(let code) = response {
    print("Success code: \(code)")
}

guard case .success(let code) = response else {
    print("Not success")
    return
}
```

**switch 模式匹配**：

```swift
enum Shape {
    case circle(radius: Double)
    case rectangle(width: Double, height: Double)
    case point
}

let shape = Shape.circle(radius: 10)

switch shape {
case .circle(let radius):
    print("Circle with radius: \(radius)")
case .rectangle(let width, let height):
    print("Rectangle: \(width) x \(height)")
case .point:
    print("Point")
}
```

**for case 模式匹配**：

```swift
let responses = [
    Response.success(200),
    Response.failure(NSError(domain: "test", code: -1)),
    Response.success(404)
]

for case .success(let code) in responses {
    print("Success code: \(code)")
}
// 输出：
// Success code: 200
// Success code: 404
```

### 3.4 错误处理

**定义错误类型**：

```swift
enum NetworkError: Error {
    case invalidURL
    case noConnection
    case decodingFailed
}
```

**throwing 函数**：

```swift
func fetchData(from urlString: String) throws -> Data {
    guard let url = URL(string: urlString) else {
        throw NetworkError.invalidURL
    }

    // 模拟网络请求
    let data = Data()

    return data
}
```

**do-catch 捕获**：

```swift
do {
    let data = try fetchData(from: "https://api.example.com")
    print("Success: \(data)")
} catch NetworkError.invalidURL {
    print("Invalid URL")
} catch {
    print("Other error: \(error)")
}
```

**try? / try!**：

```swift
// try?：错误时返回 nil
let data = try? fetchData(from: "invalid")  // nil

// try!：错误时崩溃
let data = try! fetchData(from: "https://api.example.com")  // Data or crash
```

**Rethrow（重新抛出）**：

```swift
func processData() throws -> Data {
    do {
        return try fetchData(from: "https://api.example.com")
    } catch {
        print("Fetch failed, rethrowing...")
        throw error  // 重新抛出
    }
}
```

### 3.5 访问控制

**五个访问级别**：

```swift
// open：最高级别，可被继承和重写（仅 Class）
open class OpenClass {
    open func openMethod() {}
}

// public：可被访问，但不能在模块外继承和重写
public struct PublicStruct {
    public var value: Int
}

// internal：默认级别，模块内可访问
internal struct InternalStruct {
    var value: Int
}

// fileprivate：文件内可访问
fileprivate struct FilePrivateStruct {
    var value: Int
}

// private：类型内可访问
struct PrivateStruct {
    private var value: Int
}
```

**使用原则**：

```
1. 默认使用 internal
2. 需要暴露给外部时使用 public
3. 需要支持外部继承重写时使用 open
4. 实现细节使用 private
5. 同文件内共享使用 fileprivate
```

### 3.6 属性观察器（Property Observers）

**willSet / didSet**：

```swift
class StepCounter {
    var totalSteps: Int = 0 {
        willSet {
            print("About to set totalSteps to \(newValue)")
        }
        didSet {
            print("totalSteps changed from \(oldValue) to \(totalSteps)")
            if totalSteps > 10000 {
                print("Goal achieved!")
            }
        }
    }
}

let counter = StepCounter()
counter.totalSteps = 100
// About to set totalSteps to 100
// totalSteps changed from 0 to 100
```

**延迟初始化（lazy）**：

```swift
class DataManager {
    lazy var data: [String] = {
        print("Loading data...")
        return ["Item1", "Item2", "Item3"]
    }()

    func useData() {
        // data 只在第一次访问时初始化
        print(data.count)
    }
}

let manager = DataManager()
manager.useData()  // Loading data... \n 3
manager.useData()  // 3
```

---

## 4. 面向协议编程（POP）

### 4.1 POP vs OOP

**面向对象编程（OOP）**：

```
核心思想：封装、继承、多态

问题：
- 继承耦合度高（菱形缺陷）
- 横切关注点难以共享
- 动态派发不安全
```

**面向协议编程（POP）**：

```
核心思想：协议定义能力，类型遵循协议

优势：
- 低耦合（协议组合 vs 类继承）
- 高内聚（按能力拆分）
- 值语义支持
- 编译期安全
```

### 4.2 POP 实践

**定义能力（协议）**：

```swift
protocol Flyable {
    func fly()
}

protocol Swimmable {
    func swim()
}

protocol Runnable {
    func run()
}
```

**组合能力**：

```swift
struct Duck: Flyable, Swimmable, Runnable {
    func fly() {
        print("Duck is flying")
    }

    func swim() {
        print("Duck is swimming")
    }

    func run() {
        print("Duck is running")
    }
}

struct Penguin: Swimmable, Runnable {
    func swim() {
        print("Penguin is swimming")
    }

    func run() {
        print("Penguin is running")
    }
}
```

**协议扩展提供默认实现**：

```swift
extension Flyable {
    func fly() {
        print("Flying...")
    }
}

struct Bird: Flyable {}
// Bird 不需要实现 fly()，直接使用默认实现
```

**协议组合**：

```swift
func travel(_ traveler: some Flyable & Runnable) {
    traveler.fly()
    traveler.run()
}

let duck = Duck()
travel(duck)  // ✅ Duck 遵循 Flyable 和 Runnable

let penguin = Penguin()
travel(penguin)  // ❌ Penguin 不遵循 Flyable，编译错误
```

### 4.3 类型擦除（Type Erasure）

**问题**：带关联类型的协议不能直接作为类型

```swift
protocol Container {
    associatedtype Item
    func get(_ index: Int) -> Item
}

// ❌ 错误：协议有关联类型，不能直接作为类型
let containers: [Container] = []
```

**解决方案：类型擦除包装器**

```swift
class AnyContainer<Item>: Container {
    private let _get: (Int) -> Item

    init<C: Container>(_ container: C) where C.Item == Item {
        _get = container.get
    }

    func get(_ index: Int) -> Item {
        return _get(index)
    }
}

// ✅ 可以存储不同类型的 Container
let containers: [AnyContainer<Int>] = []
```

---
## 5. 高频面试题

### 5.1 协议相关

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **协议 vs 类继承？** | 协议：能力组合、低耦合；继承：代码复用、高耦合 | ⭐⭐⭐⭐ |
| **some vs any？** | some：编译期确定、性能高；any：运行期确定、性能稍低 | ⭐⭐⭐⭐⭐ |
| **关联类型的作用？** | 让协议支持泛型，提高灵活性 | ⭐⭐⭐⭐ |
| **为什么不能直接用带关联类型的协议作为类型？** | 类型不确定，编译器无法布局内存 | ⭐⭐⭐⭐⭐ |
| **类型擦除是什么？** | 包装带关联类型的协议，使其能作为类型使用 | ⭐⭐⭐⭐⭐ |

### 5.2 泛型相关

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **泛型的作用？** | 类型安全、代码复用、灵活性 | ⭐⭐⭐ |
| **关联类型 vs 泛型？** | 关联类型：协议内、类型推断；泛型：显式指定类型 | ⭐⭐⭐⭐ |
| **where 子句的作用？** | 添加类型约束，使泛型更灵活 | ⭐⭐⭐ |

### 5.3 POP 相关

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **POP vs OOP？** | POP：协议组合；OOP：类继承 | ⭐⭐⭐⭐ |
| **如何理解协议即接口？** | 协议定义能力，类型遵循协议 | ⭐⭐⭐ |
| **POP 的优势？** | 低耦合、高内聚、值语义支持 | ⭐⭐⭐⭐ |

---

## 6. 参考资料

### 优质文章
- [Complete Guide to Protocols: In Swift & Beyond (2026)](https://yakovmanshin.com/2026/03/protocols-in-swift-and-beyond/)
- [Swift 6.0 Protocol Extensions: Powerful New Tricks](https://medium.com/swiftfy/swift-6-0-protocol-extensions-powerful-new-tricks-you-need-to-know-2e4a8372ed2f)
- [Specialized extensions using generic type constraints](https://www.swiftbysundell.com/articles/specialized-extensions-using-generic-type-constraints)
- [Swift Copy-on-Write Explained](https://www.amitsen.de/blog/swift-copy-on-write-performance)
- [The Differences Between Value Types and Reference Types in Swift](https://levelup.gitconnected.com/the-differences-between-value-types-and-reference-types-in-swift-0bf155d823a1)

### 官方文档
- [Swift Generics Manifesto](https://github.com/apple/swift/blob/master/docs/GenericsManifesto.md)
- [The Swift Programming Language - Protocols](https://docs.swift.org/swift-book/LanguageGuide/Protocols.html)
- [The Swift Programming Language - Generics](https://docs.swift.org/swift-book/LanguageGuide/Generics.html)

### 开源项目
- [Swift Algorithm Club](https://github.com/kharrison/SwiftAlgorithmClub) - Swift 算法实现



（值类型 / 写时复制 / 闭包捕获等更偏内存的内容，见 `Swift-值类型与引用类型.md` 与 `Swift-内存管理与ARC.md`。）

---

**最后更新**：2026-04-13  
**状态**：✅ 已校正示例（`Int` 扩展、`IntContainer.append`、`some` 组合语法）并增补 **Witness Table / 派发** 与 OC 对照
