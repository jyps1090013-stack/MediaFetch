//
//  SubscriptionAddView.swift
//  MediaFetch
//

internal import SwiftUI
import AppKit

struct SubscriptionAddView: View {

    @EnvironmentObject var manager: SubscriptionManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var url = ""
    @State private var folder = ""

    var body: some View {

        VStack(spacing: 20) {

            Text("新增訂閱")
                .font(.title2)
                .bold()

            Form {

                TextField("名稱", text: $name)

                TextField(
                    "YouTube 或 Bilibili 頻道/播放清單網址",
                    text: $url
                )

                HStack {

                    TextField(
                        "下載位置 (可留空以使用預設路徑)",
                        text: $folder
                    )

                    Button("選擇") {
                        chooseFolder()
                    }
                }
            }

            HStack {

                Button("取消") {
                    dismiss()
                }

                Spacer()

                Button("儲存") {

                    let item = Subscription(
                        name: name.isEmpty ? "未命名訂閱" : name,
                        url: url,
                        downloadFolderPath: folder
                    )

                    manager.add(item)

                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(url.isEmpty)
            }

        }
        .padding()
        .frame(width: 500, height: 300)
    }


    private func chooseFolder() {

        let panel = NSOpenPanel()

        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        if panel.runModal() == .OK,
           let url = panel.url {

            folder = url.path
        }
    }
}
