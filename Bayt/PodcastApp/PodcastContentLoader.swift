//
//  PodcastContentLoader.swift
//  PodcastApp
//
//  内容加载器 - 从文件系统加载 iOS 底层知识内容
//

import Foundation

class PodcastContentLoader {

    // MARK: - Singleton

    static let shared = PodcastContentLoader()

    // MARK: - Properties

    private let basePath = "/Users/fengcaifan/Documents/fcfgithub/iOSLearningSet/iOS底层知识体系"

    // MARK: - Initialization

    private init() {}

    // MARK: - Content Loading

    func loadAllEpisodes() -> [PodcastEpisode] {
        var episodes: [PodcastEpisode] = []

        // 定义知识库结构
        let knowledgeBase = getKnowledgeBaseStructure()

        for (category, files) in knowledgeBase {
            for file in files {
                if let episode = loadEpisode(category: category, fileName: file) {
                    episodes.append(episode)
                }
            }
        }

        return episodes.sorted { $0.title < $1.title }
    }

    func loadEpisode(category: String, fileName: String) -> PodcastEpisode? {
        let filePath = "\(basePath)/\(category)/\(fileName)"

        guard let content = loadFileContent(at: filePath) else {
            return nil
        }

        // 从内容中提取元数据
        let title = extractTitle(from: content)
        let description = extractDescription(from: content)
        let priority = extractPriority(from: content)

        let episode = PodcastEpisode(
            id: UUID().uuidString,
            title: title,
            description: description,
            category: category,
            priority: priority,
            fileName: fileName,
            duration: PodcastEpisode.generateDuration(for: content)
        )

        return episode
    }

    // MARK: - File Reading

    private func loadFileContent(at path: String) -> String? {
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            print("Error loading file at \(path): \(error)")
            return nil
        }
    }

    // MARK: - Content Parsing

    private func extractTitle(from content: String) -> String {
        // 提取 Markdown 标题
        if let range = content.range(of: "^#\\s+.+$", options: .regularExpression) {
            let titleLine = String(content[range]).trimmingCharacters(in: .whitespaces)
            return titleLine.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
        }
        return "未知标题"
    }

    private func extractDescription(from content: String) -> String {
        // 提取引用内容作为描述
        if let range = content.range(of: "^>\\s+.+$", options: .regularExpression) {
            let descLine = String(content[range]).trimmingCharacters(in: .whitespaces)
            return descLine.replacingOccurrences(of: ">", with: "").trimmingCharacters(in: .whitespaces)
        }
        return "暂无描述"
    }

    private func extractPriority(from content: String) -> String {
        // 从内容中提取优先级信息
        if content.contains("P0") {
            return "P0"
        } else if content.contains("P1") {
            return "P1"
        } else {
            return "P2"
        }
    }

    // MARK: - Knowledge Base Structure

    private func getKnowledgeBaseStructure() -> [String: [String]] {
        return [
            "01-语言基础": [
                "OC-Runtime消息机制.md",
                "OC-RunLoop原理与应用.md",
                "OC-Block底层实现.md",
                "OC-KVC与KVO原理.md",
                "OC-Category与关联对象.md",
                "Swift-值类型与引用类型.md",
                "Swift-协议与泛型.md",
                "Swift-并发模型(async_await_Actor).md",
                "Swift-内存管理与ARC.md"
            ],
            "02-系统框架": [
                "UIKit-渲染管线与离屏渲染.md",
                "UIKit-事件响应链与手势.md",
                "CoreAnimation-动画与图层.md",
                "CoreText-文字排版与YYLabel.md",
                "SwiftUI-状态管理与生命周期.md",
                "AVFoundation-音视频基础.md",
                "Network-URLSession与网络层设计.md"
            ],
            "03-多线程与内存": [
                "iOS内存管理完全指南.md",
                "iOS多线程完全指南.md",
                "锁的分类与性能对比.md"
            ],
            "04-性能优化": [
                "启动优化-pre_main与post_main.md",
                "卡顿优化-监控与治理.md",
                "内存优化-OOM与Jetsam.md",
                "包体积优化-LinkMap与资源瘦身.md",
                "图片优化-加载解码与降采样.md",
                "电量优化.md"
            ],
            "05-网络与安全": [
                "HTTP协议与HTTPS原理.md",
                "TCP-UDP与Socket.md",
                "HTTP2与HTTP3-QUIC.md",
                "HTTPDNS与弱网优化.md",
                "iOS签名与证书机制.md",
                "安全-混淆反调试SSL_Pinning.md"
            ],
            "06-架构与设计": [
                "架构模式对比(MVC_MVVM_VIPER_TCA).md",
                "组件化-路由与依赖注入.md",
                "设计模式在iOS中的应用.md",
                "SOLID原则实践.md"
            ],
            "07-工程化": [
                "编译原理-LLVM与Clang.md",
                "Mach-O与链接器.md",
                "CI-CD与自动化.md",
                "APM-崩溃收集与符号化.md",
                "APM-卡顿与内存监控.md",
                "单元测试与UI测试.md"
            ],
            "08-系统设计题": [
                "设计一个图片加载框架.md",
                "设计一个网络层中间件.md",
                "设计一个路由框架.md",
                "设计一个日志系统.md",
                "设计一个APM-SDK.md"
            ],
            "09-面试复盘": [
                "高频题整理.md",
                "面试-技术深度问答手册.md",
                "算法题精选.md",
                "面经-按公司归档.md"
            ]
        ]
    }

    // MARK: - Search and Filter

    func searchEpisodes(by query: String) -> [PodcastEpisode] {
        let allEpisodes = loadAllEpisodes()
        return allEpisodes.filter { episode in
            episode.title.localizedCaseInsensitiveContains(query) ||
            episode.description.localizedCaseInsensitiveContains(query) ||
            episode.category.localizedCaseInsensitiveContains(query)
        }
    }

    func getEpisodes(byPriority priority: String) -> [PodcastEpisode] {
        let allEpisodes = loadAllEpisodes()
        return allEpisodes.filter { $0.priority == priority }
    }

    func getEpisodes(byCategory category: String) -> [PodcastEpisode] {
        let allEpisodes = loadAllEpisodes()
        return allEpisodes.filter { $0.category == category }
    }
}