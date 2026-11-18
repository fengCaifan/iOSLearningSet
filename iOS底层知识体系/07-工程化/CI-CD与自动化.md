# CI-CD 与自动化

## 1. 从公私钥、CSR 到 iOS 签名证书

### 1.1 先纠正旧网络笔记中的简化模型

《iOS 网络分层及网络协议完全学习指南》已经介绍了公私钥、CA、证书和 iOS 签名。本专题沿用这些概念，但不能把旧章节中的教学简化直接当作实际打包算法。

| 旧笔记中的表述 | 打包时应采用的理解 |
|----------------|--------------------|
| CSR 就是 Mac 公钥 | CSR 是证书申请请求，包含公钥、申请信息和请求签名；私钥留在申请方 |
| 证书用来加密公钥 | 公钥可以公开，CA 的签名把身份、用途和公钥绑定起来，防止未被发现的替换 |
| 数字签名就是私钥加密、公钥解密 | 用签名算法对被签名的数据表示生成签名，再用公钥验证；不是把所有签名算法都解释成 RSA 加解密 |
| Xcode 对 App 源码文件签名，IPA 中有源码 | 正常分发包主要含编译后的可执行代码与资源；代码签名保护构建产物，不是源码仓库或 IPA zip 外壳 |
| 固定三次签名按一个顺序验证完就安装 | 应区分证书信任、代码完整性、profile 授权及运行环境约束；这是约束链，不是所有渠道的固定三步实现 |
| App Store 不用 profile，因此只靠一个 Apple 公钥即可解释全部流程 | 上传、服务端处理和设备安装是不同阶段；不能把商店渠道与 Development / Ad Hoc 的安装授权混为一谈 |

证书和签名首先解决**身份可信与内容完整性**，不是把 App 源码或开发者公钥“加密隐藏起来”。源码和私钥的保密是另外的问题。[A1–A4]

### 1.2 开发者密钥不等于某台 Mac 的硬件身份

通常是开发者或组织在受控环境生成一对密钥：

```text
私钥：用于签名，需要保密并受控保存
公钥：用于验签，可以被写进证书
```

这可以是在开发 Mac 上完成，但“在 Mac 上生成”不代表密钥在概念上只能属于这台硬件。把合法的证书与配对私钥受控迁移到构建节点后，节点才能获得同一 signing identity；只复制证书文件不够。[A1–A3]

### 1.3 CSR 请求的是“请 CA 认证这把公钥”

```text
生成密钥对
    ↓
生成 CSR：公钥 + 申请信息 + 请求签名
    ↓
把 CSR 提交到证书签发流程
    ↓
Apple 签发用于代码签名的证书
    ↓
将证书与原来的私钥配对保存
```

CSR 的请求签名与 Apple 给证书的 CA 签名不是同一个签名。PKCS#10 中请求签名由申请主体的私钥生成，覆盖证书请求信息。CSR 不包含需要交给 Apple 的开发者私钥，也不等于“裸公钥文件”。[A1、A5]

### 1.4 一张签名证书由什么组成

X.509 证书可以这样观察：

```text
Certificate
├─ 待签名的证书内容（tbsCertificate）
│  ├─ 版本、序列号、签名算法标识
│  ├─ Issuer：签发者
│  ├─ Validity：生效时间和到期时间
│  ├─ Subject：被认证的主体
│  ├─ SubjectPublicKeyInfo：公钥和公钥算法
│  └─ Extensions：用途、约束、标识等
├─ signatureAlgorithm
└─ signatureValue：签发者对上述证书内容的签名
```

CA 签名认证的不只是一个公钥字节串，还包括与身份、有效期和用途有关的证书内容。验签必须结合信任链和适用策略，不能只说“公钥能解出一段东西就合法”。[A1、A6]

Apple 开发者证书通常通过对应的 Apple 中间 CA 链接到可信根。下面是角色示意，不保证所有证书都由同一个中间证书签发：

```text
受信任的 Apple 根
    ↓ 签发/信任
对应的 Apple 中间 CA，例如 WWDR 的相关证书
    ↓ 签发
开发者代码签名证书
    ↓ 其公钥与本地私钥配对
可使用的 signing identity
```

验证过程中要看实际 Issuer、链、有效期与代码签名用途，而不是把所有 Apple 公钥合并成一把万能公钥。[A1–A3]

### 1.5 `.cer`、`.p12`、Keychain 和 `.p8` 分别是什么

| 材料 | 主要内容 | 用在什么阶段 |
|------|----------|--------------|
| `.cer` | 证书，即公钥、身份/用途等信息和 CA 签名；不包含开发者私钥 | 导入证书、观察信任链 |
| `.p12` | 可以承载证书、配对私钥及相关证书链的 PKCS#12 容器；导出身份时通常用密码保护 | 将授权签名身份受控迁移到节点 |
| Keychain | 保存证书、私钥及访问控制的环境 | `codesign` / Xcode 实际使用私钥 |
| `.mobileprovision` | 被 Apple 签名的授权描述，包含允许的 App、证书、权限、设备条件等 | 构建/导出和相应安装授权 |
| App Store Connect `.p8` | API 认证所需私钥，配合 Key ID / Issuer ID | 上传、查询或其他授权 API 操作；不替代 App 代码签名私钥 |

“Keychain 中看得到证书”不等于可以签名：还要有**配对私钥、适当的访问授权、可用于目标用途的有效身份**。CI 上出现交互式私钥访问弹窗，往往就是访问授权与无人值守环境不一致。[A1–A4；F1–F4]

Apple 下载的正常 `.cer` 是证书；但文件扩展名不是安全保证，其他工具可能用容易混淆的扩展名保存 PEM 或其他容器，不能只凭名字判断是否含私钥。[A1]

公开字段可以这样检查；不要求导出私钥：

```bash
# 证书为 DER 时使用；若实际是 PEM，要相应调整输入格式。
openssl x509 -inform DER -in signing.cer -noout -text

# 列出当前用户可用的代码签名 identity；分享输出前脱敏身份信息。
security find-identity -v -p codesigning
```

## 2. Provisioning Profile 怎样把证书变成安装授权

### 2.1 Profile 的外层与里面的字段

Profile 不是一个可以任意编辑的普通 plist。传统可读视图是携带授权内容的 CMS 签名材料；解码后可以观察其中的 plist 字段。修改解码后的字段再另存，不能保留原本的 Apple 授权。[A2]

| 字段 | 含义 | 为什么影响打包/安装 |
|------|------|----------------------|
| `Name` / `UUID` | Profile 名称与标识 | Xcode / export 选择具体授权材料 |
| `TeamIdentifier` | 对应开发团队信息 | 需要与签名和 App 配置协调 |
| `ApplicationIdentifierPrefix` | App ID 前缀 | 不应一概假设它永远与 Team ID 相同，迁移/历史材料须实物核对 |
| `DeveloperCertificates` | 允许签署相关 App 的证书集合 | 实际签名证书需要满足该授权 |
| `Entitlements` | Profile 允许的相关能力与标识约束 | App 的实际签名 entitlement 需符合授权规则 |
| `ProvisionedDevices` | 适用时的设备列表 | Development / Ad Hoc 等方式的设备授权 |
| `ProvisionsAllDevices` | 特定分发方式的设备范围线索 | 企业分发等授权判断，不能单独凭一个字段完成所有验证 |
| `CreationDate` / `ExpirationDate` | Profile 创建/失效时间 | 过期授权不能靠重新 zip 包恢复有效 |

Profile 没有为每个 App 预先保存其编译后的代码签名。它规定的是**谁可以签、可以签什么、允许哪些能力和使用条件**。[A2]

**现代授权还涉及 DER 表示。** Apple TN3125 说明 profile 中包含 `DER-Encoded-Profile`，它携带另一份 CMS 包装的 DER 授权数据；在该表示中允许的证书用 SHA-256 校验值表达。iOS 15 等对应系统开始需要这种表示。`security cms -D` 看到的传统 plist 适合观察与排障，不是要求所有系统只读取这份 plist，也不是稳定的自制 profile 格式契约。[A2]

### 2.2 App ID、证书和 entitlement 必须协调

```text
签名证书 / 配对私钥
    ↓ 符合 profile 允许的签名身份
App 与每个扩展的 Bundle ID
    ↓ 符合各自 profile 的 App ID 约束
实际签名 entitlement
    ↓ 符合 profile 和平台的能力规则
设备/分发方式/时间/信任状态
    ↓ 符合运行环境的授权条件
```

不能把 entitlement 比对简化成“两个 plist 完全一样”：有的值涉及通配、展开、数组、App 特定标识或其他规则。应看最终签进 App 的 entitlement，而不只看工程里的源 `.entitlements` 文件。[A2]

entitlement 也不是所有系统权限的统称。Camera/Microphone 等用途说明、运行时授权提示，与 App Groups、Keychain Groups、推送等签名能力，不是同一个配置层次。

