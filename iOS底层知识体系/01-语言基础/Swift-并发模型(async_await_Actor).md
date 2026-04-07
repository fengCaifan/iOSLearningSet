# Swift 并发模型(async/await/Actor)

> 一句话总结：**Swift 并发以 async/await 表达异步、以 Actor / MainActor 隔离可变状态，在编译期帮助减少数据竞争。**

---

## 📚 学习地图

- **预计学习时间**：35 分钟
- **前置知识**：GCD、内存管理
- **学习目标**：Task/Cancellation → async 函数 → Actor 与 MainActor

---

## 1. Swift 并发（async/await/Actor）

### 1.1 Swift 并发基础

```swift
// 异步执行
Task {
    await fetchData()
}

// 任务组（结构化并发）
await withTaskGroup(of: Void.self) { group in
    group.addTask { await task1() }
    group.addTask { await task2() }
}
```

### 1.2 Actor（隔离）

```swift
actor Counter {
    var value = 0

    func increment() -> Int {
        value += 1
        return value
    }
}

@MainActor
class UIUpdater {
    func updateUI() {
        // UI 更新代码
    }
}
```


---

## 2. 参考资料

### 优质文章
- [iOS 面试题\| GCD 和NSOperation 有啥区别？](https://juejin.cn/post/7360879591235551266)
- [iOS多线程之GCD、OperationQueue 对比和实践记录](https://cloud.tencent.com/developer/article/1692252)
- [iOS多线程之四：NSOperation的使用](https://cloud.tencent.com/developer/article/1334777)

---

**最后更新**：2026-04-07
