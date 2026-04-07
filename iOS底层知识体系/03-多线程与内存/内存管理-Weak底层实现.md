# 内存管理-Weak 底层实现

> 一句话总结：**weak 由全局 weak 表维护指向关系；对象释放时 Runtime 统一将 weak 引用置 nil，避免悬空指针。**

---

## 📚 学习地图

- **预计学习时间**：25 分钟
- **前置知识**：ARC、SideTable
- **学习目标**：weak 表结构 → dealloc 清理流程 → weak/assign/unsafe 差异

---

## 4. Weak 弱引用实现

### 4.1 基本概念

**作用**：
- 不增加引用计数
- 对象释放后自动置为 nil
- 打破循环引用

**使用场景**：

```objective-c
@property (nonatomic, weak) id delegate;          // delegate
__weak typeof(self) weakSelf = self;              // Block
@property (nonatomic, weak) IBOutlet UIButton *btn; // IBOutlet
```

### 4.2 底层实现

**weak 注册流程**：

```
objc_initWeak
    ↓
storeWeak(&newObj)
    ↓
weak_register_no_lock(&newObj, location)
    ↓
// 1. 通过对象地址 hash 定位到 weak_table
// 2. 查找或创建 weak_entry_t
// 3. 将 weak 指针添加到 weak_entry_t 的数组中
```

**weak_table 结构**：

```objective-c
struct weak_table_t {
    weak_entry_t *weak_entries; // 弱引用数组
    size_t num_entries;          // 数组大小
    uintptr_t mask;             // hash mask
    uintptr_t max_hash_collision; // 最大冲突次数
};

struct weak_entry_t {
    DisguisedPtr<objc_object> referent; // 被引用对象
    objc_object **weak_referrers;       // weak 指针数组
};
```

### 4.3 对象释放时 weak 置 nil

**流程**：

```
dealloc
    ↓
objc_destructInstance
    ↓
clearDeallocating
    ↓
weak_clear_no_lock
    ↓
// 1. 通过对象地址在 weak_table 中查找 weak_entry_t
// 2. 遍历 weak_referrers 数组
// 3. 将每个 weak 指针置为 nil
```

**完整示例**：

```objective-c
__weak NSString *weakStr = [[NSString alloc] initWithFormat:@"Test"];
NSLog(@"Before: %@", weakStr); // Test
// (对象超出作用域，释放)
NSLog(@"After: %@", weakStr);  // nil（自动置 nil）
```

### 4.4 weak vs assign vs unsafe_unretained

| 特性 | weak | assign | unsafe_unretained |
|------|------|--------|-------------------|
| **是否增加引用计数** | 否 | 否 | 否 |
| **对象释放后** | 自动置 nil | 不置 nil（野指针） | 不置 nil（野指针） |
| **适用类型** | 对象 | 基本数据类型 | 对象（已废弃） |
| **性能** | 需维护 weak_table | 直接赋值 | 直接赋值 |

**delegate 为什么用 weak？**

```objective-c
// ❌ 使用 assign 可能导致野指针崩溃
@property (nonatomic, assign) id delegate;
// 如果 delegate 对象被释放，再次调用会 crash

// ✅ 使用 weak 安全
@property (nonatomic, weak) id delegate;
// 对象释放后自动置 nil，调用无效果但不会 crash
```

---


## 3. 高频面试题（Weak）

### 8.4 Weak 指针

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **weak 的实现原理？** | weak_table 哈希表存储 weak 指针数组 | ⭐⭐⭐⭐ |
| **对象释放时 weak 如何自动置 nil？** | dealloc → weak_clear_no_lock → 遍历置 nil | ⭐⭐⭐⭐⭐ |
| **weak 和 assign 的区别？** | weak 自动置 nil，assign 不置（野指针） | ⭐⭐⭐⭐ |
| **大量使用 weak 会有性能问题吗？** | 需维护 weak_table，有一定开销 | ⭐⭐⭐ |


---

## 9. 参考资料

### 优质文章
- [YTMemoryLeakDetector iOS内存泄漏检测工具类](https://segmentfault.com/a/1190000012121342)
- [自动检测VC内存泄漏](https://www.jianshu.com/p/870318df8b47)
- [深入探索iOS内存优化](https://juejin.cn/post/6864492188404088846)
- [Mastering Swift's Memory Management: ARC, Weak, Unowned](https://medium.com/@commitstudiogs/mastering-swifts-memory-management-arc-weak-unowned-and-strong-references-74f40f069994)

### 开源项目
- [FBRetainCycleDetector](https://github.com/facebook/FBRetainCycleDetector) - Facebook 循环引用检测工具
- [MLeaksFinder](https://github.com/Tencent/MLeaksFinder) - 腾讯内存泄漏检测工具

---

**最后更新**：2026-04-07
**状态**：✅ 已完成

**Sources:**
- [Mastering Swift's Memory Management: ARC, Weak, Unowned](https://medium.com/@commitstudiogs/mastering-swifts-memory-management-arc-weak-unowned-and-strong-references-74f40f069994)
- [深入探索iOS内存优化](https://juejin.cn/post/6864492188404088846)
- [YTMemoryLeakDetector iOS内存泄漏检测工具类](https://segmentfault.com/a/1190000012121342)
