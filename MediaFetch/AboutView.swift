//
//  AboutView.swift
//  MediaFetch
//
//  Created by 小睡睡 on 2026/8/19.
//
internal import SwiftUI
import AppKit

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                .padding(.bottom, 10)

            Text("MediaFetch")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("版本 1.0.0")
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 250)

            VStack(spacing: 8) {
                Label("Powered by yt-dlp", systemImage: "terminal")
                Label("Powered by FFmpeg", systemImage: "film")
                Label("Built with SwiftUI", systemImage: "swift")
            }
            .font(.subheadline)

            Spacer()

            HStack {
                Button {
                    NSWorkspace.shared.open(
                        URL(string: "https://github.com/jyps1090013-stack/MediaFetch")!
                    )
                } label: {
                    Label("GitHub", systemImage: "link")
                }

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("關閉", systemImage: "xmark")
                }
            }

        }
        .padding(40)
        .frame(width: 380, height: 500)
    }
}
