# 内存优化 — OOM 与 Jetsam

> 一句话总结：

## 1. 核心概念

<!-- 建议涵盖：
  - OOM（Out Of Memory）：系统因内存不足而杀掉 App
  - Jetsam：iOS 内核的内存管理机制（类似 Linux 的 OOM Killer）
  - 前台 OOM vs 后台 OOM
  - Dirty Memory / Clean Memory / Compressed Memory
-->



## 2. 底层原理

<!-- 建议涵盖：
  - Jetsam 机制：内存压力 → memorystatus → 按优先级杀进程
  - Dirty Memory：已修改的内存页，不可被回收（malloc、UIImage 解码后的数据）
  - Clean Memory：可以被系统回收再从磁盘重新加载的内存（代码段、mmap 只读文件）
  - Compressed Memory：系统压缩不活跃的 dirty pages
  - footprint 与 phys_footprint 的区别
  - 内存水位线（memory limit）：不同设备不同，可通过 os_proc_available_memory() 获取
  - App 内存组成：__TEXT / __DATA / Stack / Heap / Memory Mapped Files
-->



## 3. 关键问题 & 面试题

<!-- 
- Q: 什么是 OOM？如何监控？
  A: 

- Q: Dirty Memory 和 Clean Memory 的区别？
  A: 

- Q: 一张 1024x1024 的图片在内存中占多少空间？
  A: 

- Q: 如何降低 App 的内存占用？
  A: 
-->



## 4. 实战应用

<!-- 例如：
  - 大图降采样（ImageIO CGImageSourceCreateThumbnailAtIndex）
  - 内存峰值监控与报警
  - 内存占用分析工具：Xcode Memory Report / vmmap / Allocations
-->



## 5. 参考资料

