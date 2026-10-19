//
//  Views.swift
//  MediaFetch
//
//  Created by 小睡睡 on 2026/7/8.
internal import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainView: View {
    @EnvironmentObject var manager: DownloadManager
    @State private var selectedTab: String? = "downloads"
    @State private var isShowingCreateTask = false

    var body: some View {
        ZStack {
            NavigationSplitView {
                List(selection: $selectedTab) {
                    Label("下載任務", systemImage: "arrow.down.circle.fill").tag("downloads")
                    Label("訂閱", systemImage: "antenna.radiowaves.left.and.right").tag("subscriptions")
                    Label("轉檔工具", systemImage: "arrow.triangle.2.circlepath").tag("converter")
                    Label("設定", systemImage: "gearshape.fill").tag("settings")
                    Label("關於", systemImage: "info.circle.fill").tag("about")
                }
                .navigationTitle("Downloader")
                .listStyle(.sidebar)

                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    DependencyStatusView(name: "yt-dlp", isReady: manager.isYtdlpReady)
                    DependencyStatusView(name: "FFmpeg", isReady: manager.isFFmpegReady)
                }
                .padding()

            } detail: {

                if selectedTab == "downloads" {

                    TaskListView()
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button {
                                    isShowingCreateTask = true
                                } label: {
                                    Label("新增下載", systemImage: "plus")
                                }
                            }
                        }

                } else if selectedTab == "subscriptions" {

                    SubscriptionView()

                } else if selectedTab == "converter" {

                    ConverterView()

                } else if selectedTab == "settings" {

                    SettingsView()

                } else {

                    AboutView()

                }
            }

            if isShowingCreateTask {
                // 背景遮罩：點擊空白處關閉
                Color.black.opacity(0.01)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            isShowingCreateTask = false
                        }
                    }
                    .ignoresSafeArea()
                    .zIndex(1)

                CreateTaskView(isPresented: $isShowingCreateTask)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(2)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isShowingCreateTask)
    }

    struct DependencyStatusView: View {
        let name: String
        let isReady: Bool

        var body: some View {
            HStack {
                Circle()
                    .fill(isReady ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    struct TaskListView: View {
        @EnvironmentObject var manager: DownloadManager

        var body: some View {
            ZStack {
                Color(NSColor.windowBackgroundColor).ignoresSafeArea()

                if manager.tasks.isEmpty {
                    ContentUnavailableView("無任務", systemImage: "tray", description: Text("點擊右上角新增下載"))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(manager.tasks) { task in
                                TaskCardView(task: task)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("任務列表")
            .toolbar {
                if !manager.tasks.isEmpty {
                    Button("清除已完成", systemImage: "trash") { manager.removeCompleted() }
                }
            }
        }
    }

    struct TaskCardView: View {
        @ObservedObject var task: DownloadTask

        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    if let url = task.info?.thumbnailURL {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                thumbnailPlaceholder
                            } else {
                                Color.gray.opacity(0.3).overlay(ProgressView())
                            }
                        }
                        .frame(width: 120, height: 68)
                        .cornerRadius(6)
                        .clipped()
                    } else {
                        thumbnailPlaceholder
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.info?.title ?? task.url)
                            .font(.headline)
                            .lineLimit(1)

                        HStack {
                            Text(task.info?.uploader ?? "未知頻道")
                            Spacer()
                            Text(task.info?.durationString ?? "")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        HStack {
                            ProgressView(value: task.progress, total: 100.0)
                                .progressViewStyle(.linear)
                                .tint(statusColor)

                            Text(String(format: "%.1f%%", task.progress))
                                .font(.caption.monospacedDigit())
                                .frame(width: 50, alignment: .trailing)
                        }

                        HStack {
                            Text(task.state.rawValue).foregroundColor(statusColor).fontWeight(.medium)
                            Spacer()
                            if task.state == .downloading {
                                Text("\(task.speed) • 剩餘: \(task.eta)")
                            }
                        }
                        .font(.caption2)
                    }

                    VStack(spacing: 12) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                task.isLogExpanded.toggle()
                            }
                        }) {
                            Image(systemName: task.isLogExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("查看詳細日誌")

                        if task.state == .downloading || task.state == .pending || task.state == .processing {
                            Button(action: { task.cancel() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("取消下載")
                        }
                    }
                }
                .padding(12)

                if task.isLogExpanded {
                    Divider()
                    TextEditor(text: .constant(task.log))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                        .scrollContentBackground(.hidden)
                        .background(Color(NSColor.underPageBackgroundColor))
                    .frame(height: 180)            }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        }

        private var statusColor: Color {
            switch task.state {
            case .completed: return .green
            case .failed: return .red
            case .downloading, .processing: return .blue
            case .cancelled: return .orange
            default: return .secondary
            }
        }

        private var thumbnailPlaceholder: some View {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 120, height: 68)
                .overlay(Image(systemName: "video.fill").foregroundColor(.gray))
        }
    }

    struct CreateTaskView: View {
        @Binding var isPresented: Bool
        @EnvironmentObject var manager: DownloadManager

        @State private var options: DownloadOptions = DownloadOptions()
        @State private var phase: Phase = .input
        @State private var videoInfo: YTDLPVideoInfo?
        @State private var isParsing = false

        @State private var showingErrorAlert = false
        @State private var errorMessage = ""

        enum Phase { case input, configure }

        let cookies = ["None", "Safari", "Chrome", "Firefox", "Edge", "匯入 cookies.txt"]
        let vQualities = ["2160", "1440", "1080", "720", "480"]
        let vFormats = ["mp4", "mkv", "webm"]
        let aFormats = ["mp3", "m4a", "flac"]
        let aQualities = [
            ("0", "最佳品質"),
            ("320K", "320 kbps"),
            ("256K", "256 kbps"),
            ("192K", "192 kbps"),
            ("128K", "128 kbps")
        ]

        var body: some View {
            VStack(spacing: 0) {
                HStack {
                    Text("新增下載任務").font(.headline)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
                .padding()

                Divider()

                if phase == .input {
                    inputView
                } else {
                    configureView
                }
            }
            .frame(width: 550)
        }

        private var inputView: some View {
            VStack(spacing: 20) {
                HStack {
                    Picker("來源", selection: $options.source) {
                        ForEach(VideoSource.allCases) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)

                    TextField("貼上影片網址 (YouTube / Bilibili)...", text: $options.url)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                        .onChange(of: options.url) { newValue in
                            autoDetectSource(url: newValue)
                        }
                }

                if !manager.isYtdlpReady {
                    Label("找不到 yt-dlp，請先至設定頁面配置路徑。", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                HStack {
                    Spacer()
                    Button("解析影片") {
                        parseVideo()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(options.url.isEmpty || isParsing || !manager.isYtdlpReady)

                    if isParsing { ProgressView().padding(.leading) }
                }
            }
            .padding(30)
            .alert("解析失敗", isPresented: $showingErrorAlert) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }

        private var configureView: some View {
            VStack(spacing: 20) {
                if let info = videoInfo {
                    HStack(alignment: .top, spacing: 12) {
                        if let url = info.thumbnailURL {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else if phase.error != nil {
                                    previewThumbnailPlaceholder
                                } else {
                                    Color.gray.opacity(0.3).overlay(ProgressView())
                                }
                            }
                            .frame(width: 140, height: 79)
                            .cornerRadius(8)
                            .clipped()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(info.title ?? "未知標題").font(.headline).lineLimit(2)
                            Text(info.uploader ?? "頻道").font(.subheadline).foregroundColor(.secondary)
                            Text(info.durationString ?? "").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(10)
                }

                Form {
                    Picker("模式", selection: $options.isAudioOnly) {
                        Text("下載影片").tag(false)
                        Text("僅下載音訊").tag(true)
                    }.pickerStyle(.segmented)

                    if options.isAudioOnly {
                        Picker("音訊格式", selection: $options.audioFormat) { ForEach(aFormats, id: \.self) { Text($0.uppercased()).tag($0) } }
                    } else {
                        HStack {
                            Picker("最高畫質", selection: $options.videoQuality) {
                                Text("4K").tag("2160")
                                Text("1440p").tag("1440")
                                Text("1080p").tag("1080")
                                Text("720p").tag("720")
                                Text("480p").tag("480")
                            }
                            Picker("格式", selection: $options.videoFormat) { ForEach(vFormats, id: \.self) { Text($0.uppercased()).tag($0) } }
                        }
                    }

                    Toggle("這是一個播放清單，下載全部", isOn: $options.downloadPlaylist)
                    Picker("瀏覽器 Cookie (下載會員專屬影片)", selection: $options.browserCookie) {
                        ForEach(cookies, id: \.self) { cookie in
                            Text(cookie).tag(cookie)
                        }
                    }
                }
                if options.browserCookie == "匯入 cookies.txt" {
                    HStack {
                        Text(options.cookiesFilePath.isEmpty ? "尚未選擇 cookies.txt" : options.cookiesFilePath)
                            .font(.caption)
                            .lineLimit(1)

                        Spacer()

                        Button("選擇檔案") {
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.text]

                            if panel.runModal() == .OK,
                               let url = panel.url {
                                options.cookiesFilePath = url.path
                            }
                        }
                    }
                }

                HStack {
                    Button("返回修改 URL") { withAnimation { phase = .input } }
                    Spacer()
                    Button("開始下載") {
                        manager.addTask(options: options, info: videoInfo)
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(20)
        }

        private var previewThumbnailPlaceholder: some View {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .overlay(Image(systemName: "video.fill").foregroundColor(.gray))
        }

        private func autoDetectSource(url: String) {
            if options.source == .auto {
                if url.contains("bilibili.com") {
                    options.source = .bilibili
                } else if url.contains("youtube.com") || url.contains("youtu.be") {
                    options.source = .youtube
                } else {
                    options.source = .auto
                }
            }
        }

        private func parseVideo() {
            isParsing = true
            Task {
                do {
                    let info = try await YTDLPService.fetchInfo(
                        url: options.url,
                        ytdlpPath: manager.ytdlpPath,
                        options: options
                    )
                    await MainActor.run {
                        self.videoInfo = info
                        withAnimation { self.phase = .configure }
                        self.isParsing = false
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.showingErrorAlert = true
                        self.isParsing = false
                    }
                }
            }
        }
    }

    struct SettingsView: View {
        @EnvironmentObject var manager: DownloadManager

        var body: some View {
            Form {
                Section {
                    VStack(alignment: .leading) {
                        Text("核心引擎路徑").font(.headline)
                        Text("應用程式需要這兩個核心元件才能運作。").font(.caption).foregroundColor(.secondary)
                    }.padding(.bottom, 5)

                    HStack {
                        TextField("yt-dlp", text: $manager.ytdlpPath).textFieldStyle(.roundedBorder)
                        Image(systemName: manager.isYtdlpReady ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(manager.isYtdlpReady ? .green : .red)
                    }

                    HStack {
                        TextField("FFmpeg", text: $manager.ffmpegPath).textFieldStyle(.roundedBorder)
                        Image(systemName: manager.isFFmpegReady ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(manager.isYtdlpReady ? .green : .red)
                    }

                    Button("重新檢查依賴狀態") { manager.checkDependencies() }
                        .padding(.top, 5)
                }

                Section("檔案儲存") {
                    HStack {
                        TextField("預設下載目錄", text: $manager.downloadPath).textFieldStyle(.roundedBorder)
                        Button("選擇...") { selectFolder() }
                    }
                }
            }
            .padding(30)
            .navigationTitle("偏好設定")
        }

        private func selectFolder() {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            if panel.runModal() == .OK, let url = panel.url { manager.downloadPath = url.path }
        }
    }


    struct ConverterView: View {
        @State private var selectedFile: URL?
        @State private var isDragging = false
        @State private var outputFormat = "mp3"
        @State private var status = "尚未選擇檔案"

        @EnvironmentObject var manager: DownloadManager

        @State private var isProcessing = false
        @State private var progress: Double = 0
        @State private var logs = ""

        let formats = ["mp3", "m4a", "wav", "mp4", "mkv"]

        var body: some View {
            VStack(spacing: 20) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 50))

                Text("檔案轉檔")
                    .font(.title)

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isDragging ? Color.accentColor : Color.secondary.opacity(0.4),
                            style: StrokeStyle(lineWidth: 2, dash: [8])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isDragging ? Color.accentColor.opacity(0.1) : Color.clear)
                        )

                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 30))

                        Text(selectedFile?.lastPathComponent ?? "將檔案拖到這裡")
                            .foregroundColor(.secondary)

                        Text("或點擊下方按鈕選擇檔案")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                    guard let provider = providers.first else {
                        return false
                    }

                    provider.loadObject(ofClass: URL.self) { url, error in
                        guard let url = url, error == nil else {
                            return
                        }

                        DispatchQueue.main.async {
                            selectedFile = url
                            status = "已選擇：\(url.lastPathComponent)"
                        }
                    }

                    return true
                }

                Button("選擇檔案") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK {
                        selectedFile = panel.url
                        status = "已選擇：\(panel.url?.lastPathComponent ?? "")"
                    }
                }

                Picker("輸出格式", selection: $outputFormat) {
                    ForEach(formats, id: \.self) { format in
                        Text(format.uppercased()).tag(format)
                    }
                }
                .frame(width: 250)

                Button("開始轉檔") {
                    startConversion()
                }
                .disabled(isProcessing || selectedFile == nil)
                .buttonStyle(.borderedProminent)

                if isProcessing {
                    VStack(spacing: 8) {

                        ProgressView(value: progress, total: 100)
                            .progressViewStyle(.linear)

                        HStack {
                            Text("轉檔中")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(String(format: "%.1f%%", progress))
                                .font(.caption.monospacedDigit())
                        }
                    }
                    .frame(width: 300)
                }

                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("轉檔工具")
        }

        private func startConversion() {
            guard let file = selectedFile else {
                status = "錯誤：請先選擇檔案"
                return
            }

            isProcessing = true
            progress = 0
            status = "準備轉檔..."
            logs = ""

            Task {
                do {

                    let output = try await FFmpegService.convert(
                        inputFile: file,
                        outputFormat: outputFormat,
                        ffmpegPath: manager.ffmpegPath,

                        progressHandler: { value in
                            Task { @MainActor in
                                progress = value
                                status = "轉檔中 \(String(format: "%.1f", value))%"
                            }
                        },

                        logHandler: { log in
                            Task { @MainActor in
                                logs += log
                            }
                        }
                    )

                    await MainActor.run {
                        progress = 100
                        isProcessing = false
                        status = "成功：\(output.lastPathComponent)"
                    }

                } catch {

                    await MainActor.run {
                        isProcessing = false
                        status = "失敗：\(error.localizedDescription)"
                    }
                }
            }
        }
    }
}
