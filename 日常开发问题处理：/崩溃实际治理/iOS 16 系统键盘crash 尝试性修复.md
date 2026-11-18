8.3 iOS 16 系统键盘crash 尝试性修复

### 背景
这个版本查看线上crash问题。最大头的是两个系统键盘的崩溃。每天加起来大概20多次crash，累积几百次

* [-[UIKeyboardTaskQueue promoteDeferredTaskIfIdle]](https://console.firebase.google.com/project/gravity-7d703/crashlytics/app/ios:com.hiclub.gravity/issues/a97a28689627b3112be2684d6d7b8307?time=last-seven-days&types=crash&versions=8.2.1%20(11857);8.2.1%20(11847);8.2.2%20(11856);8.2%20(11845);8.2%20(11837);8.2%20(10506)&sessionEventKey=f857cea0435144c8ac88bc2dbefa3d20_1855817028435214413)
* [-[UIKeyboardTaskQueue addDeferredTask:]](https://console.firebase.google.com/project/gravity-7d703/crashlytics/app/ios:com.hiclub.gravity/issues/779a58c1a2cd2df2dff5e10a24196d04?time=last-seven-days&types=crash&versions=8.2.1%20(11857);8.2.1%20(11847);8.2.2%20(11856);8.2%20(11845);8.2%20(11837);8.2%20(10506)&sessionEventKey=3f3d422e8a514a0792bedccb1c3a4a57_1855690359109017053)

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=b7b8b4f95b9c40b790deb28c064a983a&docGuid=_bsbWElmDEPmp9)
从Firebase堆栈信息来看，100% iOS 16系统的崩溃信息。

### 方案：
* 网上近期一篇蚂蚁大牛写的处理的iOS 16系统键盘崩溃治理的文章：[我给 iOS 系统打了个补丁——修复 iOS 16 系统键盘重大 Crash（附补丁源码）](https://juejin.cn/post/7276260308515045416#heading-9)堆栈信息与我们Firebase上的一模一样。
* 苹果网站也有很多人反馈类似的崩溃信息：[iOS 16 crash on [UIKeyboardTaskQueue promoteDeferredTaskIfIdle]](https://developer.apple.com/forums/thread/722734)。但是没有人回复解决方案。

于是选择尝试使用蚂蚁那个方案试试。

#### 方案简单介绍
* **原因**：

iOS 16 键盘 Crash 根因已查明，即`-[UIKeyboardTaskQueue continueExecutionOnMainThread]`方法内执行`-[UIKeyboardTaskQueue tryLockWhenReadyForMainThread]`尝试加锁失败后，不`return`继续向下执行读写不安全内存以及解锁，导致存在锁失效的情况，使得`UIKeyboardTaskQueue`成员变量`_deferredTasks`数组在多线程下出现并发添加`UIKeyboardTaskEntry`实例而引起野指针，导致最终 Crash。



* **修复手段**：

        App 内置补丁代码使得`-[UIKeyboardTaskQueue continueExecutionOnMainThread]`方法内执行`-[UIKeyboardTaskQueue tryLockWhenReadyForMainThread]`尝试加锁失败后，正常`return`。

### 注意事项
* 加弹窗控制

因为这个解决方案不确定是否100%有效。所以加了一个弹窗控制。

* 做代码混淆

因为修改的是系统内私有方法，所以加代码混淆，避免审核问题

* OC代码的宏与Swift内的区别
    * OC：#ifdef __arm64__
    * swift：#if arch(arm64)






