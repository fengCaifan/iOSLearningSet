# Crash捕获与防护体系建设

> 一句话总结：**Crash防护体系包含监控、捕获、分析、防护四个层次，通过异常捕获、信号处理、堆栈分析等技术手段，建立完整的崩溃治理体系。**

---

## 📚 学习地图

- **预计学习时间**：60 分钟
- **前置知识**：OC异常机制、Unix信号、Mach内核
- **学习目标**：理解Crash类型 → 掌握捕获技术 → 建立防护体系

---

## 1. Crash类型与原理

### 1.1 Crash分类体系

```
iOS崩溃类型：
├── Mach内核异常
│   ├── EXC_BAD_ACCESS (非法内存访问)
│   ├── EXC_BAD_INSTRUCTION (非法指令)
│   ├── EXC_ARITHMETIC (算术异常，如除零)
│   └── EXC_BREAKPOINT (断点异常)
├── POSIX信号 (Unix标准信号)
│   ├── SIGSEGV (段错误)
│   ├── SIGBUS (总线错误)
│   ├── SIGABRT (程序中止)
│   ├── SIGFPE (浮点异常)
│   ├── SIGILL (非法指令)
│   └── SIGPIPE (管道破裂)
└── OC异常 (应用层异常)
    ├── NSException (未捕获的OC异常)
    ├── C++异常 (未捕获的C++异常)
    └── 用户自定义异常
```

### 1.2 常见Crash场景分析

| Crash类型 | 常见原因 | 检测方式 |
|-----------|----------|----------|
| **野指针访问** | 访问已释放对象 | SIGSEGV信号 |
| **数组越界** | 超出数组索引范围 | SIGABRT信号 |
| **字典nil值** | 向字典添加nil对象 | NSException |
| **KVO未移除** | 观察者未正确移除 | 访问已释放对象 |
| **Main Thread Timeout** | 主线程卡顿超过阈值 | 系统强杀 |
| **Memory Warning** | 内存压力过大 | Jetsam机制 |
| **后台超时** | 后台任务执行超时 | 系统强杀 |

---


## 1.3 Crash Report 到根因：标准排查流程（核心）

> **先读报告，再建假设，再线下验证。** `EXC_BAD_ACCESS`、`SIGABRT`、`NSRangeException` 是异常呈现，不是根因名称。不要看到一个 signal 就直接说“野指针”“OOM”。

### 第 0 步：确认报告完整性与优先级

```text
确认 dSYM / UUID 符号化是否正确
→ 看影响用户数、发生次数、首发版本、趋势
→ 按核心路径、机型、系统、页面、业务场景分桶
→ 优先处理影响大且证据完整、可复现的问题
```

### 第 1 步：按异常呈现进入不同的首查路径

| Crash Report 呈现 | 首先看什么 | 常见假设 | 不能直接下的结论 |
|---|---|---|---|
| `NSRangeException` | reason、最后业务帧、下标/集合大小 | 数组/字符串/集合越界 | “系统 Foundation 有 Bug” |
| `NSInvalidArgumentException` | reason、receiver/参数真实类型 | nil/类型不对、错误参数、API 使用错误 | “一定是野指针” |
| `NSInternalInconsistencyException` | reason、UIKit/AppKit 断言、调用时序 | 生命周期/API 使用前提不满足、布局/状态不一致 | “只要吞异常即可” |
| `unrecognized selector` | receiver 实际类、selector、对象生命周期 | 类型边界错误、对象已被替换/释放、接口契约错误 | “全局消息转发能修好” |
| `EXC_BAD_ACCESS` + `SIGSEGV` / `SIGBUS` | subtype、fault address、崩溃指令、最后业务帧、线程时序 | 非法内存访问、越界、桥接、C/C++、竞态 | “一定是野指针” |
| `SIGABRT` / `EXC_CRASH` | exception reason、abort 前日志、最后业务帧 | `abort()`、未处理 Exception、Swift fatal/precondition、断言 | “一定是内存问题” |
| `EXC_BREAKPOINT` / `SIGTRAP` | reason、Swift Runtime/断言栈、业务断言 | `fatalError`、`preconditionFailure`、Swift 运行时 trap、开发者断言 | “用户点了断点” |
| `EXC_BAD_INSTRUCTION` / `SIGILL` | 崩溃指令、Swift runtime 栈、业务 reason | 非法指令、运行时 trap、错误函数指针/ABI | “一定是第三方 SDK” |
| `EXC_ARITHMETIC` / `SIGFPE` | 指令、输入、数学计算路径 | 除零、溢出/算术异常（依语言/编译设置） | “一定是浮点问题” |
| `malloc` / `NSAllocateMemory` / `CGContext` 分配失败 | footprint、资源尺寸、缓存、机型、场景 | 内存压力、峰值、堆损坏、资源过大 | “一定是 OOM” |
| 无普通 Crash Report、下次异常启动 | 运行标记、前后台、Crash/Watchdog/升级排除 | Jetsam、Watchdog、疑似 FOOM 或其他退出 | “一定是 FOOM” |

