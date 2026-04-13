# Swift-内存管理与 ARC

> 一句话总结：**Swift ARC 管引用类型；配合 weak/unowned、闭包捕获列表与值类型 COW，避免循环引用与意外峰值。**

---

## 📚 学习地图

- **预计学习时间**：55 分钟
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

### 6.4 与 Objective-C 的统一运行时（Apple 平台）

Swift 的 `class` 与 ObjC 对象在 Apple 平台上共享同一套 **引用计数** 基础设施（`retain` / `release` / `autorelease` 的抽象）。混编时常见现象：

- **Swift 调用 OC API**：返回 `NSString` / `NSArray` 等时可能经历 **桥接**（Bridging）；是否拷贝取决于 API 标注与是否可变类型，性能敏感路径需关注「是否触发 Swift 侧值拷贝」。
- **`unowned` 与 OC 的 `assign` / `__unsafe_unretained`**：都不参与「置 nil」，悬空解引用同样崩溃；`weak` 与 `__weak` 同属「弱引用 + 运行时可置空」家族，Swift 侧可选类型是语法糖。
- **`deinit`**：纯 Swift `class` 也可有；与 OC `dealloc` 对应，均在引用计数归零时走释放路径（继承 `NSObject` 时注意 `deinit` 与 `dealloc` 调用顺序文档）。

---

### 6.5 weak 的底层直觉：Side Table

**强引用**计数通常内联在对象头部（与 `isa`、指针位域等共享存储的工业实现相关，细节随 ABI 演进）。**弱引用**为避免「对象已释放、弱引用表仍指向旧内存」，常引入 **Side Table**：弱引用登记在侧表，释放时遍历置 `nil`。因此 **`weak` 比 `unowned` 多一层间接与维护成本**，但更安全。

**与面试题的关系**：「`weak` 为什么是 Optional」——对象释放后运行时将弱引用位置更新为 `nil`，无对象则无值。

---

### 6.6 autoreleasepool 在 Swift

Swift 仍可使用 `autoreleasepool { }`（尤其在 **桥接**、大量临时 `NSString` / `NSData` 或 `for` 循环里触达 Cocoa API）以降低峰值 **autorelease** 延迟释放带来的内存尖峰。ARC **不会**消灭 autorelease 语义，只是多数 Swift 原生 API 更少暴露它。

---

### 6.7 循环引用：对照 OC Block

| 场景 | OC | Swift |
|------|-----|--------|
| 闭包持 `self` | `self` 强引用 Block，Block 强引用 `self` | 同类；用 `__weak typeof(self) wself` 或 `[weak self]` |
| Timer / KVO | `target-action` 对 `self` 强引用常见 | `Timer` / `Task` 同样要注意捕获列表 |
| 代理 | `weak id<Delegate>` 惯例 | `weak var delegate` 一致 |

更底层 Block 布局见 `OC-Block底层实现.md`。

---

### 6.8 Swift 闭包捕获

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

// 显式捕获：快照为不可变的「当时值」
var count = 0
let printer = { [count] in
    print(count) // 打印捕获时刻的 count
}
count = 10
printer() // 仍打印 0

// 若闭包内需累加同一计数，优先用引用类型盒子或明确所有权，而非依赖捕获列表可变语法
final class Counter {
    var value = 0
}
let counter = Counter()
let incrementer = { [counter] in
    counter.value += 1
}
```

**与 OC 对照**：捕获列表类似 Block 对 `__block` / 非 `__block` 变量的捕获规则直觉：默认捕获的是「绑定」而非随意跨闭包同步外层 `var` 的全部语义；复杂场景用 `class` 或 `actor` 承载可变状态更清晰。

---

### 6.9 unsafe 与底层指针（与 OC 指针互操作）

- **`Unmanaged<T>`**：与 C / OC API 交互、暂时「不参与 ARC 自动平衡」时使用，用 `takeRetainedValue()` / `takeUnretainedValue()` / `passRetained` 等明确所有权转移。
- **`withExtendedLifetime`**：保证某实例在闭包执行期间不被提前释放，对应 OC 里常见「先 `strong` 局部再异步」习惯。

---

## 4. 高频面试题（Swift 内存）

### 8.6 Swift 内存管理

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **weak 和 unowned 的区别？** | weak 可选自动置 nil，unowned 不可选不置 nil | ⭐⭐⭐⭐ |
| **什么时候用 unowned？** | 对象生命周期一定比当前对象长 | ⭐⭐⭐ |
| **什么是 Copy-on-Write？** | 多个变量共享数据，修改时才拷贝 | ⭐⭐⭐ |
| **Struct 和 Class 如何选择？** | 默认 Struct；需身份、继承、`deinit`、与 OC 子类化时 Class | ⭐⭐⭐ |
| **Swift 与 OC ARC 是否同一套？** | Apple 平台 class 家族共享引用计数与弱引用机制；桥接类型注意临时对象与 autoreleasepool | ⭐⭐⭐⭐ |

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

**最后更新**：2026-04-13
**状态**：✅ 已扩充（OC 运行时对照 + weak / autoreleasepool）

**Sources:**
- [Mastering Swift's Memory Management: ARC, Weak, Unowned](https://medium.com/@commitstudiogs/mastering-swifts-memory-management-arc-weak-unowned-and-strong-references-74f40f069994)
- [深入探索iOS内存优化](https://juejin.cn/post/6864492188404088846)
- [YTMemoryLeakDetector iOS内存泄漏检测工具类](https://segmentfault.com/a/1190000012121342)
