# UIKit-事件响应链与手势

> 一句话总结：**Hit-Testing 自顶向下找命中视图，响应链再自下而上寻找响应者；手势在触摸路径上与 Responder 协同。**

---

## 📚 学习地图

- **预计学习时间**：40 分钟
- **前置知识**：UIView 基础
- **学习目标**：hitTest/pointInside → 响应链 → 手势冲突

---

## 1. 事件响应链

### 1.1 Hit-Testing（命中测试）

**寻找最合适的 View**：

```
1. 系统接收触摸事件
2. 从 Window 开始，调用 point(inside:with:) 方法
3. 从后往前遍历 subviews
4. 找到包含触摸点的最前面的 View
```

**point(inside:with:) 方法**：

```swift
class CustomView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // 自定义点击区域
        let expandedBounds = bounds.insetBy(dx: -20, dy: -20)
        return expandedBounds.contains(point)
    }
}
```

### 1.2 事件传递链（Hit-Testing to Window）

**传递过程**：

```
1. UIWindow.sendEvent(_:)：接收事件
2. UIView.hitTest(_:with:)：寻找最佳响应者
   - point(inside:with:)：判断点是否在 View 内
   - 从后往前遍历 subviews
   - 找到最合适的 View
3. 返回 Hit-Test View
```

### 1.3 事件响应链

**响应过程**：

```
1. Hit-Test View 首先尝试响应
2. 如果不能响应，传递给 nextResponder
3. 传递链：View →Superview →...→ViewController →Window →Application
4. 如果都不响应，事件被丢弃
```

**nextResponder 属性**：

```swift
// UIView 的 nextResponder 是 superview
// UIViewController 的 nextResponder 是 view（如果 view 不是它）或 parent view controller
// UIWindow 的 nextResponder 是 UIApplication
// UIApplication 的 nextResponder 是 AppDelegate（如果存在）
```

** UIResponder 链**：

```swift
// 触摸方法
touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?)

// 响应者链
class MyView: UIView {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("MyView touchesBegan")
        // 不调用 super，阻止事件继续传递
        // 或者调用 super.next?.touchesBegan(touches, with: event)
    }
}
```

### 1.4 手势识别器（UIGestureRecognizer）

**添加手势**：

```swift
let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
view.addGestureRecognizer(tapGesture)

@objc func handleTap(_ gesture: UITapGestureRecognizer) {
    print("Tapped")
}
```

**手势冲突**：

```swift
// 多个手势同时识别
tapGesture.require(toFail: swipeGesture)

// UIGestureRecognizerDelegate
func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true  // 允许同时识别
}

func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true  // 等待 otherGestureRecognizer 失败后才识别
}
```

---

## 7. 高频面试题

### 7.1 事件响应

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **事件传递链和响应链的区别？** | 传递链：从 Window → 找最佳响应者；响应链：从最佳响应者 → 往上传递 | ⭐⭐⭐⭐ |
| **如何扩大 View 的点击区域？** | 重写 point(inside:with:)，扩大 bounds | ⭐⭐⭐ |
| **nextResponder 的传递顺序？** | View → Superview → ViewController → Window → Application | ⭐⭐⭐ |
| **手势识别器如何优先处理？** | require(toFail:)、UIGestureRecognizerDelegate | ⭐⭐⭐ |

---

## 8. 参考资料

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
