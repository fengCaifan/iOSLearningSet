# 内存管理-ARC 与 AutoreleasePool

> 一句话总结：**iOS 内存管理基于引用计数，OC 通过 MRC/ARC 管理对象生命周期，Swift 通过 ARC 管理引用类型，两者底层都依赖 TaggedPointer、isa 优化和 SideTable，理解内存分配、引用计数、自动释放池和循环引用是 iOS 开发的核心能力。**

---

## 📚 学习地图

- **预计学习时间**：60 分钟
- **前置知识**：OC/Swift 基础、指针概念
- **学习目标**：理解内存布局 → 掌握引用计数机制 → 解决循环引用 → 对比 OC/Swift 差异

---
## 1. 内存布局基础

### 1.1 虚拟内存分布

iOS 进程的虚拟内存地址从低到高依次为：

| 区域 | 存储内容 | 生命周期 | 特点 |
|------|---------|----------|------|
| **代码区** | 二进制指令 | 程序整个生命周期 | 只读，可共享 |
| **已初始化数据区** | 已初始化全局变量、静态变量、字符串常量 | 程序整个生命周期 | 程序启动前确定 |
| **未初始化数据区（BSS）** | 未初始化全局变量、静态变量 | 程序整个生命周期 | 程序启动前清零 |
| **堆区** | alloc/对象、copy 后的 Block | 程序员管理（ARC/MRC） | 从低地址向高地址扩展 |
| **栈区** | 函数参数、局部变量 | 随函数调用自动管理 | 从高地址向低地址扩展 |

```objective-c
// 堆区对象
NSObject *obj = [[NSObject alloc] init]; // 堆区

// 栈区变量
int a = 10; // 栈区
```

### 1.2 Tagged Pointer 优化

**什么是 Tagged Pointer**：

小对象（如 NSNumber、NSDate、小字符串）不需要单独分配内存，直接将数据编码在指针中。

**优势**：
- 节省内存（不需要单独分配堆内存）
- 提高性能（无需引用计数管理）
- 加快访问速度（一次内存访问 vs 两次）

**识别方法**：

```objective-c
NSNumber *num1 = @10;
NSNumber *num2 = @0x10000000000; // 超出 Tagged Pointer 范围

NSLog(@"num1 class: %@", [num1 class]); // __NSCFNumber (Tagged Pointer)
NSLog(@"num2 class: %@", [num2 class]); // __NSCFNumber (普通对象)
```

**Tagged Pointer 结构**：

```
指针的 64 位被拆分为两部分：
- 高位：特殊标记位（标识这是 Tagged Pointer）
- 低位：实际数据（如数值、字符串内容）
```

---

## 2. OC 引用计数机制

### 2.1 MRC vs ARC

| 特性 | MRC | ARC |
|------|-----|-----|
| **内存管理方式** | 手动调用 retain/release/autorelease | 编译器自动插入 retain/release |
| **程序员工作** | 手动管理每个对象的生命周期 | 专注于业务逻辑 |
| **常见错误** | 忘记 release 导致内存泄漏，过度 release 导致崩溃 | 循环引用 |
| **编译器支持** | Xcode 4.2 之前 | Xcode 4.2 及以后 |

### 2.2 引用计数存储

iOS 使用 **三种方式** 存储引用计数：

#### 方式一：Tagged Pointer

小对象，指针本身存储数据，无需引用计数。

#### 方式二：NONPOINTER_ISA（64位架构优化）

**isa 指针的 64 位分布**：

```
| 位段 | 说明 |
|------|------|
| 第 1 位 | 是否是纯 isa 指针（0 = 纯指针，1 = 非） |
| 第 2 位 | 是否有关联对象 |
| 第 3 位 | 是否使用 ARC |
| 第 4-33 位 | 类对象的内存地址 |
| 第 34 位 | magic（用于调试） |
| 第 35 位 | 是否有弱引用指针 |
| 第 36 位 | 是否正在执行 dealloc |
| 第 37 位 | 引用计数是否过大（需要使用 SideTable） |
| 第 38-63 位 | 实际的引用计数值（extra_rc） |
```

