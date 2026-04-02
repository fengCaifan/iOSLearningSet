# HTTP/2 与 HTTP/3 (QUIC)

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - HTTP/1.1 的瓶颈：队头阻塞（Head-of-Line Blocking）、无法多路复用
  - HTTP/2 的核心改进：二进制帧、多路复用、头部压缩（HPACK）、服务端推送
  - HTTP/3 的核心改进：基于 QUIC（UDP）、解决 TCP 队头阻塞
-->



## 2. 底层原理

<!-- 建议涵盖：
  - HTTP/2：
    - 二进制分帧层（Frame → Stream → Connection）
    - 多路复用的实现：一个 TCP 连接上的多个 Stream
    - HPACK 头部压缩：静态表 + 动态表 + Huffman 编码
    - TCP 层队头阻塞仍然存在
  - HTTP/3 (QUIC)：
    - 为什么基于 UDP 而非 TCP？
    - QUIC 的多路复用：Stream 级别独立，无队头阻塞
    - 0-RTT 连接建立
    - 连接迁移（Connection Migration）：基于 Connection ID 而非四元组
    - iOS 中 URLSession 对 HTTP/2、HTTP/3 的支持
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: HTTP/2 相比 HTTP/1.1 有什么改进？
  A: 

- Q: HTTP/2 解决了队头阻塞吗？为什么还需要 HTTP/3？
  A: 

- Q: QUIC 为什么选择 UDP 作为底层协议？
  A: 

- Q: HTTP/3 的 0-RTT 是如何实现的？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 如何确认 App 的请求使用了 HTTP/2？
  - iOS 中启用 HTTP/3 的配置
-->



## 5. 参考资料

