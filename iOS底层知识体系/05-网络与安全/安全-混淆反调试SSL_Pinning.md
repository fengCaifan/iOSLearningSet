# 安全：SSL Pinning、混淆与反调试

> 一句话总结：**客户端安全是「提高攻击成本」：传输层用 SSL Pinning 防中间人；二进制层用混淆与反调试增加逆向难度；但没有绝对安全，敏感逻辑应由服务端裁决。**

---

## 1. 威胁模型（移动端常见攻击面）

| 威胁 | 说明 | 影响 |
|------|------|------|
| **中间人（MITM）** | 代理抓包（Charles/Fiddler）、伪证书解密 HTTPS | 接口数据泄露、伪造请求 |
| **静态分析** | class-dump、Hopper、IDA 还原逻辑 | 业务逻辑暴露、加密算法被破解 |
| **动态调试** | lldb 附加、Frida hook、越狱 Tweak | 运行时篡改行为、绕过校验 |
| **重打包** | 砸壳后修改代码重签名 | 破解 IAP、注入恶意代码 |

---

## 2. SSL Pinning（证书绑定）

### 2.1 原理

```
默认 HTTPS 验证流程：
  客户端 → 验证证书链 → 根证书在系统信任列表中 → 通过

问题：
  用户安装了 Charles/Fiddler 的根证书 → 系统信任 → 中间人解密所有 HTTPS

SSL Pinning 额外校验：
  客户端 → 系统验证证书链 → 通过
        → 额外校验：证书/公钥是否与 App 内置的一致 → 不一致则拒绝连接
```

### 2.2 两种 Pinning 方式

| 方式 | 绑定内容 | 优势 | 劣势 |
|------|----------|------|------|
| **证书 Pinning** | 整张叶子证书（DER 数据） | 最严格 | 证书续期必须发版更新 |
| **公钥 Pinning** | 证书中的 SPKI（公钥信息） | 证书续期只要不换公钥就不用更新 | 略微宽松 |

### 2.3 URLSession 实现

```swift
class NetworkDelegate: NSObject, URLSessionDelegate {
    
    // App 内置的服务器公钥 Hash（SHA256）
    let pinnedPublicKeyHashes: Set<String> = [
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=", // 主证书公钥
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=", // 备用公钥
    ]
    
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // 1. 先做系统默认验证（证书链、有效期、域名）
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)
        guard isValid else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // 2. 额外做公钥 Pinning
        let serverCertificateCount = SecTrustGetCertificateCount(serverTrust)
        for index in 0..<serverCertificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, index) else { continue }
            
            // 提取公钥并计算 SHA256
            let publicKey = SecCertificateCopyKey(certificate)
            let publicKeyData = SecKeyCopyExternalRepresentation(publicKey!, nil)! as Data
            let hash = publicKeyData.sha256Base64()
            
            if pinnedPublicKeyHashes.contains(hash) {
                // 匹配成功
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }
        
        // 3. 所有证书公钥都不匹配 → 拒绝连接
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
```

### 2.4 Alamofire 中的 Pinning

```swift
// Alamofire 5 内置了 ServerTrustManager
let evaluators: [String: ServerTrustEvaluating] = [
    "api.example.com": PinnedCertificatesTrustEvaluator(
        certificates: Bundle.main.af.certificates,  // .cer 文件
        acceptSelfSignedCertificates: false,
        performDefaultValidation: true
    )
    // 或使用公钥 Pinning
    // "api.example.com": PublicKeysTrustEvaluator(keys: Bundle.main.af.publicKeys)
]

let session = Session(
    serverTrustManager: ServerTrustManager(evaluators: evaluators)
)
```

### 2.5 Pinning 的运维问题

```
证书续期怎么办？

1. 内置多个公钥（主证书 + 备用证书）：
   即使主证书过期更换，只要公钥不变或用了备用公钥，都能通过

2. 远程配置更新 Pin 列表：
   App 启动时从安全通道获取最新的 Pin 列表
   注意：这个"安全通道"本身也需要 Pinning 保护，避免鸡生蛋问题

3. Debug 环境关闭 Pinning：
   #if DEBUG
   // 不做 Pinning，方便 Charles 调试
   #endif

Charles 抓包与 Pinning 的关系：
- 开启 Pinning：Charles 的证书不在 Pin 列表中 → 连接被拒绝 → 抓不到包
- 关闭 Pinning：Charles 证书被系统信任 → 正常抓包
- 调试时需要条件编译关闭，或内置 Debug 证书
```

---

## 3. 代码混淆

### 3.1 符号剥离（最基础）

```
Xcode Release 配置默认会做：

1. Strip Linked Product = YES
   → 去除可执行文件中的符号表
   → class-dump 能获取的信息大幅减少

2. Deployment Postprocessing = YES
   → 进一步优化二进制

3. Swift Whole Module Optimization
   → 跨文件优化，减少暴露的符号

效果：
  Debug 包 class-dump → 完整的类名、方法名、属性名
  Release 包 class-dump → OC 的方法名仍可见，Swift 的大部分已优化掉
```

### 3.2 字符串加密

