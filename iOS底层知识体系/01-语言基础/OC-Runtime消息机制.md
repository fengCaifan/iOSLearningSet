# OC Runtime 消息机制

> 一句话总结：

## 1. 核心概念

<!-- 用最简洁的语言定义清楚「是什么」 -->
<!-- 建议涵盖：objc_msgSend、消息发送三阶段（快速查找→慢速查找→消息转发）、方法缓存 -->



## 2. 底层原理

<!-- 关键流程图 / 源码级别的「为什么这样设计」 -->
<!-- 建议涵盖：
  - objc_msgSend 汇编入口（arm64）
  - 缓存查找（cache_t 哈希表结构）
  - 方法列表查找（二分查找 vs 线性查找）
  - 消息转发三步：resolveInstanceMethod → forwardingTargetForSelector → methodSignatureForSelector + forwardInvocation
  - isa 指针与元类链
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: [objc_msgSend] 为什么用汇编实现而不是 C？
  A: 

- Q: 方法缓存的哈希冲突如何解决？缓存扩容策略是什么？
  A: 

- Q: 消息转发的三个阶段分别适合什么场景？
  A: 

- Q: [self class] 和 [super class] 的区别？
  A: 
-->



## 4. 实战应用

<!-- 你在真实项目中如何使用的，例如：
  - Method Swizzling 的应用场景与注意事项
  - 利用消息转发实现 NSProxy 代理
  - Runtime 关联对象在 Category 中的使用
-->



## 5. 参考资料

<!-- 有价值的文章/源码/视频链接 -->

