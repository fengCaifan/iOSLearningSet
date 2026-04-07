# APM-卡顿与内存监控

> 一句话总结：**卡顿监控看「主线程是否按期拍心跳」；内存监控看 footprint 曲线与泄漏，配合 Instruments 与线上采样，避免监控代码本身伤性能。**

---

## 1. 核心概念

### 1.1 卡顿

- **帧视角**：`CADisplayLink` 估 FPS，适合大盘，不好归因。  
- **RunLoop 视角**：`CFRunLoopObserver` + 子线程定时器/信号量，主线程每圈应 `signal`；超时认为 stall（见《卡顿优化》与旧笔记代码思路）。  
- **子线程 ping**：周期性 `dispatch_async` 主线程设标志，监控线程 sleep 阈值后检查标志是否清除。

### 1.2 内存

- **Footprint**：`task_vm_info` 的 `phys_footprint` 近似进程 RAM 压力。  
- **泄漏**：`Leaks` / Memory Graph / `FBRetainCycleDetector`（工程化场景）。  
- **OOM**：多为间接证据（Jetsam 前 snapshot、大分配事件、前后台切换）。

---

## 2. 采集设计

### 2.1 栈回溯

- 卡顿时抓取主线程 **bt**；线上可用 **PLCrashReporter** 生成 **live report**，再符号化。  
- 注意 **隐私**：栈内可能含业务参数，上报前过滤。

### 2.2 批量与节流

- **1 分钟窗口聚合**：连续 stall 合成一条；带起止时间与若干栈样本。  
- 降采样：仅部分用户开启深度监控。

### 2.3 与滑动列表结合

- FPS 掉帧 + **主线程 RunLoop** 双重印证，定位是布局还是某次 sync 请求。

---

## 3. 关键问题 & 面试题

- **和 Watchdog 区别？** Watchdog 是系统杀进程；APM 是在被杀前自我发现热点。  
- **RunLoop 监控的注意点？** Observer 安装时机、`commonModes`、退后台暂停统计。  

---

## 4. 实战清单

- [ ] Debug 用 Instruments：**Time Profiler + Activity Monitor + Leaks**  
- [ ] Release 用 **低开销 heartbeat**，禁用 `NSThread.callStackSymbols` 的高频路径  
- [ ] 与 **崩溃 SDK** 共用 session id  

---

## 5. 参考资料

- 旧笔记：`读书笔记/iOS自学笔记/专题——卡顿、崩溃.md`（卡顿检测多方案）  
- 《卡顿优化-监控与治理》  
- [PLCrashReporter](https://github.com/microsoft/plcrashreporter)