> 用户常写成“`EXC_BAD_SEGV`”，准确写法通常是 **`EXC_BAD_ACCESS`**；它可能以 BSD signal **`SIGSEGV`** 或 **`SIGBUS`** 呈现。

### 第 2 步：所有类型通用的证据链

```text
异常类型 / reason / signal
→ 崩溃线程：从系统栈向下找最后一个业务帧
→ 版本、机型、系统、页面、用户路径、发生时机
→ 其他线程、对象创建/取消/释放、请求/任务回调时序
→ 建立 2~3 个可验证假设
→ 最小复现 + 对应工具验证
→ 根因修复 + 测试 + 灰度 + 分桶回归
```

`fault address` 只是证据之一，不是“必须先确认无效地址”的前置条件。对 `EXC_BAD_ACCESS`，系统已说明访问触发了内存异常；要并行看以下证据：

| `EXC_BAD_ACCESS` 证据 | 如何使用 | 不能证明什么 |
|---|---|---|
| `Exception Subtype: KERN_INVALID_ADDRESS` | 常见于无效虚拟地址访问 | 不能区分野指针、空指针、越界、堆损坏或 race |
| `Exception Subtype: KERN_PROTECTION_FAILURE` | 地址/页可能存在，但读写执行权限不符 | 不代表对象一定已释放 |
| Fault Address 是 `0x0` / `0x8` / `0x10` 等 | 常提示 null 指针加成员偏移访问 | 地址形态不是根因证据 |
| 随机高地址 / 地址重复出现 | 可作为 use-after-free、越界、堆损坏的线索 | 地址会复用，不能仅凭地址定性 |
| 崩溃线程最后业务帧 | 找到是谁把调用带入 `objc_msgSend`、`malloc`、CoreGraphics 或 SDK | 栈顶在系统库不代表系统库有 Bug |
| 其他线程与页面退出/回调时序 | 建立生命周期错位或 data race 假设 | 多线程存在不等于已经证明 race |

### 第 3 步：针对不同类别选择验证工具

| 假设 | 最小复现方法 | 验证工具 | 能确认什么 | 常见修复 |
|---|---|---|---|---|
| ObjC 对象释放后仍收消息 | 进入页面→发起异步/Timer→立即退出→延迟回调 | Zombie | 已释放对象的类和访问调用点 | 明确 owner、取消任务、`invalidate`/`removeObserver`、弱引用与会话 ID 校验 |
| C/C++/CF 越界、use-after-free、double free | 压力路径、边界输入、图片/音视频处理 | ASan | 被插桩代码的典型越界/释放后访问 | 边界检查、所有权、正确 bridge、释放后置空 |
| 无同步并发读写 | 延迟/并发压力回放、重复操作 | TSan | data race | actor/锁/串行队列、线程封闭、不可变快照 |
| 业务 Exception | 用 reason 与业务参数还原输入 | 断点、单测、断言、日志 | 业务状态/参数违反 API 前提 | 修调用方、边界检查、状态机、测试 |
| 内存峰值 / 分配失败 | 低端机、超大资源、列表/页面压力 | Allocations、VM Tracker、Memory Graph | 分配曲线、峰值、大户、泄漏线索 | 降采样、缓存限额、分页、退场清理 |

