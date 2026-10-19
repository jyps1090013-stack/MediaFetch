//
//  SubscriptionView.swift
//  MediaFetch
//

internal import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var manager: SubscriptionManager
    @State private var showingAdd = false

    var body: some View {

        VStack {

            HStack {

                Text("訂閱列表")
                    .font(.headline)

                Spacer()

                Button {
                    showingAdd = true
                } label: {
                    Label("新增", systemImage: "plus")
                }
            }

            HStack {
                Button("更新全部") {
                    manager.updateAll(
                        downloadManager: downloadManager
                    )
                }
                .buttonStyle(.borderedProminent)

                Text("將檢查所有訂閱並下載新影片")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical)

            List {

                ForEach(manager.subscriptions) { item in

                    HStack {

                        VStack(alignment: .leading, spacing: 5) {

                            Text(item.name)
                                .font(.headline)

                            Text(item.url)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)

                        }

                        Spacer()

                        Button {
                            if let index = manager.subscriptions.firstIndex(where: {
                                $0.id == item.id
                            }) {
                                manager.subscriptions.remove(at: index)
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingAdd) {
            SubscriptionAddView()
        }
    }
}
