# HTTPDNS 与弱网优化

> 一句话总结：**HTTPDNS 绕过运营商 DNS 劫持；弱网优化通过减少请求、压缩数据、智能重试、连接复用把"能连上"变成"在烂网里也能用"。**

---

## 1. DNS 解析基础

### 1.1 DNS 解析过程

DNS 服务器提供域名到 IP 地址的解析服务。因为计算机更适合理解纯数字（IP），而人类适合使用域名（如 www.baidu.com）。

```
DNS 解析查询方式：

1. 递归查询：
   客户端 → 本地 DNS → 根域 DNS → 顶级 DNS → 权限 DNS
   层层递归，最终返回 IP

2. 迭代查询：
   本地 DNS 依次询问根域 DNS、顶级 DNS、权限 DNS
   每次只返回"你去问谁"

DNS 缓存层级（查询优先级）：
   浏览器缓存 → 操作系统缓存 → 路由器缓存 → ISP 本地 DNS 缓存 → 递归查询
```

### 1.2 DNS 的问题

```
传统 DNS（UDP 明文，53 端口）存在三大问题：

1. 慢：多次递归查询，延迟高（100-300ms）
2. 不准确：LocalDNS 可能缓存过期或跨网解析
3. 劫持：运营商劫持 DNS，返回错误 IP（广告、钓鱼）
```

**DNS 劫持的具体表现：**
- 访问正常网站时弹出运营商广告页
- 返回错误的 IP 地址，导致请求失败或被重定向
- HTTPS 不受 DNS 劫持影响（证书验证会失败），但 HTTP 完全暴露

**DNS 解析转发问题：**
- DNS 服务器为节省资源，将解析请求转发给其他 DNS 域名服务器
- 最后返回的 IP 可能不是同一运营商的网络，导致跨网访问
- 表现为：DNS 解析成功，但实际访问很慢（走了跨运营商线路）

---

## 2. HTTPDNS

### 2.1 原理

```
传统 DNS：使用 DNS 协议（UDP 53 端口）向 LocalDNS 查询
HTTPDNS：使用 HTTP 协议（TCP 80/443 端口）向 HTTPDNS 服务器查询

本质：绕过运营商 LocalDNS，直接通过 HTTP 请求获取 IP

优势：
1. 绕过劫持：不走 UDP 53 端口，运营商无法劫持
2. 更精准：HTTPDNS 服务器能根据客户端真实 IP、运营商、地理位置返回最优 IP
3. 更快：省去递归查询，直接返回；且可以做更激进的缓存策略
4. 更灵活：可以配合负载均衡、容灾切换
```

### 2.2 实现方案

```swift
// 简化版 HTTPDNS 解析器
class HTTPDNSResolver {
    // 本地缓存（domain → IP + 过期时间）
    private var cache: [String: (ip: String, expireTime: Date)] = [:]
    
    func resolve(domain: String) -> String? {
        // 1. 先查本地缓存
        if let cached = cache[domain], cached.expireTime > Date() {
            return cached.ip
        }
        
        // 2. 缓存未命中，请求 HTTPDNS 服务器
        // 阿里云 HTTPDNS: http://203.107.1.1/{accountId}/resolve?host=xxx
        // 腾讯云 HTTPDNS: http://119.29.29.98/d?dn=xxx&ip=clientIp
        let urlString = "http://119.29.29.98/d?dn=\(domain)"
        guard let url = URL(string: urlString),
              let data = try? Data(contentsOf: url),  // 实际应异步
              let ipString = String(data: data, encoding: .utf8),
              !ipString.isEmpty else {
            return nil  // 降级到系统 DNS
        }
        
        // 3. 缓存结果（TTL 通常 300s）
        cache[domain] = (ip: ipString, expireTime: Date().addingTimeInterval(300))
        return ipString
    }
}
```

### 2.3 HTTPDNS 接入注意事项

```
1. SNI（Server Name Indication）问题：
   使用 IP 直连时，HTTPS 握手中的 SNI 字段是 IP 而非域名
   服务器可能返回错误的证书
   解决：手动设置 HTTP Header 的 Host 字段 + 自定义证书验证

2. 缓存策略：
   - 预解析：App 启动时提前解析高频域名
   - 本地缓存 + TTL：命中缓存直接用，过期后异步更新
   - 降级：HTTPDNS 请求超时，降级到系统 DNS

3. Cookie 和 WebView 问题：
   IP 直连后 Cookie 可能匹配不上（Cookie 绑定域名）
   WebView 中需要特殊处理（拦截请求替换域名）

4. 容灾：
   HTTPDNS 服务不可用时，必须有系统 DNS 兜底
   多个 HTTPDNS 服务可以做主备
```

---

## 3. 弱网优化

### 3.1 网络质量分级

```
网络状态分级（移动端常见）：

优质网络：RTT < 100ms，丢包率 < 1%（WiFi、4G 信号满格）
一般网络：100ms < RTT < 300ms，丢包率 1-5%（4G 信号一般）
弱网络：  300ms < RTT < 1000ms，丢包率 5-15%（3G、地铁、电梯）
极弱网络：RTT > 1000ms 或频繁超时（2G、信号极差）

监控指标：
- RTT（往返延迟）
- 丢包率
- 带宽
- 连接成功率
- 首包时间
```

### 3.2 减少请求数量