工具边界：Zombie 不能线上常开；ASan/TSan 开销大，通常用于 Debug/CI；Memory Graph/Leaks 找的是持有关系或泄漏，不能验证野指针。

### 第 4 步：修复、止血与回归

```text
根因修复优先：所有权 / 生命周期 / 线程同步 / 业务边界 / 资源峰值
→ 单测、压力回放、静态分析 / Sanitizer
→ 灰度发布，按版本/机型/场景观察同类 Issue
→ 告警、Code Review 规则、防回归测试
```

Runtime 防护仅适用于**高频、边界明确、可安全降级且已有证据**的问题；必须白名单、开关、日志、灰度、回滚。禁止将全局吞 `EXC_BAD_ACCESS`、未知 selector 或业务 Exception 当成常规治理方案，否则可能把 Crash 转为数据错误。

### 面试回答模板：从异常到治理

> 我先按 Crash Report 的呈现分类，而不按异常名直接下根因。例如业务 Exception 优先用 reason 和最后业务栈帧复现；对 `EXC_BAD_ACCESS` / signal，我会并行看 subtype、fault address、最后业务帧、页面与线程时序，形成生命周期、越界/bridge、C/C++ 或并发竞争等假设，再用 Zombie、ASan、TSan 或压力复现验证。修复时优先改所有权、取消/回调契约、同步边界或资源峰值；上线通过灰度和分桶观察同类 Issue 收敛。Runtime 防护只做少量可安全降级的白名单止血，不替代根因修复。

## 2. 异常捕获机制

### 2.1 OC异常捕获

```objective-c
#import <Foundation/Foundation.h>

// 异常处理回调
static void uncaughtExceptionHandler(NSException *exception) {
    // 1. 获取异常信息
    NSString *name = [exception name];
    NSString *reason = [exception reason];
    NSArray *stackTrace = [exception callStackSymbols];

    // 2. 构建崩溃报告
    NSString *crashReport = [NSString stringWithFormat:@"Exception Name: %@\n"
                            "Exception Reason: %@\n"
                            "Stack Trace:\n%@",
                            name, reason, [stackTrace componentsJoinedByString:@"\n"]];

    NSLog(@"Uncaught Exception: %@", crashReport);

    // 3. 保存到本地文件
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
                     stringByAppendingPathComponent:@"crash_report.txt"];
    [crashReport writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];

    // 4. 上传到服务器（可选）
    // [CrashReporter uploadCrashReport:crashReport];
}

// 安装异常处理器
void installExceptionHandler() {
    // 保存原有的处理器
    NSUncaughtExceptionHandler *oldHandler = NSGetUncaughtExceptionHandler();

    // 设置新的处理器
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
}

// 使用示例
- (BOOL)application:(UIApplication *)application
 didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // 安装异常处理器
    installExceptionHandler();

    return YES;
}
```

### 2.2 信号处理器

```objective-c
#import <signal.h>
#include <execinfo.h>

// 信号处理回调
static void signalHandler(int signal) {
    // 1. 获取堆栈信息
    void *callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);

    // 2. 构建崩溃报告
    NSMutableString *crashReport = [NSMutableString string];
    [crashReport appendString:@"Signal Handler:\n"];

    // 信号类型
    NSString *signalName = @"";
    switch (signal) {
        case SIGSEGV:
            signalName = @"SIGSEGV (Segmentation Fault)";
            break;
        case SIGBUS:
            signalName = @"SIGBUS (Bus Error)";
            break;
        case SIGABRT:
            signalName = @"SIGABRT (Abort)";
            break;
        case SIGFPE:
            signalName = @"SIGFPE (Floating Point Exception)";
            break;
        case SIGILL:
            signalName = @"SIGILL (Illegal Instruction)";
            break;
        case SIGPIPE:
            signalName = @"SIGPIPE (Broken Pipe)";
            break;
        default:
            signalName = [NSString stringWithFormat:@"Signal %d", signal];
            break;
    }

    [crashReport appendFormat:@"Signal: %@\n", signalName];

    // 堆栈信息
    [crashReport appendString:@"Stack Trace:\n"];
    for (int i = 0; i < frames; i++) {
        [crashReport appendFormat:@"%s\n", strs[i]];
    }

    NSLog(@"Signal Crash: %@", crashReport);

    // 3. 清理资源
    free(strs);

    // 4. 保存并上报
    // [CrashReporter uploadCrashReport:crashReport];

    // 5. 调用默认信号处理（通常会导致进程退出）
    signal(signal, SIG_DFL);
    raise(signal);
}

// 安装信号处理器
void installSignalHandler() {
    signal(SIGSEGV, signalHandler);
    signal(SIGBUS, signalHandler);
    signal(SIGABRT, signalHandler);
    signal(SIGFPE, signalHandler);
    signal(SIGILL, signalHandler);
    signal(SIGPIPE, signalHandler);
    signal(SIGHUP, signalHandler);
    signal(SIGINT, signalHandler);
    signal(SIGQUIT, signalHandler);
}
```

