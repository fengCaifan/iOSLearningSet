# 包体积优化-LinkMap 与资源瘦身

> 一句话总结：**包体=二进制+资源；Link Map/无用类/图片压缩与 On Demand Resources 组合使用，才能可持续瘦身。**

---

## 📚 学习地图

- **预计学习时间**：30 分钟
- **前置知识**：Mach-O 基础
- **学习目标**：度量 → 裁剪代码与资源

---

## 6. 包体积优化

### 6.1 分析工具

**生成 Link Map**：

```
Build Settings → Write Link Map File: YES
编译后生成文件：build/xxx.app/LinkMap-normal-xxx.txt
```

**分析 Link Map**：

```
# 文件结构：
1. Object files（目标文件）
2. Sections（段）
3. Symbols（符号及大小）

# 查找大文件：
grep '.o' linkmap.txt | awk '{print $2, $3}' | sort -k2 -rn | head -20
```

### 6.2 优化策略

| 优化项 | 具体措施 | 工具 |
|--------|---------|------|
| **资源优化** | 压缩图片、移除无用资源 | ImageOptim、Asset Catalog |
| **代码瘦身** | 移除无用代码、类 | AppCode、Dead Code Stripping |
| **编译优化** | 优化级别、开启 Bitcode | Build Settings |
| **动态库** | 懒加载、合并功能相近库 | dlopen |
| **Swift 优化** | 优化编译器选项、减少泛型 | Build Settings |

**资源优化**：

```bash
# 使用 ImageOptim 压缩 PNG
find . -name "*.png" -exec imageoptim {} \;

# 使用 Asset Catalog 的 App Thinning
# Xcode 自动根据设备生成对应尺寸的图片
```

**开启优化选项**：

```
Build Settings:
- Dead Code Stripping: YES
- Optimization Level: Fastest, Smallest [-Os]
- Strip Debug Symbols During Copy: YES
- Strip Swift Symbols: YES
- Make Strings Read-Only: YES
```

---

| **如何降低内存占用？** | 降采样、对象池、及时释放、避免缓存 | ⭐⭐⭐⭐ |
| **如何检测内存泄漏？** | Instruments Leaks、Memory Graph、MLeaksFinder | ⭐⭐⭐ |

### 7.4 崩溃处理

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
