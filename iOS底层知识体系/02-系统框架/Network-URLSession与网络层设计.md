# Network-URLSession 与网络层设计

> 一句话总结：**URLSession 是 iOS 原生异步网络栈；在其上封装 Session 配置、拦截链、缓存与重试策略，构成可测试的业务网络层。**

---

## 📚 学习地图

- **预计学习时间**：60+ 分钟
- **前置知识**：HTTP/HTTPS
- **学习目标**：URLSession API → 架构分层 → 缓存/加密pinning 要点

---

## 5. iOS 网络层架构设计

### 5.1 URLSession 完全指南

#### 5.1.1 URLSession 的组成

**URLSession 的三个核心组件**：

```
1. URLSessionConfiguration：配置会话
2. URLSession：会话对象
3. URLSessionTask：任务对象
```

#### 5.1.2 URLSessionConfiguration

**三种预定义配置**：

```swift
// 1. Default Session（默认）
// - 使用磁盘持久化缓存
// - 存储证书到钥匙串
let config = URLSessionConfiguration.default

// 2. Ephemeral Session（临时）
// - 不存储任何数据到磁盘
// - 不缓存、不存储 Cookie、不存储证书
let config = URLSessionConfiguration.ephemeral

// 3. Background Session（后台）
// - 在后台运行上传/下载任务
// - 需要提供 identifier
let config = URLSessionConfiguration.background(withIdentifier: "com.example.background")
```

**自定义配置**：

```swift
let config = URLSessionConfiguration.default

// 超时时间
config.timeoutIntervalForRequest = 30.0
config.timeoutIntervalForResource = 604800.0 // 7 天

// 缓存策略
config.requestCachePolicy = .returnCacheDataElseLoad
config.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024,   // 20 MB
                         diskCapacity: 100 * 1024 * 1024)      // 100 MB

// Cookie
config.httpShouldSetCookies = true
config.httpCookieAcceptPolicy = .always

// 安全策略
config.tlsMinimumSupportedProtocolVersion = .TLSv12
config.urlCredentialStorage = URLCredentialStorage.shared

// 代理
config.connectionProxyDictionary = ["HTTPEnable": 1, "HTTPProxy": "proxy.example.com:8080"]

// 网络服务类型（QoS）
config.networkServiceType = .background // .default, .voip, .video, etc.

// 等待
config.waitsForConnectivity = true

// 是否允许蜂窝网络
config.allowsCellularAccess = true

// 创建 Session
let session = URLSession(configuration: config)
```

#### 5.1.3 URLSessionTask 的四种类型

**1. URLSessionDataTask（数据任务）**

```swift
// 用于接收数据到内存
let task = session.dataTask(with: url) { data, response, error in
    // 处理数据
}
task.resume()
```

**2. URLSessionUploadTask（上传任务）**

```swift
// 方式 1：从 Data 上传
let data = UIImagePNGRepresentation(image)!
let task = session.uploadTask(with: request, from: data) { data, response, error in
    // 上传完成
}

// 方式 2：从 File 上传
let fileURL = URL(fileURLWithPath: "/path/to/file")
let task = session.uploadTask(with: request, fromFile: fileURL) { data, response, error in
    // 上传完成
}

// 监听上传进度
task = session.uploadTask(with: request, from: data)
session.delegate = self
task.resume()

// URLSessionTaskDelegate
func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
    let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
    print("上传进度: \(progress * 100)%")
}
```

**3. URLSessionDownloadTask（下载任务）**

```swift
// 简单下载
let task = session.downloadTask(with: url) { tempURL, response, error in
    if let tempURL = tempURL {
        // 临时文件需要移动到持久位置
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsURL.appendingPathComponent("image.jpg")

        try? FileManager.default.removeItem(at: destinationURL)
        try? FileManager.default.moveItem(at: tempURL, to: destinationURL)
    }
}
task.resume()

// 监听下载进度
session.delegate = self

func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
    print("下载进度: \(progress * 100)%")
}

func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    // 下载完成，移动文件
}
```

**4. URLSessionStreamTask（流任务）**

```swift
// 用于建立 TCP/IP 连接（用于自定义协议）
let task = session.streamTask(withHostName: "example.com", port: 80)
task.resume()
```

#### 5.1.4 后台下载与断点续传

**后台下载**：

