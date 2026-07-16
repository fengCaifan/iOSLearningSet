# 网络基础 - TCP/IP与数据传输

> 一句话总结：**网络通信建立在TCP/IP协议栈之上，理解网络分层、TCP/UDP机制、数据传输过程是iOS网络编程和优化排查的基础。**

---

## 📚 学习地图

- **预计学习时间**：50 分钟
- **前置知识**：计算机网络基础
- **学习目标**：网络分层模型 → TCP/UDP机制 → 数据传输过程 → iOS网络编程应用

---

## 1. 计算机网络基础

### 1.1 网络连接的基本概念

#### 网络设备与连接方式

```
网络连接发展历程：
├── 网线直连（需要交叉线）
├── 同轴电缆（半双工，易冲突）
├── 集线器（半双工，易冲突）
├── 网桥（能学习MAC地址，隔绝冲突域）
├── 交换机（多接口网桥，全双工通信）
└── 路由器（连接不同网段，隔绝广播域）
```

#### 重要概念：

**MAC地址（物理地址）：**
- 由网卡制造商设置
- 全局唯一，48位二进制
- 全F的MAC地址表示广播地址

**IP地址（逻辑地址）：**
- 由网络管理员分配
- 格式：网络ID + 主机ID
- 通过子网掩码计算网络ID
- `网络ID = IP地址 AND 子网掩码`

**ARP协议（地址解析协议）：**
```
作用：将IP地址解析为MAC地址

工作过程：
1. 主机A想发送数据给主机B
2. 主机A广播ARP请求："谁是192.168.1.5？"
3. 主机B收到后回复："我是192.168.1.5，MAC地址是xx:xx:xx:xx:xx:xx"
4. 主机A缓存这个映射关系，直接通信
```

**交换机与路由器对比：**
```
交换机：
- 连接同一网段设备
- 工作在数据链路层（Layer 2）
- 根据MAC地址转发数据
- 构成局域网（LAN）

路由器：
- 连接不同网段
- 工作在网络层（Layer 3）
- 根据IP地址转发数据
- 构成广域网（WAN）
```

### 1.2 网络分层模型

#### OSI七层模型 vs TCP/IP五层模型

```
OSI七层参考模型：                            数据单位
┌─────────────────┐
│ 应用层           │ HTTP, FTP, SMTP, DNS
├─────────────────┤
│ 表示层           │ 数据加密、压缩
├─────────────────┤
│ 会话层           │ 会话管理
├─────────────────┤
│ 传输层           │ TCP, UDP        段
├─────────────────┤
│ 网络层           │ IP, ICMP, ARP    包
├─────────────────┤
│ 数据链路层       │ 以太网, PPP      帧
├─────────────────┤
│ 物理层           │ 网线, 信号        比特流
└─────────────────┘

TCP/IP五层模型（实际使用）：
┌─────────────────┐
│ 应用层           │ HTTP, FTP, DNS, DHCP
├─────────────────┤
│ 传输层           │ TCP, UDP
├─────────────────┤
│ 网络层           │ IP, ARP, ICMP
├─────────────────┤
│ 数据链路层       │ CSMA/CD, PPP
├─────────────────┤
│ 物理层           │ 网线, 信号
└─────────────────┘
```

#### 各层功能详解

**应用层：**
- 处理数据：报文、用户数据
- 常用协议：
  - HTTP/HTTPS（网页浏览）
  - FTP（文件传输）
  - SMTP（邮件发送）
  - DNS（域名解析）
  - DHCP（动态IP分配）

**传输层：**
- 处理数据：段
- 常用协议：TCP、UDP
- 主要功能：端到端通信、流量控制、拥塞控制

**网络层：**
- 处理数据：包
- 常用协议：IP、ARP、ICMP
- 主要功能：路由选择、分组转发

**数据链路层：**
- 处理数据：帧
- 常用协议：CSMA/CD、PPP
- 主要功能：帧同步、差错控制

**物理层：**
- 处理数据：比特流
- 主要功能：比特传输、物理接口

---

## 2. 传输层协议详解

### 2.1 TCP vs UDP

