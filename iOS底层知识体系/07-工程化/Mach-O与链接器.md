# Mach-O 与链接器

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - Mach-O：macOS/iOS 可执行文件格式
  - 静态链接 vs 动态链接
  - dyld（Dynamic Linker）的角色
-->



## 2. 底层原理

<!-- 建议涵盖：
  - Mach-O 文件结构：Header → Load Commands → Data（__TEXT/__DATA/__LINKEDIT）
  - 静态链接：符号解析 + 重定位
  - 动态链接：lazy binding / non-lazy binding
  - dyld 加载流程：load dylibs → rebase → bind → ObjC setup → initializers
  - Universal Binary（Fat Binary）与 Thin Binary
  - ASLR（Address Space Layout Randomization）
  - 符号表与 DWARF 调试信息
  - dSYM 文件与崩溃符号化
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: Mach-O 文件的结构是什么？
  A: 

- Q: 静态库和动态库的区别？
  A: 

- Q: dyld 的加载流程？
  A: 

- Q: 什么是 ASLR？有什么作用？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 使用 MachOView / otool 分析 Mach-O
  - fishhook 的原理（基于 rebinding 动态符号）
-->



## 5. 参考资料

