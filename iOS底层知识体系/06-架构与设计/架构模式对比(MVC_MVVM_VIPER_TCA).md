# 架构模式对比(MVC/MVVM/VIPER/TCA)

> 一句话总结：**架构模式决定状态与依赖的边界；从 MVC 到 TCA，复杂度与可测试性通常同步上升。**

---

## 1. 架构模式演进

### 1.1 MVC（Model-View-Controller）

**Apple 经典架构**：

```
┌─────────────────────────────────┐
│  View (UIView/UIViewController)   │
├─────────────────────────────────┤
│  Controller (UIViewController)   │
├─────────────────────────────────┤
│  Model (Data Model)             │
└─────────────────────────────────┘
```

**职责划分**：

| 组件 | 职责 | 示例 |
|------|------|------|
| **Model** | 数据和业务逻辑 | User, NetworkManager, DatabaseManager |
| **View** | UI 展示 | UIView, UIViewController, SwiftUI View |
| **Controller** | 协调 Model 和 View | UIViewController, Presenter |

**数据流**：

```
User Action → Controller → Model (Update)
              ↓
         View (Update)
```

**优点**：
- Apple 官方推荐，文档齐全
- 职责清晰，简单易懂
- 适合小型项目

**缺点**：
- Controller 容易臃肿（Massive View Controller）
- Model 和 View 耦合度高
- 难以测试

### 1.2 MVP（Model-View-Presenter）

**改进**：

```
┌─────────────────────────────────┐
│  View (Passive View)              │
├─────────────────────────────────┤
│  Presenter (Logic)                │
├─────────────────────────────────┤
│  Model (Data)                    │
└─────────────────────────────────┘
```

**与 MVC 的区别**：

```
MVC：Controller 同时持有 View 和 Model
MVP：Presenter 只持有 Model，View 通过协议与 Presenter 通信（被动视图）
```

**优点**：
- View 和 Model 完全解耦
- Presenter 纯逻辑，易于测试
- View 可以是 Mock 对象（单元测试）

**缺点**：
- Presenter 容易臃肿（God Object）
- 协议定义繁琐
- 代码量增加

### 1.3 MVVM（Model-View-ViewModel）

**现代架构**：

```
┌─────────────────────────────────┐
│  View (UIView/UIViewController)   │
├─────────────────────────────────┤
│  ViewModel (Bindable Model)      │
├─────────────────────────────────┤
│  Model (Data)                    │
└─────────────────────────────────┘
```

**数据绑定**：

```swift
// ViewModel
class UserViewModel: ObservableObject {
    @Published var userName: String
    @Published var userEmail: String

    private let model: UserModel

    init(model: UserModel) {
        self.model = model
        self.userName = model.name
        self.userEmail = model.email
    }

    func updateEmail(_ email: String) {
        model.email = email
        userEmail = email
    }
}

// View
struct ContentView: View {
    @StateObject private var viewModel = UserViewModel(model: UserModel())

    var body: some View {
        VStack {
            TextField("Email", text: $viewModel.userEmail)
            Text(viewModel.userName)
        }
    }
}
```

**优点**：
- ViewModel 不持有 View，解耦更好
- 支持数据绑定（Combine/RxSwift）
- ViewModel 可测试
- SwiftUI 原生支持

**缺点**：
- 学习曲线陡峭
- 数据绑定调试困难
- 过度设计风险

### 1.4 VIPER（View-Interactor-Presenter-Entity-Router）

**重型架构**：

```
┌─────────────┐  ┌──────────┐  ┌─────────┐  ┌──────┐  ┌────────┐
│  View      │←→│ Presenter│←→│Interactor│←→│Entity│  │ Router │
└─────────────┘  └──────────┘  └─────────┘  └──────┘  └────────┘
```

**职责划分**：

| 组件 | 职责 |
|------|------|
| **View** | UI 展示，用户交互 |
| **Presenter** | 协调 View 和 Interactor，处理 UI 逻辑 |
| **Interactor** | 业务逻辑，数据获取 |
| **Entity** | 数据模型（纯数据） |
| **Router** | 页面路由，导航 |

**数据流**：

```
User Action → View → Presenter → Interactor → Entity
    ↑                                      ↓
    └────────── Update ←──────────────────┘
```

**代码示例**：

