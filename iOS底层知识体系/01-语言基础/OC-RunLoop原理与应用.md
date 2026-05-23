# OC RunLoop 原理与应用

> 一句话总结：**RunLoop 是一个运行循环，可以让线程在有事做的时候做事，无事做的时候休息，节省 CPU 资源。**

---

## 📚 学习地图

- **预计学习时间**：30 分钟
- **前置知识**：多线程基础
- **学习目标**：理解 RunLoop → 实战场景与代码 → 面试题与常见陷阱

---

## 1. 核心概念

### 1.1 什么是 RunLoop？

**RunLoop** 是一个运行循环，可以让线程在有事做的时候做事，无事做的时候休息，节省 CPU 资源。

**工作模式**：
- **有事做时**：将线程唤醒，处理事件/消息（内核态 ——> 用户态）
- **无事做时**：将线程休眠，不占用 CPU（用户态 ——> 内核态）

**关键术语**：

| 术语 | 说明 |
|------|------|
| **用户态** | 系统上层应用程序活动的空间 |
| **内核态** | 内核资源，为上层应用提供资源 |
| **事件循环（Event Loop）** | 不断接收和处理事件、消息的循环机制 |

### 1.2 RunLoop 的作用

| 作用 | 说明 |
|------|------|
| **保证程序不退出** | 通过事件循环维持程序持续运行 |
| **监听事件** | 网络事件、定时器事件、触摸事件 |
| **定时渲染 UI** | 每个 RunLoop 期间，被标记为需要重绘的 UI 都会进行重绘 |
| **调节 CPU 工作** | 在工作和休眠状态间切换，优化资源使用 |

### 1.3 核心结论

| 结论 | 说明 |
|------|------|
| **主线程** | RunLoop 默认开启，永不退出 |
| **子线程** | RunLoop 默认不创建，需要手动获取和启动 |
| **没有 RunLoop 的线程** | 执行完任务后立即销毁 |

---

## 2. 底层原理

### 2.1 核心结构

NSRunLoop 是对 CFRunLoop 的 OC 封装，核心数据结构包括：

#### CFRunLoop 源码简化

```c
struct __CFRunLoop {
    CFRuntimeBase _base;
    pthread_t _pthread;                // 所属线程
    CFMutableSetRef _commonModes;      // 通用 Mode 集合
    CFMutableSetRef _commonModeItems;  // 通用 Mode 的 Item
    CFRunLoopModeRef _currentMode;     // 当前运行的 Mode
    CFMutableSetRef _modes;            // 所有 Mode 的集合
};
```

#### 结构图

```
┌─────────────────────────────────────────────┐
│              CFRunLoop                       │
│  pthread: 主线程 / 子线程                    │
├─────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐     │
│  │ Mode1   │  │ Mode2   │  │ Mode3   │     │
│  │(Default)│  │(Tracking)│  │ (Common) │    │
│  └─────────┘  └─────────┘  └─────────┘     │
│       │            │            │           │
│       ▼            ▼            ▼           │
│  ┌─────────────────────────────────────┐   │
│  │  Source0     Source1                │   │
│  │  (非Port)    (Port)                  │   │
│  │  Timers                             │   │
│  │  Observers                          │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

#### CFRunLoopMode

```c
struct __CFRunLoopMode {
    CFStringRef _name;               // Mode 名称
    CFMutableSetRef _sources0;       // Source0 集合
    CFMutableSetRef _sources1;       // Source1 集合
    CFMutableSetRef _observers;      // Observer 集合
    CFMutableSetRef _timers;         // Timer 集合
};
```

### 2.2 Mode 机制

#### Mode 说明

| Mode | 说明 |
|------|------|
| DefaultMode | 所有通知都响，处理大部分事件 |
| TrackingMode | 滑动 UIScrollView 时，只处理滚动相关事件 |
| CommonModes | 不是真正的 Mode，而是一个集合（默认包含 Default + Tracking） |

#### Mode 类型

| Mode 名称 | 常量 | 使用场景 |
|-----------|------|----------|
| **DefaultMode** | NSDefaultRunLoopMode | 大部分时间 |
| **TrackingMode** | UITrackingRunLoopMode | 滑动时自动切换 |
| **CommonModes** | NSRunLoopCommonModes | 需要同时在 Default 和 Tracking 下生效 |
| **InitializationMode** | UIInitializationRunLoopMode | App 启动时，之后不再使用 |
| **GSEventReceiveMode** | GSEventReceiveRunLoopMode | 系统内部接收事件 |

#### 为什么 NSTimer 在滑动时会停止？

**原因**：
- NSTimer 默认加入 DefaultMode
- 滑动时 RunLoop 切换到 TrackingMode
- Timer 在 TrackingMode 下不会被处理

**解决方案 1**：加入 CommonModes

```objective-c
NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(timerTick) userInfo:nil repeats:YES];
[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
```

**解决方案 2**：使用 GCD 定时器（不依赖 RunLoop）

```objective-c
dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC, 0);
dispatch_source_set_event_handler(timer, ^{
    NSLog(@"滑动时也能执行");
});
dispatch_resume(timer);
```

### 2.3 Source0 vs Source1

#### 定义

| 类型 | 说明 | 例子 |
|------|------|------|
| Source0 | 非基于 port 的事件源，需要手动唤醒 RunLoop | UI 事件、performSelector |
| Source1 | 基于 mach_port 的事件源，能自动唤醒 RunLoop | 系统事件、触摸事件、Port 消息 |

#### 事件处理流程

```
硬件触摸事件
    ↓
内核发送 mach_port 消息（Source1 自动唤醒）
    ↓
RunLoop 被唤醒，处理 Source1
    ↓
Source1 将事件包装成 Source0
    ↓
RunLoop 处理 Source0（执行 UI 回调）
```

### 2.4 Observer 状态监听

#### Observer 状态枚举

```c
typedef CF_OPTIONS(CFOptionFlags, CFRunLoopActivity) {
    kCFRunLoopEntry         = 1 << 0,  // 即将进入 RunLoop
    kCFRunLoopBeforeTimers  = 1 << 1,  // 即将处理 Timer
    kCFRunLoopBeforeSources = 1 << 2,  // 即将处理 Source
    kCFRunLoopBeforeWaiting = 1 << 5,  // 即将休眠
    kCFRunLoopAfterWaiting  = 1 << 6,  // 刚从休眠唤醒
    kCFRunLoopExit          = 1 << 7,  // 即将退出
};
```

#### 添加 Observer 示例

```objective-c
CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(
    kCFAllocatorDefault,
    kCFRunLoopAllActivities,
    YES,
    0,
    ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        switch (activity) {
            case kCFRunLoopBeforeWaiting:
                NSLog(@"即将休眠");
                break;
            case kCFRunLoopAfterWaiting:
                NSLog(@"唤醒");
                break;
            default:
                break;
        }
    }
);
CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
```

### 2.5 运行流程（源码级）

#### 完整流程图

```
┌─────────────────────────────────────────────────────────────┐
│                     RunLoop 一次循环                         │
├─────────────────────────────────────────────────────────────┤
│  1. 通知 Observer：Entry                                    │
│  2. 通知 Observer：BeforeTimers                             │
│  3. 通知 Observer：BeforeSources                            │
│  4. 处理 Blocks（GCD 主队列 Block）                         │
│  5. 处理 Source0（如果有，跳回步骤4）                       │
│  6. 【真正处理 Timer】⭐                                    │
│  7. 检查是否有 Source1，有则跳转到 handle_msg（跳过休眠）⭐ │
│  8. 通知 Observer：BeforeWaiting                            │
│     ├─ [CoreAnimation 触发 UI 渲染]                         │
│  9. 休眠（mach_msg），等待 mach_port 消息                   │
│  9. 被唤醒，通知 Observer：AfterWaiting                     │
│ 10. 处理唤醒消息（Timer / Source1 / GCD Block）             │
│ 11. 跳回步骤2                                               │
└─────────────────────────────────────────────────────────────┘
```

#### CFRunLoopRun 简化源码

```c
static int __CFRunLoopRun(CFRunLoopRef rl, CFRunLoopModeRef rlm, ...) {
    while (!stop) {
        // 1. 通知 Observer：即将处理 Timer/Source（只是预告，不是真正处理）
        __CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeTimers);
        __CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeSources);

        // 2. 处理 Block
        __CFRunLoopDoBlocks(rl, rlm);

        // 3. 处理 Source0
        Boolean sourceHandled = __CFRunLoopDoSources0(rl, rlm);
        if (sourceHandled) {
            __CFRunLoopDoBlocks(rl, rlm);
        }

        // 4. 【真正处理 Timer】⭐
        __CFRunLoopDoTimers(rl, rlm);

        // 5. 检查 Source1（如果有，则跳过休眠）⭐
        if (__CFRunLoopServiceMachPort(..., &livePort)) {
            goto handle_msg; // ⭐ 直接跳到 handle_msg，不走 BeforeWaiting、mach_msg、AfterWaiting
        }

        // 6. 通知 Observer：即将休眠
        __CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeWaiting);
        // [CoreAnimation 监听到 BeforeWaiting，触发 UI 渲染]

        // 7. 真正休眠（阻塞在这里）
        __CFRunLoopSetSleeping(rl);
        mach_msg(...);  // ⭐ 只在真正休眠时调用
        __CFRunLoopUnsetSleeping(rl);

        // 8. 通知 Observer：刚被唤醒
        __CFRunLoopDoObservers(rl, rlm, kCFRunLoopAfterWaiting);

    handle_msg:
        // 9. 处理唤醒消息（Timer/Source1/GCD）
        if (msg_is_timer) __CFRunLoopDoTimers(rl, rlm);
        else if (msg_is_dispatch) __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__(msg);
        else __CFRunLoopDoSource1(rl, rlm, rls);

        // 10. 处理 Block
        __CFRunLoopDoBlocks(rl, rlm);
    }
}
```

**关键理解：**
- **步骤1只是通知**，真正处理 Timer 在步骤4
- **步骤5检查 Source1**，如果有则 `goto handle_msg`，**跳过 BeforeWaiting、mach_msg、AfterWaiting**
- **步骤7的 mach_msg** 只在**真正休眠时**调用（无 Source1 时）

#### 关键细节深度解析

**1. BeforeTimers vs 真正处理 Timer**

| 阶段 | 含义 | 实际操作 |
|------|------|----------|
| **BeforeTimers** | "即将处理 Timer"的**通知** | 不做任何实际处理 |
| **真正处理 Timer** | 执行 Timer 回调 | `__CFRunLoopDoTimers(rl, rlm)` |

**类比：**
- BeforeTimers = "闹钟响了，我要起床了"（预告）
- 真正处理 Timer = "执行闹钟的任务"（执行）

**2. UI 渲染的正确时机**

**重要修正：** UI 任务主要在 **BeforeWaiting 之前** 处理，不是之后！

```
BeforeSources 回调
    ↓
