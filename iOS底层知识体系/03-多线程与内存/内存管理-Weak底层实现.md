# 内存管理 — Weak 底层实现

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - weak 引用：不增加引用计数，对象释放后自动置 nil
  - weak 的使用场景：打破循环引用（delegate、block 中的 self）
-->



## 2. 底层原理

<!-- 建议涵盖：
  - weak 变量的注册：objc_initWeak → storeWeak → weak_register_no_lock
  - weak_table_t 结构：全局哈希表，key = 对象地址，value = weak 指针数组（weak_entry_t）
  - 对象释放时清理 weak 指针：dealloc → clearDeallocating → weak_clear_no_lock → 遍历置 nil
  - SideTable 中 weak_table 的哈希冲突解决（开放寻址法）
  - weak 与 assign/unsafe_unretained 的区别
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: weak 的实现原理？对象释放时 weak 指针怎么被自动置 nil 的？
  A: 

- Q: weak 和 assign 有什么区别？
  A: 

- Q: weak 属性能不能指向一个值类型？
  A: 

- Q: 大量使用 weak 会有性能问题吗？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - delegate 为什么用 weak？用 assign 会怎样？
  - NSHashTable / NSMapTable 的 weak 容器
-->



## 5. 参考资料

