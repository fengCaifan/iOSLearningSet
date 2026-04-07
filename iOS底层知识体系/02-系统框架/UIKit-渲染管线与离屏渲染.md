# UIKit-渲染管线与离屏渲染

> 一句话总结：**Core Animation 提交事务后经渲染 Server 合成；离屏多在遮罩/圆角/阴影等路径触发，需节制。**

---

## 📚 学习地图

- **预计学习时间**：40 分钟
- **前置知识**：CALayer
- **学习目标**：帧管线 → 离屏判定 → 优化思路

---

## 1. 渲染管线与离屏渲染

### 1.1 渲染流程

**Core Animation 渲染流水线**：

```
1. Layout（布局）：计算 View 和 Layer 的布局
2. Display（显示）：绘制内容到位图
3. Prepare（准备）：图片解码等
4. Commit（提交）：将 Layer 打包发送到渲染服务
```

**Run Loop 中的渲染时机**：

```
1. Register：注册 Callback
2. Observer：监听 Run Loop 即将进入休眠
3. Callback：执行 CA::Transaction::commit()
```

### 1.2 离屏渲染（Offscreen Rendering）

**什么是离屏渲染？**

```
在屏幕外的缓冲区进行渲染，完成后再绘制到屏幕
```

**触发场景**：

| 场景 | 优化方案 |
|------|---------|
| **圆角 + masksToBounds** | 使用贝塞尔曲线绘制图片，或 shouldRasterize |
| **阴影（shadowPath 除外）** | 设置 shadowPath |
| **图层混合** | 避免过多半透明图层重叠 |
| **shouldRasterize** | 已是优化手段，缓存渲染结果 |

**检测离屏渲染**：

```swift
// Instruments → Core Animation
// Color Offscreen-Rendered Yellow
// 黄色区域即为离屏渲染
```

**优化圆角**：

```swift
// ❌ 触发离屏渲染
imageView.layer.cornerRadius = 10
imageView.layer.masksToBounds = true

// ✅ 方案 1：使用贝塞尔曲线
extension UIImageView {
    func roundCorners(radius: CGFloat) {
        let bezierPath = UIBezierPath(roundedRect: bounds, byRoundingCorners: [.allCorners], cornerRadii: CGSize(width: radius, height: radius))
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, scale)
        bezierPath.addClip()
        draw(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.image = image
    }
}

// ✅ 方案 2：shouldRasterize 缓存
imageView.layer.shouldRasterize = true
imageView.layer.rasterizationScale = UIScreen.main.scale
```

**优化阴影**：

```swift
// ❌ 触发离屏渲染
imageView.layer.shadowColor = UIColor.black.cgColor
imageView.layer.shadowOpacity = 0.5
imageView.layer.shadowOffset = CGSize(width: 0, height: 2)
imageView.layer.shadowRadius = 4

// ✅ 设置 shadowPath
imageView.layer.shadowPath = UIBezierPath(rect: bounds).cgPath
```

---

## 2. 高频面试题

### 2.1 渲染与离屏

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **什么是离屏渲染？** | 在屏幕外缓冲区渲染，完成后绘制到屏幕 | ⭐⭐⭐ |
| **如何检测离屏渲染？** | Instruments → Core Animation → Color Offscreen-Rendered Yellow | ⭐⭐⭐⭐ |
| **如何优化圆角？** | 贝塞尔曲线绘制图片、shouldRasterize | ⭐⭐⭐⭐ |
| **如何优化阴影？** | 设置 shadowPath | ⭐⭐⭐ |

（UIView 动画与 `CABasicAnimation` 等见 `CoreAnimation-动画与图层.md`。）

---

## 3. 参考资料

### 优质文章
- [iOS 事件传递与响应机制](https://developer.apple.com/documentation/uikit/uievent)
- [Core Animation Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui/)
- [Human Interface Guidelines - iOS](https://developer.apple.com/design/human-interface-guidelines/ios)

### 官方文档
- [UIKit - Event Handling](https://developer.apple.com/documentation/uikit/uievent)
- [Core Animation](https://developer.apple.com/quartzcore/)
- [SwiftUI](https://developer.apple.com/documentation/swiftui)

---

**最后更新**：2026-04-07
**状态**：✅ 已完成
