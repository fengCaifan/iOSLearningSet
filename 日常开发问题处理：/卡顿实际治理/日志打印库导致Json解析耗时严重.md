TPHashTagVoiceListController页面卡顿排查

### 一、 整体卡顿数据
FirebasePerformance控制台显示卡顿数据如下：

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=a66e86a62e7e49cf9c02b97316fd18fb&docGuid=Z5n4rIrMQsGl6n)
PS：『冻结的帧』定义：

[冻结的帧](https://firebase.google.com/docs/perf-mon/screen-traces?hl=zh-cn#frozen-frames) - 衡量呈现时间超过 700 毫秒的屏幕实例所占的百分比。

应用中的缓慢或冻结的帧可能会导致设备性能不佳，也称为卡顿或延迟。

出现冻结的帧，也就意味着出现了卡顿。



### 二、选取TPHashTagVoiceListController，排查其卡顿原因
TPHashTagVoiceListController的卡顿率为20%，表明该页面的20％的帧**要加载700毫秒以上的时间。**

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=b70097e74eea4e2e92a7a15cbc83ca36&docGuid=Z5n4rIrMQsGl6n)


#### 1.直接体验
将Gravity切到线上环境，搜索hashtag--『#20代』进入hashtag详情页，点击语音房列表tab

尝试进入该页面、上下滑动列表，并没有感知到明显的卡顿

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=b53889ed46994e549298a281805e1c23&docGuid=Z5n4rIrMQsGl6n)


#### 2.Instrument分析
可见在进入语音房列表页时，有大量耗时操作，查看堆栈发现很大一部分耗时操作在GBDJson内，即字典转model。

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=040f847189c34b3e84a33be6128af4ab&docGuid=Z5n4rIrMQsGl6n)
此时Xcode控台台大量打印TPJson转换失败的日志

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=fab7ca3a7ba946c5932b75e21d445d92&docGuid=Z5n4rIrMQsGl6n)


**搜索源码发现GBDJson中有以下日志输出，结合已知NSLog是耗时操作，尤其是在字典转json中进行大量打印，并且线上数据返回很多，会导致更加耗时。**

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=2d76f6f4d12a41bb9cc8cd15e4350531&docGuid=Z5n4rIrMQsGl6n)


### 三、验证
如下验证代码，在线上测试发现该model转换耗时约86ms，已经远远超过16ms的一帧时长。

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=8e60308b9a734c6eb1be66dd5001f697&docGuid=Z5n4rIrMQsGl6n)


注释掉GBDJson库的NSLog输出后，字典转model时长为49ms，耗时减小50%。

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=bd80c45b05474582bb189fbbe77cacfd&docGuid=Z5n4rIrMQsGl6n)


### 排期优化
[[soulmate-11918] 【技术需求】卡顿优化--GBDJson](https://console.cloud.baidu-int.com/devops/icafe/issue/soulmate-11918/show?source=drawer-header?t=mention&mt=doc&dt=sdk)

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=ad2cd363e7cc4f4e92bca4f06b1c57fd&docGuid=Z5n4rIrMQsGl6n)


### 参考文档：
[https://firebase.google.com/docs/perf-mon/screen-traces?hl=zh-cn&platform=ios](https://firebase.google.com/docs/perf-mon/screen-traces?hl=zh-cn&platform=ios)



