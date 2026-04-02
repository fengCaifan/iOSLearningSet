# APM — 崩溃收集与符号化

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - 崩溃的三种来源：Mach 异常、Unix Signal、OC/Swift 异常（NSException / Swift Error）
  - 崩溃收集框架：KSCrash、PLCrashReporter、Firebase Crashlytics、Bugly
  - 符号化：将内存地址还原为源码中的函数名和行号
-->



## 2. 底层原理

<!-- 建议涵盖：
  - 三层异常捕获机制：
    - Mach 异常：mach_msg → exc_handler（最底层）
    - Signal：sigaction 注册信号处理器（SIGSEGV、SIGABRT、SIGBUS 等）
    - NSException：NSSetUncaughtExceptionHandler
  - 崩溃信息收集：线程堆栈、寄存器状态、设备信息、App 状态
  - 符号化流程：
    - dSYM 文件生成（DWARF 调试信息）
    - atos / symbolicatecrash 工具
    - 地址计算：stack_address - load_address + slide = symbol_offset
  - Crash 日志格式解读
  - 常见崩溃类型：Unrecognized Selector、EXC_BAD_ACCESS、野指针、数组越界、多线程崩溃
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: iOS 崩溃收集的原理？
  A: 

- Q: Mach 异常和 Signal 是什么关系？
  A: 

- Q: 如何进行崩溃日志的符号化？
  A: 

- Q: 如何捕获和处理 OOM 崩溃？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 自建崩溃收集 SDK 的设计
  - 崩溃率治理的完整流程
-->



## 5. 参考资料

