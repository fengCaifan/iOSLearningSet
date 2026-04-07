# SOLID 原则实践

> 一句话总结：**SOLID 帮助在组件化与演进中控制耦合；在 iOS 常通过协议、注入与模块化落地。**

---

## 4. SOLID 原则

### 4.1 Single Responsibility Principle（单一职责）

**原则**：一个类只负责一件事

**示例**：

```swift
// ❌ 违反 SRP
class User {
    var name: String
    var email: String

    func saveToDatabase() { }
    func sendEmail() { }
    func validateEmail() -> Bool { true }
}

// ✅ 遵循 SRP
class User {
    let profile: UserProfile
    let email: EmailService
}

struct UserProfile {
    var name: String
    var email: String
}

class EmailService {
    func send(_ email: String) { }
}

class DatabaseService {
    func save(_ user: User) { }
}
```

### 4.2 Open-Closed Principle（开闭原则）

**原则**：对扩展开放，对修改关闭

**示例**：

```swift
protocol Shape {
    func area() -> CGFloat
}

extension Shape {
    func perimeter() -> CGFloat {
        return 0
    }
}

struct Circle: Shape {
    var radius: CGFloat

    func area() -> CGFloat {
        return .pi * radius * radius
    }
}

// ✅ 扩展：添加新的计算方法
extension Circle {
    func perimeter() -> CGFloat {
        return 2 * .pi * radius
    }
}

// ❌ 不修改 Shape 协议
```

### 4.3 Liskov Substitution Principle（里氏替换）

**原则**：子类可以替换父类

**示例**：

```swift
class Bird {
    func fly() {
        print("Flying...")
    }
}

class Sparrow: Bird {
    override func fly() {
        print("Sparrow flying...")
    }
}

class Ostrich: Bird {
    override func fly() {
        // ❌ 鸵鸟不会飞，违反 LSP
        fatalError("Ostrich cannot fly")
    }
}

// ✅ 使用协议
protocol Flyable {
    func fly()
}

class Bird: Flyable {
    func fly() {
        print("Flying...")
    }
}
```

### 4.4 Interface Segregation Principle（接口隔离）

**原则**：客户端不应依赖它不需要的接口

**示例**：

```swift
// ❌ 臃肿协议
protocol Worker {
    func work()
    func eat()
    func sleep()
}

// ✅ 拆分协议
protocol Workable {
    func work()
}

protocol Eatable {
    func eat()
}

protocol Sleepable {
    func sleep()
}

class Human: Workable, Eatable, Sleepable {
    func work() { }
    func eat() { }
    func sleep() { }
}

class Robot: Workable {
    func work() { }
    // 不需要实现 eat() 和 sleep()
}
```

### 4.5 Dependency Inversion Principle（依赖倒置）

**原则**：依赖抽象而非具体实现

**示例**：

```swift
// ❌ 依赖具体
class LightBulb {
    func turnOn() { }
}

class Switch {
    private var bulb: LightBulb

    init(bulb: LightBulb) {
        self.bulb = bulb
    }

    func toggle() {
        bulb.turnOn()
    }
}

// ✅ 依赖抽象
protocol Switchable {
    func turnOn()
}

class LightBulb: Switchable {
    func turnOn() { }
}

class Switch {
    private var device: Switchable

    init(device: Switchable) {
        self.device = device
    }

    func toggle() {
        device.turnOn()
    }
}
```

---

### 6.3 SOLID 原则

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **单一职责原则？** | 一个类只负责一件事 | ⭐⭐⭐ |
| **开闭原则？** | 对扩展开放，对修改关闭 | ⭐⭐⭐⭐ |
| **里氏替换原则？** | 子类可替换父类 | ⭐⭐⭐⭐ |
| **依赖倒置原则？** | 依赖抽象而非具体 | ⭐⭐⭐⭐ |

---


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
