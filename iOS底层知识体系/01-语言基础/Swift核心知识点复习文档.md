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

### 协议基础

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
        print("Drawing circle")
    }
}
```

### 协议扩展（POP核心）

```swift
// 协议扩展提供默认实现
extension Drawable {
    func draw() {
        print("Default drawing")
    }
}

// where子句约束
extension Array where Element: Drawable {
    func drawAll() {
        forEach { $0.draw() }
    }
}
```

### 泛型基础

```swift
// 泛型函数
func swapValues<T>(_ a: inout T, _ b: inout T) {
    let temp = a
    a = b
    b = temp
}

// 泛型类型
struct Stack<Element> {
    private var items: [Element] = []
    mutating func push(_ item: Element) {
        items.append(item)
    }
    mutating func pop() -> Element? {
        return items.popLast()
    }
}
```

### 关联类型

```swift
protocol Container {
    associatedtype Item
    mutating func append(_ item: Item)
    var count: Int { get }
    subscript(i: Int) -> Item { get }
}
```

### 泛型 vs 协议的本质区别

#### 抽象维度对比

```swift
// 泛型 - 抽象"类型"本身
struct Container<T> {
    var value: T
    func getValue() -> T { return value }
}

// 协议 - 抽象"行为"能力
protocol Containerable {
    associatedtype ContentType
    var value: ContentType { get }
    func getValue() -> ContentType
}
```

#### 底层实现差异（核心区别）

**泛型的底层实现 - 编译期单态化**
```swift
// Swift代码
func process<T>(_ value: T) -> T {
    return value
}

let result = process(42)

// 底层编译过程：
// 1. 编译器为Int生成特化版本
func process_Int(_ value: Int) -> Int {
    return value
}

// 2. 为String生成不同的特化版本
func process_String(_ value: String) -> String {
    return value
}

// 3. 静态派发，无运行时开销
// 类似C++模板实例化，每种类型生成专用代码
```

**协议的底层实现 - 协议见证表 + 存在容器**
```swift
// Swift代码
protocol Drawable {
    func draw()
}

func render(_ shape: Drawable) {
    shape.draw()  // 动态派发
}

// 底层实现：
// 1. 协议见证表（每个遵循协议的类型都有）
struct Drawable_ProtocolWitnessTable {
    let draw_ptr: FunctionPointer        // draw函数指针
    let type_metadata: TypeMetadataPtr   // 类型信息
    // ...
}

// 2. 存在容器（协议类型的存储结构）
struct Drawable_ExistentialContainer {
    // 存储具体值（小对象直接存，大对象存指针）
    let value_buffer: [UInt8]  // 3个指针大小的缓冲区

    // 指向协议见证表的指针
    let witness_table: UnsafeMutablePointer<Drawable_ProtocolWitnessTable>

    // 类型元数据指针
    let type_metadata: UnsafeMutablePointer<TypeMetadata>
}

// 3. 运行时动态查找见证表中的函数指针
// 有运行时开销，但灵活性高
```

#### 性能对比

| 特性 | 泛型 | 协议 |
|------|------|------|
| **派发方式** | 静态派发（编译期确定） | 动态派发（运行时查找） |
| **实现时机** | 编译期单态化 | 运行时见证表查找 |
| **性能开销** | 最小（可内联优化） | 中等（间接函数调用） |
| **二进制大小** | 较大（每种类型生成代码） | 较小（共享代码） |
| **灵活性** | 中等（类型约束） | 高（支持异构集合） |

#### 实际性能测试

```swift
// 泛型版本 - 性能最优
struct GenericStack<T> {
    private var items: [T] = []

    mutating func push(_ item: T) {
        items.append(item)
    }

    mutating func pop() -> T? {
        return items.popLast()
    }
}

// 编译期特化，每个T生成专门代码，可内联优化
var intStack = GenericStack<Int>()

// 协议版本 - 灵活性高
protocol Stackable {
    associatedtype Item
    mutating func push(_ item: Item)
    mutating func pop() -> Item?
}

struct AnyStack: Stackable {
    typealias Item = Any
    private var items: [Any] = []

    mutating func push(_ item: Any) {
        items.append(item)
    }

    mutating func pop() -> Any? {
        return items.popLast()
    }
}