**优化**：当引用计数较小时（<10），直接存储在 isa 中，无需访问 SideTable。

#### 方式三：SideTable（散列表）

**SideTable 结构**：

```objective-c
struct SideTable {
    spinlock_t slock;           // 自旋锁
    RefcountMap refcnts;        // 引用计数表（哈希表）
    weak_table_t weak_table;    // 弱引用表（哈希表）
};
```

**为什么使用多个 SideTable？**

```
单表问题：多线程访问需要频繁加锁，性能差
多表优势：通过 hash 算法分流，不同对象可能在不同表，减少锁竞争
```

**Hash 算法**：

```objective-c
// 通过对象地址对 SideTables 个数取余，定位到对应的 SideTable
index = pointer_address % number_of_side_tables
```

### 2.3 引用计数操作

**alloc**：

```
创建对象时，并没有设置引用计数为 1。
retainCount 返回 1 是因为：局部变量初始化为 1 + isa/SideTable 中的存储值（实际为 0）。
```

**retain**：

```
1. 通过对象地址 hash 定位到 SideTable
2. 找到对应的 refcnts
3. 值 + 1（实际是位移操作：+4，因为前两位用于标记）
```

**release**：

```
1. 通过对象地址 hash 定位到 SideTable
2. 找到对应的 refcnts
3. 值 - 1（实际是位移操作：-4）
4. 如果值为 0，触发 dealloc
```

**retainCount**：

```
返回值 = 1（初始值）+ isa 中的 extra_rc + SideTable 中存储的值
```

---

## 3. AutoreleasePool 自动释放池

### 3.1 基本概念

**作用**：延迟释放对象，避免临时对象占用内存。

**编译器转换**：

```objective-c
// 编写代码
@autoreleasepool {
    Person *p = [[Person alloc] init];
}

// 编译器转换为
void *ctx = objc_autoreleasePoolPush();
Person *p = [[Person alloc] init];
objc_autoreleasePoolPop(ctx);
```

### 3.2 底层实现

**AutoreleasePoolPage 双向链表**：

```objective-c
class AutoreleasePoolPage {
    magic_t const magic;          // 校验位
    __unsafe_unretained id *next; // 指向下一个可插入的位置
    pthread_t const thread;       // 线程
    AutoreleasePoolPage *child;   // 子节点
    AutoreleasePoolPage *parent;  // 父节点
    uint32_t depth;               // 深度
    uint32_t hiwat;               // 水位线
    id *POOL_BOUNDARY;            // 哨兵对象
};
```

**结构图**：

```
Parent Page         Current Page         Child Page
+---------------+   +---------------+   +---------------+
| POOL_BOUNDARY | ← | POOL_BOUNDARY | ← | POOL_BOUNDARY |
|  obj1         |   |  obj3         |   |  obj5         |
|  obj2         |   |  obj4         |   |  obj6         |
+---------------+   +---------------+   +---------------+
       ↑                    ↑                    ↑
     parent              current             child
```

### 3.3 AutoreleasePool 与 RunLoop

**关系**：

```
RunLoop 的每个 Event 都会创建 AutoreleasePool：
- Entry：Push 创建新的 AutoreleasePool
- BeforeWaiting：Pop 旧池 + Push 新池（清理临时对象）
- Exit：Pop 释放池
```

**子线程的 AutoreleasePool**：

```
主线程：RunLoop 自动管理，无需手动创建
子线程：默认没有 RunLoop，需要手动创建 @autoreleasepool
```

### 3.4 实战应用

**for 循环中大量临时对象**：

