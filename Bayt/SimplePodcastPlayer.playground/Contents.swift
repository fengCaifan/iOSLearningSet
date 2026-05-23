//: Playground - noun: a place where people can play
//
// iOS 底层知识播客 - 简化版
// 可以直接在 Xcode 中运行这个 Playground

import AVFoundation
import Foundation

// 播客数据模型
struct SimplePodcastEpisode {
    let title: String
    let content: String
    let category: String
    let priority: String
}

// 播客管理器
class SimplePodcastPlayer {
    private let synthesizer = AVSpeechSynthesizer()

    func play(episode: SimplePodcastEpisode) {
        let utterance = AVSpeechUtterance(string: episode.content)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        synthesizer.speak(utterance)

        print("正在播放: \(episode.title)")
        print("分类: \(episode.category)")
        print("优先级: \(episode.priority)")
    }
}

// 示例播客内容
let sampleEpisodes = [
    SimplePodcastEpisode(
        title: "OC Runtime 消息机制",
        content: """
        Runtime 是 OC 的运行时系统，通过消息发送机制实现动态调用，让程序在运行时可以创建类、添加方法、修改方法实现，是 OC 动态特性的核心。

        核心概念：
        Runtime 是一个纯 C 语言编写的运行时库，为 OC 提供运行时支持，使 OC 成为一种动态语言。

        主要作用：
        1. 消息派发：通过 objc_msgSend 实现方法调用
        2. 动态方法：运行时添加、修改、交换方法
        3. 反射机制：获取类、方法、属性信息
        """,
        category: "01-语言基础",
        priority: "P0"
    ),
    SimplePodcastEpisode(
        title: "iOS 内存管理完全指南",
        content: """
        iOS 内存管理是开发者必须掌握的核心技能。

        引用计数原理：
        1. 每个对象都有一个引用计数器
        2. 当引用计数为 0 时，对象会被销毁
        3. ARC 自动管理引用计数

        内存泄漏常见原因：
        1. 循环引用
        2. Delegate 没有使用 weak
        3. Block 中的强引用
        4. Timer 没有释放
        """,
        category: "03-多线程与内存",
        priority: "P0"
    ),
    SimplePodcastEpisode(
        title: "RunLoop 原理与应用",
        content: """
        RunLoop 是 iOS 开发中的核心概念，理解它对于处理线程相关问题和性能优化非常重要。

        RunLoop 的基本概念：
        1. RunLoop 是事件处理循环
        2. 每个线程都有唯一的 RunLoop
        3. 主线程的 RunLoop 默认启动

        RunLoop 的作用：
        1. 保持线程持续运行
        2. 处理各种事件（触摸、定时器等）
        3. 节省 CPU 资源
        """,
        category: "01-语言基础",
        priority: "P0"
    )
]

// 使用示例
let player = SimplePodcastPlayer()

print("🎧 iOS 底层知识播客 - 简化版")
print("可用播客数量: \(sampleEpisodes.count)")
print("")

// 播放第一个播客
player.play(episode: sampleEpisodes[0])

print("提示：在 Playground 中，语音会自动播放")
print("在实际应用中，你可以添加播放控制界面")

// 等待播放完成（Playground 中需要保持运行）
RunLoop.main.run(until: Date(timeIntervalSinceNow: 10))