### 2.3 Debug / Release 与分发方式不是同一维度

| 分发方式 | 常见身份/授权特征 | 设备条件 | 需要注意 |
|----------|-------------------|----------|----------|
| Development | 开发身份；开发 profile；调试授权通常允许 | 适用的注册设备 | 对主 App 和扩展都核对 |
| Ad Hoc | 分发身份；Ad Hoc profile | 适用的注册设备 | 不是“任何人拿到 IPA 都能装” |
| Enterprise / In-house | 相应组织授权与企业分发材料 | 与该分发机制相符 | 不把普通开发者材料当成企业分发资格 |
| App Store / TestFlight | 提交到 App Store Connect 的相应分发材料；后续经过平台处理 | 不使用 Ad Hoc 的安装设备名单逻辑 | 上传、处理、审核/测试与发布是不同阶段 |

Debug/Release/Inhouse 是项目的构建配置名称，影响编译和资源等设置；profile 类型与导出方法是分发授权。名字可以由项目自定义，**配置名叫 Inhouse，并不会自动获得企业证书、权限或正确 Bundle ID**。[A1、A4；F1–F4]

### 2.4 安装验签应该理解为多组约束，而不是“源码三层签名”

教学上可以按三组问题理解：

1. **签名身份是否可信？** 证书链、用途与当前平台策略是否成立。
2. **被保护的构建内容是否完整？** 签名与代码/相关资源、元数据的保护关系是否一致。
3. **这个 App 在这个环境下是否被允许？** profile 的身份、App 标识、entitlement、设备及有效期等是否满足条件。

它们是逻辑约束，不是声称所有 iOS 渠道都按“profile → 证书 → IPA”三个固定步骤实现。商店分发还有服务端处理和对应渠道规则，不能把普通设备分发解释直接套过去。[A1–A4]

## 3. 从源码到 Archive、签名 App 和 IPA

### 3.1 构建签名的是产物，不是源码目录

```text
固定的源码和依赖
    ↓ 资源生成、版本/构建号、构建设置
Swift / Objective-C 等编译
    ↓
目标文件和链接
    ↓
Mach-O 可执行文件 + 框架/扩展 + 编译/处理后的资源
    ↓
按目标准备能力和授权，完成代码签名
    ↓
形成 App / xcarchive
    ↓ 按分发方式导出和准备产物
IPA 等分发制品
```

代码签名涉及 CodeDirectory、受保护内容的哈希、签名和相应身份等结构；资源封装也有相关保护。不是“用私钥把所有源码加密一次”，也不是对最外面的 IPA zip 文件做一个万能签名。[A2–A4]

标准构建工具会协调嵌套框架、扩展和外层 App。不要通过“修改签名后的 Info.plist 再 zip”试图更换授权身份或 Bundle ID。[A2–A4]

### 3.2 `.xcarchive` 保存什么

```text
Example.xcarchive/
├─ Products/Applications/GRAVITY.app/
│  ├─ GRAVITY                       编译后的可执行文件
│  ├─ Info.plist                    应用元数据
│  ├─ Frameworks/                   嵌入的框架
│  ├─ PlugIns/                      App 扩展
│  ├─ _CodeSignature/               相应签名/资源封装材料
│  └─ embedded.mobileprovision      相应渠道/阶段的授权材料
├─ dSYMs/                           符号化材料
└─ Info.plist                       Archive 元数据
```

这是理解项目产物的示意，实际内容与构建/分发方式有关。[A3–A4]`.p12`、签名私钥、API `.p8` 和源码仓库不应被当作 App 资源打进 IPA。

dSYM 用于符号化，不是设备安装 App 所需的授权；但它必须与对应二进制构建关联保存。只有 IPA、没有可追溯的符号和版本材料，会给线上排障留下缺口。

### 3.3 Archive 与 Export 分别做什么

Archive 是基于选定 workspace、scheme、configuration 和 SDK 得到可归档的构建；Export 则基于 archive 和选定分发方式准备输出，可能涉及签名选择和 profile 替换。Export 不是只给目录加一个 `.ipa` 扩展名，也不是把任意 App 改成另一套身份的通用转换器。[A1–A4；F1]

```bash
# 命令形状示例；先确认 per-target 签名设置与节点材料。
xcodebuild \
  -workspace Chat.xcworkspace \
  -scheme Chat \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -archivePath output/Example.xcarchive \
  archive

xcodebuild \
  -exportArchive \
  -archivePath output/Example.xcarchive \
  -exportPath output/export \
  -exportOptionsPlist ExportOptions.plist
```

这里选择设备平台是为了真机分发，不是声称模拟器不能 archive。Apple 文档说明 Xcode 15 及以后也能生成模拟器 archive，但它不能直接当真机分发包。[A4]

`ExportOptions.plist` 指定该 Xcode 支持的分发方法、签名方式和必要的 profile 映射等；每个真正存在的 App/扩展要与自己的授权对应。不要用一个全局 `PROVISIONING_PROFILE_SPECIFIER` 把主 App profile 强行套给所有扩展。

Fastlane `gym` / `build_app` 组织这些命令、参数、日志和输出；它不会凭空生成组织授权，或让缺失私钥的证书变得可签。[F1–F4]

### 3.4 生成 IPA 不等于交付结束

```text
Archive 成功
    ≠ Export 成功
    ≠ 本地内容校验通过
    ≠ 指定设备安装成功
    ≠ 上传到平台成功
    ≠ TestFlight 已处理可用
    ≠ App Store 已审核/发布
```

应把每一步成功的含义写进流程，失败时知道是构建、签名授权、产物完整性、设备限制还是平台认证问题，而不是统一归为“Jenkins 打包失败”。

## 4. 把手工打包过程转成 CI/CD

### 4.1 CI、CD 和自动打包的关系

- **CI：持续集成。** 对固定的源码变更自动执行构建、测试和检查，尽早发现集成问题，并阻止不满足门禁的变更。
- **持续交付：** 让通过验证的版本可以可靠地生成、保存和交付，保留必要的授权/审批。
- **持续部署：** 在满足策略后自动完成部署/发布。iOS 应用还要考虑对应分发和商店流程，不能把服务器部署方式原样套用。
- **自动打包：** 只是其中一段。一个只会产出 IPA、没有测试和验证的 Job，不等于完整的 CI/CD。[J1–J4]

可以按 PR/MR、主分支定时检查、受保护的发布标签分别触发不同任务；PR 的 build/test 门禁、覆盖率与静态分析报告、发布审批应明确配置，不能把“标签触发自动 ship”直接等同于已经具备发布质量控制。

### 4.2 Jenkins、Fastlane、Xcode 谁负责什么

| 层次 | 主要责任 | 不负责什么 |
|------|----------|------------|
| Jenkins | 触发、队列、节点、阶段、凭据绑定、日志、产物和权限 | 不替 Apple 签发证书，也不直接实现编译器 |
| Makefile / 脚本 | 把项目约定、资源和元数据操作连接起来 | 文件存在不表示 Job 一定调用它 |
| Fastlane | 组织 iOS 构建、签名管理辅助、平台上传等动作 | 不替代合法签名身份、profile 或发布授权 |
| `xcodebuild` / 签名工具 | 实际构建、归档、导出和相应签名 | 成功返回不代表后续设备或商店流程已完成 |
| Apple/分发平台 | 按渠道处理上传、验证、分发或发布 | 上传 API 凭据不替代代码签名凭据 |

所以学习 Jenkins 打包，必须往下追到实际执行的命令和签名材料，不能只看流水线 stage 的名字。[J1–J4；F1–F4]

### 4.3 哪些手工动作要变成显式输入

| 本地手工动作 | CI 中应明确的输入或条件 |
|--------------|------------------------|
| 选择 Xcode | 获批准的 Xcode/SDK 版本与 `DEVELOPER_DIR` |
| 打开 workspace / 选择 scheme | 固定源码、workspace、scheme、configuration |
| 登录账号、安装证书 | 构建用户、配对私钥、Keychain 及访问控制 |
| 选择 profile | 主 App/扩展映射，分发方式、权限与设备条件 |
| 修改版本号 | App 版本、构建号来源、与扩展的一致性 |
| Archive / Export | 保存实际参数、日志和可追溯产物 |
| 点击上传 | 独立上传开关、API 凭据、平台/发布审批 |
| 拷贝安装包给测试 | 下载权限、安装方式、制品哈希与版本记录 |

CI 不是复制某个开发者桌面上的“刚好可用状态”，而是把依赖、权限、命令、验证和结果固定成可追溯过程。

## 5. `chat-ios` 的 Jenkins / Makefile / Fastlane 实际链路

### 5.1 先找到真正的执行入口

本节按 **2026-11-05 的本地工作树**核对，不等于已检查线上 Jenkins Job 或证明某条历史脚本仍在运行。项目根目录是：

