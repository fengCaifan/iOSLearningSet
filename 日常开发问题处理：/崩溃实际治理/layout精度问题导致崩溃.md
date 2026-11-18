语音房消息cell偶现crash问题处理

## 背景：
8.0版本Firebase上出现了一个新的崩溃信息：

* [-[NSMutableDictionary(NSMutableDictionary) initWithContentsOfFile:] “Not possible to remove variable”](https://console.firebase.google.com/project/gravity-7d703/crashlytics/app/ios:com.hiclub.gravity/issues/f71b8fcf81cc23e58469fcd1adbbbe2c?time=last-twenty-four-hours&types=crash&versions=8.2%20(11845);8.2%20(11837);8.2%20(10506);8.1.1%20(11836);8.1.1%20(10506)&sessionEventKey=be8e23764a84492e922c29d30a5a594c_1853418622391225778)。

而且，之前处理完的语音房未读消息点击滚动到底部的崩溃又在8.0版本重新出现。而且裂变成了两个新的分支：

* [TPAudioLiveMessagePanelView.scrollToBottom](https://console.firebase.google.com/project/gravity-7d703/crashlytics/app/ios:com.hiclub.gravity/issues/e6f7d76175f31cfbaf5db5697cb2a5b1?time=last-twenty-four-hours&types=crash&sessionEventKey=b26ed1025706467cb60ce9145b90c464_1853447167436967155&versions=8.2%20(11845);8.2%20(11837);8.2%20(10506);8.1.1%20(11836);8.1.1%20(10506))
* [TPAudioLiveMessagePanelView.appendMessages](https://console.firebase.google.com/project/gravity-7d703/crashlytics/app/ios:com.hiclub.gravity/issues/ca2d57128386dd05afdb43bcbf41c706?time=last-twenty-four-hours&types=crash&subIssues=c2f0fc22c9e5c27ffb4dff115cb8bb21&versions=8.1.1%20(11836);8.1.1%20(10506);8.2%20(11845);8.2%20(11837);8.2%20(10506))

## 分析与查找
##### 分析：
经过对Firebase上堆栈信息的对比，发现重新出现的语音房未读消息点击滚动到底部的崩溃堆栈与之前的numOfRows的不一样，而且崩溃数减少了。而且上面三个崩溃信息的堆栈除了触发的点不同，但是后续堆栈都一致：

* crash堆栈

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=a1bc06aa63544e259ba7acc46b4591f3&docGuid=_xde_FaAG_kTa1)
> [https://console.firebase.google.com/project/gravity-7d703/crashlytics/app/ios:com.hiclub.gravity/iss](https://console.firebase.google.com/project/gravity-7d703/crashlytics/app/ios:com.hiclub.gravity/iss)
> Fatal Exception: NSInternalInconsistencyException
> Not possible to remove variable: 225: <unknown var (bug!) with engine as delegate:0x282e00080>{id: 583905} colIndex:54 from engine <NSISEngine: 0x1447de1d0>{ delegate:0x148e949a0 EngineVars: 0: objective{id: 577085} rowIndex:0 1: UIImageView:0x1447ddcf0.minX{id: 577088} rowIndex:1 2: Chat.TPALPortraitFrameView:0x13f5544e0.minX{id: 577089} rowIndex:3 3: 0x281fce700.marker{id: 577087} colIndex:2 4: UIImageView:0x1447ddcf0.minY{id: 577091} rowIndex:1073741824 5: Chat.TPALPortraitFrameView:0x13f5544e0.minY{id: 577092} rowIndex:1073741826 6: 0x281fce400.marker{id: 577090} colIndex:1073741826 7: UIImageView:0x1447ddcf0.Width{id: 577094} rowIndex:4 8: Chat.TPALPortraitFrameView:0x13f5544e0.Width{id: 577095} rowIndex:2 9: 0x281fcc300.marker{id: 577093} colIndex:4 10: UIImageView:0x1447ddcf0.Height{id: 577097} rowIndex:1073741827 11: Chat.TPALPortraitFrameView:0x13f5544e0.Height{id: 577098} rowIndex:1073741825 12: 0x281fce340.marker{id: 577096} colIndex:1073741828 13: UITableViewCellContentView:0x148e949a0.minX{id: 577100} rowIndex:66 14: 0x281fcf120.marker{id: 577099} colIndex:5 15: UITableViewCellContentView:0x148e949a0.minY{id: 577102} rowIndex:1073741881 16: 0x281fcc120.marker{id: 577101} colIndex:1073741829 17: 0x281fce4c0.marker{id: 577103} colIndex:1 18: 0x281fcf7e0.marker{id: 577106} colIndex:1073741825 19: tempToBeOptimizedToZero{id: 577104} colIndex:18 20: tempToBeOptimizedToZeroObjective{id: 577105} colIndex:80 21: UIImageView:0x148e27540.Width{id: 577108} rowIndex:5 22: 0x281fcfde0.marker{id: 577107} colIndex:8 23: UIImageView:0x148e27540.Height{id: 577110} rowIndex:1073741828 24: 0x281fcff00.marker{id: 577109} colIndex:1073741830 25: UIImageView:0x148e27540.minX{id: 577112} rowIndex:6 26: UIImageView:0x13f51c030.minX{id: 577241} rowIndex:34 27: Chat.TPVipLevelBadgeView:0x13f5c18a0.Width{id: 577114} colIndex:10 28: 0x281fccb40.marker{id: 577111} colIndex:11 29: UIImageView:0x148e27540.minY{id: 577116} rowIndex:1073741829 30: Chat.TPVipLev
##### Google查找
* 1、搜索：crash NSMutableDictionary initWithContentOfFile after NSISEngine removeConstraintWithMarker

有用的一个链接：[https://developer.apple.com/forums/thread/693118](https://developer.apple.com/forums/thread/693118)

大概意思是：NSLayoutConstraint的乘数因子的精度会导致stackView的crash。

> 对于面临同样问题的任何人来说，问题在于NSLayoutConstraint的乘数因子。
> 对我来说，我是在运行时通过编程方式应用宽度锚点（对于父stackView），其乘数是在运行时根据某些逻辑计算出来的，为0.3333333333333333，这在使用单元格时扰乱了自动布局引擎的计算（我有一个collectionView，每个单元格都有一个stackView，就是我上面提到的父stackView）。因此，我使用这个逻辑将精度从0.3333333333333333降低到0.333984375，自动布局很满意，没有更多的崩溃
* 2、搜索崩溃信息：Fatal Exception: NSInternalInconsistencyException：Not possible to remove variable:

有一个有用的链接：[https://developer.apple.com/forums/thread/674689](https://developer.apple.com/forums/thread/674689)

大多数评论都是说在执行stackView的subview.removeFromSuperview时崩溃的。



## 处理与结果
##### 分析与猜想
根据对堆栈的分析（NSISEngine 约束引擎内的crash），与google查找到的结果。

初步判断大概率跟UIStackView在cell上使用，cell的高度由StackView子视图自动撑起有关。也就是上面说的space乘数因子的精度有关。

查看语音房的约束警告，发现语音房内消息cell的高度与系统判定的cell高度存在精度差问题，（这条记录也存在于 [约束警告修改记录](https://ku.baidu-int.com/knowledge/HFVrC7hq1Q/pKzJfZczuc/vk0R29m-Cm/845ex42IvoXx72?t=mention&mt=doc&dt=doc)中）

```
[LayoutConstraints] Unable to simultaneously satisfy constraints.
    Probably at least one of the constraints in the following list is one you don't want. 
    Try this: 
        (1) look at each constraint and try to figure out which you don't expect; 
        (2) find the code that added the unwanted constraint or constraints and fix it. 
(
    "<SnapKit.LayoutConstraint:0x2839c8fc0@TPAudioLiveAvatarSuperCell.swift#244 UIStackView:0x118689ab0.top == UITableViewCellContentView:0x1186887b0.top + 5.6521739130434785>",
    "<SnapKit.LayoutConstraint:0x2839c83c0@TPAudioLiveAvatarSuperCell.swift#246 UIStackView:0x118689ab0.bottom == UITableViewCellContentView:0x1186887b0.bottom - 5.6521739130434785>",
    "<SnapKit.LayoutConstraint:0x2839c9800@TPAudioLiveAvatarSuperCell.swift#250 UIStackView:0x118689c40.height == 18.840579710144926>",
    "<SnapKit.LayoutConstraint:0x28398bb40@TPAudioLiveAvatarSuperCell.swift#280 UIStackView:0x118689dd0.height == 15.072463768115941>",
    "<SnapKit.LayoutConstraint:0x2839f4b40@TPAudioLiveTextMessageCell.swift#68 YYLabel:0x11868e770.top == UIImageView:0x118689f60.top + 19.782608695652172>",
    "<SnapKit.LayoutConstraint:0x28398bf60@TPAudioLiveTextMessageCell.swift#68 YYLabel:0x11868e770.bottom == UIImageView:0x118689f60.bottom - 19.782608695652172>",
    "<SnapKit.LayoutConstraint:0x28391f420@TPAudioLiveTextMessageCell.swift#69 YYLabel:0x11868e770.height == 20.0>",
    "<NSLayoutConstraint:0x283e4cff0 'UISV-canvas-connection' UIStackView:0x118689ab0.top == UIStackView:0x118689c40.top   (active)>",
    "<NSLayoutConstraint:0x283e4c6e0 'UISV-canvas-connection' V:[UIImageView:0x118689f60]-(0)-|   (active, names: '|':UIStackView:0x118689ab0 )>",
    "<NSLayoutConstraint:0x283da8e10 'UISV-spacing' V:[UIStackView:0x118689c40]-(5.66667)-[UIStackView:0x118689dd0]   (active)>",
    "<NSLayoutConstraint:0x283da9900 'UISV-spacing' V:[UIStackView:0x118689dd0]-(5.66667)-[UIImageView:0x118689f60]   (active)>",
    "<NSLayoutConstraint:0x283daa3f0 'UIView-Encapsulated-Layout-Height' UITableViewCellContentView:0x1186887b0.height == 116   (active)>"
)

Will attempt to recover by breaking constraint 
<SnapKit.LayoutConstraint:0x28391f420@TPAudioLiveTextMessageCell.swift#69 YYLabel:0x11868e770.height == 20.0>

Make a symbolic breakpoint at UIViewAlertForUnsatisfiableConstraints to catch this in the debugger.
The methods in the UIConstraintBasedLayoutDebugging category on UIView listed in <UIKitCore/UIView.h> may also be helpful.
```
这里大概意思是：系统做约束时判定的高度约束 "<NSLayoutConstraint:0x283daa3f0 'UIView-Encapsulated-Layout-Height' UITableViewCellContentView:0x1186887b0.height == 116   (active)>" 与所有子视图的高度之和：5.6521739130434785+5.6521739130434785+18.840579710144926+15.072463768115941+19.782608695652172+19.782608695652172+5.66667+5.66667 = 115.29650724637682

不一致（这里可以看出存在精度差）。

### 处理方案：
将自动布局中的外层UIStackview移除，即下图红色外框。

此时cell由各个子视图的相互约束撑起。

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=4a5d2c2ac0ca48eba88708ce3a535ef5&docGuid=_xde_FaAG_kTa1)
目前处理方案已于8.2版本上线。

截止目前时间，目前线上运行了2.5天，8.2版本用户已升级了64%，暂时没有再出现这几个崩溃统计。

