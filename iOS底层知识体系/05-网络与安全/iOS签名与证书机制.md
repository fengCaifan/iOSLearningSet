# iOS 签名与证书机制

> 一句话总结：**iOS 用「Apple 根信任」把开发者身份、设备、能力与二进制绑定在一起：Development 靠 Provisioning Profile 包多层签名；App Store 渠道则由 Apple 再用系统根钥简化验证链。**

---

## 1. 核心概念

### 1.1 为什么要签名

- **完整性**：二进制未被篡改。
- **来源可信**：链路到 Apple / 开发者身份可验证。
- **能力边界**：通过 **Entitlements** 声明推送、Keychain、App Group 等特权。

### 1.2 证书与 Profile 里有什么

| 文件 | 典型内容 |
|------|----------|
| **.cer（开发/发布证书）** | Mac 开发者的公钥 + **Apple 对这份公钥的签名**（证明「这把公钥是苹果认可的开发者」） |
| **.mobileprovision** | 证书 + App ID + 设备列表（Debug）+ Entitlements + **Apple 对整包元数据的签名** |
| **Entitlements** | 实际打进签名里的「权限声明」，与工程 Capabilities 对应 |

（对称/非对称、数字签名与证书链的通用原理见旧笔记《专题——iOS加解密、签名与证书》前半部分。）

---

## 2. 底层原理（开发包多层验证）

### 2.1 设备侧验证直觉

简化理解（与旧笔记插图一致）：

1. **Mac 本机**生成 **CSR**：内含 Mac 公钥，私钥留在钥匙串。
2. **Apple 后台**用 Apple 私钥签发 **.cer**：绑定你的开发者身份与 Mac 公钥。
3. **Xcode / codesign** 用 **Mac 私钥**对 App 可执行与资源签名 → 包里有一份「App 内容签名」。
4. **.mobileprovision** 再被 Apple 签名，里面**嵌上**上一步可用的证书 + AppId + 设备白名单 + Entitlements。
5. **iPhone** 内置 **Apple 公钥**：先验 Profile 外层签名 → 再验证书 → 再用证书里的 Mac 公钥验 App 内容签名。

**三个常见追问（旧笔记原问）**：

- 为何不「仅 Mac 公私钥自举」？——无法证明 Mac 公钥是 Apple 认可的开发者。  
- 为何证书之外还要 Profile？——要把 **设备、BundleID、Entitlements** 等策略一起签进来。  
- 为何不让每次构建都上传 Apple 用 Apple 私钥签 App？——效率与离线开发体验。

### 2.2 App Store 分发

上架包由 Apple **重签**，用户设备主要验证 **Apple 根信任链**；不再依赖本机 `mobileprovision` 这一层开发者草稿（与 Debug/Adhoc 不同）。

### 2.3 常用命令

```bash
# 验证签名与 entitlements
codesign -dvvv --entitlements :- YourApp.app

# 验真
codesign --verify --deep --strict --verbose=2 YourApp.app
```

---

## 3. 关键问题 & 面试题

| 题目 | 要点 |
|------|------|
| **Profile 解决什么问题？** | 把 **谁能装、装哪个 AppId、带哪些权限** 与二进制绑定。 |
| **Entitlements 从哪里来？** | Xcode Capabilities 生成 plist，打包打进签名；与 profile 要匹配。 |
| **双重签名 / 重签名场景？**  | 企业内测、插件 SDK、`fastlane resign` 换证书时需要理解各层签名含义。 |

---

## 4. 实战应用

- **签名失败排查**：证书是否过期、Profile 是否包含当前设备、BundleID 是否一致、Entitlements 是否「 Capability 比 Profile 多 」。
- **自动化**：`fastlane match` 统一管理证书与 Profile 仓库；CI 用 **App Store Connect API Key** 分发。

---

## 5. 参考资料

- [TN3125: Inside Code Signing: Provisioning Profiles](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles)
- [Code Signing Guide（-archive）](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Introduction/Introduction.html)
- 旧笔记：`读书笔记/iOS自学笔记/专题——iOS加解密、签名与证书.md`

---

## 附录：从编译视角看代码签名（整合）

### A.1 为什么需要代码签名？

```
1. 安全：确保应用未被篡改
2. 系统要求：iOS 要求所有应用必须签名
3. App Store：Apple 要求所有上架应用必须签名
```

