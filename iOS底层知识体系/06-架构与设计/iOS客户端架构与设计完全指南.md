# iOS 客户端架构与设计完全指南

## 1. 架构设计目标与 SOLID 原则

### 1.1 先分清架构模式、设计原则与设计模式

| 层次 | 要回答的问题 | 本文内容 |
|------|--------------|----------|
| 架构模式 | 页面或功能中的职责、状态和协作怎样组织？ | MVC、MVP、MVVM、VIPER、MVI、TCA、Clean Architecture |
| 设计原则 | 划分职责和依赖时，怎样减少不必要的耦合？ | SOLID |
| 设计模式与协作机制 | 某一类重复出现的局部问题，怎样解决？ | 创建型、结构型、行为型模式，以及 iOS 的 Delegate |

这些不是从“低级”到“高级”的升级链。页面架构、单向数据流和分层依赖关注的维度不同，可以组合使用。

### 1.2 好架构的目标不是平均分配代码

- **职责清晰**：某项规则改变时，知道应该改哪个 Module（模块），而不是要求每个类的行数相近。
- **调用简单**：Interface（接口）应说明调用者需要知道的输入、结果、错误、时序和生命周期约定；复杂 Implementation（实现）尽量留在模块内。
- **变化集中**：替换数据来源、增加展示规则或修复问题时，避免相同知识散落在多个调用者中。
- **可测试**：核心行为可以在合适的 Interface 上验证；可变的外部依赖可以提供测试替代实现。
- **成本匹配**：增加协议、文件、绑定和装配都要付出成本；抽象需要对应真实变化或测试需求。

### 1.3 SOLID 的使用方式

SOLID 是检查设计的视角，不是要求“所有类型都加协议”。先找到变化的原因和调用关系，再决定需要哪些抽象。

### 1.4 单一职责原则（SRP）

**核心原则**：一个模块应围绕同一类变化原因组织职责。不是“一个类只能有一个方法”，也不是把所有动作机械拆成独立类型。

#### 基础对照示例

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

#### iOS 场景与补充示例

iOS中的应用：
- UIView和CALayer的职责分离
- UITableViewDataSource和 UITableViewDelegate分离

```swift
// ❌ 违反单一职责
class UserViewController: UIViewController {
    // 既负责UI展示，又负责网络请求，还负责数据存储
    func loadUserData() { }
    func displayUser() { }
    func saveUser() { }
}

// ✅ 遵循单一职责
class UserViewController: UIViewController {
    private let userService = UserService()
    private let userView = UserView()

    override func viewDidLoad() {
        userService.loadUser { user in
            userView.display(user)
        }
    }
}
```

### 1.5 开闭原则（OCP）

**核心原则**：对已识别的变化点，通过扩展实现支持新行为，减少修改稳定调用者。不是禁止修改任何旧代码；新增 extension 也不自动证明设计符合 OCP。

#### 基础对照示例

```swift
protocol Shape {
    func area() -> CGFloat
    func perimeter() -> CGFloat
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

// ✅ 扩展实现协议已声明的能力；泛型和协议调用者也能获得 Circle 的周长实现
extension Circle {
    func perimeter() -> CGFloat {
        return 2 * .pi * radius
    }
}

// perimeter 必须是 Shape 的 requirement，不能只依赖同名 extension 方法作为多态契约
```

#### iOS 场景与补充示例

iOS中的应用：
- Category为现有类添加功能
- Protocol定义抽象接口
- Strategy模式实现算法替换

```swift
// ❌ 每次修改都要改原有代码
class ImageProcessor {
    func processImage(_ image: UIImage) -> UIImage {
        // 处理逻辑
        return image
    }
}

// ✅ 通过扩展增加新功能，不修改原有代码
protocol ImageFilter {
    func apply(to image: UIImage) -> UIImage
}

class ImageProcessor {
    func processImage(_ image: UIImage, filters: [ImageFilter]) -> UIImage {
        var result = image
        for filter in filters {
            result = filter.apply(to: result)
        }
        return result
    }
}
```

> **勘误**：原周长示例只在 `Shape` 的 extension 中声明方法，会混淆“扩展方法”和“协议多态契约”。现在把 `perimeter()` 声明进协议。不要靠新加一个 extension 来判断是否符合开闭原则。

### 1.6 里氏替换原则（LSP）

**核心原则**：替代实现必须满足调用者依赖的行为契约，不能额外加强前置条件、削弱结果保证，或把原本可用的行为变成意外失败。

#### 基础对照示例

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

class FlyingBird: Flyable {
    func fly() {
        print("Flying...")
    }
}
```

#### iOS 场景与补充示例

iOS中的应用：
- KVO原理：动态创建NSKVONotifying_子类
- 所有UIViewController子类都能替换父类使用

```swift
class BaseViewController: UIViewController {
    func setupUI() {
        // 基础UI设置
    }
}

class CustomViewController: BaseViewController {
    override func setupUI() {
        super.setupUI()
        // 自定义UI设置
    }
}

// 任何使用BaseViewController的地方都可以用CustomViewController替换
```

> “所有 Bird 都能 fly”本身就是错误抽象。正例应只让确实会飞的类型采用 `Flyable`，不能只换成协议写法，却继续要求所有鸟都会飞。

### 1.7 接口隔离原则（ISP）

**核心原则**：调用者不应被迫依赖自己不需要的能力。按调用者所需的职责划分接口，而不是按方法数量把协议切得越碎越好。

#### 基础对照示例

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

#### iOS 场景与补充示例

iOS中的应用：
- UITableViewDelegate和UITableViewDataSource分离
- UIDataSource和UIDelegate分离

```swift
// ❌ 臃肿的协议
protocol TableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
}

// ✅ 职责分离的协议
protocol TableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
}

protocol TableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
}
```

### 1.8 依赖倒置原则（DIP）

**核心原则**：高层业务规则与底层技术实现通过合适的抽象协作；业务不反向依赖具体网络或存储实现。DI 是装配依赖的方法，DIP 是依赖方向原则，两者不能直接画等号。

#### 基础对照示例

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

#### iOS 场景与补充示例

iOS中的应用：
- Protocol定义抽象接口
- Dependency Injection注入依赖

```swift
// ❌ 直接依赖具体实现
class OrderService {
    let database = MySQLDatabase() // 直接依赖具体数据库

    func saveOrder(_ order: Order) {
        database.save(order)
    }
}

// ✅ 依赖抽象
protocol Database {
    func save(_ entity: Any)
}

class OrderService {
    let database: Database // 依赖抽象

    init(database: Database) {
        self.database = database
    }

    func saveOrder(_ order: Order) {
        database.save(order)
    }
}
```

## 2. 页面架构：MVC、MVP、MVVM、VIPER

先判断**什么职责需要独立出来**，再选择名字。下面的结构图表示角色协作，不能直接当作代码依赖方向图；实际依赖应看类型引用、协议归属和装配位置。

### 2.1 MVC：让 Controller 协调，而不是包办

MVC 中 Model 不只是几个属性：它还承载应用数据及相关处理规则；View 负责展示与交互；Controller 协调两者。Apple 的 Cocoa MVC 描述强调 Model 与 View 通常通过 Controller 沟通，而不是要求它们彼此强耦合。见文末 Apple 原始资料。

**结构：**
```
┌─────────────────────────────────────┐
│           Model (数据层)             │
│  - 数据模型                          │
│  - 业务逻辑                          │
│  - 数据存储                          │
└─────────────────────────────────────┘
         ↕                    ↕
┌─────────────────────────────────────┐
│        Controller (控制层)           │
│  - 协调Model和View                   │
│  - 处理用户交互                      │
│  - 更新Model和View                   │
└─────────────────────────────────────┘
         ↕                    ↕
┌─────────────────────────────────────┐
│           View (视图层)              │
│  - UI展示                            │
│  - 用户交互                          │
│  - 动画效果                          │
└─────────────────────────────────────┘
```

**实现示例：**
```swift
// Model
struct User {
    let id: String
    var name: String
    var email: String
}

// Controller
class UserViewController: UIViewController {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!

    var user: User? {
        didSet {
            updateView()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadUser()
    }

    func loadUser() {
        // 模拟网络请求
        UserService.fetchUser { [weak self] user in
            self?.user = user
        }
    }

    func updateView() {
        guard let user = user else { return }
        nameLabel.text = user.name
        emailLabel.text = user.email
    }

    @IBAction func saveButtonTapped(_ sender: UIButton) {
        guard var user = user else { return }
        user.name = nameLabel.text ?? ""
        self.user = user
        UserService.updateUser(user)
    }
}

// View
// Interface Builder或代码创建的UI界面
```

**优缺点：**
```
优点：
1. 简单直观，易于理解
2. 代码总量少
3. iOS原生支持

缺点：
1. 若 Model、View 与具体依赖混在 Controller 中，会形成实现层面的耦合
2. Controller容易变成"大胖子"
3. 若逻辑依赖 VC 生命周期和具体外部实现，会增加测试难度；这不是 MVC 必然不可测试
4. 不利于代码复用

适用场景：
- 简单的页面
- 快速原型开发
- 学习和演示项目
```

#### UIKit 中 UIViewController 的位置

- 在 MVC 角色划分中，`UIViewController` 主要承担 Controller：管理视图生命周期、协调交互和展示。
- View 不需要通过 IBOutlet 直接依赖 Model；IBOutlet 本身也不是数据绑定机制。
- Controller 同时持有 Model 和 View，不等于已经实现双向绑定。
- MVC 写胖时，先识别数据访问、业务规则和展示转换的独立职责；不必先给整个 App 更换架构名称。

**测试切入点**：抽出的格式化规则和业务行为可以独立验证；页面测试只验证交互与展示衔接。

### 2.2 MVP：Presenter 驱动被动 View

**结构：**
```
┌─────────────────────────────────────┐
│           Model (数据层)             │
│  - 数据模型                          │
│  - 业务逻辑                          │
└─────────────────────────────────────┘
         ↕                    ↕
┌─────────────────────────────────────┐
│        Presenter (展示层)           │
│  - 处理用户交互                      │
│  - 更新Model                         │
│  - 更新View                          │
└─────────────────────────────────────┘
         ↕                    ↕
┌─────────────────────────────────────┐
│           View (视图层)              │
│  - UI展示                            │
│  - 传递用户交互给Presenter            │
│  - 被动接收更新指令                   │
└─────────────────────────────────────┘
```

**实现示例：**
```swift
// Model
struct User {
    let id: String
    var name: String
    var email: String
}

// View Protocol
protocol UserView: AnyObject {
    func showLoading()
    func hideLoading()
    func displayName(_ name: String)
    func displayEmail(_ email: String)
    func showError(_ message: String)
}

// Presenter
class UserPresenter {
    private weak var view: UserView?
    private var user: User?

    init(view: UserView) {
        self.view = view
    }

    func loadUser() {
        view?.showLoading()

        UserService.fetchUser { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let user):
                self.user = user
                self.updateView()
            case .failure(let error):
                self.view?.showError(error.localizedDescription)
            }

            self.view?.hideLoading()
        }
    }

    func updateName(_ name: String) {
        user?.name = name
        UserService.updateUser(user!)
    }

    private func updateView() {
        guard let user = user else { return }
        view?.displayName(user.name)
        view?.displayEmail(user.email)
    }
}

// View Controller
class UserViewController: UIViewController, UserView {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    private var presenter: UserPresenter!

    override func viewDidLoad() {
        super.viewDidLoad()
        presenter = UserPresenter(view: self)
        presenter.loadUser()
    }

    // UserView Protocol
    func showLoading() {
        activityIndicator.startAnimating()
    }

    func hideLoading() {
        activityIndicator.stopAnimating()
    }

    func displayName(_ name: String) {
        nameLabel.text = name
    }

    func displayEmail(_ email: String) {
        emailLabel.text = email
    }

    func showError(_ message: String) {
        showAlert(message: message)
    }

    @IBAction func saveButtonTapped(_ sender: UIButton) {
        presenter.updateName(nameLabel.text ?? "")
    }
}
```

**优缺点：**
```
优点：
1. View 通过 Presenter 的展示契约协作，不直接操作 Model
2. Presenter易于测试（纯逻辑）
3. View可以独立演化
4. 业务逻辑清晰

缺点：
1. Presenter容易变重
2. View接口可能很复杂
3. 需要维护更多的接口定义

