IM收消息卡顿优化

# 一、背景
Firebase收集到 IM 相关的卡顿，堆栈如下：

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=b39ed966dda648e5b2b75d84b5127d16&docGuid=lbe6N5asqO7r4X)


选取其中一个用户（uuid为：**10540DF6-338F-4093-AE23-D6A4B37F3D4D**），建立神策报表观察：

[https://www.hcapp-dc.com/user-sequence/search-users?project=Gravity&product=sensors_analysis#q=%7B%22user_id%22%3A%229096922730777212167%22%2C%22distinct_id%22%3A%2210540DF6-338F-4093-AE23-D6A4B37F3D4D%22%2C%22measures%5B0%5D%5Baggregator%5D%22%3A%22count%22%2C%22measures%5B0%5D%5Bfield%5D%22%3A%22%22%2C%22filter%5Bconditions%5D%5B0%5D%5Bfunction%5D%22%3A%22equal%22%2C%22filter%5Bconditions%5D%5B0%5D%5Bfield%5D%22%3A%22user.%24id%22%2C%22filter%5Bconditions%5D%5B0%5D%5Bparams%5D%5B0%5D%22%3A%2210540DF6-338F-4093-AE23-D6A4B37F3D4D%22%2C%22all_page%22%3Afalse%2C%22page%22%3A0%2C%22from%22%3A%22user_search%22%2C%22isSearch%22%3Atrue%2C%22title%5Bname%5D%22%3A%22用户列表%22%2C%22title%5Bdesc%5D%22%3A%22搜索结果用户明细%22%7D](https://www.hcapp-dc.com/user-sequence/search-users?project=Gravity&product=sensors_analysis#q=%7B%22user_id%22%3A%229096922730777212167%22%2C%22distinct_id%22%3A%2210540DF6-338F-4093-AE23-D6A4B37F3D4D%22%2C%22measures%5B0%5D%5Baggregator%5D%22%3A%22count%22%2C%22measures%5B0%5D%5Bfield%5D%22%3A%22%22%2C%22filter%5Bconditions%5D%5B0%5D%5Bfunction%5D%22%3A%22equal%22%2C%22filter%5Bconditions%5D%5B0%5D%5Bfield%5D%22%3A%22user.%24id%22%2C%22filter%5Bconditions%5D%5B0%5D%5Bparams%5D%5B0%5D%22%3A%2210540DF6-338F-4093-AE23-D6A4B37F3D4D%22%2C%22all_page%22%3Afalse%2C%22page%22%3A0%2C%22from%22%3A%22user_search%22%2C%22isSearch%22%3Atrue%2C%22title%5Bname%5D%22%3A%22用户列表%22%2C%22title%5Bdesc%5D%22%3A%22搜索结果用户明细%22%7D)



2025/12/6 ~ 2026/1/17 期间，平均每天的卡顿数为 30 次左右。

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=ec75b1d6aaaa47c8bb28ce7c12f13f22&docGuid=lbe6N5asqO7r4X)




# 二、修复方案
1. 分析堆栈发现是 IM 收消息的时候，查询数据库导致的卡顿，线下自测发现 IM 消息少时不会有卡顿，可能是线上用户频繁收到 IM 消息，导致查询数据库特别频繁，从而卡顿；
2. 需要在收到 IM 消息后，对查询数据库做频率限制，目前限制0.5s内只查询一次数据库；
3. 需求卡片：[[soulmate-30099] 【技术需求】优化IM收消息卡顿](https://console.cloud.baidu-int.com/devops/icafe/issue/soulmate-30099/show?source=copy-shortcut?t=mention&mt=doc&dt=sdk)



# 三、修复效果
uuid为**10540DF6-338F-4093-AE23-D6A4B37F3D4D**的用户，卡顿已降为0

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=3acf0deaab3f419094de8259392df765&docGuid=lbe6N5asqO7r4X)