【处理用户态事件】
    ├─ 处理 Block
    ├─ 处理 Source0（触摸事件）
    └─ 处理 Timer
    ↓
【UI 相关任务在这里处理】⭐⭐⭐
    ├─ AutoLayout（计算布局）
    ├─ drawRect（自定义绘制）
    ├─ 图片解码
    ├─ 主线程 IO
    └─ CA Commit（提交渲染）
    ↓
【如果这里有耗时操作，RunLoop 会一直卡在这里】⚠️
    ↓
【无法进入 BeforeWaiting】⚠️
    ↓
【错过了 VSync 信号】⚠️
    ↓
【掉帧、卡顿】⚠️
    ↓
【终于处理完了】
    ↓
BeforeWaiting 回调
    ↓
【CoreAnimation 的 commit 在这里执行】⭐⭐⭐
    └─ 在 BeforeWaiting Observer 回调内部执行
    ├─ GPU 渲染（通常很快，5-10ms）
    └─ 合成显示
    ↓
【休眠】
    mach_msg(...)
```

**关键理解：**
- **大部分 UI 任务在 BeforeWaiting 之前处理**（AutoLayout、drawRect、图片解码等）
- **Core Animation 的 commit 发生在 BeforeWaiting 阶段**，在 Observer 回调内部执行
- **BeforeWaiting 之后是最终渲染**（通常很快，5-10ms）
- **卡顿的本质**：RunLoop 长时间无法进入 BeforeWaiting（因为处理 UI 任务耗时过长）

**3. 有 Source1 时的流程（跳过休眠）**

```
处理 Source0
    ↓
【判断】是否有 Source1 消息？
    ↓ YES
goto handle_msg ⭐
    ↓
【不走 BeforeWaiting】
【不走 mach_msg 休眠】
【不走 AfterWaiting】
    ↓
handle_msg:
    处理 Source1
    处理 Blocks
    ↓
回到 BeforeTimers（下一轮）
```

**关键理解：**
- 如果有 Source1，RunLoop **不会进入休眠**
- 直接 `goto handle_msg` 处理 Source1
- **跳过** BeforeWaiting、mach_msg、AfterWaiting 这三个阶段

**4. mach_msg 何时被调用？**

```
【条件1】无 Source1 待处理
    ↓
【条件2】Mode 中有事件源（Timer/Source0/Source1）
    ↓
【条件3】RunLoop 未被停止
    ↓
