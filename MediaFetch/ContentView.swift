internal import SwiftUI

struct ContentView: View {
    @State private var selectedFile: URL?
    @State private var isDragging = false
    @State private var outputFormat = "mp3"
    @State private var status = "尚未選擇檔案"

    @EnvironmentObject var manager: DownloadManager

    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var logs = ""

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)

            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