```text
/Users/fengcaifan/baidu/Gravity/baidu/gensoft-ipcs-mobile/chat-ios
```

| 文件 | 在链路中的职责 | 本地核对范围 |
|------|----------------|--------------|
| `bin/Jenkins.groovy` | Jenkins 阶段、构建参数、制品归档、成功或失败通知 | 1–169 行，[P1] |
| `Makefile` | 资源处理、版本号、构建类型到 fastlane lane 的转接 | 1–77 行，[P2] |
| `fastlane/Fastfile` | `gym` 归档导出、签名选择、TestFlight / 蒲公英上传 | 18–185 行，[P3] |
| `fastlane/Appfile` | 默认 App 标识和账号配置 | [P4] |
| `Gemfile` / `Gemfile.lock` / `Pluginfile` | Ruby 工具和插件的依赖声明、锁定版本 | [P5] |
| `Chat.xcworkspace` | 把 `Chat/Chat.xcodeproj` 和 Pods 工程组合起来 | [P6] |
| `Chat/Chat.xcodeproj/project.pbxproj` | target、构建配置、Bundle ID、archive 阶段的签名配置 | [P6] |
| `cer/*.mobileprovision` | 可用于安装和构建的授权材料；不能只凭文件名判断类型 | [P7] |

**Jenkins 不直接调用 `gym`；这套代码中间还有 Makefile。** 调用链是：

```text
用户/其他系统触发 Job，提供参数
    ↓
Jenkins 调度一个 agent
    ↓
bin/Jenkins.groovy
    ├─ Git：进入已有的 chat-ios/ 工作目录，切分支、拉代码、清旧输出
    ├─ Dependence：pod install --verbose
    └─ Package：按 type 选择 make target
            ↓
        Makefile
            ├─ resource：SwiftGen + PNG 处理
            └─ version：更新 build number、版本号
                    ↓
                Fastfile 对应 lane
                    ↓
                gym / build_app
                    ↓
                xcodebuild archive → exportArchive
                    ↓
                IPA / xcarchive / dSYM 等制品
                    ↓
                按 lane 执行上传
    ↓
Jenkins post：归档制品，发送成功/失败通知
```

这张图表示本地脚本调用关系。最初是谁克隆了仓库、Job 怎样加载 Groovy、哪个节点安装了签名材料，脚本没有给出全部答案，需要到平台核对。[P1–P3]

### 5.2 页面参数怎样传到打包过程

`Jenkins.groovy` 引用了 `params`，但没有在脚本中声明 `parameters { ... }`。因此**参数定义位置尚未确认**，不能说复制这个文件就会自动出现同样的构建表单。[P1:4–13、17–23]

| 参数 | 代码中的用途 | 需要分清的边界 |
|------|--------------|----------------|
| `branch` | `git checkout` 的目标 | 应约束合法值；源码必须对应受信任、可追溯的提交 |
| `type` | 选择 appstore / adhoc / debug / 其他分支 | 原脚本把所有未匹配值都落到 inhouse，不应把这种默认行为当作安全设计 |
| `version` | 传给 `make ... VERSION=...` | 最终对应 `CFBundleShortVersionString`，不是 Jenkins 的任务序号 |
| `buildNumber` | 显式传入 App 构建号 | 空值时回退到 Jenkins 的 `BUILD_NUMBER` |
| `isUpload` | 被环境变量保存，并在 `Upload Pgy` 阶段判断 | 它没有被传给 Makefile 的 `ISUPLOAD`，也没有控制 appstore lane 的上传 |

这里至少有三种不同标识：

- **Git commit SHA**：回答“构建的是哪份代码”。
- **Jenkins `BUILD_NUMBER`**：回答“这个 Job 的第几次运行”。
- **App `CFBundleVersion`**：回答“这个版本的第几次 App 构建”。

可以让 Jenkins 序号成为 App 构建号来源，但它们不是天然同一个值。用户指定 `buildNumber` 后，原通知仍使用 Jenkins 的 `BUILD_NUMBER`，不能据通知文本直接判断 IPA 内的构建号。[P1:61–67、127–133]

### 5.3 每个 Jenkins stage 实际做了什么

**Git 阶段**进入 `chat-ios/`，清理工作树、切分支、拉取代码，再删除旧输出。这里是既有目录上的 Git 操作，不是完整的 SCM checkout 定义。[P1:15–43]

尤其注意：

```groovy
// 原项目中的风险写法，仅用于说明，不作为新平台模板。
git pull -r || exit 0
```

拉取失败时，shell 仍返回成功，后续 Job 可能继续用旧代码打包；`exit 0` 还会跳过这个 shell 剩余的清理命令。正确目标是：checkout 失败立即失败，记录实际 SHA，不把“旧代码也能编译”当作本次构建成功。[P1:25–40]

**Dependence 阶段**执行 `pod install --verbose`。`bundle install` 被注释了，所以不能认为它已经按 `Gemfile.lock` 安装工具。[P1:45–55]

**Package 阶段**计算构建号，运行 `make resource`，随后选择对应构建 target。[P1:56–95]

**Upload Pgy 阶段**只有条件判断和 `echo`；它没有调用上传 API。真正的上传在 Fastfile 中，不在这个看起来叫“Upload”的 stage 里。[P1:97–115；P3:117–148、175–182]

**post 阶段**在成功时保存 `chat-ios/output/*` 并通知下载地址，失败时通知日志地址。`onlyIfSuccessful: true` 不会保存失败构建的这批制品；后续应另外保存失败日志和测试报告，不能只保存成功 IPA。[P1:117–169]

### 5.4 Makefile 不是可有可无的一层

| Jenkins 的 `type` | Make target | fastlane lane | Xcode configuration | 导出方法（项目原值） |
|------------------|-------------|---------------|---------------------|----------------------|
| `debug` | `build_debug` | `development` | `Debug` | `development` |
| `adhoc` | `build_adhoc` | `adhoc` | `Release` | `ad-hoc` |
| `appstore` | `build_release` | `appstore` | `Release` | `app-store` |
| 其他值 | `build_inhouse` | `inhouse` | `Inhouse` | `enterprise` |

表中的方法字符串是**现有配置值**，不是要求新 Xcode 永远使用这几个旧名字。搭建新节点时应核对该 Xcode 的 `-help` 和锁定 fastlane 版本支持的导出选项。[P1:68–92；P2:35–49；P3]

`make resource` 执行 SwiftGen，并进入 PNG 处理；PNG 处理会准备 Python 环境和 Pillow。因此构建节点不仅需要 Xcode，还依赖项目的 Ruby、Python、Pods、资源脚本及私有库访问能力。[P2:7–23]

`make version` 先调用构建号脚本，再更新版本号。当前脚本实际修改主 App 和 NotificationService 的 plist；虽然声明了 Widget 路径，却没有更新 Widget，也没有更新 AudioScreenCapture。需要结合扩展的最终 plist 核对版本一致性，不能只看主 App 已写入。[P2:14–16、29–33；P8]

`make uploadDsym` 是另一个 target；Jenkins 的 Package 分支没有调用它。存在“上传符号表”的命令，不代表每次流水线已执行该命令。[P2:51–64；P1:68–92]

### 5.5 Fastfile 怎样把证书授权落实到多个 target

Fastfile 对四个 Bundle ID 配置了 profile 映射：主 App、NotificationService、AudioScreenCapture，以及一个 Widget 标识。[P3:31–43、57–69、97–109、162–174]

但是当前 Xcode 工程解析到的 Native Target 是：

```text
Chat                     → GRAVITY.app
NotificationService      → NotificationService.appex
AudioScreenCapture       → AudioScreenCapture.appex
```

没有解析到 Widget Native Target。Fastfile 里的 Widget 映射可能是遗留配置；是否需要它，应看实际分支和归档中的 `.appex`，不能只按 Fastfile 的四个条目推导当前工程一定有四个 target。[P6]

对于确实存在的主 App 和扩展，签名需要逐个成立：

```text
主 App 的 Bundle ID        ↔ 主 App profile 的 App ID
通知扩展的 Bundle ID       ↔ 通知扩展 profile 的 App ID
录屏扩展的 Bundle ID       ↔ 录屏扩展 profile 的 App ID

每个目标：
    实际签名证书必须被对应 profile 允许
    实际 entitlement 必须满足对应授权
    当前设备必须满足对应分发方式的设备条件
```

主 App 签名正确，不会替缺少 profile 或权限不匹配的扩展“兜底”。应用组、钥匙串共享、推送环境等也不能只看主 App 的 Bundle ID。[P6–P7；签名规则见第 2 章]

### 5.6 用项目中的描述文件做一次实物拆解

