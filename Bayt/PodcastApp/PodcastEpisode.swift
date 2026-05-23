//
//  PodcastEpisode.swift
//  PodcastApp
//
//  播客单集数据模型
//

import Foundation

struct PodcastEpisode: Identifiable, Equatable {

    let id: String
    let title: String
    let description: String
    let category: String
    let priority: String
    let fileName: String
    let duration: TimeInterval // 预计时长（秒）

    var fullContent: String {
        return """
        【播客标题】\(title)

        【分类】\(category)

        【简介】\(description)

        【优先级】\(priority)

        【正文内容】

        \(content)
        """
    }

    private var content: String {
        // 这里应该是从文件加载的实际内容
        // 为了演示，我们返回占位符内容
        return """
        欢迎收听 iOS 底层知识播客。今天我们要讨论的主题是：\(title)。

        这个主题属于 \(category) 类别，对于深入理解 iOS 开发非常重要。

        在我们的学习体系中，这个主题被标记为 \(priority) 优先级。

        让我们开始今天的学习之旅。

        （注：完整内容将在运行时从文件中加载）
        """
    }
}

// MARK: - Episode Metadata

extension PodcastEpisode {

    static func generateDuration(for content: String) -> TimeInterval {
        // 假设平均语速为每分钟 150 个汉字
        let wordCount = content.count
        let wordsPerMinute = 150.0
        return (Double(wordCount) / wordsPerMinute) * 60.0
    }
}

// MARK: - Episode Categories

enum EpisodeCategory: String, CaseIterable {
    case languageBasics = "01-语言基础"
    case systemFrameworks = "02-系统框架"
    case threadingMemory = "03-多线程与内存"
    case performanceOptimization = "04-性能优化"
    case networkSecurity = "05-网络与安全"
    case architectureDesign = "06-架构与设计"
    case engineering = "07-工程化"
    case systemDesign = "08-系统设计题"
    case interviewReview = "09-面试复盘"

    var displayName: String {
        return rawValue
    }
}

// MARK: - Episode Priority

enum EpisodePriority: String, CaseIterable {
    case p0 = "P0"
    case p1 = "P1"
    case p2 = "P2"

    var displayName: String {
        switch self {
        case .p0: return "必须掌握"
        case .p1: return "重要"
        case .p2: return "加分项"
        }
    }

    var description: String {
        switch self {
        case .p0: return "必须掌握，面试高频"
        case .p1: return "重要，资深岗常考"
        case .p2: return "加分项，有则更好"
        }
    }
}