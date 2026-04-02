# APM — 卡顿与内存监控

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - APM（Application Performance Monitoring）：应用性能监控
  - 卡顿监控：检测主线程长时间阻塞
  - 内存监控：检测内存泄漏、大内存分配、OOM 预警
  - MetricKit：Apple 提供的系统级性能数据
-->



## 2. 底层原理

<!-- 建议涵盖：
  - 卡顿监控（详见 04-性能优化，此处侧重 SDK 设计）：
    - 数据采集：RunLoop Observer / ping / CADisplayLink
    - 堆栈采集：mach_thread API
    - 数据聚合：相同堆栈归类、采样率控制
    - 上报策略：批量上报、优先级队列
  - 内存监控：
    - 内存水位监控：定时采样 resident_size / phys_footprint
    - 大内存分配追踪：hook malloc / vm_allocate
    - 内存泄漏检测：MLeaksFinder + FBRetainCycleDetector
    - OOM 预警：接近系统内存限制时主动释放缓存
  - MetricKit 集成：MXDiagnosticPayload、MXMetricPayload
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: 如何设计一个 APM SDK？核心模块有哪些？
  A: 

- Q: 线上卡顿监控的方案和挑战？
  A: 

- Q: 如何监控 App 的内存使用情况？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - APM SDK 的整体架构设计
  - 监控数据的可视化与告警
-->



## 5. 参考资料