本次只解码了三个 `.mobileprovision` 的公开字段，**没有读取 `.p12` 或 `.p8` 的私钥内容**，没有输出设备 UDID，也没有把素材密码写进本文。CMS 解码结果只用于观察字段，不等于证明线上节点使用的材料就是这些文件，或完成平台安装验签。[P7]

| 文件 | Profile Name | 类型线索 | 设备数量 | 有效期 |
|------|--------------|----------|----------|--------|
| `Dev_Gravity.mobileprovision` | `Dev: Gravity` | `get-task-allow=true`；有设备名单；推送环境 development | 77 | 2027-05-20（UTC） |
| `Dev_Gravity_NotificationService.mobileprovision` | `Dev: Gravity NotificationService` | `get-task-allow=true`；有设备名单 | 77 | 2027-05-20（UTC） |
| `Dev_Gravity_AudioScreenCapture.mobileprovision` | `Dev: Gravity AudioScreenCapture` | `get-task-allow=true`；有设备名单 | 72 | 2027-05-20（UTC） |

三份文件各包含一张 `DeveloperCertificates`，证书 DER 的 SHA-256 相同，说明它们引用同一张开发证书；三者的 App ID 分别对应主 App 和两个扩展。这里只比较了证书本身，**尚未确认 Jenkins 节点里的私钥与这张证书配对**。[P7]

从这份材料能推出：

- 仓库里这三份是开发授权材料，不是企业分发或 App Store profile。
- 截至 2026-11-05，它们的 profile 有效期尚未结束；仍应独立检查证书、撤销状态和实际使用的 profile。
- 录屏扩展的设备数量与主 App 不同；某台设备能安装主 App 所需授权，不代表扩展也满足条件。仅比较数量不等于逐一验证了设备集合。
- 它们不能证明节点已经准备了 Ad Hoc、App Store 或企业分发的全部材料。[P7]

### 5.7 Archive 的签名与 export 的签名要一起看

Xcode 工程中的 `CODE_SIGN_STYLE`、`DEVELOPMENT_TEAM`、`PROVISIONING_PROFILE_SPECIFIER` 影响构建/归档；Fastfile 的 `export_options` 影响归档后的导出。只读其中一处，会遗漏另一阶段的约束。[P3；P6]

本地配置中：

- Debug 使用开发身份和 Dev profile。
- Release 使用分发身份和 AppStore profile。
- Inhouse 配置仍使用开发身份、Dev profile 和与 Debug 相同的 Team。
- Fastfile 的 inhouse lane 却指定另一个 Team、企业分发身份，以及 `ent.hiclub.gravity` 等不同主 App/通知扩展标识。

这是**需要对照实际构建设置和 export 日志核验的不一致**，不能只凭 lane 名称认为企业签名已经正确，也不能在没跑真实构建前宣称线上一定失败。需要检查实际 target 的 Bundle ID、archive 中的签名、导出映射和节点上的企业证书/profile。[P3:151–174；P6]

另一个细节：原 Fastfile 把 `codesigning_identity` 放在 `export_options` 哈希内。不能直接把一个非标准 plist 字段当成“签名身份已经被强制选择”；应看 gym 参数、实际生成的 ExportOptions 和 `xcodebuild` 日志，核对 `signingCertificate` 等有效字段。[P3；fastlane build_app 官方资料]

### 5.8 上传资格和代码签名资格不是同一种凭据

appstore lane 完成 IPA 和 archive zip 后，调用 `app_store_connect_api_key`，再使用 `pilot` 上传 TestFlight。它优先从构建用户的外部目录查找 `.p8`，没有找到时回退到 fastlane 目录。[P3:74–149]

这条链路里：

```text
.p12 / Keychain 中的代码签名私钥
    → 签出获授权的 App

App Store Connect 的 .p8 API 私钥 + Key ID + Issuer ID
    → 对上传 API 进行认证
```

两者不可互相替代。`.p8` 不是 profile 里的开发证书，也不会让一份签名错误的 IPA 自动变得可安装。上图对应本项目使用的团队 API key；个人 API key 对 Issuer ID 的要求不同，按实际账号/key 类型与工具文档核对。[F4]

当前 appstore lane **没有受 Jenkins `params.isUpload` 控制**：进入 appstore lane 就继续执行 `pilot`。`skip_waiting_for_build_processing` 跳过相应处理等待；`skip_submission` 的上传方式不会在上传后自动完成对测试者的分发。它不是 App Store 审核/发布开关。“上传成功”不等于 TestFlight 已处理可用或已分发给测试者，更不等于 App Store 已审核、已发布。[P3:117–148；F4]

inhouse lane 使用 `options[:isUpload]` 决定是否调用 `pgyer`，但 Jenkins 的 `isUpload` 没有传给 Makefile 的 `ISUPLOAD`。Makefile 又把默认值写成大写 `FALSE`。不能把 Jenkins 页面上的一个勾选框，推断成所有上传路径都已经被统一控制。[P1:97–108；P2:5、44–46；P3:175–182]

在核对过的 fastlane `2.198.0` 和固定的当前源码提交中，CLI 只把小写 `true` / `yes`、`false` / `no` 转换成布尔值，没有统一转小写。Ruby 仅把 `false` 和 `nil` 当作假；字符串 `"FALSE"` 仍为真值。[F6]

| 参数原值 | 解析结果 | 直接 `if options[:isUpload]` |
|----------|----------|-----------------------------|
| `isUpload:false` | 布尔 false | 不进入上传分支 |
| `isUpload:true` | 布尔 true | 进入上传分支 |
| `isUpload:FALSE` | 字符串 `"FALSE"` | **会进入上传分支** |
| `isUpload:TRUE` | 字符串 `"TRUE"` | 会进入上传分支 |

因此，在这些实现下，原调用链的默认大写 `FALSE` 不是可靠的关闭开关。当前 Jenkins 实际 fastlane 版本、参数是否被外部包装层转换，以及某次历史构建是否真的上传，仍需日志确认；不能把静态语义推论写成历史上传事实。

最小处理是调用端统一传小写布尔值，并在 lane 显式校验；下面是可落地的规范化逻辑，不执行任何上传：

```ruby
raw = options.fetch(:isUpload, false)
upload_enabled = case raw
                 when true, false
                   raw
                 when String
                   value = raw.strip.downcase
                   UI.user_error!('isUpload 必须为 true 或 false') unless %w[true false].include?(value)
                   value == 'true'
                 else
                   UI.user_error!('isUpload 类型不合法')
                 end

# 在真实 lane 中只在 upload_enabled 为 true 时执行上传动作。
```

### 5.9 工具链锁定存在真实缺口

| 工具 | Gemfile 声明 | Gemfile.lock 锁定 |
|------|--------------|------------------|
| CocoaPods | `1.13.0` | `1.11.3` |
| fastlane | `>= 2.229.0` | `2.198.0` |

这是本地文件的实际差异，不是对“最新版本”的推荐。[P5]

Jenkins 脚本没有执行已注释的 `bundle install`，Makefile 直接调用全局 `fastlane`。因此当前构建结果可能依赖节点预装的 Ruby 工具版本，不能把 lock 文件当作已生效的环境保证。[P1:48–53；P2:35–49]

后续迁移应先在受控环境中校准 Gemfile 与 lock，审查版本变更并提交一致的锁文件，再使用 `bundle exec`。**不要在新节点上直接照抄 `bundle update`，也不要把锁文件不一致产生的错误用 `|| exit 0` 忽略。**

私有 CocoaPods 源还需要构建用户自己的 SSH/网络访问能力；本地登录账号能拉取，不代表 Jenkins agent 账号也能拉取。版本号、私有 spec 和 Git tag 的一致性也应纳入检查。[P5–P6；Podfile 私有源配置]

### 5.10 不把已有风险当成搭建教程

| 本地发现 | 为什么与打包正确性有关 | 后续处理方向 |
|----------|----------------------|--------------|
| `agent any` | 没有限定具备 Xcode 和签名环境的节点 | 使用专用 macOS label；核对线上实际调度 |
| 已有目录中 `git pull` 失败仍成功 | 可能构建旧提交 | 受控 checkout，记录 SHA，失败立即停止 |
| 没有 test / lint stage；scheme 还引用缺失的 ChatTests 目标 | 自动打包不等于完整 CI 质量门禁，测试入口本身也需核验 | 补齐或修复测试 target，再接入测试和检查 |
| 上传 stage 只 echo；上传发生在 lane 内 | 参数表面含义与实际行为不同 | 显式传递布尔值，分别控制打包与上传 |
| 多套签名配置与旧 target 映射并存 | Archive、export 和扩展授权可能不一致 | 核对 archive 内容和签名矩阵 |
| 构建号通知与实际 App 构建号可能不同 | 排障时无法可靠定位制品 | 制品元数据同时保存 SHA、Job 序号、App 构建号 |
| `Gemfile` / lock 不一致，全局工具执行 | 换节点后可能出现不同结果 | 锁版本，用 `bundle exec` 执行 |
| 签名资产被 Git 跟踪，脚本存在凭据字面量 | 仓库、历史或日志的访问范围可能超出签名权限范围 | 审查访问记录，移入凭据管理；确认泄露后轮换，不只删除当前文件 |
| 只保存成功输出，dSYM 上传 target 不在主链路 | 失败日志或符号化材料可能缺失 | 保存构建日志、测试报告、archive / dSYM 元数据 |

