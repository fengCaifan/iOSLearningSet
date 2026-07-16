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