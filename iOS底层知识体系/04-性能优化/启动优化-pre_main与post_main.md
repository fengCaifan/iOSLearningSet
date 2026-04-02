# 启动优化 — pre-main 与 post-main

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - 启动的定义：冷启动 vs 温启动 vs 热启动
  - pre-main 阶段：dyld 加载 → rebase/binding → ObjC setup → initializers（+load）
  - post-main 阶段：main() → didFinishLaunching → 首屏渲染完成
-->



## 2. 底层原理

<!-- 建议涵盖：
  - dyld3 / dyld4 的优化（启动闭包缓存）
  - rebase 和 binding 的区别与优化（减少 ObjC 类/selector/category 数量）
  - +load 方法对启动的影响与治理
  - 二进制重排：基于 Clang 插桩（-fsanitize-coverage）获取启动期调用函数 → 生成 order file → Page Fault 优化
  - 启动任务调度框架设计：依赖图 + 优先级 + 主线程/子线程分配
  - System Trace / App Launch Instrument 的使用
  - MetricKit 的 MXAppLaunchMetric
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: App 冷启动的完整流程？
  A: 

- Q: 如何优化 pre-main 阶段？
  A: 

- Q: 什么是二进制重排？为什么能优化启动？
  A: 

- Q: 如何度量和监控启动耗时？
  A: 

- Q: 启动任务过多怎么管理？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 你在项目中如何将启动时间从 X 秒优化到 Y 秒
  - 启动任务调度框架的设计与实现
  - +load 方法的迁移方案
-->



## 5. 参考资料

