# TableView 图片加载：OperationQueue + GCD 最小示例

这是一个 **Swift + UIKit** 示例。将目录内的三个 `.swift` 文件加入 UIKit 工程；在 `SceneDelegate` 或导航控制器中把根控制器设为 `ImageListViewController`。示例使用 `picsum.photos`，设备需有网络。

## 关键结构

```text
整个列表共享 1 个 ImageLoader
  ├── 1 个 NSOperationQueue（maxConcurrentOperationCount = 4）
  │     ├── 图片 A：1 个 ImageLoadOperation
  │     ├── 图片 B：1 个 ImageLoadOperation
  │     └── 图片 C：1 个 ImageLoadOperation
  ├── 1 个 GCD 并发 decodeQueue（做 CPU 解码）
  └── 1 个 GCD 并发 cacheQueue（读并发，barrier 写独占）
```

**每张图片不会单独创建 `OperationQueue`。** 每张图片创建的是一个 `Operation`，它们全都加入列表共享的同一个 `OperationQueue`。因此 `maxConcurrentOperationCount = 4` 仍然必要：它限制最多四个图片请求处于从下载到解码的执行生命周期，避免快速滚动时同时网络请求/解码过多，引起 CPU、内存峰值或带宽争抢。

本 demo 将“下载 → 解码 → 写缓存”封装在**一个异步 Operation**中，而不是为每个阶段再拆一个 Operation。这样更容易看清职责，也避免 URLSession 异步回调导致 `NSBlockOperation` 过早结束的问题。复杂生产场景才可拆成 `DownloadOperation → DecodeOperation → CacheOperation` 依赖链；此时仍应把所有 Operation 放进**全局共享**的队列中。

## 协作流程

```text
cellForRow:
  记录 cell.representedURLString
  → loader 先读缓存
  → 未命中则创建 ImageLoadOperation 并加入共享 operationQueue
  → URLSession 下载完成
  → decodeQueue 后台解码
  → cacheQueue barrier 写缓存
  → main queue 回调
  → 比较 Cell 的 URL 是否仍是本次 URL，匹配才赋图

prepareForReuse / didEndDisplaying:
  → request.cancel
  → operation.cancel + URLSessionTask.cancel
```

取消是协作式的：网络回调、解码前后都会检查 `isCancelled`，但已经排到主线程的回调仍可能到达，因此最终的 `representedURLString` 比对不可省略。

## Group 放在哪里？

本 demo 的单 Cell 加载无需等“所有图片完成”，故不使用 Group。若 Feed 首屏需等整批图片下载、解码、缓存全部结束后只刷新一次：对每个图片完整流程 `dispatch_group_enter` 一次，并在最后一个阶段（缓存写完或失败/取消收尾处）**恰好一次** `dispatch_group_leave`；随后 `dispatch_group_notify(group, mainQueue, ...)` 刷新。不能只用 `dispatch_group_async` 包住 `dataTask` 的创建，因为网络 completion 发生时外层 block 早已返回。
