# 单元测试与 UI 测试

> 一句话总结：**单测保「逻辑与回归」，依赖可注入与稳定边界；UI 测保「关键路径"，用 accessibility 与录制维护，二者都讲「稳定、快速、可重复」。**

---

## 1. 核心概念

### 1.1 XCTest 家族

| 类型 | 用途 |
|------|------|
| **Unit Test** | 纯函数、ViewModel、Parser、路由注册表等 |
| **UI Test** | XCUITest 驱动真实 App，走登录/支付等黄金路径 |
| **Performance** | `measure {}` 基线化关键算法 |

### 1.2 FIRST 原则（单测）

- **Fast**、**Independent**、**Repeatable**、**Self-Validating**、**Timely**。

---

## 2. 底层原理与实践

### 2.1 可测试性来自架构

- **依赖注入**：网络、时钟、随机数、UserDefaults 抽象成协议，测试时换 `Mock`。
- **纯函数优先**：输入确定 → 输出确定，无需 mock 系统。
- **异步**：`XCTestExpectation` + `wait(for:timeout:)`；Swift `async` 测试用 `@MainActor` 或 `await`。

### 2.2 Mock / Stub

- 只对**直接依赖** mock；避免过度 mock 导致「测的是假对象」。
- 网络：本地 `URLProtocol` stub 或依赖 **OHHTTPStubs** 类库（团队规范允许时）。

### 2.3 UI 测试

- 给关键控件设 **accessibilityIdentifier**，避免文案变化即碎测。  
- **启动参数**：`app.launchArguments` 注入测试账号、关闭动画。  
- 长流程拆分 **多个用例** + 共享 `setUp`；失败截图与会话日志。

### 2.4 覆盖率

- Xcode `Code Coverage` 看趋势，不唯覆盖率；核心模块优先 **分支覆盖**。

---

## 3. 关键问题 & 面试题

- **单测与 TDD 价值？** 重构安全带、文档化行为、减少回归。  
- **哪些不适合单测？** 强 UI 布局细节交给快照或 UI 测；与系统紧耦合的用集成测。  

---

## 4. 实战清单

- [ ] CI 上跑 `xcodebuild test`（模拟器矩阵选 1~2 个代表性 OS）  
- [ ] 测试数据 **fixtures** 放 bundle，避免依赖外网  
- [ ] 核心解析 / 金额 / 权限判定的 **边界用例**  

---

## 5. 参考资料

- [XCTest - Apple](https://developer.apple.com/documentation/xctest)
- [Testing in Xcode - WWDC](https://developer.apple.com/videos/frameworks/testing)
