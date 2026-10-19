//
//  YTDLPMacAppApp.swift
//  MediaFetch
//
//  Created by 小睡睡 on 2026/7/8.
internal import SwiftUI
import AppKit

@main
struct YTDLPMacAppApp: App {
    @StateObject private var downloadManager = DownloadManager()
    @StateObject private var subscriptionManager = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(downloadManager)
                .environmentObject(subscriptionManager)
                .frame(minWidth: 850, minHeight: 600)
                .onAppear {
                    downloadManager.checkDependencies()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About MediaFetch") {
                    NSApplication.shared.orderFrontStandardAboutPanel()
                }
            }

            CommandGroup(replacing: .newItem) {
                Button("NewDownloadTask") {
                    NotificationCenter.default.post(
                        name: Notification.Name("NewDownloadTask"),
                        object: nil
                    )
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Tools") {
                Button("ConverterTool") {
                    NotificationCenter.default.post(
                        name: Notification.Name("OpenConverter"),
                        object: nil
                    )
                }

                Button("CheckDependencies") {
                    NotificationCenter.default.post(
                        name: Notification.Name("CheckDependencies"),
                        object: nil
                    )
                }
            }
        }
    }
}
