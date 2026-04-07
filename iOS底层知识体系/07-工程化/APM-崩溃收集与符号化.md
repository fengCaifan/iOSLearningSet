# APM-崩溃收集与符号化

> 一句话总结：**崩溃采集要讲清信号/异常类型、线程快照与 dSYM 符号化；上报需聚合与版本关联。**

---

## 📚 学习地图

- **预计学习时间**：45 分钟
- **前置知识**：Mach 异常、编译产物
- **学习目标**：NSSetUncaughtExceptionHandler / Signal → 符号化 → 上报要点

---

## 5. 崩溃治理与堆栈捕获

### 5.1 崩溃类型

| 崩溃类型 | 说明 | 示例 |
|---------|------|------|
| **Mach 异常** | 底层内核异常 | EXC_BAD_ACCESS（访问非法内存） |
| **Unix Signal** | POSIX 信号 | SIGKILL（系统杀进程）、SIGABRT（调用 abort()） |
| **C++ Exception** | C++ 异常 | std::out_of_range |
| **Objective-C Exception** | OC 异常 | NSArray 越界 |
| **Swift Error** | Swift 错误 | 强制解包 nil |

### 5.2 崩溃捕获

**Mach 异常捕获**：

```objective-c
#include <mach/exc.h>

// 创建异常端口
mach_port_t exceptionPort = MACH_PORT_NULL;

// 创建异常端口
mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &exceptionPort);
mach_port_insert_right(mach_task_self(), exceptionPort, exceptionPort, MACH_MSG_TYPE_MAKE_SEND);

// 设置异常端口
thread_set_exception_ports(mach_thread_self(), EXC_MASK_BAD_ACCESS, exceptionPort,
                          EXCEPTION_DEFAULT, THREAD_STATE_NONE);

// 监听异常端口
mach_msg_server_once(exceptionPort, 0, exceptionPort);
```

**Signal 捕获**：

```objective-c
#include <signal.h>

void signalHandler(int signal) {
    // 记录堆栈
    void *callStack[128];
    int frames = backtrace(callStack, 128);
    char **symbols = backtrace_symbols(callStack, frames);

    // 写入日志或上报
    for (int i = 0; i < frames; i++) {
        printf("%s\n", symbols[i]);
    }

    // 恢复默认处理并重新触发
    signal(SIGABRT, SIG_DFL);
    raise(SIGABRT);
}

// 注册信号处理
signal(SIGABRT, signalHandler);
signal(SIGTERM, signalHandler);
signal(SIGSEGV, signalHandler);
```

### 5.3 堆栈符号化

**什么是符号化**：

```
原始崩溃日志：
0 MyApp  0x0000000101234567 0x123000 + 12345

符号化后：
0 MyApp  0x0000000101234567 -[ViewController viewDidLoad] (ViewController.m:45)
```

**dSYM 文件**：

```
dSYM 包含：
- 符号表（函数名、类名）
- 源代码行号信息
- 地址映射

Xcode 自动生成：
- Debug 构建默认不生成
- Release 构建自动生成（Build Settings → Debug Information Format: DWARF with dSYM）
```

**atos 符号化命令**：

```bash
# 符号化单个地址
atos -o MyApp.app.dSYM/Contents/Resources/DWARF/MyApp -arch arm64 -l 0x100000000 0x1234567

# 批量符号化崩溃日志
symbolicatecrash -o MyApp.app.dSYM/Contents/Resources/DWARF/MyApp crash.log.crash
```

### 5.4 Crash 上报系统设计

**架构**：

```
┌─────────────────┐
│   Crash Monitor  │
│  (Mach + Signal) │
└────────┬─────────┘
         │
         ↓
┌─────────────────┐
│  Stack Capture  │
│  (backtrace)     │
└────────┬─────────┘
         │
         ↓
┌─────────────────┐
│ Symbolication   │
│  (本地或服务器)  │
└────────┬─────────┘
         │
         ↓
┌─────────────────┐
│  Crash Report   │
│  (JSON/CSV)      │
└────────┬─────────┘
         │
         ↓
┌─────────────────┐
│   Upload Server │
└─────────────────┘
```

**实现示例**：

