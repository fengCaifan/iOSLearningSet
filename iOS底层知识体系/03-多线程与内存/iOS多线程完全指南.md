# iOS 多线程体系：pthread、GCD、Operation

> **一句话总结**：先把 **Mach 线程 / pthread** 当作「真·执行载体」，再在其上理解 **libdispatch（GCD）** 做队列与线程池调度，**NSOperationQueue** 在更高层做依赖、取消与并发度；日常选型按场景在 pthread / NSThread / GCD / Operation 间取舍。[锁与同步原语](锁的分类与性能对比.md)见专文；Swift 并发见 [Swift-并发模型](../01-语言基础/Swift-并发模型(async_await_Actor).md)。

---

## 📚 学习地图

- **预计学习时间**：约 70～90 分钟  
- **前置知识**：进程/线程概念、[RunLoop 与线程](../01-语言基础/OC-RunLoop原理与应用.md)、[内存管理与 AutoreleasePool](iOS内存管理完全指南.md)  
- **学习目标**：能画清「从内核线程到 GCD 队列」的路径 → 会写 pthread / NSThread / GCD / Operation 典型代码 → 能解释死锁、group、barrier、Operation 状态机  

素材对齐：`原始小集/multithreads.md`、`知识小集` 中多线程与锁相关章节。

---

## 目录

