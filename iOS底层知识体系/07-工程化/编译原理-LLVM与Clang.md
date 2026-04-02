# 编译原理 — LLVM 与 Clang

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - LLVM 架构：Frontend（Clang/Swift Frontend）→ Optimizer → Backend
  - 编译流程：预处理 → 词法分析 → 语法分析 → 语义分析 → IR 生成 → 优化 → 目标代码
  - Clang 与 swiftc 的关系
-->



## 2. 底层原理

<!-- 建议涵盖：
  - OC 编译流程：.m → 预处理 → AST → LLVM IR → 优化 → 汇编 → Mach-O
  - Swift 编译流程：.swift → AST → SIL（Swift Intermediate Language）→ LLVM IR → 汇编
  - SIL 的作用：Swift 特有的中间表示，用于 Swift 级别的优化
  - Clang Plugin / LibTooling：自定义编译检查
  - 编译优化级别：-O0 / -Os / -Osize / -O（WMO）
  - 增量编译 vs 全量编译
  - 编译时间优化：模块化、预编译头（PCH → Module）、并行编译
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: OC 和 Swift 的编译流程有什么区别？
  A: 

- Q: 什么是 LLVM IR？有什么作用？
  A: 

- Q: 如何优化项目的编译速度？
  A: 

- Q: Clang 静态分析器的原理？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - Clang Plugin 实现自定义代码规范检查
  - 编译时间的分析与优化实践
-->



## 5. 参考资料

