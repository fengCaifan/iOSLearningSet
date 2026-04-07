# SwiftUI-状态管理与生命周期

> 一句话总结：**SwiftUI 用 @State/@Binding/@ObservedObject 等属性包装器表达单向数据流；与 UIKit 通过 UIHostingController/UIViewRepresentable 互通。**

---

## 📚 学习地图

- **预计学习时间**：50 分钟
- **前置知识**：Swift 基础
- **学习目标**：声明式 UI → 状态流 → 互操作

## 📖 目录

## 4. SwiftUI 基础

### 4.1 声明式 UI

**UIKit（命令式）**：

```swift
let label = UILabel()
label.text = "Hello"
label.font = UIFont.systemFont(ofSize: 17)
view.addSubview(label)
```

**SwiftUI（声明式）**：

```swift
struct ContentView: View {
    var body: some View {
        Text("Hello")
            .font(.system(size: 17))
    }
}
```

### 4.2 状态管理

**@State**：

```swift
struct ContentView: View {
    @State private var isOn = false

    var body: some View {
        Toggle("Switch", isOn: $isOn)
    }
}
```

**@Binding**：

```swift
struct ParentView: View {
    @State private var isOn = false

    var body: some View {
        ChildView(isOn: $isOn)  // $isOn 是 Binding
    }
}

struct ChildView: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("Switch", isOn: $isOn)
    }
}
```

**@ObservedObject & @Published**：

```swift
class ViewModel: ObservableObject {
    @Published var count = 0

    func increment() {
        count += 1
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ViewModel()

    var body: some View {
        VStack {
            Text("\(viewModel.count)")
            Button("Increment") {
                viewModel.increment()
            }
        }
    }
}
```

**@EnvironmentObject**：

```swift
// 注入
struct ContentView: View {
    @EnvironmentObject var settings: UserSettings

    var body: some View {
        Text("Username: \(settings.username)")
    }
}

// 提供
struct AppView: View {
    @StateObject private var settings = UserSettings()

    var body: some View {
        ContentView()
            .environmentObject(settings)
    }
}
```

### 4.3 数据流

**单向数据流**：

```
User Action → Action → State Update → View Update
```

**示例**：

```swift
enum Action {
    case increment
    case decrement
}

struct AppState {
    var count: Int = 0

    mutating func handle(_ action: Action) {
        switch action {
        case .increment:
            count += 1
        case .decrement:
            count -= 1
        }
    }
}

struct ContentView: View {
    @State private var state = AppState()

    var body: some View {
        VStack {
            Text("\(state.count)")
            Button("+") {
                state.handle(.increment)
            }
            Button("-") {
                state.handle(.decrement)
            }
        }
    }
}
```

---

## 5. SwiftUI 高级特性

### 5.1 自定义 ViewModifier

**ViewModifier 协议**：

```swift
struct ShadowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color, radius: radius)
    }
}

extension View {
    func shadow(color: Color = .black, radius: CGFloat = 5) -> some View {
        modifier(ShadowModifier(color: color, radius: radius))
    }
}

// 使用
Text("Hello")
    .shadow(color: .blue, radius: 10)
```

### 5.2 PreferenceKey

**父子 View 通信**：

```swift
struct SizePreferenceKey: PreferenceKey {
    typealias Value = CGSize
    static var defaultValue: CGSize = .zero
}

struct ChildView: View {
    var body: some View {
        GeometryReader { geometry in
            Color.blue
                .preference(key: SizePreferenceKey.self, value: geometry.size)
        }
    }
}

struct ParentView: View {
    var body: some View {
        VStack {
            ChildView()
                .onPreferenceChange(SizePreferenceKey.self) { size in
                    print("Child size: \(size)")
                }
        }
    }
}
```

### 5.3 自定义 Shape

**Shape 协议**：

```swift
struct Diamond: Shape {
    var inset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let size = min(rect.width, rect.height) / 2 - inset

        path.move(to: CGPoint(x: center.x, y: center.y - size))
        path.addLine(to: CGPoint(x: center.x + size, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + size))
        path.addLine(to: CGPoint(x: center.x - size, y: center.y))
        path.closeSubpath()

        return path
    }
}

// 使用
Diamond(inset: 10)
    .fill(Color.blue)
    .frame(width: 100, height: 100)
```

### 5.4 Combine 集成

**onReceive**：

```swift
class ViewModel: ObservableObject {
    @Published var data: [String] = []

    func fetchData() {
        // 模拟网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.data = ["Item1", "Item2", "Item3"]
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ViewModel()

    var body: some View {
        List(viewModel.data, id: \.self) { item in
            Text(item)
        }
        .onReceive(viewModel.$data) { data in
            print("Data updated: \(data)")
        }
        .onAppear {
            viewModel.fetchData()
        }
    }
}
```

---

## 6. UIKit 与 SwiftUI 互操作

### 6.1 SwiftUI 中使用 UIKit

**UIViewRepresentable**：

```swift
struct ActivityIndicator: UIViewRepresentable {
    @Binding var isAnimating: Bool

    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView(style: .large)
        return indicator
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        if isAnimating {
            uiView.startAnimating()
        } else {
            uiView.stopAnimating()
        }
    }
}

// 使用
struct ContentView: View {
    @State private var isAnimating = false

    var body: some View {
        ActivityIndicator(isAnimating: $isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}
```

**UIViewControllerRepresentable**：

```swift
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(image: $image, presentationMode: presentationMode)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @Binding var image: UIImage?
        @Binding var presentationMode: PresentationMode

        init(image: Binding<UIImage?>, presentationMode: Binding<PresentationMode>) {
            self._image = image
            self._presentationMode = presentationMode
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                image = uiImage
            }
            presentationMode.dismiss()
        }
    }
}
```

### 6.2 UIKit 中使用 SwiftUI

**UIHostingController**：

```swift
import SwiftUI

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let swiftUIView = ContentView()
        let hostingController = UIHostingController(rootView: swiftUIView)

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.didMove(toParent: self)
    }
}

struct ContentView: View {
    var body: some View {
        Text("Hello from SwiftUI")
            .font(.largeTitle)
    }
}
```

---

## 7. 高频面试题

### 7.1 SwiftUI

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **@State vs @Binding vs @ObservedObject？** | @State：本地状态；@Binding：子视图修改父视图；@ObservedObject：引用类型，外部管理 | ⭐⭐⭐⭐ |
| **@EnvironmentObject 的作用？** | 全局共享状态，依赖注入 | ⭐⭐⭐ |
| **SwiftUI 的 View 刷新机制？** | 状态改变 → body 重新计算 → View 更新（Diff 算法） | ⭐⭐⭐⭐ |
| **UIViewRepresentable 的作用？** | 在 SwiftUI 中使用 UIView | ⭐⭐⭐ |

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
