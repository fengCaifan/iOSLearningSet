# GCD 底层与队列模型

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - GCD 的核心：任务（Block）+ 队列（串行/并发）+ 线程池
  - 同步 vs 异步、串行 vs 并发的组合效果
  - 主队列的特殊性
-->



## 2. 底层原理

<!-- 建议涵盖：
  - libdispatch 源码：dispatch_queue 的数据结构
  - 队列与线程的映射关系（队列不等于线程）
  - dispatch_sync 的实现：直接在当前线程执行 + barrier
  - dispatch_async 的实现：将 block 入队 → 唤醒线程池
  - dispatch_once 的底层实现（原子操作 + 信号量）
  - dispatch_semaphore 的实现原理
  - dispatch_group 的 enter/leave 计数机制
  - 线程池上限（Thread Explosion 问题）
  - dispatch_barrier 的原理与应用（读写锁）
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: dispatch_sync 在主队列调用为什么会死锁？
  A: 

- Q: dispatch_once 是如何保证线程安全和只执行一次的？
  A: 

- Q: dispatch_barrier 的原理？怎么实现读写锁？
  A: 

- Q: 如何控制 GCD 的最大并发数？
  A: 

- Q: GCD 和 NSOperation 有什么区别？各自的优势？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - dispatch_group 实现多接口并发请求
  - dispatch_barrier 实现多读单写
  - DispatchWorkItem 的取消机制
-->



## 5. 参考资料

