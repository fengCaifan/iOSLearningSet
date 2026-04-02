# 安全 — 混淆、反调试与 SSL Pinning

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - 代码混淆：增加逆向工程的难度
  - 反调试：检测和阻止调试器附加
  - SSL Pinning：固定证书/公钥，防止中间人攻击
  - Keychain：安全的本地存储
-->



## 2. 底层原理

<!-- 建议涵盖：
  - 代码混淆方案：
    - OC：类名/方法名混淆（宏替换、工具生成混淆映射表）
    - Swift：符号天然有一定程度的混淆（name mangling）
    - LLVM 混淆 Pass（控制流平坦化、字符串加密、指令替换）
  - 反调试：
    - ptrace(PT_DENY_ATTACH)
    - sysctl 检测调试状态
    - isatty / ioctl 检测
  - 越狱检测：
    - 检测特定文件/路径（/Applications/Cydia.app 等）
    - 检测 fork 能力
    - 检测 dyld 注入
  - SSL Pinning 实现：
    - 证书固定（Certificate Pinning）
    - 公钥固定（Public Key Pinning）
    - URLSession delegate 中实现
  - Keychain 安全存储：kSecAttrAccessible 策略
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: 如何防止 App 被抓包？
  A: 

- Q: SSL Pinning 有哪些实现方式？各自的优缺点？
  A: 

- Q: 如何检测越狱环境？
  A: 

- Q: 敏感数据应该存储在哪里？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - SSL Pinning 的接入与证书更新方案
  - 安全存储方案的选型
-->



## 5. 参考资料