### 2.3 完整的Crash捕获框架

```objective-c
// CrashReporter.h
#import <Foundation/Foundation.h>

@interface CrashReporter : NSObject

+ (instancetype)sharedInstance;

// 安装Crash监控
- (void)installCrashHandler;

// 上传Crash报告
- (void)uploadCrashReports;

@end

// CrashReporter.m
#import "CrashReporter.h"
#import <sys/signal.h>
#include <execinfo.h>

@interface CrashReporter ()
@property (nonatomic, strong) NSMutableArray *pendingCrashReports;
@property (nonatomic, assign) NSUncaughtExceptionHandler *previousExceptionHandler;
@end

@implementation CrashReporter

+ (instancetype)sharedInstance {
    static CrashReporter *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CrashReporter alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _pendingCrashReports = [NSMutableArray array];
    }
    return self;
}

- (void)installCrashHandler {
    // 1. 安装OC异常处理器
    [self installExceptionHandler];

    // 2. 安装信号处理器
    [self installSignalHandler];

    // 3. 检查是否有未上传的Crash
    [self loadPendingCrashReports];
}

#pragma mark - OC异常处理

- (void)installExceptionHandler {
    // 保存原有处理器
    self.previousExceptionHandler = NSGetUncaughtExceptionHandler();

    // 设置新处理器
    NSSetUncaughtExceptionHandler(&handleException);
}

static void handleException(NSException *exception) {
    // 获取异常信息
    NSDictionary *crashInfo = @{
        @"type": @"NSException",
        @"name": [exception name],
        @"reason": [exception reason],
        @"stackTrace": [exception callStackSymbols],
        @"timestamp": [NSDate date],
        @"appVersion": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
        @"deviceModel": [self getDeviceModel],
        @"systemVersion": [[UIDevice currentDevice] systemVersion]
    };

    // 保存Crash信息
    [[CrashReporter sharedInstance] saveCrashReport:crashInfo];

    // 调用原有处理器（如果有）
    if ([CrashReporter sharedInstance].previousExceptionHandler) {
        [CrashReporter sharedInstance].previousExceptionHandler(exception);
    }
}

#pragma mark - 信号处理

- (void)installSignalHandler {
    signal(SIGSEGV, handleSignal);
    signal(SIGBUS, handleSignal);
    signal(SIGABRT, handleSignal);
    signal(SIGFPE, handleSignal);
    signal(SIGILL, handleSignal);
    signal(SIGPIPE, handleSignal);
}

static void handleSignal(int signal) {
    // 获取堆栈
    void *callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);

    // 转换堆栈为数组
    NSMutableArray *stackTrace = [NSMutableArray arrayWithCapacity:frames];
    for (int i = 0; i < frames; i++) {
        [stackTrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);

    // 获取信号名称
    NSString *signalName = [CrashReporter getSignalName:signal];

    // 构建Crash信息
    NSDictionary *crashInfo = @{
        @"type": @"Signal",
        @"signal": signalName,
        @"signalCode": @(signal),
        @"stackTrace": stackTrace,
        @"timestamp": [NSDate date],
        @"appVersion": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
        @"deviceModel": [self getDeviceModel],
        @"systemVersion": [[UIDevice currentDevice] systemVersion]
    };

    // 保存Crash信息
    [[CrashReporter sharedInstance] saveCrashReport:crashInfo];

    // 调用默认处理
    signal(signal, SIG_DFL);
    raise(signal);
}

#pragma mark - 辅助方法

+ (NSString *)getSignalName:(int)signal {
    switch (signal) {
        case SIGSEGV: return @"SIGSEGV (Segmentation Fault)";
        case SIGBUS: return @"SIGBUS (Bus Error)";
        case SIGABRT: return @"SIGABRT (Abort)";
        case SIGFPE: return @"SIGFPE (Floating Point Exception)";
        case SIGILL: return @"SIGILL (Illegal Instruction)";
        case SIGPIPE: return @"SIGPIPE (Broken Pipe)";
        default: return [NSString stringWithFormat:@"Signal %d", signal];
    }
}

+ (NSString *)getDeviceModel {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

#pragma mark - 报告管理

- (void)saveCrashReport:(NSDictionary *)crashInfo {
    NSString *fileName = [NSString stringWithFormat:@"crash_%@.plist", [[NSDate date] description]];
    NSString *path = [self crashReportsPath];
    NSString *filePath = [path stringByAppendingPathComponent:fileName];

    [crashInfo writeToFile:filePath atomically:YES];
    [self.pendingCrashReports addObject:filePath];

    NSLog(@"Crash report saved: %@", filePath);
}

- (NSString *)crashReportsPath {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
                     stringByAppendingPathComponent:@"CrashReports"];

    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    }

    return path;
}

- (void)loadPendingCrashReports {
    NSString *path = [self crashReportsPath];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];

    for (NSString *file in files) {
        if ([file hasPrefix:@"crash_"]) {
            NSString *filePath = [path stringByAppendingPathComponent:file];
            [self.pendingCrashReports addObject:filePath];
        }
    }

    NSLog(@"Loaded %ld pending crash reports", (long)self.pendingCrashReports.count);
}

- (void)uploadCrashReports {
    if (self.pendingCrashReports.count == 0) {
        return;
    }

    for (NSString *filePath in self.pendingCrashReports) {
        NSDictionary *crashInfo = [NSDictionary dictionaryWithContentsOfFile:filePath];

        if (crashInfo) {
            // 上传到服务器
            [self uploadSingleCrashReport:crashInfo completion:^{
                // 上传成功后删除本地文件
                [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
            }];
        }
    }

    [self.pendingCrashReports removeAllObjects];
}

- (void)uploadSingleCrashReport:(NSDictionary *)crashInfo
                     completion:(void(^)(void))completion {
    // 实现具体的上传逻辑
    // 使用NSURLSession或你的网络框架

    NSLog(@"Uploading crash report: %@", crashInfo);

    // 模拟上传
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"Crash report uploaded successfully");
        if (completion) {
            completion();
        }
    });
}

@end
```