// 运行时类型擦除，涉及存在容器和见证表，性能较低
var anyStack = AnyStack()
```

#### 使用场景指导

**选择泛型的场景**：
```swift
// 1. 容器类型 - 性能关键
struct Cache<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]
    func get(_ key: Key) -> Value? { storage[key] }
    mutating func set(_ key: Key, _ value: Value) { storage[key] = value }
}

// 2. 算法实现 - 需要类型安全
func binarySearch<T: Comparable>(_ array: [T], target: T) -> Int? {
    var low = 0, high = array.count - 1
    while low <= high {
        let mid = (low + high) / 2
        if array[mid] == target { return mid }
        else if array[mid] < target { low = mid + 1 }
        else { high = mid - 1 }
    }
    return nil
}

// 3. 性能关键代码 - 避免动态派发
final class Vector<T> {
    private var elements: [T] = []
    func append(_ element: T) { elements.append(element) }
    subscript(index: Int) -> T { elements[index] }
}
```

**选择协议的场景**：
```swift
// 1. 定义接口 - 需要多态
protocol NetworkRequest {
    associatedtype ResponseType: Decodable
    func execute() async throws -> ResponseType
}

// 2. 能力抽象 - 支持异构集合
protocol Encodable {
    func encode(to encoder: Encoder) throws
}

let encodables: [any Encodable] = [1, "hello", true]  // 不同类型

// 3. 依赖注入 - 解耦
protocol Service {
    func fetchUser() async throws -> User
}

class ViewModel {
    let service: Service
    init(service: Service) {
        self.service = service
    }
}
```

#### 结合使用（最强大的模式）

```swift
// 协议定义行为 + 泛型提供类型约束
protocol Repository {
    associatedtype Entity
    associatedtype ID: Hashable

    func find(by id: ID) -> Entity?
    func save(_ entity: Entity)
}

// 泛型函数约束协议
func fetchEntity<R: Repository>(_ repository: R, id: R.ID) -> R.Entity? {
    return repository.find(by: id)
}

// 具体实现
struct UserRepository: Repository {
    typealias Entity = User
    typealias ID = Int

    func find(by id: Int) -> User? {
        return User(id: id, name: "User\(id)")
    }

    func save(_ entity: User) {
        // 保存逻辑
    }
}

// 使用 - 类型安全 + 灵活行为
let userRepo = UserRepository()
if let user = fetchEntity(userRepo, id: 123) {
    print("Found user: \(user.name)")
}
```

### 类型擦除技术

#### 问题的出现

```swift
// 问题：协议使用了关联类型，不能直接作为类型使用
protocol Processor {
    associatedtype Output
    func process() -> Output
}

class NetworkProcessor: Processor {
    typealias Output = Data
    func process() -> Data {
        return Data()
    }
}

// ❌ 编译错误：Processor只能作为约束，不能作为具体类型
let processors: [Processor] = [NetworkProcessor()]
```

#### 解决方案：类型擦除

```swift
// 类型擦除包装器
struct AnyProcessor<Output>: Processor {
    private let _process: () -> Output

    init<P: Processor>(_ processor: P) where P.Output == Output {
        _process = processor.process
    }

    func process() -> Output {
        return _process()
    }
}

// ✅ 现在可以使用了
let processors: [AnyProcessor<Data>] = [
    AnyProcessor(NetworkProcessor())
]
```

### 面试高频题

**Q: 协议相比继承有什么优势？**
A: 协议支持多重遵循、更灵活的组合、值类型也能遵循、协议扩展提供默认实现（类似mixin），而继承只能单继承、主要针对类。

**Q: 泛型和协议的本质区别是什么？**
A: **抽象维度不同**：泛型是类型抽象（"处理不同类型的相同逻辑"），协议是行为抽象（"不同类型的相同行为"）。**底层实现不同**：泛型采用编译期单态化，静态派发，性能最优；协议采用运行时见证表查找，动态派发，灵活性高。

**Q: 为什么泛型性能比协议好？**
A: 泛型在编译期为每种具体类型生成专门的代码（单态化），可以进行内联优化，函数调用是静态派发。协议需要通过存在容器和见证表进行间接调用，涉及动态派发，有额外的运行时开销。

**Q: 什么时候用泛型，什么时候用协议？**
A: **泛型**：性能关键代码、容器类型、算法实现。**协议**：需要多态行为、定义接口、能力抽象、支持异构集合。**结合使用**：协议定义行为约束，泛型提供类型安全。

**Q: 什么是类型擦除？为什么需要它？**
A: 类型擦除是解决"带有关联类型的协议不能作为具体类型使用"的技术。通过创建包装器结构体，隐藏具体的类型信息，只暴露协议定义的接口，使得不同具体类型可以统一存储和使用。

**Q: associatedtype和泛型参数有什么区别？**
A: **associatedtype**：在协议中使用，延迟具体类型的指定，由遵循协议的类型决定。**泛型参数**：在具体类型或函数中使用，调用时指定具体类型。associatedtype支持更灵活的抽象，但使用时需要类型擦除。

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

### async/await 基础

```swift
// 异步函数定义
func fetchUserData() async throws -> User {
    let url = URL(string: "https://api.example.com/user")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}

