# 分阶段图片加载 Demo：三个 OperationQueue + 依赖

这是 `TableViewImageLoadingDemo` 的进阶版本。将四个 `.swift` 文件添加到 UIKit 工程，并将根控制器设为 `SplitImageListViewController`。

## 目标

满足以下独立约束：

```text
最多 6 个网络下载
最多 2 个图片解码
最多 1 个缓存写入（实际项目通常指磁盘编码 / I/O）
```

## 结构

```text
同一张图片：
DownloadOperation ──dependency──> DecodeOperation ──dependency──> CacheWriteOperation
     ↓                                   ↓                                  ↓
downloadQueue(6)                    decodeQueue(2)                 cacheWriteQueue(1)

所有图片共享上面三个队列，而不是每张图创建一组队列。
```

## 为什么同时有 `cacheWriteQueue` 和 `memoryCacheQueue`？

它们不是重复：

- `cacheWriteQueue`：控制**缓存写入这一业务阶段**一次只做一个。真实实现常包括磁盘编码、文件写入、索引更新等。
- `memoryCacheQueue`：保护共享的 Swift `Dictionary`。它使用 GCD concurrent queue，读可以并发，写通过 barrier 独占。

若只有内存缓存字典，`CacheWriteOperation` 通常没有必要；直接使用 `NSCache`、`actor`、锁或 barrier 即可。这里保留它是为了演示独立的第三个限流阶段。

## 重要边界

1. `addDependency` 的含义是“上游**已结束**”，不是“上游**成功**”。下载失败或取消时，DecodeOperation 仍可能获得执行机会，因此它会检查 `context.data`；缓存同理检查 `context.image`。
2. `DownloadOperation` 是异步 Operation：只有 URLSession 回调里执行 `finish()` 后，`downloadQueue` 才释放一个下载并发名额。
3. Cell 取消三个 Operation，已运行任务会在每个阶段检查 `isCancelled`；UI 赋图前还要比较 `representedURLString`，取消不能代替这一身份校验。
4. 生产图片框架还需要：请求去重/合并、磁盘缓存、HTTP 缓存、降采样、渐进式解码、预取、优先级动态调整、内存警告清理、指标与错误重试。
