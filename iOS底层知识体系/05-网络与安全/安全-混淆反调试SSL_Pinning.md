# 安全-混淆反调试SSL_Pinning

> 一句话总结：**客户端安全是「提高攻击成本」：传输层用证书绑定防中间人；二进制层用混淆与反调试增时；但没有绝对安全，敏感逻辑应服务端裁决。**

---

## 1. 核心概念

### 1.1 威胁模型（移动端常见）

| 威胁 | 说明 |
|------|------|
| **中间人（MITM）** | 代理抓包、伪证书解密 HTTPS |
| **静态分析** | class-dump、Hopper、IDA 还原逻辑 |
| **动态调试** | lldb 附加、函数插桩、越狱 Hook（Frida 等） |

### 1.2 SSL / Certificate Pinning

在系统默认信任链之上，再校验**服务端证书 / 公钥**是否与 App 内置的一份一致；不一致则**取消**连接。

- **证书 Pinning**：绑定整张叶子证书（轮换麻烦，需发版更新）。
- **公钥 Pinning**：绑定 SPKI（证书续期若公钥不变可少更客户端）。

Apple 文档：[Performing manual server trust authentication](https://developer.apple.com/documentation/foundation/url_loading_system/handling_an_authentication_challenge/performing_manual_server_trust_authentication)

---

## 2. 底层原理

### 2.1 URLSession 校验 serverTrust

在 `urlSession(_:didReceive:completionHandler:)` 中：

1. `challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust`
2. 取 `serverTrust`，用 `SecTrustCopyCertificateChain` / `SecCertificateCopyData` 等与**打包证书**或**本地 SPKI Hash**比对
3. 匹配 → `completionHandler(.useCredential, URLCredential(trust: ...))`  
   不匹配 → `.cancelAuthenticationChallenge`

**注意**：ATS 仍可约束域名；Pinning 是在默认链路外**加严**，别误用为绕过 ATS。

### 2.2 混淆（Obfuscation）

- **符号剥离**：Release `Strip`，Swift 尽量 `Whole Module Optimization`。
- **字符串加密**：敏感 key、URL 分段拼接或运行时解密（可被内存 dump，只能提高门槛）。
- **控制流平坦化 / 虚拟机保护**：常见由商业加固或自研 Pass 完成，需处理审核与崩溃符号化成本。

### 2.3 反调试（示意级别）

- **ptrace PT_DENY_ATTACH**、定时检测调试器附加、检测可疑动态库（越狱环境）。
- **越狱检测**：文件路径、`fork`、`syscall`、沙盒特征；注意误杀与隐私合规。

**合规提示**：过度反调试可能影响崩溃收集与 App Review 体验，需权衡。

---

## 3. 关键问题 & 面试题

- **Pinning 与 Charles 抓包关系？** 不信任用户装的 CA 时，Charles 直代理解密会失败；团队调试可用**仅 Debug 关闭 Pinning** 或内置 Debug 证书。
- **证书过期怎么办？** 多备证书、服务端双证并行；客户端「主备公钥 pin」。
- **为何不能只在客户端校验license？** 可被重打包；关键授权**放服务端**。

---

## 4. 实战清单

- [ ] 生产环境开启 Pinning，DebugScheme 可编译开关隔离  
- [ ] 不把密钥硬编码；用 Keychain + 服务端短时票据  
- [ ] 与安全/法务确认数据采集与越狱检测文案  

---

## 5. 参考资料

- [Handling an Authentication Challenge - Apple](https://developer.apple.com/documentation/foundation/urlsessiondelegate/urlsession(_:didreceive:completionhandler:))
- OWASP [Certificate and Public Key Pinning](https://owasp.org/www-community/controls/Certificate_and_Public_Key_Pinning)
- 旧笔记（密码学基础）：`读书笔记/iOS自学笔记/专题——iOS加解密、签名与证书.md`
