# Swift 并发模型(async/await/Actor)

> 一句话总结：**Swift 并发以 async/await 表达异步控制流、以 Actor / MainActor 在类型系统里隔离可变状态；底层仍常映射到线程池与 libdispatch，但与 GCD「队列+Block」相比多了编译期可验证的隔离与结构化生命周期。**

---

## 📚 学习地图

- **预计学习时间**：90～120 分钟
- **前置知识**：GCD、RunLoop（见 `OC-RunLoop原理与应用.md`）、内存与捕获（见 `Swift-内存管理与ARC.md`）
- **学习目标**：理解 **Task 与执行器** → **Continuation 与线程跳迁** → **Actor 隔离与 OC 主线程模型的对应关系** → **Sendable / Swift 6 数据竞争检查**

---

## 1. 心智模型：从 GCD / NSOperationQueue 到 Swift 并发

**Objective-C 时代的主流模型**：

- `dispatch_async(queue, ^{ ... })`：把 **Block** 投递到队列；队列由 **libdispatch** 映射到线程池或主线程。
- `NSOperationQueue`：在 GCD 之上增加依赖、优先级、取消（协作式）等。
- 主线程：`dispatch_get_main_queue()` 与 **RunLoop** 配合驱动 UIKit；见同目录 `OC-RunLoop原理与应用.md`。

**Swift 并发（Structured Concurrency）在工程上补了什么？**

- **结构化范围**：`async let` / `withTaskGroup` 让子任务的生命周期绑定到父 `Task`，父任务取消可向下传播（仍依赖协作检查 `Task.isCancelled`）。
- **隔离（isolation）**：`actor` / `@MainActor` 把「哪些代码能碰哪些可变状态」写进类型系统；这比「约定所有 UI 都在主队列改」更可静态分析。
- **底层仍可能是 libdispatch**：Apple 平台上默认执行器与线程池实现与 GCD 有历史渊源；把 Swift 并发理解为「**新语言表面 + 新调度语义**」比「完全替代内核/线程」更准确。

---

## 2. async / await 与线程：不是「每个 await 换一个线程」

```swift
func load() async -> Data {
    let (data, _) = try! await URLSession.shared.data(from: url)
    return data
}
```

- `await` 表示 **挂起点**：当前任务可能让出执行线程，完成后再恢复。
- **恢复时不保证回到同一线程**（除非受 **Actor 隔离** 或 **MainActor** 约束）。
- 这与「在 GCD 全局队列上 `dispatch_async` 嵌套」类似：回调可能在不同线程；区别在于 **async 函数用状态机（continuation）表达**，避免 Callback Hell。

**与 OC Block 的对比**：

| 点 | OC Block + GCD | Swift async |
|----|------------------|---------------|
| 控制流 | 嵌套回调 | 线性写法的挂起/恢复 |
| 错误 | 常靠 completion 多参数 | `throws` 与 `try await` 统一 |
| 线程 | 由 queue 决定 | 由 **Executor** + 隔离域决定 |

---

## 3. Task、优先级与取消

```swift
Task {
    await work()
}

Task(priority: .userInitiated) {
    await work()
}
```

- **独立任务**：`Task { }` 不继承外部 `async` 的取消与优先级（与 `async let` / `task group` 不同）。
- **取消是协作式的**：被调代码应周期性检查 `Task.isCancelled`，I/O 常用 `URLSession` 的异步 API 与取消令牌配合。
- **与 `NSOperation` 的 `cancel`**：思想类似——**不会强行杀掉线程**，只改变标志；未检查则仍会继续跑。

---

## 4. Actor：串行队列的「类型化」版本（类比与差异）

```swift
actor Counter {
    private var value = 0
    func increment() -> Int {
        value += 1
        return value
    }
}
```

**类比 OC**：可把 `actor` 想象成「**仅允许在一条隐式串行队列上**访问其存储属性」的类型；所有 `await actor.method()` 都可能挂起，Compiler 防止你**同步**从外部直接读内部 `var`。

**差异**：

