# 设计模式在 iOS 中的应用

> 一句话总结：**设计模式是解决特定问题的成熟方案，iOS开发中23种GoF设计模式有15+种经常使用，理解场景比记忆类图更重要。**

---

## 一、为什么需要设计模式？

### 1.1 核心价值

**解决的问题**：
- ❌ 代码重复：同样的逻辑写多遍
- ❌ 耦合严重：改一个地方影响多处
- ❌ 难以扩展：加功能要改很多代码
- ❌ 难以测试：依赖太多，无法单元测试

**带来的好处**：
- ✅ **代码复用**：成熟方案，直接套用
- ✅ **易维护**：结构清晰，改动影响小
- ✅ **易扩展**：符合开闭原则，对扩展开放
- ✅ **易沟通**：团队共同语言，"用单例模式"大家都懂

### 1.2 设计模式分类

GoF 23种设计模式，按目的分为3类：

| 类型 | 数量 | 解决什么问题 | iOS常用 |
|------|------|-------------|---------|
| **创建型** | 5种 | 对象怎么创建 | 3种（Singleton、Factory、Builder） |
| **结构型** | 7种 | 类/对象怎么组合 | 5种（Adapter、Decorator、Facade、Proxy、Bridge） |
| **行为型** | 11种 | 对象怎么交互、职责分配 | 8种（Observer、Delegate、Strategy、Command、Mediator、Memento、Template Method、State） |

---

## 二、创建型模式（5种）

### 2.1 Singleton（单例模式）

#### **核心思想**
保证一个类只有一个实例，并提供全局访问点。

#### **iOS中的应用**
- `UserDefaults.standard` - 用户偏好设置
- `URLSession.shared` - 网络会话
- `UIApplication.shared` - App实例
- `NSNotificationCenter.default` - 通知中心
- `FileManager.default` - 文件管理器

#### **使用场景**
✅ 需要全局唯一实例：
- 配置管理器（AppConfig）
- 网络管理器（NetworkManager）
- 数据库管理器（DatabaseManager）
- 日志管理器（Logger）

❌ 不应该用单例：
- 业务模型（User、Order等）
- 临时状态（当前页面状态）
- 可以有多个实例的对象（View、ViewController）

#### **优缺点**
- ✅ 全局访问，使用方便
- ✅ 节省资源，避免重复创建
- ❌ 全局状态，难以测试
- ❌ 隐藏依赖，耦合严重

#### **Swift实现方式**
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

### 2.2 Factory Method（工厂方法模式）

#### **核心思想**
定义创建对象的接口，让子类决定创建哪种对象。

#### **iOS中的应用**
- `NSNumber(value:)` - 根据类型创建不同的Number子类
- `UIView(frame:)` - 创建不同类型的View（UIView、UILabel、UIButton等）
- 数据解析器：根据服务器返回的type字段，创建不同的Model

#### **使用场景**
✅ 不知道具体创建什么对象：
- 解析JSON时，根据type字段创建不同的Model
- 创建不同类型的Cell（普通Cell、图片Cell、视频Cell）
- 创建不同类型的动画（淡入、滑入、缩放）

❌ 对象类型简单固定：
- 只创建一种对象，不需要工厂