### A.2 签名流程

**1. 生成证书和 Provisioning Profile**：

```
开发者账号 → Apple Developer → 生成证书
```

**2. 签名**：

```
codesign -s "iPhone Developer: Name (ABCDEFGHIJ)" \
        --entitlements entitlements.plist \
        MyApp.app
```

**3. 验证签名**：

```bash
codesign -v MyApp.app
# 输出：valid on disk
```

### A.3 签名与 Mach-O

**Code Signature Segment**：

```
Mach-O 文件中有一个 __LINKEDIT 段
├── Code Signature
├── Entitlements
└── Requirements
```

**签名结构**：

```
┌─────────────────────────────────┐
│  Code Signature (Blob)          │
│  ├── CMS Signature              │
│  ├── Code Directory             │
│  │   ├── Slot (Code Segment)    │
│  │   └── Requirement Set        │
│  └── Requirements               │
└─────────────────────────────────┘
```

---

## 附录B：iOS手机调试时证书底层原理（面试高频）

### B.1 调试时的证书验证流程

当你在Xcode中直接运行APP到真机时，系统会进行如下的证书验证流程：

```
1. Xcode使用本地Mac的私钥对APP源码文件进行签名（编号001）
2. Apple使用Apple私钥对Mac公钥进行签名生成证书（编号002）
3. Apple使用Apple私钥对（证书+devices+app id+entitlements）进行签名生成mobileprovision（编号003）
4. iPhone使用内置的Apple公钥验证mobileprovision的签名（003）
5. 验证通过后，提取证书，再次使用Apple公钥验证证书签名（002）
6. 验证通过后，提取Mac公钥，使用Mac公钥验证APP签名（001）
7. 三层验证都通过，APP才能安装运行
```

### B.2 为什么需要三层签名？

**问题1：为什么不直接使用"Mac私钥签名，Mac公钥验证"？**

答：无法证明Mac公钥是合法的，脱离了Apple的控制体系。

**问题2：为什么需要用Apple私钥进行第二次签名（证书）？**

答：为了建立信任链，证明Mac公钥是经过Apple认证的合法开发者公钥。

**问题3：为什么还需要第三次签名（mobileprovision）？**

答：为了添加运行时约束：
- **devices**：控制只能在特定调试设备上运行
- **app id**：控制只能用于指定Bundle ID的APP
- **entitlements**：控制APP的权限（推送、IAP、Keychain等）

**问题4：为什么不直接用Apple私钥对APP进行签名？**

答：Apple私钥存储在Apple服务器，每次都上传APP到Apple签名效率太低，影响开发体验。

### B.3 实际开发中的对应关系

**钥匙串操作 → CSR文件：**

```bash
# 在钥匙串访问中：证书助理 → 从证书颁发机构请求证书
# 生成：CertificateSigningRequest.certSigningRequest（这就是Mac公钥）
```

**Apple Developer操作 → .cer文件：**

```bash
# Apple Developer → 添加Certificate → 提交CSR文件
# 生成：ios_development.cer 或 ios_distribution.cer
# 本质：Apple私钥对Mac公钥的数字签名
```

**Apple Developer操作 → .mobileprovision文件：**

```bash
# Apple Developer → 添加Provisioning Profile
# 选择：App ID、Devices、Certificates
# 生成：xxx.mobileprovision
# 本质：Apple私钥对（证书+devices+app id+entitlements）的数字签名
```

### B.4 App Store分发的区别

从App Store下载的APP不需要.mobileprovision文件，因为：

```
1. App Store已经保证了分发渠道的可信性
2. Apple在上架过程中会对APP进行重签名
3. 安装时只需验证Apple的签名即可
```

### B.5 调试时的常见问题

**问题1：真机调试失败，提示"找不到开发证书"**

- 检查钥匙串是否有开发证书
- 检查Xcode的Signing & Capabilities设置
- 重新下载Provisioning Profile

**问题2：提示"设备不被支持"**

- 检查Provisioning Profile是否包含当前设备的UDID
- 在Apple Developer中添加设备UDID
- 重新生成Provisioning Profile

**问题3：提示"Entitlements不匹配"**

- 检查工程的entitlements文件与Provisioning Profile是否匹配
- 确保开启的Capabilities在Profile中都有授权
- 检查Bundle ID是否一致
