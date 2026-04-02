# SwiftUI 状态管理与生命周期

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - 声明式 UI 的核心理念：UI = f(State)
  - 属性包装器家族：@State / @Binding / @ObservedObject / @StateObject / @EnvironmentObject / @Environment
  - View 的生命周期：init → body → onAppear → onDisappear
-->



## 2. 底层原理

<!-- 建议涵盖：
  - @State 的存储位置（Attribute Graph，而非 View struct 本身）
  - @StateObject vs @ObservedObject 的生命周期差异（所有权 vs 借用）
  - View Identity：Structural Identity vs Explicit Identity (id modifier)
  - SwiftUI Diff 算法与视图更新机制
  - @Observable (iOS 17) vs ObservableObject 的区别
  - 与 UIKit 的互操作：UIViewRepresentable / UIViewControllerRepresentable
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: @StateObject 和 @ObservedObject 有什么区别？什么时候用哪个？
  A: 

- Q: SwiftUI 的 View 是 struct，为什么 @State 能做到状态持久化？
  A: 

- Q: SwiftUI 中如何避免不必要的 View 重建？
  A: 

- Q: 如何在 SwiftUI 中使用现有的 UIKit 组件？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - SwiftUI 与 UIKit 混编的最佳实践
  - 大型 SwiftUI 项目的状态管理方案（TCA / 自建）
  - SwiftUI 性能陷阱与优化
-->



## 5. 参考资料