---

## 3. Crash防护策略

### 3.1 常见Crash防护

#### 3.1.1 野指针防护

```objective-c
// 使用Zombie Objects检测（仅开发环境）
#ifdef DEBUG
    [NSSet set setValue:@YES forKey:@"NSZombieEnabled"];
#endif

// 安全的封装方法
@interface NSArray (SafeExtension)

+ (instancetype)safeArrayWithObject:(id)object {
    if (object == nil) {
        return [self array]; // 返回空数组而不是崩溃
    }
    return [self arrayWithObject:object];
}

- (id)safeObjectAtIndex:(NSUInteger)index {
    if (index >= self.count) {
        NSLog(@"Array index out of bounds: %lu >= %lu", (unsigned long)index, (unsigned long)self.count);
        return nil;
    }
    return [self objectAtIndex:index];
}

@end

@implementation NSMutableArray (SafeExtension)

- (void)safeAddObject:(id)object {
    if (object == nil) {
        NSLog(@"Attempt to add nil object to array");
        return;
    }
    [self addObject:object];
}

@end
```

#### 3.1.2 字典防护

```objective-c
@implementation NSMutableDictionary (SafeExtension)

- (void)safeSetObject:(id)object forKey:(id<NSCopying>)key {
    if (object == nil) {
        NSLog(@"Attempt to set nil object for key: %@", key);
        return;
    }

    if (key == nil) {
        NSLog(@"Attempt to use nil key");
        return;
    }

    [self setObject:object forKey:key];
}

- (void)safeSetValue:(id)value forKey:(NSString *)key {
    if (key == nil) {
        NSLog(@"Attempt to set value for nil key");
        return;
    }

    // setValue:forKey: 允许value为nil，会调用removeObjectForKey:
    [self setValue:value forKey:key];
}

@end
```