mach_msg(...) ← 真正休眠，阻塞在这里
```

**关键理解：**
- mach_msg **只在真正休眠时调用**
- 如果有 Source1，不会调用 mach_msg
- 如果 Mode 中没有事件源，RunLoop 会直接退出（不调用 mach_msg）

**5. 每一轮都会休眠吗？**

**不一定！** 分两种情况：

| 情况 | 是否休眠 | 原因 |
|------|----------|------|
| **有 Source1 待处理** | ❌ 不休眠 | `goto handle_msg`，跳过 mach_msg |
| **无 Source1，Mode 有事件源** | ✅ 会休眠 | 正常流程：BeforeWaiting → mach_msg |
| **无 Source1，Mode 无事件源** | ❌ 不休眠 | RunLoop 直接退出 |

**示例：**
```objective-c
// 会休眠
[[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
// 流程：处理事件 → BeforeWaiting → mach_msg 休眠 → 被唤醒 → ...

// 不会休眠（无事件源）
NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
[runLoop run]; // ⚠️ 会立即退出，因为没有事件源
```

### 2.6 与线程的关系

#### 为什么 main 函数不会退出？

```objective-c
int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
```

**答案**：`UIApplicationMain` 内部启动了主线程的 RunLoop，RunLoop 通过事件循环不断接受和处理消息，同时在用户态和内核态之间切换，从而保持程序持续运行。

#### 一对一关系

```objective-c
// 每个线程都有唯一的一个 RunLoop
NSLog(@"主线程 RunLoop: %p", [NSRunLoop currentRunLoop]);
NSLog(@"主线程 RunLoop: %p", [NSRunLoop currentRunLoop]);
// 两次打印地址相同

// 子线程 RunLoop 懒加载
dispatch_async(dispatch_get_global_queue(0, 0), ^{
    NSRunLoop *runloop = [NSRunLoop currentRunLoop];  // 第一次访问时创建
    NSLog(@"子线程 RunLoop: %p", runloop);
});
```

#### 关系表

| 线程类型 | RunLoop 创建时机 | RunLoop 是否自动运行 |
|----------|-----------------|-------------------|
| 主线程 | App 启动时自动创建 | ✅ 自动运行 |
| 子线程 | 第一次调用 currentRunLoop 时创建 | ❌ 需要手动运行 |

#### 关键特性

| 特性 | 说明 |
|------|------|
| **一一对应** | 一个线程对应一个 RunLoop |
| **懒加载** | 首次调用 `currentRunLoop` 时创建 |
| **生命周期** | RunLoop 随线程创建而创建，随线程销毁而销毁 |
| **线程安全** | CFRunLoopRef 是线程安全的，NSRunLoop 不是 |

### 2.7 与 AutoreleasePool 的关系

1. **主线程 RunLoop**：
   - kCFRunLoopEntry 时创建 AutoreleasePool
   - kCFRunLoopBeforeWaiting 时 drain 并创建新池
   - kCFRunLoopExit 时 drain

2. **子线程**：需要手动创建 AutoreleasePool（通常在 @autoreleasepool 块中）

#### 自动释放池管理示例

```objective-c
// RunLoop 每次休眠前（BeforeWaiting）会销毁并重建自动释放池
// 因此循环中产生的临时对象不会造成内存暴涨
for (int i = 0; i < 100000; i++) {
    NSString *str = [NSString stringWithFormat:@"%d", i];
    // 这些临时对象会在每次 RunLoop 循环结束时释放
}
```

### 2.8 在 UI 刷新中的角色

#### UI 渲染完整流程

```
┌─────────────────────────────────────────────────────────────┐
│                    一次 UI 渲染周期                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 事件处理（触摸、网络等）                                  │
│     └─> 修改 UI 状态（frame、backgroundColor 等）            │
│                                                             │
│  2. RunLoop 处理完所有事件                                  │
│     └─> 即将进入休眠（kCFRunLoopBeforeWaiting）              │
│                                                             │
│  3. 系统注册的 Observer 触发                                │
│     └─> _ZN2CA11Transaction17commit_if_needed_Ev            │
│         └─> 提交 CATransaction                              │
│                                                             │
│  4. CoreAnimation 渲染                                      │
│     ├─> 解码图片                                            │
│     ├─> 计算布局                                            │
│     ├─> 绘制显示列表（Display List）                         │
│     ├─> 离屏渲染（如需要）                                   │
│     └─> 生成位图                                            │
│                                                             │
│  5. GPU 处理                                                │
│     ├─> 合成位图                                            │
│     ├─> 纹理渲染                                            │
│     └─> 写入帧缓冲                                          │
│                                                             │
│  6. 硬件显示                                                │
│     └─> 逐行扫描显示                                        │
│                                                             │
│  ⏱️  总时间：必须 < 16.67ms（60Hz）才能保持 60 FPS            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### CADisplayLink 与 RunLoop

**CADisplayLink 的定时器机制**：

```objective-c
// CADisplayLink 是一个与屏幕刷新率同步的定时器
CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self
                                                         selector:@selector(displayLinkCallback:)];
// 默认以 NSRunLoopCommonModes 运行
[displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

// 每秒刷新次数（60Hz 屏幕约为 60 次）
NSLog(@"fps: %.2f", displayLink.duration); // ~0.0167 秒
```

**CADisplayLink vs NSTimer**：

| 特性 | CADisplayLink | NSTimer |
|------|---------------|---------|
| **触发时机** | 屏幕刷新后 | 指定时间间隔 |
| **精度** | 与屏幕刷新率同步 | 可能有延迟 |
| **默认 Mode** | CommonModes | DefaultMode |
| **适用场景** | UI 动画、帧率监控 | 通用定时任务 |

**核心原理**：

```
屏幕硬件刷新（VSync 信号）
    ↓
唤醒 RunLoop（通过 Source1）
    ↓
执行 CADisplayLink 回调
    ↓
更新 UI 动画
    ↓
下一次屏幕刷新
```

#### 渲染性能指标

**帧率（FPS）**：

| 帧率 | 说明 | 体验 |
|------|------|------|
| **60 FPS** | 每秒 60 帧，每帧 16.67ms | 流畅 |
| **30 FPS** | 每秒 30 帧，每帧 33.33ms | 可接受 |
| **< 30 FPS** | 帧率过低 | 卡顿 |

**为什么是 16.67ms？**

```
60Hz 屏幕刷新率：
1 秒 = 1000ms
每帧时间 = 1000ms / 60 ≈ 16.67ms

120Hz 屏幕刷新率：
每帧时间 = 1000ms / 120 ≈ 8.33ms
```

#### 卡顿产生的原理

**正常情况**：

```
RunLoop 处理事件（5ms）
    ↓
UI 渲染（10ms）
    ↓
总计：15ms < 16.67ms ✅ 流畅
```

**卡顿情况**：

```
RunLoop 处理事件（30ms）⬅️ 主线程被阻塞
    ↓
UI 渲染（10ms）
    ↓
总计：40ms > 16.67ms ❌ 掉帧（从 60 FPS 降到 25 FPS）
```

**卡顿原因分类**：

| 类型 | 原因 | 示例 |
|------|------|------|
| **主线程阻塞** | 耗时计算、同步网络请求 | 大数据处理、JSON 解析 |
| **视图过于复杂** | 图层过多、离屏渲染 | 阴影、圆角、毛玻璃 |
| **频繁重绘** | 不合理的 setNeedsDisplay | 滑动时不断刷新视图 |

#### CATransaction 的作用

**隐式动画**：

```objective-c
// Core Animation 隐式动画
[CATransaction begin];
view.layer.opacity = 0.5;
[CATransaction commit]; // 在 RunLoop BeforeWaiting 时自动提交
```

**显式动画**：

```objective-c
[CATransaction begin];
[CATransaction setAnimationDuration:0.25];
view.layer.opacity = 0.5;
[CATransaction commit];
```

**CATransaction 与 RunLoop 的关系**：

```
RunLoop 状态变化：
    ↓
kCFRunLoopBeforeWaiting
    ↓
CoreAnimation 注册的 Observer 触发
    ↓
提交 CATransaction（如果有未提交的修改）
    ↓
触发动画渲染
    ↓
RunLoop 进入休眠
```

#### 离屏渲染（Offscreen Rendering）

**什么是离屏渲染**：

```
正常渲染（Onscreen）：
视图 → CPU 计算布局 → GPU 渲染 → 直接显示在屏幕

离屏渲染（Offscreen）：
视图 → CPU 计算布局 → GPU 渲染到缓冲区 → 合成 → 显示在屏幕
                                     ↑
                              额外的渲染开销
```

**会触发离屏渲染的场景**：

| 场景 | 说明 |
|------|------|
| **圆角 + 裁剪** | `clipsToBounds = YES` + `cornerRadius > 0` |
| **阴影** | `shadowPath` 未设置时 |
| **图层蒙版** | `mask` 属性 |
| **光栅化** | `shouldRasterize = YES` |
| **毛玻璃效果** | `UIBlurEffect` |

**检测离屏渲染**：

```objective-c
// 模拟器 Debug → Color Offscreen-Rendered Yellow
// 离屏渲染的区域会显示为黄色
```

**优化建议**：

```objective-c
// ❌ 会触发离屏渲染
view.layer.cornerRadius = 10;
view.layer.masksToBounds = YES;

// ✅ 优化方案1：使用贝塞尔曲线绘制
UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:view.bounds
                                               cornerRadius:10];
CAShapeLayer *maskLayer = [CAShapeLayer layer];
maskLayer.path = path.CGPath;
view.layer.mask = maskLayer;

// ✅ 优化方案2：设置 shadowPath 避免离屏渲染
view.layer.shadowOpacity = 0.5;
view.layer.shadowPath = [UIBezierPath bezierPathWithRect:view.bounds].CGPath;
```

#### UI 渲染优化实践

**1. 异步绘制**

```objective-c
// 将耗时操作放到子线程
dispatch_async(dispatch_get_global_queue(0, 0), ^{
    // 图片解码、数据处理
    UIImage *image = [self decodeImage:imageData];

    dispatch_async(dispatch_get_main_queue(), ^{
        // 回到主线程更新 UI
        imageView.image = image;
    });
});
```

**2. 减少图层数量**

```objective-c
// ❌ 多个图层
view.layer.shadowOpacity = 0.5;
view.layer.shadowOffset = CGSizeMake(0, -2);
view.layer.shadowRadius = 3;

// ✅ 单图层（使用绘制）
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    // 绘制阴影和内容
}
```

**3. 按需渲染**

```objective-c
// 避免不必要的重绘
- (void)updateContent {
    if (self.needsUpdate) {
        self.needsUpdate = NO;
        [self setNeedsDisplay]; // 标记需要重绘
        // RunLoop 会在合适的时机触发 display
    }
}
```

**4. CALayer 异步绘制**

```objective-c
// 异步 Layer 绘制（iOS 4+）
class.asyncDrawing = YES; // 开启异步绘制
class.drawsAsynchronously = YES;
```

#### 监控 UI 性能

**1. FPS 监控**

```objective-c
@interface FPSMonitor ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) NSUInteger frameCount;
@property (nonatomic, assign) CFTimeInterval lastTime;
@end

@implementation FPSMonitor

- (instancetype)init {
    if (self = [super init]) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self
                                                    selector:@selector(displayLinkCallback:)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void)displayLinkCallback {
    _frameCount++;

    CFTimeInterval currentTime = _displayLink.timestamp;
    if (currentTime - _lastTime >= 1.0) {
        CGFloat fps = _frameCount / (currentTime - _lastTime);
        NSLog(@"FPS: %.2f", fps);
        _frameCount = 0;
        _lastTime = currentTime;
    }
}

@end
```

**2. RunLoop 卡顿监控**

参见前面 3.4 节的完整实现

**3. 系统工具**

| 工具 | 说明 |
|------|------|
| **Instruments** | Time Profiler、Core Animation |
| **Xcode View Debugging** | 检测图层混合、离屏渲染 |
| **模拟器 Debug** | Color Misaligned Images、Color Offscreen-Rendered Yellow |

### 2.9 与 GCD 的交互

- GCD 的 Timer 在创建时会注册到 RunLoop 中
- 但 GCD 的 DispatchQueue 不依赖 RunLoop

---

## 3. 实战应用（完整代码）

### 3.1 滑动时 NSTimer 不工作

**场景**：在 TableView 滑动时，NSTimer 停止工作

**解决方案**：

```objective-c
// ❌ 错误写法：只在 DefaultMode
NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerTick) userInfo:nil repeats:YES];

// ✅ 正确写法：使用 CommonModes
NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(timerTick) userInfo:nil repeats:YES];
[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
```

### 3.2 常驻线程（完整实现）

#### 应用场景

| 场景 | 说明 |
|------|------|
| 网络回调（NSURLConnection） | 回调必须在创建线程上执行 |
| 日志写入 | 频繁写入，避免重复创建线程 |
| 数据库操作 | SQLite 需要串行化访问 |
| 长连接心跳 | 需要持续运行的线程 |
| 音视频解码 | 保持解码上下文 |

#### 完整封装（可直接使用）

**PermanentThread.h**

```objective-c
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PermanentThread : NSObject

/// 在常驻线程上执行任务（串行）
- (void)executeTask:(void(^)(void))task;

/// 停止常驻线程
- (void)stop;

/// 线程是否正在运行
@property (nonatomic, assign, readonly) BOOL isRunning;

@end

NS_ASSUME_NONNULL_END
```

**PermanentThread.m**

```objective-c
#import "PermanentThread.h"

@interface PermanentThread ()
@property (nonatomic, strong) NSThread *thread;
@property (atomic, assign) BOOL stopped;
@property (atomic, assign, readwrite) BOOL isRunning;
@end

@implementation PermanentThread

- (instancetype)init {
    if (self = [super init]) {
        _stopped = NO;
        _isRunning = NO;
        [self _startThread];
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

#pragma mark - Public

- (void)executeTask:(void(^)(void))task {
    if (!task) return;
    if (self.stopped || !self.thread) return;

    // 将任务派发到常驻线程执行
    [self performSelector:@selector(_executeTaskOnThread:)
                 onThread:self.thread
               withObject:task
            waitUntilDone:NO];
}

- (void)stop {
    if (self.stopped) return;
    self.stopped = YES;
    if (self.thread) {
        [self performSelector:@selector(_stopRunLoop)
                     onThread:self.thread
                   withObject:nil
                waitUntilDone:NO];
    }
}

#pragma mark - Private

- (void)_startThread {
    __weak typeof(self) weakSelf = self;
    self.thread = [[NSThread alloc] initWithBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        strongSelf.isRunning = YES;

        // 关键1：添加 Port，防止 RunLoop 因无事件源而退出
        [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];

        // 关键2：值班循环 + runMode
        while (!strongSelf.stopped) {
            @autoreleasepool {
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                          beforeDate:[NSDate distantFuture]];
            }
        }

        strongSelf.isRunning = NO;
    }];
    self.thread.name = [NSString stringWithFormat:@"com.permanent.thread.%p", self];
    [self.thread start];
}

- (void)_executeTaskOnThread:(void(^)(void))task {
    @autoreleasepool {
        task();
    }
}

- (void)_stopRunLoop {
    CFRunLoopStop(CFRunLoopGetCurrent());
}

@end
```

#### 设计答疑

**Q1: 为什么 executeTask 中还要用 performSelector？**

A: 因为 `executeTask:` 是在调用者线程执行的，我们需要让任务在常驻线程上执行。`performSelector:onThread:` 正是用来将方法派发到指定线程的。

**Q2: 为什么 while 循环中只加一个 runMode？**

A: `runMode:beforeDate:` 处理完一个事件后就会返回，所以需要 while 循环让它处理完一个后继续等待下一个。常驻线程通常只处理后台任务，DefaultMode 足够，不需要 TrackingMode。

**Q3: 为什么需要添加 Port？**

A: 如果 Mode 中没有 Source0、Source1、Timer，RunLoop 会直接返回而不等待。添加 Port 就是添加一个 Source1，让 RunLoop 有事件源可以等待。

#### 使用示例

```objective-c
PermanentThread *thread = [[PermanentThread alloc] init];

// 执行任务
[thread executeTask:^{
    NSLog(@"在常驻线程执行任务");
    [NSThread sleepForTimeInterval:2];
    NSLog(@"任务完成");
}];

// 停止线程
[thread stop];
```

### 3.3 卡顿监控（信号量方案）

#### 原理

**1. 卡顿监控的本质（重要理解）⭐⭐⭐**

**卡顿监控并不是只监听 BeforeSources，而是监听 RunLoop 状态变化。**

之所以重点关注 **BeforeSources** 和 **AfterWaiting**，是因为：
- **主线程的大多数耗时任务**都发生在这两个阶段之后
- 包括：事件处理、layout、draw、图片解码等

**Core Animation 的 commit 虽然发生在 kCFRunLoopBeforeWaiting 阶段，但它是在 BeforeWaiting Observer 回调内部执行的，属于 RunLoop 即将休眠前的最后工作。**

**真正的卡顿，通常表现为 RunLoop 长时间无法进入 BeforeWaiting，而不是停在 sleep 阶段。**

---

**2. 信号量方案监控的是"RunLoop 状态是否切换"**

```
正常情况：
BeforeSources ──(发送信号)──> 1ms ──(收到信号)──> BeforeWaiting ──(发送信号)──> ...
    ↓ 子线程等待信号                          ↓ 子线程等待信号
  (收到信号，重置超时)                      (收到信号，重置超时)

卡顿情况：
BeforeSources ──(发送信号)──> 50ms ──(超时！)──> ⚠️ 卡顿！
    ↓ 子线程等待信号                          ↓ 子线程超时
  (50ms 后超时，检测卡顿)                   (RunLoop 卡在某个状态)
```

**关键理解：**
- 每次 RunLoop 状态切换时，Observer 回调会**发送信号量**
- 子线程**等待信号量**，如果超时说明 RunLoop 状态**没有切换**
- 如果超时时，RunLoop 处于 `BeforeSources` 或 `BeforeWaiting`，说明处理任务耗时过长

**监控的核心：**
| 状态 | 是否监控卡顿 | 说明 |
|------|-------------|------|
| **BeforeSources** | ✅ 监控 | 如果卡在这里，说明 AfterWaiting 之后处理任务耗时过长 |
| **BeforeWaiting** | ✅ 监控 | 如果卡在这里，说明 Source0/Timer/Block 处理耗时过长 ⭐⭐⭐ |
| **AfterWaiting** | ❌ 不监控 | 休眠是正常的，不算卡顿 |

---

**3. 工业级卡顿监控：状态定位（⭐⭐⭐⭐ 高级）**

卡顿监控通常会监听 **kCFRunLoopAllActivities**，记录 RunLoop 当前 Activity。

后台线程通过 **semaphore + timeout** 检测 RunLoop 状态是否长时间没有变化。

**根据停留的不同状态，可以定位不同类型的卡顿：**

```
┌─────────────────────────────────────────────────────────┐
│  如果长时间停留在 kCFRunLoopBeforeSources            │
│  或 kCFRunLoopAfterWaiting                              │
├─────────────────────────────────────────────────────────┤
│  通常说明：                                            │
│  ✅ 业务逻辑耗时过长                                   │
│  ✅ 事件处理耗时过长                                   │
│  ✅ layout 计算耗时过长                                │
│  ✅ drawRect 绘制耗时过长                              │
│  ✅ 图片解码耗时过长                                   │
│                                                         │
│  优化方向：                                            │
│  → 异步执行耗时任务                                    │
│  → 优化算法复杂度                                      │
│  → 减少主线程工作量                                    │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  如果长时间停留在 kCFRunLoopBeforeWaiting              │
├─────────────────────────────────────────────────────────┤
│  通常说明：                                            │
│  ✅ CoreAnimation commit 过重                           │
│  ✅ layer tree 编码耗时过长                             │
│  ✅ 渲染提交过重                                       │
│  ✅ 图层数量过多                                       │
│  ✅ 离屏渲染过多                                       │
│                                                         │
│  优化方向：                                            │
│  → 减少图层数量                                        │
│  → 避免离屏渲染                                        │
│  → 优化图层树结构                                      │
│  → 使用 shouldRasterize（慎用）                        │
└─────────────────────────────────────────────────────────┘
```

**工业级卡顿监控的优势：**

| 能力 | 说明 |
|------|------|
| **检测卡顿** | 通过 semaphore timeout 检测 RunLoop 状态是否长时间不变 |
| **定位阶段** | 根据停留的状态，定位是业务逻辑还是渲染问题 |
| **优化指导** | 给出明确的优化方向（异步执行 vs 优化渲染） |

**实际应用示例：**

```objective-c
- (void)checkLag {
    CFTimeInterval elapsed = CACurrentMediaTime() - self.lastTime;

    if (elapsed > self.threshold) {
        switch (self.activity) {
            case kCFRunLoopBeforeSources:
            case kCFRunLoopAfterWaiting:
                NSLog(@"⚠️ 业务逻辑/事件处理/layout 耗时：%f ms", elapsed * 1000);
                NSLog(@"   建议：异步执行耗时任务、优化算法、减少主线程工作量");
                break;

            case kCFRunLoopBeforeWaiting:
                NSLog(@"⚠️ CoreAnimation commit/layer tree 编码/渲染提交 耗时：%f ms", elapsed * 1000);
                NSLog(@"   建议：减少图层数量、避免离屏渲染、优化图层树结构");
                break;

            default:
                break;
        }
    }
}
```

**总结：**
- 工业级卡顿监控不仅能检测"是否卡顿"
- 还能大致定位卡顿发生在哪个 RunLoop 阶段
- 根据不同阶段给出针对性的优化建议

#### 完整代码

**LagMonitor.h**

```objective-c
#import <Foundation/Foundation.h>

@interface LagMonitor : NSObject
+ (instancetype)shared;
- (void)startMonitoring;
- (void)stopMonitoring;
@property (nonatomic, assign) double threshold; // 卡顿阈值，默认 0.05 秒
@end
```

**LagMonitor.m**

```objective-c
#import "LagMonitor.h"

@interface LagMonitor ()
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, assign) CFRunLoopObserverRef observer;
@property (nonatomic, assign) CFRunLoopActivity activity;
@property (nonatomic, assign) BOOL isMonitoring;
@end

@implementation LagMonitor

+ (instancetype)shared {
    static LagMonitor *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LagMonitor alloc] init];
        instance.threshold = 0.05;
    });
    return instance;
}

- (void)startMonitoring {
    if (self.isMonitoring) return;
    self.isMonitoring = YES;

    // 1. 创建信号量（初始值0）
    self.semaphore = dispatch_semaphore_create(0);

    // 2. 创建 Observer
    CFRunLoopObserverContext context = {0, (__bridge void *)self, NULL, NULL};
    self.observer = CFRunLoopObserverCreate(
        kCFAllocatorDefault,
        kCFRunLoopAllActivities,
        YES,
        0,
        lagMonitorObserverCallback,
        &context
    );
    CFRunLoopAddObserver(CFRunLoopGetMain(), self.observer, kCFRunLoopCommonModes);

    // 3. 在子线程监控
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (self.isMonitoring) {
            // 等待信号量，超时则说明卡顿
            long result = dispatch_semaphore_wait(self.semaphore,
                dispatch_time(DISPATCH_TIME_NOW, self.threshold * NSEC_PER_SEC));

            if (result != 0) {
                // 超时，根据当前状态判断卡顿类型
                NSString *lagType = nil;

                switch (self.activity) {
                    case kCFRunLoopBeforeSources:
                        lagType = @"业务逻辑/事件处理/layout 耗时";
                        break;

                    case kCFRunLoopBeforeWaiting:
                        lagType = @"CoreAnimation commit/渲染提交 耗时";
                        break;

                    case kCFRunLoopAfterWaiting:
                        lagType = @"唤醒消息处理 耗时";
                        break;

                    default:
                        lagType = @"未知状态";
                        break;
                }

                // 卡顿，上报堆栈和类型
                NSArray *stack = [NSThread callStackSymbols];
                NSLog(@"⚠️ 检测到卡顿[%@]: %@", lagType, stack);
                // 这里可以添加上报逻辑
            }
        }
    });
}

- (void)stopMonitoring {
    if (!self.isMonitoring) return;
    self.isMonitoring = NO;
    if (self.observer) {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), self.observer, kCFRunLoopCommonModes);
        CFRelease(self.observer);
        self.observer = NULL;
    }
}

static void lagMonitorObserverCallback(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    LagMonitor *monitor = (__bridge LagMonitor *)info;
    monitor.activity = activity;
    dispatch_semaphore_signal(monitor.semaphore);
}

@end
```

#### 其他监控方案对比

**方案1：监控 BeforeSources → BeforeWaiting（推荐）**

```objective-c
static CFTimeInterval lastTime = 0;

static void observerCallback(CFRunLoopObserverRef observer,
                             CFRunLoopActivity activity,
                             void *info) {
    CFTimeInterval currentTime = CACurrentMediaTime();
    CFTimeInterval elapsed = currentTime - lastTime;

    if (activity == kCFRunLoopBeforeWaiting) {
        // ⭐ 监控 BeforeSources → BeforeWaiting 的时间
        if (elapsed > 0.01667) { // 16.67ms
            NSLog(@"⚠️ 卡顿：%f ms", elapsed * 1000);
            // 说明：AutoLayout、drawRect、图片解码等耗时操作
        }
        lastTime = currentTime;
    }
}
```

**优点：** 简单直接，抓住主要矛盾
**缺点：** 无法区分是哪个具体操作耗时过长

---

**方案2：监控所有状态之间的时间（更精确）**

```objective-c
static CFRunLoopActivity lastActivity = 0;
static CFTimeInterval lastTime = 0;

static void observerCallback(CFRunLoopObserverRef observer,
                             CFRunLoopActivity activity,
                             void *info) {
    CFTimeInterval currentTime = CACurrentMediaTime();
    CFTimeInterval elapsed = currentTime - lastTime;

    // ⭐ 监控每个阶段之间的时间
    switch (activity) {
        case kCFRunLoopBeforeSources:
            if (elapsed > 0.01667) {
                NSLog(@"⚠️ AfterWaiting → BeforeSources 卡顿：%f ms", elapsed * 1000);
                // 说明 AfterWaiting 之后处理任务耗时过长
            }
            break;

        case kCFRunLoopBeforeWaiting:
            if (elapsed > 0.01667) {
                NSLog(@"⚠️ BeforeSources → BeforeWaiting 卡顿：%f ms", elapsed * 1000);
                // 说明处理 Source0/Timer/Block 耗时过长 ⭐⭐⭐
            }
            break;

        case kCFRunLoopAfterWaiting:
            // 休眠时间，不监控
            break;
    }

    lastActivity = activity;
    lastTime = currentTime;
}
```

**优点：** 可以精确定位是哪个阶段耗时过长
**缺点：** 实现稍复杂

---

#### 监控方案选择建议

| 方案 | 适用场景 | 难度 | 准确度 |
|------|----------|------|--------|
| **信号量方案** | 生产环境、需要上报 | ⭐⭐ | ⭐⭐⭐ |
| **时间间隔监控** | 开发调试、简单监控 | ⭐ | ⭐⭐ |
| **全状态监控** | 性能分析、定位问题 | ⭐⭐⭐ | ⭐⭐⭐⭐ |

**推荐：**
- 生产环境使用**信号量方案**（已实现）
- 性能分析时使用**全状态监控**（可以精确定位问题）

@end
```

### 3.4 UITableView 卡顿优化

#### 原理

将耗时任务（如图片解码）推迟到 RunLoop 休眠前执行

#### 实现示例

```objective-c
@interface ViewController ()
@property (strong, nonatomic) NSMutableArray<RunLoopTask> *tasks;
@property (assign, nonatomic) NSInteger maxTaskCount;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _tasks = [NSMutableArray array];
    _maxTaskCount = 30; // 约等于一屏 cell 数量
    [self addRunLoopObserver];
}

- (void)addRunLoopObserver {
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFRunLoopObserverContext context = {0, (__bridge void *)self, NULL, NULL, NULL};

    CFRunLoopObserverRef observer = CFRunLoopObserverCreate(
        kCFAllocatorDefault,
        kCFRunLoopBeforeWaiting,
        YES,
        0,
        &runLoopObserverCallback,
        &context
    );

    CFRunLoopAddObserver(runLoop, observer, kCFRunLoopDefaultMode);
    CFRelease(observer);
}

static void runLoopObserverCallback(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    ViewController *vc = (__bridge ViewController *)info;
    if (vc.tasks.count == 0) return;

    RunLoopTask task = vc.tasks.firstObject;
    if (task) task();
    [vc.tasks removeObjectAtIndex:0];
}

- (void)addTask:(RunLoopTask)task {
    [self.tasks addObject:task];
    if (self.tasks.count > self.maxTaskCount) {
        [self.tasks removeObjectAtIndex:0];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Cell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    cell.imageView.image = nil;

    [self addTask:^{
        UIImage *img = [UIImage imageWithContentsOfFile:path];
        cell.imageView.image = img;
    }];

    return cell;
}

@end
```

#### 局限性

| 问题 | 说明 |
|------|------|
| ⚠️ 首屏渲染问题 | 不滑动时不会触发渲染 |
| ⚠️ CommonModes 模式 | 在 CommonModes 下可能导致卡顿 |
| ⚠️ 任务对应问题 | 快速滑动时任务队列可能不对应 |

### 3.5 线程保活（防止崩溃后退出）

**原理**：在 Crash 处理中启动 RunLoop，防止线程退出

**注意**：这只是临时措施，真正的解决方案应该找到崩溃原因

### 3.6 FPS 监控工具

#### 原理

使用 CADisplayLink 监听屏幕刷新回调，统计 1 秒内的刷新次数，计算 FPS。

**与 RunLoop 的关系**：
- CADisplayLink 注册到主线程 RunLoop 的 CommonModes
- 每次屏幕刷新时唤醒 RunLoop，执行回调
- 通过回调频率可以判断 UI 渲染性能

#### 完整实现

**FPSMonitor.h**

```objective-c
#import <Foundation/Foundation.h>

@interface FPSMonitor : NSObject

+ (instancetype)shared;
- (void)startMonitoring;
- (void)stopMonitoring;
- (NSString *)currentFPS; // 返回当前 FPS 字符串

@end
```

**FPSMonitor.m**

```objective-c
#import "FPSMonitor.h"

@interface FPSMonitor ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) NSUInteger frameCount;
@property (nonatomic, assign) CFTimeInterval lastTime;
@property (nonatomic, copy) NSString *fpsString;
@end

@implementation FPSMonitor

+ (instancetype)shared {
    static FPSMonitor *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FPSMonitor alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _frameCount = 0;
        _lastTime = 0;

        // 创建 CADisplayLink
        _displayLink = [CADisplayLink displayLinkWithTarget:self
                                                     selector:@selector(displayLinkCallback:)];
        // 以 CommonModes 运行，确保滑动时也能监控
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void)startMonitoring {
    self.frameCount = 0;
    self.lastTime = self.displayLink.timestamp;
    self.displayLink.paused = NO;
}

- (void)stopMonitoring {
    self.displayLink.paused = YES;
}

- (void)displayLinkCallback {
    self.frameCount++;

    CFTimeInterval currentTime = self.displayLink.timestamp;

    // 每秒更新一次 FPS
    if (currentTime - self.lastTime >= 1.0) {
        CGFloat fps = self.frameCount / (currentTime - self.lastTime);
        self.fpsString = [NSString stringWithFormat:@"%.1f FPS", fps];

        NSLog(@"%@", self.fpsString);

        // 重置计数
        self.frameCount = 0;
        self.lastTime = currentTime;
    }
}

- (NSString *)currentFPS {
    return self.fpsString ?: @"计算中...";
}

@end
```

#### 集成到项目

**在 AppDelegate 中启动**

```objective-c
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // 启动 FPS 监控
    [[FPSMonitor shared] startMonitoring];

    return YES;
}
```

**显示 FPS 标签**

```objective-c
- (void)showFPSLabel {
    UILabel *fpsLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 20, 100, 20)];
    fpsLabel.tag = 9999;
    fpsLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];
    fpsLabel.textColor = [UIColor whiteColor];
    fpsLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    fpsLabel.layer.cornerRadius = 5;
    fpsLabel.layer.masksToBounds = YES;
    fpsLabel.textAlignment = NSTextAlignmentCenter;

    [[UIApplication sharedApplication].keyWindow addSubview:fpsLabel];

    // 定期更新
    [NSTimer scheduledTimerWithTimeInterval:1.0
                                     target:self
                                   selector:@selector(updateFPSLabel:)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)updateFPSLabel:(NSTimer *)timer {
    UILabel *fpsLabel = [[UIApplication sharedApplication].keyWindow viewWithTag:9999];
    fpsLabel.text = [[FPSMonitor shared] currentFPS];

    // 根据 FPS 改变颜色
    NSString *fps = [[FPSMonitor shared] currentFPS];
    if ([fps hasPrefix:@"5"] || [fps hasPrefix:@"6"]) {
        fpsLabel.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.7];
    } else if ([fps hasPrefix:@"4"] || [fps hasPrefix:@"3"]) {
        fpsLabel.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:0.7];
    } else {
        fpsLabel.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.7];
    }
}
```

#### FPS 监控的局限性

| 局限性 | 说明 |
|--------|------|
| **不是真实帧率** | CADisplayLink 回调不代表屏幕实际刷新 |
| **检测不到硬件卡顿** | GPU 渲染问题可能检测不到 |
| **模拟器 vs 真机** | 模拟器的帧率可能与真机不同 |

#### 更准确的监控方案

| 方案 | 说明 |
|------|------|
| **Core Animation FPS** | 真机 Debug → Core Animation → FPS |
| **Instruments** | Core Animation 工具，显示真实 GPU 渲染帧率 |
| **RunLoop 卡顿监控** | 结合使用，综合判断性能问题 |

---

## 4. 面试题 & 常见问题

### 4.1 面试高频题

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **什么是 RunLoop？** | 事件处理循环，让线程有活时工作、没活时休眠 | ⭐ |
| **RunLoop 和线程的关系？** | 一对一，主线程自动开启，子线程需手动启动 | ⭐ |
| **为什么 NSTimer 在滑动时停止？** | 滑动时 Mode 切换为 TrackingMode，Timer 在 DefaultMode 下 | ⭐⭐ |
| **如何解决 Timer 滑动停止？** | 加入 CommonModes 或用 GCD 定时器 | ⭐⭐ |
| **如何实现常驻线程？** | 子线程 RunLoop 添加 Port，while + runMode 循环 | ⭐⭐⭐ |
| **RunLoop 的 Mode 有哪几种？** | Default、Tracking、Common、Initialization、GSEventReceive | ⭐⭐ |
| **Source0 和 Source1 的区别？** | Source0 手动唤醒，Source1 基于 port 自动唤醒 | ⭐⭐ |
| **RunLoop 的运行流程？** | Entry → BeforeTimers → BeforeSources → 处理事件 → BeforeWaiting → 休眠 → 唤醒 → AfterWaiting → 处理消息 → 循环 | ⭐⭐⭐ |
| **Observer 可以监听哪些状态？** | Entry、BeforeTimers、BeforeSources、BeforeWaiting、AfterWaiting、Exit | ⭐⭐ |
| **卡顿监控的原理？** | 监听 RunLoop 状态变化，检测状态停留时间是否超阈值 | ⭐⭐⭐ |
| **一次性 Timer 和重复 Timer 的区别？** | 一次性触发后自动移除，重复需要手动 invalidate | ⭐ |
| **performSelector:afterDelay: 在子线程不生效？** | 依赖 RunLoop 的 Timer，子线程默认没有 RunLoop | ⭐⭐ |
| **RunLoop 与 UI 渲染的关系？** | UI 任务主要在 BeforeWaiting 之前处理（AutoLayout、drawRect、图片解码等）；卡顿的本质是无法及时进入 BeforeWaiting | ⭐⭐⭐ |
| **CADisplayLink 与 NSTimer 的区别？** | CADisplayLink 与屏幕刷新率同步，更适合 UI 动画；NSTimer 是固定时间间隔 | ⭐⭐ |
| **什么是离屏渲染？** | 渲染到缓冲区而非直接显示，会触发额外性能开销；圆角、阴影、毛玻璃会触发 | ⭐⭐⭐ |
| **如何优化滑动流畅度？** | 异步绘制、减少图层数量、避免离屏渲染、按需渲染、使用 RunLoop 休眠时机处理任务 | ⭐⭐⭐ |
| **为什么是 16.67ms？** | 60Hz 屏幕刷新率，每帧 1000ms/60≈16.67ms；超过则掉帧 | ⭐⭐ |
| **卡顿产生的原理？** | 主线程被阻塞导致 RunLoop 无法及时进入 BeforeWaiting（AutoLayout、drawRect、图片解码等耗时操作），错过 VSync 信号，导致掉帧 | ⭐⭐⭐ |
| **Timer 在什么时候真正处理？** | BeforeTimers 只是通知，真正处理 Timer 在 BeforeSources 之后、BeforeWaiting 之前 | ⭐⭐⭐⭐ |
| **UI 渲染发生在什么时候？** | UI 任务主要在 BeforeWaiting 之前处理（AutoLayout、drawRect、图片解码等）；BeforeWaiting 之后是 CoreAnimation 的最终渲染⭐⭐⭐ | ⭐⭐⭐⭐ |
| **有 Source1 时会休眠吗？** | 不会，会 goto handle_msg，跳过 BeforeWaiting、mach_msg、AfterWaiting | ⭐⭐⭐⭐ |
| **mach_msg 什么时候调用？** | 只在真正休眠时调用（无 Source1、Mode 有事件源时） | ⭐⭐⭐ |
| **每一轮都会休眠吗？** | 不一定，有 Source1 时不休眠，Mode 无事件源时直接退出 | ⭐⭐⭐ |
| **卡顿监控应该监控哪些状态？** | 主要监控 BeforeSources → BeforeWaiting 的时间（处理 UI 任务：AutoLayout、drawRect、图片解码等的耗时）⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **工业级卡顿监控如何定位问题？** | 监听 kCFRunLoopAllActivities，根据不同状态停留定位问题：BeforeSources/AfterWaiting = 业务逻辑；BeforeWaiting = 渲染问题 | ⭐⭐⭐⭐⭐ |
| **BeforeSources 之后处理什么？** | Block、Source0（UI事件、performSelector）、Timer，不仅仅是 UI 事件 | ⭐⭐⭐ |

### 4.2 深度面试题（⭐⭐⭐⭐）

#### Q1: BeforeTimers 和真正处理 Timer 的区别？

**问题：** BeforeTimers 是什么时候？Timer 是什么时候真正处理的？

**答案：**
- **BeforeTimers**：只是"通知"，告诉 Observer "即将处理 Timer"，不做任何实际处理
- **真正处理 Timer**：在 BeforeSources **之后**，调用 `__CFRunLoopDoTimers(rl, rlm)` 才真正执行 Timer 回调

**代码层面：**
```c
// 1. 通知：BeforeTimers（不做任何处理）
__CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeTimers);