这是静态核对发现的改进点；未修改项目，也未进行线上构建或判断历史制品是否有效。[P1–P8]

## 6. 项目中另有一条 `ci.yml` / 集群脚本链路

### 6.1 它不能与 Jenkins / Fastlane 混为一谈

```text
ci.yml 定义集群环境、签名检查和 build command
    ↓
集群平台准备工具、证书/profile 等环境（实际行为需到平台核对）
    ↓
sh build_submitter_scripts.sh -c Inhouse
    ↓
解锁/切换 Keychain
    ↓
xcodebuild clean build
    ↓
手工复制 GRAVITY.app → Payload → zip IPA
    ↓
单独压缩主 App dSYM → output
```

这条脚本没有调用 Fastfile，也没有使用标准的 `archive → exportArchive` 过程。[P9]

`ci.yml` 中的集群名、Xcode `26.3`、Python `3.9.6`、Keychain 名称是**仓库配置值**。本次没有连接集群，不能据此确认软件确实已安装或版本适合现在的构建。新节点应以受支持工具链和项目实测为准，不能把配置中的数字当成“当前最新”。[P9:1–33]

### 6.2 签名准备做在调用脚本之前和脚本之中

YAML 声明一个 `.p12` 和三份 Dev profile；脚本操作 Keychain，使 `codesign` 可以找到签名身份。这正对应证书模型中的“有证书 + 有配对私钥 + 有授权描述文件”，而不是“安装 Xcode 就有签名资格”。[P9]

但当前 YAML 只明确列出开发材料，构建命令却选择 Inhouse。其他分发材料是否由集群预装或别处注入，尚未核验，不能把这三份 Dev profile 推导成企业分发授权。

原脚本会修改 Keychain search list 和默认 Keychain，并以固定密码解锁；本文不复制密码。共享节点上这种全局状态会影响其他构建，后续应采用隔离、受控签名环境和可靠清理。

### 6.3 旧脚本的包装方法不能当成标准打包步骤

脚本在 `xcodebuild` 完成后复制 `.app`，又修改主 App 和扩展的 `CFBundleIdentifier`，随后 zip。修改已签名的 Info.plist 会使签名保护的内容与原签名不一致；没有看到相应重新签名和重新匹配 profile 的步骤，不能把“zip 命令成功”当成“可安装包已经成立”。[P9:109–136；代码签名规则]

当前工作树还没有脚本引用的 `GRAVITY/info.plist`、`GRAVITY/NotificationService/info.plist` 路径，真实 plist 在 `Chat/` 下。脚本保留了旧目录假设，说明搭建新平台前必须先检查入口是否仍适用于当前工程。[P8–P9]

标准教程应使用可追溯的 `xcarchive` 和明确的 export 配置；旧脚本只作为理解遗留链路的材料，不推荐直接迁移执行。

## 7. 把证书验证变成 CI/CD 的阶段条件

### 7.1 触发、构建、签名和发布分别承担什么责任

| 阶段 | 输入 | 必须确认的条件 | 输出 |
|------|------|----------------|------|
| 触发/checkout | 参数、受信任的仓库引用 | 权限、实际 SHA、输入合法性 | 固定代码快照 |
| 环境/依赖 | Xcode、Ruby、锁文件、私有依赖 | 工具版本可追溯，依赖锁一致 | 可重复构建环境 |
| 编译/测试 | 源码、scheme、configuration、目标 SDK | build/test/check 通过 | 报告和构建产物 |
| 签名准备 | 证书、配对私钥、profile | 身份有效，授权与 target 匹配，节点可非交互使用私钥 | 可用 signing identity |
| Archive | 构建配置、签名设置 | App/扩展配置一致 | xcarchive、签名 App、dSYM |
| Export | archive、分发方法、目标 profile | 分发授权匹配，必要的签名选择可完成 | IPA 等分发制品 |
| 验证 | IPA / App / profile / 元数据 | 本地签名校验、权限/设备约束核对、实际安装验证 | 可验收的制品 |
| 分发/发布 | 制品、平台认证凭据、审批 | 上传权限和发布审批成立 | 内测分发或发布记录 |

Jenkins 成功只能说明它观察到的任务成功。必须把对应检查写进任务，才能让“绿灯”代表这些条件；否则它可能只说明 shell 返回了 0。

### 7.2 Keychain 与签名材料怎样进入节点

Jenkins 调度的是进程和任务，不会自动赋予代码签名私钥。签名材料可以来自受控 Secret File、证书管理服务或只读 `match` 同步，但必须明确：

- 哪个构建用户持有哪个 Keychain？
- 证书与私钥是否成对存在，是否被 profile 允许？
- 是否具备非交互签名的访问授权，而不是弹出无人能点击的密码框？
- 是否会向非受信任 PR 暴露私钥或上传凭据？
- 构建结束后哪些临时文件和 Keychain 要删除，哪些共享材料不能误删？

**更安全的边界是两个 Job：** 普通 PR 构建/测试没有发布签名与上传凭据；可信发布 Job 使用受保护的流水线定义和审查通过的提交，经过授权后才加载签名材料。单靠 Jenkinsfile 里一个可被 PR 修改的 `when` 条件，不构成秘密保护边界。

### 7.3 为制品保存可追溯材料

至少保存：Git SHA、Job 标识、App 版本和构建号、Xcode/SDK、scheme/configuration、导出方法、实际 Bundle ID、使用 profile 的标识和有效期、测试报告、构建/export 日志、IPA 哈希、archive 和 dSYM 的关联信息。

示例中的命令只检查已有产物，不代替设备和商店的验收：

```bash
# 对已解包的 App 做本地签名检查；路径按实际产物调整。
codesign --verify --deep --strict --verbose=2 "Payload/GRAVITY.app"
codesign -d --entitlements :- "Payload/GRAVITY.app"

# 解码只帮助观察授权字段，不单独证明平台允许安装。
security cms -D -i "Payload/GRAVITY.app/embedded.mobileprovision"

# 检查可执行文件与 dSYM 的 UUID 是否对应。
dwarfdump --uuid "Payload/GRAVITY.app/GRAVITY"
dwarfdump --uuid "archive.xcarchive/dSYMs/GRAVITY.app.dSYM"
```

主 App 与每个扩展都应单独观察 Bundle ID、entitlements 和 profile；`codesign --verify` 通过不等于设备名单、有效期、信任策略或 App Store 校验都已通过。

### 7.4 缓存、并发和混合工程不能牺牲可重复性

- DerivedData、依赖和模块缓存要带 Xcode/SDK/锁文件维度；缓存命中不应掩盖依赖变化。
- 可以先分别 build-for-testing / test-without-building，再扩大测试并行；不能让多个签名任务同时清理一个工作目录或改同一个默认 Keychain。
- 项目可能含预编译 Flutter/Unity 材料，但这份 Jenkins 主链路没有直接调用 `bin/flutter_build.sh` 或 Unity 构建脚本，不能据目录存在推导每次都会重编译它们。若改为源码构建，需要另外锁定对应 SDK 和脚本入口。
- 内测包问题通过重新出包、下线分发链接等处理；App Store 发布不是任意时刻可恢复旧二进制的“自动回滚”。交付机制应分别说明应用版本、功能开关和服务端回退。

## 8. 到现有 Jenkins 打包平台上怎样核对

### 8.1 先区分代码里已确认的内容和平台上待确认的内容

| 项目 | 本地证据 | 现场需要确认 |
|------|----------|--------------|
| Pipeline | 有 `bin/Jenkins.groovy` | Job 是 inline Script、Pipeline from SCM、共享库还是其他平台包装？加载的是哪个提交？ |
| 参数 | 脚本读取 branch/type/version/buildNumber/isUpload | 参数在哪里定义，默认值、权限、合法值和布尔类型是什么？ |
| 工作目录 | shell 进入 `chat-ios/` | 谁先创建或克隆该目录，实际 WORKSPACE 是什么？ |
| Node | `agent any` | 实际运行在哪台 macOS agent，label、executors 和运行用户是什么？ |
| 签名 | 工程/Fastfile 有手工签名设置 | 哪些 Keychain、证书和 profile 由节点预装，哪些由 Job 注入？ |
| 分发 | lane 内含上传，post 含下载通知 | isUpload 的实际效果、上传凭据范围、内部下载服务怎样认证？ |
| 工具链 | Gemfile 与 lock 不一致 | 构建日志里真实的 Ruby、fastlane、Pods、Xcode 版本是什么？ |
| 质量门禁 | Groovy 没有 test/lint stage | 平台包装层或上游 Job 是否另有检查？ |

