import UIKit

/// Cell 复用或页面离开时持有的请求句柄。
/// cancel 是协作式的：它不会让已经回到主队列的闭包凭空消失，UI 层仍需校验 URL / ID。
final class ImageRequest {
    private let operation: ImageLoadOperation?

    init(operation: ImageLoadOperation? = nil) {
        self.operation = operation
    }

    func cancel() {
        operation?.cancel()
    }
}

/// 一张图片对应一个异步 Operation。
/// 它在一个任务中按顺序完成：网络下载 -> 后台解码 -> 回调 Loader 写缓存 / 更新 UI。
private final class ImageLoadOperation: Operation, @unchecked Sendable {
    private let url: URL
    private let decodeQueue: DispatchQueue
    private let completion: (UIImage?) -> Void
    private let stateLock = NSLock()

    private var task: URLSessionDataTask?
    private var _executing = false
    private var _finished = false

    override var isAsynchronous: Bool { true }
    override var isExecuting: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return _executing
    }
    override var isFinished: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return _finished
    }

    init(url: URL,
         decodeQueue: DispatchQueue,
         completion: @escaping (UIImage?) -> Void) {
        self.url = url
        self.decodeQueue = decodeQueue
        self.completion = completion
        super.init()
    }

    override func start() {
        if isCancelled {
            finish()
            return
        }

        willChangeValue(forKey: "isExecuting")
        stateLock.lock()
        _executing = true
        stateLock.unlock()
        didChangeValue(forKey: "isExecuting")

        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }

            // 网络完成时，Cell 可能已复用并取消了该请求。
            guard !self.isCancelled, error == nil, let data, !data.isEmpty else {
                self.finish()
                return
            }

            // 解码是 CPU 工作，明确放到后台队列，避免占用 URLSession 回调队列。
            self.decodeQueue.async { [weak self] in
                guard let self, !self.isCancelled else {
                    self?.finish()
                    return
                }

                let image = self.decode(data: data)
                guard !self.isCancelled, let image else {
                    self.finish()
                    return
                }

                self.completion(image) // 当前仍在后台；Loader 负责切回主线程。
                self.finish()
            }
        }
        task?.resume()
    }

    override func cancel() {
        super.cancel()
        task?.cancel() // URLSession 的 completion 仍可能已经在排队，因此所有阶段都要检查 isCancelled。
    }

    private func decode(data: Data) -> UIImage? {
        guard let source = UIImage(data: data) else { return nil }

        // 通过后台绘制触发位图解码，避免首次显示时把较重的解码工作压到主线程。
        let format = UIGraphicsImageRendererFormat()
        format.scale = source.scale
        let renderer = UIGraphicsImageRenderer(size: source.size, format: format)
        return renderer.image { _ in
            source.draw(at: .zero)
        }
    }

    private func finish() {
        stateLock.lock()
        let shouldFinish = !_finished
        stateLock.unlock()
        guard shouldFinish else { return }

        willChangeValue(forKey: "isExecuting")
        willChangeValue(forKey: "isFinished")
        stateLock.lock()
        _executing = false
        _finished = true
        stateLock.unlock()
        didChangeValue(forKey: "isFinished")
        didChangeValue(forKey: "isExecuting")
    }
}

/// 列表共享的图片加载器：共享一个 OperationQueue，而不是一张图片一个 Queue。
final class ImageLoader {
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.fcf.image-loader.operations"
        queue.maxConcurrentOperationCount = 4
        return queue
    }()

    private let decodeQueue = DispatchQueue(
        label: "com.fcf.image-loader.decode",
        qos: .userInitiated,
        attributes: .concurrent
    )

    // Dictionary 可变且非线程安全：读任务可并发，写任务用 barrier 独占。
    private let cacheQueue = DispatchQueue(
        label: "com.fcf.image-loader.cache",
        attributes: .concurrent
    )
    private var memoryCache: [String: UIImage] = [:]

    @discardableResult
    func loadImage(url: URL, completion: @escaping (UIImage?) -> Void) -> ImageRequest {
        let key = url.absoluteString

        // 为了演示读多写少，读缓存使用同步读；这里临界区极短，且不做磁盘 I/O。
        let cachedImage = cacheQueue.sync { memoryCache[key] }
        if let cachedImage {
            DispatchQueue.main.async { completion(cachedImage) }
            return ImageRequest()
        }

        let operation = ImageLoadOperation(url: url, decodeQueue: decodeQueue) { [weak self] image in
            guard let self, let image else { return }

            // sync 的目的：Operation 完成前确保缓存已写入；不能在 cacheQueue 内再次 sync 自己。
            self.cacheQueue.sync(flags: .barrier) {
                self.memoryCache[key] = image
            }
            DispatchQueue.main.async {
                completion(image)
            }
        }

        operationQueue.addOperation(operation)
        return ImageRequest(operation: operation)
    }
}
