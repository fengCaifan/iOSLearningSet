# TCP/UDP 与 Socket

> 一句话总结：**传输层 TCP 提供可靠字节流，UDP 提供尽最大努力交付；理解握手、可靠传输与粘包拆包，是调试弱网与自定义协议的基础。**

---

## 📚 学习地图

- **预计学习时间**：45 分钟
- **前置知识**：计算机网络分层（见下）
- **学习目标**：IP/TCP/UDP 要点 → Socket 编程注意点

---

## 1. 计算机网络基础

### 1.1 网络分层模型

**OSI 7 层模型 vs TCP/IP 5 层模型**：

| OSI 7 层 | TCP/IP 5 层 | 对应协议 | 数据单位 |
|----------|-------------|----------|----------|
| 应用层 | 应用层 | HTTP、DNS、DHCP | 报文 |
| 表示层 | | (TLS/SSL) | |
| 会话层 | | | |
| 传输层 | 传输层 | TCP、UDP | 段 |
| 网络层 | 网络层 | IP、ICMP、ARP | 包 |
| 数据链路层 | 数据链路层 | Ethernet、PPP | 帧 |
| 物理层 | 物理层 | 网线、光纤 | 比特流 |

### 1.2 物理层与数据链路层

**网络设备演进**：

```
集线器（半双工）→ 网桥（隔离冲突域）→ 交换机（全双工，多接口）
路由器：隔离广播域，连接不同网段
```

**MAC 地址与 IP 地址**：

```
MAC 地址：网卡的物理地址，全球唯一，用于局域网通信
IP 地址：逻辑地址，用于跨网段通信
子网掩码：网络 ID = IP & 子网掩码
```

**ARP 协议**：

```
作用：通过 IP 地址查询 MAC 地址
过程：广播询问 "谁是 192.168.1.1？" → 目标回复 "我是，MAC 是 xx:xx:xx:xx:xx:xx"
```

### 1.3 网络层（IP 层）

**IP 首部字段**：

```c
struct IPHeader {
    uint8_t version;        // IPv4/IPv6
    uint8_t headerLength;   // 首部长度（20-60 字节）
    uint8_t tos;            // 服务质量
    uint16_t totalLength;   // 总长度
    uint16_t identification;// 标识（分片用）
    uint16_t flags;         // 标志（是否允许分片）
    uint16_t fragmentOffset;// 片偏移
    uint8_t ttl;            // 生存时间（经过路由器数量）
    uint8_t protocol;       // 上层协议（TCP=6, UDP=17）
    uint16_t checksum;      // 首部校验和
    uint32_t srcIP;         // 源 IP
    uint32_t destIP;        // 目的 IP
};
```

**分片**：

```
MTU（Maximum Transmission Unit）= 1500 字节
超过 MTU 的数据包需要分片
每片都有独立的 IP 首部
通过 identification + fragmentOffset 重组
```

---

## 2. 传输层（TCP/UDP）

### 2.1 TCP vs UDP 对比

| 特性 | TCP | UDP |
|------|-----|-----|
| **连接性** | 面向连接 | 无连接 |
| **可靠性** | 可靠传输，不丢包 | 尽最大努力交付，可能丢包 |
| **首部开销** | 20-60 字节 | 8 字节 |
| **传输速度** | 慢 | 快 |
| **资源消耗** | 高 | 低 |
| **应用场景** | HTTP、FTP、SMTP | 音视频通话、直播、DNS |
| **流量控制** | 有（滑动窗口） | 无 |
| **拥塞控制** | 有 | 无 |

### 2.2 TCP 三次握手

**流程**：

```
客户端 → 服务器：SYN=1, seq=x
服务器 → 客户端：SYN=1, ACK=1, seq=y, ack=x+1
客户端 → 服务器：ACK=1, seq=x+1, ack=y+1
```

**为什么需要三次握手？**

```
防止失效的连接请求报文段突然又传送到服务器

如果只有两次：
1. 客户端发送连接请求 A（但滞留在网络中）
2. 客户端超时重传连接请求 B，建立连接
3. 连接结束后，失效的请求 A 到达服务器
4. 服务器误认为是新连接，建立连接（错误！）
```

**第三次握手失败会怎样？**

```
服务器发送 SYN+ACK 后进入 SYN_RCVD 状态
如果收不到 ACK，会重传 SYN+ACK（默认 5 次）
超过重传次数后，发送 RST 强制关闭连接
```

### 2.3 TCP 四次挥手

**流程**：

```
客户端 → 服务器：FIN=1, seq=u
服务器 → 客户端：ACK=1, seq=v, ack=u+1
（半关闭状态：客户端→服务器方向关闭）
服务器 → 客户端：FIN=1, ACK=1, seq=w, ack=u+1
客户端 → 服务器：ACK=1, seq=u+1, ack=w+1
```

**为什么需要四次？**

```
TCP 是全双工协议：
1. 客户端说："我发完了数据"（FIN）
2. 服务器说："好的，我知道了"（ACK）
3. 服务器说："我数据也发完了"（FIN）
4. 客户端说："好的，拜拜"（ACK）

有时 2、3 步合并，变成三次挥手
```

### 2.4 TCP 可靠传输

**ARQ 协议 + 滑动窗口**：

```
停止等待 ARQ：
- 发送一个包，等待 ACK
- 超时未收到 ACK，重传
- 问题：效率低

连续 ARQ + 滑动窗口：
- 发送窗口：连续发送多个包
- 接收窗口：接收后返回 ACK（累积确认）
- 超时重传：只重传丢失的包（SACK 选择性确认）
```

**流量控制**：

```
目的：防止发送方发送过快，接收方来不及处理
实现：滑动窗口大小 = 接收方窗口大小（rwnd）
过程：
1. 接收方在 ACK 中告知窗口大小
2. 发送方根据窗口调整发送速率
3. 窗口为 0 时，发送方停止发送，定时探测
```

**拥塞控制**：

```
目的：防止过多数据注入网络，导致路由器过载
发送窗口 = min(接收窗口 rwnd, 拥塞窗口 cwnd)

四个阶段：
1. 慢开始：cwnd 从 1 开始，指数增长（1→2→4→8...）
2. 拥塞避免：到达阈值 ssthresh 后，线性增长
3. 快重传：收到 3 个重复 ACK，立即重传
4. 快恢复：cwnd 减半，进入拥塞避免
```

**现代拥塞控制算法**：

```
BBR（Bottleneck Bandwidth and RTT）：
- Google 开源，2016 年
- 不基于丢包判断拥塞（主动测量带宽和 RTT）
- 适合高延迟、高丢包场景
- YouTube、Google 搜索已使用
```

---


---

### 7.1 TCP/UDP

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **TCP 和 UDP 的区别？** | 连接性、可靠性、速度、应用场景 | ⭐⭐ |
| **为什么三次握手？两次不行吗？** | 防止失效的连接请求 | ⭐⭐⭐ |
| **TIME_WAIT 状态的作用？** | 确保最后一个 ACK 到达，等待 2MSL | ⭐⭐⭐⭐ |
| **TCP 如何保证可靠传输？** | ARQ、滑动窗口、超时重传、SACK | ⭐⭐⭐ |
| **什么是拥塞控制？如何实现？** | 慢开始、拥塞避免、快重传、快恢复 | ⭐⭐⭐⭐ |


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
