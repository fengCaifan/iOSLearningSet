### Dart 如何实现多继承
1. Dart是单继承，需要实现多继承效果可以使用混入mixins方式，混入的类只能继承Object，不能有构造方法，混入相同的方法，回执行最后一个。Dart 的混入（Mixins）是一种用来共享代码的方式，它允许一个类将多个类的功能合并到一个类中。你可以通过 with 关键字将一个或多个混入应用到一个类中。混入并不支持构造函数，因此它们只能包含实例方法和字段。

### 单线程的Dart如何运行，单线程是不是无法实现并发？
1. Dart在单线程中是以消息循环来运行的，其中包含两个任务队列，一个是微任务队列microtask queue，一个是事件队列event queue。
2. 将需要异步执行的逻辑交给微任务队列或事件队列。
3. Future就是将任务插入到事件队列。如果向微任务队列插入任务：Future.microtask()、scheduleMicrotask()，Stream中的执行异步的模式就是scheduleMicrotask。
因为microtask的优先级又高于event，如果 microtask 太多就可能会对触摸、绘制等外部事件造成阻塞卡顿。
两个任务队列通过UI Task Runner执行
4. Flutter 运行时会把 Dart VM 的_scheduleMicrotask关联到 Engine，所以 Dart 的 MicroTask 处理会占用 Engine 的资源。

5. Event Queue和Microtask Queue提供了任务的优先级以及排队机制，通过Task Runner在适当的线程上执行这些任务
6. Isolate，一种并发编程机制，运行在同一程序中并行执行代码，与多线程不同，有独立内存和事件队列，通过消息传递进行通信，避免由于内存带来的数据竞争和同步问题。可以理解为Dart中的线程，跟准确的说是一种微线程。与线程最大的区别就是不共享内存，所以也不存在锁竞争等问题。只能通过发送消息通信，开销低于线程。
   一般情况下，我们可以无需关心Isolate。当Flutter应用程序启动的时候，会默认启动一个主Isolate，此时，所有的Dart代码都会在主Isolate内执行。虽然我们无需关心Isolate，但可以通过使用 async-await 来处理异步操作，也完全可以流畅运行。

#### 追问：isolate 有什么性能问题么？

4. 为了减少 isolate 创建所带来的消耗，建出一个 isolate 线程池 LoadBalancer，并自动实现了负载均衡，runMultiple可以让一个方法在多个isolate中执行，LoadBalancer会在第一次使用的时候创建isolate。

### await for 关键词有什么作用

1. await for 不断获取stream流中的数据，然后执行循环体中的逻辑。

### 线程合并

- 用一个 Task Runner 同时消费处理两个 Task Queue 中排队的任务。

### Stream
1. StreamController: 用于创建和管理 Stream。它可以添加事件到流中，并控制流的状态。
2. StreamSubscription: 用于订阅 Stream，接收流中的事件，并可以取消订阅。

### **Flutter 如何实现跨平台渲染？**

- 使用 **Skia 渲染引擎** 绘制 UI，不使用原生控件。
- Flutter 将 Dart 代码 AOT 编译为机器码，直接在平台 canvas 上绘制像素。
- 因此在 iOS / Android / Web 外观一致、性能稳定。

### 讲讲 flutter 中的事件竞争

Flutter 事件流从 PointerEvent → Gesture → Listener → GestureArena。

✔ Widget 不直接响应事件，真正接收事件的是 Element 对应的 RenderObject。

✔ 当多个手势（GestureRecognizer）想响应同一事件时，会进入 Gesture Arena：

- 谁先确认（accept）谁赢；
- 谁放弃或冲突失败，就 cancel；
- 典型场景：Tap vs DoubleTap、滑动 vs 点击。

✔ 解决冲突可用：`HitTestBehavior`、`AbsorbPointer`、`RawGestureDetector`、自定义 GestureRecognizer。

### final和const有什么区别

`final` 表示变量只能被赋值一次，但它的值可以在运行时确定。而 `const` 是编译时常量，必须在编译时就确定，且对象会被放入常量池中实现内存复用。

所以：

* **时间点不同**：final = run-time，const = compile-time

* **内存不同**：const 对象全局唯一（canonicalized）

* **类中 const 需要 static 修饰**

* **Flutter 推荐在 Widget 中多用 const，提高性能**。

### 如何实现websocket的稳定链接
1. 发送心跳数据
2. 捕获关闭连接事件，然后重连
3. 短线重连

### 你了解 flutter 的 Plugin-in 机制么
在 Flutter 中，PlatformView是一种机制，允许你在 Flutter 应用中嵌入原生视图（如 Android 的 View 或 iOS 的 UIView）。这使得 Flutter 应用能够利用平台特定的功能或组件，同时保持 Flutter 的 UI 构建能力。
- 和原生视图之间可以通过消息传递进行交互。
- 可以扩展Flutter应用的能力，满足更多的需求。比如集成地图