```swift
// 1. 创建 Background Configuration
let config = URLSessionConfiguration.background(withIdentifier: "com.example.background")

// 2. 创建 Session
let session = URLSession(configuration: config, delegate: self, delegateQueue: .main)

// 3. 创建下载任务
let task = session.downloadTask(with: url)
task.resume()

// 4. AppDelegate 中保存 completionHandler
class AppDelegate: UIResponder, UIApplicationDelegate {
    var backgroundCompletionHandler: (() -> Void)?

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        backgroundCompletionHandler = completionHandler
    }
}

// 5. 下载完成后调用
extension ViewController: URLSessionTaskDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                  let completionHandler = appDelegate.backgroundCompletionHandler else {
                return
            }
            completionHandler()
        }
    }
}
```

**断点续传**：

```swift
class DownloadManager {
    private var session: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    private var resumeData: Data?

    func startDownload(url: URL) {
        let config = URLSessionConfiguration.background(withIdentifier: "download")
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)

        if let resumeData = resumeData {
            // 恢复下载
            downloadTask = session?.downloadTask(withResumeData: resumeData)
        } else {
            // 新下载
            downloadTask = session?.downloadTask(with: url)
        }

        downloadTask?.resume()
    }

    func pauseDownload() {
        downloadTask?.cancel { resumeData in
            self.resumeData = resumeData
            self.downloadTask = nil
        }
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 移动文件到持久位置
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsURL.appendingPathComponent("downloaded_file")

        try? FileManager.default.removeItem(at: destinationURL)
        try? FileManager.default.copyItem(at: location, to: destinationURL)
    }
}
```

#### 5.1.5 URLSessionDelegate

**完整 Delegate 实现**：

```swift
class NetworkDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate {

    // MARK: - URLSessionDelegate

    // Session 完成时调用
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error {
            print("Session invalid: \(error)")
        }
    }

    // 收到服务器挑战（证书验证）
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    // MARK: - URLSessionTaskDelegate

    // Task 完成
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("Task completed with error: \(error)")
        }
    }

    // 收到响应
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    //    print("Status code: \((response as! HTTPURLResponse).statusCode)")
        completionHandler(.allow) // 允许继续接收数据
    }

    // MARK: - URLSessionDataDelegate

    // 接收数据
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // 累积数据
    }

    // MARK: - URLSessionDownloadDelegate

    // 下载进度
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        print("下载进度: \(progress * 100)%")
    }

    // 下载完成
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("下载完成，临时文件: \(location)")
    }
}
```

#### 5.1.6 AFNetworking vs Alamofire

**AFNetworking（Objective-C）**：

```objective-c
// 请求管理
AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:@"https://api.example.com"]];

// 设置请求序列化
manager.requestSerializer = [AFJSONRequestSerializer serializer];
manager.requestSerializer.timeoutInterval = 30;

// 设置响应序列化
manager.responseSerializer = [AFJSONResponseSerializer serializer];

// 发起 GET 请求
[manager GET:@"users" parameters:nil progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
    NSLog(@"Success: %@", responseObject);
} failure:^(NSURLSessionDataTask *task, NSError *error) {
    NSLog(@"Error: %@", error);
}];
```

**Alamofire（Swift）**：

```swift
import Alamofire

// 简单请求
AF.request("https://api.example.com/users")
    .validate()
    .responseJSON { response in
        switch response.result {
        case .success(let value):
            print("Success: \(value)")
        case .failure(let error):
            print("Error: \(error)")
        }
    }

// 带参数和 Headers
AF.request("https://api.example.com/users",
           method: .post,
           parameters: ["name": "John", "age": 30],
           encoding: JSONEncoding.default,
           headers: ["Authorization": "Bearer xxx"])
    .validate()
    .responseJSON { response in
        debugPrint(response)
    }

// 下载
AF.download("https://example.com/file.zip")
    .downloadProgress { progress in
        print("下载进度: \(progress.fractionCompleted * 100)%")
    }
    .validate()
    .responseJSON { response in
        if let fileURL = response.fileURL {
            print("下载完成: \(fileURL)")
        }
    }
```

### 5.2 网络层架构设计

**分层架构**：

```
┌─────────────────────────────────────┐
│      Service Layer（业务层）         │
│  UserService, ProductService, ...   │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      API Layer（接口层）             │
│  UserAPI, ProductAPI, ...           │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   Network Layer（网络层）            │
│  NetworkManager, RequestBuilder     │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   URLSession + Extension            │
└─────────────────────────────────────┘
```

**Request Builder**：

