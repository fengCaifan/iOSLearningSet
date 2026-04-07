# Mach-O 与链接器

> 一句话总结：**Mach-O 描述段、节与加载命令；静态链接合并目标文件，动态链接在启动时由 dyld 完成重定位与 bind。**

---

## 2. Mach-O 文件结构

### 2.1 Mach-O 组成

**Header + Load Commands + Data**：

```
┌─────────────────────────────────┐
│  Header（头部）                   │
│  - CPU 类型                      │
│  - 文件类型                       │
│  - 加载命令数量                   │
├─────────────────────────────────┤
│  Load Commands（加载命令）        │
│  - SEGMENT command（段命令）      │
│  - DYLIB command（动态库命令）    │
│  - SYMTAB command（符号表命令）   │
├─────────────────────────────────┤
│  Data（数据）                     │
│  - __TEXT（代码段）               │
│  - __DATA（数据段）               │
│  - __LINKEDIT（链接信息）         │
└─────────────────────────────────┘
```

### 2.2 Header（头部）

**结构**：

```c
struct mach_header_64 {
    uint32_t    magic;      // 魔数：0xFEEDFACE + 0x01000000 (64-bit)
    uint32_t    cputype;    // CPU 类型：0x01000007 (ARM64)
    uint32_t    cpusubtype; // CPU 子类型
    uint32_t    filetype;   // 文件类型：0x2 (EXECUTE)
    uint32_t    ncmds;      // 加载命令数量
    uint32_t    sizeofcmds;  // 加载命令大小
    uint32_t    flags;      // 标志位
    uint32_t    reserved;   // 保留字段
};
```

### 2.3 Load Commands（加载命令）

**常用加载命令**：

| 命令 | 说明 | 示例 |
|------|------|------|
| `LC_SEGMENT` | 定义段（__TEXT/__DATA） | 代码段、数据段 |
| `LC_SYMTAB` | 符号表 | 存储函数、类名等符号 |
| `LC_DYSYMTAB` | 动态符号表 | 动态库的符号 |
| `LC_LOAD_DYLIB` | 加载动态库 | `@rpath/System/Library/Frameworks/...` |
| `LC_UUID` | UUID | 唯一标识符 |

**Load Command 示例**：

```bash
# 使用 otool 查看加载命令
otool -l MyApp

# 输出：
Load command 1
  cmd LC_SEGMENT
  segname __TEXT
Load command 2
  cmd LC_SYMTAB
  symtab
Load command 3
  cmd LC_LOAD_DYLIB
    dylib /usr/lib/libobjc.A.dylib
```

### 2.4 Segment（段）和 Section（节）

**段与节的层次**：

```
Segment（段）
  └── Section（节）
      └── Raw Data（原始数据）
```

**常见 Segment**：

```bash
# 使用 size 命令查看段和节
size -x -m MyApp

# 输出：
Segment __TEXT: 0x1000
  Section __text: 0x31 (addr 0x100000f50 offset 3920)
  Section __stubs: 0x6 (addr 0x100000f82 offset 3970)

Segment __DATA: 0x1000
  Section __nl_symbol_ptr: 0x8 (addr 0x100001000 offset 4096)
```

**__TEXT 段**：

```
- 只读代码段
- 包含机器码
- 存储位置：从 0x100000000 开始（ASLR 后会随机偏移）
```

**__DATA 段**：

```
- 可读写数据段
- 包含：
  - 已初始化数据（__data）
  - 未初始化数据（__bss）
- 存储位置：紧跟在 __TEXT 后
```

### 2.5 符号表（Symbol Table）

**符号表结构**：

```
<起始地址> <结束地址> <函数> [<文件名：行号>]
```

**示例**：

```bash
# 使用 nm 查看符号表
nm -nm MyApp

# 输出：
                     (undefined) external _printf (from System)
0000000100000f50 (__TEXT,__text) external _main
0000000100001128 (__TEXT,__text) non-external _Person.description
```

