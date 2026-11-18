import Foundation

/// URLSession 等回调式异步 API 的 Operation 基类。
/// OperationQueue 只有观察到 isFinished == true 后，才会为下一个任务腾出并发名额。
class AsyncOperation: Operation, @unchecked Sendable {
    private let stateLock = NSLock()
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

    override func start() {
        if isCancelled { finish(); return }
        willChangeValue(forKey: "isExecuting")
        stateLock.lock(); _executing = true; stateLock.unlock()
        didChangeValue(forKey: "isExecuting")
        execute()
    }

    /// 子类开始真正的异步工作；每一条成功、失败、取消路径最终都必须调用 finish()。
    func execute() {
        fatalError("Subclasses must override execute()")
    }

    func finish() {
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