### 线程合并|四大Task Runner|四大线程
四大 Task Runner 是用于管理和调度不同类型任务的组件，确保高效的渲染和响应性。它们分别是：

- UI Task Runner：主线程，Event Queue 和 Microtask Queue
- IO Task Runner：后台线程中执行
- Platform Task Runner：主线程
- GPU Task Runner：独立线程

四大线程：Platform线程、UI线程、Raster线程、IO线程

platform 线程和 Raster 线程在使用 __PlatformView__ 的场景时需要合并和分离的问题。之前的官方的线程合并机制，只支持一对一的线程合并，但多引擎场景就需要一对多的合并和一些相关的配套逻辑。
__Flutter 需要在主线程上进行UI更新，而原生视图可能会在不同的线程上处理事件和渲染。__

调度：Flutter 使用任务队列来调度任务，确保任务按照优先级和依赖关系进行执行。
线程安全：由于UI更新只能在主线程上进行，其他任务会在相应的线程中处理，以保持应用的响应性。

### flutter和其他款平台框架的优势？
1. 快速开发：热重载，所见即所得。
2. 单一代码库：
3. UI：大量的UI组件
4. 高性能：使用自己的渲染引擎Skia，可以直接绘制UI，
5. 开发工具：Flutter Dev Tools，Flutter Inspector帮助开发者调试和性能优化。
6. 广泛的领域：

### Dart的final和const有什么区别？（与上述相同，问的比较多）
都是用来声明常量，final声明只能被赋值一次，不能被修改，运行时初始化，可以延迟初始化，可以使表达式计算的结果，const只能被赋值一次，不能被修改，编译时常量

### 工厂函数

工厂函数是一个特殊的构造函数，类似于swift的convenience

Object是超类，可以表示任何对象
dynamic是一种动态类型，编译时没有类型检查，可以被赋任何类型的值，可能会导致类型错误，运行时异常。
var用来声明变量，编译器会根据赋值推断出类型，并且在编译时进行静态类型检查。

### Dart中的casecade级联和extension扩展运算
级联运算符：..同一对象执行多个操作，无需重复引用该对象

### mixin混入和interface接口有何区别？（问的多）
mixin是一种在类中重用代码的机制，

### 状态管理
setState，
Provider是基于InheritedWidget基础上封装，依赖注入的概念，可以在组件树的任何位置共享状态，通知相关子组件进行更新，适用于中等应用。
Bloc：是一种基于Rx响应式编程和单向数据流的状态管理库，内部使用Stream和Sink来处理输入和输出，并使用事件和状态流来管理应用状态。Bloc适用于复杂的业务逻辑和交互。将应用程序的状态和事件分离，并提供了强大的工具和模式来处理异步操作和状态变化。
MobX：基于观察者模式，支持响应式编程，声明式编程风格，能够自动处理状态变化
GetX：高度集成，不够灵活。

Redux：Redux是一个基于Flux架构的状态管理库，它通过单一的全局状态存储（Store）和纯函数（Reducers）来管理状态。**Redux使用了不可变数据和单向数据流的概念**，并通过派发操作（Actions）来触发状态的变化。Redux适用于大型应用或需要严格的状态管理和可预测性的场景。

Riverpod：使用一个声明式的 API，Riverpod不需要依赖注入的机制。你只需要定义 Provider 并在需要的地方访问它们。
而不需要显式地管理状态的生命周期。不依赖BuildContext，对测试非常友好

### Bloc 和 Cubit 之间有什么区别？
Cubit是Bloc的简化版本，没有异步操作和副作用管理，更加轻量简洁，适用于中小型应用或简化的状态管理需求。
Bloc是通过Stream来管理状态，通过派发事件流（Event）和监听状态流（State）来更新状态。Cubit是使用一个单一的State对象来管理
单向数据流，不可变状态原则，类似的工作方式和API

### 依赖注入
依赖注入（Dependency Injection）是一种设计模式，管理程序中的依赖关系，可以解耦组件之间的依赖关系，代码的可测试性、可维护性和可扩展性都会有提高。
controller，route，service，配置环境变量等

Get_it依赖注入的第三方库，提供了一个简单强大的依赖注入容器，使得在应用程序中管理和访问依赖变得更加容易

### Flutter 是如何与原生Android、iOS进行通信的？
PlatformChannel
BasicMessageChannel ：用于传递字符串和半结构化的信息。
MethodChannel ：用于传递方法调用（method invocation）。
EventChannel : 用于数据流（event streams）的通信。