| 特性 | TCP | UDP |
|------|-----|-----|
| **连接性** | 面向连接 | 无连接 |
| **可靠性** | 可靠传输，不丢包 | 尽最大努力交付，可能丢包 |
| **首部开销** | 20-60字节 | 8字节 |
| **传输速率** | 较慢 | 快 |
| **资源消耗** | 大 | 小 |
| **应用场景** | 文件传输、邮件、网页 | 直播、游戏、语音通话 |

### 2.2 UDP详解

**特点：**
```
1. 无连接：不需要建立连接
2. 不可靠：不保证数据送达
3. 简单高效：头部仅8字节
4. 支持一对一、一对多、多对多通信
```

**UDP头部结构：**
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          Source Port          |       Destination Port        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|            Length             |           Checksum            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

- Source Port：源端口号（16位）
- Destination Port：目标端口号（16位）
- Length：UDP数据包长度（16位）
- Checksum：校验和（16位）
```

**应用场景：**
```
适用场景：
1. 实时性要求高：直播、视频会议
2. 数据量小但频繁：DNS查询
3. 广播/多播：网络广播
4. 游戏数据：对实时性要求高，容忍丢包
```

### 2.3 TCP详解

**特点：**
```
1. 面向连接：三次握手建立连接
2. 可靠传输：确认机制、重传机制
3. 流量控制：滑动窗口协议
4. 拥塞控制：慢启动、拥塞避免
5. 全双工通信：双方可以同时发送数据
```

**TCP头部结构（20字节固定）：**
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          Source Port          |       Destination Port        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Sequence Number                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Acknowledgment Number                      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Data |           |U|A|P|R|S|F|                               |
| Offset| Reserved  |R|C|S|S|Y|I            Window             |
|       |           |G|K|H|T|N|N|                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           Checksum            |         Urgent Pointer          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Options                    |    Padding    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

重要字段：
- Source Port：源端口号（16位）
- Destination Port：目标端口号（16位）
- Sequence Number：序号（32位）
- Acknowledgment Number：确认号（32位）
- Data Offset：数据偏移（4位，首部长度）
- Flags：标志位（URG, ACK, PSH, RST, SYN, FIN）
- Window：窗口大小（16位）
- Checksum：校验和（16位）
```

**TCP三次握手：**
```
客户端                                  服务端
   │                                       │
   │          SYN=1, seq=x                │
   │─────────────────────────────────────>│
   │                                       │
   │    SYN=1, ACK=1, seq=y, ack=x+1      │
   │<─────────────────────────────────────│
   │                                       │
   │    ACK=1, seq=x+1, ack=y+1           │
   │─────────────────────────────────────>│
   │                                       │
   │           连接建立完成                  │

解释：
1. 客户端发送SYN包，请求建立连接
2. 服务端回复SYN+ACK包，同意建立连接
3. 客户端发送ACK包，确认连接建立

为什么需要三次握手：
- 防止失效的连接请求突然传到服务端
- 确认双方的发送和接收能力都正常
- 同步双方的序列号
```

**TCP四次挥手：**
```
客户端                                  服务端
   │                                       │
   │          FIN=1, seq=u                 │
   │─────────────────────────────────────>│
   │                                       │
   │    ACK=1, seq=v, ack=u+1             │
   │<─────────────────────────────────────│
   │                                       │
   │  （等待服务端数据发送完毕）             │
   │                                       │
   │    FIN=1, ACK=1, seq=w, ack=u+1       │
   │<─────────────────────────────────────│
   │                                       │
   │    ACK=1, seq=u+1, ack=w+1            │
   │─────────────────────────────────────>│
   │                                       │
   │           连接关闭完成                  │

解释：
1. 客户端发送FIN包，请求关闭连接
2. 服务端回复ACK包，确认收到关闭请求
3. 服务端发送FIN包，请求关闭连接（此时可能还有数据要发送）
4. 客户端回复ACK包，确认关闭连接

为什么需要四次挥手：
- TCP是全双工协议，双方都可以主动关闭连接
- 需要双方都确认关闭才能完全断开连接
```

**TCP可靠传输机制：**