// 调用异步函数
Task {
    do {
        let user = try await fetchUserData()
        print("User: \(user.name)")
    } catch {
        print("Error: \(error)")
    }
}
```

### 结构化并发

```swift
// 并行执行多个任务
async let user1 = fetchUser(id: 1)
async let user2 = fetchUser(id: 2)
async let user3 = fetchUser(id: 3)

// 等待所有任务完成
let users = await (user1, user2, user3)

// TaskGroup处理动态数量的任务
await withTaskGroup(of: User.self) { group in
    for id in userIds {
        group.addTask {
            return try await fetchUser(id: id)
        }
    }

    for try await user in group {
        print("User: \(user.name)")
    }
}
```

### Actor 数据隔离

```swift
// Actor定义
actor Counter {
    private var value = 0

    func increment() {
        value += 1
    }

    func getValue() -> Int {
        return value
    }
}

// 使用Actor
let counter = Counter()
Task {
    await counter.increment()
    let currentValue = await counter.getValue()
}
```

### MainActor

```swift
// MainActor确保代码在主线程执行
@MainActor
class ViewModel: ObservableObject {
    @Published var data: String = ""

    func loadData() async {
        // 网络请求（后台线程）
        let result = await fetchFromNetwork()
        // UI更新（主线程，因为是MainActor）
        self.data = result
    }
}
```

### Swift并发 vs GCD

| 特性 | Swift并发 | GCD |
|------|-----------|-----|
| 语法 | async/await | Block/closure |
| 结构化 | ✅ 结构化范围 | ❌ 非结构化 |
| 类型安全 | ✅ 编译期检查 | ❌ 运行时错误 |
| 数据竞争 | ✅ Actor隔离 | ❌ 手动同步 |
| 取消传播 | ✅ 自动 | ❌ 手动检查 |
| 底层 | libdispatch | libdispatch |

### 面试高频题

**Q: Swift并发相比GCD有什么优势？**
A: Swift并发提供了结构化并发、编译期数据竞争检查、Actor数据隔离、取消自动传播等优势，避免了GCD的回调地狱和非结构化的任务管理，同时在类型安全性方面有显著提升。

---

## 🎯 第五部分：方法派发机制与VTable

### Swift的三种方法派发机制

Swift与OC的最大区别之一就是方法派发机制。Swift采用了三种不同的派发方式，根据具体情况在编译期确定最优策略。

#### 1. 静态派发 (Static Dispatch)

**特点**：编译期确定函数地址，可直接内联优化

```swift
// 值类型方法 - 静态派发
struct Point {
    var x: Int
    var y: Int
    func draw() { print("Draw point") }  // 静态派发
    mutating func move() { }             // 静态派发
}

// final修饰的方法 - 强制静态派发
class Calculator {
    final func add(_ a: Int, _ b: Int) -> Int {
        return a + b  // 可能被内联为直接返回结果
    }
}

// 扩展中的方法
extension String {
    func fcfLength() -> Int { return self.count }  // 静态派发
}
```

**性能**：~1个CPU周期，最快

#### 2. 虚函数表派发 (VTable Dispatch)

**特点**：通过虚函数表间接查找，支持继承多态

```swift
// Class默认使用虚函数表派发
class Animal {
    func makeSound() { print("Animal sound") }  // 虚函数表派发
    func move() { print("Moving") }              // 虚函数表派发
}

class Dog: Animal {
    override func makeSound() { print("Bark") }  // 虚函数表派发
    func fetch() { print("Fetching") }           // 虚函数表派发
}

