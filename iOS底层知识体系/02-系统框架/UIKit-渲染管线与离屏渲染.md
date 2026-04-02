# UIKit 渲染管线与离屏渲染

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - iOS 渲染全流程：CPU 布局/绘制 → GPU 渲染 → 帧缓冲区 → 显示
  - CALayer 与 UIView 的关系
  - 离屏渲染（Offscreen Rendering）的定义
-->



## 2. 底层原理

<!-- 建议涵盖：
  - 完整渲染管线：Handle Events → Layout (layoutSubviews) → Display (drawRect) → Prepare → Commit → Render Server → GPU
  - CATransaction 与 RunLoop 的关系（commit 时机）
  - 离屏渲染的本质：GPU 需要额外开辟缓冲区 + 上下文切换
  - 触发离屏渲染的场景：圆角+masksToBounds、shadow、group opacity、mask、shouldRasterize
  - iOS 9+ 圆角优化：UIImageView 不再触发离屏渲染
  - Core Animation 的 hit testing 流程
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: iOS 从点击屏幕到画面显示经历了哪些步骤？
  A: 

- Q: 什么是离屏渲染？为什么会导致性能问题？
  A: 

- Q: 如何避免离屏渲染？
  A: 

- Q: layoutSubviews 和 drawRect 分别在什么时候调用？
  A: 

- Q: setNeedsLayout / layoutIfNeeded / setNeedsDisplay 的区别？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 圆角图片的多种高性能实现方案对比
  - 阴影的性能优化（shadowPath）
  - Instruments Core Animation 调试离屏渲染
-->



## 5. 参考资料

