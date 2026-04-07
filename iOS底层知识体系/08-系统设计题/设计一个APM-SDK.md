# 设计一个 APM-SDK

> 一句话总结：**APM = 信号采集（卡顿/FPS/内存/启动/网络/崩溃） + 队列持久化 + 批量上报 + 后台符号化与聚合；设计重点是低开销、可解释、隐私合规。**

---

## 1. 需求澄清

| 类型 | 指标 |
|------|------|
| **崩溃** | Mach Exception / Signal / Uncaught NSException，栈回溯与 dSYM |
| **卡顿** | 主线程 RunLoop / 子线程 ping、阈值与采样 |
| **启动** | pre-main / first screen / 关键接口首包 |
| **性能** | 电池、CPU、内存 foot print、关键 VC 耗时 |
| **网络** | 成功率、耗时、DNS/TLS 分段（若可） |

---

## 2. 架构

```text
Probe（Hook / RunLoop Observer / Method Swizzle）
    → EventNormalizer（打标签 session、user、build）
    → DiskQueue（SQLite / 文件 + 限长）
    → Uploader（batch + gzip + 退避）
    → Dashboard（服务端聚合，不在客户端）
```

### 2.1 卡顿（旧笔记《卡顿、崩溃》）

- **FPS**：`CADisplayLink` 估帧，适合仪表盘，不易定位栈。  
- **RunLoop Observer**：监听 BeforeSources / AfterWaiting + 子线程 + 信号量，**超时计数**认为卡顿。  
- **堆栈**：`NSThread.callStackSymbols` 粗；线上常见 **PLCrashReporter** / 自研基于 `backtrace` + 自建存储。

### 2.2 崩溃

- **`NSSetUncaughtExceptionHandler`** + Signal（SIGABRT/SIGSEGV…）注册；注意 **嵌套崩溃** 与 handler 内安全代码。
- 崩溃瞬间写 **原子写文件**，下次启动上报。

### 2.3 启动监控

- pre-main：`DYLD_PRINT_STATISTICS`（调试）+ 生产用 **method trace/自定义阶段埋点**。  
- 业务冷启动：从 `main` → 首屏渲染 / 首接口。

### 2.4 内存

- 定时 `phys_footprint`（`task_info`）采样；结合 **OOM 退出原因**（Jetsam）只能用间接指标 + 前后台切换。

---

## 3. 隐私与性能

- 默认可关闭详细上报；敏感字段 hash/截断。  
- **异步 + 合并**；避免在 RunLoop 回调里做重 I/O。  
- Swizzle 需 **幂等、白名单类**，减少意外副作用。

---

## 4. 面试题

- **卡顿与 ANR 区别？** iOS 无 Android 式 ANR，但 Watchdog 会杀；监控目标是主线程卡死时长。  
- **如何避免监控本身卡主线程？** 堆栈采集线程、限制频率、临界区无锁数据结构。  

---

## 5. 参考资料

- 旧笔记：`读书笔记/iOS自学笔记/专题——卡顿、崩溃.md`
- [PLCrashReporter](https://github.com/microsoft/plcrashreporter)
- 《卡顿优化-监控与治理》与《APM-崩溃收集与符号化》同目录笔记