#### 3.1.3 KVO防护

```objective-c
@interface SafeKVOObserver : NSObject

@property (nonatomic, weak) NSObject *observedObject;
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, copy) void (^observationBlock)(id changes);

- (instancetype)initWithObservedObject:(NSObject *)object
                               keyPath:(NSString *)keyPath
                       observationBlock:(void (^)(id changes))block;

@end

@implementation SafeKVOObserver

- (instancetype)initWithObservedObject:(NSObject *)object
                               keyPath:(NSString *)keyPath
                       observationBlock:(void (^)(id))block {
    if (self = [super init]) {
        _observedObject = object;
        _keyPath = [keyPath copy];
        _observationBlock = [block copy];

        // 添加观察
        [object addObserver:self
                forKeyPath:keyPath
                   options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                   context:nil];
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if (self.observationBlock) {
        self.observationBlock(change);
    }
}

- (void)dealloc {
    // 自动移除观察
    @try {
        [_observedObject removeObserver:self forKeyPath:_keyPath];
    } @catch (NSException *exception) {
        NSLog(@"Failed to remove observer: %@", exception);
    }
}

@end
```

### 3.2 方法不存在防护

```objective-c
// 使用消息转发机制
@interface NSObject (SafeMethodInvocation)

@end

@implementation NSObject (SafeMethodInvocation)

+ (void)load {
    // 交换方法实现
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];

        SEL originalSelector = @selector(methodSignatureForSelector:);
        SEL swizzledSelector = @selector(safe_methodSignatureForSelector:);

        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

        BOOL didAddMethod = class_addMethod(class,
                                            originalSelector,
                                            method_getImplementation(swizzledMethod),
                                            method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            class_replaceMethod(class,
                              swizzledSelector,
                              method_getImplementation(originalMethod),
                              method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

#pragma mark - Method Implementation

- (NSMethodSignature *)safe_methodSignatureForSelector:(SEL)selector {
    // 先调用原始方法
    NSMethodSignature *signature = [self safe_methodSignatureForSelector:selector];

    if (signature != nil) {
        return signature;
    }

    // 方法不存在时，返回一个默认签名
    NSLog(@"Method not found: %@ in class %@", NSStringFromSelector(selector), [self class]);

    // 返回一个void类型的签名，避免崩溃
    return [NSMethodSignature signatureWithObjCTypes:"v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Invoking unimplemented method: %@ on %@", NSStringFromSelector(anInvocation.selector), [self class]);

    // 不调用原有实现，避免崩溃
    // 可以在这里添加降级逻辑或上报
}

@end
```

---

## 4. 系统级Crash监控

### 4.1 主线程卡顿监控