// 2. 通知：BeforeSources（不做任何处理）
__CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeSources);

// 3. 处理 Block
__CFRunLoopDoBlocks(rl, rlm);

// 4. 处理 Source0
__CFRunLoopDoSources0(rl, rlm);

// 5. 【这里才真正处理 Timer】⭐
__CFRunLoopDoTimers(rl, rlm);
```

**记忆技巧：**
- BeforeTimers = "预告"（闹钟响了）
- 真正处理 Timer = "执行"（起床执行任务）

---

#### Q2: UI 渲染发生在什么时候？

**问题：** UI 渲染发生在什么时候？是 RunLoop 本身处理的吗？

**答案：**
- **大部分 UI 任务在 BeforeWaiting 之前处理**⭐⭐⭐
- **BeforeWaiting 之后是 CoreAnimation 的最终渲染**（通常很快）

**完整流程：**
```
BeforeSources 回调
    ↓
【处理用户态事件】
    ├─ 处理 Block
    ├─ 处理 Source0（触摸事件）
    └─ 处理 Timer
    ↓
【UI 相关任务在这里处理】⭐⭐⭐
    ├─ AutoLayout（计算布局）← 可能很耗时
    ├─ drawRect（自定义绘制）← 可能很耗时
    ├─ 图片解码 ← 可能很耗时
    ├─ 主线程 IO ← 可能很耗时
    └─ CA Commit（提交渲染）
    ↓