```swift
// Protocol
protocol HomePresentable: class {
    var interactor: HomeInteractable? { get set }
    var router: HomeRoutable? { get set }
}

protocol HomeInteractable: class {
    var presenter: HomePresentable? { get set }
    func fetchUsers()
}

protocol HomeRoutable: class {
    func navigateToDetail(for user: User)
}

// Implementation
class HomeInteractor: HomeInteractable {
    weak var presenter: HomePresentable?
    var users = [User]()

    func fetchUsers() {
        // 获取数据
        users = [User(id: 1, name: "John")]
        presenter?.didFetchUsers(users)
    }
}

class HomePresenter: HomePresentable {
    var interactor: HomeInteractable?
    var router: HomeRoutable?

    func didFetchUsers(_ users: [User]) {
        // 更新 View
        view?.updateUsers(users)
    }
}
```

**优点**：
- 职责划分最细
- 高内聚、低耦合
- 高度可测试
- 模块化好

**缺点**：
- 代码量大
- 学习曲线陡峭
- 过度设计风险
- 小项目不适用

### 1.5 TCA (The Composable Architecture)

**SwiftUI 时代的单向数据流架构**：

```
┌─────────────────────────────────┐
│            State                 │
└──────────────┬──────────────────┘
               │
      ┌────────▼────────┐
      │  Reducer        │
      └────────┬────────┘
               │
      ┌────────▼────────┐
      │   Store         │
      └────────┬────────┘
               │
      ┌────────▼────────┐
      │    View         │
      └─────────────────┘
```

**核心概念**：

| 概念 | 说明 |
|------|------|
| **State** | 应用状态，唯一真理来源 |
| **Action** | 描述状态变化的事件 |
| **Reducer** | 纯函数，接收 State 和 Action，返回新 State |
| **Store** | 管理 State 和 Reducer |
| **Effect** | 副作用，处理异步逻辑 |

**代码示例**：

```swift
// 1. 定义 State
struct AppState {
    var count: Int = 0
    var users: [User] = []
}

// 2. 定义 Action
enum AppAction {
    case increment
    case decrement
    case fetchUsers([User])
}

// 3. 定义 Reducer
let appReducer = Reducer<AppState, AppAction> { state, action in
    switch action {
    case .increment:
        state.count += 1
        return state
    case .decrement:
        state.count -= 1
        return state
    case .fetchUsers(let users):
        state.users = users
        return state
    }
}

// 4. 创建 Store
let store = Store(initialState: AppState(), reducer: appReducer)

// 5. View
struct ContentView: View {
    let store: Store<AppState, AppAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                Text("Count: \(viewStore.count)")
                Button("+") { viewStore.send(.increment) }
            }
        }
    }
}
```

**优点**：
- 单向数据流，状态可预测
- 纯函数 Reducer，易于测试
- 适合 SwiftUI
- 支持时间旅行调试

**缺点**：
- 学习曲线陡峭
- 样板代码多
- 过度设计风险

---

## 2. 架构模式对比

### 2.1 横向对比

| 特性 | MVC | MVP | MVVM | VIPER | TCA |
|------|-----|-----|------|-------|-----|
| **复杂度** | ⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **可测试性** | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **可维护性** | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **学习曲线** | ⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **代码量** | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **适用项目** | 小型 | 中型 | 中大型 | 大型 | 大型 |
| **SwiftUI 支持** | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

### 2.2 如何选择？

**项目规模**：

```
小型项目（< 5 个页面）：
→ MVC

中型项目（5-20 个页面）：
→ MVVM + Combine

大型项目（> 20 个页面）：
→ VIPER 或 MVVM + Module
→ 团队协作：VIPER
→ 个人开发：MVVM
```

**团队规模**：

```
1-2 人：MVC 或 MVVM
3-5 人：MVVM + Module
5+ 人：VIPER 或 TCA
```

**技术栈**：

```
UIKit：
→ MVC / MVVM / VIPER

SwiftUI：
→ MVVM / TCA（原生支持）
```

---

### 6.1 架构模式

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **MVC 的缺点？** | Massive View Controller，难以测试 | ⭐⭐⭐ |
| **MVVM 的优势？** | ViewModel 可测试，支持数据绑定 | ⭐⭐⭐⭐ |
| **VIPER 的缺点？** | 代码量大，学习曲线陡 | ⭐⭐⭐ |
| **MVC vs MVVM vs VIPER？** | MVC：简单；MVVM：数据绑定；VIPER：高内聚 | ⭐⭐⭐⭐ |

### 6.2 设计模式

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **Delegate 的作用？** | 事件回调，解耦 | ⭐⭐⭐ |
| **Singleton 的使用场景？** | 全局唯一，网络管理、数据库管理 | ⭐⭐⭐ |
| **Observer 的实现方式？** | 通知中心、KVO、Combine | ⭐⭐⭐⭐ |
| **Adapter 的应用场景？** | 接口不兼容，数据转换 | ⭐⭐⭐ |

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