```objective-c
// ❌ 不加 autoreleasepool，内存峰值高
for (int i = 0; i < 100000; i++) {
    NSData *data = [NSData dataWithContentsOfURL:url];
    // data 会一直累积，直到循环结束
}

// ✅ 每次循环手动释放
for (int i = 0; i < 100000; i++) {
    @autoreleasepool {
        NSData *data = [NSData dataWithContentsOfURL:url];
    } // 每次循环结束，data 就被释放
}
```

---

## 8. 高频面试题

### 8.1 内存布局与 Tagged Pointer

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **iOS 内存布局是怎样的？** | 代码区、数据区、堆区、栈区，从低到高 | ⭐⭐ |
| **Tagged Pointer 是什么？** | 小对象优化，数据存储在指针中，无需引用计数 | ⭐⭐⭐ |
| **Tagged Pointer 有什么优势？** | 节省内存、提高性能、减少堆内存分配 | ⭐⭐⭐ |
| **如何判断一个对象是 Tagged Pointer？** | 检查 isa 的最低位或使用 isKindOfClass | ⭐⭐⭐⭐ |

### 8.2 引用计数与 ARC

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **引用计数存储在哪里？** | TaggedPointer（无）→ isa（extra_rc）→ SideTable | ⭐⭐⭐⭐ |
| **为什么有多个 SideTable？** | 分散锁竞争，提高并发性能 | ⭐⭐⭐⭐ |
| **alloc 后引用计数是 1 吗？** | 实际为 0，retainCount 返回 1 是因为初始值+存储值 | ⭐⭐⭐⭐ |
| **ARC 和 MRC 的区别？** | ARC 是编译器自动插入 retain/release，MRC 手动管理 | ⭐⭐⭐ |

### 8.3 AutoreleasePool

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **AutoreleasePool 底层数据结构？** | AutoreleasePoolPage 双向链表 + 哨兵对象 | ⭐⭐⭐ |
| **AutoreleasePool 什么时候释放？** | RunLoop 的 BeforeWaiting、Exit 时 pop | ⭐⭐⭐⭐ |
| **子线程需要创建 AutoreleasePool 吗？** | 需要，子线程默认无 RunLoop | ⭐⭐⭐ |
| **for 循环中什么时候用 @autoreleasepool？** | 大量临时对象，及时释放降低内存峰值 | ⭐⭐⭐ |

### 8.4 Weak 指针

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **weak 的实现原理？** | weak_table 哈希表存储 weak 指针数组 | ⭐⭐⭐⭐ |
| **对象释放时 weak 如何自动置 nil？** | dealloc → weak_clear_no_lock → 遍历置 nil | ⭐⭐⭐⭐⭐ |
| **weak 和 assign 的区别？** | weak 自动置 nil，assign 不置（野指针） | ⭐⭐⭐⭐ |
| **大量使用 weak 会有性能问题吗？** | 需维护 weak_table，有一定开销 | ⭐⭐⭐ |

### 8.5 循环引用

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **常见的循环引用场景？** | delegate、Block、Timer、通知中心 | ⭐⭐⭐ |
| **NSTimer 为什么循环引用？** | RunLoop → Timer → target(self) | ⭐⭐⭐⭐ |
| **如何解决 NSTimer 循环引用？** | 中间代理、Block-based Timer + weak | ⭐⭐⭐⭐ |
| **如何检测内存泄漏？** | Instruments Leaks、Memory Graph、MLeaksFinder | ⭐⭐⭐⭐ |

### 8.6 Swift 内存管理

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **weak 和 unowned 的区别？** | weak 可选自动置 nil，unowned 不可选不置 nil | ⭐⭐⭐⭐ |
| **什么时候用 unowned？** | 对象生命周期一定比当前对象长 | ⭐⭐⭐ |
| **什么是 Copy-on-Write？** | 多个变量共享数据，修改时才拷贝 | ⭐⭐⭐ |
| **Struct 和 Class 如何选择？** | 默认 Struct，需要引用语义或继承时 Class | ⭐⭐⭐ |

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
