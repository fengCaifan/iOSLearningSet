# Swift 内存管理与 ARC

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - ARC 在 Swift 中的工作方式（编译器插入 retain/release）
  - strong / weak / unowned 三种引用
  - 闭包中的捕获列表 [weak self]
-->



## 2. 底层原理

<!-- 建议涵盖：
  - Swift 对象的引用计数存储：InlineRefCounts（强引用 + unowned 引用 + 标志位）
  - Side Table：weak 引用的间接表
  - Swift 对象销毁流程：deinit → release strong → release unowned → release weak
  - unowned 与 weak 的底层区别（无 Side Table vs 有 Side Table）
  - 闭包的捕获语义：值捕获 vs 引用捕获
  - autoreleasepool 在 Swift 中的使用场景
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: weak 和 unowned 的区别？什么时候用 unowned？
  A: 

- Q: Swift 的 ARC 和 OC 的 ARC 有什么区别？
  A: 

- Q: 闭包中 [weak self] 和 [unowned self] 如何选择？
  A: 

- Q: Swift 中还需要使用 autoreleasepool 吗？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 常见的循环引用场景与排查
  - Instruments Leaks 工具的使用
  - 大规模对象创建时 autoreleasepool 的性能优化
-->



## 5. 参考资料

