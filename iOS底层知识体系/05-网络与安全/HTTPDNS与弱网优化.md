# HTTPDNS 与弱网优化

> 一句话总结：**HTTPDNS 与弱网策略（重试、合并、压缩、监控）把「能连上」变成「在烂网里也能尽量可用」。**

---

## 📚 学习地图

- **预计学习时间**：70 分钟
- **前置知识**：计算机网络基础
- **学习目标**：理解 TCP/IP → 掌握 HTTP 协议演进 → 设计网络层架构 → 性能优化

---

## 6. 性能优化

### 6.1 HTTPDNS

**问题**：

```
传统 DNS：
1. 慢：多次递归查询，延迟高（100-300ms）
2. 不准确：LocalDNS 可能缓存过期
3. 劫持：运营商劫持 DNS，返回错误 IP
```

**HTTPDNS 方案**：

```
使用 HTTP 协议查询 DNS：
1. 直接访问 HTTPDNS 服务器（如阿里、腾讯）
2. 返回最优 IP（根据客户端 IP、运营商、地理位置）
3. 绕过 LocalDNS，避免劫持
```

**实现**：

```swift
class HTTPDNSResolver {
    func resolve(domain: String) -> String? {
        let urlString = "http://httpdns.server/resolve?domain=\(domain)"
        guard let url = URL(string: urlString),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ips = json["ips"] as? [String],
              let ip = ips.first else {
            return nil
        }

        return ip
    }
}

// 使用
let resolver = HTTPDNSResolver()
if let ip = resolver.resolve(domain: "api.example.com") {
    var components = URLComponents(string: "https://api.example.com/users")!
    components.host = ip
    // 使用 ip 替代域名发起请求
}
```

### 6.2 弱网优化

**策略**：

**1. 减少请求数量**：

```
- 合并 API（GraphQL、Batch API）
- 本地缓存（减少重复请求）
- 预加载（预测用户行为）
```

**2. 减少数据传输量**：

```
- Gzip 压缩（HTTP Header: Accept-Encoding: gzip）
- Protocol Buffers（替代 JSON）
- 图片压缩、WebP 格式
- 分页加载
```

**3. 超时与重试**：

```swift
var request = URLRequest(url: url)
request.timeoutInterval = 15 // 弱网环境缩短超时时间
request.networkServiceType = .background // 降低优先级

// 指数退避重试
func retryWithBackoff(attempt: Int) {
    let delay = pow(2.0, Double(attempt)) // 1s, 2s, 4s, 8s...
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        // 重试请求
    }
}
```

**4. 连接复用**：

```swift
let configuration = URLSessionConfiguration.default
configuration.httpMaximumConnectionsPerHost = 6 // 增加最大连接数
configuration.requestCachePolicy = .returnCacheDataElseLoad // 优先使用缓存
let session = URLSession(configuration: configuration)
```

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
