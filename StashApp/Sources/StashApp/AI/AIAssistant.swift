import Foundation

@MainActor
@Observable
final class AIAssistant {
    var isRunning = false
    var response = ""
    var errorText: String?

    static var resolvedPath: String?

    func run(_ prompt: String) async {
        guard !prompt.isEmpty, !isRunning else { return }
        isRunning = true
        response = ""
        errorText = nil

        if Self.resolvedPath == nil {
            let found = await resolveClaudePath()
            if found.isEmpty {
                errorText = "Claude CLI not found. Install Claude Code."
                isRunning = false
                return
            }
            Self.resolvedPath = found
        }

        guard let claudePath = Self.resolvedPath else {
            errorText = "Claude CLI not found. Install Claude Code."
            isRunning = false
            return
        }

        let output: (String, String) = await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let proc = Process()
                let outPipe = Pipe()
                let errPipe = Pipe()
                proc.executableURL = URL(fileURLWithPath: claudePath)
                proc.arguments = ["-p", prompt]
                proc.standardOutput = outPipe
                proc.standardError = errPipe

                do {
                    try proc.run()
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    proc.waitUntilExit()
                    let exitCode = proc.terminationStatus
                    let outStr = String(data: outData, encoding: .utf8) ?? ""
                    if exitCode != 0 && outStr.isEmpty {
                        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                        let errStr = String(data: errData, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        cont.resume(returning: ("", errStr.isEmpty ? "claude exited with code \(exitCode)" : errStr))
                    } else {
                        cont.resume(returning: (outStr, ""))
                    }
                } catch {
                    cont.resume(returning: ("", error.localizedDescription))
                }
            }
        }

        // The CLI may report credit/auth problems on stdout (exit 0) or stderr —
        // map the known ones to a friendly, actionable message.
        if let friendly = Self.friendlyError(in: output.0 + "\n" + output.1) {
            self.errorText = friendly
            self.response = ""
        } else if output.1.isEmpty {
            self.response = output.0
        } else {
            self.errorText = output.1
        }
        self.isRunning = false
    }

    private static func friendlyError(in text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("credit balance") {
            return "Anthropic API credits are low. Add credits at console.anthropic.com, "
                + "or remove ANTHROPIC_API_KEY from your shell to use your Claude subscription instead."
        }
        if lower.contains("invalid api key") || lower.contains("unauthorized")
            || lower.contains("not logged in") || lower.contains("authentication_error") {
            return "Claude isn't authenticated. Run `claude` in a terminal to log in "
                + "(or set a valid ANTHROPIC_API_KEY)."
        }
        return nil
    }

    func cancel() {
        isRunning = false
    }

    private func resolveClaudePath() async -> String {
        return await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let proc = Process()
                let pipe = Pipe()
                proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
                proc.arguments = ["-lc", "command -v claude"]
                proc.standardOutput = pipe
                proc.standardError = Pipe()
                do {
                    try proc.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    proc.waitUntilExit()
                    let path = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    cont.resume(returning: path)
                } catch {
                    cont.resume(returning: "")
                }
            }
        }
    }
}