[神策报表](https://www.hcapp-dc.com/segmentation/?project=Gravity&product=sensors_analysis#q=%7B%22approx%22%3Afalse%2C%22sampling_factor%22%3A64%2C%22by_fields%22%3A%5B%5D%2C%22filter%22%3A%7B%22conditions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%7D%2C%22arith_rollup%22%3Atrue%2C%22measures%22%3A%5B%7B%22event_name%22%3A%22firebase_crashlytics%22%2C%22aggregator%22%3A%22general%22%2C%22id%22%3A0.289084860286555%2C%22default_measure_name%22%3A%22firebase_crashlytics的总次数%22%2C%22name%22%3A%22修复卡顿%22%2C%22type%22%3A%22normal%22%2C%22openPanel%22%3Atrue%2C%22editName%22%3A%22修复卡顿%22%2C%22filter%22%3A%7B%22conditions%22%3A%5B%7B%22field%22%3A%22event.%24Anything.is_fatal%22%2C%22function%22%3A%22isFalse%22%2C%22params%22%3A%5B%5D%2C%22%24%24render_index%22%3A1%7D%2C%7B%22field%22%3A%22event.%24Anything.%24distinct_id%22%2C%22function%22%3A%22contain%22%2C%22params%22%3A%5B%2210540DF6-338F-4093-AE23-D6A4B37F3D4D%22%5D%2C%22%24%24render_index%22%3A2%7D%2C%7B%22field%22%3A%22event.%24Anything.%24app_version%22%2C%22function%22%3A%22contain%22%2C%22params%22%3A%5B%2213.7%22%5D%2C%22%24%24render_index%22%3A3%7D%5D%2C%22filters%22%3A%5B%5D%7D%7D%2C%7B%22event_name%22%3A%22firebase_crashlytics%22%2C%22aggregator%22%3A%22general%22%2C%22id%22%3A0.8738565404340491%2C%22default_measure_name%22%3A%22firebase_crashlytics的总次数%22%2C%22name%22%3A%22未修复卡顿%22%2C%22type%22%3A%22normal%22%2C%22filter%22%3A%7B%22conditions%22%3A%5B%7B%22field%22%3A%22event.%24Anything.is_fatal%22%2C%22function%22%3A%22isFalse%22%2C%22params%22%3A%5B%5D%2C%22%24%24searchValue%22%3A%22fat%22%2C%22%24%24render_index%22%3A1%7D%2C%7B%22field%22%3A%22event.%24Anything.%24distinct_id%22%2C%22function%22%3A%22contain%22%2C%22params%22%3A%5B%2210540DF6-338F-4093-AE23-D6A4B37F3D4D%22%5D%2C%22%24%24render_index%22%3A2%7D%2C%7B%22field%22%3A%22event.%24Anything.%24app_version%22%2C%22function%22%3A%22notContain%22%2C%22params%22%3A%5B%2213.7%22%5D%2C%22%24%24render_index%22%3A3%7D%5D%2C%22filters%22%3A%5B%5D%7D%2C%22openPanel%22%3Atrue%2C%22editName%22%3A%22未修复卡顿%22%7D%5D%2C%22from_date%22%3A%222025-12-06%22%2C%22to_date%22%3A%222026-02-03%22%2C%22compare_to_date%22%3A%22%22%2C%22rangeText%22%3A%22%22%2C%22unit%22%3A%22day%22%2C%22detail_and_rollup%22%3Atrue%2C%22enable_detail_follow_rollup_by_values_rank%22%3Atrue%2C%22sub_task_type%22%3A%22SEGMENTATION%22%2C%22time_zone_mode%22%3A%22SERVER%22%2C%22server_time_zone%22%3A%22UTC%2B08%3A00%22%2C%22compareKey%22%3A%22%22%7D)



卡顿大盘数据

版本上线稳定后，人均卡顿次数有下降

![](https://rte.weiyun.baidu.com/wiki/attach/image/api/imageDownloadAddress?attachId=af9b0a4692884ad5ac3f0b87b97875a5&docGuid=lbe6N5asqO7r4X)


