适用场景：
- 中等复杂度的项目
- 需要较高测试覆盖率
- 团队对架构有一定理解
```

---

**测试切入点**：向 Presenter 注入数据依赖和一个记录调用的 View 替代实现，验证用户动作触发了什么展示命令。注意 Presenter 也可能写胖，移出 VC 并不自动消除职责混杂。

### 2.3 MVVM：抽出展示状态与转换逻辑

ViewModel 对外提供页面所需状态和交互入口，不应直接操作具体 View。网络传输、缓存与可复用业务规则不必全塞进 ViewModel；它可以调用独立的用例或数据访问模块。

绑定可以用回调、观察、Combine 或其他机制实现。采用 MVVM 并不强制采用 Combine，也不要求 ViewModel 的属性与 Model 一一对应。

#### 2.3.1 基础 MVVM：KVO 绑定

**结构：**
```
┌─────────────────────────────────────┐
│           Model (数据层)             │
│  - 数据模型                          │
│  - 业务逻辑                          │
│  - 数据存储                          │
└─────────────────────────────────────┘
         ↕                    ↕
┌─────────────────────────────────────┐
│       ViewModel (视图模型)           │
│  - 展示与交互逻辑                    │
│  - 数据转换                          │
│  - 属性变化通知                      │
└─────────────────────────────────────┘
         ↕                    ↕
┌─────────────────────────────────────┐
│           View (视图层)              │
│  - UI展示                            │
│  - 绑定ViewModel属性                │
│  - 用户交互                          │
└─────────────────────────────────────┘
```

**实现示例（使用KVO）：**
```swift
// Model
struct User {
    let id: String
    var name: String
    var email: String
}

// ViewModel
class UserViewModel: NSObject {
    @objc dynamic var userName: String = ""
    @objc dynamic var userEmail: String = ""
    @objc dynamic var isLoading: Bool = false

    private var user: User?

    override init() {
        super.init()
    }

    func loadUser() {
        isLoading = true

        UserService.fetchUser { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let user):
                self.user = user
                self.userName = user.name
                self.userEmail = user.email
            case .failure:
                self.userName = "Error"
                self.userEmail = "Error"
            }

            self.isLoading = false
        }
    }

    func updateName(_ name: String) {
        guard var user = user else { return }
        user.name = name
        self.user = user
        UserService.updateUser(user)
    }
}

// View Controller
class UserViewController: UIViewController {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    private var viewModel: UserViewModel!
    private var userNameObserver: NSKeyValueObservation?
    private var userEmailObserver: NSKeyValueObservation?
    private var isLoadingObserver: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel = UserViewModel()
        setupBindings()
        viewModel.loadUser()
    }

    func setupBindings() {
        // 使用KVO观察ViewModel属性变化
        userNameObserver = viewModel.observe(\.userName) { [weak self] viewModel, change in
            let name = viewModel.userName
            DispatchQueue.main.async { [weak self] in
                self?.nameLabel.text = name
            }
        }

        userEmailObserver = viewModel.observe(\.userEmail) { [weak self] viewModel, change in
            let email = viewModel.userEmail
            DispatchQueue.main.async { [weak self] in
                self?.emailLabel.text = email
            }
        }

        isLoadingObserver = viewModel.observe(\.isLoading) { [weak self] viewModel, change in
            let loading = viewModel.isLoading
            DispatchQueue.main.async { [weak self] in
                if loading {
                    self?.activityIndicator.startAnimating()
                } else {
                    self?.activityIndicator.stopAnimating()
                }
            }
        }
    }

    @IBAction func saveButtonTapped(_ sender: UIButton) {
        viewModel.updateName(nameLabel.text ?? "")
    }

    deinit {
        // 清理观察者
        userNameObserver?.invalidate()
        userEmailObserver?.invalidate()
        isLoadingObserver?.invalidate()
    }
}
```

> KVO 绑定只解决“怎样收到变化”，不解决请求之间的竞态。真实页面仍需约定 ViewModel 状态的串行访问方式，并处理取消和过期结果。

#### 2.3.2 响应式 MVVM：Combine 绑定

**使用Combine的MVVM：**
```swift
import Combine

// ViewModel
class UserViewModel {
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private var user: User?
    private var cancellables = Set<AnyCancellable>()

    func loadUser() {
        isLoading = true

        UserService.fetchUser()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] user in
                self?.user = user
                self?.userName = user.name
                self?.userEmail = user.email
            }
            .store(in: &cancellables)
    }

    func updateName(_ name: String) {
        guard var user = user else { return }
        user.name = name
        self.user = user
        UserService.updateUser(user)
            .sink { completion in
                print("Update completed")
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
}

// View Controller
class UserViewController: UIViewController {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    private var viewModel = UserViewModel()
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
        viewModel.loadUser()
    }

    func setupBindings() {
        // 使用Combine绑定ViewModel属性
        viewModel.$userName
            .assign(to: \.text, on: nameLabel)
            .store(in: &cancellables)

        viewModel.$userEmail
            .assign(to: \.text, on: emailLabel)
            .store(in: &cancellables)

        viewModel.$isLoading
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.activityIndicator.startAnimating()
                } else {
                    self?.activityIndicator.stopAnimating()
                }
            }
            .store(in: &cancellables)

        viewModel.$errorMessage
            .sink { [weak self] message in
                if !message.isEmpty {
                    self?.showAlert(message: message)
                }
            }
            .store(in: &cancellables)
    }

    @IBAction func saveButtonTapped(_ sender: UIButton) {
        viewModel.updateName(nameLabel.text ?? "")
    }
}
```

**优缺点：**
```
优点：
1. ViewModel可以独立测试
2. 数据绑定自动更新View
3. 响应式编程，代码简洁
4. 支持复杂的数据流

缺点：
1. 学习曲线较陡
2. 调试相对困难
3. 不恰当的强捕获和订阅所有权可能形成循环引用；采用 Combine 本身并不等于泄漏
4. 需要仔细管理生命周期

适用场景：
- 复杂的数据绑定场景
- 需要高测试覆盖率
- 团队熟悉响应式编程
- 长期维护的项目
```

---

#### 2.3.3 SwiftUI / Combine 的补充绑定示例

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

> `@StateObject` 与 `@ObservedObject` 的选择还涉及对象由谁创建和持有，不能只看“用了 MVVM”。上面各示例的数据类型和数据依赖是独立约定。

**测试切入点**：不用启动 VC，向 ViewModel 输入动作和数据响应，验证展示状态、错误、加载状态及转换结果。依赖注入方式见第 4 章。

### 2.4 VIPER：进一步区分展示、用例与路由

**组件划分：**
```
┌─────────────────────────────────────┐
│           View (视图层)             │
│  - UI展示                            │
│  - 用户交互                          │
│  - 通知Presenter用户事件             │
└─────────────────────────────────────┘
         ↕
┌─────────────────────────────────────┐
│       Presenter (展示层)            │
│  - 处理用户交互                      │
│  - 协调各个组件                      │
│  - 不包含业务逻辑                    │
└─────────────────────────────────────┘
         ↕                ↕         ↕
    ┌─────────┐  ┌──────────┐  ┌─────────┐
    │ Interactor│  │  Router │  │ Entity  │
    │  (交互层) │  │ (路由)  │  │ (实体)  │
    └──────────┘  └─────────┘  └─────────┘
```

**各组件职责：**
```
View：
- 展示UI
- 接收用户交互
- 通知Presenter

Presenter：
- 处理View事件
- 调用Interactor
- 更新View
- 协调各个组件

Interactor：
- 业务逻辑处理
- 数据获取和转换
- 调用Router进行页面跳转

Router：
- 页面跳转
- 组件导航
- 传递数据

Entity：
- 数据模型
- 不包含业务逻辑
```

#### 2.4.1 完整职责协作示例

```swift
// Entity
struct User {
    let id: String
    var name: String
    var email: String
}

// Interactor Protocol
protocol UserInteractor: AnyObject {
    func fetchUser()
    func updateUserName(_ name: String)
}

// Router Protocol
protocol UserRouter: AnyObject {
    func navigateToProfile(userId: String)
    func navigateToSettings()
}

// Presenter Protocol
protocol UserPresenter: AnyObject {
    func viewDidLoad()
    func didTapSaveButton(withName name: String)
    func didTapSettingsButton()
}

// View Protocol
protocol UserView: AnyObject {
    func showLoading()
    func hideLoading()
    func displayName(_ name: String)
    func displayEmail(_ email: String)
    func showError(_ message: String)
}

// Interactor Implementation
class UserInteractorImpl: UserInteractor {
    weak var presenter: UserPresenter?
    var user: User?

    func fetchUser() {
        UserService.fetchUser { [weak self] result in
            switch result {
            case .success(let user):
                self?.user = user
                self?.presentFetchedUser(user)
            case .failure(let error):
                self?.presentError(error.localizedDescription)
            }
        }
    }

    func updateUserName(_ name: String) {
        user?.name = name
        UserService.updateUser(user!) { [weak self] in
            self?.didUpdateUser()
        }
    }

    private func presentFetchedUser(_ user: User) {
        presenter?.didFetchUser(user.name, email: user.email)
    }

    private func presentError(_ message: String) {
        presenter?.didFailWithError(message)
    }

    private func didUpdateUser() {
        presenter?.didUpdateUserSuccessfully()
    }
}

// Router Implementation
class UserRouterImpl: UserRouter {
    weak var viewController: UIViewController?

    func navigateToProfile(userId: String) {
        let profileVC = ProfileViewController(userId: userId)
        viewController?.navigationController?.pushViewController(profileVC, animated: true)
    }

    func navigateToSettings() {
        let settingsVC = SettingsViewController()
        viewController?.navigationController?.pushViewController(settingsVC, animated: true)
    }
}

// Presenter Implementation
class UserPresenterImpl: UserPresenter {
    weak var view: UserView?
    var interactor: UserInteractor?
    var router: UserRouter?

    func viewDidLoad() {
        view?.showLoading()
        interactor?.fetchUser()
    }

    func didTapSaveButton(withName name: String) {
        interactor?.updateUserName(name)
    }

    func didTapSettingsButton() {
        router?.navigateToSettings()
    }

    func didFetchUser(_ name: String, email: String) {
        view?.hideLoading()
        view?.displayName(name)
        view?.displayEmail(email)
    }

    func didFailWithError(_ message: String) {
        view?.hideLoading()
        view?.showError(message)
    }

    func didUpdateUserSuccessfully() {
        view?.showError("User updated successfully")
    }
}

// View Implementation
class UserViewController: UIViewController, UserView {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    var presenter: UserPresenter?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupVIPER()
        presenter?.viewDidLoad()
    }

    func setupVIPER() {
        let presenter = UserPresenterImpl()
        let interactor = UserInteractorImpl()
        let router = UserRouterImpl()

        presenter.view = self
        presenter.interactor = interactor
        presenter.router = router

        interactor.presenter = presenter
        router.viewController = self

        self.presenter = presenter
    }

    @IBAction func saveButtonTapped(_ sender: UIButton) {
        presenter?.didTapSaveButton(withName: nameLabel.text ?? "")
    }

    @IBAction func settingsButtonTapped(_ sender: UIButton) {
        presenter?.didTapSettingsButton()
    }

    // UserView Protocol
    func showLoading() {
        activityIndicator.startAnimating()
    }

    func hideLoading() {
        activityIndicator.stopAnimating()
    }

    func displayName(_ name: String) {
        nameLabel.text = name
    }

    func displayEmail(_ email: String) {
        emailLabel.text = email
    }

    func showError(_ message: String) {
        showAlert(message: message)
    }
}
```

**优缺点：**
```
优点：
1. 展示、业务和路由职责显式分离
2. 可分别验证 Presenter、Interactor 和路由行为；测试质量仍取决于具体设计
3. 易于维护和扩展
4. 支持大型项目

缺点：
1. 代码量大幅增加
2. 学习曲线陡峭
3. 初期开发效率低
4. 过度设计风险高

适用场景：
- 大型复杂项目
- 需要高测试覆盖率
- 团队规模较大
- 长期维护的基线项目
```

---

#### 2.4.2 协议交互的精简补充示例

```swift
// Protocol
protocol HomePresentable: AnyObject {
    var interactor: HomeInteractable? { get set }
    var router: HomeRoutable? { get set }
}

protocol HomeInteractable: AnyObject {
    var presenter: HomePresentable? { get set }
    func fetchUsers()
}

