# Swift 并发模型（async/await & Actor）

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - async/await：协程式异步编程
  - Task：结构化并发的基本单元
  - Actor：数据隔离的并发安全模型
  - Sendable：跨并发域传递的安全协议
  - MainActor：主线程隔离
-->



## 2. 底层原理

<!-- 建议涵盖：
  - Swift 协程实现：Continuation、挂起点（suspension point）
  - 协作式线程池（Cooperative Thread Pool）vs GCD 线程爆炸
  - Actor 的信箱模型（Mailbox）与重入（Reentrancy）问题
  - Sendable checking：编译期并发安全检查
  - Task 的结构化与非结构化（Task {} vs TaskGroup vs detached Task）
  - AsyncSequence / AsyncStream
  - 与 GCD/OperationQueue 的对比与迁移路径
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: async/await 和 GCD 相比有什么优势？
  A: 

- Q: Actor 如何保证数据安全？和加锁有什么区别？
  A: 

- Q: 什么是 Sendable？为什么需要它？
  A: 

- Q: Task 和 detached Task 的区别？TaskGroup 的使用场景？
  A: 

- Q: @MainActor 标记的作用是什么？
  A: 

- Q: async/await 的底层是如何实现的？（Continuation）
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 从 GCD 回调迁移到 async/await 的实践
  - Actor 在数据缓存层的应用
  - AsyncStream 封装 delegate 回调
  - 与 Combine 的对比与共存方案
-->



## 5. 参考资料

