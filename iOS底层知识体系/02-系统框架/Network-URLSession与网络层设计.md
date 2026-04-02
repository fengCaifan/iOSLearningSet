# Network — URLSession 与网络层设计

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - URLSession 架构：Session → Configuration → Task（Data/Upload/Download/WebSocket）
  - URLProtocol：网络请求拦截机制
  - Alamofire / Moya 的架构分层
-->



## 2. 底层原理

<!-- 建议涵盖：
  - URLSession 的线程模型（delegateQueue、内部串行队列）
  - URLCache 缓存策略（CachePolicy）
  - URLProtocol 拦截的原理与限制（WKWebView 的坑）
  - HTTP 请求/响应的完整生命周期
  - Background Session 的工作原理
  - Network.framework（NWConnection）与 URLSession 的区别
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: URLSession 和 NSURLConnection 有什么区别？
  A: 

- Q: 如何设计一个网络层中间件（拦截器链）？
  A: 

- Q: URLProtocol 能拦截 WKWebView 的请求吗？为什么？
  A: 

- Q: 大文件下载如何实现断点续传？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 项目中网络层的分层设计（API 层 → 中间件层 → 传输层）
  - 请求重试、降级、Mock 的实现方案
  - Charles / Wireshark 抓包调试
-->



## 5. 参考资料