1. **序列号与确认号：**
```
- 序列号：数据字节的编号
- 确认号：期望收到的下一个字节编号
- 确认机制：发送方收到ACK后才发送下一个数据包
```

2. **超时重传：**
```
- 发送方启动定时器，等待ACK
- 超时未收到ACK，重传数据包
- 采用指数退避算法计算超时时间
```

3. **快速重传：**
```
- 收到3个重复的ACK，立即重传丢失的数据包
- 不需要等待超时
```

4. **流量控制（滑动窗口）：**
```
- 接收方通过窗口大小告诉发送方自己的接收能力
- 发送方根据窗口大小调整发送速率
- 防止接收方缓冲区溢出
```

5. **拥塞控制：**
```
- 慢启动：从较小窗口开始，指数增长
- 拥塞避免：达到阈值后，线性增长
- 拥塞发生：降低发送速率，避免网络崩溃
- 快速恢复：检测到丢包后，适当降低窗口
```

---

## 3. 网络层协议详解

### 3.1 IP协议

**IP头部结构：**
```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|Version|  IHL  |    DSCP   |ECN|          Total Length         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|         Identification        |Flags|      Fragment Offset    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  TTL  |  Protocol  |           Header Checksum               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Source Address                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Destination Address                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

重要字段：
- Version：版本号（IPv4或IPv6）
- IHL：首部长度（最小20字节）
- Total Length：总长度（最大65535字节）
- Identification：标识（分片重组用）
- Flags：标志（DF、MF）
- Fragment Offset：片偏移
- TTL：生存时间（防止数据包无限循环）
- Protocol：协议号（TCP=6，UDP=17，ICMP=1）
- Source Address：源IP地址
- Destination Address：目的IP地址
```

### 3.2 ICMP协议

**作用：**
```
- 网络诊断工具：ping、traceroute
- 错误报告：目标不可达、超时等
- 网络拥塞控制：源抑制
```

**ICMP报文类型：**
```
常见类型：
- Type 0：Echo Reply（ping回复）
- Type 3：Destination Unreachable（目标不可达）
- Type 4：Source Quench（源抑制）
- Type 5：Redirect（重定向）
- Type 8：Echo Request（ping请求）
- Type 11：Time Exceeded（超时）
```

**Ping工作原理：**
```
1. 发送Echo Request（Type 8）
2. 接收Echo Reply（Type 0）
3. 计算往返时间（RTT）
4. 统计丢包率
```

### 3.3 ARP协议

**ARP工作流程：**
```
1. 主机A要发送数据给主机B（已知B的IP地址）
2. 主机A查询ARP缓存表中是否有B的MAC地址
3. 如果没有，主机A广播ARP请求："谁是192.168.1.5？"
4. 主机B回复ARP响应："我是192.168.1.5，MAC地址是xx:xx:xx:xx:xx:xx"
5. 主机A将映射关系缓存到ARP表
6. 主机A可以直接发送数据给主机B
```

**ARP缓存：**
```
- 缓存IP地址到MAC地址的映射
- 有生存时间（TTL），通常几分钟
- 可以手动添加静态ARP条目
- 可以使用arp命令查看和修改ARP缓存
```

---

## 4. 数据传输过程

### 4.1 数据封装过程

```
应用层数据                            HTTP请求
    ↓ 添加TCP头部
传输层数据              TCP头部 + HTTP请求
    ↓ 添加IP头部
网络层数据      IP头部 + TCP头部 + HTTP请求
    ↓ 添加以太网头部
数据链路层数据 以太网头部 + IP头部 + TCP头部 + HTTP请求 + 以太网尾部
    ↓ 转换为比特流
物理层比特流   01010101010101010101010101010101
```

### 4.2 数据分片与重组

**为什么需要分片：**
```
- 数据链路层有最大传输单元（MTU）限制
- 以太网MTU通常为1500字节
- IP数据包超过MTU需要分片传输
```

**分片过程：**
```
1. IP层检测到数据包超过MTU
2. 将数据包分片，每片不超过MTU
3. 每片都有独立的IP头部
4. 使用Identification字段标识分片关系
5. 使用Fragment Offset表示分片位置
6. 最后一个分片的MF标志位为0
```