```swift
class CrashReporter {
    static let shared = CrashReporter()

    func setup() {
        // 注册异常处理
        NSSetUncaughtExceptionHandler { exception in
            self.handleException(exception)
        }

        // 注册信号处理
        registerSignalHandler()
    }

    private func handleException(_ exception: NSException) {
        let stackTrace = exception.callStackSymbols.joined(separator: "\n")
        let crashInfo = [
            "name": exception.name.rawValue,
            "reason": exception.reason ?? "",
            "stackTrace": stackTrace,
            "device": UIDevice.current.model,
            "os": UIDevice.current.systemVersion
        ]

        // 写入本地文件
        saveCrashReport(crashInfo)

        // 延迟上报（下次启动）
        scheduleUpload()
    }

    private func saveCrashReport(_ info: [String: Any]) {
        let path = crashReportPath()
        let data = try? JSONSerialization.data(withJSONObject: info)
        try? data?.write(to: path)
    }

    private func crashReportPath() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("crash_reports/\(UUID().uuidString).json")
    }
}
```

---

### 7.3 内存优化

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **Dirty Memory vs Clean Memory？** | Dirty：无法回收（堆、图片），Clean：可回收（代码段） | ⭐⭐⭐⭐ |
| **什么是 Jetsam？** | iOS 内存管理机制，内存压力时按优先级杀进程 | ⭐⭐⭐⭐ |
| **如何降低内存占用？** | 降采样、对象池、及时释放、避免缓存 | ⭐⭐⭐⭐ |
| **如何检测内存泄漏？** | Instruments Leaks、Memory Graph、MLeaksFinder | ⭐⭐⭐ |

### 7.4 崩溃处理

---

## 8. 参考资料

### 优质文章
- [iOS App启动优化与二进制重排](https://juejin.cn/post/6844904165773328392)
- [美团App冷启动治理](https://www.jianshu.com/p/8e0b38719278)
- [iOS Memory Deep Dive](https://developer.apple.com/videos/play/wwdc2018/416/)
- [Xcode Instruments: Find Memory Leaks in 5 Minutes](https://medium.com/@chandra.welim/xcode-instruments-find-memory-leaks-in-5-minutes-not-hours-4f80982e3682)
- [Mastering iOS Profiler Instruments](https://medium.com/@asherazeem25/mastering-ios-profiler-instruments-a-complete-guide-to-performance-optimization-9a4813a059a1)
- [Crash Analytics in iOS (2026): A Complete Practical Guide](https://medium.com/@garejakirit/crash-analytics-in-ios-2026-a-complete-practical-guide-d2c0b9c0cec5)
- [The ultimate guide to symbolica ting iOS crash reports](https://www.zoho.com/apptics/digest/ios-crash-debugging-guide.html)

### 开源项目
- [MLeaksFinder](https://github.com/Tencent/MLeaksFinder) - 腾讯内存泄漏检测工具
- [OOMDetector](https://github.com/Tencent/OOMDetector) - 腾讯 OOM 监控工具
- [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) - 日志框架
- [PLCrashReporter](https://github.com/microsoft/plcrashreporter) - 崩溃报告框架

### Apple 官方文档

---

## 附录：dSYM 与 atos（整合）

## 6. dSYM 与符号化

### 6.1 dSYM 文件

**什么是 dSYM？**

```
dSYM 文件包含：
1. 符号表（函数名、类名、行号）
2. 地址映射（地址 → 符号）
3. DWARF 调试信息
```

**生成 dSYM**：

```
Build Settings:
- Debug Information Format: DWARF with dSYM
- Deployment Postprocessing: Yes
- Strip Debug Symbols (Copy): Yes
```

### 6.2 符号化过程

**崩溃日志**：

```
Thread 0 Crashed:
0   MyApp                         0x0000000101234567 0x12345 + 12345
1   MyApp                         0x0000000101234890 0x23456 + 23456
```

**符号化后**：

```
Thread 0 Crashed:
0   MyApp                         0x0000000101234567 main (main.m:45) + 12345
1   MyApp                         0x0000000101234890 viewDidLoad (ViewController.m:67) + 23456
```

### 6.3 atos 工具

**符号化命令**：

```bash
atos -o MyApp.app.dSYM/Contents/Resources/DWARF/MyApp \
      -arch arm64 \
      -l 0x100000000 \
      0x1234567

# 输出：
main (in main.m:45)
```

**批量符号化**：

```bash
symbolicatecrash MyApp.crash.ips MyApp.app.dSYM/Contents/Resources/DWARF/MyApp
```

---