本次未访问现有 Jenkins 网页、没有导出 Job 配置，也没有触发构建。源代码是学习依据，平台状态是后续现场核对事项，不能相互替代。

### 8.2 一次现场核对的具体顺序

1. 从一个**已有成功构建**打开 Console Output，记录 Git SHA、工作目录、Node、工具版本、gym 的 archive/export 命令和产物路径；先脱敏日志再分享。
2. 打开 Job Configure，核对参数、Pipeline Definition、Script Path、SCM 分支、权限和保留策略；不改配置、不展示 Secret 值。
3. 打开对应 Node，核对运行账号、label、executors、Java、Xcode 路径与私有依赖访问方式。
4. 只记录 credential 的用途和绑定位置，不获取或复制生产密码、`.p8` 或签名私钥。
5. 对比一次 Debug 和一次 App Store/企业构建，确认签名材料在哪个阶段切换、上传动作在哪发生。
6. 检查制品下载入口与权限：脚本通知的 `/download?jobName=...&build=...` 是内部下载服务，不是仅凭 URL 就能确认 Jenkins 原生 Artifact 服务。HTTPS、安装描述和设备授权仍需要单独验证。

### 8.3 用只读诊断确认构建用户环境

下面应在受控诊断任务中运行，输出先脱敏；不打印整个 `env`，不解锁或导出生产私钥：

```bash
whoami
pwd
java -version
xcode-select -p
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
ruby -v
bundle --version
bundle exec fastlane --version
bundle exec pod --version
security list-keychains -d user
security find-identity -v -p codesigning
```

当前项目 Gemfile/lock 不一致时，`bundle exec` 的失败本身就是诊断信息；不能为了让诊断变绿而临时更新整个依赖图。签名身份输出有个人或团队信息，分享前要脱敏。

## 9. 搭建一套能解释清楚的 Jenkins iOS 打包环境

### 9.1 Controller 和 macOS Agent 分工

```text
浏览器 / Git 事件
    ↓
Jenkins Controller
    ├─ Job、参数、队列、权限、凭据绑定、日志和制品入口
    └─ 调度 macOS Agent
            ├─ agent 进程：Java / Remoting
            ├─ 构建环境：Xcode / SDK / Ruby / Bundler / CocoaPods
            ├─ 项目：workspace / scheme / 资源脚本 / 私有依赖
            └─ 签名环境：构建用户的 Keychain / profile
```

Controller 可以与构建节点分开部署。**运行 Jenkins 的 Java 和编译 iOS 的 Xcode 是两套不同的要求**：Controller 不必持有生产签名私钥；真正执行 iOS 构建的节点必须具备受支持的 macOS/Xcode 环境。

教学环境可以在一台 Mac 上理解两种角色，但应分别明确运行用户和工作目录。生产环境不要把下载服务、Controller、普通 PR 执行器和生产签名权限无条件混在一起。

**Java 运行时核对日期：2026-11-05。** Jenkins 官方矩阵当时列出 Java 21、25 的支持区间：

| Java | 首个支持的 LTS | 首个支持的 weekly | 官方计划支持到 |
|------|----------------|------------------|----------------|
| 21 | 2.479.1 | 2.463 | 2027-09 |
| 25 | 2.541.1 | 2.534 | 2029-09 |

这不是“最新 Jenkins 版本”清单，也不是给现有未知版本 Controller 强行换 JVM 的指令。Java 17 在当时矩阵已列入历史支持；新安装先选择目标 Jenkins core，再按矩阵和插件/OS/架构兼容性选择 Java。Controller、agent、CLI 都要满足各自的 Jenkins Java 要求，实际搭建时再次核对官方支持政策。[J3]

### 9.2 先搭实验 Controller，不改现有生产平台

在实验 Mac 上使用 Homebrew 的命令形状如下；它们是后续操作步骤，本次没有执行安装或启动服务：

```bash
brew install jenkins-lts
brew services start jenkins-lts
brew services info jenkins-lts
```

这些安装/启动命令在 Jenkins 的 macOS LTS 下载说明中有示例；该页面也说明 macOS 安装器由 Jenkins 项目之外的维护者提供。实际包、Java 依赖和服务路径按官方说明及本机 `brew info jenkins-lts` 核对，不把某个固定版本或某人的目录当作所有平台的标准。[J5]

初始化时：

1. 从服务配置或启动日志确认真正的 `JENKINS_HOME`、端口和运行账号。
2. 在机器本地完成首次管理员解锁；不要把初始管理员密码贴进笔记、聊天或构建日志。
3. 创建独立管理员账号，关闭匿名构建/管理权限，按最小权限配置账号或组织认证。
4. 保留 CSRF 防护，使用受控网络和 HTTPS 接入；不要为了连通性关闭所有安全机制。
5. 确認构建缓存、凭据和 `JENKINS_HOME` 的访问权限、备份与恢复方案。备份本身也包含敏感材料，必须受保护。
6. 首先只运行 `echo`、`pwd`、`java -version` 等无签名任务，确认 Controller 的调度、日志和权限，再连接 iOS Agent。

初始账号、插件版本、服务运行用户和 URL 是现场安装状态，本文不声称已经配置完成。

### 9.3 安装与流水线实际需要的能力

| 能力 | 用途 | 是否一开始就需要 |
|------|------|------------------|
| Pipeline | 执行 Jenkinsfile / Declarative Pipeline | 需要 |
| Git / SCM | 获取受控代码版本 | 需要 |
| Credentials Binding | 把 Secret Text / Secret File 绑定到限定步骤 | 签名或认证任务需要 |
| SSH Build Agents | 如果采用 SSH 启动 macOS agent | 仅 SSH 连接方案需要 |
| JUnit | 展示 JUnit XML 测试报告 | 接入真正测试后需要；不能直接把 xcresult 当 JUnit XML |
| 权限/组织认证能力 | 管理管理员、构建用户和发布权限 | 按已有组织平台选择 |

先安装必要插件，并记录 Jenkins、Java、插件兼容矩阵；不要直接导入旧机器的全部插件和生产凭据。

### 9.4 注册专用 macOS 构建节点

1. 为构建准备专用非 root 用户，明确其 home、Keychain 和工作目录。这个用户与开发者桌面登录账号不是同一概念。
2. 安装并选择获批准的 Xcode，按组织授权完成许可、首次组件初始化和必要 SDK 准备。
3. 安装与 Controller 相容的 agent Java；核对后台服务实际使用的 Java，而不只看交互 shell 的 `java -version`。
4. 创建节点，例如实验名称 `ios-mac-01`，label 为 `macos-ios`，签名实验阶段先设一个 executor。
5. 选择 SSH 或 inbound/WebSocket 等受支持连接方式；SSH 账号和 inbound secret 只由管理者保存，不能复用 App 签名私钥充当 agent 身份。
6. 按节点页面和平台方案生成连接/启动配置，使用系统服务确保重启后可以连接；不把真实 secret 写进仓库、shell 历史或本文。
7. 将 Controller 的内置构建执行器与真实构建任务分开，确认 label 调度的任务确实在 macOS 节点执行。

节点上的诊断应确认：

```bash
whoami
pwd
java -version
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
ruby -v
bundle --version
```

后台服务继承的 PATH、`DEVELOPER_DIR`、SSH 凭据和 Keychain 与桌面终端可能不同，这正是“本地可以，Jenkins 不行”的常见排查方向。

### 9.5 先固定源码和依赖，暂不放入生产签名凭据

1. 建立受保护的 Pipeline 定义来源，设置 SCM URL、只读获取代码凭据和明确分支/提交策略。
2. 校准 `Gemfile` 与 `Gemfile.lock`，选定经过验证的版本后再提交锁文件；当前 `chat-ios` 的声明/锁定不一致，不能跳过这个步骤。
3. 以构建用户验证私有 Git、CocoaPods spec 和 submodule 的访问权限。
4. 用 `bundle exec` 执行已锁定工具，记录版本；不要让 Jenkins 每次自动升级工具。
5. 用相同源码和环境先完成不携带发布密钥的模拟器构建。

当前本地项目只解析到 App 和两个扩展，没有测试 Native Target；共享 Chat scheme 虽然引用 `ChatTests`，但该目标的 BlueprintIdentifier 未在工程对象中找到。不能把以下模拟器 build 当成“单元测试已经通过”；接入测试前需要补齐或修复测试 target / scheme，再配置报告输出。[P6]

```bash
#!/bin/bash
set -euo pipefail
mkdir -p output
bundle check
bundle exec pod install
xcodebuild \
  -workspace Chat.xcworkspace \
  -scheme Chat \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath output/DerivedData-Simulator \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee output/simulator-build.log
```

