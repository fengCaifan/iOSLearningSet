# Core Text 文字排版与 YYLabel

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - Core Text 的角色：底层文字排版引擎
  - 排版层级：CTFramesetter → CTFrame → CTLine → CTRun
  - YYText / YYLabel 的核心价值：异步排版 + 异步渲染
-->



## 2. 底层原理

<!-- 建议涵盖：
  - NSAttributedString 与 Core Text 的关系
  - CTFramesetter 的排版流程
  - 图文混排的实现（CTRunDelegate）
  - YYLabel 的异步绘制原理（后台线程 Core Graphics 绘制 → 主线程设置 layer.contents）
  - YYTextLayout 的缓存与预排版
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: UILabel 和 YYLabel 的核心区别？
  A: 

- Q: 如何实现图文混排？
  A: 

- Q: 大量富文本列表的性能优化思路？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 聊天气泡中富文本的高性能实现
  - 社交 Feed 流中 @/话题/链接 的识别与点击
-->



## 5. 参考资料