```objc
// 问题：Hopper/IDA 中搜索字符串可以快速定位关键逻辑
// 比如搜索 "api_secret" 就能找到加密相关代码

// 方案：编译期加密，运行时解密
// 简单示例（实际应使用更复杂的混淆）

// 加密后存储（编译期生成）
static const char encrypted_key[] = {0x61 ^ 0xFF, 0x70 ^ 0xFF, 0x69 ^ 0xFF, ...};

// 运行时解密
NSString *decryptKey(void) {
    char decrypted[sizeof(encrypted_key)];
    for (int i = 0; i < sizeof(encrypted_key); i++) {
        decrypted[i] = encrypted_key[i] ^ 0xFF;
    }
    return [[NSString alloc] initWithBytes:decrypted length:sizeof(encrypted_key) encoding:NSUTF8StringEncoding];
}

// 注意：这只能增加逆向门槛，内存 dump 仍可获取
```

### 3.3 控制流混淆（进阶）

```
控制流平坦化：将正常的 if-else / switch 逻辑打散成一个大的 while + switch 结构
→ IDA 中看到的是一个巨大的状态机，难以还原真实逻辑

工具：
- LLVM Obfuscator（开源，基于 LLVM Pass）
- 商业方案：梆梆加固、爱加密、网易易盾等

代价：
- 性能下降（10-30%）
- 调试困难
- 崩溃符号化受影响
```

---

## 4. 反调试

### 4.1 常见检测手段

```c
// 1. ptrace 拒绝附加
#import <sys/types.h>
#import <sys/ptrace.h>

void disableDebugger() {
    ptrace(PT_DENY_ATTACH, 0, 0, 0);
    // 调用后，任何调试器 attach 都会失败
    // 注意：这个调用本身也容易被 hook 绕过
}

// 2. 检测调试器是否已附加
#import <sys/sysctl.h>

BOOL isBeingDebugged() {
    int name[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc info;
    size_t infoSize = sizeof(info);
    sysctl(name, 4, &info, &infoSize, NULL, 0);
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

// 3. 检测越狱环境
BOOL isJailbroken() {
    // 检测常见越狱文件
    NSArray *paths = @[
        @"/Applications/Cydia.app",
        @"/usr/sbin/sshd",
        @"/bin/bash",
        @"/etc/apt",
        @"/private/var/lib/apt/"
    ];
    for (NSString *path in paths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            return YES;
        }
    }
    // 检测是否能 fork
    pid_t pid = fork();
    if (pid >= 0) {
        // 正常 App 不能 fork，能 fork 说明沙盒被突破
        return YES;
    }
    return NO;
}

// 4. 检测可疑动态库（Frida、Substrate 等）
BOOL hasSuspiciousLibraries() {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "FridaGadget") ||
            strstr(name, "frida") ||
            strstr(name, "substrate") ||
            strstr(name, "ellekit")) {
            return YES;
        }
    }
    return NO;
}
```

### 4.2 反调试的局限性

```
所有客户端反调试都可以被绕过：
- ptrace 可以被 hook/patch
- sysctl 检测可以被 hook 返回 false
- 越狱检测可以被 Tweak 绕过（如 Liberty Lite）
- 字符串检测可以被修改文件路径绕过

正确心态：
- 反调试是「提高攻击成本」，不是「绝对防御」
- 敏感逻辑必须放服务端
- 加密密钥不能硬编码在客户端
- 关键校验（支付、授权）必须服务端二次验证
```

---

## 5. 安全最佳实践清单

```
传输安全：
✅ 全站 HTTPS（ATS 默认要求）
✅ 生产环境开启 SSL Pinning（公钥 Pinning 优先）
✅ Debug 环境通过编译宏关闭 Pinning
✅ 内置主备两个公钥，应对证书续期

存储安全：
✅ 密钥存 Keychain，不存 UserDefaults / 文件
✅ 敏感数据用 Data Protection（NSFileProtectionComplete）
✅ 不在日志中打印 token、密码等

代码安全：
✅ Release 包 Strip 符号
✅ 关键字符串（API Key、Secret）加密存储
✅ 核心逻辑用 C/C++ 编写（增加逆向难度）
✅ 关键校验服务端二次验证

合规注意：
⚠️ 越狱检测的文案需法务确认（不能歧视用户）
⚠️ 过度反调试可能影响 App Review
⚠️ SSL Pinning 不能影响合法的网络安全审计
```

---

## 6. 面试高频问题

| 问题 | 答案要点 |
|------|----------|
| **什么是 SSL Pinning？** | 在系统证书链验证之外，额外校验证书/公钥是否与 App 内置的一致 |
| **证书 Pinning vs 公钥 Pinning？** | 证书 Pinning 更严格但续期要发版；公钥 Pinning 续期不换公钥则无需更新 |
| **Charles 能抓 HTTPS 的包是为什么？** | 用户安装了 Charles 根证书，系统信任了它；开启 Pinning 后则抓不到 |
| **证书过期怎么办？** | 内置主备公钥 + 远程更新 Pin 列表 |
| **客户端安全的边界是什么？** | 只能提高攻击成本，不能绝对防御；敏感逻辑必须服务端裁决 |
| **越狱检测怎么做？** | 检测文件路径、fork、动态库；但都可以被绕过 |

---

**最后更新**：2025-01-27