protocol HomeRoutable: AnyObject {
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

**测试切入点**：分别验证 Presenter 如何翻译展示事件、Interactor 如何执行用例、Router 如何接收导航请求。文件和协议更多并不代表测试覆盖会自动提高。

## 3. 状态与数据流：MVI、TCA

这部分重点是“动作怎样改变状态、异步结果怎样返回”，与 MVC / MVVM 的角色划分、Clean Architecture 的依赖规则不是完全互斥的选项。

### 3.1 MVI：意图驱动状态变化

**一句话理解**：MVI就是把"用户点击按钮"变成"发送意图"，然后用"处理函数"计算新状态，最后更新界面。

**核心思想**：
```
用户操作 → 意图(Intent) → 处理(Reducer) → 新状态(Model) → 更新界面(View)
```

**生活类比**：
> 就像在餐厅点餐：
> - **Intent（意图）**：你说"我要一份宫保鸡丁"
> - **Reducer（厨师）**：根据你的意图做菜
> - **Model（菜品）**：做好的宫保鸡丁
> - **View（餐桌）**：把菜端到你面前

**为什么叫MVI？**
- **Model**：当前状态；本例通过返回新值更新状态，是否采用不可变表示取决于实现
- **View**：界面，只负责显示
- **Intent**：意图，描述用户想做什么

**记忆口诀**：
> MVI = 用户有意图(Intent) → 电脑处理(Reducer) → 产生新状态(Model) → 界面更新(View)

**简单代码示例**：

```swift
// 1. 意图：用户想做什么
enum CounterIntent {
    case 加1
    case 减1
}

// 2. 状态：当前的数据
struct CounterModel {
    let 数值: Int
}

// 3. 处理：根据意图计算新状态（纯函数，输入相同输出一定相同）
func 计数器处理(state: CounterModel, intent: CounterIntent) -> CounterModel {
    switch intent {
    case .加1:
        return CounterModel(数值: state.数值 + 1)
    case .减1:
        return CounterModel(数值: state.数值 - 1)
    }
}

// 4. ViewModel：连接View和Model
class CounterViewModel: ObservableObject {
    @Published var 状态 = CounterModel(数值: 0)

    func 处理意图(_ intent: CounterIntent) {
        状态 = 计数器处理(state: 状态, intent: intent)
    }
}
```

**优点**：
- ✅ **单向数据流**：数据流向清晰，容易理解
- ✅ **意图驱动**：用户操作一目了然
- ✅ **易于测试**：处理函数是纯函数，输入输出确定
- ✅ **状态演进集中**：本例返回新的状态值；结构体本身并不自动保证不可变或线程安全
- ✅ **可从小模型开始**：先显式描述动作和状态，再按需求增加副作用处理

**缺点**：
- ❌ **需要定义事件衔接方式**：可以采用回调、观察、Combine 等；MVI 不强制某个库
- ❌ **意图定义多**：每个用户操作都要定义Intent
- ❌ **状态更新成本**：大型状态的复制、计算和渲染需要测量，不能仅凭“结构体”判断性能

**适用场景**：
- ✅ 用户动作与异步事件交织，需要清楚地描述状态变化的功能
- ✅ 需要清晰的数据流
- ✅ SwiftUI项目
- ✅ 团队协作（职责明确）

**测试切入点**：给定旧状态和 Intent，断言新状态；有副作用时，分别验证触发条件和结果事件。计数器例子的状态函数是纯函数，但完整功能还要处理异步工作。

### 3.2 TCA：可组合的状态、动作与副作用

TCA 的核心是状态管理、功能组合、副作用管理、依赖与测试。它支持 SwiftUI，也支持 UIKit；可以组合和作用域化多个功能，不必把整个 App 的所有状态塞进一个巨大 Store。下面旧例中的“银行系统”只是帮助记忆，不是数据库设计建议。

**核心思想**：
```
唯一状态库(Store) → 接收操作(Action) → 处理函数(Reducer)计算新状态 → 界面自动更新
```

**生活类比**：
> 就像银行的账户系统：
> - **State（账户余额）**：唯一的数据源
> - **Action（存取款操作）**：你要存钱或取钱
> - **Reducer（银行系统）**：计算新的余额
> - **Store（状态与动作的运行入口）**：存储所有账户信息
> - **View（ATM屏幕）**：显示余额

**为什么叫TCA？**
- **T**he：这个（特指一种架构）
- **C**omposable：可组合的（小的Reducer可以组合成大的）
- **A**rchitecture：架构

**5个核心概念**：
```
1. State（状态）：所有数据，唯一真理来源
2. Action（操作）：描述状态变化的事件，如"加1"、"减1"
3. Reducer（处理器）：纯函数，接收旧状态+操作，返回新状态
4. Store（仓库）：管理状态和处理器
5. Effect（副作用）：处理异步操作（网络请求、数据库）
```

**记忆口诀**：
> TCA = 银行存取款系统
> - Store = 当前功能的状态与动作入口，可与子功能组合
> - Action = 存取款单（你的操作）
> - Reducer = 柜员（计算新余额）
> - State = 账户余额（当前状态）
> - Effect = 联网验证（异步操作）

#### 3.2.1 现代 TCA 的阅读入口

下面是独立编写的最小计数器示例，采用官方 README 当前展示的 `@Reducer`、`@ObservableState`、`StoreOf` 风格。它只演示同步状态变化；异步功能还需设计 Effect、取消和可替换依赖。

```swift
import ComposableArchitecture
import SwiftUI

@Reducer
struct CounterFeature {
    @ObservableState
    struct State: Equatable {
        var count = 0
    }

    enum Action {
        case increment
        case decrement
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .increment:
                state.count += 1
            case .decrement:
                state.count -= 1
            }
            return .none
        }
    }
}

struct CounterScreen: View {
    let store: StoreOf<CounterFeature>

    var body: some View {
        VStack {
            Text("当前计数：\(store.count)")
            Button("增加") { store.send(.increment) }
            Button("减少") { store.send(.decrement) }
        }
    }
}

// 在装配位置创建 Store，而不是在每次 View.body 求值时重新创建。
let counterStore = Store(initialState: CounterFeature.State()) {
    CounterFeature()
}
```

#### 3.2.2 历史片段：计数器写法对照

> **历史 API / 概念伪代码**：原笔记混用了闭包式 `Reducer` 的泛型与不同版本 Store 写法，以下保留其状态—动作关系，不保证对应某一个可直接编译的 TCA 版本。新项目优先参考上一节与官方迁移指南。

```swift
// 1. 状态：计数器的值
struct CounterState {
    var count: Int = 0
}

// 2. 操作：可以做什么
enum CounterAction {
    case 加1
    case 减1
}

// 3. 处理器：根据操作计算新状态
let counterReducer = Reducer<CounterState, CounterAction> { state, action in
    switch action {
    case .加1:
        state.count += 1
        return .none  // 无副作用
    case .减1:
        state.count -= 1
        return .none
    }
}

// 4. 创建Store
let store = Store(
    initialState: CounterState(),
    reducer: counterReducer
)

// 5. SwiftUI界面使用
struct CounterView: View {
    let store: Store<CounterState, CounterAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                Text("计数: \(viewStore.count)")
                Button("+") { viewStore.send(.加1) }
                Button("-") { viewStore.send(.减1) }
            }
        }
    }
}
```

#### 3.2.3 历史示例：计数器与用户列表

> **旧版 Environment / Combine / WithViewStore 风格**：保留来理解依赖传递、请求 Effect 与响应 Action；`User`、网络实现及其标识约定需由独立 Demo 补齐。不要将此处旧 API 与现代宏写法混用。

```swift
import ComposableArchitecture
import Combine

// 1. 定义State
struct AppState {
    var count: Int = 0
    var users: [User] = []
    var isLoading: Bool = false
    var errorMessage: String?
}

// 2. 定义Action
enum AppAction {
    case increment
    case decrement
    case fetchUsers
    case usersResponse(Result<[User], Error>)
}

// 3. 定义Environment（外部依赖）
struct AppEnvironment {
    var apiService: APIService
    var mainQueue: AnySchedulerOf<DispatchQueue>
}

// 4. 定义Reducer
let appReducer = Reducer<AppState, AppAction, AppEnvironment> {
    state, action, environment in

    switch action {
    case .increment:
        state.count += 1
        return .none

    case .decrement:
        state.count -= 1
        return .none

    case .fetchUsers:
        state.isLoading = true
        state.errorMessage = nil

        return environment.apiService.fetchUsers()
            .receive(on: environment.mainQueue)
            .catchToEffect(AppAction.usersResponse)

    case .usersResponse(.success(let users)):
        state.users = users
        state.isLoading = false
        return .none

    case .usersResponse(.failure(let error)):
        state.isLoading = false
        state.errorMessage = error.localizedDescription
        return .none
    }
}

// 5. 创建API Service
struct APIService {
    func fetchUsers() -> Effect<[User], Error> {
        return Future { promise in
            // 模拟网络请求
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let users = [
                    User(id: 1, name: "张三"),
                    User(id: 2, name: "李四")
                ]
                promise(.success(users))
            }
        }
        .eraseToEffect()
    }
}

// 6. 创建Store
let store = Store(
    initialState: AppState(),
    reducer: appReducer,
    environment: AppEnvironment(
        apiService: APIService(),
        mainQueue: .main.eraseToAnyScheduler()
    )
)

// 7. SwiftUI View
struct ContentView: View {
    let store: Store<AppState, AppAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            List {
                Section(header: Text("计数器")) {
                    HStack {
                        Text("Count: \(viewStore.count)")
                        Spacer()
                        Button("-") { viewStore.send(.decrement) }
                        Button("+") { viewStore.send(.increment) }
                    }
                }

                Section(header: Text("用户列表")) {
                    if viewStore.isLoading {
                        Text("加载中...")
                    } else if let errorMessage = viewStore.errorMessage {
                        Text("错误: \(errorMessage)")
                            .foregroundColor(.red)
                    } else {
                        ForEach(viewStore.users) { user in
                            Text(user.name)
                        }
                    }
                }
            }
            .navigationTitle("TCA Demo")
            .onAppear {
                viewStore.send(.fetchUsers)
            }
        }
    }
}

// 8. Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            store: Store(
                initialState: AppState(),
                reducer: appReducer,
                environment: AppEnvironment(
                    apiService: APIService(),
                    mainQueue: .main.eraseToAnyScheduler()
                )
            )
        )
    }
}
```

#### 3.2.4 历史示例：用户登录

> 同样采用旧版 API。重点观察“输入变化 → 登录动作 → 异步结果动作 → 加载 / 错误状态”。登录数据类型和 API 实现为项目依赖，不由本文提供。

```swift
// 1. 登录State
struct LoginState {
    var email: String = ""
    var password: String = ""
    var isLoading: Bool = false
    var loginResponse: LoginResponse?
    var errorMessage: String?
}

// 2. 登录Action
enum LoginAction {
    case emailChanged(String)
    case passwordChanged(String)
    case loginButtonTapped
    case loginResponse(Result<LoginResponse, Error>)
}

// 3. 登录Environment
struct LoginEnvironment {
    var apiService: APIService
    var mainQueue: AnySchedulerOf<DispatchQueue>
}

// 4. 登录Reducer
let loginReducer = Reducer<LoginState, LoginAction, LoginEnvironment> {
    state, action, environment in

    switch action {
    case .emailChanged(let email):
        state.email = email
        return .none

    case .passwordChanged(let password):
        state.password = password
        return .none

    case .loginButtonTapped:
        state.isLoading = true
        state.errorMessage = nil

        return environment.apiService.login(email: state.email, password: state.password)
            .receive(on: environment.mainQueue)
            .catchToEffect(LoginAction.loginResponse)

    case .loginResponse(.success(let response)):
        state.isLoading = false
        state.loginResponse = response
        return .none

    case .loginResponse(.failure(let error)):
        state.isLoading = false
        state.errorMessage = error.localizedDescription
        return .none
    }
}

// 5. 登录View
struct LoginView: View {
    let store: Store<LoginState, LoginAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            Form {
                TextField("邮箱", text: viewStore.binding(get: \.email, send: LoginAction.emailChanged))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)

                SecureField("密码", text: viewStore.binding(get: \.password, send: LoginAction.passwordChanged))

                if viewStore.isLoading {
                    ProgressView()
                } else {
                    Button("登录") {
                        viewStore.send(.loginButtonTapped)
                    }
                    .disabled(!viewStore.isValidForm)
                }

                if let errorMessage = viewStore.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("登录")
        }
    }
}

// ViewStore扩展
extension LoginState {
    var isValidForm: Bool {
        return !email.isEmpty && !password.isEmpty && password.count >= 6
    }
}
```

#### 3.2.5 收益、代价与测试

- **收益**：动作和状态显式；子功能可以组合；副作用和依赖可以替换，从而验证异步事件链。
- **代价**：需要理解状态划分、动作建模、Effect、取消、依赖与版本迁移；采用库会增加学习和维护成本。
- **不要混淆**：Reducer 可以描述状态变化并返回 Effect，不代表完整功能“完全没有副作用”。记录动作或回放状态，也不意味着默认就能撤销网络请求等外部副作用；不要把“任意时间旅行”当成开箱即用保证。
- **测试切入点**：验证发送动作后的状态，以及 Effect 产生的后续动作。具体 TestStore 用法以项目锁定版本为准。

## 4. 分层与依赖：Clean Architecture、DI

### 4.1 Clean Architecture 的核心：依赖朝业务规则方向

Clean Architecture 不是“再加三个文件夹”，也不是页面数量达到某个阈值后必须采用的框架。它强调核心规则不反向依赖具体展示、网络和存储实现。

常见 iOS 划分如下：

```text
代码依赖方向（不是网络调用时序）：

Presentation ───────→ Domain ←─────── Data
View / ViewModel      Entity          Repository 实现
ViewController        Use Case        API / Database / Cache
                      Repository 协议

装配位置：创建具体实现，并将它们注入需要这些协议的对象。
```

| 层 | 主要职责 | 依赖约束 |
|----|----------|----------|
| Presentation | 展示状态、交互响应、页面协作 | 可依赖 Domain，不要求业务用例知道 UIKit / SwiftUI |
| Domain | 核心规则、实体、用例、所需的数据访问协议 | 不依赖具体页面和具体数据实现 |
| Data | 实现仓库协议，访问网络、数据库和缓存 | 依赖 Domain 的契约，隐藏具体技术细节 |

**Model 和 Domain 不等同于数据库；Repository 协议与实现也不应都机械放在 Data。** 洋葱类比里核心是业务规则，不能把数据访问实现当作最内层。

MVVM 可以用于 Presentation，同时遵守 Clean 的依赖方向。MVVM 不强制 Combine，MVC 也不强制把所有业务逻辑放进 Controller。

#### 4.1.1 Combine 用例的最小示例

> 下面原有示例选择 `AnyPublisher` 作为用例接口，因此 Domain 对 Combine 有明确依赖，不能再称为“完全不依赖框架”。若需要更严格的技术隔离，应重新选择接口表示；关键是明确选择及其代价。

```swift
// 1. Domain Layer（不依赖具体 UI / 数据实现；本例接口选择了 Combine）

// 实体：纯数据
struct User {
    let id: String
    let name: String
    let email: String
}

// 用例：业务逻辑
protocol FetchUsersUseCase {
    func execute() -> AnyPublisher<[User], Error>
}

class FetchUsersUseCaseImpl: FetchUsersUseCase {
    private let userRepository: UserRepository  // 依赖接口，不依赖具体实现

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    func execute() -> AnyPublisher<[User], Error> {
        return userRepository.fetchUsers()
    }
}

// 2. Data Layer（数据层）

// 仓库接口（在Domain层定义）
protocol UserRepository {
    func fetchUsers() -> AnyPublisher<[User], Error>
}

// 仓库实现（在Data层实现）
class UserRepositoryImpl: UserRepository {
    private let apiService: APIService

    init(apiService: APIService) {
        self.apiService = apiService
    }

    func fetchUsers() -> AnyPublisher<[User], Error> {
        return apiService.fetchUsers()
    }
}

// 3. Presentation Layer（展示层）

class UserListViewModel: ObservableObject {
    @Published var users: [User] = []

    private let fetchUsersUseCase: FetchUsersUseCase
    private var cancellables = Set<AnyCancellable>()

    init(fetchUsersUseCase: FetchUsersUseCase) {
        self.fetchUsersUseCase = fetchUsersUseCase
    }

    func fetchUsers() {
        fetchUsersUseCase.execute()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in
                // 实际页面应把失败转换为错误展示状态。
            }, receiveValue: { [weak self] users in
                self?.users = users
            })
            .store(in: &cancellables)
    }
}
```

#### 4.1.2 用户列表：缓存、仓库、用例、ViewModel 与装配

保留原有用户列表完整链路。缓存命中即返回只是示例策略；实际功能应约定有效期、失效条件、是否继续刷新和重复请求行为。

```swift
// 1. Domain Layer（业务层，最核心）

// Entity（实体）
struct User: Identifiable {
    let id: String
    let name: String
    let email: String
}

// Use Case（用例协议）
protocol FetchUsersUseCase {
    func execute() -> AnyPublisher<[User], Error>
}

// Use Case实现
class FetchUsersUseCaseImpl: FetchUsersUseCase {
    private let userRepository: UserRepository

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    func execute() -> AnyPublisher<[User], Error> {
        return userRepository.fetchUsers()
    }
}

// Repository协议（仓库）
protocol UserRepository {
    func fetchUsers() -> AnyPublisher<[User], Error>
    func fetchUser(id: String) -> AnyPublisher<User, Error>
}

// 2. Data Layer（数据层）

// Repository实现
class UserRepositoryImpl: UserRepository {
    private let apiService: APIService
    private let cacheService: CacheService

    init(apiService: APIService, cacheService: CacheService) {
        self.apiService = apiService
        self.cacheService = cacheService
    }

    func fetchUsers() -> AnyPublisher<[User], Error> {
        // 先从缓存读取
        if let cachedUsers = cacheService.loadUsers() {
            return Just(cachedUsers)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }

        // 缓存没有，从网络获取
        return apiService.fetchUsers()
            .handleEvents(receiveOutput: { users in
                self.cacheService.saveUsers(users)
            })
            .eraseToAnyPublisher()
    }

    func fetchUser(id: String) -> AnyPublisher<User, Error> {
        return apiService.fetchUser(id: id)
    }
}

// 3. Presentation Layer（展示层）

// ViewModel
class UserListViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let fetchUsersUseCase: FetchUsersUseCase
    private var cancellables = Set<AnyCancellable>()

    init(fetchUsersUseCase: FetchUsersUseCase) {
        self.fetchUsersUseCase = fetchUsersUseCase
    }

    func fetchUsers() {
        isLoading = true
        errorMessage = nil

        fetchUsersUseCase.execute()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] users in
                self?.users = users
            }
            .store(in: &cancellables)
    }
}

// SwiftUI View
struct UserListView: View {
    @StateObject private var viewModel: UserListViewModel

    init(viewModel: UserListViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                Text("错误: \(errorMessage)")
                    .foregroundColor(.red)
            } else {
                ForEach(viewModel.users) { user in
                    Text(user.name)
                }
            }
        }
        .navigationTitle("用户列表")
        .onAppear {
            viewModel.fetchUsers()
        }
    }
}

// 4. Dependency Injection（依赖注入）

// DI Container
class DIContainer {
    static let shared = DIContainer()

    private init() {}

    lazy var apiService: APIService = {
        return APIServiceImpl()
    }()

    lazy var cacheService: CacheService = {
        return CacheServiceImpl()
    }()

    lazy var userRepository: UserRepository = {
        return UserRepositoryImpl(
            apiService: apiService,
            cacheService: cacheService
        )
    }()

    lazy var fetchUsersUseCase: FetchUsersUseCase = {
        return FetchUsersUseCaseImpl(
            userRepository: userRepository
        )
    }()

    func makeUserListViewModel() -> UserListViewModel {
        return UserListViewModel(
            fetchUsersUseCase: fetchUsersUseCase
        )
    }
}

// 5. 使用
struct ContentView: View {
    var body: some View {
        UserListView(
            viewModel: DIContainer.shared.makeUserListViewModel()
        )
    }
}
```

> DIContainer 的单例是原示例的装配选择，不是 DI 或 Clean 的必要条件。只在装配位置访问容器，把已解析的协议依赖传给业务对象；不要让每个对象自行调用 `DIContainer.shared` 查找依赖。

#### 4.1.3 登录：业务校验、仓库与展示状态

这里的邮箱和密码检查仅为业务规则示意，不是完整认证规范。错误类型、网络实现与 TokenStorage 由独立示例工程定义。

```swift
// 1. Domain Layer

// Entity
struct LoginCredentials {
    let email: String
    let password: String
}

struct AuthToken {
    let token: String
    let expiresAt: Date
}

// Use Case
protocol LoginUseCase {
    func execute(credentials: LoginCredentials) -> AnyPublisher<AuthToken, Error>
}

class LoginUseCaseImpl: LoginUseCase {
    private let authRepository: AuthRepository

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    func execute(credentials: LoginCredentials) -> AnyPublisher<AuthToken, Error> {
        // 验证邮箱格式
        guard credentials.email.contains("@") else {
            return Fail(error: AuthError.invalidEmail)
                .eraseToAnyPublisher()
        }

        // 验证密码长度
        guard credentials.password.count >= 6 else {
            return Fail(error: AuthError.passwordTooShort)
                .eraseToAnyPublisher()
        }

        // 调用Repository
        return authRepository.login(credentials)
    }
}

// Repository协议
protocol AuthRepository {
    func login(_ credentials: LoginCredentials) -> AnyPublisher<AuthToken, Error>
    func logout() -> AnyPublisher<Void, Error>
}

// 2. Data Layer

// Repository实现
class AuthRepositoryImpl: AuthRepository {
    private let apiService: APIService
    private let tokenStorage: TokenStorage

    init(apiService: APIService, tokenStorage: TokenStorage) {
        self.apiService = apiService
        self.tokenStorage = tokenStorage
    }

    func login(_ credentials: LoginCredentials) -> AnyPublisher<AuthToken, Error> {
        return apiService.login(email: credentials.email, password: credentials.password)
            .handleEvents(receiveOutput: { token in
                self.tokenStorage.save(token)
            })
            .eraseToAnyPublisher()
    }

    func logout() -> AnyPublisher<Void, Error> {
        return apiService.logout()
            .handleEvents(receiveOutput: { _ in
                self.tokenStorage.clear()
            })
            .eraseToAnyPublisher()
    }
}

// 3. Presentation Layer

// ViewModel
class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isLoggedIn: Bool = false

    private let loginUseCase: LoginUseCase
    private var cancellables = Set<AnyCancellable>()

    var isValidForm: Bool {
        email.contains("@") && password.count >= 6
    }

    init(loginUseCase: LoginUseCase) {
        self.loginUseCase = loginUseCase
    }

    func login() {
        let credentials = LoginCredentials(email: email, password: password)
        isLoading = true
        errorMessage = nil

        loginUseCase.execute(credentials: credentials)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] _ in
                self?.isLoggedIn = true
            }
            .store(in: &cancellables)
    }
}

// View
struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel

    init(viewModel: LoginViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            TextField("邮箱", text: $viewModel.email)
            SecureField("密码", text: $viewModel.password)

            if viewModel.isLoading {
                ProgressView()
            } else {
                Button("登录") {
                    viewModel.login()
                }
                .disabled(!viewModel.isValidForm)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .navigationTitle("登录")
    }
}
```

#### 4.1.4 收益、代价与验证方式

- **收益**：核心规则与具体技术选择分开；数据来源和展示可以独立替换；用例、仓库及展示状态有明确的测试位置。
- **代价**：协议、映射、装配和层间转交增多；若只是没有变化的简单操作，层层转发可能增加理解成本。
- **判断依据**：是否存在需要独立维护的业务规则、变化的数据来源和稳定的测试契约，而不是“20 个页面 / 5 人团队 / 3 年维护”的硬阈值。
- **跨平台注意**：可以共享规则与接口思路，但 iOS Swift 代码不会因采用 Clean 就自动与 Android 共享实现。

### 4.2 依赖注入（DI）：谁创建依赖，谁使用依赖

DIP 讨论依赖方向，DI 讨论把对象所需依赖交给它的方式。定义协议之后，如果业务仍在内部写死具体实现，测试和替换仍可能困难。

#### 4.2.1 构造函数注入

```swift
protocol UserService {
    func fetchUser() -> User
}

class UserViewModel {
    private let userService: UserService

    // 通过构造函数注入依赖
    init(userService: UserService) {
        self.userService = userService
    }

    func loadUser() {
        let user = userService.fetchUser()
        // 处理用户数据
    }
}

// 使用示例
class UserViewController: UIViewController {
    private var viewModel: UserViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()

        // 注入依赖
        let userService = UserServiceImpl()
        viewModel = UserViewModel(userService: userService)
    }
}
```

对象创建时就具备必需依赖，适合业务必需且生命周期稳定的依赖；在装配位置选择真实实现或测试替代实现。

#### 4.2.2 属性注入

```swift
class UserViewModel {
    // 通过属性注入依赖
    var userService: UserService?

    func loadUser() {
        guard let userService = userService else {
            return
        }

        let user = userService.fetchUser()
        // 处理用户数据
    }
}
```

适用于创建方式受框架限制或依赖确实可选的情况。若依赖必需，需明确“什么时候必须完成注入”，不要静默 return 掩盖装配错误。

#### 4.2.3 方法注入

```swift
class UserViewModel {
    // 通过方法注入依赖
    func loadUser(with service: UserService) {
        let user = service.fetchUser()
        // 处理用户数据
    }
}
```

---

适合只在某次操作需要的依赖或上下文，不必为了一个临时参数引入长期持有关系。

#### 4.2.4 测试替代实现与装配位置

沿用构造函数示例中的 `UserService` 契约，可以在测试中提供固定数据或可控错误，再验证 ViewModel 的行为。测试不应依赖真实网络是否可用。

```text
生产装配：RealUserService → UserViewModel
测试装配：FakeUserService → UserViewModel

测试关注：
- 给定响应，展示状态是否正确？
- 失败是否收口到错误和加载状态？
- 取消、重入、过期响应是否遵守约定？
```

### 4.3 页面导航与对象装配

VIPER 示例中的 Router，以及 MVVM 常配合的 Coordinator，都是把导航或流程协作集中起来的可选方式。不要仅因为“使用 MVVM”就给每个简单页面强制增加一套导航层。

- 页面发出用户意图或导航请求。
- 导航对象决定目标页面及其依赖装配。
- 明确父子导航对象、VC 和闭包之间的所有权，避免页面退出后仍被持有。
- URL Router、Target-Action、Protocol-Service 等跨模块通信细节转到独立组件化专题。

## 5. 架构对比、选型与混合实践

### 5.1 按问题比较，不按名字排名

| 方案 | 主要关注点 | 可以带来的收益 | 需要承担的代价 |
|------|------------|----------------|----------------|
| MVC | Model / View / Controller 协作 | 直接、装配少；独立 Model 行为仍可测试 | Controller 若包办太多职责容易混杂 |
| MVP | Presenter 主动驱动 View | 展示决策可以脱离真实 UI 验证 | View 协议与展示命令增多 |
| MVVM | 展示状态与转换 | ViewModel 可独立验证，UI 订阅状态变化 | 绑定、生命周期与状态一致性要明确 |
| VIPER | 展示、用例、实体、路由分工 | 较多职责有独立验证位置 | 类型、协议和装配成本增加 |
| MVI | Intent → 状态演进 → 渲染 | 状态变化和事件路径显式 | 动作、副作用和状态划分需要建模 |
| TCA | 可组合状态、动作、副作用与依赖 | 有统一的组合和测试工具 | 库的学习成本与版本迁移成本 |
| Clean | 核心规则与外部实现的依赖方向 | 业务与展示、网络和存储实现分开 | 层间协议、映射与装配可能增多 |

不能从表里读出“VIPER 最高”“MVC 必然不可测”。MVVM 不必双向绑定，VIPER 不会自动形成严格单向状态流，Clean 本身也不规定 UI 状态存放在哪里。

### 5.2 选型前先回答六个问题

1. **业务复杂度**：复杂的是展示转换、核心规则，还是异步事件与状态组合？
2. **变化点**：哪些数据来源、导航或展示策略确实会变化？
3. **测试目标**：需要脱离真实 UI / 网络验证哪些行为？
4. **团队与技术栈**：能否维护协议、绑定、状态建模和依赖库？UIKit 与 SwiftUI 都不自动决定唯一答案。
5. **迁移代价**：能否在一个功能内验证，并保持旧链路可回退？
6. **可观测效果**：用维护范围、缺陷、测试反馈或装配复杂度验证收益，而不是只看 VC 行数下降。

简单功能可以保留 MVC；需要独立展示状态时可评估 MVP / MVVM；事件复杂时评估单向数据流；核心业务需要隔离时评估 Clean。这里是问题导向的候选方案，不是规模阈值对应表。

### 5.3 混合架构：不同维度可以组合

**分层架构：**
```
┌─────────────────────────────────────┐
│          UI层 (View/Controller)      │
│  - 使用MVC或MVVM                    │
│  - 处理用户交互                      │
└─────────────────────────────────────┘
         ↕
┌─────────────────────────────────────┐
│          业务层 (Service)            │
│  - 业务逻辑                          │
│  - 数据处理                          │
│  - 独立的模块                        │
└─────────────────────────────────────┘
         ↕
┌─────────────────────────────────────┐
│          数据层 (Repository)         │
│  - 数据存储                          │
│  - 网络请求                          │
│  - 缓存管理                          │
└─────────────────────────────────────┘
```

**模块化架构：**
```
项目结构：
├── App (应用入口)
├── Core (核心模块)
│   ├── Network (网络)
│   ├── Database (数据库)
│   └── Utils (工具)
├── Features (功能模块)
│   ├── Home (首页)
│   ├── Profile (个人中心)
│   └── Settings (设置)
└── Resources (资源)
```

上面的目录只是组织示意，不能代替依赖规则。可以让 MVVM 负责展示，让 Use Case 承载规则，让 Repository 屏蔽数据来源；简单页面无需机械复制全部层次。

### 5.4 渐进迁移，而不是全面重写

1. 找到具体痛点：重复规则、难测状态、隐藏依赖或高风险修改点。
2. 先补行为验证，再选择一个有代表性的功能拆分职责。
3. 明确新旧链路共存方式、开关、回滚点和依赖归属。
4. 对比改动范围、缺陷、测试反馈与协作成本；没有收益就调整设计。
5. 只推广已经验证有效的约定，不要求所有页面统一成同一种结构。

团队能力、交付周期和维护期限会影响取舍，但不能推出“高级团队必用 VIPER”或“长期项目必须全面升级”。

## 6. 设计模式在 iOS 中的应用

### 6.1 先找问题，再选模式

本章保留原笔记的创建型、结构型、行为型案例，以及 iOS 常用的 Delegate。**Delegate 是 Cocoa 的重要协作机制，但不是 GoF 23 种模式中的一个条目。** 原笔记没有单独讲 Interpreter，因此本文不再宣称完整覆盖 GoF 23 种模式，也不沿用“已完善 15 种”的错误统计。

**解决的问题**：
- ❌ 代码重复：同样的逻辑写多遍
- ❌ 耦合严重：改一个地方影响多处
- ❌ 难以扩展：加功能要改很多代码
- ❌ 难以测试：依赖太多，无法单元测试

**带来的好处**：
- ✅ **代码复用**：识别成熟方案的适用条件，再决定是否采用
- ✅ **易维护**：结构清晰，改动影响小
- ✅ **易扩展**：符合开闭原则，对扩展开放
- ✅ **易沟通**：团队共同语言，"用单例模式"大家都懂

### 6.2 创建型模式

#### 6.2.1 Singleton（单例模式）

**核心思想**
保证一个类只有一个实例，并提供全局访问点。

**iOS中的应用**
- `UserDefaults.standard` - 用户偏好设置
- `URLSession.shared` - 网络会话
- `UIApplication.shared` - App实例
- `NSNotificationCenter.default` - 通知中心
- `FileManager.default` - 文件管理器

**使用场景**
✅ 需要全局唯一实例：
- 配置管理器（AppConfig）
- 网络管理器（NetworkManager）
- 数据库管理器（DatabaseManager）
- 日志管理器（Logger）

❌ 不应该用单例：
- 业务模型（User、Order等）
- 临时状态（当前页面状态）
- 可以有多个实例的对象（View、ViewController）

**优缺点**
- ✅ 全局访问，使用方便
- ✅ 节省资源，避免重复创建
- ❌ 全局状态，难以测试
- ❌ 隐藏依赖，耦合严重

**Swift实现方式**
```swift
// 线程安全的单例
class NetworkManager {
    static let shared = NetworkManager()

    private init() {}  // 私有化初始化方法

    func fetchData() { }
}

// 使用
NetworkManager.shared.fetchData()
```

---

#### 6.2.2 Factory Method 与简单工厂

**核心思想**
定义创建对象的接口，让子类决定创建哪种对象。

**iOS中的应用**
- 创建入口可以隐藏具体类型，但普通初始化器不自动等同于 GoF 工厂方法
- 严格的 Factory Method 通过可替换的创建方法，让子类或具体创建者决定产品类型
- 数据解析器：根据服务器返回的type字段，创建不同的Model

**使用场景**
✅ 不知道具体创建什么对象：
- 解析JSON时，根据type字段创建不同的Model
- 创建不同类型的Cell（普通Cell、图片Cell、视频Cell）
- 创建不同类型的动画（淡入、滑入、缩放）

❌ 对象类型简单固定：
- 只创建一种对象，不需要工厂

**实际案例**
```swift
// 场景：聊天消息解析；这是按 type 分支的简单工厂，不是严格的 GoF Factory Method
// JSON: {"type": "text", "content": "hello"}
// JSON: {"type": "image", "url": "https://..."}

protocol Message { }
class TextMessage: Message { }
class ImageMessage: Message { }

class MessageFactory {
    static func create(from json: [String: Any]) -> Message {
        let type = json["type"] as? String ?? "text"

        switch type {
        case "text":
            return TextMessage()
        case "image":
            return ImageMessage()
        default:
            return TextMessage()  // 默认
        }
    }
}
```

---

#### 6.2.3 Abstract Factory（抽象工厂模式）

**核心思想**
提供一个接口，用于创建相关或依赖对象的家族，而不需要明确指定具体类。

**iOS中的应用**
- 不同主题的UI组件创建（暗色主题、亮色主题）
- 不同平台的UI组件创建（iOS风格、Android风格）
- 不同数据源的Cell创建（本地数据、网络数据）

**使用场景**
✅ 需要创建一系列相关对象：
- 主题切换：创建一套完整的暗色UI组件
- 平台适配：创建iOS风格或Android风格的组件
- 数据源切换：创建本地或网络的数据对象

**实际案例**
```swift
// 场景：主题切换
protocol ButtonFactory {
    func createButton() -> UIButton
    func createTextField() -> UITextField
}

class DarkThemeFactory: ButtonFactory {
    func createButton() -> UIButton {
        let button = UIButton()
        button.backgroundColor = .darkGray
        return button
    }

    func createTextField() -> UITextField {
        let textField = UITextField()
        textField.backgroundColor = .darkGray
        return textField
    }
}

class LightThemeFactory: ButtonFactory {
    func createButton() -> UIButton {
        let button = UIButton()
        button.backgroundColor = .white
        return button
    }

    func createTextField() -> UITextField {
        let textField = UITextField()
        textField.backgroundColor = .white
        return textField
    }
}

// 使用
let factory = DarkThemeFactory()
let button = factory.createButton()  // 创建暗色主题按钮
let textField = factory.createTextField()  // 创建暗色主题输入框
```

---

#### 6.2.4 Builder（建造者模式）

**核心思想**
将复杂对象的构建与表示分离，使得同样的构建过程可以创建不同的表示。

**iOS中的应用**
- `URLSession.configuration` - 分步骤配置网络请求
- `UIAlertController` - 链式调用配置弹窗
- 自定义View的复杂初始化（多种参数组合）

**使用场景**
✅ 对象创建过程复杂：
- 多个参数，且有些参数可选
- 参数有多种组合方式
- 创建过程需要多个步骤

❌ 对象创建简单：
- 只有一两个参数，直接用init即可

**实际案例**
```swift
// 场景：创建复杂的网络请求
class NetworkRequestBuilder {
    private var url: String = ""
    private var method: String = "GET"
    private var headers: [String: String] = [:]
    private var body: Data?

    func setURL(_ url: String) -> NetworkRequestBuilder {
        self.url = url
        return self
    }

    func setMethod(_ method: String) -> NetworkRequestBuilder {
        self.method = method
        return self
    }

    func addHeader(_ key: String, value: String) -> NetworkRequestBuilder {
        self.headers[key] = value
        return self
    }

    func setBody(_ body: Data) -> NetworkRequestBuilder {
        self.body = body
        return self
    }

    func build() -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        request.httpBody = body
        return request
    }
}

// 使用：链式调用，清晰明了
let request = NetworkRequestBuilder()
    .setURL("https://api.example.com/users")
    .setMethod("POST")
    .addHeader("Authorization", value: "Bearer token")
    .setBody(jsonData)
    .build()
```

---

#### 6.2.5 Prototype（原型模式）

**核心思想**
通过复制现有对象来创建新对象，而不是通过创建新实例。

**iOS中的应用**
- `NSObject.copy()` - 对象拷贝
- `NSCopying` 协议 - 实现拷贝功能
- Model的深拷贝（避免修改影响原对象）

**使用场景**
✅ 创建新对象成本高：
- 对象创建需要从数据库/网络加载大量数据
- 对象初始化需要大量计算
- 需要保存对象状态快照（撤销操作）

**实际案例**
```swift
// 场景：表单填写，用户复制之前的提交记录
class FormModel: NSCopying {
    var name: String = ""
    var email: String = ""
    var phone: String = ""

    func copy(with zone: NSZone? = nil) -> Any {
        let copy = FormModel()
        copy.name = name
        copy.email = email
        copy.phone = phone
        return copy
    }
}

// 使用
let originalForm = FormModel()
originalForm.name = "张三"
originalForm.email = "zhang@example.com"

// 复制表单，修改部分字段
let newForm = originalForm.copy() as! FormModel
newForm.name = "李四"  // 不影响原表单
```

---

### 6.3 结构型模式

#### 6.3.1 Adapter（适配器模式）

**核心思想**
将一个类的接口转换成客户期望的另一个接口，让原本不兼容的类可以合作。

**iOS中的应用**
- `UITableViewDataSource` - 将数据适配成TableView能显示的格式
- 第三方SDK封装 - 将不友好的API转换成自己项目的风格
- 数据格式转换 - JSON转Model、XML转Model

**使用场景**
✅ 接口不兼容：
- 使用第三方SDK，接口不符合项目规范
- 旧系统接口需要适配新系统
- 数据格式不匹配（服务器返回的JSON和Model字段不一致）

**实际案例**
```swift
// 场景：接入第三方支付SDK（假设接口不友好）
// 第三方SDK的接口
class ThirdPartyPaymentSDK {
    func payWith(amount: Double, currency: String, orderId: String) {
        // 第三方支付逻辑
    }
}

// 项目期望的接口
protocol PaymentAdapter {
    func pay(order: Order)
}

// 适配器
class PaymentAdapterImpl: PaymentAdapter {
    private let sdk = ThirdPartyPaymentSDK()

    func pay(order: Order) {
        // 转换接口
        sdk.payWith(amount: order.amount,
                  currency: "CNY",
                  orderId: order.id)
    }
}

// 使用：业务层不需要知道第三方SDK的细节
let adapter = PaymentAdapterImpl()
adapter.pay(order: myOrder)
```

---

#### 6.3.2 Bridge（桥接模式）

**核心思想**
将抽象部分与实现部分分离，使它们都可以独立地变化。

**iOS中的应用**
- Core Animation - 抽象的动画接口 + 不同平台的实现
- UIKit - 抽象的UI组件 + iOS/iPadOS/watchOS的实现
- 绘图引擎 - 抽象的绘图API + Metal/OpenGL/CoreGraphics实现

**使用场景**
✅ 抽象和实现都需要独立扩展：
- UI组件：抽象的Button + 不同平台的Button实现
- 绘图引擎：抽象的画笔 + Metal/OpenGL/CoreGraphics实现
- 消息推送：抽象的推送接口 + APNs/FCM/HMS实现

**实际案例**
```swift
// 场景：消息推送，支持多个推送平台
// 抽象部分
protocol Message {
    func send()
}

class PushNotification: Message {
    private let platform: PushPlatform

    init(platform: PushPlatform) {
        self.platform = platform
    }

    func send() {
        platform.push(title: "新消息", body: "你有新消息")
    }
}

// 实现部分
protocol PushPlatform {
    func push(title: String, body: String)
}

class APNs: PushPlatform {
    func push(title: String, body: String) {
        // APNs推送逻辑
    }
}

class FCM: PushPlatform {
    func push(title: String, body: String) {
        // Firebase推送逻辑
    }
}

// 使用：可以任意组合
let apnsPush = PushNotification(platform: APNs())
apnsPush.send()

let fcmPush = PushNotification(platform: FCM())
fcmPush.send()
```

---

#### 6.3.3 Composite（组合模式）

**核心思想**
将对象组合成树形结构以表示"部分-整体"的层次结构，使用户对单个对象和组合对象的使用具有一致性。

**iOS中的应用**
- `UIView` 的 subview - View可以包含子View，形成View树
- `CALayer` 的 sublayer - Layer可以包含子Layer
- 文件系统 - 文件夹可以包含文件和子文件夹

**使用场景**
✅ 需要表示"部分-整体"层次结构：
- UI层级：View包含多个子View
- 文件系统：文件夹包含文件和子文件夹
- 组织架构：公司包含多个部门，部门包含多个员工

**实际案例**
```swift
// 场景：文件系统
protocol FileSystemItem {
    var name: String { get }
    func display(indent: String)
}

class File: FileSystemItem {
    let name: String

    init(name: String) {
        self.name = name
    }

    func display(indent: String) {
        print("\(indent)📄 \(name)")
    }
}

class Folder: FileSystemItem {
    let name: String
    private var items: [FileSystemItem] = []

    init(name: String) {
        self.name = name
    }

    func addItem(_ item: FileSystemItem) {
        items.append(item)
    }

    func display(indent: String = "") {
        print("\(indent)📁 \(name)")
        for item in items {
            item.display(indent: indent + "  ")
        }
    }
}

// 使用：构建文件树
let root = Folder(name: "根目录")
let projects = Folder(name: "项目")
let file1 = File(name: "main.swift")
let file2 = File(name: "config.json")

root.addItem(projects)
projects.addItem(file1)
projects.addItem(file2)

root.display()

// 输出：
// 📁 根目录
//   📁 项目
//     📄 main.swift
//     📄 config.json
```

---

#### 6.3.4 Decorator（装饰器模式）

**核心思想**
动态地给对象添加一些额外的职责，比生成子类更灵活。

**iOS中的应用**
- `UITableView` 的 separators、headers - 给TableView添加额外的装饰
- `CALayer` 的 border、shadow - 给Layer添加装饰效果
- `NSMutableAttributedString` - 给字符串添加装饰（颜色、字体等）

**使用场景**
✅ 动态添加功能：
- 给View添加边框、阴影、圆角
- 给文本添加颜色、字体、下划线
- 给图片添加水印、滤镜

❌ 功能固定不变：
- 直接用继承更简单

**实际案例**
```swift
// 场景：咖啡店订单（经典案例）
// 基础组件
protocol Coffee {
    func cost() -> Double
    func description() -> String
}

class SimpleCoffee: Coffee {
    func cost() -> Double { return 10 }
    func description() -> String { return "普通咖啡" }
}

// 装饰器
class CoffeeDecorator: Coffee {
    let coffee: Coffee

    init(_ coffee: Coffee) {
        self.coffee = coffee
    }

    func cost() -> Double { return coffee.cost() }
    func description() -> String { return coffee.description() }
}

// 具体装饰器
class MilkDecorator: CoffeeDecorator {
    override func cost() -> Double { return super.cost() + 2 }
    override func description() -> String { return super.description() + " + 牛奶" }
}

class SugarDecorator: CoffeeDecorator {
    override func cost() -> Double { return super.cost() + 1 }
    override func description() -> String { return super.description() + " + 糖" }
}

// 使用：动态组合
let coffee = SimpleCoffee()
print(coffee.description())  // 普通咖啡: ¥10

let milkCoffee = MilkDecorator(coffee)
print(milkCoffee.description())  // 普通咖啡 + 牛奶: ¥12

let milkSugarCoffee = SugarDecorator(milkCoffee)
print(milkSugarCoffee.description())  // 普通咖啡 + 牛奶 + 糖: ¥13
```

---

#### 6.3.5 Facade（外观模式）

**核心思想**
为子系统中的一组接口提供一个一致的界面，定义一个高层接口，这个接口使得这一子系统更加容易使用。

**iOS中的应用**
- `UIImage(named:)` - 隐藏了图片加载的复杂过程（缓存、解压等）
- `URLSession.shared.dataTask()` - 隐藏了网络请求的复杂过程
- `AVAudioPlayer` - 隐藏了音频播放的复杂细节

**使用场景**
✅ 简化复杂子系统的使用：
- 网络请求：隐藏配置、缓存、重试等细节
- 图片加载：隐藏下载、解码、缓存等细节
- 音视频播放：隐藏解码、渲染、同步等细节

**实际案例**
```swift
// 场景：封装网络请求
// 子系统的复杂接口
class NetworkConfigurator {
    func configureHeaders() { }
    func configureTimeout() { }
    func configureCache() { }
}

class NetworkCache {
    func getCache(_ url: String) -> Data? { return nil }
    func setCache(_ url: String, data: Data) { }
}

class NetworkRequest {
    func send(_ url: String, completion: (Data?) -> Void) { }
}

// 外观：提供简单接口
class NetworkFacade {
    private let configurator = NetworkConfigurator()
    private let cache = NetworkCache()
    private let request = NetworkRequest()

    init() {
        configurator.configureHeaders()
        configurator.configureTimeout()
        configurator.configureCache()
    }

    func get(_ url: String, completion: (Data?) -> Void) {
        // 先查缓存
        if let cachedData = cache.getCache(url) {
            completion(cachedData)
            return
        }

        // 缓存未命中，发送网络请求
        request.send(url) { data in
            if let data = data {
                self.cache.setCache(url, data: data)
            }
            completion(data)
        }
    }
}

// 使用：业务层代码非常简单
let network = NetworkFacade()
network.get("https://api.example.com/users") { data in
    print("收到数据：\(data)")
}
```

---

#### 6.3.6 Proxy（代理模式）

**核心思想**
为其他对象提供一种代理以控制对这个对象的访问。

**iOS中的应用**
- `NSProxy` - 消息转发代理
- `WKNavigationDelegate` - 控制WebView的页面加载
- 延迟加载代理 - 图片、大文件等到需要时才加载

**使用场景**
✅ 需要控制对象访问：
- 远程代理：访问远程对象（网络请求）
- 虚拟代理：延迟加载大对象（图片、视频）
- 保护代理：控制访问权限（需要登录才能访问）
- 智能代理：引用计数（ARC）

**实际案例**
```swift
// 场景：图片延迟加载
class ImageProxy {
    private var image: UIImage?
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func getImage(completion: @escaping (UIImage?) -> Void) {
        // 如果已经加载，直接返回
        if let image = image {
            completion(image)
            return
        }

        // 懒加载：第一次使用时才下载
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: self.url) {
                let downloadedImage = UIImage(data: data)
                self.image = downloadedImage
                DispatchQueue.main.async {
                    completion(downloadedImage)
                }
            }
        }
    }
}

// 使用
let proxy = ImageProxy(url: URL(string: "https://example.com/large.jpg")!)

// 第一次使用：触发下载
proxy.getImage { image in
    print("图片加载完成")
}

// 第二次使用：直接从内存返回
proxy.getImage { image in
    print("图片已缓存")
}
```

---

#### 6.3.7 Flyweight（享元模式）

**核心思想**
运用共享技术有效地支持大量细粒度的对象。

**iOS中的应用**
- `UILabel` 的复用 - TableView中Cell的复用
- 字体缓存 - 相同字体只创建一次
- 图片缓存 - 相同图片只加载一次

**使用场景**
✅ 有大量相似对象：
- Cell复用：TableView中相同类型的Cell复用
- 字符串常量：相同的字符串只保存一份
- 图片缓存：相同的图片只加载一次

**实际案例**
```swift
// 场景：字符串常量池
class StringFlyweight {
    private var pool: [String: String] = [:]

    func get(string: String) -> String {
        if let existing = pool[string] {
            return existing
        }

        pool[string] = string
        return string
    }
}

// 使用
let flyweight = StringFlyweight()

let s1 = flyweight.get(string: "Hello")
let s2 = flyweight.get(string: "Hello")
let s3 = flyweight.get(string: "World")

// s1 和 s2 是同一个对象（内存地址相同）
// s3 是不同的对象
```

---

### 6.4 行为型模式与 iOS 协作机制

#### 6.4.1 Observer（观察者模式）

**核心思想**
定义对象间的一种一对多的依赖关系，当一个对象的状态发生改变时，所有依赖于它的对象都得到通知并被自动更新。

**iOS中的应用**
- `NotificationCenter` - 通知中心
- `KVO (Key-Value Observing)` - 键值观察
- `Combine / RxSwift` - 响应式编程
- Delegate 可用于事件回调，但不要把所有委托行为都等同于一对多观察者

**使用场景**
✅ 一对多的通知：
- 登录状态变化：通知多个页面更新UI
- 数据更新：通知多个观察者刷新
- 网络状态变化：通知监听的模块

**实现方式对比**

| 方式 | 优点 | 缺点 | 适用场景 |
|------|------|------|----------|
| **NotificationCenter** | 解耦强，一对多 | 容易忘记移除观察者 | 跨模块通知 |
| **KVO** | 系统支持，自动触发 | 只能监听属性，容易崩溃 | 监听Model属性变化 |
| **Delegate** | 类型安全，编译期检查 | 一对一，耦合稍强 | 一对一的回调 |
| **Combine/RxSwift** | 链式调用，功能强大 | 学习成本高 | 复杂的数据流 |

---

#### 6.4.2 Delegate（委托模式）

**核心思想**
将一个对象的某些职责委托给另一个对象处理。

**iOS中的应用**
- `UITableViewDelegate` - TableView的事件回调
- `UITextFieldDelegate` - TextField的事件回调
- `UIApplicationDelegate` - App生命周期回调

**使用场景**
✅ 需要回调事件：
- TableView的点击事件
- TextField的输入变化
- 网络请求完成回调

❌ 不适合：
- 一对多的通知（用Observer）
- 简单的函数调用（直接调用即可）

**实际案例**
```swift
// 协议定义
protocol UserCellDelegate: AnyObject {
    func userCellDidClickFollow(_ userId: String)
}

class UserCell: UITableViewCell {
    weak var delegate: UserCellDelegate?
    var userId: String?

    @objc func followButtonClicked() {
        guard let userId = userId else { return }
        delegate?.userCellDidClickFollow(userId)
    }
}

// 使用：ViewController实现协议
class UserViewController: UIViewController, UserCellDelegate {
    func userCellDidClickFollow(_ userId: String) {
        // 处理关注逻辑
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(...)
        cell.delegate = self
        return cell
    }
}
```

---

#### 6.4.3 Strategy（策略模式）

**核心思想**
定义一系列算法，把它们一个个封装起来，并且使它们可相互替换。

**iOS中的应用**
- 排序算法：`sorted(by:)` 可以传入不同的比较策略
- 动画类型：淡入、滑入、缩放等不同策略
- 压缩算法：ZIP、GZIP等不同策略

**使用场景**
✅ 需要在运行时切换算法：
- 不同等级的VIP用户有不同的计算折扣方式
- 不同类型的消息有不同的发送策略（推送、短信、邮件）
- 不同平台有不同的UI样式策略

**实际案例**
```swift
// 场景：不同类型的用户有不同的折扣策略
protocol DiscountStrategy {
    func calculateDiscount(price: Double) -> Double
}

class NormalUserStrategy: DiscountStrategy {
    func calculateDiscount(price: Double) -> Double {
        return price  // 无折扣
    }
}

class VIPUserStrategy: DiscountStrategy {
    func calculateDiscount(price: Double) -> Double {
        return price * 0.9  // 9折
    }
}

class SVIPUserStrategy: DiscountStrategy {
    func calculateDiscount(price: Double) -> Double {
        return price * 0.8  // 8折
    }
}

// 使用
class ShoppingCart {
    private var strategy: DiscountStrategy

    init(strategy: DiscountStrategy) {
        self.strategy = strategy
    }

    func setStrategy(_ strategy: DiscountStrategy) {
        self.strategy = strategy
    }

    func calculateFinalPrice(price: Double) -> Double {
        return strategy.calculateDiscount(price: price)
    }
}

let cart = ShoppingCart(strategy: NormalUserStrategy())
print(cart.calculateFinalPrice(price: 100))  // 100

cart.setStrategy(VIPUserStrategy())
print(cart.calculateFinalPrice(price: 100))  // 90
```

---

#### 6.4.4 Command（命令模式）

**核心思想**
将一个请求封装为一个对象，从而使你可用不同的请求对客户进行参数化。

**iOS中的应用**
- `NSInvocation` - 封装方法调用
- 撤销/重做操作 - 文本编辑器的撤销
- 任务队列 - 异步执行任务

**使用场景**
✅ 需要封装操作：
- 撤销/重做功能（文本编辑器、画图应用）
- 任务队列（异步执行多个任务）
- 事务操作（数据库事务）

**实际案例**
```swift
// 场景：文本编辑器的撤销功能
protocol Command {
    func execute()
    func undo()
}

class AddTextCommand: Command {
    private var textView: UITextView
    private var text: String

    init(textView: UITextView, text: String) {
        self.textView = textView
        self.text = text
    }

    func execute() {
        textView.text += text
    }

    func undo() {
        let count = text.count
        if let originalText = textView.text.dropLast(count).string {
            textView.text = originalText
        }
    }
}

// 使用
let command = AddTextCommand(textView: myTextView, text: "Hello")
command.execute()  // 添加文本
command.undo()     // 撤销添加
```

---

#### 6.4.5 Mediator（中介者模式）

**核心思想**
用一个中介对象来封装一系列的对象交互，中介者使各对象不需要显式地相互引用。

**iOS中的应用**
- `UITableView` - Cell和DataSource之间的中介
- `UINavigationController` - ViewController之间的中介
- 组件化中的Mediator - 模块间的通信中介

**使用场景**
✅ 多个对象间复杂交互：
- 聊天界面：输入框、发送按钮、消息列表之间的交互
- 表单界面：多个输入框、提交按钮、验证逻辑之间的交互
- 模块化通信：不同模块间的通信（Target-Action方案的Mediator）

**实际案例**
```swift
// 场景：聊天界面
class ChatMediator {
    weak var inputField: UITextField?
    weak var sendButton: UIButton?
    weak var tableView: UITableView?

    // 用户输入文字
    func inputFieldDidChange(_ text: String) {
        sendButton?.isEnabled = !text.isEmpty
    }

    // 用户点击发送
    func sendButtonClicked() {
        guard let text = inputField?.text else { return }

        // 1. 清空输入框
        inputField?.text = ""

        // 2. 禁用发送按钮
        sendButton?.isEnabled = false

        // 3. 刷新消息列表
        // ...
    }
}
```

---

#### 6.4.6 Memento（备忘录模式）

**核心思想**
在不破坏封装性的前提下，捕获一个对象的内部状态，并在该对象之外保存这个状态。

**iOS中的应用**
- `NSCoding` / `Codable` - 对象归档
- `UserDefaults` - 保存用户设置
- 游戏存档 - 保存游戏进度

**使用场景**
✅ 需要保存/恢复状态：
- 撤销/重做功能
- 游戏存档
- 表单草稿保存

**实际案例**
```swift
// 场景：表单草稿保存
class FormMemento {
    let name: String
    let email: String
    let phone: String

    init(name: String, email: String, phone: String) {
        self.name = name
        self.email = email
        self.phone = phone
    }
}

class Form {
    var name: String = ""
    var email: String = ""
    var phone: String = ""

    func save() -> FormMemento {
        return FormMemento(name: name, email: email, phone: phone)
    }

    func restore(_ memento: FormMemento) {
        name = memento.name
        email = memento.email
        phone = memento.phone
    }
}

// 使用
let form = Form()
form.name = "张三"

// 保存草稿
let draft = form.save()

// 修改表单
form.name = "李四"

// 恢复草稿
form.restore(draft)
print(form.name)  // "张三"
```

---

#### 6.4.7 Template Method（模板方法模式）

**核心思想**
定义一个操作中的算法的骨架，而将一些步骤延迟到子类中。

**iOS中的应用**
- `UIViewController` 的生命周期 - loadView、viewDidLoad、viewWillAppear等
- `UIView` 的 draw(_:) - 子类重写自定义绘制
- 网络请求基类 - 定义请求流程，子类实现具体URL

**使用场景**
✅ 有通用的流程，但具体步骤不同：
- 网络请求：配置请求 → 发送 → 处理响应（具体URL不同）
- 数据解析：下载数据 → 解析 → 缓存（具体解析方式不同）
- 页面加载：初始化 → 加载数据 → 渲染UI（具体数据不同）

**实际案例**
```swift
// 场景：网络请求基类
class NetworkRequest {
    // 模板方法：定义流程
    final func send(completion: @escaping (Data?) -> Void) {
        let url = getURL()
        let parameters = getParameters()

        var request = URLRequest(url: url)
        request.httpMethod = httpMethod()

        // 发送请求
        URLSession.shared.dataTask(with: request) { data, _, _ in
            completion(data)
        }.resume()
    }

    // 子类需要实现的方法
    func getURL() -> URL { fatalError("子类必须实现") }
    func getParameters() -> [String: Any] { [:] }
    func httpMethod() -> String { "GET" }
}

// 具体子类
class GetUserRequest: NetworkRequest {
    private let userId: String

    init(userId: String) {
        self.userId = userId
    }

    override func getURL() -> URL {
        return URL(string: "https://api.example.com/users/\(userId)")!
    }
}
```

---

#### 6.4.8 Iterator（迭代器模式）

**核心思想**
提供一种方法顺序访问一个聚合对象中各个元素，而又不需暴露该对象的内部表示。

**iOS中的应用**
- `for...in` 循环 - 遍历数组、字典
- `Sequence` / `IteratorProtocol` - 自定义迭代器
- `makeIterator()` - 创建迭代器

**使用场景**
✅ 需要遍历集合：
- 遍历数组、字典、Set
- 自定义数据结构的遍历
- 懒加载序列（按需生成）

---

#### 6.4.9 State（状态模式）

**核心思想**
允许一个对象在其内部状态改变时改变它的行为。

**iOS中的应用**
- `UIView` 的状态 - normal、highlighted、disabled
- 网络请求状态 - idle、loading、success、error
- 订单状态 - 待支付、已支付、已发货、已完成

**使用场景**
✅ 对象行为取决于状态：
- 网络请求：不同状态显示不同UI
- 订单流程：不同状态有不同的操作
- 播放器：播放、暂停、缓冲等不同状态

**实际案例**
```swift
// 场景：网络请求状态
protocol RequestState {
    func handle()
}

class IdleState: RequestState {
    func handle() {
        print("请求空闲")
    }
}

class LoadingState: RequestState {
    func handle() {
        print("请求中，显示Loading")
    }
}

class SuccessState: RequestState {
    let data: Data

    init(data: Data) {
        self.data = data
    }

    func handle() {
        print("请求成功，处理数据：\(data)")
    }
}

class ErrorState: RequestState {
    let error: Error

    init(error: Error) {
        self.error = error
    }

    func handle() {
        print("请求失败：\(error)")
    }
}

// 使用
class NetworkRequest {
    var state: RequestState = IdleState()

    func send() {
        state = LoadingState()
        state.handle()

        // 模拟网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.state = SuccessState(data: Data())
            self.state.handle()
        }
    }
}
```

---

#### 6.4.10 Chain of Responsibility（责任链模式）

**核心思想**
为解除请求的发送者和接收者之间的耦合，而使多个对象都有机会处理这个请求。

**iOS中的应用**
- `UIResponder` 链 - 触摸事件的传递链
- `NSError` 的处理链 - 多个错误处理器
- 事件拦截链 - gesture、button、superview

**使用场景**
✅ 多个对象可以处理同一请求：
- 事件处理：触摸事件沿着响应链传递
- 日志处理：根据日志级别选择不同的处理器
- 权限验证：多层验证（登录 → VIP → 管理员）

---

#### 6.4.11 Visitor（访问者模式）

**核心思想**
表示一个作用于某对象结构中的各元素的操作。它使你可以在不改变各元素的类的前提下定义作用于这些元素的新操作。

**iOS中的应用**
- `MapKit` - 地图元素的点击事件
- `CoreGraphics` - 绘制元素的访问
- JSON解析 - 遍历JSON树并处理不同类型的节点

**使用场景**
✅ 对象结构稳定，但操作经常变化：
- 文档结构：段落、图片、表格（结构稳定）→ 导出PDF、导出Word（操作变化）
- 文件系统：文件、文件夹（结构稳定）→ 压缩、加密（操作变化）

---

### 6.5 设计模式选择指南

#### 6.5.1 根据问题选择模式

| 问题 | 推荐模式 |
|------|----------|
| **需要全局唯一实例** | Singleton |
| **不知道具体创建什么对象** | Factory Method |
| **需要创建一系列相关对象** | Abstract Factory |
| **对象创建过程复杂** | Builder |
| **接口不兼容** | Adapter |
| **需要动态添加功能** | Decorator |
| **简化复杂子系统** | Facade |
| **控制对象访问** | Proxy |
| **一对多的通知** | Observer |
| **一对一的回调** | Delegate |
| **需要在运行时切换算法** | Strategy |
| **需要封装操作** | Command |
| **多个对象间复杂交互** | Mediator |
| **需要保存/恢复状态** | Memento |
| **有通用的流程，具体步骤不同** | Template Method |
| **对象行为取决于状态** | State |

#### 6.5.2 设计模式使用原则

**不要过度使用**：
- ❌ 不是所有地方都要用设计模式
- ❌ 简单场景直接实现即可
- ✅ 复杂场景才考虑设计模式

**先理解后使用**：
- ❌ 不要为了用模式而用模式
- ✅ 理解模式解决的问题，再决定是否使用

**结合实际场景**：
- ❌ 不要生搬硬套书本案例
- ✅ 结合项目实际需求灵活运用

---

### 6.6 学习路径与记忆辅助

#### 6.6.1 设计模式学习路径

```
第1阶段：理解意图
→ 读懂每个模式解决什么问题
→ 理解模式的核心思想

第2阶段：识别场景
→ 在iOS SDK中找到应用案例
→ 在自己项目中找到使用场景

第3阶段：灵活运用
→ 根据实际问题选择合适的模式
→ 不要生搬硬套，灵活变通
```

#### 6.6.2 设计模式记忆口诀

**创建型**：
- Single一个实例 - Singleton
- Factory创建对象 - Factory
- Builder构建复杂 - Builder
- Prototype复制自己 - Prototype

**结构型**：
- Adapter适配接口 - Adapter
- Decorator添加装饰 - Decorator
- Facade简化访问 - Facade
- Proxy控制访问 - Proxy
- Bridge连接抽象 - Bridge

**行为型**：
- Observer观察变化 - Observer
- Delegate委托事件 - Delegate
- Strategy切换算法 - Strategy
- Command封装操作 - Command
- Mediator中介交互 - Mediator
- State状态改变 - State

---

## 7. 面试题与复习索引

### 7.1 架构与原则：先讲职责，再讲取舍

| 问题 | 回答骨架 | 回读位置 |
|------|----------|----------|
| MVC 为什么会写胖？ | 实现把哪些职责集中到 VC；Model 并非只能放属性；怎样逐步抽出变化点 | 2.1、5.4 |
| MVP 与 MVVM 的关键差异？ | Presenter 驱动 View 命令；ViewModel 提供状态与交互入口；绑定只是衔接方式 | 2.2、2.3 |
| 怎样避免胖 ViewModel？ | 展示逻辑与可复用业务、网络、缓存分开；控制依赖和公开状态 | 2.3、4.1 |
| VIPER 的收益和代价？ | 分别验证展示、用例和路由；额外协议、类型和装配成本 | 2.4 |
| MVI 怎样处理异步结果？ | 意图、状态转换、副作用、结果事件；不要直接从任意回调修改分散状态 | 3.1 |
| TCA 的核心概念？ | State、Action、Reducer、Store、Effect，以及组合、依赖和测试 | 3.2 |
| Clean 的依赖规则？ | Presentation / Data 依赖 Domain；仓库协议与实现分开；框架依赖是明确选择 | 4.1 |
| DI 与 DIP 的区别？ | 装配方法与依赖方向原则；协议不是目的；在装配位置选择具体实现 | 1.8、4.2 |
| 怎样选架构？ | 痛点、变化点、测试目标、团队成本、迁移与验证；不是名字排名 | 第 5 章 |
| 单一职责原则？ | 同一类变化原因；不是每个类只能有一个方法 | 1.4 |
| 开闭原则？ | 为真实变化点提供扩展机制，不是永久禁止修改旧代码 | 1.5 |
| 里氏替换原则？ | 替代实现满足调用者依赖的行为契约 | 1.6 |
| 接口隔离原则？ | 调用者无需依赖不需要的能力，按角色划分契约 | 1.7 |

### 7.2 设计模式高频追问

#### 7.2.1 Delegate 和 Block 的区别？

| 维度 | Delegate | Block |
|------|----------|-------|
| **代码位置** | 回调方法在实现类中 | 回调代码在使用处 |
| **可读性** | 清晰，方法名明确 | 内联代码，上下文清晰 |
| **依赖表达** | 用协议表达一组协作行为 | 用闭包类型表达回调契约；不天然比 Delegate 耦合更强 |
| **使用场景** | 多个回调方法 | 单一回调 |

**选择建议**：
- 一组相关的长期协作行为通常适合 Delegate；一次性回调常适合闭包。
- 还要看所有权、取消与可读性，不以“3 个方法”作为硬阈值。

---

#### 7.2.2 Singleton 的优缺点？如何避免滥用？

**优点**：
- ✅ 全局访问，使用方便
- ✅ 节省资源，避免重复创建

**缺点**：
- ❌ 全局状态，难以测试
- ❌ 隐藏依赖，耦合严重
- ❌ 多线程访问需要考虑线程安全

**避免滥用**：
- 优先使用依赖注入，而不是单例
- 单例只用于真正需要全局唯一实例的场景
- 考虑使用协议 + 容器，而不是直接访问单例

---

#### 7.2.3 Observer 模式的几种实现方式对比？

| 方式 | 优点 | 缺点 | 适用场景 |
|------|------|------|----------|
| **NotificationCenter** | 一对多，发送方不持有观察者 | 需区分注册方式，管理 block token 与观察生命周期 | 跨模块通知 |
| **KVO** | 观察兼容属性变化 | 需管理 observation，明确通知线程和对象生命周期 | 监听兼容属性 |
| **Delegate** | 协议契约、类型检查 | 需明确 delegate 所有权及协作生命周期 | 单一协作对象的事件或行为委托 |
| **Combine/RxSwift** | 链式调用，功能强大 | 学习成本高 | 复杂数据流 |

---

#### 7.2.4 什么时候使用 Strategy 模式？

**使用场景**：
- 需要在运行时切换算法（不同用户的折扣策略）
- 有多种算法可以解决同一个问题（不同的排序算法）
- 算法的使用者和算法的实现者应该分离

**实际案例**：
- VIP用户有不同的折扣计算方式
- 不同类型的消息有不同的发送策略
- 不同平台有不同的UI样式

---

#### 7.2.5 Factory Method 和 Abstract Factory 的区别？

| 维度 | Factory Method | Abstract Factory |
|------|----------------|------------------|
| **创建对象** | 一个对象 | 一系列相关对象 |
| **关注点** | 让具体创建者决定某类产品的实例 | 创建一族互相配套的产品；两者可以组合使用 |
| **复杂度** | 简单 | 复杂 |

**选择建议**：
- 替换某类产品的创建行为 → 评估 Factory Method；简单 type 分支也可能只是简单工厂
- 创建一系列相关对象 → Abstract Factory

---

### 7.3 项目回答检查表

用一个真实功能说明：

1. 原来的问题是什么，为什么值得调整？
2. 哪些职责独立出来，状态由谁维护？
3. 谁依赖哪个协议，具体实现在哪装配？
4. UI、请求、观察和任务的生命周期怎样收口？
5. 哪些行为可以独立测试，新旧链路怎样迁移和回退？
6. 收益如何验证，有哪些额外成本？没有真实数据就不编造指标。

语音房的插件组合、Context、通信和生命周期，继续使用独立组件化专题；不要把“采用某个页面架构”与“整个 App 已经完成模块化”混为一谈。

## 8. 整合说明、勘误与参考资料

### 8.1 本次整合范围

**整合日期：2026-11-04。** 本文合并以下四份原文，旧文件在完成内容核对后移除，后续只维护本文：

| 原文 | 本文主要落点 | 处理方式 |
|------|--------------|----------|
| `1、SOLID原则实践.md` | 第 1 章、第 7 章 | 合并定义，保留基础对照示例，修正协议周长与 Flyable 示例 |
| `2、架构模式对比.md` | 第 2～5 章、第 7 章 | 保留独有 MVVM / VIPER 示例、MVI、TCA、Clean 代码；统一对比与选型 |
| `4、设计模式在iOS中的应用.md` | 第 6 章、第 7 章 | 保留所有模式条目、案例和学习路径，统一分类与高频问答 |
| `iOS架构模式对比与实战.md` | 第 1、2、4、5 章 | 作为 UIKit 页面架构骨架，保留 KVO / Combine / VIPER 和 DI 示例 |

组件化、插件化、动态化文档不改动。旧文中的“已完成”仅表示文档写作状态，不转写为学习掌握度；实际复习进度仍以仓库根目录《学习复习总控与交接手册》为准。

### 8.2 重要勘误

| 原表述或问题 | 本文处理 |
|--------------|----------|
| MVC 的 View 与 Model 必然高度耦合；IBOutlet 等于直接通信或双向绑定 | 按 Cocoa MVC 角色重新说明；区分模式与不良实现 |
| 架构目标是代码均摊；VIPER 可测试性“最高” | 改为职责、变化范围、契约与测试条件，不做绝对排名 |
| 页面数量、团队人数或维护年限决定唯一架构 | 统一为问题导向的取舍与验证 |
| MVVM 必须依赖 Combine；MVI 必须采用响应式库 | 区分架构与衔接机制，不强制某个库 |
| TCA 不支持 UIKit、所有状态必须放一个大 Store、默认任意时间旅行 | 说明 UIKit 支持、功能组合与副作用边界；保留旧代码但标注版本风险 |
| Clean 核心是数据层；使用 AnyPublisher 却声称不依赖框架 | 修正依赖方向；明确 Combine 契约选择 |
| Combine sink 使用不存在的第三个 failure 尾随闭包 | 失败在 receiveCompletion 中处理，补齐 cancellables / 初始化及表单状态 |
| 周长仅是协议 extension 方法；所有鸟都被要求 fly | 声明协议 requirement；只让会飞的类型采用 Flyable |
| Delegate 被算成 GoF 条目；简单工厂被当成严格 Factory Method | 保留案例，明确类别和示例实际表达的模式 |
| Swift 强制解包、列表标识、错误状态和 UI 接收线程存在遗漏 | 修正本次直接相关的明显问题；其余省略明确列为教学片段约定 |
| Combine 参考链接指向 Apple News；目录链接与文件名不一致 | 更新官方参考资料与知识体系入口 |

### 8.3 优先阅读的原始资料

- [Apple：Model-View-Controller（归档，作为角色定义参考）](https://developer.apple.com/library/archive/documentation/General/Conceptual/DevPedia-CocoaCore/MVC.html)
- [Apple：Delegation（归档，作为 Cocoa 委托机制参考）](https://developer.apple.com/library/archive/documentation/General/Conceptual/DevPedia-CocoaCore/Delegation.html)
- [Apple：Combine](https://developer.apple.com/documentation/combine)
- [Point-Free：TCA 官方仓库与 README](https://github.com/pointfreeco/swift-composable-architecture)
- [TCA：版本迁移资料](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.0/)
- [iOS Clean Architecture + MVVM：项目 README、依赖方向与示例](https://github.com/kudoleh/iOS-Clean-Architecture-MVVM)

> 本次核对了 Apple 的 MVC / Delegation 角色说明、TCA 官方 README 的当前写法，以及 iOS Clean 示例的分层说明；归档文章不作为最新平台实践的保证。库代码以项目实际锁定版本及其迁移资料为准。

### 8.4 原笔记的补充阅读与工具索引

以下合并原笔记参考项，去除重复和明显错误链接；未逐一验证外部页面可用性，也不把旧标题中的年份当作版本依据。

- [iOS Architecture Patterns. Demystifying MVC, MVP, MVVM and VIPER](https://medium.com/ios-os-x-development/ios-architecture-patterns-ecba4c38de52)
- [iOS Architecture Patterns: MVC, MVP, MVVM, VIPER, and VIP in Swift](https://www.oreilly.com/library/view/ios-architecture-patterns/9781484290682/)
- [The perfect iOS app architecture](https://betterprogramming.com/the-perfect-ios-app-architecture-mvvm-viper-clean-swift/)
- [Why VIPER and MVVM in SwiftUI are actually the same pattern](https://matteomanferdini.com/2021/09/26/why-viper-and-mvvm-in-swiftui-are-actually-the-same-pattern/)
- [Hero (iOS Architecture Pattern)](https://github.com/netguru/Hero) - MVVM+Coordinator
- [RxFlow](https://github.com/RxSwiftCommunity/RxFlow) - Coordinated navigation
- [Point-Free: TCA Documentation](https://www.pointfree.co/blog/posts/the-composable-architecture/)
- [Clean Architecture by Robert Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [iOS Architecture Patterns](https://medium.com/@abdullah.ezen/iOS-architecture-patterns-mvc-mvp-mvvm-viper-8815e441a5f1)
- [MVVM Tutorial with ReactiveCocoa](https://www.raywenderlich.com/6589778-mvvm-tutorial-with-reactivecocoa)
- [VIPER Architecture in iOS](https://www.objc.io/books/good-vibe/)
- [R.swift](https://github.com/mac-cain13/R.swift) - 类型安全的资源访问
- [Swinject](https://github.com/Swinject/Swinject) - 依赖注入框架
- [ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) - 响应式编程框架
- [Cocoa Bindings Programming Topics](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CocoaBindings/index.html)
- [Testing with Xcode](https://developer.apple.com/library/archive/documentation/DeveloperTools/Testing/Testing-top.html)

- GoF：《设计模式：可复用面向对象软件的基础》（原笔记的模式分类参考）。

**维护约定**：同一概念只在正文集中讲解，选型和复习题链接回正文；有新发现就更新对应章节，不再新建一份重复的“架构对比”文档。