```objective-c
@interface MainThreadWatchDog : NSObject

@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, assign) NSTimeInterval timeout;
@property (nonatomic, strong) NSThread *watchThread;

- (void)startWatching;
- (void)stopWatching;

@end

@implementation MainThreadWatchDog

- (instancetype)initWithTimeout:(NSTimeInterval)timeout {
    if (self = [super init]) {
        _timeout = timeout;
        _semaphore = dispatch_semaphore_create(0);
    }
    return self;
}

- (void)startWatching {
    self.watchThread = [[NSThread alloc] initWithTarget:self
                                             selector:@selector(watchDogThread)
                                               object:nil];
    [self.watchThread start];
}

- (void)watchDogThread {
    @autoreleasepool {
        while (!self.watchThread.isCancelled) {
            // 在主线程发送信号
            dispatch_async(dispatch_get_main_queue(), ^{
                dispatch_semaphore_signal(self.semaphore);
            });

            // 等待信号
            dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeout * NSEC_PER_SEC));
            intptr_t result = dispatch_semaphore_wait(self.semaphore, timeout);

            if (result != 0) {
                // 超时，主线程被阻塞
                [self handleMainThreadBlock];
            }

            // 睡眠一段时间再检测
            [NSThread sleepForTimeInterval:self.timeout / 2];
        }
    }
}

- (void)handleMainThreadBlock {
    NSLog(@"⚠️ Main thread blocked for %.2f seconds", self.timeout);

    // 获取主线程堆栈
    NSArray *stackTrace = [self getMainThreadStackTrace];

    // 上报卡顿信息
    NSDictionary *lagInfo = @{
        @"type": @"MainThreadBlock",
        @"duration": @(self.timeout),
        @"stackTrace": stackTrace,
        @"timestamp": [NSDate date]
    };

    // [CrashReporter uploadLagReport:lagInfo];
}

- (NSArray *)getMainThreadStackTrace {
    pthread_t mainThread = pthread_main_thread_np();
    char buffer[256];
    NSArray *stackTrace = @[];

    // 这里应该使用更复杂的堆栈获取方法
    // 简化示例
    return stackTrace;
}

- (void)stopWatching {
    [self.watchThread cancel];
}

@end
```

### 4.2 内存压力监控

```objective-c
@interface MemoryPressureMonitor : NSObject

- (void)startMonitoring;
- (void)stopMonitoring;

@end

@implementation MemoryPressureMonitor

- (void)startMonitoring {
    // 监听内存警告通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMemoryWarning)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
}

- (void)handleMemoryWarning {
    NSLog(@"⚠️ Memory warning received");

    // 获取当前内存使用情况
    NSDictionary *memoryInfo = [self getCurrentMemoryUsage];

    // 上报内存压力
    NSDictionary *pressureInfo = @{
        @"type": @"MemoryWarning",
        @"memoryUsage": memoryInfo,
        @"timestamp": [NSDate date]
    };

    // [CrashReporter uploadMemoryPressure:pressureInfo];

    // 清理缓存
    [self clearMemoryCache];
}

- (NSDictionary *)getCurrentMemoryUsage {
    // 获取内存使用情况
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(),
                                   MACH_TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);

    if (kerr == KERN_SUCCESS) {
        return @{
            @"residentSize": @(info.resident_size),
            @"virtualSize": @(info.virtual_size),
            @"maxMemory": @([self getDeviceMemory])
        };
    }

    return @{};
}

- (NSUInteger)getDeviceMemory {
    return [NSProcessInfo processInfo].physicalMemory;
}

- (void)clearMemoryCache {
    // 清理图片缓存
    // [[SDImageCache sharedImageCache] clearMemory];

    // 清理其他缓存
    // ...
}

- (void)stopMonitoring {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
}

@end
```

---

## 5. Crash分析与符号化

### 5.1 崩溃日志分析

```bash
# 典型的崩溃日志格式
Incident Identifier: [唯一标识]
CrashReporter Key:   [设备标识]
Hardware Model:      iPhone12,1
Process:             MyApp [123]
Path:                /var/containers/Bundle/Application/XXX/MyApp.app
Identifier:          com.example.myapp
Version:             1.0.0 (123)
Code Type:           ARM-64
Parent Process:      launchd [1]

Date/Time:           2026-06-03 10:30:45.000 +0800
Launch Time:         2026-06-03 10:25:00.000 +0800
OS Version:          iPhone OS 15.0 (19A346)
Report Type:         [崩溃类型]

Exception Type:  EXC_BAD_ACCESS (SIGSEGV)
Exception Codes: 0x0000000000000000 at 0x0000000123456789
Crashed Thread:  0

Thread 0 name:  Dispatch queue: com.apple.main-thread
Thread 0 Crashed:
0   MyApp                         0x0000000100041234 main + 100
1   libdispatch.dylib            0x0000000184567890 _dispatch_call_block_and_release + 24
2   libdispatch.dylib            0x0000000184567891 _dispatch_client_callout + 16
```

