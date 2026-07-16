# HTTP/2 与 HTTP/3 (QUIC)

> 一句话总结：**HTTP/2 用二进制分帧与多路复用缓解应用层 HOL；HTTP/3 将传输搬到 QUIC(UDP) 上，彻底解决 TCP 队头阻塞并支持连接迁移。**

---

## 1. HTTP/1.1 的核心问题（为什么需要 HTTP/2）

HTTP/1.1 采用持久连接（keep-alive），多个请求可以共用一个 TCP 连接，但仍存在三大性能瓶颈：

**① 队头阻塞（Head-of-Line Blocking）**
- 管道化中，前面的请求响应慢，后面的请求被阻塞
- 浏览器只能通过开多个 TCP 连接（通常 6 个）来缓解

**② 文本协议**
- 解析效率低
- Header 携带大量重复数据（Cookie、User-Agent 每次都完整发送）

**③ 无法真正多路复用**
- 一个 TCP 连接同一时间只能处理一个请求-响应对
- 虽然有 keep-alive，但请求仍然是串行的

---

## 2. HTTP/2 核心改进

### 2.1 二进制分帧层

```
HTTP/1.1：纯文本格式，用换行符分隔
HTTP/2：二进制格式，最小传输单位是 Frame（帧）

Frame 结构：
┌─────────────────────────────────┐
│ Length (24bit) │ Type (8bit)    │
├─────────────────────────────────┤
│ Flags (8bit) │ Stream ID (31bit)│
├─────────────────────────────────┤
│           Payload               │
└─────────────────────────────────┘

Frame Type：
- HEADERS：请求/响应头
- DATA：请求/响应体
- SETTINGS：连接配置
- WINDOW_UPDATE：流量控制
- PUSH_PROMISE：服务端推送预告

Stream（流）：
- 一个双向字节流，由多个 Frame 组成
- 每个 Stream 有唯一 ID
- 多个 Stream 共享一个 TCP 连接
```

### 2.2 多路复用（Multiplexing）

```
HTTP/1.1：
  连接1: 请求A ──────── 响应A
  连接2: 请求B ──────── 响应B
  连接3: 请求C ──────── 响应C
  （需要多个 TCP 连接）

HTTP/2：
  一个 TCP 连接：
    Stream 1: [HEADERS帧] [DATA帧] [DATA帧]
    Stream 3: [HEADERS帧] [DATA帧]
    Stream 5: [HEADERS帧] [DATA帧] [DATA帧] [DATA帧]
  （帧可以交叉发送，接收端按 Stream ID 重组）

关键：
- 一个 TCP 连接并发数百个 Stream
- 解决了 HTTP/1.1 应用层的 HOL 阻塞
- 但仍受 TCP 层 HOL 阻塞影响（一个包丢失 → 整个 TCP 窗口阻塞）
```

### 2.3 头部压缩（HPACK）

```
HPACK 方案：
1. 静态字典（61 个常见 Header）
   Index 2 = ":method: GET"
   Index 3 = ":method: POST"
   Index 8 = ":status: 200"
   → 只需发送 index 号

2. 动态字典（连接级别）
   首次出现的 Header 加入动态字典
   后续请求只发 index 号

3. Huffman 编码
   对 Header 值做 Huffman 压缩

效果：Header 大小减少 80-90%
```

### 2.4 服务端推送（Server Push）

- 服务器可以主动推送资源（无需客户端请求）
- 示例：请求 HTML 时，服务器主动推送 CSS、JS
- 客户端可以发送 RST_STREAM 拒绝推送
- 实际使用率不高，很多 CDN 已禁用

### 2.5 HTTP/2 仍存在的问题

```
TCP 层队头阻塞（这是 HTTP/3 出现的根本原因）：

HTTP/2 多个 Stream 共享一个 TCP 连接
TCP 保证有序交付 → 一个 TCP 包丢失 → 后续所有包必须等待重传
即使后续包属于不同的 Stream，也被阻塞

示意：
  Stream 1: [包1] [包2-丢失] [包3]
  Stream 2: [包4] [包5]
  Stream 3: [包6]
  
  TCP 层：包2 丢失 → 包3、4、5、6 全部阻塞等待包2 重传
  结果：Stream 2、3 被无辜阻塞

在高丢包网络（如移动网络）下，HTTP/2 可能比 HTTP/1.1 更慢
（因为 HTTP/1.1 至少开了 6 个 TCP 连接，一个阻塞不影响其他）
```

---

## 3. HTTP/3（QUIC）

### 3.1 QUIC 是什么

```
QUIC = Quick UDP Internet Connections（Google 2012 年提出，2021 年 RFC 9000）

本质：在 UDP 之上重新实现了 TCP 的可靠传输 + TLS 加密 + HTTP/2 的多路复用

协议栈对比：
  HTTP/2：  HTTP/2  →  TLS 1.2/1.3  →  TCP  →  IP
  HTTP/3：  HTTP/3  →  QUIC（含 TLS 1.3）→  UDP  →  IP

为什么基于 UDP？
- TCP 是操作系统内核实现的，修改和部署周期极长
- UDP 足够简单（无连接、无状态），QUIC 在用户态实现所有功能
- 中间设备（NAT、防火墙）普遍支持 UDP
```