// 多态调用
let animal: Animal = Dog()
animal.makeSound()  // 运行时通过VTable找到Dog的实现
```

**性能**：~3-4个CPU周期

#### 3. 消息派发 (Message Dispatch)

**特点**：通过objc_msgSend运行时查找，完全动态

```swift
// @objc dynamic修饰 - 强制消息派发
class Person: NSObject {
    @objc dynamic var age: Int = 0  // 支持KVO
    @objc dynamic func birthday() { }  // 支持运行时方法替换
}

// 纯OC类 - 消息派发
// 在OC代码中定义的类，在Swift中调用仍使用消息派发
```

**性能**：~10+个CPU周期

### VTable的底层原理

#### 内存结构

```swift
class Animal {
    var name: String = ""
    func makeSound() { print("Animal") }
    func move() { print("Moving") }
}

class Dog: Animal {
    var breed: String = ""
    override func makeSound() { print("Bark") }
    override func move() { print("Running") }
    func fetch() { print("Fetching") }
}
```

**Dog对象的内存布局**：
```
Dog对象 (堆内存):
┌────────────────────────────────┐
│  isa指针 (8字节)               │ → 指向Dog的类型元数据
├────────────────────────────────┤
│  name: String (16字节)         │ ← Animal的成员
├────────────────────────────────┤
│  breed: String (16字节)        │ ← Dog的成员
└────────────────────────────────┘

Dog类型元数据 (全局数据区):
┌────────────────────────────────┐
│  Kind: Class                   │
│  Superclass: Animal元数据指针  │
│  VTable偏移量                  │
├────────────────────────────────┤
│  虚函数表 (VTable):            │
│  [0] makeSound → Dog_makeSound │ ← 函数指针
│  [1] move       → Dog_move     │
│  [2] fetch      → Dog_fetch    │
├────────────────────────────────┤
│  其他元数据...                 │
└────────────────────────────────┘
```

#### VTable查找过程

```swift
let animal: Animal = Dog()
animal.makeSound()  // 如何调用到Dog的实现？
```

**汇编级别的查找过程**：
```assembly
; animal.makeSound() 的汇编实现

; 1. 获取对象
mov x0, animal          ; x0 = Dog对象

; 2. 获取isa指针
ldr x8, [x0]            ; x8 = Dog类的元数据

