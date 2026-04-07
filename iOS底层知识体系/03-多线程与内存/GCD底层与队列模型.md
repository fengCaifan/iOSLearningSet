# GCD 底层与队列模型

> 一句话总结：**GCD 与 NSOperationQueue 是 iOS 两类核心并发原语：前者轻量高效，后者适合依赖、取消与并发度控制；再配上锁与 Swift 并发模型，构成完整并发知识链。**

---

## 📚 学习地图

- **预计学习时间**：50 分钟
- **前置知识**：多线程基础、内存管理
- **学习目标**：掌握 GCD / OperationQueue → 线程安全与锁 → Swift 并发（async/await/Actor）

---

## 1. GCD（Grand Central Dispatch）

### 1.1 什么是 GCD？

**GCD** 是 Apple 开发的一套基于 C 语言的底层 API，用于多线程编程，自动管理线程池。

**核心优势**：
- 自动管理线程生命周期
- 高效的线程池复用
- 简洁的 API

### 1.2 GCD 的核心概念

**队列（Dispatch Queue）**：

| 队列类型 | 说明 | 使用场景 |
|---------|------|----------|
| **Serial Queue** | 串行队列，一次只执行一个任务 | 同步访问、避免资源竞争 |
| **Concurrent Queue** | 并发队列，可同时执行多个任务 | 并行处理、提高效率 |

**创建队列**：

```objective-c
// 串行队列
dispatch_queue_t serialQueue = dispatch_queue_create("com.example.serial", DISPATCH_QUEUE_SERIAL);

// 并发队列
dispatch_queue_t concurrentQueue = dispatch_queue_create("com.example.concurrent", DISPATCH_QUEUE_CONCURRENT);

// 全局队列（系统提供的并发队列）
dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
```

### 1.3 GCD 的使用

#### 异步执行

```objective-c
dispatch_async(dispatch_get_global_queue(0, 0), ^{
    // 子线程执行耗时操作
    NSData *data = [NSData dataWithContentsOfURL:url];

    dispatch_async(dispatch_get_main_queue(), ^{
        // 回到主线程更新 UI
        self.imageView.image = [UIImage imageWithData:data];
    });
});
```

#### 延迟执行

```objective-c
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    NSLog(@"After 1 second");
});
```

#### Group（任务组）

```objective-c
dispatch_group_t group = dispatch_group_create();

// 添加任务
dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
    NSLog(@"Task 1");
});

dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
    NSLog(@"Task 2");
});

// 所有任务完成后的回调
dispatch_group_notify(group, dispatch_get_main_queue(), ^{
    NSLog(@"All tasks completed");
});

// 等待（会阻塞当前线程）
dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
```

#### Semaphore（信号量）

```objective-c
// 创建信号量（初始值为 0）
dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

// 等待信号（阻塞）
dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

// 发送信号
dispatch_semaphore_signal(semaphore);
```

**应用**：控制并发数量、同步资源

---

## 2. NSOperationQueue 与 NSOperation

### 2.1 什么是 NSOperationQueue？

**NSOperationQueue** 是 GCD 的面向对象封装，提供了更强大的任务控制能力。

**核心优势**：
- ✅ 面向对象，代码更清晰
- ✅ 可以设置任务优先级
- ✅ 可以设置最大并发数
- ✅ 支持任务依赖关系
- ✅ 可以取消任务

### 2.2 NSOperation 的使用

#### 创建 Operation

```objective-c
// 1. 使用 Block
NSBlockOperation *operation1 = [NSBlockOperation blockOperationWithBlock:^{
    NSLog(@"Operation 1");
}];

// 2. 自定义 Operation
@interface CustomOperation : NSOperation
@end

@implementation CustomOperation

- (void)main {
    // 任务代码
    NSLog(@"Custom Operation");
}

@end
```

#### 创建 Queue

```objective-c
NSOperationQueue *queue = [[NSOperationQueue alloc] init];
queue.maxConcurrentOperationCount = 3; // 最大并发数
queue.name = @"com.example.queue";
queue.qualityOfService = NSQualityOfServiceUserInitiated; // 优先级
```

#### 添加任务

```objective-c
[queue addOperation:operation1];
[queue addOperation:operation2];
```

### 2.3 任务依赖关系

```objective-c
NSOperation *operation1 = [NSBlockOperation blockOperationWithBlock:^{
    NSLog(@"Operation 1");
}];

NSOperation *operation2 = [NSBlockOperation blockOperationWithBlock:^{
    NSLog(@"Operation 2");
}];

NSOperation *operation3 = [NSBlockOperation blockOperationWithBlock:^{
    NSLog(@"Operation 3");
}];

// 设置依赖：operation3 依赖 operation1 和 operation2
[operation3 addDependency:operation1];
[operation3 addDependency:operation2];

[queue addOperation:operation1];
[queue addOperation:operation2];
[queue addOperation:operation3];

// 执行顺序：operation1/2 并发 → operation3
```

### 2.4 取消任务

