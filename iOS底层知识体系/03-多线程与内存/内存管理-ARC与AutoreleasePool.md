# 内存管理 — ARC 与 AutoreleasePool

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - MRC → ARC 的演进
  - ARC 的本质：编译器自动插入 retain/release/autorelease
  - AutoreleasePool 的作用：延迟释放
-->



## 2. 底层原理

<!-- 建议涵盖：
  - 引用计数存储：isa 中的 extra_rc（NONPOINTER_ISA）+ SideTable（溢出时）
  - SideTable 结构：spinlock + RefcountMap + weak_table_t
  - AutoreleasePool 底层：AutoreleasePoolPage 双向链表
  - POOL_BOUNDARY（哨兵对象）标记每次 push 的边界
  - AutoreleasePool 与 RunLoop 的关系：Entry 时 push、BeforeWaiting 时 pop+push、Exit 时 pop
  - Tagged Pointer：小对象优化，无需引用计数管理
  - dealloc 流程：rootDealloc → object_dispose → objc_destructInstance
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: AutoreleasePool 的底层数据结构是什么？
  A: 

- Q: AutoreleasePool 什么时候释放？和 RunLoop 是什么关系？
  A: 

- Q: 子线程需要手动创建 AutoreleasePool 吗？
  A: 

- Q: Tagged Pointer 是什么？有什么优化作用？
  A: 

- Q: 引用计数存储在哪里？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - for 循环中大量创建临时对象时 @autoreleasepool 的使用
  - 引用计数调试：CFGetRetainCount
-->



## 5. 参考资料