### 5.2 符号化工具使用

```bash
# 使用Xcode的symbolicatecrash工具

# 1. 找到symbolicatecrash工具
find /Applications/Xcode.app -name symbolicatecrash -type f

# 2. 设置环境变量
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# 3. 准备文件
# 将.crash文件、.dSYM文件、.app文件放在同一目录下

# 4. 执行符号化
./symbolicatecrash MyApp.crash MyApp.dSYM > MyApp_symbolicated.crash

# 使用atos工具符号化单个地址
atos -o MyApp.app/MyApp -arch arm64 -l 0x100000000 0x0000000100041234
```

### 5.3 符号化脚本

```bash
#!/bin/bash
# automate_symbolicate.sh

# 设置变量
CRASH_FILE=$1
DSYM_FILE=$2
APP_FILE=$3

# 检查参数
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <crash_file> <dsym_file> <app_file>"
    exit 1
fi

# 设置环境变量
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# 查找symbolicatecrash工具
SYMBOLICATE_PATH=$(find /Applications/Xcode.app -name symbolicatecrash -type f | head -n 1)

if [ -z "$SYMBOLICATE_PATH" ]; then
    echo "Error: symbolicatecrash not found!"
    exit 1
fi

echo "Using symbolicatecrash: $SYMBOLICATE_PATH"

# 执行符号化
"$SYMBOLICATE_PATH" "$CRASH_FILE" "$DSYM_FILE" > "${CRASH_FILE}_symbolicated.txt"

echo "Symbolication complete: ${CRASH_FILE}_symbolicated.txt"
```

---

## 6. 最佳实践总结

### 6.1 Crash防护体系架构

```
┌─────────────────────────────────────┐
│      Crash防护体系架构              │
├─────────────────────────────────────┤
│  监控层：                            │
│  - FPS监控                           │
│  - 主线程卡顿监控                    │
│  - 内存压力监控                      │
├─────────────────────────────────────┤
│  捕获层：                            │
│  - OC异常捕获                        │
│  - 信号处理                         │
│  - Mach异常处理                     │
├─────────────────────────────────────┤
│  分析层：                            │
│  - 堆栈收集                         │
│  - 符号化处理                       │
│  - 统计分析                         │
├─────────────────────────────────────┤
│  防护层：                            │
│  - 代码防护                         │
│  - 运行时检查                       │
│  - 降级策略                         │
└─────────────────────────────────────┘
```

### 6.2 建立完整的Crash处理流程

```
1. 开发阶段
   - 启用 Zombie Objects
   - 使用 Address Sanitizer
   - 开启 Thread Sanitizer
   - 使用静态分析工具

2. 测试阶段
   - 内测用户安装Crash监控SDK
   - 收集真实场景的Crash
   - 建立Crash优先级分类

3. 生产环境
   - 实时监控Crash率
   - 及时处理高优先级Crash
   - 定期分析Crash趋势

4. 持续改进
   - 建立Crash知识库
   - 总结常见问题模式
   - 改进代码质量
```

---

## 7. 参考资料

### 优质文章
- [iOS Crash捕获与防护](https://juejin.cn/post/6844903900728610829)
- [PLCrashReporter使用指南](https://github.com/microsoft/plcrashreporter)
- [KSCrash框架解析](https://github.com/kstenerud/KSCrash)
- [Bugly iOS接入指南](https://bugly.qq.com/docs/)

### 开源项目
- [PLCrashReporter](https://github.com/microsoft/plcrashreporter) - 微软崩溃报告框架
- [KSCrash](https://github.com/kstenerud/KSCrash) - 强大的崩溃处理库
- [Bugly](https://bugly.qq.com/) - 腾讯崩溃监控服务
- [Firebase Crashlytics](https://firebase.google.com/docs/crashlytics) - Google崩溃分析

### Apple官方文档
- [Technical Note TN2123 - Exception Handling in Cocoa](https://developer.apple.com/library/archive/technotes/tn/tn2123/_index.html)
- [Debugging in macOS](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/debugging_with_gdb/)