【如果这里有耗时操作，RunLoop 会一直卡在这里】⚠️
    ↓
【无法进入 BeforeWaiting】⚠️
    ↓
【错过了 VSync 信号】⚠️
    ↓
【掉帧、卡顿】⚠️
    ↓
【终于处理完了】
    ↓
BeforeWaiting 回调
    ↓
【CoreAnimation 的最终渲染】（通常很快，5-10ms）
    ├─ GPU 渲染
    └─ 合成显示
    ↓
【休眠】
    mach_msg(...)
```

**关键理解：**
- 卡顿的本质：RunLoop 长时间无法进入 BeforeWaiting
- 原因：AutoLayout、drawRect、图片解码等耗时操作
- 监控：检测 RunLoop 是否能及时进入 BeforeWaiting

---

#### Q3: 有 Source1 时会休眠吗？

**问题：** 如果有 Source1 待处理，RunLoop 会进入休眠吗？

**答案：**
- **不会！** 如果有 Source1，RunLoop 会 `goto handle_msg`，**跳过休眠**

**完整流程：**
```
处理 Source0
    ↓
【判断】是否有 Source1 消息？
    ↓ YES
goto handle_msg ⭐
    ↓
【不走 BeforeWaiting】
【不走 mach_msg 休眠】
【不走 AfterWaiting】
    ↓