### 3.2 QUIC 核心改进

**① 彻底解决 HOL 阻塞**

```
QUIC 的 Stream 之间完全独立：

Stream 1: [包1] [包2-丢失] [包3]  → 只有 Stream 1 等待重传
Stream 2: [包4] [包5]             → 正常传输，不受影响
Stream 3: [包6]                   → 正常传输，不受影响

原理：每个 Stream 有独立的重传和顺序控制
丢包只影响所属 Stream，不阻塞其他 Stream
```

**② 更快的连接建立（1-RTT / 0-RTT）**

```
HTTP/2 + TLS 1.2 首次连接：
  TCP 三次握手（1-RTT）+ TLS 握手（2-RTT）= 3-RTT

HTTP/3 + QUIC 首次连接：
  QUIC 握手（含 TLS）= 1-RTT

QUIC 恢复连接（0-RTT）：
  客户端缓存了上次连接参数，第一个包就可以携带 HTTP 请求数据
```

**③ 连接迁移（Connection Migration）**

```
TCP 连接标识 = {源 IP, 源端口, 目标 IP, 目标端口}（四元组）
→ 网络切换（WiFi → 4G）→ IP 变了 → TCP 连接断开 → 重新三次握手

QUIC 连接标识 = Connection ID（64 位随机数）
→ 网络切换 → IP 变了 → Connection ID 不变 → 连接继续

典型场景：用户从 WiFi 走到电梯切换到 4G
- HTTP/2：所有请求中断，等待重连
- HTTP/3：无缝切换，请求不中断
```

**④ QUIC 的丢包恢复机制**

```
1. 独立包号（Packet Number）：
   每个包有唯一递增的包号，不复用
   解决了 TCP 的重传歧义问题

2. SACK + NACK：
   接收方明确告诉发送方"哪些包收到了、哪些没收到"
   发送方精确重传丢失的包

3. 更精确的 RTT 测量：
   独立包号使得 RTT 计算无歧义
   更准确的超时重传时间
```

**⑤ 0-RTT 的安全风险**

```
0-RTT 数据可能被重放攻击（Replay Attack）

缓解措施：
- 0-RTT 只用于幂等请求（GET 查询）
- 写操作（POST/PUT/DELETE）必须等 1-RTT 完成后再发
- 服务器维护"已使用票据"列表
```

---

## 4. 总结对比

| 特性 | HTTP/1.1 | HTTP/2 | HTTP/3 |
|------|----------|--------|--------|
| **传输层** | TCP | TCP | QUIC（UDP） |
| **连接建立** | 1-RTT（TCP）+ 2-RTT（TLS） | 同左 | 1-RTT / 0-RTT |
| **多路复用** | ❌（需多连接） | ✅（共享 TCP） | ✅（独立 Stream） |
| **HOL 阻塞** | 连接级 | TCP 层仍有 | ✅ 彻底解决 |
| **头部压缩** | ❌ | HPACK | QPACK |
| **连接迁移** | ❌ | ❌ | ✅（Connection ID） |
| **加密** | 可选（HTTPS） | 可选 | 强制（TLS 1.3） |

---

## 5. iOS 工程侧

**HTTP/2（iOS 9+ 默认支持）**：URLSession 自动协商，无需配置。

**HTTP/3（iOS 15+ 支持）**：
```swift
let config = URLSessionConfiguration.default
config.assumesHTTP3Capable = true  // iOS 15+
// URLSession 自动尝试 HTTP/3，失败则降级到 HTTP/2
```

**工程注意事项**：
- HTTP/2 时代不再需要域名分片、雪碧图等 HTTP/1.1 优化手段
- 中国大陆环境下 UDP 可能被 QoS 限制，HTTP/3 不一定比 HTTP/2 快
- URLSession 会自动降级：HTTP/3 → HTTP/2 → HTTP/1.1

---

## 6. 面试高频问题

| 问题 | 答案要点 |
|------|----------|
| **HTTP/2 相比 HTTP/1.1 有什么改进？** | 二进制分帧、多路复用、HPACK 头部压缩、服务端推送 |
| **HTTP/2 多路复用怎么实现的？** | 一个 TCP 连接多个 Stream，帧交叉发送按 Stream ID 重组 |
| **HTTP/2 还有什么问题？** | TCP 层 HOL 阻塞：一个包丢失整个连接阻塞 |
| **HTTP/3 为什么基于 UDP？** | TCP 改不动（内核实现）；UDP 简单，QUIC 在用户态实现可靠传输 |
| **QUIC 怎么解决 HOL 阻塞？** | Stream 之间完全独立，丢包只影响所属 Stream |
| **什么是连接迁移？** | Connection ID 替代四元组标识连接，网络切换不断开 |
| **0-RTT 有什么风险？** | 重放攻击，只能用于幂等请求 |

---

**最后更新**：2025-01-27
