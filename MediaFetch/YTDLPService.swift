//
//  YTDLPService.swift
//  MediaFetch
//
//  Created by 小睡睡 on 2026/7/8.
import Foundation

class YTDLPService {

    static func fetchInfo(url: String, ytdlpPath: String, options: DownloadOptions) async throws -> YTDLPVideoInfo {
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let outPipe = Pipe()
            let errPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: ytdlpPath)
            process.environment = [
                "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            ]
            var arguments = ["--dump-json", "--no-playlist", "--no-warnings"]
            arguments.append(contentsOf: cookieArguments(for: options))
            arguments.append(url)
            process.arguments = arguments
            process.standardOutput = outPipe
            process.standardError = errPipe

            try process.run()

            let outData = try outPipe.fileHandleForReading.readToEnd() ?? Data()
            let errData = try errPipe.fileHandleForReading.readToEnd() ?? Data()

            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errString = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知錯誤"
                throw NSError(domain: "YTDLPError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errString])
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            do {
                return try decoder.decode(YTDLPVideoInfo.self, from: outData)
            } catch {
                throw NSError(domain: "YTDLPJSONError", code: -1, userInfo: [NSLocalizedDescriptionKey: "JSON 解析失敗：\(error.localizedDescription)"])
            }
        }.value
    }

    static func startDownload(task: DownloadTask, options: DownloadOptions, destination: URL, ytdlpPath: String, ffmpegPath: String, archivePath: String? = nil) async throws {

        // 使用 detached task 將所有阻塞操作移出主執行緒
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let outPipe = Pipe()
            let errPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: ytdlpPath)
            process.environment = [
                "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            ]
            var arguments: [String] = [
                "--newline",
                "--js-runtimes", "deno"
            ]

            if options.isAudioOnly {
                arguments.append(contentsOf: [
                    "-x",
                    "--audio-format", options.audioFormat,
                    "--audio-quality", options.audioQuality
                ])
            } else {
                let vq = options.videoQuality
                let formatStr = "bestvideo[height<=\(vq)]+bestaudio/best[height<=\(vq)]"
                arguments.append(contentsOf: ["-f", formatStr, "--merge-output-format", options.videoFormat])
            }

            arguments.append(contentsOf: cookieArguments(for: options))

            if options.downloadPlaylist {
                arguments.append("--yes-playlist")
            } else {
                arguments.append("--no-playlist")
            }

            if let archive = archivePath {
                arguments.append(contentsOf: ["--download-archive", archive])
            }

            let outputTemplate = destination.appendingPathComponent("%(title)s.%(ext)s").path
            arguments.append(contentsOf: ["-o", outputTemplate, "--ffmpeg-location", ffmpegPath, options.url])

            process.arguments = arguments
            process.standardOutput = outPipe
            process.standardError = errPipe

            await MainActor.run {
                task.process = process
                task.state = .downloading
                task.log = "=== 開始下載 ===\n執行指令： yt-dlp \(arguments.joined(separator: " "))\n\n"
            }

            outPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    task.appendLog(output)
                    Self.parseLog(output: output, task: task)
                }
            }

            errPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    task.appendLog(output)
                }
            }

            do {
                try process.run()
                process.waitUntilExit() // 現在在背景執行緒，不會阻塞 UI

                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil

                await MainActor.run {
                    if task.state == .cancelled { return }

                    if process.terminationStatus == 0 {
                        task.state = .completed
                        task.progress = 100.0
                        task.appendLog("\n=== 下載順利完成 ===")
                    } else {
                        task.state = .failed
                        task.appendLog("\n=== 下載失敗 (Exit Code: \(process.terminationStatus)) ===")
                    }
                }
            } catch {
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                await MainActor.run {
                    task.state = .failed
                    task.appendLog("\n=== 發生嚴重例外錯誤 ===\n\(error.localizedDescription)")
                }
                throw error
            }
        }.value
    }

    private static func cookieArguments(for options: DownloadOptions) -> [String] {
        if options.browserCookie == "匯入 cookies.txt" {
            guard !options.cookiesFilePath.isEmpty else {
                return []
            }
            return ["--cookies", options.cookiesFilePath]
        }

        if options.browserCookie != "None" {
            return ["--cookies-from-browser", options.browserCookie.lowercased()]
        }

        return []
    }
    private static func parseLog(output: String, task: DownloadTask) {
        guard !output.contains("ERROR:") && !output.contains("WARNING:") else { return }

        if let pMatch = output.range(of: #"(\d+(?:\.\d+)?)%"#, options: .regularExpression) {
            if let val = Double(String(output[pMatch]).replacingOccurrences(of: "%", with: "")) {
                task.progress = val
            }
        }
        if let sMatch = output.range(of: #"at\s+([0-9a-zA-Z./]+)"#, options: .regularExpression) {
            task.speed = String(output[sMatch]).replacingOccurrences(of: "at", with: "").trimmingCharacters(in: .whitespaces)
        }
        if let eMatch = output.range(of: #"ETA\s+([0-9:]+)"#, options: .regularExpression) {
            task.eta = String(output[eMatch]).replacingOccurrences(of: "ETA", with: "").trimmingCharacters(in: .whitespaces)
        }
        if output.contains("Merging formats") || output.contains("Extracting audio") || output.contains("Fixing") {
            task.state = .processing
            task.progress = 100.0
        }
    }
}
