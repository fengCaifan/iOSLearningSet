# 内存优化-OOM 与 Jetsam

> 一句话总结：**Jetsam 在系统内存吃紧时按优先级回收进程；治理要关注 footprint、泄漏、大图与后台存活。**  
> **内存专题 Q&A** 见 [面试模拟-04-内存优化.md](../../09-面试复盘/面试模拟/面试模拟-04-内存优化.md)；**FOOM 口径** 见 [面试模拟-06-FOOM归因方案.md](../../09-面试复盘/面试模拟/面试模拟-06-FOOM归因方案.md)。

---

## 📚 学习地图

- **预计学习时间**：35 分钟
- **前置知识**：虚拟内存、ARC
- **学习目标**：内存分类 → OOM 原因 → 策略

---

## 3. 内存优化

### 3.1 内存分类

| 类型 | 说明 | 示例 | 可回收 |
|------|------|------|--------|
| **Clean Memory** | 可从磁盘重新加载 | 代码段、只读数据 | ✅ 是 |
| **Dirty Memory** | 已修改，无法回收 | 堆对象、图片缓存 | ❌ 否 |
| **Compressed Memory** | 系统压缩的 dirty pages | 不活跃的 dirty pages | ✅ 是（解压后） |

### 3.2 OOM 与 Jetsam

**Jetsam 机制**：

```
内存压力 → memorystatus_monitor → 按优先级杀进程
优先级（从高到低）：
1. 前台 App
2. Audio App
3. 后台 App - Recent
4. 后台 App - Long-term
5. 后台 App - Suspended
```

**监控 OOM**：

```swift
func checkMemoryPressure() {
    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

    let result = withUnsafeMutablePointer(to: &stats) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
        }
    }

    if result == KERN_SUCCESS {
        let free = stats.free_count
        let active = stats.active_count
        let inactive = stats.inactive_count
        let wired = stats.wire_count
        let total = free + active + inactive + wired

        let usage = Double(active + wired) / Double(total)
        print("Memory usage: \(usage * 100)%")

        if usage > 0.85 {
            print("⚠️ High memory pressure!")
        }
    }
}
```

### 3.3 内存优化策略

**大图降采样**：

```objective-c
UIImage * downsampleImage(UIImage *image, CGSize size) {
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)UIImageJPEGRepresentation(image, 1), nil);

    NSDictionary *options = @{
        (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageIfAbsent: @YES,
        (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize: @(MAX(size.width, size.height)),
        (__bridge NSString *)kCGImageSourceShouldCacheImmediately: @YES
    };

    CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    UIImage *result = [UIImage imageWithCGImage:thumbnail];

    CGImageRelease(thumbnail);
    CFRelease(source);

    return result;
}
```

**图片内存计算**：

```
1024 x 1024 图片的内存占用：
- 未解码（磁盘）：~300KB（JPEG 压缩）
- 解码后（内存）：1024 x 1024 x 4 字节 = 4MB
- 使用 @3x 设备：1024 x 1024 x 4 x 3 = 12MB
```

**避免内存泄漏**：

```objective-c
// ❌ 循环引用
self.handler = ^{
    [self doSomething];
};

// ✅ 使用 weak
__weak typeof(self) weakSelf = self;
self.handler = ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (strongSelf) {
        [strongSelf doSomething];
    }
};
```

### 3.4 FOOM 归因（与 OOM / 崩溃统计）

**FOOM（常见口径）**：用户感知「前台闪退」，但 **未进入应用自捕获的 crash 回调**。其中一大块是 **Jetsam（内存被杀）**；另含 **Watchdog**、用户强杀、系统杀进程等，**定义因团队而异**。

**判定条件（示例）**：上次处于 **前台**、**无版本升级**、**无系统升级**、**无捕获到的 crash** 等；更严方案（如参考业界）还会排除 **exit、用户强杀、后台启动** 等，**口径越严、数量越少、越接近「真问题」**。

**易误判场景**（整理文档要点）：

- **`applicationState` 短暂 Active**：系统唤醒后很快退出，并非真实用户会话；可 **延迟 N 秒** 再认定一次有效前台启动（降低误判，难彻底消除）。
- **Crash 漏报**：SDK **写盘失败**、**二次 crash** 等，实际为 crash 却记入 FOOM；可探讨 **本地 crashlog 痕迹** 与 FOOM 互证。
- **Watchdog**：无法被应用捕获；可与 **卡顿监控最后一次主线程栈** 等结合做 **辅助归因**。

**治理顺序**：业务早期可 **粗粒度** 看趋势；**内存与泄漏** 治理后，再 **收紧 FOOM 判定**、对齐更严监控（如 Matrix 思路）做数据校准。

### 3.5 实战补充（与业务文档一致）

- **footprint**：除 Instruments 外，**Xcode Memory Gauge** 对 **瞬时尖峰** 往往更敏感。
- **Allocations Generation Mark**：适合「滑动/滚动中对象持续上涨」类问题。
- **独立缓存命名空间**：如 **语音房** 单独图片 cache、限制 memory/disk，**退房或离开场景清理**；Feed 刷新可清旧图缓存。
- **WKWebView**：实现 `webViewWebContentProcessDidTerminate` 并 **reload**。
- **典型案例**：在 **scroll 回调** 中反复切换导航栏大图 → footprint 陡升，**标志位只执行一次**；第三方富文本在 **未约束宽度** 下设置对齐导致 **巨大临时布局**，用 **注释二分 + Memory Gauge** 定位。

---


| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **卡顿的原因？** | 主线程耗时、离屏渲染、复杂布局、锁等待 | ⭐⭐⭐⭐ |
| **如何监控卡顿？** | RunLoop Observer、CADisplayLink、子线程 Ping 主线程 | ⭐⭐⭐⭐⭐ |
| **如何优化离屏渲染？** | shadowPath、shouldRasterize、异步绘制 | ⭐⭐⭐⭐ |
| **Instruments 如何使用？** | Time Profiler、Allocations、Leaks、Core Animation | ⭐⭐⭐ |


---

## 8. 参考资料

### 优质文章
- [iOS App启动优化与二进制重排](https://juejin.cn/post/6844904165773328392)
- [美团App冷启动治理](https://www.jianshu.com/p/8e0b38719278)
- [iOS Memory Deep Dive](https://developer.apple.com/videos/play/wwdc2018/416/)
- [Xcode Instruments: Find Memory Leaks in 5 Minutes](https://medium.com/@chandra.welim/xcode-instruments-find-memory-leaks-in-5-minutes-not-hours-4f80982e3682)
- [Mastering iOS Profiler Instruments](https://medium.com/@asherazeem25/mastering-ios-profiler-instruments-a-complete-guide-to-performance-optimization-9a4813a059a1)
- [Crash Analytics in iOS (2026): A Complete Practical Guide](https://medium.com/@garejakirit/crash-analytics-in-ios-2026-a-complete-practical-guide-d2c0b9c0cec5)
- [The ultimate guide to symbolica ting iOS crash reports](https://www.zoho.com/apptics/digest/ios-crash-debugging-guide.html)

### 开源项目
- [MLeaksFinder](https://github.com/Tencent/MLeaksFinder) - 腾讯内存泄漏检测工具
- [OOMDetector](https://github.com/Tencent/OOMDetector) - 腾讯 OOM 监控工具
- [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) - 日志框架
- [PLCrashReporter](https://github.com/microsoft/plcrashreporter) - 崩溃报告框架

### Apple 官方文档