这不是把所有目标的签名需求取消，而是验证不需要设备分发证书的模拟器构建阶段；真正导出设备 IPA 仍需要完整签名授权。

### 9.6 用 Credentials 注入签名材料

实验 Job 可以先只支持 Development IPA，不上传 TestFlight 或企业分发平台。使用独立测试凭据，避免复制仓库中的旧密码或直接使用生产上传密钥。

| 示例 credential ID | 类型 | 含义 |
|--------------------|------|------|
| `ios-dev-p12` | Secret File | 获授权的开发签名证书与私钥导出文件 |
| `ios-dev-p12-password` | Secret Text | 解密该 `.p12` 的密码 |
| `ios-dev-profile-bundle` | Secret File | 与真实 App/扩展相符的 profile 集合，示例使用受控 zip |
| `ios-ci-keychain-password` | Secret Text | 实验临时 Keychain 密码，不是 Apple 账号密码 |

这些 ID 仅是示例，不是现有平台凭据名。Team ID、签名身份名可以是非敏感配置，但要与注入材料匹配；不能用“字段填了 Apple Development”替代对真实 identity 的检查。

- 凭据绑定只覆盖需要签名的步骤，不覆盖任意 PR 脚本。
- 不把整个环境打印到日志，不使用 shell trace 暴露密码，也不把 Secret File 归档为产物。Groovy 用单引号脚本让 shell 从环境展开秘密，避免 Groovy 插值；Secret File 绑定要在进入子目录之前完成，防止秘密落在可浏览的子目录 workspace 临时区域。日志遮罩不是对恶意构建的完整隔离。[J4]
- 临时 Keychain 只授予实际需要的签名工具，避免给所有进程开放私钥使用权。
- 独占实验构建账号可以安装本实验的 profile；生产环境要明确已有 profile 的所有权和清理策略，不能全目录删除。

### 9.7 先用一个最小 Job 验证职责分离

下面是**拟建实验 Job 的示例**，不是现有 `Jenkins.groovy` 的替换补丁。本次未把它写入 `chat-ios` 或上传到 Jenkins。它只在受保护的源码和凭据范围内使用，默认不生成签名 IPA、不上传。

```groovy
pipeline {
    agent { label 'macos-ios' }

    options {
        timestamps()
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        timeout(time: 90, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    parameters {
        booleanParam(
            name: 'BUILD_DEVELOPMENT_IPA',
            defaultValue: false,
            description: '可信源码的开发 IPA；不上传'
        )
    }

    stages {
        stage('Checkout') {
            steps {
                // Job 的 SCM 定义必须来自受保护分支。
                checkout scm
                sh 'git rev-parse HEAD'
            }
        }

        stage('Preflight and Dependencies') {
            steps {
                sh '''#!/bin/bash
set -euo pipefail
xcodebuild -version
ruby -v
bundle --version
bundle check
bundle exec pod install
'''
            }
        }

        stage('Simulator Build') {
            steps {
                sh '''#!/bin/bash
set -euo pipefail
mkdir -p output
xcodebuild \
  -workspace Chat.xcworkspace \
  -scheme Chat \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath output/DerivedData-Simulator \
  build CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee output/simulator-build.log
'''
            }
        }

        stage('Development IPA') {
            when {
                expression { params.BUILD_DEVELOPMENT_IPA }
            }
            steps {
                input message: '确认源码已受信任，使用实验开发签名材料，不上传'
                withCredentials([
                    file(credentialsId: 'ios-dev-p12', variable: 'P12_FILE'),
                    string(credentialsId: 'ios-dev-p12-password', variable: 'P12_PASSWORD'),
                    file(credentialsId: 'ios-dev-profile-bundle', variable: 'PROFILES_ZIP'),
                    string(credentialsId: 'ios-ci-keychain-password', variable: 'CI_KEYCHAIN_PASSWORD')
                ]) {
                    // TEAM_ID / SIGNING_IDENTITY 由受控 Job 或节点配置提供。
                    sh '''#!/bin/bash
set -euo pipefail
set +x
bundle exec fastlane ci_development
'''
                }
            }
        }
    }

    post {
        always {
            // 不包含 credentials 目录或整个 WORKSPACE。
            archiveArtifacts(
                artifacts: 'output/*.ipa,output/*.zip,output/*.log,output/*.json',
                allowEmptyArchive: true
            )
        }
    }
}
```

这个示例减少了原脚本对 `chat-ios/` 预先存在的假设，用 `checkout scm` 后在仓库根目录执行命令；不能一边保留旧工作目录假设，一边直接照搬新模板。

`input` 是操作确认，不是完整的信任边界。真正保护秘密的是 Job 权限、受保护的流水线/源码、凭据 scope 和构建用户隔离。需要对提交代码做审查，不能让不受信任的人修改 Fastfile 后在签名节点执行。

### 9.8 与实验 Job 配套的 Fastlane 签名片段

下面 lane 是后续可实现的模型，**当前项目没有这条 `ci_development` lane**。在锁文件、节点和签名材料核对完成后再落地；不能只把 Jenkinsfile 粘贴进去就认为已经可运行。

```ruby
require 'securerandom'
require 'tmpdir'

platform :ios do
  lane :ci_development do
    keychain_name = "ci-#{SecureRandom.hex(6)}"
    keychain_created = false
    archive_path = 'output/ci_development.xcarchive'

    begin
      create_keychain(
        name: keychain_name,
        password: ENV.fetch('CI_KEYCHAIN_PASSWORD'),
        default_keychain: false,
        unlock: true,
        timeout: 3600,
        lock_when_sleeps: true,
        add_to_search_list: true
      )
      keychain_created = true

      import_certificate(
        certificate_path: ENV.fetch('P12_FILE'),
        certificate_password: ENV.fetch('P12_PASSWORD'),
        keychain_name: keychain_name,
        keychain_password: ENV.fetch('CI_KEYCHAIN_PASSWORD')
      )

      Dir.mktmpdir('ci-profiles-') do |directory|
        # 只使用管理员提供的受控签名材料归档。
        sh('unzip', '-q', ENV.fetch('PROFILES_ZIP'), '-d', directory)
        profiles = Dir.glob(File.join(directory, '**', '*.mobileprovision'))
        UI.user_error!('没有找到 provisioning profiles') if profiles.empty?
        profiles.each { |path| install_provisioning_profile(path: path) }

        build_app(
          workspace: 'Chat.xcworkspace',
          scheme: 'Chat',
          configuration: 'Debug',
          codesigning_identity: ENV.fetch('SIGNING_IDENTITY'),
          export_method: 'development',
          output_directory: 'output',
          output_name: 'ci_development.ipa',
          archive_path: archive_path,
          export_options: {
            signingStyle: 'manual',
            teamID: ENV.fetch('TEAM_ID'),
            provisioningProfiles: {
              'com.hiclub.gravity' => 'Dev: Gravity',
              'com.hiclub.gravity.NotificationService' => 'Dev: Gravity NotificationService',
              'com.hiclub.gravity.AudioScreenCapture' => 'Dev: Gravity AudioScreenCapture'
            }
          }
        )
      end

      zip(path: archive_path, output_path: 'output/ci_development.xcarchive.zip')
    ensure
      delete_keychain(name: keychain_name) if keychain_created
    end
  end
end
```

这里把签名身份作为 `build_app` 的参数，而不是随意加到 export plist 中。Profile 映射依据当前确实存在的三个 target，不复制不存在的 Widget 目标。

临时 Keychain 不改成默认 Keychain，但添加搜索列表仍属于构建用户状态；因此实验先用独占账号和单 executor。 `ensure` 处理的是进程内退出路径，任务被强杀、agent 掉线或机器重启时不能保证执行；生产化还要有 Jenkins 收尾与节点恢复时的受控清理，只处理本任务创建的材料，不清空共享 Keychain 或全部 profile。官方 `install_provisioning_profile` 返回实际安装路径，部署时应记录路径/所有权并安排清理。实际生产化还需确认当前 Xcode 与 action 的安装位置、原有文件是否被覆盖，以及失败/取消后怎样处置临时材料，不能删除别的 Job 或开发账号的共享 profile。[F2–F3]**本次只核验流程和语法，没有使用任何私钥运行这个 lane。**

### 9.9 再加测试、Ad Hoc、App Store 与审批

1. 先建立可运行的测试 target / 共享 scheme，确认本地 `xcodebuild test` 成功；再接入 `scan` 和 JUnit XML，不用空测试报告装饰“CI 已完善”。
2. 为 Ad Hoc / App Store 分别准备相匹配的分发证书与 profile，核对主 App 和扩展，不把 Dev `.p12` 当作所有分发方式的通用材料。
3. 将 `build`、`upload`、`submit/release` 拆成显式动作，上传开关明确解析为布尔值；失败应保留日志并停止，不靠打印“上传中”代表实际上传。
4. App Store Connect `.p8` 由受控凭据提供，不再从仓库 fallback；先验证 TestFlight 上传，再考虑提审与发布审批。
5. 将 dSYM / archive 与构建 SHA、版本号关联，确认符号化流程，不只保留 IPA。
6. 完成备份恢复、证书轮换、Keychain 清理、磁盘空间、失败告警、并发隔离和权限检查后，才考虑把实验流程推广到既有平台。