**符号类型**：

| 符号 | 说明 |
|------|------|
| `external` | 外部符号（可被其他模块链接） |
| `non-external` | 内部符号（仅当前模块使用） |
| `undefined` | 未定义（需要在其他库中查找） |

---

## 3. dyld 动态链接

### 3.1 dyld 简介

**dyld（Dynamic Linker）**：

```
作用：动态链接器，在程序启动时加载所有依赖的动态库

位置：/usr/lib/dyld
```

**启动流程**：

```
1. Kernel 加载 dyld
2. dyld 加载 Mach-O 主程序
3. dyld 加载共享缓存（系统动态库）
4. dyld 递归加载所有依赖的动态库
5. Rebase & Bind（符号重定位）
6. ObjC Runtime Setup
7. 初始化（+load、constructor）
8. 跳转到 main()
```

### 3.2 Rebase & Bind（符号重定位）

**Rebase（重定位）**：

```
作用：修正内部指针地址

原因：ASLR（地址空间布局随机化）导致加载地址不确定

过程：
1. 读取所有 Rebase 指针
2. 加上 ASLR 偏移值
3. 写回指针位置
```

**Bind（绑定）**：

```
作用：绑定外部符号（动态库中的函数）

过程：
1. 读取所有 Bind 指针
2. 通过符号名查找动态库中的符号地址
3. 将地址写入指针位置
```

**优化**：

```
1. Rebase 使用并发处理（多线程同时处理）
2. Bind 使用递归查找
3. 共享缓存：系统动态库预绑定，减少 Bind 时间
```

### 3.3 ObjC Runtime Setup

**setup 过程**：

```
1. 读取所有 ObjC 类、Category、Protocol
2. 注册所有类（objc_readClassPair）
3. 插入 Category 方法到类的方法列表
4. 调用所有 +load 方法
```

**优化**：

```
1. 缓存类信息
2. 延迟 +load 调用（按需加载）
3. 移除无用类（Dead Code Stripping）
```

---


---

## 7. 高频面试题

### 7.1 编译流程

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **iOS 应用的编译流程？** | 预处理 → 编译 → 汇编 → 链接 → 签名 | ⭐⭐⭐ |
| **预处理的作用？** | 处理 # 指令，展开宏、包含头文件 | ⭐⭐⭐ |
| **AST 是什么？** | 抽象语法树，表示代码结构 | ⭐⭐⭐⭐ |

### 7.2 Mach-O 文件

| 问题 | 答案要点 | 难度 |
|------|----------|------|
| **Mach-O 的组成？** | Header + Load Commands + Data | ⭐⭐⭐⭐ |
| **__TEXT 和 __DATA 的区别？** | __TEXT：只读代码；__DATA：可读写数据 | ⭐⭐⭐ |
| **符号表的作用？** | 存储函数、类名等符号，用于调试和符号化 | ⭐⭐⭐⭐ |

---

## 8. 参考资料

### 优质文章
- [iOS App启动优化](https://juejin.cn/post/6844904165773328392)
- [美团App冷启动治理](https://www.jianshu.com/p/8e0b38719278)
- [Understanding iOS App Startup Time](https://medium.com/@sarunw/understanding-ios-app-startup-time-178ad9a3986b)
- [Mach-O 文件结构详解](https://www.jianshu.com/p/d1d89de0de7)

### Apple 文档
- [Mach-O File Format](https://developer.apple.com/library/archive/documentation/mac/Conceptual/MachO/index.html)
- [dyld: Dynamic Linking On OS X](https://developer.apple.com/library/archive/documentation/Darwin/Reference/ManPages/man5/dyld.1.html)

### 开源工具
- [apple-llvm/llvm](https://github.com/apple/llvm) - LLVM 编译器
- [apple/swift](https://github.com/apple/swift) - Swift 编译器

---

**最后更新**：2026-04-07
**状态**：✅ 已完成
