# iOS架构模式对比与实战

> 一句话总结：**iOS架构从MVC演进到MVVM、VIPER，核心目标是职责分离、可测试性和可维护性，选择架构要考虑项目规模、团队技能和业务复杂度。**

---

## 📚 学习地图

- **预计学习时间**：60 分钟
- **前置知识**：iOS开发基础、设计模式
- **学习目标**：理解架构演进 → 掌握各架构特点 → 实战选择适合的架构

---

## 1. 架构设计原则

### 1.1 SOLID原则

**单一职责原则（SRP）：**
```
定义：一个类只应该有一个引起它变化的原因

iOS中的应用：
- UIView和CALayer的职责分离
- UITableViewDataSource和 UITableViewDelegate分离

实现示例：
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

    func viewDidLoad() {
        userService.loadUser { user in
            userView.display(user)
        }
    }
}
```

**开闭原则（OCP）：**
```
定义：对扩展开放，对修改关闭

iOS中的应用：
- Category为现有类添加功能
- Protocol定义抽象接口
- Strategy模式实现算法替换

实现示例：
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

**里氏替换原则（LSP）：**
```
定义：父类可以被子类无缝替换

iOS中的应用：
- KVO原理：动态创建NSKVONotifying_子类
- 所有UIViewController子类都能替换父类使用

实现示例：
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

**接口隔离原则（ISP）：**
```
定义：使用多个专门的接口，而不是单一庞大接口

iOS中的应用：
- UITableViewDelegate和UITableViewDataSource分离
- UIDataSource和UIDelegate分离

实现示例：
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

**依赖倒置原则（DIP）：**
```
定义：抽象不依赖于具体实现，具体实现依赖于抽象

iOS中的应用：
- Protocol定义抽象接口
- Dependency Injection注入依赖

实现示例：
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

### 1.2 架构设计目标

```
好的架构应该关注：

1. 代码均摊
   - 每个类、结构体、方法都有明确的职责
   - 避免God Class（上帝类）
   - 保持代码平衡分配

2. 可测试性
   - 单元测试易于编写
   - 依赖注入方便Mock
   - UI层和业务逻辑分离

3. 易用性
   - 新功能易于添加
   - 代码易于理解和维护
   - 重构成本低

4. 可扩展性
   - 支持功能扩展
   - 支持模块替换
   - 支持多人协作
```

---

## 2. MVC架构

### 2.1 传统MVC

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
        user?.name = nameLabel.text ?? ""
        UserService.updateUser(user!)
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
1. View和Model耦合严重
2. Controller容易变成"大胖子"
3. 难以编写单元测试
4. 不利于代码复用

适用场景：
- 简单的页面
- 快速原型开发
- 学习和演示项目
```

### 2.2 iOS中的MVC变体

**Apple风格的MVC：**
```
iOS中的MVC与标准MVC有所不同：

1. Controller负责：
   - View的生命周期管理
   - 用户交互处理
   - Model和View的协调

2. View和Model直接通信：
   - View可以通过IBOutlet访问Controller
   - Model可以通过KVO/KVC通知View更新

3. 双向绑定：
   - Controller可以同时持有Model和View
   - 实现了数据的双向流动
```

---

## 3. MVP架构

### 3.1 标准MVP

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
1. View和Model完全解耦
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

## 4. MVVM架构

### 4.1 基础MVVM

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
│  - 业务逻辑                          │
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
        user?.name = name
        UserService.updateUser(user!)
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
            self?.nameLabel.text = viewModel.userName
        }

        userEmailObserver = viewModel.observe(\.userEmail) { [weak self] viewModel, change in
            self?.emailLabel.text = viewModel.userEmail
        }

        isLoadingObserver = viewModel.observe(\.isLoading) { [weak self] viewModel, change in
            if viewModel.isLoading {
                self?.activityIndicator.startAnimating()
            } else {
                self?.activityIndicator.stopAnimating()
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

### 4.2 响应式MVVM（Combine/RxSwift）

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
            .sink { [weak self] completion in
                self?.isLoading = false
            } receiveValue: { [weak self] user in
                self?.user = user
                self?.userName = user.name
                self?.userEmail = user.email
            }
            .store(in: &cancellables)
    }

    func updateName(_ name: String) {
        user?.name = name
        UserService.updateUser(user!)
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
3. 过度使用会导致内存泄漏
4. 需要仔细管理生命周期

适用场景：
- 复杂的数据绑定场景
- 需要高测试覆盖率
- 团队熟悉响应式编程
- 长期维护的项目
```

---

## 5. VIPER架构

### 5.1 VIPER结构

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

### 5.2 VIPER实现示例

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
1. 职责划分最清晰
2. 可测试性最高
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

## 6. 架构选择指南

### 6.1 对比分析

