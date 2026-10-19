//
//  DownloadManager.swift
//  MediaFetch
//
//  Created by 小睡睡 on 2026/7/8.
import Foundation
internal import SwiftUI
import Combine

@MainActor
class DownloadManager: ObservableObject {
    @Published var tasks: [DownloadTask] = []

    @AppStorage("ytdlpPath") var ytdlpPath = Constants.defaultYTDLPPath
    @AppStorage("ffmpegPath") var ffmpegPath = Constants.defaultFFmpegPath
    @AppStorage("downloadPath") var downloadPath = Constants.defaultDownloadFolder.path

    @Published var isYtdlpReady: Bool = false
    @Published var isFFmpegReady: Bool = false

    func checkDependencies() {
        let fm = FileManager.default
        isYtdlpReady = fm.isExecutableFile(atPath: ytdlpPath)
        isFFmpegReady = fm.isExecutableFile(atPath: ffmpegPath)
    }

    func addTask(options: DownloadOptions, info: YTDLPVideoInfo?) {
        let task = DownloadTask(url: options.url, info: info)
        withAnimation { tasks.insert(task, at: 0) }

        Task {
            do {
                let destURL = URL(fileURLWithPath: downloadPath)
                try await YTDLPService.startDownload(task: task, options: options, destination: destURL, ytdlpPath: ytdlpPath, ffmpegPath: ffmpegPath)
            } catch {
                task.state = .failed
            }
        }
    }

    func addSubscriptionDownload(url: String, name: String, destination: URL, archivePath: String? = nil) {
        var options = DownloadOptions()
        options.url = url
        options.downloadPlaylist = true

        let task = DownloadTask(url: url, info: nil)
        withAnimation { tasks.insert(task, at: 0) }

        Task {
            do {
                try await YTDLPService.startDownload(
                    task: task,
                    options: options,
                    destination: destination,
                    ytdlpPath: ytdlpPath,
                    ffmpegPath: ffmpegPath,
                    archivePath: archivePath
                )
            } catch {
                await MainActor.run {
                    task.state = .failed
                }
            }
        }
    }

    func removeCompleted() {
        withAnimation { tasks.removeAll { $0.state == .completed || $0.state == .cancelled } }
    }
}