```
1. 合并 API：
   - 一个页面需要 5 个接口 → 合并成 1 个聚合接口
   - GraphQL：客户端指定需要的字段，一次请求获取所有数据

2. 本地缓存：
   - 有缓存先展示缓存，后台刷新后更新
   - 离线数据（如配置项）本地持久化

3. 预加载：
   - 预测用户行为，提前请求下一页数据
   - 首屏数据随配置下发

4. 增量更新：
   - 不请求全量数据，只请求变化的部分（如 ETag / If-Modified-Since）
```

### 3.3 减少数据传输量

```
1. 数据压缩：
   - HTTP Header: Accept-Encoding: gzip
   - 服务端 Response: Content-Encoding: gzip（减少 60-80%）

2. 高效序列化：
   - Protocol Buffers 替代 JSON（减少 30-50% 体积 + 更快解析）
   - 场景：高频接口、大数据量接口

3. 图片优化：
   - WebP 格式（比 PNG 小 30%，比 JPEG 小 25%）
   - 按屏幕尺寸请求对应 size 的图片（CDN 裁剪）
   - 渐进式 JPEG（先加载模糊轮廓，再加载细节）

4. 分页加载：
   - 列表数据分页，按需加载
   - 图片懒加载（可见时才请求）
```

### 3.4 超时与重试策略

```swift
// 动态超时：根据网络质量调整
func timeoutInterval(for networkQuality: NetworkQuality) -> TimeInterval {
    switch networkQuality {
    case .excellent: return 10
    case .good:     return 15
    case .weak:     return 20
    case .veryWeak: return 30
    }
}

// 指数退避重试
func retryWithExponentialBackoff(attempt: Int, maxAttempts: Int = 3) {
    guard attempt < maxAttempts else {
        // 达到最大重试次数，报错
        return
    }
    let delay = pow(2.0, Double(attempt))  // 1s, 2s, 4s
    let jitter = Double.random(in: 0...0.5) // 随机抖动，避免同时重试
    DispatchQueue.main.asyncAfter(deadline: .now() + delay + jitter) {
        // 重试请求
    }
}

// 重试策略要点：
// 1. 只重试幂等请求（GET、HEAD）或明确安全的请求
// 2. 非幂等请求（POST 支付）不能随便重试
// 3. 服务器返回 429 (Too Many Requests) 或 503 时尊重 Retry-After
// 4. 弱网下适当增加超时时间，减少无意义的超时重试
```

### 3.5 连接优化

```swift
// URLSession 连接优化配置
let config = URLSessionConfiguration.default
config.httpMaximumConnectionsPerHost = 4        // 每个 Host 最大连接数
config.timeoutIntervalForRequest = 15           // 请求超时
config.timeoutIntervalForResource = 60          // 资源总超时
config.waitsForConnectivity = true              // iOS 11+ 等待网络可用再发
config.requestCachePolicy = .returnCacheDataElseLoad  // 优先缓存

// HTTP/2 下一个连接就够了（多路复用）
// 但需要确保服务器支持 HTTP/2
```

### 3.6 弱网监控

```swift
// 使用 NWPathMonitor（iOS 12+）监控网络状态
import Network

let monitor = NWPathMonitor()
monitor.pathUpdateHandler = { path in
    if path.status == .satisfied {
        if path.usesInterfaceType(.wifi) {
            // WiFi
        } else if path.usesInterfaceType(.cellular) {
            // 蜂窝
        }
    } else {
        // 无网络
    }
    // path.isExpensive — 是否计费网络
    // path.isConstrained — 是否低数据模式
}
monitor.start(queue: DispatchQueue.global())

// 结合 URLSessionTaskMetrics 统计网络质量
func urlSession(_ session: URLSession, task: URLSessionTask,
                didFinishCollecting metrics: URLSessionTaskMetrics) {
    for metric in metrics.transactionMetrics {
        let dns = metric.domainLookupEndDate?.timeIntervalSince(metric.domainLookupStartDate ?? Date()) ?? 0
        let connect = metric.connectEndDate?.timeIntervalSince(metric.connectStartDate ?? Date()) ?? 0
        let ttfb = metric.responseStartDate?.timeIntervalSince(metric.requestStartDate ?? Date()) ?? 0
        // 上报 DNS 耗时、连接耗时、首包时间
    }
}
```

---

## 4. 面试高频问题

| 问题 | 答案要点 |
|------|----------|
| **什么是 DNS 劫持？怎么解决？** | 运营商劫持 UDP 53 端口返回错误 IP；HTTPDNS 通过 HTTP 协议绕过 |
| **HTTPDNS 的原理？** | 用 HTTP 协议（80/443端口）直接向 HTTPDNS 服务器请求 IP，绕过 LocalDNS |
| **HTTPDNS 有什么坑？** | SNI 问题（HTTPS 证书校验）、Cookie 域名匹配、WebView 拦截 |
| **弱网优化怎么做？** | 减少请求数、压缩数据、智能重试（指数退避）、连接复用、离线缓存 |
| **重试策略怎么设计？** | 指数退避 + 随机抖动 + 最大次数限制 + 只重试幂等请求 |
| **怎么监控网络质量？** | NWPathMonitor + URLSessionTaskMetrics（DNS/连接/首包耗时） |

---

**最后更新**：2025-01-27
