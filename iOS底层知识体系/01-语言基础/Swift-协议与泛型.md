# Swift 协议与泛型

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - Protocol 作为类型约束 vs 作为存在类型（Existential Type）
  - 泛型（Generics）：类型参数化
  - 关联类型（Associated Type）
  - some (Opaque Type) vs any (Existential Type) — Swift 5.7+
-->



## 2. 底层原理

<!-- 建议涵盖：
  - Protocol Witness Table (PWT)：协议方法的分派机制
  - Value Witness Table (VWT)：值类型的内存操作
  - 泛型特化（Generic Specialization）：编译器优化，为具体类型生成专用代码
  - 类型擦除（Type Erasure）：AnyHashable、AnyPublisher 的实现原理
  - Primary Associated Types（Swift 5.7）
  - some 关键字的编译期行为 vs any 的运行时开销
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: some View 和 any View 有什么区别？
  A: 

- Q: 为什么不能直接用 Protocol 作为集合的元素类型（如果 Protocol 有 Associated Type）？
  A: 

- Q: 什么是类型擦除？为什么需要它？请举例实现一个。
  A: 

- Q: 泛型和协议的方法分派方式有什么不同？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 面向协议编程（POP）在项目中的实践
  - 泛型网络层 / 泛型数据源的设计
  - some 与 any 在 SwiftUI 中的实际应用
-->



## 5. 参考资料

