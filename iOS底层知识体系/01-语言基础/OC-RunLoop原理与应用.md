# OC RunLoop 原理与应用

> 一句话总结：**RunLoop 是一个运行循环，可以让线程在有事做的时候做事，无事做的时候休息，节省 CPU 资源。**

---

## 📚 学习地图

- **预计学习时间**：30 分钟
- **前置知识**：多线程基础
- **学习目标**：理解 RunLoop → 掌握核心用法 → 解决实际面试题

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
│  6. 检查是否有 Source1，有则跳转到步骤9                     │
│  7. 通知 Observer：BeforeWaiting                            │
│  8. 休眠，等待 mach_port 消息                               │
│  9. 被唤醒，通知 Observer：AfterWaiting                     │
│ 10. 处理唤醒消息（Timer / Source1 / GCD Block）             │
│ 11. 跳回步骤2                                               │
└─────────────────────────────────────────────────────────────┘
```

#### CFRunLoopRun 简化源码

```c
static int __CFRunLoopRun(CFRunLoopRef rl, CFRunLoopModeRef rlm, ...) {
    while (!stop) {
        // 1. 通知 Observer
        __CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeTimers);
        __CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeSources);

        // 2. 处理 Block
        __CFRunLoopDoBlocks(rl, rlm);

        // 3. 处理 Source0
        Boolean sourceHandled = __CFRunLoopDoSources0(rl, rlm);
        if (sourceHandled) {
            __CFRunLoopDoBlocks(rl, rlm);
        }

        // 4. 检查 Source1
        if (__CFRunLoopServiceMachPort(..., &livePort)) {
            goto handle_msg;
        }

        // 5. 通知 Observer：即将休眠
        __CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeWaiting);

        // 6. 休眠
        __CFRunLoopSetSleeping(rl);
        mach_msg(...);  // 休眠，等待消息
        __CFRunLoopUnsetSleeping(rl);

        // 7. 通知 Observer：刚被唤醒
        __CFRunLoopDoObservers(rl, rlm, kCFRunLoopAfterWaiting);

    handle_msg:
        // 8. 处理唤醒消息
        if (msg_is_timer) __CFRunLoopDoTimers(rl, rlm);
        else if (msg_is_dispatch) __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__(msg);
        else __CFRunLoopDoSource1(rl, rlm, rls);

        __CFRunLoopDoBlocks(rl, rlm);
    }
}
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

参见前面 4.4 节的完整实现

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

## 3. 面试题 & 常见问题

### 3.1 面试高频题

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
| **RunLoop 与 UI 渲染的关系？** | BeforeWaiting 时提交 CATransaction，触发渲染；必须在 16.67ms 内完成才能保持 60FPS | ⭐⭐⭐ |
| **CADisplayLink 与 NSTimer 的区别？** | CADisplayLink 与屏幕刷新率同步，更适合 UI 动画；NSTimer 是固定时间间隔 | ⭐⭐ |
| **什么是离屏渲染？** | 渲染到缓冲区而非直接显示，会触发额外性能开销；圆角、阴影、毛玻璃会触发 | ⭐⭐⭐ |
| **如何优化滑动流畅度？** | 异步绘制、减少图层数量、避免离屏渲染、按需渲染、使用 RunLoop 休眠时机处理任务 | ⭐⭐⭐ |
| **为什么是 16.67ms？** | 60Hz 屏幕刷新率，每帧 1000ms/60≈16.67ms；超过则掉帧 | ⭐⭐ |
| **卡顿产生的原理？** | 主线程被阻塞导致 RunLoop 处理时间超过 16.67ms，无法在屏幕刷新前完成渲染 | ⭐⭐⭐ |

### 3.2 常见陷阱

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

## 4. 实战应用（完整代码）

### 4.1 滑动时 NSTimer 不工作

**场景**：在 TableView 滑动时，NSTimer 停止工作

**解决方案**：

```objective-c
// ❌ 错误写法：只在 DefaultMode
NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerTick) userInfo:nil repeats:YES];

// ✅ 正确写法：使用 CommonModes
NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(timerTick) userInfo:nil repeats:YES];
[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
```

### 4.2 常驻线程（完整实现）

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

### 4.3 卡顿监控（信号量方案）

#### 原理

通过 Observer 监听 RunLoop 状态变化，使用信号量检测每次状态变化的耗时，超过阈值则认为卡顿。

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
                // 超时，检查是否处于休眠状态（休眠不算卡顿）
                if (self.activity == kCFRunLoopBeforeWaiting ||
                    self.activity == kCFRunLoopAfterWaiting) {
                    continue;
                }
                // 卡顿，上报堆栈
                NSArray *stack = [NSThread callStackSymbols];
                NSLog(@"⚠️ 检测到卡顿: %@", stack);
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

### 4.4 UITableView 卡顿优化

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

### 4.5 线程保活（防止崩溃后退出）

**原理**：在 Crash 处理中启动 RunLoop，防止线程退出

**注意**：这只是临时措施，真正的解决方案应该找到崩溃原因

### 4.6 FPS 监控工具

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

## 5. 参考资料

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

**最后更新**：2026-04-03
**状态**：✅ 已完成
