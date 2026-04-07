# HTTP/2 与 HTTP/3 (QUIC)

> 一句话总结：**HTTP/2 用二进制分帧与多路复用缓解应用层 HOL；HTTP/3 将传输搬到 QUIC(UDP) 上，减少 TCP 队头阻塞并支持连接迁移。**

---

## 📚 学习地图

- **预计学习时间**：30 分钟
- **前置知识**：HTTP/1.1、TLS
- **学习目标**：帧/流/QUIC 取舍 → 工程侧启示

---

### 3.2 HTTP/2

**核心改进**：

**1. 二进制分帧层**：

```
HTTP/1.1 文本格式 → HTTP/2 二进制格式
Frame：HTTP/2 最小单位
Stream：双向字节流，由多个 Frame 组成
```

**2. 多路复用**：

```
一个 TCP 连接可以并发多个 Stream
解决了 HTTP/1.1 的 HOL 阻塞
但仍受 TCP 层 HOL 阻塞影响（丢包导致整个 TCP 连接阻塞）
```

**3. 头部压缩（HPACK）**：

```
静态字典：常见头部（如 method、path）
动态字典：连接期间的头部
Huffman 编码：压缩头部值
效果：Header 大小减少 80-90%
```

**4. 服务端推送**：

```
服务器可以主动推送资源（无需请求）
示例：请求 HTML 时，服务器主动推送 CSS、JS
```

### 3.3 HTTP/3（QUIC）

**核心改进**：

**1. 基于 UDP 的 QUIC 协议**：

```
HTTP/2：TCP + TLS
HTTP/3：QUIC（UDP）+ 内置 TLS

QUIC = Quick UDP Internet Connections
```

**2. 解决 TCP 层 HOL 阻塞**：

```
HTTP/2：Stream 1 丢包 → Stream 2、3 都阻塞
HTTP/3：Stream 1 丢包 → 只影响 Stream 1，Stream 2、3 继续传输
```

**3. 0-RTT 和 1-RTT 握手**：

```
HTTP/2 + TLS 1.2：
- TCP 三次握手（1-RTT）
- TLS 握手（2-RTT）
- 总共：3-RTT

HTTP/3 + TLS 1.3：
- 首次连接：1-RTT
- 恢复连接：0-RTT（复用之前的连接参数）
- 连接建立速度提升 33%
```

**4. 连接迁移**：

```
HTTP/2：IP 或端口变化，连接断开（四元组标识）
HTTP/3：Connection ID 标识，支持网络切换（WiFi → 4G）
```

**HTTP/2 vs HTTP/3 对比**：

| 特性 | HTTP/2 | HTTP/3 |
|------|--------|--------|
| **传输层** | TCP | QUIC（UDP） |
| **连接建立** | 3-RTT | 1-RTT（首次），0-RTT（恢复） |
| **HOL 阻塞** | Stream 级（有 TCP 层阻塞） | Stream 级（无 TCP 层阻塞） |
| **网络切换** | 不支持 | 支持（连接迁移） |
| **性能** | 基准 | 快 12-33% |

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