```swift
struct NetworkRequest {
    let endpoint: String
    let method: HTTPMethod
    let parameters: [String: Any]?
    let headers: [String: String]?
    let body: Data?

    enum HTTPMethod: String {
        case GET, POST, PUT, DELETE, PATCH
    }
}

protocol RequestBuilding {
    func build(request: NetworkRequest, baseURL: String) -> URLRequest
}

class RequestBuilder: RequestBuilding {
    func build(request: NetworkRequest, baseURL: String) -> URLRequest {
        guard let url = URL(string: baseURL + request.endpoint) else {
            fatalError("Invalid URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        // 添加公共 Headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("iOS/1.0", forHTTPHeaderField: "User-Agent")

        // 添加自定义 Headers
        request.headers?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // 添加 Parameters
        if let parameters = request.parameters {
            switch request.method {
            case .GET:
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                components.queryItems = parameters.map { key, value in
                    URLQueryItem(name: key, value: "\(value)")
                }
                urlRequest.url = components.url
            case .POST, .PUT, .PATCH, .DELETE:
                let body = try? JSONSerialization.data(withJSONObject: parameters, options: [])
                urlRequest.httpBody = body
            }
        }

        return urlRequest
    }
}
```

**Network Manager**：

```swift
protocol Networking {
    @discardableResult
    func request<T: Decodable>(
        _ request: NetworkRequest,
        responseType: T.Type,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) -> URLSessionDataTask?
}

class NetworkManager: Networking {
    let session: URLSession
    let requestBuilder: RequestBuilding
    let baseURL: String

    init(
        session: URLSession = .shared,
        requestBuilder: RequestBuilder = RequestBuilder(),
        baseURL: String = "https://api.example.com"
    ) {
        self.session = session
        self.requestBuilder = requestBuilder
        self.baseURL = baseURL
    }

    func request<T: Decodable>(
        _ request: NetworkRequest,
        responseType: T.Type,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) -> URLSessionDataTask? {
        let urlRequest = requestBuilder.build(request: request, baseURL: baseURL)

        let task = session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard 200...299 ~= httpResponse.statusCode else {
                completion(.failure(.httpError(httpResponse.statusCode)))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }

        task.resume()
        return task
    }
}

enum NetworkError: Error {
    case networkError(Error)
    case invalidResponse
    case httpError(Int)
    case noData
    case decodingError(Error)
}
```

**API Layer**：

```swift
protocol UserAPIType {
    func fetchUsers(completion: @escaping (Result<[User], NetworkError>) -> Void)
    func fetchUser(id: Int, completion: @escaping (Result<User, NetworkError>) -> Void)
}

class UserAPI: UserAPIType {
    let network: Networking

    init(network: Networking = NetworkManager()) {
        self.network = network
    }

    func fetchUsers(completion: @escaping (Result<[User], NetworkError>) -> Void) {
        let request = NetworkRequest(
            endpoint: "/users",
            method: .GET,
            parameters: nil,
            headers: nil,
            body: nil
        )

        network.request(request, responseType: [User].self, completion: completion)
    }

    func fetchUser(id: Int, completion: @escaping (Result<User, NetworkError>) -> Void) {
        let request = NetworkRequest(
            endpoint: "/users/\(id)",
            method: .GET,
            parameters: nil,
            headers: nil,
            body: nil
        )

        network.request(request, responseType: User.self, completion: completion)
    }
}
```

**Service Layer**：

```swift
protocol UserServiceType {
    func fetchUsers(completion: @escaping (Result<[User], Error>) -> Void)
    func fetchUser(id: Int, completion: @escaping (Result<User, Error>) -> Void)
}

class UserService: UserServiceType {
    let api: UserAPIType

    init(api: UserAPIType = UserAPI()) {
        self.api = api
    }

    func fetchUsers(completion: @escaping (Result<[User], Error>) -> Void) {
        api.fetchUsers { result in
            // 业务逻辑处理
            switch result {
            case .success(let users):
                // 缓存、过滤、排序等
                completion(.success(users))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchUser(id: Int, completion: @escaping (Result<User, Error>) -> Void) {
        api.fetchUser(id: id, completion: completion)
    }
}
```

### 5.3 高级特性

**重试机制**：

```swift
class RetryNetworkManager: Networking {
    let network: Networking
    let maxRetries: Int

    init(network: Networking, maxRetries: Int = 3) {
        self.network = network
        self.maxRetries = maxRetries
    }

    func request<T>(
        _ request: NetworkRequest,
        responseType: T.Type,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) -> URLSessionDataTask? {
        var retries = 0

        func attempt() {
            _ = network.request(request, responseType: responseType) { result in
                if case .failure(let error) = result,
                   retries < self.maxRetries,
                   self.isRetryable(error) {
                    retries += 1
                    attempt() // 重试
                } else {
                    completion(result)
                }
            }
        }

        attempt()
        return nil
    }

    private func isRetryable(_ error: NetworkError) -> Bool {
        switch error {
        case .httpError(let code):
            return 500...599 ~= code || code == 429 // 服务器错误或限流
        case .networkError:
            return true // 网络错误重试
        default:
            return false
        }
    }
}
```