1. [多线程方案总览](#1-多线程方案总览)
2. [底层脉络：Mach 线程、pthread、libdispatch](#2-底层脉络mach-线程pthreadlibdispatch)
3. [pthread](#3-pthread)
4. [NSThread 与 performSelector](#4-nsthread-与-performselector)
5. [GCD（Grand Central Dispatch）](#5-gcdgrand-central-dispatch) — 含 libdispatch 实现向
6. [NSOperation 与 NSOperationQueue](#6-nsoperation-与-nsoperationqueue)
7. [技术选型汇总](#7-技术选型汇总)
8. [线程安全与相关专题](#8-线程安全与相关专题)
9. [高频面试题](#9-高频面试题)
10. [参考资料](#10-参考资料)

---

## 1. 多线程方案总览

Apple 平台常见「多线程」表达方式（从偏底层到偏业务）：

| 层面 | API / 抽象 | 典型用途 |
|------|------------|----------|
| POSIX | **pthread** | 与 C/C++ 互通、精细控制线程属性、未封装场景 |
| Foundation | **NSThread** | 简单显式线程、`threadDictionary`、与 NSObject 习惯写法结合 |
| Foundation | **performSelector:** / **performSelector:onThread:** | 老式「扔任务到某线程」；目标线程常需 **RunLoop** |
| C（系统） | **GCD / libdispatch** | 默认首选：队列、线程池、QoS、 barrier、group |
| Foundation | **NSOperationQueue** | 依赖图、取消、`maxConcurrentOperationCount`、可测试性 |
| Swift | **async/await、actor** | 结构化并发（另见 Swift 专文） |

---

## 2. 底层脉络：Mach 线程、pthread、libdispatch

以下为 **工程向心智模型**（精确到内核实现需结合 XNU / objc4 版本）：

```
┌─────────────────────────────────────────────────────────────┐
│ 进程（任务）                                                 │
│   Mach 层：内核调度实体（线程 / 调度优先级 / 端口等）          │
│        ↑ 用户态通过 pthread 抽象封装                          │
│   pthread：线程创建、join、互斥量、条件变量                    │
│        ↑ GCD 全局队列等工作项由 libdispatch 建在系统线程池上   │
│   libdispatch：队列 FIFO、worker 线程、QoS 映射               │
│        ↑ NSOperationQueue 再封装一层任务图与 KVO 友好状态     │
└─────────────────────────────────────────────────────────────┘
```

要点：

- **pthread** 是用户态标准线程 API，在 Apple OS 上与 **内核线程** 一一对应（可粗略记：pthread ≈ 可调度的执行流）。
- **GCD 的队列不是线程**：队列保存 **block/work item**；**libdispatch** 把 item 派发到 **线程池**中的某条 pthread 上执行（主队列则绑定主线程 + RunLoop）。
- **QoS（Quality of Service）** 会从队列/任务传递到实际执行线程，影响调度优先顺序与能耗（与「优先级反转」等问题相关，见 [锁的分类与性能对比](锁的分类与性能对比.md) 中 OSSpinLock / `os_unfair_lock` 讨论）。

---

## 3. pthread

### 3.1 何时考虑用 pthread？

- 与 **C/C++ 库、跨平台代码** 对接；
- 需要 **线程属性**（栈大小、detach 状态等）细调；
- 不想引入 **Objective-C runtime** 的极薄层逻辑。

多数 **应用业务** 仍推荐 **GCD / Operation**，少直接碰 `pthread_create`。

### 3.2 最小示例（C）

```c
#include <pthread.h>

static void *thread_main(void *ctx) {
    // 工作...
    (void)ctx;
    return NULL;
}

void start_worker(void) {
    pthread_t tid;
    int err = pthread_create(&tid, NULL, thread_main, NULL);
    if (err != 0) { /* handle */ }
    pthread_join(tid, NULL); // 或 detach，按设计选择
}
```

### 3.3 与 ObjC / Foundation 的关系

- **NSThread** 底层仍基于 **pthread**（可通过 `NSThread` 与系统 API 观察线程关系）。
- **RunLoop**、**AutoreleasePool**、**NSThreadPerformWaiting** 等都与「**哪条 pthread 在跑**」强相关：子线程若只有 **短时任务**且无 RunLoop，需注意 **autorelease 对象**释放节奏（见 [iOS内存管理完全指南 §6](iOS内存管理完全指南.md#6-autoreleasepool-原理与-runloop)）。

### 3.4 互斥与条件变量（与锁文档衔接）

`pthread_mutex_t`、`pthread_cond_t`、`pthread_rwlock_t` 等是 **POSIX 同步原语**；**NSLock / NSRecursiveLock / NSCondition** 等多为其封装。详细基准与选型见 [锁的分类与性能对比.md](锁的分类与性能对比.md)。

---

## 4. NSThread 与 performSelector

### 4.1 NSThread

```objective-c
// 方式一：分离线程执行 selector
[NSThread detachNewThreadSelector:@selector(backgroundWork)
                         toTarget:self
                       withObject:nil];

// 方式二：块 + 显式 start
NSThread *t = [[NSThread alloc] initWithBlock:^{
    // 注意 autoreleasepool、runloop 需求
}];
t.name = @"com.example.worker";
[t start];
```

常用 API：`+[NSThread currentThread]`、`+[NSThread isMainThread]`、**`threadDictionary`**（Per-thread 存储，类似 TLS 玩法）。

### 4.2 performSelector 系列

| 方法 | 注意点 |
|------|--------|
| `performSelector:` | 常在当前线程、同步执行（延迟版本依赖 RunLoop） |
| `performSelector:withObject:afterDelay:` | **依赖当前线程 RunLoop** |
| `performSelector:onThread:withObject:waitUntilDone:` | 目标线程 **须有 RunLoop** 且在跑，否则可能永远不执行 |

**常驻子线程** 典型模式：线程入口 `[[NSRunLoop currentRunLoop] run]`，再配合 `performSelector:onThread:` 投递（更现代写法多用 **GCD 队列** 替代）。

### 4.3 与 GCD 的取舍

- 需要「**明确 named 线程** + RunLoop + performSelector」的老代码 / 第三方库：NSThread 仍常见。
- 新业务：**串行队列** 往往比「自建 NSThread + 锁队列」更简单。

---

## 5. GCD（Grand Central Dispatch）

### 5.1 核心概念（对齐知识小集）

| 维度 | 说明 |
|------|------|
| **同步 / 异步** | `dispatch_sync` 会阻塞当前线程直到闭包结束；`dispatch_async` 立即返回 |
| **串行 / 并发队列** | 串行：同一时刻一块执行；并发：同一队列可派多个 block 到线程池 |
| **全局队列** | 系统并发队列，**QoS** 区分 `userInteractive` … `background` |
| **主队列** | 与主线程绑定，用于 UI；`dispatch_sync(main)` 在已在主线程时易死锁 |

> **易错纠正**：队列不等于线程。串行/并发描述同一队列任务之间能否同时执行；sync/async 描述提交任务的调用方是否等待 block 结束。除主队列固定由主线程执行外，任务在哪条 worker 线程运行、是否复用或创建线程均由系统调度；不要说“串行队列在当前线程执行”“并发/async 必开新线程”。

创建队列：

```objective-c
dispatch_queue_t serial = dispatch_queue_create("com.example.s", DISPATCH_QUEUE_SERIAL);
dispatch_queue_t concurrent = dispatch_queue_create("com.example.c", DISPATCH_QUEUE_CONCURRENT);
dispatch_queue_t global = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
dispatch_queue_t mainQ = dispatch_get_main_queue();
```

### 5.2 常用模式（代码示例）

#### 异步 + 切回主线程

```objective-c
dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
    NSData *data = [NSData dataWithContentsOfURL:url];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = [UIImage imageWithData:data];
    });
});
```

#### 延迟

```objective-c
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
               dispatch_get_main_queue(), ^{
    NSLog(@"1s later");
});
```

#### 单次初始化

```objective-c
static dispatch_once_t onceToken;
dispatch_once(&onceToken, ^{
    [self setupOnce];
});
```

#### Group（块内全是同步逻辑时）

```objective-c
dispatch_group_t group = dispatch_group_create();

dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
    NSLog(@"Task 1");
});
dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
    NSLog(@"Task 2");
});

dispatch_group_notify(group, dispatch_get_main_queue(), ^{
    NSLog(@"All done");
});

// 慎用：阻塞当前线程直到 group 完成
// dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
```

#### 信号量：限制并发数 / 线程间同步

```objective-c
dispatch_semaphore_t sem = dispatch_semaphore_create(2); // 最多 2 个并发

for (NSInteger i = 0; i < 10; i++) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        // 临界区或受控并发任务
        dispatch_semaphore_signal(sem);
    });
}
```

`wait` 不是只检查计数：它先尝试将计数减 `1`，原计数大于 `0` 则继续，原计数为 `0` 则阻塞等待；`signal` 将计数加 `1`，并可能唤醒一个等待者。实际代码应保证每个成功的 `wait` 都在成功、失败、取消、提前返回等路径中恰好对应一次 `signal`（Swift 中常用 `defer`）。不要在主线程 `wait` 网络或耗时任务结果：会阻塞 RunLoop、卡 UI；若回调也依赖主线程，可能永久等待。

### 5.3 QoS（与调度）

QoS 影响 **开始调度**的相对顺序与系统分配的计算资源；**不保证**「先开始必先结束」。与全局队列优先级相关的面试表述要严谨。

### 5.4 Barrier（栅栏）：多读单写

**并发队列 + barrier**：barrier 前已入队的并发任务可先跑完；barrier 块**独占**队列；barrier 后再继续并发读。适合保护**可变集合**的读多写少（知识小集「Dispatch_Barrier」场景）。

```objective-c
dispatch_queue_t q = dispatch_queue_create("com.example.rw", DISPATCH_QUEUE_CONCURRENT);

dispatch_async(q, ^{ /* read */ });
dispatch_barrier_async(q, ^{
    /* write：独占 */
});
```

> Swift 侧为 `DispatchQueue` 的 `.flags.barrier`；OC 为 `dispatch_barrier_async`。

**前提与边界**：Barrier 必须用于**自己创建的并发队列**。不能在 `DispatchQueue.global()` / 全局 root queue 上依赖它实现共享数据读写互斥，因为全局队列是系统共享资源，不是应用可控制的读写边界，其他提交到该队列的任务不受此 barrier 约束。若读缓存必须立即返回结果，可在不位于该队列内部时做极短的 `queue.sync` 读取；不要将磁盘 I/O 或网络置于临界区。

### 5.5 Group：`enter` / `leave`

`dispatch_group_async` 适合 **block 内同步工作**。若 block 里再开 **异步网络**，**不能**指望 group 自动等子异步结束，应配对：

```objective-c
dispatch_group_t g = dispatch_group_create();

dispatch_group_enter(g);
[self fetchAWithCompletion:^{
    dispatch_group_leave(g);
}];

dispatch_group_enter(g);
[self fetchBWithCompletion:^{
    dispatch_group_leave(g);
}];

dispatch_group_notify(g, dispatch_get_main_queue(), ^{
    // A、B 均完成
});
```

每个 `enter` 必须**恰好一次**对应 `leave`：成功、失败、取消和超时的最终收口均不能遗漏。若超时处理与正常 completion 可能竞态到达，应使用线程安全的“单次收口”标记防止重复 `leave`。不要以 `group.async { dataTask.resume() }` 代替：外层 block 会在 `resume()` 后立即返回，Group 不会等待 URLSession completion。

（与 `原始小集/multithreads.md` 一致。）

### 5.6 死锁典型场景（面试常画图）

1. **同一串行队列**：`async` 里再对该队列 `sync`（等待自己排空，互相等）。  
2. **同一串行队列**：`sync` 嵌套 `sync`。  
3. **主队列**：已在主线程时 `dispatch_sync(main, …)`。  
4. **NSOperation 依赖成环**：`A` 依赖 `B` 且 `B` 依赖 `A`，就绪条件永不满足。

避免方式不是机械地把所有 `sync` 改为 `async`，因为这会改变后续逻辑的完成时序。UI 耗时工作应组织为“主线程发起 → 后台 async 计算 → main.async 消费结果”，所有依赖结果的逻辑放在 completion 内。已经在某个串行队列中时，直接调用普通函数即可，不要再 `sync` 同一个队列；外部代码若确实需要同步读取极短状态，才在确认不位于该队列内部时使用 `sync`。

### 5.7 libdispatch 实现要点（源码向）

以下对齐 Apple 开源 **libdispatch**（Darwin 内置实现与 [swift-corelibs-libdispatch](https://github.com/apple/swift-corelibs-libdispatch) 可对读）的**常见结构**。具体符号、结构体字段随 **iOS / macOS 版本**会变，面试与源码阅读请以当前版本为准。

#### 5.7.1 Dispatch 对象与生命周期

- `dispatch_queue_t`、`dispatch_group_t`、`dispatch_semaphore_t`、`dispatch_source_t` 等均属 **dispatch 对象**，在现代系统中与 **`os_object`** 体系相关（纯 C 侧仍有 `dispatch_retain` / `dispatch_release`，与旧文档、MRC 工程习惯兼容）。
- 队列、source 等在 **引用计数归零** 时回收底层资源；**勿向已释放队列 async**（与任何 C 对象一样）。

#### 5.7.2 队列 ≠ 线程：FIFO 与 target queue

- 队列内部维护 **待执行的 work item 队列**（FIFO 语义对单队列成立）；`dispatch_async` 把 **Block（或 `dispatch_function_t`）** 挂入该结构。
- **用户创建的串行/并发队列**往往通过 **target queue 链** 挂到 **全局 root 队列（按 QoS 分桶）** 或特殊入口；可用 `dispatch_set_target_queue` **改变转发目标**（调高/调低优先级、合并到某一 serial 等高级用法）。
- **结论**：业务上的「我的串行队列」是 **调度边界**；真正跑在 **哪条 pthread** 上由 libdispatch **线程池 + 当时负载** 决定（主队列除外，见下）。

#### 5.7.3 串行 drain、并发 width、barrier 独占

- **串行队列（lane）**：同一时刻通常 **仅一条** item 处于**执行态**；内部 **`drain` / invoke** 循环逐项消耗。
- **并发队列**：存在 **并发宽度（width）** 概念（与 QoS、系统策略等相关），可同时向 worker **派发多条** item。
- **`dispatch_barrier_async`**：在**自己创建的并发队列**上，barrier item **独占**：先等此前已入队的并发 item 结束，再**单独执行** barrier，之后再继续接受后续 item —— 这是「多读单写」的底层基础。（**全局并发队列**上 barrier 行为无意义/不推荐，以文档为准。）

#### 5.7.4 主队列与全局 root 队列

- **`dispatch_get_main_queue()`**：与 **主线程 + Main RunLoop** 协作的特殊队列；向主队列提交的工作最终在主线程执行，与 UIKit 事件、CommonModes 中的 Source0/Timer 等 **交错**。
- **`dispatch_get_global_queue(QOS_…, 0)`**：对应某一 **全局 root 并发队列**；由系统维护 **worker 线程池**（底层仍是 **pthread**），线程数**动态**、**不可依赖**「恰好 N 条」。

#### 5.7.5 `dispatch_sync`：排队、阻塞与死锁

- `dispatch_sync` 必须把 block **排到目标队列**并 **等待其执行结束** 才返回当前调用线程。
- 在 **同一串行队列**上嵌套 `sync`（或主线程 `sync` 主队列），易导致 **自等待** → **死锁**；实现上多涉及 **条件变量 / 同步屏障路径**（源码中常见 `…sync_invoke…` 一类辅助符号）。
- 性能提示：`sync` **占用调用线程**，在高性能场景慎用；仅当需要「等队列上顺序执行完一小段逻辑」时使用。

#### 5.7.6 异步提交与 Block 生命周期

- `dispatch_async` 对 Block 通常执行 **堆拷贝**（语义等价 `Block_copy`），直到 item 执行完毕再释放；因此会 **延长被捕获对象的生存期**。
- 易踩坑：**短生命周期的控制器**被 block 强捕获**且**投递延迟，可能形成**泄漏或离谱生命周期**；配合 `__weak` 或显式打破环。

#### 5.7.7 `dispatch_semaphore`、`dispatch_once`（Darwin）

- **信号量**：Darwin 上传统实现贴近 **Mach 层同步**（阻塞与唤醒线程），适合「**限流 / 线程间 handshake**」；在 **QoS / 优先级** 场景仍可能遇到 **优先级反转** 问题，需结合系统演进与锁文档理解。
- **`dispatch_once`**：**全局一次性**初始化，基于 **原子状态**；必须使用 **静态存储期的 `dispatch_once_t`**，切忌每次创建新 token。

#### 5.7.8 `dispatch_source`（建立概念）

- 把 **内核或运行时事件**（定时、信号、可读写的 fd、Mach port 等）**楔入**某一 `dispatch_queue_t`，事件触发时在队列上执行 handler；与 RunLoop Source 同属 **「等服务 → 回调」** 心智模型，但 API 层不同。

### 5.8 GCD 底层 vs 使用层：怎么学

| 层次 | 你要掌握什么 |
|------|----------------|
| 使用层 | `async/sync`、队列类型、group、barrier、死锁模式、主线程回切 |
| 实现层 | 队列=FIFO item、target 链、串行 drain / 并发 width、主队列特殊、Block 拷贝 |
| 系统层 | pthread 执行体、QoS、Mach 与信号量（粗线条即可） |


## 6. NSOperation 与 NSOperationQueue

### 6.1 定位

- **NSOperation**：**「一个任务单元」**，可封装同步/异步执行体、优先级、依赖。  
- **NSOperationQueue**：调度器，决定何时 `start` 就绪的 operation；支持 **最大并发数**、**取消**、**暂停（suspended）** 等。

与 GCD 关系：**可理解为基于 libdispatch 等能力的更高层封装**；不要纠结「每一行是不是 GCD」，面试答 **「更高层抽象 + 依赖/取消/并发度」** 即可。

### 6.2 创建与基础用法

#### Block 与自定义 Operation

```objective-c
NSBlockOperation *op1 = [NSBlockOperation blockOperationWithBlock:^{
    NSLog(@"op1");
}];

@interface CustomOperation : NSOperation
@end
@implementation CustomOperation
- (void)main {
    if ([self isCancelled]) return;
    NSLog(@"custom");
}
@end
```

#### 队列与并发度

```objective-c
NSOperationQueue *queue = [[NSOperationQueue alloc] init];
queue.maxConcurrentOperationCount = 3; // 1 = 串行；-1 为系统默认
queue.name = @"com.example.queue";
queue.qualityOfService = NSQualityOfServiceUserInitiated;
[queue addOperation:op1];
```

#### 依赖：`1、2` 并行完成后执行 `3`

```objective-c
NSOperation *o1 = [NSBlockOperation blockOperationWithBlock:^{ NSLog(@"1"); }];
NSOperation *o2 = [NSBlockOperation blockOperationWithBlock:^{ NSLog(@"2"); }];
NSOperation *o3 = [NSBlockOperation blockOperationWithBlock:^{ NSLog(@"3"); }];

[o3 addDependency:o1];
[o3 addDependency:o2];

[queue addOperations:@[o1, o2, o3] waitUntilFinished:NO];
// 实际顺序：1 与 2 可并发，完成后 3
```

#### 取消

```objective-c
[queue cancelAllOperations];
[op1 cancel];
```

### 6.3 状态与取消（知识小集要点）

常见状态链路：`isReady` → `isExecuting` → `isFinished`；中途 `isCancelled`。

- **`cancel`**：最好在 **`main` / 执行体中轮询 `isCancelled`**；已开始且未协作检查的 **重计算** 仍可能继续跑一段。  
- **依赖**：`addDependency:` 必须**无环**，否则死锁。  
- **单独 `start`**：`NSBlockOperation` / `NSInvocationOperation` 的 `start` 在**当前线程同步**跑；**进队列**后才异步调度。

> **易错纠正**：`maxConcurrentOperationCount` 限制的是同时处于执行状态的 **Operation 数**，不等于固定线程数；底层执行线程仍由系统决定。`cancel()` 只是协作式取消信号，已开始的任务必须在开始、耗时循环、异步回调、写入共享状态和更新 UI 前检查 `isCancelled`。

> **依赖不等于成功**：`decode.addDependency(download)` 只保证 DownloadOperation 已结束；下载失败或取消后 DecodeOperation 仍可能开始，因此下游必须校验上游产物（如 `Data` / `UIImage`）是否有效。

### 6.4 异步 Operation 与 RunLoop（知识小集）

自定义 Operation 在 `main` 里发起 **异步回调**时，若 `main` 立刻返回，框架会认为 operation **已结束**。常见写法：**在 `main` 里等到异步完成**（或正确重写 `asynchronous` / `isExecuting` 等，见下方）。

一种教学用模式（简化，与知识小集一致）：

```objc
@interface SlowOperation : NSOperation
@property (nonatomic, assign) BOOL done;
@end

@implementation SlowOperation

- (void)main {
    if ([self isCancelled]) return;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        // 假装异步
        [NSThread sleepForTimeInterval:0.1];
        self.done = YES;
    });

    while (!self.done && !self.isCancelled) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate distantFuture]];
    }
}

@end
```

工程上更推荐：改用 **GCD + group** 或 **Operation 异步子类**正确维护 **KVO 状态**（`executing`/`finished`），避免忙等 RunLoop。

对 URLSession 这类回调式 API，普通 `main()` 在 `dataTask.resume()` 后马上返回，不能代表网络请求完成，会让队列过早释放并发名额。应实现异步 Operation：启动时将 `isExecuting` 置为 `true`；在成功、失败、取消和所有提前返回路径的**最终收口处恰好一次** `finish()`，同步将 `isExecuting` 置为 `false`、`isFinished` 置为 `true`。完整 Swift 代码见 [TableViewImageLoadingDemo](Demos/TableViewImageLoadingDemo/README.md)。

### 6.5 NSOperationQueue 与「主队列」

```objective-c
NSOperationQueue *mainQueue = [NSOperationQueue mainQueue]; // 主线程
```

URLSession 等 API 的 `delegateQueue` 常指定 `mainQueue` 或自定义队列。

### 6.6 GCD vs NSOperationQueue（特性对照）

| 特性 | GCD | NSOperationQueue |
|------|-----|------------------|
| API 形态 | C / Block | 面向对象 |
| 典型开销 | 更低 | 略高（一层抽象） |
| 任务依赖 | 需自行用 group / barrier 等拼 | **原生** `addDependency:` |
| 取消 | 无统一「取消闭包」语义 | **cancel** + 协作式轮询 |
| 并发度 | 常用 **semaphore** 等 | **`maxConcurrentOperationCount`** |
| 暂停整批任务 | 需自建 | **`suspended`** |
| 适用 | 轻量异步、系统级密集调度 | 复杂流程、可取消流水线、单测友好 |

### 6.7 实战：TableView 图片加载如何在 Operation 与 GCD 之间选型

图片加载不是“开一个后台线程下载”这么简单；一个请求通常至少包括：

```text
读内存缓存 → 网络下载 → 图片解码 / 降采样 → 写内存或磁盘缓存 → 主线程显示
```

先按职责划分，而不是机械地把所有步骤都包装为 `Operation`：

| 问题 / 阶段 | 更合适的抽象 | 原因 |
|---|---|---|
| 一张图片完整加载任务的排队、优先级、取消、总并发数 | `OperationQueue` + `Operation` | 这是有生命周期的工作单元，需要统一调度与取消 |
| Operation 内部的一段后台 CPU 工作（如解码） | GCD 并发队列或独立 `OperationQueue` | 简单场景 GCD 轻量；需要单独限流时再升为 Operation 阶段 |
| 内存缓存 Dictionary 的读多写少线程安全 | 自建并发 `DispatchQueue` + barrier；也可 `actor` / `NSCache` / 锁 | 本质是保护共享可变状态，不是任务依赖图 |
| 下载、解码、磁盘写分别有并发上限、优先级或重试要求 | 多个 `OperationQueue` + 依赖链 | 各阶段资源约束不同，适合独立编排 |

> **队列不按每张图片创建。** 一个列表 / 一个图片服务应共享 Loader 和它内部的队列；每张图片只创建一个或多个 **Operation** 加入共享队列。若每张图片各创建 `maxConcurrentOperationCount = 4` 的队列，60 张图仍可能同时运行 60 × 4 个任务，限流完全失效，缓存也无法共享。

#### 6.7.1 方案 A：每张图片一个异步 Operation（普通列表的优先选择）

适用条件：只需要限制“同时加载几张图”，下载、解码不要求分别限流；取消、优先级和任务生命周期希望统一管理。

```text
整个列表共享一个 ImageLoader
  ├── operationQueue（例如最多 4 个完整图片加载任务）
  ├── decodeQueue（GCD 并发队列）
  └── cacheQueue（GCD 并发队列：并发读 + barrier 写）

图片 A：ImageLoadOperation
  URLSession 下载 → decodeQueue 解码 → cacheQueue 写缓存 → main queue 回调 UI
```

此方案中 `ImageLoadOperation` **只有在解码、缓存等必要阶段结束后才 `finish`**。所以虽然解码放到了 GCD 队列，`operationQueue` 的上限仍会限制同时活跃的完整链路数。

对应可运行 Swift + UIKit Demo：[TableViewImageLoadingDemo/Demo 说明](Demos/TableViewImageLoadingDemo/README.md)。重点阅读 `ImageLoader.swift`、`ImageCell.swift`、`ImageListViewController.swift`。

**最小核心代码（Swift + UIKit，便于复习）**：Loader 只创建一次，因此一个列表的所有图片共享并发上限、解码队列与缓存。

```swift
final class ImageLoader {
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.example.image-loader.operations"
        queue.maxConcurrentOperationCount = 4 // 限制完整图片加载链路，而非队列容量
        return queue
    }()

    private let decodeQueue = DispatchQueue(
        label: "com.example.image-loader.decode",
        qos: .userInitiated,
        attributes: .concurrent
    )

    private let cacheQueue = DispatchQueue(
        label: "com.example.image-loader.cache",
        attributes: .concurrent
    )
    private var memoryCache: [String: UIImage] = [:]

    @discardableResult
    func loadImage(url: URL, completion: @escaping (UIImage?) -> Void) -> ImageRequest {
        let key = url.absoluteString

        // 仅做极短的内存读；不要在这里做磁盘 I/O 或网络。
        if let cached = cacheQueue.sync(execute: { memoryCache[key] }) {
            DispatchQueue.main.async { completion(cached) }
            return ImageRequest()
        }

        let operation = ImageLoadOperation(url: url, decodeQueue: decodeQueue) { [weak self] image in
            guard let self, let image else { return }
            // Dictionary 写入必须独占；Operation 结束前保证缓存已写完。
            self.cacheQueue.sync(flags: .barrier) { self.memoryCache[key] = image }
            DispatchQueue.main.async { completion(image) }
        }
        operationQueue.addOperation(operation)
        return ImageRequest(operation: operation)
    }
}
```

一张图对应一个异步 Operation。以下省略了 `NSLock` 保护的 KVO 状态细节（完整实现见 Demo），重点是：请求真正完成前不能 `finish()`；下载回调和解码阶段都需要检查协作式取消。

```swift
final class ImageLoadOperation: AsyncOperation {
    private let url: URL
    private let decodeQueue: DispatchQueue
    private var task: URLSessionDataTask?

    override func execute() {
        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            guard !self.isCancelled, error == nil, let data, !data.isEmpty else {
                self.finish(); return
            }

            self.decodeQueue.async {
                guard !self.isCancelled, let image = self.decode(data) else {
                    self.finish(); return
                }
                self.completion(image) // Loader 再写缓存并回主线程
                self.finish()
            }
        }
        task?.resume()
    }

    override func cancel() {
        super.cancel()
        task?.cancel() // 已经在路上的 completion 仍可能到达
    }
}
```

Cell 必须保存请求句柄（强引用，便于取消），但回调**弱引用 Cell**，并在最终赋图前检查 Cell 当前身份：

```swift
final class ImageCell: UITableViewCell {
    var representedURLString: String?
    var imageRequest: ImageRequest? // strong：Cell 需要用它 cancel

    override func prepareForReuse() {
        super.prepareForReuse()
        imageRequest?.cancel()
        imageRequest = nil
        representedURLString = nil
    }
}

// cellForRowAt:
cell.representedURLString = url.absoluteString
cell.imageRequest = imageLoader.loadImage(url: url) { [weak cell] image in
    guard let cell, cell.representedURLString == url.absoluteString else { return }
    cell.imageView?.image = image
}
```

#### 6.7.2 异步 Operation：URLSession 为什么不能只覆写 `main()`？

以下写法是错误示意：

```swift
final class WrongDownloadOperation: Operation {
    override func main() {
        URLSession.shared.dataTask(with: url) { _, _, _ in
            // 网络回调还没发生
        }.resume()
        // main 返回，OperationQueue 已误认为 Operation 完成
    }
}
```

`URLSessionDataTask` 是回调式异步任务，`main()` 返回不代表网络完成。若不处理，下载队列会提前释放并发名额，限流失真。

正确方式是实现异步 Operation：

```text
isReady → isExecuting → isFinished
                    ↘ isCancelled
```

1. 声明 `isAsynchronous == true`；
2. 开始请求时 KVO 通知 `isExecuting = true`；
3. 无论成功、失败还是取消，在网络 completion 的最终收尾处**恰好一次**通知 `isExecuting = false`、`isFinished = true`；
4. `cancel()` 除设置 Operation 的取消标记外，还应 `URLSessionTask.cancel()`；任务各阶段继续协作检查 `isCancelled`。

不要通过 RunLoop 循环或忙等来“阻塞到异步回调结束”；正确维护 Operation 的 KVO 状态更可靠、更节能。

#### 6.7.3 方案 B：下载、解码、缓存为独立 Operation（独立资源约束）

当需求变为：**最多 6 个网络下载、最多 2 个图片解码、磁盘缓存写入必须串行**，方案 A 不再适合。此时应让每个阶段拥有自己的共享队列和上限：

```text
同一张图片：
DownloadOperation ──dependency──> DecodeOperation ──dependency──> CacheWriteOperation
     ↓                                   ↓                                  ↓
downloadQueue(6)                    decodeQueue(2)                 cacheWriteQueue(1)
```

```swift
decode.addDependency(download) // Decode 等 Download 结束
cache.addDependency(decode)    // Cache 等 Decode 结束

downloadQueue.addOperation(download)
decodeQueue.addOperation(decode)
cacheWriteQueue.addOperation(cache)
```

不同图片可以形成流水线：A 在解码时，B～G 仍可下载；但任一图片内部仍严格遵守下载 → 解码 → 缓存的依赖顺序。

**依赖只表示“上游已结束”，不表示“上游成功”。** 因此下载失败或取消后，`DecodeOperation` 仍可能变为就绪状态；它的 `main()` 必须检查上游产出的 `Data` 是否存在、自己是否已取消。缓存阶段同样检查是否有有效 `UIImage`。

对应可运行 Swift + UIKit Demo：[SplitImagePipelineDemo/Demo 说明](Demos/SplitImagePipelineDemo/README.md)。重点阅读 `AsyncOperation.swift` 和 `SplitImagePipeline.swift`。

**分阶段 Pipeline 核心代码**：三个队列是 Pipeline 的共享属性；每个 URL 创建三个 Operation，分别加入对应队列，而不是“一张图创建三个 Queue”。

```swift
final class SplitImagePipeline {
    private let downloadQueue = makeQueue(name: "download", maxConcurrent: 6)
    private let decodeQueue = makeQueue(name: "decode", maxConcurrent: 2)
    private let cacheWriteQueue = makeQueue(name: "cache-write", maxConcurrent: 1)

    func loadImage(url: URL, completion: @escaping (UIImage?) -> Void) -> SplitImageRequest {
        let context = ImagePipelineContext() // 在三个阶段间安全传递 Data / UIImage
        let download = DownloadOperation(url: url, context: context)
        let decode = DecodeOperation(context: context)
        let cache = CacheWriteOperation(context: context, completion: completion)

        decode.addDependency(download) // 上游结束后 Decode 才能开始
        cache.addDependency(decode)    // Decode 结束后 Cache 才能开始

        downloadQueue.addOperation(download) // 网络最多 6 个
        decodeQueue.addOperation(decode)     // 解码最多 2 个
        cacheWriteQueue.addOperation(cache)  // 磁盘写最多 1 个
        return SplitImageRequest(operations: [download, decode, cache])
    }
}
```

下游 Operation 的关键不是只依赖，而是还要验证上游产物：

```swift
final class DecodeOperation: Operation {
    let context: ImagePipelineContext

    override func main() {
        // dependency 不能代表下载成功：下载失败 / 取消也会“结束”。
        guard !isCancelled,
              let data = context.data,
              let source = UIImage(data: data) else { return }

        let image = decodeAndDownsample(source) // 后台 OperationQueue 执行
        guard !isCancelled else { return }
        context.image = image
    }
}

final class CacheWriteOperation: Operation {
    override func main() {
        guard !isCancelled, let image = context.image else { return }
        writeDiskCache(image) // 由 maxConcurrentOperationCount = 1 串行控制
        guard !isCancelled else { return }
        DispatchQueue.main.async { completion(image) }
    }
}
```

#### 6.7.4 缓存写阶段与缓存线程安全是两个维度

下面两个队列看起来都与缓存有关，却解决不同问题：

```text
cacheWriteQueue（OperationQueue，max = 1）
  → 控制“缓存写入”业务阶段，例如图片编码、磁盘文件 I/O、索引更新；防止写放大

memoryCacheQueue（GCD concurrent queue + barrier）
  → 保护共享的内存 Dictionary；读取可并发，写入必须独占
```

若仅仅是写一个内存 Dictionary，通常不值得额外建立 `CacheWriteOperation`；`NSCache`、Swift `actor`、锁、串行队列或 concurrent queue + barrier 已足够。Demo 中保留缓存写 Operation，仅用于展示阶段级限流。

#### 6.7.5 Cell 复用、取消与错图防护

`cancel()` 是**协作式取消**，并不会抹掉一个已经回到主线程的 completion。因此完整防护链是：

```text
Cell 配置 URL-A：记录 representedURLString = A，保存 ImageRequest
  ↓
Cell 离屏 / prepareForReuse：取消 ImageRequest（进一步取消 Download / Decode / Cache Operation）
  ↓
网络回调、解码开始前/后、缓存写前：检查 isCancelled
  ↓
回主线程赋图前：再次比较 cell.representedURLString 是否仍为 A
  ↓
匹配才显示图片
```

最后一步不可省略：Cell 可能已从 URL-A 复用为 URL-B，而 A 的回调在取消后仍有机会晚到。回调应弱引用 Cell / Controller，避免异步任务不必要地延长 UI 对象生命周期。

#### 6.7.6 `dispatch_group` 在图片加载中的位置

单个 Cell 加载通常无需 Group。若首屏要求“整批图片下载、解码、缓存完成后只刷新一次”，对**每张图片完整流程**调用一次 `enter`，并在最后一阶段完成（或失败/取消收尾）时**恰好一次** `leave`：

```swift
group.enter()
pipeline.loadImage(url: url) { image in
    defer { group.leave() }
    // 处理当前结果
}
group.notify(queue: .main) {
    // 本批所有流程均收口
}
```

不能只用 `group.async` 包住 `URLSessionDataTask` 的创建；创建 task 后外层 block 就返回了，Group 不会自动等待网络 completion。

---

## 7. 技术选型汇总

| 需求 | 更倾向 |
|------|--------|
| 轻量异步、延迟、一次性初始化 | **GCD** |
| 读多写少共享可变状态 | **并发队列 + barrier**（或串行队列一把锁） |
| 多异步任务汇总回调 | **group enter/leave** 或 **Operation 依赖** |
| 依赖图、取消、并发度、可测试 | **NSOperationQueue** |
| 图片整体加载限流、优先级和取消 | **共享 OperationQueue + 每图一个异步 Operation** |
| 下载 / 解码 / 磁盘写有独立并发资源约束 | **多个共享 OperationQueue + 依赖链** |
| 内存缓存读多写少 | **concurrent DispatchQueue + barrier**（或 `NSCache` / actor） |
| C 库、线程属性、join 语义 | **pthread** |
| 与旧代码 RunLoop / performSelector 集成 | **NSThread + RunLoop** |

---

## 8. 线程安全与相关专题

- **锁、信号量、自旋锁演进**：见 [锁的分类与性能对比.md](锁的分类与性能对比.md)。  
- **用串行队列替代锁**：注意 **死锁**（勿在持队列时 `sync` 同队列）。  
- `atomic`：**仅保证属性 setter/getter 调用**的原子性，**不保证**对象内部字段与业务逻辑原子。  
- **AutoreleasePool 与 子线程**：见 [iOS内存管理完全指南](iOS内存管理完全指南.md)。

---

## 9. 高频面试题

| 问题 | 答案要点 |
|------|----------|
| iOS 常见多线程方案？ | pthread、NSThread、performSelector、GCD、Operation、Swift 并发 |
| pthread 与 GCD？ | pthread 管「线程实体」；GCD 管「任务队列 + 线程池」 |
| `sync` 与 `async`？ | sync 阻塞当前线程直到 block 执行完；async 只入队 |
| 如何避免 GCD 死锁？ | 勿向**同一串行队列**嵌套 sync；勿主线程 sync 主队列 |
| barrier？ | 并发队列上的写独占点，多读单写 |
| group 与异步网络？ | `enter`/`leave` 配对，或改同步子步骤 |
| GCD vs NSOperationQueue？ | 轻量/性能 vs 依赖、取消、maxConcurrent |
| Operation 取消为何「不灵」？ | 须执行体检查 `isCancelled` |
| 主队列与 RunLoop？ | 主队列任务由主 RunLoop 取出执行 |
| `dispatch_async` 为何常伴 Block_copy？ | 异步 item 存活到执行完毕，堆上持有 Block |
| 全局队列有几条线程？ | **由系统决定**，勿写死假设 |

---

## 10. 参考资料

- Apple：[Dispatch Queues](https://developer.apple.com/documentation/dispatch)、[Thread Management](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/ThreadManagement/ThreadManagement.html)  
- 开源：[apple/swift-corelibs-libdispatch](https://github.com/apple/swift-corelibs-libdispatch)（与 Darwin 内置实现高度同源，便于读队列/drain/target）  
- 站内：`读书笔记/iOS自学笔记/原始小集/multithreads.md`  
- 延伸阅读：  
  - [iOS 面试题 | GCD 和 NSOperation 有啥区别？](https://juejin.cn/post/7360879591235551266)  
  - [iOS多线程之GCD、OperationQueue 对比和实践记录](https://cloud.tencent.com/developer/article/1692252)  
  - [iOS多线程之四：NSOperation的使用](https://cloud.tencent.com/developer/article/1334777)  

---

**最后更新**：2026-04-07  
**状态**：✅ pthread / NSThread / GCD（含 libdispatch 实现向）/ Operation