- **编译器检查**：跨 actor 边界访问可变状态会报错，而不是仅靠规范或崩溃现场反推。
- **可重入（reentrancy）**：在 `await` 期间 actor 可能处理其他进入请求；设计时要避免「中间状态被别的调用看见」的假设错误——这与「在串行队列 async 点之间别的队列也能跑」的交错问题同源，只是 Swift 用 `await` 显式标出挂起点。

---

## 5. MainActor：主线程隔离与 UIKit

```swift
@MainActor
final class ViewModel: ObservableObject {
    @Published var title: String = ""
    func update(from data: Data) {
        title = String(decoding: data, as: UTF8.self)
    }
}
```

**与 OC 的对应**：

- UIKit / AppKit 要求 **主线程**触摸 UI；OC 里习惯 `dispatch_async(dispatch_get_main_queue(), ^{ ... })` 或 `performSelectorOnMainThread:withObject:waitUntilDone:`。
- `@MainActor` 把「必须在主执行器上」写进类型；`await` 到 `@MainActor` 方法时，运行时会调度回 **main executor**（与主 RunLoop 驱动的线程一致）。

**混编提示**：从非隔离上下文 `await` 调用 `@MainActor` API 是合法路径；若用 **同步** API 强行走主线程，仍会回到 GCD 主队列那套，注意**死锁**（主线程同步 `wait` 自己又等主线程）。

---

## 6. Sendable、隔离与 Swift 6 数据竞争

- **Sendable**：标记「可安全跨并发域传递」的类型；编译器据此诊断 **data race**。
- **常见规则直觉**：`struct` 若成员均 `Sendable` 则常自动 `Sendable`；很多 `class` 需 `@unchecked Sendable`（自行保证）或保持非 `Sendable` 强制在 actor 内持有。
- **与 OC 的 `atomic` / `@synchronized` 对比**：OC 常靠锁或队列约定；Swift 6 倾向在编译期把「共享可变状态」收敛到 **actor** 或 **串行执行上下文**，而不是到处散落的锁。

---

## 7. Continuation：桥接回调式 API（含 GCD / 传统 OC）

将「完成时调用 Block」转为 `async`：

```swift
func loadAsync() async throws -> String {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
        DispatchQueue.global().async {
            do {
                let s = try heavyWork()
                continuation.resume(returning: s)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

**要点**：

- **必须且只能** `resume` 一次；多次或零次会触发运行时诊断（Checked）或 UB（Unsafe）。
- 这是把 **legacy OC / C 回调** 渐进迁移到 Swift 并发的标准胶水层。

---

## 8. 与 Block 捕获、内存管理的交集

- Swift 并发闭包同样受 **ARC** 与 **逃逸** 规则约束；长生命周期的 `Task` 会强持有捕获对象，易形成与「GCD + self」同类的**循环引用**——需 `[weak self]` 等（见 `Swift-内存管理与ARC.md` 与 `OC-Block底层实现.md`）。
- **Actor 隔离**不改变引用计数模型，只改变**谁能同步访问状态**。

---

## 9. 高频对照表（面试向）

| 问题 | 要点 |
|------|------|
| async 会不会阻塞线程？ | `await` 挂起**任务**不阻塞当前线程；线程可去跑别的 work item |
| Actor vs 串行队列？ | 类比串行队列；Actor 带编译期隔离与可重入语义 |
| MainActor vs 主队列？ | 目标都是主线程执行器；MainActor 是语言级标记 |
| 与 GCD 是否二选一？ | 可共存；Continuation 桥接旧 API；新代码优先 Swift 并发 |
| Swift 6 数据竞争？ | `Sendable` + 隔离域；比纯约定更接近「编译期保证」 |

---

## 10. 参考资料

### 官方与演进

- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)（Swift 语言指南）
- WWDC：Swift Concurrency、Strict Concurrency、Migrate to Swift 6 相关议题

### 与 GCD / OC 上下文衔接（本仓库）

- `OC-RunLoop原理与应用.md` — 主线程消息泵
- `OC-Block底层实现.md` — Block 布局与捕获，对照 `Task` 闭包

---

**最后更新**：2026-04-13  
**状态**：✅ 已扩充（底层对照 + Continuation + Swift 6 方向）