## 10. 用故障现象反查打包与签名链路

| 现象 | 优先核对 | 不能靠什么解决 |
|------|----------|----------------|
| 找不到 signing identity | 构建用户、证书与配对私钥、Keychain 可访问性、证书有效期 | 只安装 `.cer` |
| 找不到 provisioning profile | 安装位置、App ID、签名证书、profile 类型与有效期、各扩展映射 | 只改 profile 文件名 |
| 本地成功、Jenkins 失败 | Xcode/Ruby/锁文件、PATH、构建用户、私有依赖、非交互 Keychain | 无条件 `sudo` 或把所有权限打开 |
| 主 App 能签，扩展失败 | 扩展 Bundle ID、entitlement、对应 profile、设备授权 | 只给主 App 配置签名 |
| Archive 成功，export 失败 | 导出方法、分发身份、目标 profile 与 App ID、实际 ExportOptions | 把 archive 文件 zip 一下 |
| IPA 生成成功，设备安装失败 | 签名完整性、profile 设备条件、权限、信任/有效期、安装渠道 | 把 zip 成功等同于验签成功 |
| TestFlight 上传失败 | 上传 API 凭据、IPA 路径、版本号、商店校验和服务端状态 | 更换开发 profile 代替上传认证 |
| 复选框关闭却上传 | Jenkins 参数有没有传到 Makefile/lane、大小写与字符串布尔值、隐式上传 | 只看 stage 名称或页面参数 |
| dSYM 无法符号化 | binary / dSYM UUID、平台处理后的制品关联、正确 archive | 只按文件名或 App 版本号匹配 |
| 任务绿灯但产物不对 | checkout SHA、实际 build number、失败是否被吞掉、产物验证是否接入 | 更多 `echo 'success'` |

签名解释应最终回到四个问题：**谁签的、签了什么、授权它做什么、当前运行环境是否接受这个授权。** Jenkins/Fastlane 的作用是把材料、命令、验证和发布资格按可追溯的顺序组织起来，不改变密码学和平台授权本身。

## 11. 资料与核验边界

### 11.1 原笔记与项目源码

本次核对日期为 **2026-11-05**。项目结论依据指定目录的本地工作树；它不是对线上 Jenkins 状态的认证，也不保证所有文件与当前 Git HEAD 完全一致。

- [N1] 原签名概念来源：[iOS 网络分层及网络协议完全学习指南](../05-网络与安全/iOS%20网络分层及网络协议完全学习指南.md)，iOS 签名章节；本文已纠正其中的“源码签名”“CSR 等于公钥”和固定三步验签等简化。
- [P1] `chat-ios/bin/Jenkins.groovy:1–169`。
- [P2] `chat-ios/Makefile:1–77`。
- [P3] `chat-ios/fastlane/Fastfile:18–185`。
- [P4] `chat-ios/fastlane/Appfile`、`fastlane/Pluginfile`；账号和令牌值不摘录。
- [P5] `chat-ios/Gemfile`、`Gemfile.lock`、`fastlane/Pluginfile`，包括工具声明与锁定版本的差异。
- [P6] `chat-ios/Chat.xcworkspace/contents.xcworkspacedata`、`Chat/Chat.xcodeproj/project.pbxproj`、共享 `Chat.xcscheme` 与各 `.entitlements`；解析 target/configuration/scheme 引用，不触发构建。
- [P7] 三份 `cer/Dev_Gravity*.mobileprovision` 的公开解码字段与其中证书 DER 的哈希；不摘录设备 UDID或私钥。
- [P8] `chat-ios/bin/update_build_number.sh:1–22`、`bin/update_version.sh:1–14` 及对应 plist 路径存在性。
- [P9] `chat-ios/ci.yml:1–33`、`build_submitter_scripts.sh:1–145`。

### 11.2 官方技术资料

- [A1] [Apple TN3161：Inside Code Signing — Certificates](https://developer.apple.com/documentation/technotes/tn3161-inside-code-signing-certificates)。证书、密钥、数字身份、信任链、CMS 与代码签名。
- [A2] [Apple TN3125：Inside Code Signing — Provisioning Profiles](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles)。授权维度、entitlement、分发差异与 DER profile。
- [A3] [Apple TN3126：Inside Code Signing — Hashes](https://developer.apple.com/documentation/technotes/tn3126-inside-code-signing-hashes)。资源摘要、CodeResources 与签名关联。
- [A4] [Apple：Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)。Archive、分发资产、TestFlight 与提审/发布。
- [A5] [Apple：Create a certificate signing request](https://developer.apple.com/help/account/certificates/create-a-certificate-signing-request/)，以及 [RFC 2986：PKCS #10](https://www.rfc-editor.org/rfc/rfc2986)。申请信息、公钥与请求签名的结构。
- [A6] [RFC 5280：X.509 Certificate and CRL Profile](https://www.rfc-editor.org/rfc/rfc5280)，第 4.1 节。证书和待签名证书内容的结构；不是推荐沿用其历史算法示例。
- [J1] [Jenkins：Using agents](https://www.jenkins.io/doc/book/using/using-agents/)。分布式执行模型。
- [J2] [Jenkins：Controller Isolation](https://www.jenkins.io/doc/book/security/controller-isolation/)。内置节点和 Controller 文件权限隔离。
- [J3] [Jenkins：Java Support Policy](https://www.jenkins.io/doc/book/platform-information/support-policy-java/)。按目标 core 版本与日期核对 JVM 支持。
- [J4] [Jenkins：Pipeline syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)，以及 [Credentials Binding](https://www.jenkins.io/doc/pipeline/steps/credentials-binding/)。参数、阶段、绑定与遮罩限制。
- [J5] [Jenkins：macOS 安装说明](https://www.jenkins.io/doc/book/installing/macos/)，以及 [macOS LTS 下载/安装说明](https://www.jenkins.io/download/lts/macos/)。实验安装与首次初始化。
- [F1] [fastlane：build_app / gym](https://docs.fastlane.tools/actions/build_app/)。Archive / export、多个 profile 的映射与输出。
- [F2] [fastlane：create_keychain](https://docs.fastlane.tools/actions/create_keychain/)，以及 [import_certificate](https://docs.fastlane.tools/actions/import_certificate/)。钥匙串创建、搜索列表与签名身份导入。
- [F3] [fastlane：install_provisioning_profile](https://docs.fastlane.tools/actions/install_provisioning_profile/)，以及 [delete_keychain](https://docs.fastlane.tools/actions/delete_keychain/)。安装路径与清理动作。
- [F4] [fastlane：app_store_connect_api_key](https://docs.fastlane.tools/actions/app_store_connect_api_key/)，以及 [upload_to_testflight / pilot](https://docs.fastlane.tools/actions/upload_to_testflight/)。API 认证、处理等待与上传/分发边界。
- [F5] [fastlane：setup_ci](https://docs.fastlane.tools/actions/setup_ci/)。临时 Keychain、只读 match 与 CI 路径；本文未把 match 的所有存储/加密实现当作已经审计。
- [F6] [fastlane 2.198.0 CLI parser](https://github.com/fastlane/fastlane/blob/2.198.0/fastlane/lib/fastlane/command_line_handler.rb)，以及 [固定当前源码提交的 parser](https://github.com/fastlane/fastlane/blob/70b08d70050c8675c95bc46cf672223a488a47c8/fastlane/lib/fastlane/command_line_handler.rb)。该提交时间为 2026-11-04T13:09:08Z；它不是未经查询的“最新发布版”。大写 FALSE 的行为是代码核验与 Ruby 真值语义推论，未在真实上传任务中执行。

### 11.3 已做和未做的验证

已做：读取原笔记与项目配置；解码三个 profile 的公开字段；解析 Xcode target/configuration 和 scheme；核对重要官方技术文档、RFC 与 fastlane parser；对文档示例做可离线完成的语法和布尔逻辑检查。

未做：读取/导出签名私钥；验证节点私钥是否与 profile 配对；访问现有 Jenkins；导出 Job/插件/Node 配置；执行 bundle 安装、真实 Xcode 构建、签名、设备安装、TestFlight/蒲公英上传；安装或启动 Jenkins。

因此，本文中的“实际链路”是**源码可证明的调用链**；平台额外包装、真实执行版本、账号与凭据绑定、构建/安装结果仍需现场核对。实验 Jenkinsfile 与 lane 是待落地的流程示例，不宣称已能在当前平台直接运行。
