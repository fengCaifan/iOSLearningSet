# UIKit 事件响应链与手势

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - 事件传递（Hit-Testing）：从 UIApplication → UIWindow → ... → 最终响应者
  - 响应链（Responder Chain）：从 First Responder → ... → UIApplication
  - 手势识别器（UIGestureRecognizer）与响应链的关系
-->



## 2. 底层原理

<!-- 建议涵盖：
  - hitTest:withEvent: 与 pointInside:withEvent: 的递归调用流程
  - 事件传递的逆序遍历（后添加的 subview 优先）
  - 手势识别器优先级高于 UIResponder 的 touches 方法
  - cancelsTouchesInView / delaysTouchesBegan / delaysTouchesEnded
  - 多手势冲突解决：require(toFail:) / delegate 方法
  - IOKit → SpringBoard → Mach Port → UIApplication 的事件来源
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: 事件传递和响应链的区别？方向是什么？
  A: 

- Q: 如何扩大 UIButton 的点击区域？
  A: 

- Q: 手势识别器和 touchesBegan 等方法的优先级关系？
  A: 

- Q: 一个 view 超出了父 view 的 bounds，能不能接收到触摸事件？怎么解决？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 穿透点击（将事件传递给下层 view）
  - 复杂手势冲突场景的解决方案
-->



## 5. 参考资料

