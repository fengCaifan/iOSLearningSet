//
//  PodcastDetailView.swift
//  PodcastApp
//
//  播客详细播放视图
//

import SwiftUI

struct PodcastDetailView: View {
    let episode: PodcastEpisode
    @StateObject private var playerManager = PodcastPlayerManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var speechRate: Float = 0.5

    private let rateOptions: [Float] = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 关闭按钮
                HStack {
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()

                // 播客封面
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [blueGradient, purpleGradient]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 200, height: 200)

                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                    }
                    .shadow(radius: 10)

                    Text("iOS 底层知识播客")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.top, 40)

                // 播客信息
                VStack(spacing: 12) {
                    Text(episode.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(episode.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // 标签
                    HStack(spacing: 12) {
                        Text(episode.category)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)

                        Text(episode.priority)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(priorityColor.opacity(0.1))
                            .foregroundColor(priorityColor)
                            .cornerRadius(12)

                        Text(durationText)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                // 播放控制
                VStack(spacing: 20) {
                    // 进度条
                    VStack(spacing: 8) {
                        ProgressView(value: playerManager.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(x: 1, y: 2, anchor: .center)

                        HStack {
                            Text("0:00")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(totalDurationText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // 主控制按钮
                    HStack(spacing: 30) {
                        Button(action: {
                            playerManager.skipBackward()
                        }) {
                            Image(systemName: "gobackward.15")
                                .font(.title)
                                .foregroundColor(.primary)
                        }

                        Button(action: {
                            if playerManager.isPlaying {
                                playerManager.pause()
                            } else {
                                playerManager.resume()
                            }
                        }) {
                            Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                        }

                        Button(action: {
                            playerManager.skipForward()
                        }) {
                            Image(systemName: "goforward.15")
                                .font(.title)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .padding()

                // 语速控制
                VStack(spacing: 12) {
                    Text("朗读速度")
                        .font(.headline)

                    HStack(spacing: 16) {
                        ForEach(rateOptions, id: \.self) { rate in
                            Button(action: {
                                speechRate = rate
                                playerManager.setSpeechRate(rate)
                            }) {
                                Text("\(rate, specifier: "%.1f")x")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(speechRate == rate ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(speechRate == rate ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()

                // 操作按钮
                HStack(spacing: 20) {
                    Button(action: {
                        // 添加到收藏
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "heart")
                                .font(.title2)
                            Text("收藏")
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                    }

                    Button(action: {
                        // 分享功能
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                            Text("分享")
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                    }

                    Button(action: {
                        // 查看笔记
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.title2)
                            Text("笔记")
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            playerManager.play(episode: episode)
        }
        .onDisappear {
            // 不自动停止播放，让用户继续听
        }
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

    private var totalDurationText: String {
        let minutes = Int(episode.duration) / 60
        let seconds = Int(episode.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var blueGradient: Color {
        return Color(red: 0.0, green: 0.5, blue: 1.0)
    }

    private var purpleGradient: Color {
        return Color(red: 0.5, green: 0.0, blue: 1.0)
    }
}

// MARK: - Preview

struct PodcastDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEpisode = PodcastEpisode(
            id: "1",
            title: "OC Runtime 消息机制",
            description: "Runtime 是 OC 的运行时系统，通过消息发送机制实现动态调用",
            category: "01-语言基础",
            priority: "P0",
            fileName: "OC-Runtime消息机制.md",
            duration: 1800.0
        )

        PodcastDetailView(episode: sampleEpisode)
    }
}