**重组过程：**
```
1. 接收方根据Identification字段识别分片
2. 根据Fragment Offset重组分片
3. 收到最后一个分片（MF=0）后完成重组
4. 重组后的数据包交给传输层处理
```

---

## 5. 网络编程应用

### 5.1 Socket编程基础

**Socket概念：**
```
- Socket是网络编程的API接口
- 实现了不同主机间进程的通信
- 支持TCP、UDP等多种协议
- 提供了统一的编程接口
```

**TCP Socket编程流程：**
```objective-c
// 服务端
// 1. 创建Socket
int serverSocket = socket(AF_INET, SOCK_STREAM, 0);

// 2. 绑定地址和端口
struct sockaddr_in serverAddr;
serverAddr.sin_family = AF_INET;
serverAddr.sin_port = htons(8080);
serverAddr.sin_addr.s_addr = INADDR_ANY;
bind(serverSocket, (struct sockaddr*)&serverAddr, sizeof(serverAddr));

// 3. 监听连接
listen(serverSocket, 10);

// 4. 接受连接
struct sockaddr_in clientAddr;
socklen_t clientAddrLen = sizeof(clientAddr);
int clientSocket = accept(serverSocket, (struct sockaddr*)&clientAddr, &clientAddrLen);

// 5. 接收数据
char buffer[1024];
ssize_t bytesRead = recv(clientSocket, buffer, sizeof(buffer), 0);

// 6. 发送数据
send(clientSocket, "Hello, Client!", 14, 0);

// 7. 关闭连接
close(clientSocket);
close(serverSocket);
```

```objective-c
// 客户端
// 1. 创建Socket
int clientSocket = socket(AF_INET, SOCK_STREAM, 0);

// 2. 连接服务端
struct sockaddr_in serverAddr;
serverAddr.sin_family = AF_INET;
serverAddr.sin_port = htons(8080);
serverAddr.sin_addr.s_addr = inet_addr("192.168.1.100");
connect(clientSocket, (struct sockaddr*)&serverAddr, sizeof(serverAddr));

// 3. 发送数据
send(clientSocket, "Hello, Server!", 14, 0);

// 4. 接收数据
char buffer[1024];
ssize_t bytesRead = recv(clientSocket, buffer, sizeof(buffer), 0);

// 5. 关闭连接
close(clientSocket);
```

### 5.2 iOS网络编程

**NSURLSession使用：**
```objective-c
// GET请求
- (void)sendGETRequest {
    NSURL *url = [NSURL URLWithString:@"https://api.example.com/users"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSLog(@"Status Code: %ld", (long)httpResponse.statusCode);

        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSLog(@"Response: %@", jsonData);
    }];

    [task resume];
}

// POST请求
- (void)sendPOSTRequest {
    NSURL *url = [NSURL URLWithString:@"https://api.example.com/users"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";

    // 设置请求头
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    // 设置请求体
    NSDictionary *params = @{@"name": @"John", @"age": @30};
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params options:0 error:nil];
    request.HTTPBody = jsonData;

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
            return;
        }

        id responseData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSLog(@"Response: %@", responseData);
    }];

    [task resume];
}
```

**网络优化建议：**
```objective-c
// 1. 使用缓存策略
- (void)setupURLCache {
    int cacheSizeMemory = 50 * 1024 * 1024;  // 50MB
    int cacheSizeDisk = 100 * 1024 * 1024;   // 100MB

    NSURLCache *urlCache = [[NSURLCache alloc] initWithMemoryCapacity:cacheSizeMemory
                                                          diskCapacity:cacheSizeDisk
                                                              diskPath:@"nsurlcache"];
    [NSURLCache setSharedURLCache:urlCache];
}

// 2. 配置请求超时
- (NSMutableURLRequest *)createRequestWithURL:(NSURL *)url {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:30.0];
    return request;
}

// 3. 使用后台下载
- (void)setupBackgroundSession {
    NSString *identifier = @"com.example.backgroundSession";
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration
                                       backgroundSessionConfigurationWithIdentifier:identifier];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    // 使用session进行网络请求
}

// 4. 监控网络状态
- (void)setupNetworkMonitoring {
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];

    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        switch (status) {
            case AFNetworkReachabilityStatusNotReachable:
                NSLog(@"Network Not Reachable");
                break;
            case AFNetworkReachabilityStatusReachableViaWiFi:
                NSLog(@"Network Reachable via WiFi");
                break;
            case AFNetworkReachabilityStatusReachableViaWWAN:
                NSLog(@"Network Reachable via WWAN");
                break;
            default:
                break;
        }
    }];
}
```

