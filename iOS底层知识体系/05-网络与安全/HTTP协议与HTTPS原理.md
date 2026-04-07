# HTTP 协议与 HTTPS 原理

> 一句话总结：**HTTP 定义报文语义与缓存；HTTPS 在 TLS 上封装 HTTP，依靠证书链与握手建立可信加密通道。**

---

## 📚 学习地图

- **预计学习时间**：50 分钟
- **前置知识**：TCP
- **学习目标**：HTTP/1.1 特性 → TLS 握手 → 常见攻击面

---

### 3.1 HTTP/1.0 vs HTTP/1.1

| 特性 | HTTP/1.0 | HTTP/1.1 |
|------|---------|----------|
| **连接** | 每次请求新建 TCP | 持久连接（Keep-Alive） |
| **管道化** | ❌ 不支持 | ✅ 支持（但有 HOL 阻塞） |
| **Host 头** | ❌ 不必需 | ✅ 必需（虚拟主机） |
| **断点续传** | ❌ 不支持 | ✅ 支持（Range 头） |

**HTTP/1.1 的性能问题**：

```
1. 队头阻塞（Head-of-Line Blocking）：
   - 管道化中，前面的请求慢，后面的请求被阻塞

2. 文本协议：
   - 解析效率低
   - Header 携带大量重复数据（Cookie、User-Agent）

3. 无法多路复用：
   - 一个 TCP 连接同时只能处理一个请求
```
## 4. HTTPS 与安全

### 4.1 HTTP 的安全问题

**四大安全威胁**：

```
1. 截获（被动）：窃听通信内容
2. 中断（主动）：中断网络通信
3. 篡改（主动）：篡改通信内容
4. 伪造（主动）：伪造通信内容
```

### 4.2 加密方式

**对称加密**：

```
特点：加密和解密使用同一个密钥
算法：DES、AES
优点：速度快
缺点：密钥传输不安全
```

**非对称加密**：

```
特点：公钥加密，私钥解密
算法：RSA、ECC
优点：密钥传输安全
缺点：速度慢
```

**混合加密（HTTPS 采用）**：

```
1. 使用非对称加密传输对称密钥
2. 使用对称加密传输数据
```

### 4.3 HTTPS 握手流程（TLS 1.2）

```
1. ClientHello：
   - 支持的加密套件
   - 随机数 Random1

2. ServerHello + Certificate + ServerKeyExchange：
   - 选择的加密套件
   - 随机数 Random2
   - 服务器证书（包含公钥）
   - 签名

3. 客户端验证证书：
   - 证书链验证：叶子证书 → 中间证书 → 根证书
   - 有效性验证：过期时间、吊销状态
   - 域名验证：证书域名是否匹配访问域名

4. ClientKeyExchange + ChangeCipherSpec + Finished：
   - 生成预主密钥（Pre-master Secret）
   - 用服务器公钥加密预主密钥
   - 发送 ChangeCipherSpec（后续消息都加密）

5. 计算主密钥：
   - 主密钥 = PRF(预主密钥, Random1, Random2)
   - 生成对称密钥（用于加密数据）

6. 服务器 ChangeCipherSpec + Finished
```

### 4.4 TLS 1.3 改进

**1. 握手简化**：

```
TLS 1.2：2-RTT 握手
TLS 1.3：1-RTT 握手，0-RTT 恢复
```

**2. 移除不安全算法**：

```
- 移除 RSA 密钥交换（不支持前向保密）
- 移除 CBC 模式、MD5、SHA-1
- 只支持 AEAD（AES-GCM、ChaCha20-Poly1305）
```

**3. 会话恢复**：

```
PSK（Pre-Shared Key）：
- 首次连接后保存会话票据
- 下次连接直接使用 PSK，实现 0-RTT
```

### 4.5 中间人攻击

**原理**：

```
客户端 ← 攻击者 → 服务器
（攻击者拦截并篡改通信）
```

**HTTPS 如何防范**：

```
1. 证书验证：
   - 客户端验证服务器证书
   - 证书由 CA（Certificate Authority）签名
   - 攻击者无法伪造 CA 签名的证书

2. 公钥 pinning（SSL Pinning）：
   - App 内置服务器证书或公钥
   - 只信任特定证书，防止 CA 被攻破
```

---


---

### 7.2 HTTP 协议

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **HTTP/1.1 vs HTTP/2 的区别？** | 二进制分帧、多路复用、HPACK、服务端推送 | ⭐⭐⭐⭐ |
| **HTTP/2 vs HTTP/3 的区别？** | TCP vs QUIC（UDP）、HOL 阻塞、连接迁移 | ⭐⭐⭐⭐⭐ |
| **GET 和 POST 的区别？** | 参数位置、缓存、幂等性、安全性 | ⭐⭐⭐ |
| **HTTP 状态码：301 vs 302？** | 301 永久重定向，302 临时重定向 | ⭐⭐⭐ |
| **HTTP 和 HTTPS 的区别？** | 加密、端口、证书、性能 | ⭐⭐⭐ |

### 7.3 HTTPS 与安全

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **HTTPS 握手流程？** | ClientHello → ServerHello + Certificate → ClientKeyExchange | ⭐⭐⭐⭐ |
| **为什么用混合加密？** | 对称加密速度快，非对称加密安全 | ⭐⭐⭐ |
| **中间人攻击是什么？如何防范？** | 拦截通信，HTTPS 通过证书验证防范 | ⭐⭐⭐⭐ |
| **SSL Pinning 的原理？** | App 内置证书，只信任特定证书 | ⭐⭐⭐ |


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
