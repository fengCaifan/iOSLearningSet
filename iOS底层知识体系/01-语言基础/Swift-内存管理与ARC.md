# Swift-内存管理与 ARC

> 一句话总结：**Swift ARC 管引用类型；配合 weak/unowned、闭包捕获列表与值类型 COW，避免循环引用与意外峰值。**

---

## 📚 学习地图

- **预计学习时间**：35 分钟
- **前置知识**：OC 内存管理、值类型
- **学习目标**：ARC 规则 → COW → 闭包捕获

---

### 6.2 Copy-on-Write（写时复制）

**原理**：多个变量共享同一份数据，只有修改时才拷贝。

**支持的类型**：Array、Dictionary、Set 等。

**示例**：

```swift
var arr1 = [1, 2, 3]
var arr2 = arr1          // 共享数据，不拷贝
arr1.append(4)           // 触发 COW，arr1 拷贝一份数据再修改
print(arr2)              // [1, 2, 3]（不受影响）
```

**自定义 COW**：

```swift
struct CopyOnWriteBox<T> {
    private var _box: HeapBox<T>

    init(value: T) {
        _box = HeapBox(value)
    }

    var value: T {
        get { _box.value }
        set {
            if !isKnownUniquelyReferenced(&_box) {
                _box = HeapBox(newValue)
            } else {
                _box.value = newValue
            }
        }
    }

    private class HeapBox {
        var value: T
        init(_ value: T) { self.value = value }
    }
}
```

### 6.3 Swift ARC

**三种引用类型**：

```swift
// 1. strong（默认）
class Person {
    var name: String
    init(name: String) { self.name = name }
}

// 2. weak（可选，自动置 nil）
class ViewController {
    weak var delegate: SomeDelegate?
}

// 3. unowned（不可选，不自动置 nil）
class Person {
    unowned var creditCard: CreditCard
}
```

**weak vs unowned**：

| 特性 | weak | unowned |
|------|------|---------|
| **类型** | 可选（需要解包） | 不可选 |
| **自动置 nil** | ✅ 是 | ❌ 否 |
| **适用场景** | 对象可能被提前释放 | 对象生命周期一定比当前对象长 |
| **性能** | 需维护 Side Table | 无需 Side Table（性能稍好） |

**示例**：

```swift
// 使用 weak 的场景
class ViewController {
    weak var delegate: SomeDelegate? // delegate 可能被释放
}

// 使用 unowned 的场景
class Customer {
    unowned var creditCard: CreditCard // CreditCard 生命周期一定比 Customer 长
}

class CreditCard {
    var customer: Customer?
}
```

### 6.4 Swift 闭包捕获

**捕获列表**：

```swift
// weak 捕获
class ViewController {
    var name = "Test"

    func setup() {
        let closure = { [weak self] in
            print(self?.name ?? "nil") // self 可能为 nil
        }
    }
}

// unowned 捕获
class Person {
    var name = "Tom"

    func setup() {
        let closure = { [unowned self] in
            print(self.name) // self 一定存在
        }
    }
}

// 显式捕获变量
var count = 0
let closure = { [count] in
    count += 1 // 错误：count 是 let
}

// 正确写法
let closure = { [var count] in // Swift 5.3+
    count += 1
}
```

---


## 4. 高频面试题（Swift 内存）

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