| 架构 | 代码量 | 复杂度 | 可测试性 | 学习成本 | 适用项目规模 |
|------|--------|--------|----------|----------|------------|
| **MVC** | 少 | 低 | 低 | 低 | 小型 |
| **MVP** | 中 | 中 | 中 | 中 | 中型 |
| **MVVM** | 中 | 中 | 高 | 高 | 中大型 |
| **VIPER** | 多 | 高 | 最高 | 最高 | 大型 |

### 6.2 选择决策树

```
项目类型选择：

1. 简单项目（单一功能、快速开发）
   → 使用MVC
   - 代码简单直接
   - 开发效率高
   - 容易理解和维护

2. 中等项目（多个模块、需要一定测试）
   → 使用MVP或MVVM
   - MVP：更传统，易理解
   - MVVM：更现代，支持绑定

3. 复杂项目（大型应用、团队协作）
   → 使用MVVM
   - 支持数据绑定
   - 易于单元测试
   - 代码结构清晰

4. 大型项目（企业级、长期维护）
   → 使用VIPER
   - 职责最清晰
   - 可测试性最高
   - 便于多人协作

5. 混合方案（推荐）
   → 针对不同模块使用不同架构
   - 核心模块：MVVM
   - 简单页面：MVC
   - 复杂业务：VIPER
```

### 6.3 实战建议

**渐进式架构演进：**
```
第一阶段：MVC
- 项目初期使用MVC快速开发
- 验证产品功能
- 积累业务理解

第二阶段：部分重构
- 识别复杂模块
- 将复杂模块重构为MVVM
- 建立测试体系

第三阶段：全面重构
- 整体架构升级
- 建立完善的测试
- 统一架构模式
```

**团队协作考虑：**
```
1. 技能水平
   - 初级团队：选择MVC
   - 中级团队：选择MVP或MVVM
   - 高级团队：可以考虑VIPER

2. 项目周期
   - 短期项目：MVC或MVP
   - 中期项目：MVVM
   - 长期项目：VIPER

3. 团队规模
   - 小团队（2-3人）：MVC或MVP
   - 中团队（5-10人）：MVVM
   - 大团队（10+人）：VIPER
```

---

## 7. 架构模式实战

### 7.1 混合架构方案

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

### 7.2 依赖注入

**构造函数注入：**
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

**属性注入：**
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

**方法注入：**
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

## 8. 总结

### 8.1 架构演进趋势

```
架构演进历程：

Cocoa (MVC)
    ↓ 解耦需求
MVP (更清晰的职责分离)
    ↓ 数据绑定需求
MVVM (响应式编程)
    ↓ 可测试性需求
VIPER (极致的模块化)
    ↓ 实用主义
Unidirectional (单向数据流)
    ↓ 函数式编程
Functional Reactive (函数响应式)
```

### 8.2 最佳实践

**选择架构的原则：**
```
1. 根据项目规模选择
   - 小项目：简单架构
   - 大项目：复杂架构

2. 根据团队能力选择
   - 技能弱：简单架构
   - 技能强：先进架构

3. 根据业务复杂度选择
   - 业务简单：MVC足够
   - 业务复杂：MVVM/VIPER

4. 保持一致性
   - 同一项目使用统一架构
   - 便于理解和维护

5. 渐进式重构
   - 不追求一次性完美
   - 随着需求演进架构
```

### 8.3 面试要点

**常见面试问题：**

1. **MVC、MVP、MVVM的区别？**
   - 职责划分不同
   - 数据流向不同
   - 可测试性不同

2. **MVVM的优势？**
   - 数据绑定自动化
   - ViewModel可测试
   - View和Model解耦

3. **VIPER的缺点？**
   - 代码量大幅增加
   - 学习曲线陡峭
   - 初期开发效率低

4. **如何选择架构？**
   - 项目规模
   - 团队能力
   - 业务复杂度
   - 长期维护考虑

---

## 9. 参考资料

### 优质文章
- [iOS Architecture Patterns](https://medium.com/@abdullah.ezen/iOS-architecture-patterns-mvc-mvp-mvvm-viper-8815e441a5f1)
- [MVVM Tutorial with ReactiveCocoa](https://www.raywenderlich.com/6589778-mvvm-tutorial-with-reactivecocoa)
- [VIPER Architecture in iOS](https://www.objc.io/books/good-vibe/)
- [Clean Architecture for iOS](https://blog.cleancoder.io/uncle-bobs-clean-architecture/)

### 开源项目
- [R.swift](https://github.com/mac-cain13/R.swift) - 类型安全的资源访问
- [Swinject](https://github.com/Swinject/Swinject) - 依赖注入框架
- [ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) - 响应式编程框架
- [Combine](https://developer.apple.com/documentation/apple_news/publishing_refining_articles_with_the_publishing_api) - Apple响应式框架

### Apple官方文档
- [Design Patterns: Model-View-Controller](https://developer.apple.com/library/archive/documentation/General/Conceptual/DevPedia-CocoaApp/MVC.html)
- [Cocoa Bindings Programming Topics](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CocoaBindings/index.html)
- [Testing with Xcode](https://developer.apple.com/library/archive/documentation/DeveloperTools/Testing/Testing-top.html)