**缓存策略**：

```swift
class CachedNetworkManager: Networking {
    let network: Networking
    let cache: URLCache

    init(network: Networking, cache: URLCache = .shared) {
        self.network = network
        self.cache = cache
    }

    func request<T>(
        _ request: NetworkRequest,
        responseType: T.Type,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) -> URLSessionDataTask? {
        let urlRequest = URLRequest(url: URL(string: request.endpoint)!)

        // 检查缓存
        if let cachedResponse = cache.cachedResponse(for: urlRequest) {
            do {
                let decoded = try JSONDecoder().decode(T.self, from: cachedResponse.data)
                completion(.success(decoded))
                return nil
            } catch {
                // 缓存解析失败，继续网络请求
            }
        }

        // 网络请求
        return network.request(request, responseType: responseType) { [weak self] result in
            guard let self = self else { return }

            if case .success(let data) = result,
               let jsonData = try? JSONEncoder().encode(data),
               let response = HTTPURLResponse(url: urlRequest.url!, statusCode: 200, httpVersion: nil, headerFields: nil) {
                let cachedResponse = CachedURLResponse(response: response, data: jsonData)
                self.cache.storeCachedResponse(cachedResponse, for: urlRequest)
            }

            completion(result)
        }
    }
}
```

---


---

### 7.4 iOS 网络层设计

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **如何设计一个网络层？** | 分层架构、Request Builder、Network Manager、API Layer | ⭐⭐⭐⭐ |
| **如何处理重试？** | 判断错误类型、指数退避、最大重试次数 | ⭐⭐⭐ |
| **如何实现缓存？** | URLCache、Cache-Control、ETag | ⭐⭐⭐ |
| **弱网优化策略？** | HTTPDNS、减少请求、压缩、超时重试 | ⭐⭐⭐⭐ |

---


---

## 8. 参考资料

### 优质文章
- [HTTP/2, HTTP/3, and QUIC: The Protocol Evolution](https://medium.com/@hosseinnejati/http-2-http-3-and-quic-the-protocol-evolution-that-affects-your-architecture-b28b006b20e9)
- [HTTP3 vs HTTP2: Performance Comparison](https://www.catchpoint.com/http3-vs-http2)
- [HTTP/3 vs HTTP/2: Cloudflare Performance](https://blog.cloudflare.com/http-3-vs-http-2/)
- [iOS Interview Guide: Networking Layer Design](https://medium.com/@dhruvinbhalodiya752/ios-interview-guide-how-to-build-a-scalable-networking-layer-2420324806f5)
- [Mastering API Architecture in iOS: 2026 Guide](https://www.zignuts.com/blog/mastering-api-architecture-in-ios)
- [Designing Resilient Networking Layers in Swift](https://medium.com/@shubhamsanghavi100/designing-resilient-networking-data-layers-in-swift-ios-offline-support-retry-logic-5973dd723b9d)

### 协议文档
- [RFC 9114 - HTTP/3](https://httpwg.org/specs/rfc9114.html)
- [RFC 9000 - QUIC Protocol](https://quicwg.org/base-drafts/rfc9000.html)
- [RFC 8446 - TLS 1.3](https://tlswg.org/rfc8446/)

### 开源项目
- [Alamofire](https://github.com/Alamofire/Alamofire) - Swift 网络库
- [Moya](https://github.com/Moya/Moya) - 网络层抽象

---

**最后更新**：2026-04-07
**状态**：✅ 已完成

**Sources:**
- [HTTP/2, HTTP/3, and QUIC: The Protocol Evolution](https://medium.com/@hosseinnejati/http-2-http-3-and-quic-the-protocol-evolution-that-affects-your-architecture-b28b006b20e9)
- [HTTP/3 vs HTTP/2: Cloudflare Performance](https://blog.cloudflare.com/http-3-vs-http-2/)
- [iOS Interview Guide: Networking Layer Design](https://medium.com/@dhruvinbhalodiya752/ios-interview-guide-how-to-build-a-scalable-networking-layer-2420324806f5)
- [Mastering API Architecture in iOS: 2026 Guide](https://www.zignuts.com/blog/mastering-api-architecture-in-ios)
