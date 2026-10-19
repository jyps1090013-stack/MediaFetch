//
//  SubscriptionManager.swift
//  MediaFetch
//

import Foundation
import Combine
internal import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    // 保留舊資料夾名稱，讓改名前已儲存的訂閱清單能繼續被讀取。
    private let legacyApplicationSupportFolderName = "YouTube Downloader"

    @Published var subscriptions: [Subscription] = [] {
        didSet {
            save()
        }
    }

    private let fileURL: URL

    init() {
        let folder = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(legacyApplicationSupportFolderName)

        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("subscriptions.json")
        load()
    }

    func add(_ subscription: Subscription) {
        subscriptions.append(subscription)
    }

    func remove(at offsets: IndexSet) {
        subscriptions.remove(atOffsets: offsets)
    }

    func updateAll(downloadManager: DownloadManager) {
        for item in subscriptions {
            // 決定儲存路徑：優先使用訂閱設定的路徑，否則使用全域路徑 + 訂閱名稱
            let destinationPath: String
            if !item.downloadFolderPath.isEmpty {
                destinationPath = item.downloadFolderPath
            } else {
                destinationPath = URL(fileURLWithPath: downloadManager.downloadPath)
                    .appendingPathComponent(item.name).path
            }

            let destinationURL = URL(fileURLWithPath: destinationPath)

            // 建立目錄
            try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

            // 建立該訂閱專用的 archive 檔案，用於紀錄已下載影片
            let archiveURL = destinationURL.appendingPathComponent("archive.txt")
            let archivePath = archiveURL.path

            downloadManager.addSubscriptionDownload(
                url: item.url,
                name: item.name,
                destination: destinationURL,
                archivePath: archivePath
            )
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(subscriptions)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("保存失敗:", error)
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            subscriptions = try JSONDecoder().decode([Subscription].self, from: data)
        } catch {
            print("載入失敗:", error)
        }
    }
}
