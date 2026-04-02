# HTTP 协议与 HTTPS 原理

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - HTTP/1.1 的特点：无状态、文本协议、持久连接（Keep-Alive）
  - HTTPS = HTTP + TLS/SSL
  - 对称加密 vs 非对称加密 vs 数字证书
-->



## 2. 底层原理

<!-- 建议涵盖：
  - HTTP 报文结构：请求行/状态行 + Headers + Body
  - 常见状态码：2xx/3xx/4xx/5xx 及具体含义
  - Cookie / Session 机制
  - HTTPS TLS 1.2 握手完整流程（4 次握手）：
    ClientHello → ServerHello+Certificate → ClientKeyExchange → ChangeCipherSpec
  - TLS 1.3 的改进（1-RTT 握手、0-RTT 恢复、移除 RSA 密钥交换）
  - 证书链验证流程：叶子证书 → 中间证书 → 根证书
  - 中间人攻击（MITM）的原理
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: HTTP 和 HTTPS 的区别？
  A: 

- Q: HTTPS 的加密流程？为什么用混合加密？
  A: 

- Q: GET 和 POST 的区别？（深层回答 vs 表面回答）
  A: 

- Q: 常见的 HTTP 状态码及其含义？301 和 302 的区别？
  A: 

- Q: 什么是中间人攻击？如何防范？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - Charles 抓包 HTTPS 的原理
  - App 如何验证服务器证书
-->



## 5. 参考资料

