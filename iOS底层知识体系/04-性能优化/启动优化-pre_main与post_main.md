# 启动优化-pre_main 与 post_main

> 一句话总结：**启动分为 pre-main（dyld、静态初始化等）与 post-main（业务冷启动）；优化依赖可量化拆解、减负与合理的静态构造治理。**  
> **BootTask / 同步异步启动链等问答** 见 [面试模拟-05-启动优化.md](../../09-面试复盘/面试模拟/面试模拟-05-启动优化.md)。

---

## 📚 学习地图

- **预计学习时间**：45 分钟
- **前置知识**：iOS 开发基础、操作系统原理
- **学习目标**：启动阶段拆分 → pre/post-main 手段 → 监控与回归

---

## 1. 启动优化

### 1.1 启动流程

**启动阶段划分**：

```
pre-main（main 函数之前）：
- dyld 加载动态库
- rebase & rebinding（符号重定位）
- ObjC 类加载、Category 插入
- +load 方法调用

post-main（main 函数之后）：
- main() 函数执行
- didFinishLaunchingWithOptions
- 首屏 ViewController 初始化
- 首屏 View 渲染
```

**时间指标**：

```
理想的启动时间：
- pre-main: < 400ms
- 总启动时间（到首屏显示）: < 1.5s

Apple 标准：
- 20% 用户期望：2 秒内启动
- 80% 用户容忍：4 秒内启动
```

### 1.2 pre-main 优化与二进制重排

**dyld 加载过程**：

```
1. exec() 创建进程
2. 加载 Mach-O Header
3. 加载共享缓存（系统动态库）
4. 加载主程序 Mach-O
5. 递归加载依赖的动态库
6. Rebase & Bind（符号重定位）
7. ObjC setup（类注册、Category 插入、+load）
8. 初始化入口函数
```

**Page Fault对启动的影响：**

```
iOS使用虚拟内存管理，以Page为单位进行内存映射：
- Page大小：16KB
- 映射方式：懒加载（Lazy Loading）
- 触发机制：访问未映射的Page时触发Page Fault

Page Fault开销：
- 每次Page Fault约1微秒~0.8毫秒
- 启动时可能触发数百次Page Fault
- 累计开销可达数百毫秒

二进制重排原理：
传统布局：启动函数分散在不同Page → 多次Page Fault
优化布局：启动函数集中在相邻Page → 减少Page Fault
优化效果：可减少50-80%的Page Fault
```

**优化策略：**

| 优化项 | 具体措施 | 收益 |
|--------|---------|------|
| **减少动态库** | 合并功能相近的库，移除无用库 | 每个库约 1-5ms |
| **懒加载动态库** | 使用 `dlopen` 延迟加载非必须库 | 减少初始化时间 |
| **减少 +load 方法** | 移动到 `+initialize` 或构造函数 | 每个 +load 约 0.1-1ms |
| **移除无用类/方法** | 使用 Dead Code Stripping | 减少 Page Fault |
| **二进制重排** | 将启动时调用的方法排列到相邻页 | 减少 50-80% Page Fault |

**二进制重排详细实现：**

**步骤1：编译期插桩配置**
```c
// Other C Flags: -fsanitize-coverage=trace-pc-guard
// Other Swift Flags: -sanitize-coverage=func -sanitize=undefined
```

**步骤2：实现追踪回调**
```objective-c
#import <dlfcn.h>
#import <libkern/OSAtomic.h>

// 追踪节点数据结构
typedef struct {
    void *pc;        // 程序计数器（函数地址）
    void *next;      // 下一个节点
} SanitizerNode;

// 原子队列
static OSQueueHead traceList = OS_ATOMIC_QUEUE_INIT;

// 追踪节点初始化
void __sanitizer_cov_trace_pc_guard_init(uint32_t *start, uint32_t *stop) {
    static uint32_t nodeCount = 0;

    if (start == stop || *start) {
        return;  // 已经初始化过
    }

    // 为每个追踪节点分配唯一ID
    for (uint32_t *i = start; i < stop; i++, nodeCount++) {
        *i = nodeCount;
    }
}

// 函数调用时的回调
void __sanitizer_cov_trace_pc_guard(uint32_t *guard) {
    // 获取当前程序计数器（调用栈地址）
    void *pc = __builtin_return_address(0);

    // 创建追踪节点
    SanitizerNode *node = malloc(sizeof(SanitizerNode));
    node->pc = pc;
    node->next = NULL;

    // 将节点加入原子队列
    OSAtomicEnqueue(&traceList, node, offsetof(SanitizerNode, next));
}
```

