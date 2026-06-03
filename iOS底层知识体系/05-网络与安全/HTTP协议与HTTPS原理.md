# HTTP 协议与 HTTPS 原理

> 一句话总结：**HTTP 定义报文语义与缓存；HTTPS 在 TLS 上封装 HTTP，依靠证书链与握手建立可信加密通道。**

---

## 📚 学习地图

- **预计学习时间**：50 分钟
- **前置知识**：TCP
- **学习目标**：HTTP/1.1 特性 → TLS 握手 → 常见攻击面

---

## 2. 加密解密基础（理解HTTPS的前提）

### 2.1 对称加密

**特点：** 加密和解密使用同一个密钥

```
优点：速度快
缺点：密钥传输不安全
```

**常见算法：**
- **DES**：密钥长度56位，已不安全
- **3DES**：DES重复3次，性能和安全性都不理想
- **AES**：目前最安全的对称加密算法，推荐使用

### 2.2 非对称加密

**特点：** 加密和解密使用不同的密钥

```
公钥：公开，用于加密
私钥：保密，用于解密

优点：密钥传输安全
缺点：速度慢
```

**常见算法：**
- **RSA**：应用最广泛的非对称加密算法
- **ECC**：椭圆曲线加密，更高效的算法

**密钥配送问题的解决方案：**

```
1. 事先共享密钥
2. 密钥分配中心（KDC）
3. Diffie-Hellman密钥交换
```

### 2.3 单向散列函数

**特点：** 根据任意长度的消息计算出固定长度的散列值

```
优点：
- 计算速度快
- 内容不同，散列值也不同（防篡改）
- 单向性，无法从散列值推算原值

常见算法：
- MD5：128位散列值，已不安全
- SHA-1：160位散列值，已不安全
- SHA-2：SHA-256/384/512，目前安全
```

**应用场景：**
- 防止数据被篡改
- 口令密码的加密
- 数字签名

### 2.4 数字签名

**作用：** 验证消息的真实性和完整性

```
关键区别：
非对称加密：公私钥由接收者生成，用于机密性
数字签名：公私钥由发送者生成，用于真实性
```

**数字签名过程：**

```
1. 发送者对消息进行单向散列
2. 用发送者的私钥对散列值加密（签名）
3. 接收者用发送者的公钥解密签名
4. 接收者对消息进行同样的散列
5. 对比两个散列值，验证真实性
```

**数字签名无法解决的问题：**
- 不能保证消息的机密性
- 公钥的合法性无法保证（中间人攻击）

### 2.5 混合密码系统

**HTTPS采用的方案：**

```
结合对称加密和非对称加密的优势：

1. 使用非对称加密传输对称密钥（解决密钥配送问题）
2. 使用对称加密传输数据（解决速度问题）
```

**混合加密流程（简化版）：**

```
Alice >>>>>>> Bob

加密过程：
1. Bob生成公钥和私钥
2. Bob将公钥发送给Alice
3. Alice生成随机会话密钥（临时密钥）
4. Alice用会话密钥加密消息（对称加密）
5. Alice用Bob的公钥加密会话密钥（非对称加密）
6. Alice发送加密的消息和加密的会话密钥

解密过程：
1. Bob用私钥解密会话密钥
2. Bob用会话密钥解密消息
```

### 2.6 证书的作用

**核心作用：** 解决数字签名中公钥合法性的问题

```
证书包含：
- 个人信息（姓名、邮箱等）
- 公钥
- CA的数字签名

验证过程：
1. 接收者生成公私钥对，将公钥提交给CA
2. CA用自己的私钥对公钥进行签名，生成证书
3. 发送者从CA下载证书
4. 发送者用CA的公钥验证证书
5. 验证通过后，使用证书中的公钥加密消息
```

**证书链验证：**

```
叶子证书 → 中间证书 → 根证书
每个证书都由上一级CA签名验证
```

---

## 3. HTTP 演进历史

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