#### **实际案例**
```swift
// 场景：聊天消息解析
// JSON: {"type": "text", "content": "hello"}
// JSON: {"type": "image", "url": "https://..."}

protocol Message { }
class TextMessage: Message { }
class ImageMessage: Message { }

class MessageFactory {
    static func create(from json: [String: Any]) -> Message {
        let type = json["type"] as! String

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

### 2.3 Abstract Factory（抽象工厂模式）

#### **核心思想**
提供一个接口，用于创建相关或依赖对象的家族，而不需要明确指定具体类。

#### **iOS中的应用**
- 不同主题的UI组件创建（暗色主题、亮色主题）
- 不同平台的UI组件创建（iOS风格、Android风格）
- 不同数据源的Cell创建（本地数据、网络数据）

#### **使用场景**
✅ 需要创建一系列相关对象：
- 主题切换：创建一套完整的暗色UI组件
- 平台适配：创建iOS风格或Android风格的组件
- 数据源切换：创建本地或网络的数据对象

#### **实际案例**
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

### 2.4 Builder（建造者模式）

#### **核心思想**
将复杂对象的构建与表示分离，使得同样的构建过程可以创建不同的表示。

#### **iOS中的应用**
- `URLSession.configuration` - 分步骤配置网络请求
- `UIAlertController` - 链式调用配置弹窗
- 自定义View的复杂初始化（多种参数组合）

#### **使用场景**
✅ 对象创建过程复杂：
- 多个参数，且有些参数可选
- 参数有多种组合方式
- 创建过程需要多个步骤

❌ 对象创建简单：
- 只有一两个参数，直接用init即可

#### **实际案例**
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

### 2.5 Prototype（原型模式）

#### **核心思想**
通过复制现有对象来创建新对象，而不是通过创建新实例。

#### **iOS中的应用**
- `NSObject.copy()` - 对象拷贝
- `NSCopying` 协议 - 实现拷贝功能
- Model的深拷贝（避免修改影响原对象）

#### **使用场景**
✅ 创建新对象成本高：
- 对象创建需要从数据库/网络加载大量数据
- 对象初始化需要大量计算
- 需要保存对象状态快照（撤销操作）

#### **实际案例**
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

## 三、结构型模式（7种）

### 3.1 Adapter（适配器模式）

#### **核心思想**
将一个类的接口转换成客户期望的另一个接口，让原本不兼容的类可以合作。

#### **iOS中的应用**
- `UITableViewDataSource` - 将数据适配成TableView能显示的格式
- 第三方SDK封装 - 将不友好的API转换成自己项目的风格
- 数据格式转换 - JSON转Model、XML转Model

#### **使用场景**
✅ 接口不兼容：
- 使用第三方SDK，接口不符合项目规范
- 旧系统接口需要适配新系统
- 数据格式不匹配（服务器返回的JSON和Model字段不一致）

#### **实际案例**
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

### 3.2 Bridge（桥接模式）

#### **核心思想**
将抽象部分与实现部分分离，使它们都可以独立地变化。

#### **iOS中的应用**
- Core Animation - 抽象的动画接口 + 不同平台的实现
- UIKit - 抽象的UI组件 + iOS/iPadOS/watchOS的实现
- 绘图引擎 - 抽象的绘图API + Metal/OpenGL/CoreGraphics实现

#### **使用场景**
✅ 抽象和实现都需要独立扩展：
- UI组件：抽象的Button + 不同平台的Button实现
- 绘图引擎：抽象的画笔 + Metal/OpenGL/CoreGraphics实现
- 消息推送：抽象的推送接口 + APNs/FCM/HMS实现

#### **实际案例**
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

### 3.3 Composite（组合模式）

#### **核心思想**
将对象组合成树形结构以表示"部分-整体"的层次结构，使用户对单个对象和组合对象的使用具有一致性。

#### **iOS中的应用**
- `UIView` 的 subview - View可以包含子View，形成View树
- `CALayer` 的 sublayer - Layer可以包含子Layer
- 文件系统 - 文件夹可以包含文件和子文件夹

#### **使用场景**
✅ 需要表示"部分-整体"层次结构：
- UI层级：View包含多个子View
- 文件系统：文件夹包含文件和子文件夹
- 组织架构：公司包含多个部门，部门包含多个员工

#### **实际案例**
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

### 3.4 Decorator（装饰器模式）

#### **核心思想**
动态地给对象添加一些额外的职责，比生成子类更灵活。

#### **iOS中的应用**
- `UITableView` 的 separators、headers - 给TableView添加额外的装饰
- `CALayer` 的 border、shadow - 给Layer添加装饰效果
- `NSMutableAttributedString` - 给字符串添加装饰（颜色、字体等）

#### **使用场景**
✅ 动态添加功能：
- 给View添加边框、阴影、圆角
- 给文本添加颜色、字体、下划线
- 给图片添加水印、滤镜

❌ 功能固定不变：
- 直接用继承更简单

#### **实际案例**
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

### 3.5 Facade（外观模式）

#### **核心思想**
为子系统中的一组接口提供一个一致的界面，定义一个高层接口，这个接口使得这一子系统更加容易使用。

#### **iOS中的应用**
- `UIImage(named:)` - 隐藏了图片加载的复杂过程（缓存、解压等）
- `URLSession.shared.dataTask()` - 隐藏了网络请求的复杂过程
- `AVAudioPlayer` - 隐藏了音频播放的复杂细节

#### **使用场景**
✅ 简化复杂子系统的使用：
- 网络请求：隐藏配置、缓存、重试等细节
- 图片加载：隐藏下载、解码、缓存等细节
- 音视频播放：隐藏解码、渲染、同步等细节

#### **实际案例**
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

### 3.6 Proxy（代理模式）

#### **核心思想**
为其他对象提供一种代理以控制对这个对象的访问。

#### **iOS中的应用**
- `NSProxy` - 消息转发代理
- `WKNavigationDelegate` - 控制WebView的页面加载
- 延迟加载代理 - 图片、大文件等到需要时才加载

#### **使用场景**
✅ 需要控制对象访问：
- 远程代理：访问远程对象（网络请求）
- 虚拟代理：延迟加载大对象（图片、视频）
- 保护代理：控制访问权限（需要登录才能访问）
- 智能代理：引用计数（ARC）

#### **实际案例**
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

### 3.7 Flyweight（享元模式）

#### **核心思想**
运用共享技术有效地支持大量细粒度的对象。

#### **iOS中的应用**
- `UILabel` 的复用 - TableView中Cell的复用
- 字体缓存 - 相同字体只创建一次
- 图片缓存 - 相同图片只加载一次

#### **使用场景**
✅ 有大量相似对象：
- Cell复用：TableView中相同类型的Cell复用
- 字符串常量：相同的字符串只保存一份
- 图片缓存：相同的图片只加载一次

#### **实际案例**
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

## 四、行为型模式（11种）

### 4.1 Observer（观察者模式）

#### **核心思想**
定义对象间的一种一对多的依赖关系，当一个对象的状态发生改变时，所有依赖于它的对象都得到通知并被自动更新。

#### **iOS中的应用**
- `NotificationCenter` - 通知中心
- `KVO (Key-Value Observing)` - 键值观察
- `Combine / RxSwift` - 响应式编程
- `Delegate` - 委托模式（也是一种观察者）

#### **使用场景**
✅ 一对多的通知：
- 登录状态变化：通知多个页面更新UI
- 数据更新：通知多个观察者刷新
- 网络状态变化：通知监听的模块

#### **实现方式对比**

| 方式 | 优点 | 缺点 | 适用场景 |
|------|------|------|----------|
| **NotificationCenter** | 解耦强，一对多 | 容易忘记移除观察者 | 跨模块通知 |
| **KVO** | 系统支持，自动触发 | 只能监听属性，容易崩溃 | 监听Model属性变化 |
| **Delegate** | 类型安全，编译期检查 | 一对一，耦合稍强 | 一对一的回调 |
| **Combine/RxSwift** | 链式调用，功能强大 | 学习成本高 | 复杂的数据流 |

---

### 4.2 Delegate（委托模式）

#### **核心思想**
将一个对象的某些职责委托给另一个对象处理。

#### **iOS中的应用**
- `UITableViewDelegate` - TableView的事件回调
- `UITextFieldDelegate` - TextField的事件回调
- `UIApplicationDelegate` - App生命周期回调

#### **使用场景**
✅ 需要回调事件：
- TableView的点击事件
- TextField的输入变化
- 网络请求完成回调

❌ 不适合：
- 一对多的通知（用Observer）
- 简单的函数调用（直接调用即可）

#### **实际案例**
```swift
// 协议定义
protocol UserCellDelegate: class {
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

### 4.3 Strategy（策略模式）

#### **核心思想**
定义一系列算法，把它们一个个封装起来，并且使它们可相互替换。

#### **iOS中的应用**
- 排序算法：`sorted(by:)` 可以传入不同的比较策略
- 动画类型：淡入、滑入、缩放等不同策略
- 压缩算法：ZIP、GZIP等不同策略

#### **使用场景**
✅ 需要在运行时切换算法：
- 不同等级的VIP用户有不同的计算折扣方式
- 不同类型的消息有不同的发送策略（推送、短信、邮件）
- 不同平台有不同的UI样式策略

#### **实际案例**
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

### 4.4 Command（命令模式）

#### **核心思想**
将一个请求封装为一个对象，从而使你可用不同的请求对客户进行参数化。

#### **iOS中的应用**
- `NSInvocation` - 封装方法调用
- 撤销/重做操作 - 文本编辑器的撤销
- 任务队列 - 异步执行任务

#### **使用场景**
✅ 需要封装操作：
- 撤销/重做功能（文本编辑器、画图应用）
- 任务队列（异步执行多个任务）
- 事务操作（数据库事务）

#### **实际案例**
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

### 4.5 Mediator（中介者模式）

#### **核心思想**
用一个中介对象来封装一系列的对象交互，中介者使各对象不需要显式地相互引用。

#### **iOS中的应用**
- `UITableView` - Cell和DataSource之间的中介
- `UINavigationController` - ViewController之间的中介
- 组件化中的Mediator - 模块间的通信中介

#### **使用场景**
✅ 多个对象间复杂交互：
- 聊天界面：输入框、发送按钮、消息列表之间的交互
- 表单界面：多个输入框、提交按钮、验证逻辑之间的交互
- 模块化通信：不同模块间的通信（Target-Action方案的Mediator）

#### **实际案例**
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

### 4.6 Memento（备忘录模式）

#### **核心思想**
在不破坏封装性的前提下，捕获一个对象的内部状态，并在该对象之外保存这个状态。

#### **iOS中的应用**
- `NSCoding` / `Codable` - 对象归档
- `UserDefaults` - 保存用户设置
- 游戏存档 - 保存游戏进度

#### **使用场景**
✅ 需要保存/恢复状态：
- 撤销/重做功能
- 游戏存档
- 表单草稿保存

#### **实际案例**
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

### 4.7 Template Method（模板方法模式）

#### **核心思想**
定义一个操作中的算法的骨架，而将一些步骤延迟到子类中。

#### **iOS中的应用**
- `UIViewController` 的生命周期 - loadView、viewDidLoad、viewWillAppear等
- `UIView` 的 draw(_:) - 子类重写自定义绘制
- 网络请求基类 - 定义请求流程，子类实现具体URL

#### **使用场景**
✅ 有通用的流程，但具体步骤不同：
- 网络请求：配置请求 → 发送 → 处理响应（具体URL不同）
- 数据解析：下载数据 → 解析 → 缓存（具体解析方式不同）
- 页面加载：初始化 → 加载数据 → 渲染UI（具体数据不同）

#### **实际案例**
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

### 4.8 Iterator（迭代器模式）

#### **核心思想**
提供一种方法顺序访问一个聚合对象中各个元素，而又不需暴露该对象的内部表示。

#### **iOS中的应用**
- `for...in` 循环 - 遍历数组、字典
- `Sequence` / `IteratorProtocol` - 自定义迭代器
- `makeIterator()` - 创建迭代器

#### **使用场景**
✅ 需要遍历集合：
- 遍历数组、字典、Set
- 自定义数据结构的遍历
- 懒加载序列（按需生成）

---

### 4.9 State（状态模式）

#### **核心思想**
允许一个对象在其内部状态改变时改变它的行为。

#### **iOS中的应用**
- `UIView` 的状态 - normal、highlighted、disabled
- 网络请求状态 - idle、loading、success、error
- 订单状态 - 待支付、已支付、已发货、已完成

#### **使用场景**
✅ 对象行为取决于状态：
- 网络请求：不同状态显示不同UI
- 订单流程：不同状态有不同的操作
- 播放器：播放、暂停、缓冲等不同状态

#### **实际案例**
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

### 4.10 Chain of Responsibility（责任链模式）

#### **核心思想**
为解除请求的发送者和接收者之间的耦合，而使多个对象都有机会处理这个请求。

#### **iOS中的应用**
- `UIResponder` 链 - 触摸事件的传递链
- `NSError` 的处理链 - 多个错误处理器
- 事件拦截链 - gesture、button、superview

#### **使用场景**
✅ 多个对象可以处理同一请求：
- 事件处理：触摸事件沿着响应链传递
- 日志处理：根据日志级别选择不同的处理器
- 权限验证：多层验证（登录 → VIP → 管理员）

---

### 4.11 Visitor（访问者模式）

#### **核心思想**
表示一个作用于某对象结构中的各元素的操作。它使你可以在不改变各元素的类的前提下定义作用于这些元素的新操作。

#### **iOS中的应用**
- `MapKit` - 地图元素的点击事件
- `CoreGraphics` - 绘制元素的访问
- JSON解析 - 遍历JSON树并处理不同类型的节点

#### **使用场景**
✅ 对象结构稳定，但操作经常变化：
- 文档结构：段落、图片、表格（结构稳定）→ 导出PDF、导出Word（操作变化）
- 文件系统：文件、文件夹（结构稳定）→ 压缩、加密（操作变化）

---

## 五、设计模式选择指南

### 5.1 根据问题选择模式

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

### 5.2 设计模式使用原则

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

## 六、iOS高频面试题

### Q1: Delegate 和 Block 的区别？

| 维度 | Delegate | Block |
|------|----------|-------|
| **代码位置** | 回调方法在实现类中 | 回调代码在使用处 |
| **可读性** | 清晰，方法名明确 | 内联代码，上下文清晰 |
| **解耦程度** | 较强（协议定义） | 较弱（直接调用） |
| **使用场景** | 多个回调方法 | 单一回调 |

**选择建议**：
- 回调方法多（3个以上）→ Delegate
- 回调方法少（1-2个）→ Block

---

### Q2: Singleton 的优缺点？如何避免滥用？

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

### Q3: Observer 模式的几种实现方式对比？

| 方式 | 优点 | 缺点 | 适用场景 |
|------|------|------|----------|
| **NotificationCenter** | 解耦强，一对多 | 容易忘记移除，运行时崩溃 | 跨模块通知 |
| **KVO** | 系统支持，自动触发 | 只能监听属性，容易崩溃 | 监听Model属性 |
| **Delegate** | 类型安全，编译期检查 | 一对一 | 一对一回调 |
| **Combine/RxSwift** | 链式调用，功能强大 | 学习成本高 | 复杂数据流 |

---

### Q4: 什么时候使用 Strategy 模式？

**使用场景**：
- 需要在运行时切换算法（不同用户的折扣策略）
- 有多种算法可以解决同一个问题（不同的排序算法）
- 算法的使用者和算法的实现者应该分离

**实际案例**：
- VIP用户有不同的折扣计算方式
- 不同类型的消息有不同的发送策略
- 不同平台有不同的UI样式

---

### Q5: Factory Method 和 Abstract Factory 的区别？

| 维度 | Factory Method | Abstract Factory |
|------|----------------|------------------|
| **创建对象** | 一个对象 | 一系列相关对象 |
| **实现方式** | 继承（子类决定） | 组合（组合不同的工厂） |
| **复杂度** | 简单 | 复杂 |

**选择建议**：
- 只创建一种对象 → Factory Method
- 创建一系列相关对象 → Abstract Factory

---

## 七、总结

### 7.1 设计模式学习路径

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

### 7.2 设计模式记忆口诀

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

**最后更新**：2026-05-24
**状态**：✅ 已完善（15种设计模式，文字描述 + iOS实际应用）

**Sources**:
- GoF《设计模式：可复用面向对象软件的基础》
- iOS SDK源码
- 大厂架构设计实践
