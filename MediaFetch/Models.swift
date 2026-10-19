//
//  Models.swift
//  MediaFetch
//
//  Created by 小睡睡 on 2026/7/8.
import Foundation
internal import SwiftUI
import Combine

struct Constants {
    static let defaultYTDLPPath = "/opt/homebrew/bin/yt-dlp"
    static let defaultFFmpegPath = "/opt/homebrew/bin/ffmpeg"
    static let defaultDownloadFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
}

enum VideoSource: String, CaseIterable, Identifiable {
    case auto = "自動辨識"
    case youtube = "YouTube"
    case bilibili = "Bilibili"

    var id: String { self.rawValue }
}

struct YTDLPVideoInfo: Codable {
    let id: String?
    let title: String?
    let uploader: String?
    let channel: String?
    let channelId: String?
    let thumbnail: String?
    let webpageUrl: String?
    let durationString: String?

    init(
        id: String? = nil,
        title: String? = nil,
        uploader: String? = nil,
        channel: String? = nil,
        channelId: String? = nil,
        thumbnail: String? = nil,
        webpageUrl: String? = nil,
        durationString: String? = nil
    ) {
        self.id = id
        self.title = title
        self.uploader = uploader
        self.channel = channel
        self.channelId = channelId
        self.thumbnail = thumbnail
        self.webpageUrl = webpageUrl
        self.durationString = durationString
    }

    /// yt-dlp returns Bilibili artwork as HTTP. App Transport Security refuses
    /// non-secure requests, while Bilibili's CDN supports the equivalent HTTPS URL.
    var thumbnailURL: URL? {
        guard var components = URLComponents(string: thumbnail ?? "") else {
            return nil
        }

        if components.scheme?.lowercased() == "http" {
            components.scheme = "https"
        }

        return components.url
    }
}

struct DownloadOptions {
    var url: String = ""
    var source: VideoSource = .auto
    var isAudioOnly: Bool = false
    var videoQuality: String = "1080"
    var audioFormat: String = "mp3"
    var videoFormat: String = "mp4"
    var browserCookie: String = "None"
    var cookiesFilePath: String = ""
    var downloadPlaylist: Bool = false
    var audioQuality = "0"
}

enum DownloadState: String, Codable {
    case pending = "等待中"
    case downloading = "下載中"
    case processing = "處理中 (轉檔/合併)"
    case completed = "已完成"
    case failed = "失敗"
    case cancelled = "已取消"
}

@MainActor
class DownloadTask: Identifiable, ObservableObject {
    let id = UUID()
    @Published var url: String
    @Published var info: YTDLPVideoInfo? { didSet { notifyUpdate() } }
    @Published var progress: Double = 0.0 { didSet { notifyUpdate() } }
    @Published var speed: String = "-- MB/s" { didSet { notifyUpdate() } }
    @Published var eta: String = "--:--" { didSet { notifyUpdate() } }
    @Published var state: DownloadState = .pending { didSet { notifyUpdate() } }

    // 終端機日誌與展開狀態
    @Published var log: String = ""
    @Published var isLogExpanded: Bool = false

    var process: Process?
    let subscriptionID: UUID?
    let subscriptionVideoID: String?
    var onUpdate: (() -> Void)?

    init(
        url: String,
        info: YTDLPVideoInfo? = nil,
        subscriptionID: UUID? = nil,
        subscriptionVideoID: String? = nil
    ) {
        self.url = url
        self.info = info
        self.subscriptionID = subscriptionID
        self.subscriptionVideoID = subscriptionVideoID
    }

    func cancel() {
        if process?.isRunning == true {
            process?.terminate()
            state = .cancelled
            appendLog("\n=== 任務已由使用者取消 ===")
        }
    }

    func appendLog(_ text: String) {
        log += text
    }

    private func notifyUpdate() {
        onUpdate?()
    }
}