handle_msg:
    处理 Source1
    处理 Blocks
    ↓
回到 BeforeTimers（下一轮）
```

**代码层面：**
```c
// 1. 处理 Source0
__CFRunLoopDoSources0(rl, rlm);

// 2. 【真正处理 Timer】
__CFRunLoopDoTimers(rl, rlm);

// 3. 检查 Source1
if (__CFRunLoopServiceMachPort(..., &livePort)) {
    goto handle_msg; // ⭐ 直接跳到 handle_msg
}

// 4. 通知 BeforeWaiting
__CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeWaiting);

// 5. 真正休眠
mach_msg(...);

handle_msg:
    // 处理消息
    __CFRunLoopDoSource1(rl, rlm);
```

**关键理解：**
- 有 Source1 时，RunLoop **不会进入休眠**
- 跳过 **BeforeWaiting、mach_msg、AfterWaiting** 这三个阶段
- 直接处理 Source1，然后进入下一轮循环

---

#### Q4: mach_msg 什么时候调用？

**问题：** mach_msg 是在什么时候调用的？每次循环都会调用吗？

**答案：**
- **mach_msg 只在真正休眠时调用**
- **不是每次循环都会调用！**

**调用条件：**
1. **无 Source1 待处理**
2. **Mode 中有事件源**（Timer/Source0/Source1）
3. **RunLoop 未被停止**

**不会调用的情况：**
- 有 Source1 待处理（`goto handle_msg`）
- Mode 中没有事件源（RunLoop 直接退出）

**示例：**
```objective-c
// 不会调用 mach_msg（无事件源）
NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
[runLoop run]; // ⚠️ 会立即退出

