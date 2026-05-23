//
//  PodcastListView.swift
//  PodcastApp
//
//  主播客列表视图
//

import SwiftUI

struct PodcastListView: View {
    @StateObject private var contentLoader = PodcastContentLoader()
    @StateObject private var playerManager = PodcastPlayerManager.shared
    @State private var episodes: [PodcastEpisode] = []
    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    @State private var selectedPriority = "全部"

    private let categories = ["全部"] + EpisodeCategory.allCases.map { $0.rawValue }
    private let priorities = ["全部", "P0", "P1", "P2"]

    var body: some View {
        NavigationView {
            VStack {
                // 搜索和筛选栏
                VStack(spacing: 12) {
                    // 搜索框
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("搜索播客内容", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)

                    // 筛选器
                    HStack {
                        Picker("分类", selection: $selectedCategory) {
                            ForEach(categories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())

                        Picker("优先级", selection: $selectedPriority) {
                            ForEach(priorities, id: \.self) { priority in
                                Text(priority).tag(priority)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(UIColor.systemBackground))

                // 播客列表
                List(filteredEpisodes) { episode in
                    PodcastEpisodeRow(episode: episode)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            playerManager.play(episode: episode)
                        }
                }
                .listStyle(PlainListStyle())

                // 播放控制栏（如果正在播放）
                if playerManager.isPlaying, let currentEpisode = playerManager.currentEpisode {
                    PlayingNowBar(episode: currentEpisode)
                        .padding()
                }
            }
            .navigationTitle("iOS 底层知识播客")
            .onAppear {
                loadEpisodes()
            }
        }
    }

    private var filteredEpisodes: [PodcastEpisode] {
        var result = episodes

        // 搜索过滤
        if !searchText.isEmpty {
            result = result.filter { episode in
                episode.title.localizedCaseInsensitiveContains(searchText) ||
                episode.description.localizedCaseInsensitiveContains(searchText)
            }
        }

        // 分类过滤
        if selectedCategory != "全部" {
            result = result.filter { $0.category == selectedCategory }
        }

        // 优先级过滤
        if selectedPriority != "全部" {
            result = result.filter { $0.priority == selectedPriority }
        }

        return result
    }

    private func loadEpisodes() {
        episodes = PodcastContentLoader.shared.loadAllEpisodes()
    }
}

// MARK: - Episode Row View

struct PodcastEpisodeRow: View {
    let episode: PodcastEpisode
    @StateObject private var playerManager = PodcastPlayerManager.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                // 标题
                Text(episode.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                // 描述
                Text(episode.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // 元信息
                HStack(spacing: 12) {
                    // 分类标签
                    Text(episode.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)

                    // 优先级标签
                    Text(episode.priority)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priorityColor.opacity(0.1))
                        .foregroundColor(priorityColor)
                        .cornerRadius(8)

                    // 时长
                    Text(durationText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 播放状态指示器
            if playerManager.currentEpisode?.id == episode.id {
                Image(systemName: playerManager.isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .padding(.vertical, 8)
    }

    private var priorityColor: Color {
        switch episode.priority {
        case "P0": return .red
        case "P1": return .orange
        case "P2": return .green
        default: return .gray
        }
    }

    private var durationText: String {
        let minutes = Int(episode.duration) / 60
        return "\(minutes) 分钟"
    }
}

// MARK: - Playing Now Bar

struct PlayingNowBar: View {
    let episode: PodcastEpisode
    @StateObject private var playerManager = PodcastPlayerManager.shared

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("正在播放")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(episode.title)
                        .font(.headline)
                        .lineLimit(1)
                }

                Spacer()

                // 播放控制按钮
                HStack(spacing: 20) {
                    Button(action: {
                        playerManager.skipBackward()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                    }

                    Button(action: {
                        if playerManager.isPlaying {
                            playerManager.pause()
                        } else {
                            playerManager.resume()
                        }
                    }) {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                    }

                    Button(action: {
                        playerManager.skipForward()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                    }
                }
            }

            // 进度条
            ProgressView(value: playerManager.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

// MARK: - Preview

struct PodcastListView_Previews: PreviewProvider {
    static var previews: some View {
        PodcastListView()
    }
}