; 3. 获取VTable
ldr x8, [x8, #VTableOffset]  ; x8 = VTable地址

; 4. 根据索引获取函数指针
ldr x8, [x8, #8*1]      ; makeSound在索引1，每个指针8字节
                        ; x8 = Dog_makeSound函数地址

; 5. 调用函数
blr x8                  ; 跳转到Dog_makeSound()
```

#### 继承关系中的VTable

```swift
class Animal {
    func breathe() { }  // VTable[0]
    func move() { }     // VTable[1]
}

class Mammal: Animal {
    override func move() { }  // VTable[1]
    func sleep() { }          // VTable[2]
}

class Dog: Mammal {
    override func move() { }  // VTable[1]
    func bark() { }           // VTable[3]
}
```

**VTable继承结构**：
```
Animal.VTable:
[0] breathe → Animal_breathe
[1] move     → Animal_move

Mammal.VTable:
[0] breathe → Animal_breathe      (继承)
[1] move     → Mammal_move        (重写)
[2] sleep    → Mammal_sleep       (新增)

Dog.VTable:
[0] breathe → Animal_breathe      (继承)
[1] move     → Dog_move           (重写)
[2] sleep    → Mammal_sleep       (继承)
[3] bark     → Dog_bark           (新增)
```

### 关键概念对比

#### VTable vs Runtime方法表

| 特性 | VTable | Runtime方法表 |
|------|-------|--------------|
| **存储位置** | 代码段（只读） | 堆内存（可读写） |
| **生成时机** | 编译期 | 编译期+运行时 |
| **能否修改** | 不能动态修改 | 可以动态添加/删除 |
| **查找方式** | 数组索引查找 | 哈希表/链表查找 |
| **查找速度** | O(1)直接访问 | O(1)哈希查找，但有开销 |
| **存储内容** | 函数指针数组 | 完整的方法元数据 |

#### Swift vs OC 多态实现

**OC多态**：
```objective-c
Animal *dog = [[Dog alloc] init];
[dog makeSound];  // 运行时通过objc_msgSend查找
```

**Swift多态**：
```swift
let dog: Animal = Dog()
dog.makeSound()  // 运行时通过VTable查找
```

**关键区别**：
- OC：消息派发，极其灵活，可运行时修改
- Swift：虚函数表派发，类型安全，性能更好

#### 3. 协议见证表派发

**特点**：协议类型调用时的特殊派发机制

```swift
protocol Drawable {
    func draw()
}

struct Circle: Drawable {
    func draw() { print("Circle") }
}

class Rectangle: Drawable {
    func draw() { print("Rectangle") }
}
```

**关键概念**：派发方式取决于**调用类型**，不是**实现类型**

```swift
// 情况1：具体类型调用
let circle = Circle()
circle.draw()  // ← 静态派发 (struct)

let rect = Rectangle()
rect.draw()    // ← 虚函数表派发 (class)

// 情况2：协议类型调用
let shape1: Drawable = circle
shape1.draw()  // ← 协议见证表派发

let shape2: Drawable = rect
shape2.draw()  // ← 协议见证表派发
```

**核心原理**：
- **struct本身只有静态派发**，但当用协议类型调用时使用协议见证表
- **class用类类型调用时用VTable**，用协议类型调用时用协议见证表
- 协议见证表本质是VTable的变体，专门为协议多态设计

**性能对比**：
- 静态派发：~1 CPU周期
- 虚函数表派发：~3-4 CPU周期
- 协议见证表派发：~5-7 CPU周期
- 消息派发：~10+ CPU周期

### @objc的三种情况

#### 1. @objc - 双重派发
```swift
class Person: NSObject {
    @objc func greet() { print("Hello") }
}
```
- Swift内调用：虚函数表派发
- OC调用：消息派发
- 目的：OC互操作

#### 2. @objc dynamic - 强制消息派发
```swift
class Person: NSObject {
    @objc dynamic var age: Int = 0  // 支持KVO
}
```
- 所有调用：消息派发
- 目的：runtime特性（KVO/KVC/方法交换）

#### 3. final - 强制静态派发
```swift
class Calculator {
    final func add(_ a: Int, _ b: Int) -> Int {
        return a + b  // 可内联优化
    }
}
```
- 编译期确定
- 目的：性能优化

### 实际应用指南

#### 默认策略（推荐）
```swift
// Struct默认静态派发 - 性能最优
struct ViewModel {
    func processData() { }  // 自动静态派发
}

// Class默认虚函数表派发 - 性能和灵活性的平衡
class Service {
    func execute() { }       // 虚函数表派发
    final func setup() { }   // 明确不需要重写，用final优化
}
```

#### 需要OC互操作
```swift
class BridgedClass: NSObject {
    @objc func objcMethod() { }  // 暴露给OC，Swift仍用VTable
}
```

#### 需要runtime特性
```swift
class Observable: NSObject {
    @objc dynamic var value: Int = 0  // 支持KVO
}

class Swizzling: NSObject {
    @objc dynamic func method() { }  // 支持方法交换
}
```

#### 性能关键路径
```swift
class PerformanceClass {
    // 热点方法用final优化
    final func hotMethod() { }  // 静态派发，可内联
}
```

### 性能对比测试

```swift
// 测试不同派发的性能差异

class Base {
    func vtableMethod() { }        // 虚函数表
    final func staticMethod() { }  // 静态派发
}

struct StructType {
    func method() { }              // 静态派发
}

class DynamicClass: NSObject {
    @objc dynamic func msgMethod() { }  // 消息派发
}

// 性能排序（从快到慢）：
// 1. final/static method       (编译期确定)
// 2. struct method             (编译期确定)
// 3. class VTable method       (虚函数表查找)
// 4. protocol witness table    (协议见证表查找)
// 5. @objc dynamic method      (消息派发)
```

### 面试高频题

**Q: Swift为什么比OC快？**
A: Swift默认使用更高效的派发机制：
- Struct等值类型直接静态派发，可内联优化
- Class方法使用虚函数表派发，比OC消息转发快
- 只有@objc dynamic才走OC runtime，性能开销明确

**Q: 什么时候需要@objc dynamic？**
A: 只有需要OC runtime特性时：
- KVO/KVC
- Core Animation的动画代理
- 与OC代码混用时需要runtime动态调用
- 方法交换

**Q: Struct和Class的性能差异是什么？**
A: 主要差异在方法派发：
- Struct方法静态派发，编译期确定，可内联
- Class方法虚函数表派发，需要运行时查找
- Struct没有引用计数开销，Class有ARC管理成本

**Q: 协议见证表派发是什么时候用的？**
A: 只有用**协议类型**调用时才用协议见证表派发：
- `struct`实现协议后，用具体类型调用是静态派发，用协议类型调用是协议见证表派发
- `class`实现协议后，用类类型调用是虚函数表派发，用协议类型调用是协议见证表派发
- 核心原则：派发方式取决于调用类型，不是实现类型

---

## 🔥 Swift面试速记卡

### 值类型与引用类型
- Struct: 值语义、栈分配、线程安全、无继承
- Class: 引用语义、堆分配、需线程安全、支持继承
- 选择：数据简单用Struct，需要继承/引用语义用Class

### 协议与泛型
- **泛型本质**：类型抽象，编译期单态化，静态派发，性能最优
- **协议本质**：行为抽象，运行时见证表，动态派发，灵活性高
- **底层区别**：泛型为每个类型生成专门代码，协议通过存在容器间接调用
- **选择原则**：性能关键用泛型，需要多态用协议，结合使用最强大
- **类型擦除**：解决关联类型协议不能作为具体类型的问题

### 内存管理
- ARC只管引用类型
- weak/unowned打破循环引用
- 闭包捕获列表避免泄漏
- COW优化性能

### 并发模型
- async/await：结构化并发
- Actor：数据竞争保护
- MainActor：主线程隔离
- 优于GCD：类型安全、结构化、编译期检查

### 方法派发机制
- **静态派发**：编译期确定，Struct、final方法，性能最优
- **虚函数表派发**：Class默认，支持多态，性能良好
- **协议见证表派发**：协议类型调用，VTable的变体，性能中等
- **消息派发**：@objc dynamic，灵活但性能开销大
- **核心原则**：派发方式取决于调用类型，不是实现类型

### 底层原理
- **Optional本质**：泛型枚举，关联值存储，小对象内存优化
- **闭包本质**：编译为类实例，捕获变量成成员，捕获列表避免循环引用
- **ARC本质**：strong直接访问+引用计数，weak通过SideTable间接访问
- **String本质**：≤15字符内联存储，Substring共享内存，COW优化

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

## 📊 Swift知识点自检

### 基础概念（必须掌握）
- [ ] 能清晰区分值类型和引用类型
- [ ] 理解Copy-on-Write机制
- [ ] 掌握协议和泛型的基本用法
- [ ] 理解Swift ARC的内存管理规则
- [ ] 理解Swift三种方法派发机制的区别
- [ ] 能区分泛型和协议的适用场景
- [ ] 理解协议见证表派发的使用场景

### 进阶概念（加分项）
- [ ] 面向协议编程（POP）思想
- [ ] 关联类型和类型擦除
- [ ] Swift并发模型的高级特性
- [ ] Actor隔离和Sendable
- [ ] VTable的底层实现原理
- [ ] 泛型单态化原理
- [ ] 协议见证表和存在容器
- [ ] Optional的枚举本质和内存优化
- [ ] 闭包的类实现机制
- [ ] weak引用的SideTable实现

### 实战应用（亮点）
- [ ] 能根据场景选择Struct/Class
- [ ] 能设计协议导向的架构
- [ ] 能处理复杂的内存管理问题
- [ ] 能使用现代Swift并发API
- [ ] 能根据性能需求选择合适的派发机制
- [ ] 能在泛型和协议之间做出正确选择
- [ ] 能实现类型擦除解决实际问题
- [ ] 能理解协议类型调用带来的性能影响

---

## 🎯 复习建议

### 时间紧迫时（30分钟）
1. 重点复习面试高频题
2. 记忆速记卡内容
3. 过一遍代码示例

### 时间充裕时（1小时）
1. 系统阅读每个话题
2. 理解底层原理
3. 结合实际项目思考应用场景

### 面试前一天
1. 再次复习速记卡
2. 回答自检问题
3. 准备实际案例

---

**最后更新**: 2026-05-23
**适用面试**: iOS开发、Swift工程师
**配合文档**: 01-语言基础中的4个Swift专题文档