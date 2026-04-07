# CI-CD 与自动化

> 一句话总结：**CI 把「构建-单测-静态分析-打包」自动化；CD 把「分发内测 / 提交商店」流水线化；iOS 常见组合是 Xcode Cloud 或自建 Runner + `xcodebuild`/`fastlane`。**

---

## 1. 核心概念

| 环节 | 目标 |
|------|------|
| **Integrate** | 每次 MR 编译通过、单测绿、Lint 无新增致命问题 |
| **Deliver** | TestFlight 内部测试、生产发布可重复回滚 |
| **Sign** | 证书与 Profile 由服务或 `match` 仓库托管，避免个人机器 |

---

## 2. 流水线设计

### 2.1 典型 Job 顺序

1. `git clone` → `bundle install`（若用 Ruby 工具链）  
2. `pod install` / `spm resolve`  
3. **Lint**：SwiftLint、clang-format（团队择一）  
4. **Unit Test**：`xcodebuild test -scheme ... -destination 'platform=iOS Simulator,name=iPhone 16'`  
5. **Build Archive**：`xcodebuild archive` 或 `gym`（fastlane）  
6. **Export IPA** + **upload** TestFlight / 企业分发平台

### 2.2 证书与变量

- GitLab CI / GitHub Actions **受保护变量**存 `APP_STORE_CONNECT_API_KEY`、证书密码。  
- 推荐 **fastlane match** 或 Xcode Cloud 的托管签名。

### 2.3 CocoaPods 私有库（旧笔记摘录）

- `pod repo add <specs>` 同步私有 spec 仓库；`pod spec` CI 校验版本号与 tag 一致。

### 2.4 效能优化

- **DerivedData** 缓存、**Module Cache**、并行 Simulator；大团队可分 **build 与 test** job。

---

## 3. 关键问题 & 面试题

- **CI 与本地环境不一致？** 锁定 Xcode 版本、用 `xcode-select`、Docker 难以跑真 iOS，多在 macOS Runner。  
- **flutter 混合工程？** 先在 CI 装 Flutter SDK，再执行 `flutter build ios` 或由宿主工程驱动。  

---

## 4. 实战清单

- [ ] PR 必须通过 **build + test** 才能合并  
- [ ] `main` 分支夜间 **静态分析与覆盖率** 报表  
- [ ] 发布标签触发 **自动 ship**  

---

## 5. 参考资料

- [Xcode Cloud - Apple](https://developer.apple.com/xcode-cloud/)
- [fastlane](https://docs.fastlane.tools)
- 旧笔记：`读书笔记/组件化实践/cocopod组件化笔记.md`
