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

（与 `原始小集/multithreads.md` 一致。）

### 5.6 死锁典型场景（面试常画图）

1. **同一串行队列**：`async` 里再对该队列 `sync`（等待自己排空，互相等）。  
2. **同一串行队列**：`sync` 嵌套 `sync`。  
3. **主队列**：已在主线程时 `dispatch_sync(main, …)`。  
4. **NSOperation 依赖成环**：`A` 依赖 `B` 且 `B` 依赖 `A`，就绪条件永不满足。

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

---

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

---

## 7. 技术选型汇总

| 需求 | 更倾向 |
|------|--------|
| 轻量异步、延迟、一次性初始化 | **GCD** |
| 读多写少共享可变状态 | **并发队列 + barrier**（或串行队列一把锁） |
| 多异步任务汇总回调 | **group enter/leave** 或 **Operation 依赖** |
| 依赖图、取消、并发度、可测试 | **NSOperationQueue** |
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
