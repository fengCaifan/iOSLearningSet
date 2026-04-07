# CoreText-文字排版与 YYLabel

> 一句话总结：**Core Text 在底层用 `CFAttributedString` + `CGPath` 排版，产出 CTLine/CTRun；UIKit 是左上角坐标系，Core Text 常用左下角，需要 CTM 转换。YYLabel 本质是把这套排版搬到子线程位图再贴主线程。**

---

## 1. 核心概念

### 1.1 职责分工

- **Core Text**：排版与字形整形（shaping）、画字到 `CGContext`。
- **Core Graphics**：路径、阴影、边框、位图上下文。
- 富文本 UIKit 组件（`UILabel`/`UITextView`）高层易用，复杂富文本与性能极致时常下沉到 Core Text。

### 1.2 核心对象（由上到下）

| 类型 | 含义 |
|------|------|
| **CTFramesetter** | 根据属性串与 path 创建 `CTFrame` |
| **CTFrame** | 一块排版区域，内含多行 **CTLine** |
| **CTLine** | 一行，内含多个 **CTRun**（同属性连续区段） |
| **CTRun** | 一次绘制单元；可用 **CTRunDelegate** 占位图文混排 |
| **CTFont** | 字体、metric，与 `UIFont` 可桥接 |

---

## 2. 底层原理

### 2.1 排版流程

1. `CGPath` 指定绘制区域（常为矩形，也支持异形 path）。
2. `CTFramesetterCreateWithAttributedString` + `CTFramesetterCreateFrame` 生成 `CTFrame`。
3. `CTFrameDraw` 绘制到上下文。

### 2.2 坐标系转换

```objc
CGContextSetTextMatrix(context, CGAffineTransformIdentity);
CGContextTranslateCTM(context, 0, self.bounds.size.height);
CGContextScaleCTM(context, 1.0, -1.0);
```

### 2.3 图文混排（CTRunDelegate）

- Core Text **不直接画附件图**：在富文本中插入占位字符（如 U+FFFC），给该 run 设置 `kCTRunDelegateAttributeName`。
- delegate 回调提供 ascent/descent/width，布局阶段为图片留出盒模型。
- **布局后再算 frame**：遍历 line → run，读到 delegate 的 refCon，结合 `CTLineGetOffsetForStringIndex`、`CTRunGetTypographicBounds` 算 rect，最后用 `CGContextDrawImage` 或 `UIImage drawInRect` 绘制。

### 2.4 截断与行数限制

- 不限行：`CTFrameDraw` 一次画完。
- 限制行数：取 `CTFrameGetLines` 前 N 行，用 **CTLineDraw** 逐行绘制；最后一行可用 `CTLineTruncateToken` 等方式生成省略。

### 2.5 与自动布局

- `sizeThatFits:` / `intrinsicContentSize` 中调用 `CTFramesetterSuggestFrameSizeWithConstraints` 计算内容尺寸；Auto Layout 下需先有**确定宽度**。

---

## 3. YYText / YYLabel 在做什么

- **瓶颈**：UIKit 文本绘制多在主线程，富文本 + 大图纹混排易卡。
- **思路**：异步线程创建 **bitmap context**，用 Core Text + Core Graphics 画完，主线程只设置 `layer.contents`。
- **难点**：Run/Line 级坐标与附件 frame 的计算、线程安全、取消过时绘制（如 `YYAsyncLayer` 的 display 取消与队列调度）。

---

## 4. 关键问题 & 面试题

- **为什么说 Core Text 更适合做「预排版」？** `CTFramesetterSuggestFrameSizeWithConstraints` 在 Feed 类列表里算高更省。
- **CTRunDelegate 解决什么问题？** 在文本流中插入可换行的**占位**，再把图贴到算好的 rect。
- **YYText 异步绘制要避免什么？** 数据竞争、过时任务回写、过度并发吃满 CPU。

---

## 5. 参考资料

- [Core Text Programming Guide（存档）](https://developer.apple.com/library/archive/documentation/StringsTextFonts/Conceptual/CoreText_Programming/Introduction/Introduction.html)
- [YYText GitHub](https://github.com/ibireme/YYText)
- 旧笔记：`读书笔记/iOS自学笔记/专题 —— Core Text 与 YYLabel.md`
