import UIKit

// MARK: - 共享每张图片在各 Operation 间传递的结果

private final class ImagePipelineContext: @unchecked Sendable {
    private let lock = NSLock()
    private var _data: Data?
    private var _image: UIImage?

    var data: Data? { lock.lock(); defer { lock.unlock() }; return _data }
    var image: UIImage? { lock.lock(); defer { lock.unlock() }; return _image }

    func set(data: Data) { lock.lock(); _data = data; lock.unlock() }
    func set(image: UIImage) { lock.lock(); _image = image; lock.unlock() }
}

/// 一个请求持有三个 Operation。Cell 复用时调用 cancel，三个阶段都会收到取消信号。
final class SplitImageRequest {
    private let operations: [Operation]
    init(operations: [Operation] = []) { self.operations = operations }
    func cancel() { operations.forEach { $0.cancel() } }
}

// MARK: - 三个独立阶段

private final class DownloadOperation: AsyncOperation, @unchecked Sendable {
    private let url: URL
    private let context: ImagePipelineContext
    private var task: URLSessionDataTask?

    init(url: URL, context: ImagePipelineContext) {
        self.url = url
        self.context = context
        super.init()
    }

    override func execute() {
        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            defer { self.finish() }
            guard !self.isCancelled, error == nil, let data, !data.isEmpty else { return }
            self.context.set(data: data)
        }
        task?.resume()
    }

    override func cancel() {
        super.cancel()
        task?.cancel()
    }
}

private final class DecodeOperation: Operation, @unchecked Sendable {
    private let context: ImagePipelineContext
    init(context: ImagePipelineContext) { self.context = context }

    override func main() {
        guard !isCancelled, let data = context.data, let source = UIImage(data: data) else { return }

        // 可在这里加入 CGImageSourceThumbnailAtIndex 做降采样；Demo 只展示后台位图解码。
        let format = UIGraphicsImageRendererFormat()
        format.scale = source.scale
        let renderer = UIGraphicsImageRenderer(size: source.size, format: format)
        let image = renderer.image { _ in source.draw(at: .zero) }

        guard !isCancelled else { return }
        context.set(image: image)
    }
}

private final class CacheWriteOperation: Operation, @unchecked Sendable {
    private let key: String
    private let context: ImagePipelineContext
    private weak var pipeline: SplitImagePipeline?
    private let completion: (UIImage?) -> Void

    init(key: String,
         context: ImagePipelineContext,
         pipeline: SplitImagePipeline,
         completion: @escaping (UIImage?) -> Void) {
        self.key = key
        self.context = context
        self.pipeline = pipeline
        self.completion = completion
    }

    override func main() {
        guard !isCancelled, let image = context.image else { return }
        pipeline?.writeToMemoryCache(image, for: key)
        guard !isCancelled else { return }
        DispatchQueue.main.async { [completion] in completion(image) }
    }
}

// MARK: - Pipeline

/// 教学版：下载、解码、缓存写拥有不同的 OperationQueue，因此可分别限流。
final class SplitImagePipeline {
    private let downloadQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.fcf.image-pipeline.download"
        queue.maxConcurrentOperationCount = 6
        return queue
    }()

    private let decodeQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.fcf.image-pipeline.decode"
        queue.maxConcurrentOperationCount = 2
        return queue
    }()

    // 在真实工程中，此队列常对应磁盘缓存的编码 / 文件 I/O，串行可简化一致性与写放大控制。
    private let cacheWriteQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.fcf.image-pipeline.cache-write"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    // 这是“共享内存 Dictionary 的线程安全”问题，和缓存写入阶段的调度是两个维度。
    private let memoryCacheQueue = DispatchQueue(
        label: "com.fcf.image-pipeline.memory-cache",
        attributes: .concurrent
    )
    private var memoryCache: [String: UIImage] = [:]

    @discardableResult
    func loadImage(url: URL, completion: @escaping (UIImage?) -> Void) -> SplitImageRequest {
        let key = url.absoluteString
        if let cached = memoryCacheQueue.sync(execute: { memoryCache[key] }) {
            DispatchQueue.main.async { completion(cached) }
            return SplitImageRequest()
        }

        let context = ImagePipelineContext()
        let download = DownloadOperation(url: url, context: context)
        let decode = DecodeOperation(context: context)
        let cache = CacheWriteOperation(key: key, context: context, pipeline: self, completion: completion)

        // dependency 只保证“上游结束”，不保证“上游成功”；每个下游在 main 中仍须检查 data/image。
        decode.addDependency(download)
        cache.addDependency(decode)

        downloadQueue.addOperation(download)  // 最多 6 个网络阶段
        decodeQueue.addOperation(decode)      // 最多 2 个解码阶段
        cacheWriteQueue.addOperation(cache)   // 一次只写一个缓存阶段

        return SplitImageRequest(operations: [download, decode, cache])
    }

    fileprivate func writeToMemoryCache(_ image: UIImage, for key: String) {
        memoryCacheQueue.sync(flags: .barrier) {
            memoryCache[key] = image
        }
    }
}