### 性能优化（会问，但问的都比较宽泛，提问方式不统一）
* 启动速度
iOS:减少启动时间: 使用launch screens代替复杂的启动界面，减少在启动期间执行的任务。
    懒加载: 延迟加载非关键资源，尽量在应用启动后进行加载。
    优化应用初始化: 避免在application(_:didFinishLaunchingWithOptions:)方法中执行耗时操作，将其转移到后台线程。
Android:
    优化onCreate()方法: 避免在Activity的onCreate()方法中进行耗时操作，考虑使用异步任务或延迟加载。
    使用SplashScreen: 显示启动屏幕（Splash Screen）来掩盖启动时间。
    分离启动逻辑: 将复杂的启动逻辑分散到后台线程中，以减少主线程的负担。

* OOM（Out Of Memory）
iOS:合理管理内存: 避免持有不必要的强引用，使用weak或unowned引用来防止内存泄漏。
    内存警告处理: 实现applicationDidReceiveMemoryWarning(_:)来释放不必要的资源。
    使用 Instruments: 利用Instruments工具来检测内存泄漏和分析内存使用情况。
Android:
    优化内存使用: 避免加载大量数据到内存中，使用Bitmap的压缩和重用机制。
    内存监控: 使用Android Profiler和LeakCanary来监控和检测内存泄漏。
    垃圾回收: 注意合理使用WeakReference和SoftReference来减少内存压力。

* 卡顿治理
  iOS:避免主线程阻塞: 确保耗时操作在后台线程中执行，使用GCD或OperationQueue来进行异步处理。
    优化UI渲染: 使用Instruments分析主线程的CPU使用情况，优化UI渲染和布局。
    减少视图层次: 简化视图层次结构，避免嵌套过深的视图。
  Android:
    异步操作: 使用AsyncTask、Handler或Executor来处理耗时操作，避免阻塞UI线程。
    优化布局: 减少布局的深度和复杂性，使用ConstraintLayout等高效的布局容器。
    性能分析工具: 使用Android Studio Profiler分析和优化应用的性能。
* 包体积
iOS:资源优化: 删除未使用的资源和依赖，优化图片和音频文件。
    分割资源: 使用App Thinning和On-Demand Resources来分割和优化资源包。
    编译优化: 使用Bitcode以减少应用包的大小。
Android:
    使用ProGuard/R8: 通过混淆和压缩代码来减少APK的体积。
    分割APK: 使用Android App Bundles和Dynamic Delivery来实现按需下载和安装的模块化。
    压缩资源: 优化图片资源，使用WebP格式和其他压缩工具。

* 耗电量
  iOS:优化后台任务: 避免频繁使用后台更新和定位服务，使用BackgroundTasks合理调度任务。
    减少不必要的网络请求: 合理规划网络请求和数据同步，减少频繁的后台通信。
    使用Energy Diagnostics: 利用Instruments的Energy Diagnostics工具来监测和优化电池消耗。
  Android:
    优化后台服务: 减少后台服务的运行时间，使用JobScheduler或WorkManager来合理安排任务。
    减少位置更新频率: 优化位置服务的使用频率和精度。
    使用Battery Historian: 监测和分析应用的电池消耗情况，优化耗电量大的操作。

在flutter中，通过以下操作进行优化

* 启动速度
- 减少启动时间：
    使用启动画面：Splash Screen，修改Android/iOS的启动画面来掩盖应用启动时的延时。
    优化main方法：避免在main中进行耗时操作，将初始化逻辑分散到应用的生命周期中，比如initState方法
- 懒加载：
    初始化延迟：对于一些必须要在启动后初始化的内容，使用懒加载技术，在应用启动后进行加载。
    分离启动界面：尽量将复杂的启动逻辑和初始化异步执行。

* OOM
- 合理的内存管理：
    优化图片资源：使用CachedNetworkImage或flutter_cache_manager等库来缓存和优化图片资源，避免一次性加载大量图片。
    避免内存泄露：在dispose()中释放不在使用的资源和订阅等，例如Stream和AnimationController， __我发现Gate.io中使用了大量的动画，如果不合理的使用和释放AnimationController就有可能造成内存泄露。__
- 监控内存使用：
    Flutter DevTools提供了大量的开发工具，可以使用Memory来监控内存使用情况，检测出内存泄露和优化内存占用。

* 卡顿治理：
因为flutter是单线程，所以卡顿一般都要在线程的角度入手。
- 避免主线程阻塞：
    异步编程：使用Future、async/await来处理异步操作，比如耗时操作比如读文件、网络请求等，放在异步方法中，保证主线程UI流程。
- 优化UI渲染：
    使用Flutter性能工具：Flutter DevTools中提供的Preformance可以分析和优化应用的UI渲染性能。
    避免过渡的重绘：尽可能保证只更新需要更新的部分，减少不必要的UI重绘。还有静态组件可以通过const构造函数来优化。（const修饰在编译时确定）