// 会调用 mach_msg（有事件源）
[[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
// ✅ 会进入休眠，等待消息
```

---

#### Q5: 卡顿监控应该监控哪些状态？

**问题：** 卡顿监控应该监控 RunLoop 的哪些状态？为什么？

**答案：**
- **主要监控 `BeforeSources` → `BeforeWaiting` 的时间**
- 这个阶段包含了所有可能的耗时操作

**监控的核心：**
| 状态 | 是否监控卡顿 | 说明 |
|------|-------------|------|
| **BeforeSources → BeforeWaiting** | ✅ **必须监控**⭐⭐⭐ | 处理 Source0/Timer/Block，最容易卡顿 |
| **AfterWaiting → BeforeSources** | ✅ 可以监控 | 处理 Timer/Source1/GCD，也可能卡顿 |
| **BeforeWaiting → AfterWaiting** | ❌ 不监控 | 休眠时间，不算卡顿 |

**原因：**
- `BeforeSources → BeforeWaiting` 是处理任务的阶段
- 包含了 Source0、Timer、Block 的处理
- 这些是**最可能卡顿的地方**

**实现建议：**
```objective-c
// 最简单有效的监控
if (beforeSources 到 beforeWaiting 的时间 > 16.67ms) {
    NSLog(@"⚠️ 卡顿：处理任务耗时过长");
}
```

---

#### Q6: 工业级卡顿监控如何定位问题？

**问题：** 工业级卡顿监控如何根据不同状态定位卡顿原因？

**答案：**

**监控所有状态：**
```objective-c
// 监听 kCFRunLoopAllActivities
CFRunLoopObserverRef observer = CFRunLoopObserverCreate(
    kCFAllocatorDefault,
    kCFRunLoopAllActivities, // ⭐ 监听所有状态
    YES,
    0,
    observerCallback,
    &context
);
```

**状态定位：**

| 状态停留 | 卡顿类型 | 可能原因 | 优化方向 |
|---------|---------|---------|---------|
| **kCFRunLoopBeforeSources** | 业务逻辑/事件处理 | JSON 解析、复杂计算、主线程 IO | 异步执行、优化算法 |
| **kCFRunLoopBeforeSources** | layout/drawRect | AutoLayout、drawRect、图片解码 | 异步绘制、图片预加载 |
| **kCFRunLoopAfterWaiting** | 唤醒消息处理 | Timer、Source1、GCD 任务 | 优化任务调度 |
| **kCFRunLoopBeforeWaiting** | CoreAnimation commit | 图层过多、离屏渲染、layer tree 编码 | 减少图层、避免离屏渲染 |

**优势：**
- ✅ 不仅能检测"是否卡顿"
- ✅ 还能定位"卡顿发生在哪个阶段"
- ✅ 给出针对性的优化建议

---

### 4.3 常见陷阱

#### performSelector 原理

```objective-c
// performSelector:withObject:afterDelay: 底层依赖 RunLoop 的 Timer
[self performSelector:@selector(task) withObject:nil afterDelay:1.0];

// 滑动时不执行的原因：Timer 默认在 DefaultMode 下
// 解决：包装一层 NSPort 或者改用 dispatch_after
```

#### UI 渲染相关陷阱

**1. 频繁调用 setNeedsDisplay 导致卡顿**

```objective-c
// ❌ 错误：在滑动时频繁刷新
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self.view setNeedsDisplay]; // 每次滑动都触发重绘
}

