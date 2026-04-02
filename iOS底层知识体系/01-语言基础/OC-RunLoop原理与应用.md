# OC RunLoop 原理与应用

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：RunLoop 本质（事件循环）、与线程的关系、CFRunLoopRef 结构 -->



## 2. 底层原理

<!-- 建议涵盖：
  - RunLoop 的运行流程（Source0/Source1/Timer/Observer）
  - RunLoop 与 AutoreleasePool 的关系
  - RunLoop 在 UI 刷新中的角色（CATransaction commit 时机）
  - RunLoop 与 GCD 的交互
  - CFRunLoopMode 切换机制（DefaultMode vs TrackingMode vs CommonModes）
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: RunLoop 和线程是什么关系？
  A: 

- Q: NSTimer 在列表滑动时为什么会停？怎么解决？
  A: 

- Q: RunLoop 的几种 Mode 分别是什么？CommonModes 的本质是什么？
  A: 

- Q: 如何利用 RunLoop 实现卡顿监控？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 利用 RunLoop 空闲时机预加载数据
  - RunLoop Observer 实现卡顿检测
  - 常驻线程的实现与注意事项
-->



## 5. 参考资料

