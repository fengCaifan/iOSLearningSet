# 设计一个 APM SDK

> 一句话总结：

## 1. 需求分析

<!-- 建议涵盖：
  - 四大核心模块：崩溃监控、卡顿监控、网络监控、内存监控
  - 扩展模块：启动耗时、页面加载耗时、电量、磁盘、CPU
  - 非功能需求：低侵入、低性能开销、数据准确、可灰度
-->



## 2. 架构设计

<!-- 建议涵盖：
  - 整体架构：
    - SDK Core：初始化、配置管理、开关控制、采样率
    - Monitor 模块：各监控能力独立模块化
      - CrashMonitor：Mach 异常 + Signal + NSException
      - LagMonitor：RunLoop Observer + 堆栈采集
      - MemoryMonitor：定时采样 + OOM 检测
      - NetworkMonitor：URLProtocol 拦截 / NSURLSessionTaskMetrics
    - Reporter 模块：数据聚合 + 压缩 + 上报
    - Storage 模块：本地持久化（SQLite / mmap）
  - 数据流：Monitor 采集 → 本地 Storage → 聚合 → 上报 → 后端分析
-->



## 3. 关键设计决策

<!-- 
  - 采样率控制：全量 vs 采样，平衡数据量与性能开销
  - 上报策略：实时上报 vs 批量上报 vs Wi-Fi 上报
  - 符号化时机：客户端 vs 服务端（通常服务端）
  - 堆栈聚合算法：相同堆栈归类，生成 Issue
  - SDK 自身的稳定性保障：避免 SDK 自身导致崩溃
  - 隐私合规：用户授权、数据脱敏
-->



## 4. 参考框架

<!-- 
  - 微信 Matrix
  - 字节 Slardar
  - Firebase Performance
  - 开源：KSCrash / PLCrashReporter / GodEye
-->



## 5. 面试回答要点

<!-- 
  - 先画全局架构图
  - 然后深入一个模块的实现细节（推荐崩溃或卡顿）
  - 讨论 SDK 设计的工程考量（性能、稳定性、可扩展性）
-->

