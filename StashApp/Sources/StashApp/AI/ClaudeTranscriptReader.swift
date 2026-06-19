import Foundation

struct ClaudeTranscriptReader: Sendable {
    let baseDir: URL

    init(baseDir: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")) {
        self.baseDir = baseDir
    }

    func read(modifiedWithin: TimeInterval, now: Date) -> [UsageRecord] {
        let fm = FileManager.default
        let cutoff = now.addingTimeInterval(-modifiedWithin)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let projectDirs = try? fm.contentsOfDirectory(
            at: baseDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var records: [UsageRecord] = []

        for projectDir in projectDirs {
            guard (try? projectDir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            else { continue }

            guard let jsonlFiles = try? fm.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in jsonlFiles where file.pathExtension == "jsonl" {
                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let mtime = attrs.contentModificationDate,
                      mtime >= cutoff
                else { continue }

                guard let data = try? Data(contentsOf: file),
                      let text = String(data: data, encoding: .utf8)
                else { continue }

                for line in text.components(separatedBy: "\n") {
                    guard line.contains("\"usage\"") else { continue }
                    guard let lineData = line.data(using: .utf8),
                          let obj = (try? JSONSerialization.jsonObject(with: lineData)) as? [String: Any]
                    else { continue }

                    guard let timestampStr = obj["timestamp"] as? String,
                          let timestamp = formatter.date(from: timestampStr)
                    else { continue }

                    let sessionId = obj["sessionId"] as? String ?? ""
                    let cwd = obj["cwd"] as? String ?? ""
                    let gitBranch = obj["gitBranch"] as? String

                    guard let message = obj["message"] as? [String: Any],
                          let usageDict = message["usage"] as? [String: Any]
                    else { continue }

                    let modelStr = message["model"] as? String ?? ""
                    let inputTokens = usageDict["input_tokens"] as? Int ?? 0
                    let cacheCreation = usageDict["cache_creation_input_tokens"] as? Int ?? 0
                    let cacheRead = usageDict["cache_read_input_tokens"] as? Int ?? 0
                    let outputTokens = usageDict["output_tokens"] as? Int ?? 0

                    records.append(UsageRecord(
                        timestamp: timestamp,
                        sessionId: sessionId,
                        repoPath: cwd,
                        branch: gitBranch,
                        model: modelStr,
                        inputTokens: inputTokens + cacheCreation + cacheRead,
                        outputTokens: outputTokens
                    ))
                }
            }
        }

        return records
    }
}