**步骤3：收集调用数据**
```objective-c
// 在AppDelegate中收集数据
- (void)collectFunctionCalls {
    // 从原子队列中取出所有节点
    NSMutableArray<NSString *> *functions = [NSMutableArray array];

    while (true) {
        // 从队列中取出节点
        SanitizerNode *node = OSAtomicDequeue(&traceList, offsetof(SanitizerNode, next));

        if (node == NULL) {
            break;  // 队列为空，结束
        }

        // 将地址转换为函数名
        Dl_info info;
        if (dladdr(node->pc, &info) == 0) {
            free(node);
            continue;
        }

        // 获取函数名
        NSString *functionName = [NSString stringWithUTF8String:info.dli_sname];

        // 处理C函数和Block前缀
        BOOL isObjCMethod = [functionName hasPrefix:@"+["] || [functionName hasPrefix:@"-["];
        if (!isObjCMethod) {
            functionName = [@"_" stringByAppendingString:functionName];
        }

        // 去重
        if (![functions containsObject:functionName]) {
            [functions addObject:functionName];
        }

        free(node);
    }

    // 倒序（因为入栈是逆序）
    NSMutableArray *reversedFunctions = [NSMutableArray array];
    for (NSString *function in [functions reverseObjectEnumerator]) {
        [reversedFunctions addObject:function];
    }

    // 保存到文件
    NSString *functionString = [reversedFunctions componentsJoinedByString:@"\n"];
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"orderfile.txt"];
    [functionString writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
```

**步骤4：生成和应用Order File**
```bash
# 1. 配置Order File路径
# Build Settings → Linking → Order File → order.file

# 2. 验证效果
# Instruments → System Trace
# 查看 "File Backed Page In" 事件数量
# 优化前：1000+ 次，优化后：200-300 次
```

### 1.3 post-main 优化

**优化策略**：

```objective-c
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // ❌ 耗时操作阻塞启动
    [self initializeThirdPartySDKs]; // 500ms
    [self preloadData];              // 300ms
    [self setupDatabase];            // 200ms

    // ✅ 分级初始化
    [self initializeCoreSDKs];      // 必须同步，100ms
    [self initializeSecondarySDKs]; // 可延迟到首屏后

    return YES;
}

// ✅ 异步初始化
- (void)initializeSecondarySDKs {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self initializeAnalytics];
        [self initializePushNotification];
        [self initializeCrashReporter];
    });
}

// ✅ 按需初始化
- (void)setupDatabase {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 在第一次使用数据库时才初始化
    });
}
```

**首屏优化**：

```swift
// ❌ 阻塞主线程
override func viewDidLoad() {
    super.viewDidLoad()
    loadData() // 耗时 500ms
    setupUI()  // 耗时 300ms
}

// ✅ 异步加载
override func viewDidLoad() {
    super.viewDidLoad()
    setupUI() // 立即显示骨架屏或占位内容

    DispatchQueue.global(qos: .userInitiated).async {
        let data = self.loadData()
        DispatchQueue.main.async {
            self.updateUI(with: data)
        }
    }
}
```

### 1.4 启动时间监控

**开发环境**：

```
环境变量：DYLD_PRINT_STATISTICS = 1
输出 pre-main 各阶段耗时
```

**线上监控**：

```objective-c
#import <sys/sysctl.h>
#import <mach/mach.h>

+ (NSTimeInterval)processStartTime {
    struct kinfo_proc kProcInfo;
    int cmd[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    size_t size = sizeof(kProcInfo);

    if (sysctl(cmd, sizeof(cmd)/sizeof(*cmd), &kProcInfo, &size, NULL, 0) == 0) {
        struct timeval startTime = kProcInfo.kp_proc.p_un.__p_starttime;
        return startTime.tv_sec * 1000.0 + startTime.tv_usec / 1000.0;
    }

    return 0;
}

// 在 main 函数中使用
int main(int argc, char * argv[]) {
    @autoreleasepool {
        NSTimeInterval launchTime = [AppState processStartTime];
        NSLog(@"Pre-main time: %.0fms", launchTime);

        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
```

---

---

## 附录：dyld / 启动监控补充（整合）

## 3. dyld 动态链接

### 3.1 dyld 简介

**dyld（Dynamic Linker）**：

```
作用：动态链接器，在程序启动时加载所有依赖的动态库

位置：/usr/lib/dyld
```

**启动流程**：

```
1. Kernel 加载 dyld
2. dyld 加载 Mach-O 主程序
3. dyld 加载共享缓存（系统动态库）
4. dyld 递归加载所有依赖的动态库
5. Rebase & Bind（符号重定位）
6. ObjC Runtime Setup
7. 初始化（+load、constructor）
8. 跳转到 main()
```

### 3.2 Rebase & Bind（符号重定位）

**Rebase（重定位）**：

```
作用：修正内部指针地址

原因：ASLR（地址空间布局随机化）导致加载地址不确定

过程：
1. 读取所有 Rebase 指针
2. 加上 ASLR 偏移值
3. 写回指针位置
```

**Bind（绑定）**：

```
作用：绑定外部符号（动态库中的函数）

过程：
1. 读取所有 Bind 指针
2. 通过符号名查找动态库中的符号地址
3. 将地址写入指针位置
```

**优化**：

```
1. Rebase 使用并发处理（多线程同时处理）
2. Bind 使用递归查找
3. 共享缓存：系统动态库预绑定，减少 Bind 时间
```

### 3.3 ObjC Runtime Setup

**setup 过程**：

```
1. 读取所有 ObjC 类、Category、Protocol
2. 注册所有类（objc_readClassPair）
3. 插入 Category 方法到类的方法列表
4. 调用所有 +load 方法
```

