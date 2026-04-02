# 包体积优化 — LinkMap 与资源瘦身

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - IPA 包组成：可执行文件（Mach-O）+ 资源文件（Assets/Storyboard/配置文件）+ Frameworks
  - App Thinning：App Slicing / Bitcode / On-Demand Resources
-->



## 2. 底层原理

<!-- 建议涵盖：
  - LinkMap 文件分析：各段（__TEXT / __DATA / __LINKEDIT）大小、各库/文件的贡献
  - 代码瘦身：
    - 无用代码检测（基于 LinkMap / otool / objc-class-ref 对比）
    - 无用方法检测（基于 __objc_selrefs vs __objc_methnames）
    - Swift 符号裁剪（-Osize、whole-module-optimization）
    - 段迁移：__TEXT → __RODATA
  - 资源瘦身：
    - 无用资源检测工具（LSUnusedResources）
    - 图片压缩（tinypng / WebP / HEIF）
    - Asset Catalog 优化
    - 重复资源检测
  - 动态库 vs 静态库对包体积的影响
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: 如何分析和减小 iOS App 的包体积？
  A: 

- Q: 如何检测项目中的无用代码？
  A: 

- Q: 动态库和静态库哪个对包体积更友好？
  A: 

- Q: App Thinning 的几种方式分别是什么？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 包体积优化的完整实践流程
  - CI 集成包体积监控
-->



## 5. 参考资料