---

## 6. 网络调试工具

### 6.1 常用命令行工具

```bash
# ping：测试网络连通性
ping www.google.com

# traceroute：追踪网络路径
traceroute www.google.com

# netstat：查看网络连接状态
netstat -an

# ifconfig：查看网络接口配置
ifconfig

# arp：查看和修改ARP缓存
arp -a

# nslookup：DNS查询
nslookup www.google.com

# curl：测试HTTP请求
curl -I https://www.google.com

# tcpdump：抓包工具
tcpdump -i en0 -n host 192.168.1.1
```

### 6.2 iOS网络调试

**Charles抓包配置：**
```
1. iOS设备设置HTTP代理
2. 安装Charles证书
3. 信任证书（设置 -> 通用 -> 关于本机 -> 证书信任设置）
4. 配置SSL Proxying
```

**常见问题解决：**
```
1. 无法抓包HTTPS
   - 检查证书是否安装
   - 检查SSL Proxying是否启用
   - 检查设备是否信任证书

2. 代理配置后网络不通
   - 检查代理服务器地址和端口
   - 检查防火墙设置
   - 检查Charles是否正常运行
```

---

## 7. 总结

### 7.1 知识体系梳理

```
网络基础
├── 网络分层
│   ├── 应用层：HTTP, DNS, DHCP
│   ├── 传输层：TCP, UDP
│   ├── 网络层：IP, ICMP, ARP
│   ├── 数据链路层：以太网, PPP
│   └── 物理层：网线, 信号
├── 协议详解
│   ├── TCP：可靠传输、流量控制、拥塞控制
│   ├── UDP：快速传输、不可靠
│   ├── IP：路由选择、分片传输
│   └── ARP：地址解析、缓存机制
└── 实际应用
    ├── Socket编程
    ├── iOS网络开发
    ├── 网络调试
    └── 性能优化
```

### 7.2 面试高频问题

1. **TCP三次握手为什么需要三次？**
   - 防止失效的连接请求
   - 确认双方收发能力
   - 同步序列号

2. **TCP四次挥手为什么需要四次？**
   - TCP全双工，双方都可以主动关闭
   - 需要双方都确认关闭

3. **TCP如何保证可靠传输？**
   - 序列号和确认号
   - 超时重传
   - 快速重传
   - 流量控制
   - 拥塞控制

4. **HTTP和TCP的关系？**
   - HTTP是应用层协议
   - TCP是传输层协议
   - HTTP基于TCP实现可靠传输

5. **为什么有了IP还要MAC地址？**
   - IP地址用于网络层路由
   - MAC地址用于数据链路层传输
   - 二者解决不同层次的通信问题

---

## 8. 参考资料

### 优质文章
- [TCP/IP详解](https://www.amazon.com/TCP-Illustrated-Vol-Addison-Wesley/dp/0201633469)
- [图解TCP/IP](https://www.jianshu.com/p/9a6c3d2f2c3d)
- [iOS网络编程](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/NetworkingOverview/)

### 开源项目
- [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket) - 异步Socket库
- [AFNetworking](https://github.com/AFNetworking/AFNetworking) - HTTP网络库
- [Alamofire](https://github.com/Alamofire/Alamofire) - Swift网络库

### 标准协议
- [RFC 791 - Internet Protocol (IP)](https://tools.ietf.org/html/rfc791)
- [RFC 793 - Transmission Control Protocol (TCP)](https://tools.ietf.org/html/rfc793)
- [RFC 768 - User Datagram Protocol (UDP)](https://tools.ietf.org/html/rfc768)