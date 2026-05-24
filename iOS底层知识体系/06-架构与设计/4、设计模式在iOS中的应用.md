# 设计模式在 iOS 中的应用

> 一句话总结：**创建型/结构型/行为型模式在 UIKit 与业务层大量出现，理解意图比死记类图更重要。**

---

## 3. 设计模式

### 3.1 创建型模式

**Singleton（单例）**：

```swift
class NetworkManager {
    static let shared = NetworkManager()

    private init() {
        // 私有化初始化
    }

    func fetchData() {
        // 网络请求
    }
}

// 使用
NetworkManager.shared.fetchData()
```

**Factory（工厂）**：

```swift
protocol Shape {
    func draw()
}

class Circle: Shape {
    func draw() { print("Drawing circle") }
}

class Square: Shape {
    func draw() { print("Drawing square") }
}

enum ShapeType {
    case circle
    case square
}

class ShapeFactory {
    static func createShape(_ type: ShapeType) -> Shape {
        switch type {
        case .circle:
            return Circle()
        case .square:
            return Square()
        }
    }
}

// 使用
let shape = ShapeFactory.createShape(.circle)
shape.draw()
```

### 3.2 结构型模式

**Adapter（适配器）**：

```swift
// 目标协议
protocol Target {
    func request()
}

// 被适配者
class Adaptee {
    func specificRequest() {
        print("Specific request")
    }
}

// 适配器
class Adapter: Target {
    private let adaptee: Adaptee

    init(adaptee: Adaptee) {
        self.adaptee = adaptee
    }

    func request() {
        adaptee.specificRequest()  // 转换调用
    }
}

// 使用
let adaptee = Adaptee()
let adapter = Adapter(adaptee: adaptee)
adapter.request()
```

**Proxy（代理）**：

```swift
protocol Subject {
    func request()
}

class RealSubject: Subject {
    func request() {
        print("Real request")
    }
}

class Proxy: Subject {
    private var realSubject: RealSubject?

    func request() {
        if realSubject == nil {
            realSubject = RealSubject()
        }
        realSubject?.request()
    }
}
```

**Decorator（装饰器）**：

```swift
protocol Component {
    func operation() -> String
}

class ConcreteComponent: Component {
    func operation() -> String {
        return "ConcreteComponent"
    }
}

class Decorator: Component {
    private let component: Component

    init(_ component: Component) {
        self.component = component
    }

    func operation() -> String {
        return component.operation()
    }
}

class ConcreteDecorator: Decorator {
    override func operation() -> String {
        return "ConcreteDecorator(\(super.operation()))"
    }
}
```

### 3.3 行为型模式

**Observer（观察者）**：

```swift
// Swift 原生支持：ObservableObject + @Published
class ViewModel: ObservableObject {
    @Published var data: String = ""

    func fetchData() {
        data = "New data"
    }
}

class View {
    var cancellable: AnyCancellable?

    func observe(viewModel: ViewModel) {
        cancellable = viewModel.$data.sink { data in
            print("Data updated: \(data)")
        }
    }
}

// 使用
let viewModel = ViewModel()
let view = View()
view.observe(viewModel)
viewModel.fetchData()
```

**Strategy（策略）**：

```swift
protocol Strategy {
    func execute(_ data: [Int]) -> Int
}

struct SumStrategy: Strategy {
    func execute(_ data: [Int]) -> Int {
        return data.reduce(0, +)
    }
}

struct AverageStrategy: Strategy {
    func execute(_ data: [Int]) -> Int {
        guard !data.isEmpty else { return 0 }
        return data.reduce(0, +) / data.count
    }
}

class Context {
    private var strategy: Strategy

    init(strategy: Strategy) {
        self.strategy = strategy
    }

    func setStrategy(_ strategy: Strategy) {
        self.strategy = strategy
    }

    func executeStrategy(_ data: [Int]) -> Int {
        return strategy.execute(data)
    }
}

// 使用
let context = Context(strategy: SumStrategy())
let result = context.executeStrategy([1, 2, 3, 4, 5])
```

**Delegate（委托）**：

```swift
// 协议
protocol Delegate: class {
    func didCompleteTask(_ result: String)
}

// 委托对象
class Worker {
    weak var delegate: Delegate?

    func doWork() {
        let result = "Task completed"
        delegate?.didCompleteTask(result)
    }
}

// 代理对象
class Boss: Delegate {
    func didCompleteTask(_ result: String) {
        print("Received: \(result)")
    }
}

// 使用
let boss = Boss()
let worker = Worker()
worker.delegate = boss
worker.doWork()
```

---

### 6.2 设计模式

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **Delegate 的作用？** | 事件回调，解耦 | ⭐⭐⭐ |
| **Singleton 的使用场景？** | 全局唯一，网络管理、数据库管理 | ⭐⭐⭐ |
| **Observer 的实现方式？** | 通知中心、KVO、Combine | ⭐⭐⭐⭐ |
| **Adapter 的应用场景？** | 接口不兼容，数据转换 | ⭐⭐⭐ |


---

## 7. 参考资料

### 优质文章
- [iOS Architecture Patterns. Demystifying MVC, MVP, MVVM and VIPER](https://medium.com/ios-os-x-development/ios-architecture-patterns-ecba4c38de52)
- [iOS Architecture Patterns: MVC, MVP, MVVM, VIPER, and VIP in Swift (2026)](https://www.oreilly.com/library/view/ios-architecture-patterns/9781484290682/)
- [The perfect iOS app architecture](https://betterprogramming.com/the-perfect-ios-app-architecture-mvvm-viper-clean-swift/)
- [Why VIPER and MVVM in SwiftUI are actually the same pattern](https://matteomanferdini.com/2021/09/26/why-viper-and-mvvm-in-swiftui-are-actually-the-same-pattern/)

### 开源项目
- [Hero (iOS Architecture Pattern)](https://github.com/netguru/Hero) - MVVM+Coordinator
- [RxFlow](https://github.com/RxSwiftCommunity/RxFlow) - Coordinated navigation
- [TCA (The Composable Architecture)](https://github.com/pointfreeco/The-Composable-Architecture)

---

**最后更新**：2026-04-07
**状态**：✅ 已完成

**Sources:**
- [iOS Architecture Patterns. Demystifying MVC, MVP, MVVM and VIPER](https://medium.com/ios-os-x-development/ios-architecture-patterns-ecba4c38de52)
- [iOS Architecture Patterns (2026)](https://www.oreilly.com/library/view/ios-architecture-patterns/9781484290682/)
- [The perfect iOS app architecture](https://betterprogramming.com/the-perfect-ios-app-architecture-mvvm-viper-clean-swift/)
