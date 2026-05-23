//
//  PodcastPlayerManager.swift
//  PodcastApp
//
//  播客播放器管理器 - 负责文本转语音和播放控制
//

import Foundation
import AVFoundation

class PodcastPlayerManager: NSObject, ObservableObject {

    // MARK: - Properties

    @Published var isPlaying: Bool = false
    @Published var currentEpisode: PodcastEpisode?
    @Published var progress: Double = 0.0
    @Published var speechRate: Float = 0.5  // 朗读速度

    private var speechSynthesizer: AVSpeechSynthesizer
    private var currentUtterance: AVSpeechUtterance?

    // MARK: - Singleton

    static let shared = PodcastPlayerManager()

    // MARK: - Initialization

    override init() {
        self.speechSynthesizer = AVSpeechSynthesizer()
        super.init()
        self.speechSynthesizer.delegate = self
    }

    // MARK: - Playback Control

    func play(episode: PodcastEpisode) {
        // 如果正在播放且是同一集，则暂停
        if isPlaying && currentEpisode?.id == episode.id {
            pause()
            return
        }

        // 停止当前播放
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        // 设置当前集
        currentEpisode = episode

        // 创建语音表达
        let utterance = AVSpeechUtterance(string: episode.fullContent)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        currentUtterance = utterance

        // 开始播放
        speechSynthesizer.speak(utterance)
        isPlaying = true
    }

    func pause() {
        speechSynthesizer.pauseSpeaking(at: .immediate)
        isPlaying = false
    }

    func resume() {
        speechSynthesizer.continueSpeaking()
        isPlaying = true
    }

    func stop() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        currentEpisode = nil
        progress = 0.0
    }

    func skipForward() {
        // 实现快进功能
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)

            if let utterance = currentUtterance,
               let episode = currentEpisode {
                // 简单实现：重新开始播放（实际应该计算位置跳转）
                let modifiedUtterance = AVSpeechUtterance(string: episode.fullContent)
                modifiedUtterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
                modifiedUtterance.rate = speechRate
                modifiedUtterance.volume = 1.0

                currentUtterance = modifiedUtterance
                speechSynthesizer.speak(modifiedUtterance)
                isPlaying = true
            }
        }
    }

    func skipBackward() {
        // 实现快退功能
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)

            if let utterance = currentUtterance,
               let episode = currentEpisode {
                // 简单实现：重新开始播放
                let modifiedUtterance = AVSpeechUtterance(string: episode.fullContent)
                modifiedUtterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
                modifiedUtterance.rate = speechRate
                modifiedUtterance.volume = 1.0

                currentUtterance = modifiedUtterance
                speechSynthesizer.speak(modifiedUtterance)
                isPlaying = true
            }
        }
    }

    func setSpeechRate(_ rate: Float) {
        self.speechRate = rate
        // 如果正在播放，更新当前语速
        if isPlaying, let utterance = currentUtterance {
            utterance.rate = rate
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension PodcastPlayerManager: AVSpeechSynthesizerDelegate {

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = true
            self.progress = 0.0
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.progress = 1.0
            // 播放完成后的处理（比如自动播放下一集）
            self.playNextEpisodeIfNeeded()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.progress = 0.0
        }
    }

    private func playNextEpisodeIfNeeded() {
        // 可以在这里实现自动播放下一集的逻辑
        // 比如根据播放列表自动播放下一集
    }
}