**优化**：

```
1. 缓存类信息
2. 延迟 +load 调用（按需加载）
3. 移除无用类（Dead Code Stripping）
```

---

## 4. 启动优化

### 4.1 启动时间分析

**pre-main 时间**：

```
dyld 加载时间 = Rebase + Bind + ObjC Setup

可通过环境变量查看：
DYLD_PRINT_STATISTICS = 1
```

**输出示例**：

```
dyld: 34.53 ms：100%  (pre-main 启动时间)
    8.20 ms：23.7%  dyld 加载动态库
   12.34 ms：35.7%  Rebase & Bind
    2.14 ms：  6.2%  ObjC Setup
   11.85 ms： 34.3%  其他
```

### 4.2 优化策略

**策略 1：减少动态库数量**

```
优化前：
- 依赖 200 个动态库
- dyld 加载耗时 500ms

优化后：
- 合并功能相近的动态库
- 移除无用动态库
- 依赖 50 个动态库
- dyld 加载耗时 150ms
```

**策略 2：减少 +load 方法**

```objective-c
// ❌ 在 +load 中执行耗时操作
+ (void)load {
    [self initializeHeavyStuff];  // 耗时 200ms
}

// ✅ 延迟到 +initialize
+ (void)initialize {
    [self initializeHeavyStuff];  // 首次使用时才调用
}
```

**策略 3：二进制重排**

**原理**：将启动时用到的函数排列到相邻 Page，减少 Page Fault

**工具**：

```bash
# 1. 生成 Link Map
Build Settings → Write Link Map File: YES

# 2. 分析 Link Map
cat linkmap.txt | grep '.o' | awk '{print $2, $3}' | sort -k2 -rn | head -20

# 3. 生成 Order File
使用 Clang 插桩（-fsanitize-coverage=trace-pc-guard）

# 4. 应用 Order File
Build Settings → Order File → order.file

# 5. 验证效果
Instruments → System Trace → File Backed Page In
```

**示例**：

```swift
// order.file 内容（符号列表）
-[ViewController viewDidLoad]
-[ViewController viewWillAppear:]
...
```

**策略 4：延迟初始化**

```swift
// ❌ 在 didFinishLaunching 中初始化所有模块
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    AnalyticsManager.shared.initialize()    // 耗时 100ms
    PushNotificationManager.shared.setup()   // 耗时 200ms
    DatabaseManager.shared.connect()       // 耗时 300ms

    // 总耗时 600ms
    return true
}

// ✅ 延迟初始化
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // 主线程只做必须的初始化
    DatabaseManager.shared.connect()  // 必须在主线程

    // 其他模块延迟初始化
    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
        AnalyticsManager.shared.initialize()
        PushNotificationManager.shared.setup()
    }

    return true
}
```

### 4.3 启动时间监控

**开发环境**：

```
环境变量：DYLD_PRINT_STATISTICS = 1
输出：pre-main 各阶段耗时
```

**线上监控**：

```objective-c
#import <sys/sysctl.h>

+ (NSTimeInterval)processStartTime {
    struct kinfo_proc procInfo;
    int cmd[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    size_t size = sizeof(procInfo);

    if (sysctl(cmd, sizeof(cmd)/sizeof(*cmd), &procInfo, &size, NULL, 0) == 0) {
        struct timeval startTime = procInfo.kp_proc.p_un.__p_starttime;
        return startTime.tv_sec * 1000.0 + startTime.tv_usec / 1000.0;
    }

    return 0;
}

// 在 main 函数中
int main(int argc, char * argv[]) {
    NSTimeInterval preMainTime = [AppState processStartTime];
    NSLog(@"Pre-main time: %.0fms", preMainTime);

    return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
}
```

### 4.4 业务实践：启动任务分发器（BootTask）

大型 App 常见痛点是 `didFinishLaunching` **堆满初始化**。工程上可拆成 **多枚 BootTask + 统一分发**，并严格划分 **同步 / 异步**（与专题整理一致）：

| 思路 | 说明 |
|------|------|
| **BootTask 协议** | 日志、广告、网络监控、业务配置、启动接口等各占一枚任务类，职责单一、可单测。 |
| **分发器** | 如「Bootor」在启动与前后台切换时 **统一广播** 生命周期，避免在 AppDelegate 里散落 `if`。 |
| **syncLaunch** | 主线程 **必须** 完成且阻塞首屏的：如 IM 连接注册、推送 token请求、首屏强依赖配置等（按业务裁剪）。 |
| **asyncLaunch** | 用户中心、词库、性能监控、设备上报等 **后台队列** 执行，避免拉长首屏。 |
| **路由与 Window** | 登录态决定 RootVC；Tab **懒加载**、非首 Tab延迟初始化。 |

**监控**：除 `DYLD_PRINT_STATISTICS` 外，可对 **`didFinishLaunching` → 首屏 `viewDidAppear`** 打点；需要时用 **进程启动时间**（如 `sysctl` + `kinfo_proc`）辅助分析 pre-main 体感。

---