// ✅ 正确：使用 CADisplayLink 节流
- (void)startMonitoring {
    self.displayLink = [CADisplayLink displayLinkWithTarget:self
                                                     selector:@selector(updateUI)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                            forMode:NSRunLoopCommonModes];
}

- (void)updateUI {
    // 限制刷新频率
    if (self.needsUpdate) {
        self.needsUpdate = NO;
        [self.view setNeedsDisplay];
    }
}
```

**2. 主线程阻塞导致掉帧**

```objective-c
// ❌ 错误：在主线程进行耗时操作
- (void)tableView:(UITableView *)tableView
    willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath {
    // 图片解码很耗时
    UIImage *image = [UIImage imageWithData:data];
    cell.imageView.image = image;
}

// ✅ 正确：异步解码
- (void)tableView:(UITableView *)tableView
    willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        UIImage *image = [self decodeImage:data];
        dispatch_async(dispatch_get_main_queue(), ^{
            cell.imageView.image = image;
        });
    });
}
```

**3. 离屏渲染导致卡顿**

```objective-c
// ❌ 错误：会触发离屏渲染
view.layer.cornerRadius = 10;
view.layer.masksToBounds = YES;

// ✅ 优化：使用 shadowPath 避免离屏渲染
view.layer.shadowOpacity = 0.5;
view.layer.shadowColor = [UIColor blackColor].CGColor;
view.layer.shadowOffset = CGSizeMake(0, -2);
view.layer.shadowRadius = 3;
// 关键：设置 shadowPath 避免离屏渲染
view.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:view.bounds
                                                  cornerRadius:10].CGPath;
```

**4. 未在正确时机提交 CATransaction**

```objective-c
// ⚠️ 注意：隐式动画会在 RunLoop BeforeWaiting 时自动提交
// 但如果在循环中修改，可能导致多次提交

// ❌ 错误：循环中多次触发隐式动画
for (UIView *view in views) {
    view.alpha = 0.5; // 每次都创建新的 CATransaction
}

// ✅ 正确：显式包裹在单个 transaction 中
[CATransaction begin];
for (UIView *view in views) {
    view.alpha = 0.5;
}
[CATransaction commit];
```

---

## 5. 知识图谱总结

```
RunLoop（CFRunLoop / NSRunLoop）
├── 与线程
│   ├── 一对一绑定；主线程系统自动跑；子线程须 run / runMode:beforeDate:
│   └── 目的：有事件干活，无事件休眠（省 CPU）
├── Mode
│   ├── 常见：kCFRunLoopDefaultMode、UITrackingRunLoopMode、commonModes（并集）
│   └── 同一时刻只跑一种 Mode → Timer/源 要挂在「当前会跑」的 Mode 上
├── 输入与观察
│   ├── Source0：用户态触发，须 wakeUp，处理 UI、performSelector 等
│   ├── Source1：port / 内核事件，可唤醒 RunLoop
│   ├── Timers：依赖 Mode；默认 Default → 滑动进 Tracking 易「停表」
│   └── Observer：Entry / BeforeTimers / BeforeSources / BeforeWaiting / AfterWaiting / Exit
├── 一圈主流程（⭐⭐⭐ 深度理解）
│   ├── BeforeTimers/BeforeSources = "通知"，不做处理
│   ├── 【真正处理 Timer】在 BeforeSources 之后
│   ├── 【UI 任务处理】在 BeforeWaiting 之前⭐⭐⭐
│   │   ├── AutoLayout（计算布局）
│   │   ├── drawRect（自定义绘制）
│   │   ├── 图片解码
│   │   └── CA Commit（提交渲染）
│   ├── 【判断 Source1】有则 goto handle_msg（跳过休眠）⭐⭐⭐
│   ├── BeforeWaiting → CoreAnimation commit（在 Observer 回调内部）⭐⭐⭐
│   ├── mach_msg = 只在真正休眠时调用
│   └── 每一轮不一定都休眠（有 Source1 或无事件源时）
├── 关键细节（⭐⭐⭐⭐ 高频面试）
│   ├── Timer 处理时机：BeforeTimers 是通知，真正处理在之后
│   ├── UI 任务处理：主要在 BeforeWaiting 之前（AutoLayout、drawRect、图片解码）⭐⭐⭐
│   ├── CoreAnimation commit：在 BeforeWaiting Observer 回调内部执行
│   ├── 卡顿本质：RunLoop 无法及时进入 BeforeWaiting（因为 UI 任务耗时）⭐⭐⭐
│   ├── 卡顿监控：监听 kCFRunLoopAllActivities，通过 semaphore + timeout 检测状态变化⭐⭐⭐
│   ├── 状态定位：BeforeSources/AfterWaiting = 业务逻辑；BeforeWaiting = 渲染问题⭐⭐⭐⭐
│   ├── Source1 跳转：goto handle_msg，跳过 BeforeWaiting/mach_msg/AfterWaiting
│   ├── mach_msg 调用：只在真正休眠时（无 Source1、有事件源时）
│   └── 休眠判断：有 Source1 不休眠，无事件源直接退出
├── 与周边系统
│   ├── AutoreleasePool：主线程 Pool 与 RunLoop 周期配合 drain（见 §2.7）
│   ├── CADisplayLink：挂 CommonModes，随刷新回调
│   └── GCD：主队列「进主线程 RunLoop」；普通并发队列不依赖 RunLoop
└── 实战速记
    ├── NSTimer 滑动不走 → 换 CommonModes 或 dispatch_source_t
    ├── 常驻线程 → 子线程 + 输入源（如 NSPort）+ while + runMode
    ├── 卡顿监控 → 监听 kCFRunLoopAllActivities，重点关注 BeforeSources 和 AfterWaiting⭐⭐⭐
    ├── 监控原理 → 真正的卡顿表现为 RunLoop 长时间无法进入 BeforeWaiting
    ├── 状态定位 → BeforeSources/AfterWaiting = 业务逻辑；BeforeWaiting = 渲染问题⭐⭐⭐⭐
    └── 性能优化 → 16.67ms 帧预算，BeforeWaiting 之前必须完成所有 UI 任务
```

---

## 6. 参考资料

### 官方文档
- [CFRunLoop Reference](https://developer.apple.com/library/archive/documentation/CoreFoundation/Reference/CFRunLoopRef/)
- [Threading Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/)

### 优质文章
- [深入理解 RunLoop](https://blog.ibireme.com/2015/05/18/runloop/) (ibireme)
- [RunLoop 官方文档翻译](https://www.jianshu.com/p/6d6316201382)
- [RunLoop 在 iOS 中的应用](https://www.jianshu.com/p/8d64b2e32c54)

### 相关 Demo
- [YYText](https://github.com/ibireme/YYText) - 异步绘制和排版
- [AsyncDisplayKit](https://github.com/facebookarchive/AsyncDisplayKit) - 异步 UI 渲染

---

**最后更新**：2026-05-09（补充工业级卡顿监控的状态定位原理）
**状态**：✅ 已完善并修正