- 简化布局：
    减少布局嵌套：
    使用RepaintBoundary：对于需要频繁重绘的部分，使用RepaintBoundary来隔离重绘区域，提高渲染性能

### 包体积
- 资源优化：
    压缩和优化资源：压缩图片，使用webp格式的图片。
    清理不必要的资源：删除未使用的资源文件。
- 代码优化：
    删除不必要的依赖包
- 使用Flutter build工具：
    构建时优化：使用flutter build apk --release来生成优化后的发布版本，开启ProGuard和代码混淆以减少APK的体积。

### 耗电量
- 优化后台任务：
    减少后台操作：后台任务重尽量减少不必要的电池消耗，如频繁的网络请求和长时间计算任务，包括获取gps定位等。
    使用WorkManager插件：对于需要后台处理的任务，考虑使用workmanager插件进行后台任务调度和管理。
- 优化位置服务：
    减少位置跟新频率：
- 使用性能分析工具：
    Flutter DevTools：使用Preformance和Timeline来分析电池使用情况，并优化耗电量大的操作。


### 常用组件

1. 布局组件
    Container: 用于创建一个矩形区域，可以设置边距、填充、对齐、装饰等属性。
    Row: 横向布局组件，子组件会在水平轴上排列。
    Column: 纵向布局组件，子组件会在垂直轴上排列。
    Stack: 允许子组件重叠显示，层级关系由添加顺序决定。
    Flex: 更灵活的布局组件，可以控制子组件在主轴上的扩展和收缩。
    Expanded: 用于在 Row 或 Column 中占据剩余空间的组件。
2. 输入组件
    TextField: 文本输入框，支持多种文本输入和验证功能。
    Checkbox: 复选框，用户可以选择或取消选择。
    Radio: 单选按钮，用于选择一组选项中的单一选项。
    Switch: 开关按钮，用于在两种状态之间切换。
    Slider: 滑块，用于选择一个范围内的值。
3. 按钮组件
    ElevatedButton: 带有阴影的按钮，通常用于主要操作。
    TextButton: 没有阴影的按钮，通常用于次要操作。
    OutlinedButton: 带有边框的按钮，常用于需要突出但不需要填充的按钮。
4. 显示组件
    Text: 显示文本的基本组件，支持多种文本样式和格式化。
    Image: 显示图片，支持从网络、本地文件或资源加载图片。
    Icon: 显示图标，支持 Material 和 Cupertino 图标库。
    Card: 用于显示内容的卡片式组件，带有阴影和圆角。
5. 列表和网格组件
    ListView: 滚动的列表视图，支持纵向或横向滚动。
    GridView: 网格布局的列表视图，可以显示可滚动的网格。
    ListTile: 列表项组件，通常用于 ListView 中，包含标题、子标题和图标。
6. 对话框和底部弹出
    AlertDialog: 弹出对话框，通常用于显示消息或提示用户进行选择。
    BottomSheet: 底部弹出菜单，常用于显示额外的内容或操作选项。
    SnackBar: 短暂显示的提示条，通常用于展示简单的操作反馈。
7. 导航组件
    Navigator: 用于管理应用的路由和页面堆栈，支持页面跳转和返回。
    Drawer: 抽屉式导航菜单，通常用于应用的侧边栏。
    BottomNavigationBar: 底部导航栏，常用于应用的主要页面切换。
8. 动画和装饰
    AnimatedContainer: 带有动画效果的容器，支持平滑的属性过渡。
    Hero: 用于创建页面切换时的共享元素动画。
    FadeTransition: 渐隐渐现的动画过渡效果。
9. 表单和验证
    Form: 用于管理表单状态和验证。
    FormField: 表单字段的基类，可以自定义表单输入组件。
10. 滚动组件
    SingleChildScrollView: 允许单个子组件在一个方向上滚动。
    CustomScrollView: 支持多个滚动视图的自定义滚动视图，通常与 Sliver 组件结合使用。
11. Sliver
     在Flutter中，Sliver是用于构建灵活和高性能滚动效果的组件。可变大小的滚动元素，高性能滚动，灵活的自定义

### Flutter的JIT和AOT

两种不同的编译方式，将flutter代码转换为机器代码。

1. JIT(just in time)编译：开发调试阶段，JIT将Dart代码转换为中间代码，在运行时动态的将中间代码转换为机器代码，允许热重载，更快的开发周期和编译时间，但应用程序执行相对较慢。
2. AOT(Ahead of time)编译：发布生产环境时使用AOT编译，AOT将Dart代码预先编译为机器代码，生成二进制文件，更快的启动和更高的执行性能，不支持热重载，编译时间较长。

### 