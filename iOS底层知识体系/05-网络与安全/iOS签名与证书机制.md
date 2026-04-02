# iOS 签名与证书机制

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - 代码签名的目的：确保代码完整性和来源可信
  - 证书体系：Apple Root CA → WWDR CA → 开发者证书
  - Provisioning Profile 的组成：Certificate + App ID + Device IDs + Entitlements
-->



## 2. 底层原理

<!-- 建议涵盖：
  - 双重签名机制：
    - Mac 私钥签名 → CSR → Apple 颁发证书（包含 Mac 公钥）
    - Xcode 用 Mac 私钥对 App 签名
    - 设备用 Apple 公钥验证证书 → 用证书中的公钥验证 App 签名
  - Provisioning Profile 的验证流程
  - Entitlements 的作用（Push、Keychain Sharing、App Groups 等）
  - 重签名原理与工具（codesign、fastlane resign）
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: iOS App 的签名机制是怎样的？
  A: 

- Q: 什么是 Provisioning Profile？它包含哪些内容？
  A: 

- Q: 企业签名和 App Store 签名有什么区别？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 签名错误的常见排查思路
  - 自动化签名配置（Fastlane match）
-->



## 5. 参考资料