```objective-c
// 取消所有任务
[queue cancelAllOperations];

// 取消特定操作
[operation cancel];
```

---

## 3. GCD vs NSOperationQueue 对比

### 3.1 核心差异

| 特性 | GCD | NSOperationQueue |
|------|-----|------------------|
| **执行效率** | ⭐ 更高 | 稍有性能开销 |
| **面向对象** | ❌ C语言API | ✅ 完全面向对象 |
| **并发控制** | FIFO顺序 | 可设置最大并发数 |
| **任务优先级** | QoS | 优先级 + 依赖关系 |
| **任务取消** | ❌ 不支持 | ✅ 支持 |
| **任务依赖** | ❌ 不支持 | ✅ 支持复杂依赖 |
| **代码可读性** | 相对较低 | ✅ 更易理解 |
| **线程安全** | 手动保证 | Queue 内部保证 |
| **适用场景** | 简单异步任务 | 复杂任务管理 |

### 3.2 何时使用哪个？

#### 使用 GCD 的场景：

```objective-c
// 简单的后台任务
dispatch_async(dispatch_get_global_queue(0, 0), ^{
    [self fetchUserData];
});

// 延迟执行
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    [self showTimeoutAlert];
});

// 单次执行
static dispatch_once_t onceToken;
dispatch_once(&onceToken, ^{
    [self setupSingleton];
});
```

#### 使用 NSOperationQueue 的场景：

```objective-c
// 需要控制并发数
NSOperationQueue *queue = [[NSOperationQueue alloc] init];
queue.maxConcurrentOperationCount = 2; // 最多2个并发

// 需要任务优先级
NSBlockOperation *highPriorityOp = [NSBlockOperation blockOperationWithBlock:^{}];
highPriorityOp.queuePriority = NSOperationQueuePriorityHigh;

// 需要任务依赖
[uploadOp addDependency:compressOp]; // 上传依赖压缩

// 需要取消任务
[queue cancelAllOperations];
```

---

## 4. 线程安全与数据竞争

### 4.1 数据竞争示例

```objective-c
// ❌ 不安全
@property (nonatomic, assign) NSInteger count;

- (void)increment {
    self.count++; // 不是原子操作
}

// ✅ 使用原子操作
@property (atomic, assign) NSInteger count;

// ✅ 使用锁
@property (nonatomic, strong) NSLock *lock;

- (void)increment {
    [self.lock lock];
    self.count++;
    [self.lock unlock];
}
```

### 4.2 线程安全的集合

| 集合 | 线程安全版本 |
|------|-----------|
| NSArray | ❌ 无 |
| NSMutableArray | ❌ 无 |
| NSDictionary | ❌ 无 |
| NSMutableDictionary | ❌ 无 |
| **NSMutableArray** | ❌ 无 |
| **NSMutableDictionary** | ❌ 无 |

**解决方案**：
```objective-c
// 使用串行队列
@property (nonatomic, strong) dispatch_queue_t queue;

- (void)setObject:(id)object forKey:(id)key {
    dispatch_barrier_async(self.queue, ^{
        [_dictionary setObject:object forKey:key];
    });
}

- (id)objectForKey:(id)key {
    __block id obj;
    dispatch_sync(self.queue, ^{
        obj = [_dictionary objectForKey:key];
    });
    return obj;
}
```

## 5. 高频面试题

### 5.1 GCD vs NSOperationQueue

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **GCD 和 NSOperationQueue 的区别？** | GCD 是底层 C API，性能高；OperationQueue 是面向对象封装，支持优先级、依赖、取消 | ⭐⭐⭐⭐ |
| **什么时候用 GCD？** | 简单异步任务、性能敏感 | ⭐⭐⭐ |
| **什么时候用 NSOperationQueue？** | 需要任务依赖、优先级控制、取消操作 | ⭐⭐⭐ |
| **如何控制并发数量？** | GCD：信号量；OperationQueue：maxConcurrentOperationCount | ⭐⭐⭐ |

### 5.2 其他并发面试题

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **Serial Queue 和 Concurrent Queue 的区别？** | Serial 一次执行一个，Concurrent 可同时执行多个 | ⭐⭐ |
| **dispatch_sync 的作用？** | 同步等待任务完成，可能导致死锁 | ⭐⭐⭐ |
| **如何避免死锁？** | 不要在串行队列中使用 dispatch_sync 执行同一个队列的任务 | ⭐⭐⭐⭐ |
| **NSOperationQueue 的依赖关系？** | addDependency，支持复杂的依赖图 | ⭐⭐⭐ |

## 6. 参考资料

### 优质文章
- [iOS 面试题\| GCD 和NSOperation 有啥区别？](https://juejin.cn/post/7360879591235551266)
- [iOS多线程之GCD、OperationQueue 对比和实践记录](https://cloud.tencent.com/developer/article/1692252)
- [iOS多线程之四：NSOperation的使用](https://cloud.tencent.com/developer/article/1334777)

---

**最后更新**：2026-04-07
