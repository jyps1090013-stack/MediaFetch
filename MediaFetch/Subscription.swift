//
//  Subscription.swift
//  MediaFetch
//
//  Created by 小睡睡 on 2026/8/22.
//

import Foundation

struct SubscriptionVideo: Identifiable, Codable {
    var id: String // Video ID
    var title: String
    var thumbnail: String?
    var duration: String?
    var state: DownloadState = .pending
    var progress: Double = 0.0
}

struct Subscription: Identifiable, Codable {
    var id = UUID()

    var name: String
    var url: String
    var downloadFolderPath: String

    var enabled: Bool = true
    var lastUpdate: Date = Date()
    var videos: [SubscriptionVideo] = []
}
