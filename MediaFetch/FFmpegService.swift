import Foundation

class FFmpegService {

    static func convert(
        inputFile: URL,
        outputFormat: String,
        ffmpegPath: String,
        progressHandler: @escaping (Double) -> Void,
        logHandler: @escaping (String) -> Void
    ) async throws -> URL {

        let outputDirectory = inputFile.deletingLastPathComponent()

        let outputFileName =
            inputFile
                .deletingPathExtension()
                .appendingPathExtension(outputFormat)
                .lastPathComponent

        let outputFile = outputDirectory.appendingPathComponent(outputFileName)

        return try await Task.detached(priority: .userInitiated) {

            // MARK: - 先取得影片總長度

            let durationProcess = Process()
            let durationPipe = Pipe()

            durationProcess.executableURL = URL(fileURLWithPath: ffmpegPath)

            durationProcess.arguments = [
                "-i", inputFile.path
            ]

            durationProcess.standardOutput = durationPipe
            durationProcess.standardError = durationPipe

            try durationProcess.run()

            let durationData =
                try durationPipe.fileHandleForReading.readToEnd() ?? Data()

            durationProcess.waitUntilExit()

            let durationOutput =
                String(data: durationData, encoding: .utf8) ?? ""

            // FFmpeg 通常會輸出：
            // Duration: 00:03:42.15
            let duration = parseDuration(from: durationOutput)

            // MARK: - 正式轉檔

            let process = Process()

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: ffmpegPath)

            process.arguments = [
                "-i", inputFile.path,
                "-y",

                // 讓 FFmpeg 輸出機器可讀的進度
                "-progress", "pipe:1",
                "-nostats",

                outputFile.path
            ]

            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // MARK: - Progress Output

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in

                let data = handle.availableData

                guard !data.isEmpty,
                      let output = String(data: data, encoding: .utf8)
                else {
                    return
                }

                // FFmpeg 會輸出：
                //
                // frame=123
                // fps=60
                // out_time_ms=1234567
                // speed=1.2x
                // progress=continue

                let lines = output.components(separatedBy: .newlines)

                for line in lines {

                    if line.hasPrefix("out_time_ms=") {

                        let valueString = line
                            .replacingOccurrences(of: "out_time_ms=", with: "")

                        if let microseconds = Double(valueString),
                           let duration = duration,
                           duration > 0 {

                            let currentSeconds = microseconds / 1_000_000.0

                            let progress =
                                min(
                                    max(currentSeconds / duration, 0),
                                    1
                                ) * 100

                            progressHandler(progress)
                        }
                    }

                    if line == "progress=end" {
                        progressHandler(100)
                    }
                }
            }

            // MARK: - Error / Log Output

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in

                let data = handle.availableData

                guard !data.isEmpty,
                      let output = String(data: data, encoding: .utf8)
                else {
                    return
                }

                logHandler(output)
            }

            try process.run()

            process.waitUntilExit()

            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil

            if process.terminationStatus != 0 {

                throw NSError(
                    domain: "FFmpegError",
                    code: Int(process.terminationStatus),
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "轉檔失敗 (Exit Code: \(process.terminationStatus))"
                    ]
                )
            }

            progressHandler(100)

            return outputFile
        }.value
    }

    // MARK: - 解析影片長度

    private static func parseDuration(from output: String) -> Double? {

        let pattern =
            #"Duration:\s*(\d{2}):(\d{2}):(\d{2}(?:\.\d+)?)"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: output,
                range: NSRange(output.startIndex..., in: output)
              )
        else {
            return nil
        }

        guard
            let hourRange = Range(match.range(at: 1), in: output),
            let minuteRange = Range(match.range(at: 2), in: output),
            let secondRange = Range(match.range(at: 3), in: output)
        else {
            return nil
        }

        let hours = Double(output[hourRange]) ?? 0
        let minutes = Double(output[minuteRange]) ?? 0
        let seconds = Double(output[secondRange]) ?? 0

        return hours * 3600 + minutes * 60 + seconds
    }
}
