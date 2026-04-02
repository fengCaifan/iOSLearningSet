# Swift 值类型与引用类型

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - Struct vs Class 的本质区别
  - 栈分配 vs 堆分配的性能差异
  - Copy-on-Write (COW) 机制
-->



## 2. 底层原理

<!-- 建议涵盖：
  - Swift 对象的内存布局（HeapObject: metadata + refCounts + ivars）
  - 值类型在栈上的内存布局
  - COW 实现原理：isKnownUniquelyReferenced
  - Existential Container：协议类型的内存布局（Inline Value Buffer + VWT + PWT）
  - 值类型中包含引用类型时的 copy 行为
  - 编译器优化：栈提升（Stack Promotion）
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: Struct 和 Class 该如何选择？
  A: 

- Q: 什么是 Copy-on-Write？哪些类型默认支持？如何为自定义 Struct 实现？
  A: 

- Q: 一个 Struct 里包含一个 Array 属性，copy 时 Array 会被深拷贝吗？
  A: 

- Q: 为什么 Swift 推荐使用值类型？性能一定更好吗？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 大型 Model 使用 Struct 还是 Class 的决策过程
  - 性能敏感场景下值类型 vs 引用类型的 benchmark
-->



## 5. 参考资料

