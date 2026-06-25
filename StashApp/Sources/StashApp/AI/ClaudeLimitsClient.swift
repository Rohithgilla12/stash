import Foundation

struct UsageWindow: Sendable, Equatable {
    let label: String
    let percentLeft: Double
    let resetsAt: Date?
}

struct ClaudeLimits: Sendable, Equatable {
    let session: UsageWindow?
    let weekly: UsageWindow?
    let sonnet: UsageWindow?
    let opus: UsageWindow?
}

enum ClaudeLimitsError: Error {
    case noToken
    case http(Int)
    case network
    case decode
}

// v1 surfaces session/weekly/sonnet/opus windows; extra_usage (overage spend) is intentionally deferred.
private struct APIResponse: Decodable {
    let five_hour: WindowDTO?
    let seven_day: WindowDTO?
    let seven_day_sonnet: WindowDTO?
    let seven_day_opus: WindowDTO?
}

private struct WindowDTO: Decodable {
    let utilization: Double?
    let resets_at: String?
}

actor ClaudeLimitsClient {

    static nonisolated func decodeLimits(from data: Data, now: Date) throws -> ClaudeLimits {
        let decoder = JSONDecoder()
        let response = try decoder.decode(APIResponse.self, from: data)

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]

        func parseDate(_ str: String?) -> Date? {
            guard let str else { return nil }
            return fractionalFormatter.date(from: str) ?? plainFormatter.date(from: str)
        }

        func makeWindow(label: String, dto: WindowDTO?) -> UsageWindow? {
            guard let dto, let utilization = dto.utilization else { return nil }
            return UsageWindow(
                label: label,
                percentLeft: max(0, 100 - utilization),
                resetsAt: parseDate(dto.resets_at)
            )
        }

        return ClaudeLimits(
            session: makeWindow(label: "Session", dto: response.five_hour),
            weekly: makeWindow(label: "Weekly", dto: response.seven_day),
            sonnet: makeWindow(label: "Sonnet", dto: response.seven_day_sonnet),
            opus: makeWindow(label: "Opus", dto: response.seven_day_opus)
        )
    }

    func fetch() async -> Result<ClaudeLimits, ClaudeLimitsError> {
        guard let token = await acquireToken() else {
            return .failure(.noToken)
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return .failure(.network)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            return .failure(.http(http.statusCode))
        }

        do {
            let limits = try ClaudeLimitsClient.decodeLimits(from: data, now: Date())
            guard limits.session != nil || limits.weekly != nil else {
                return .failure(.decode)
            }
            return .success(limits)
        } catch {
            return .failure(.decode)
        }
    }

    private func acquireToken() async -> String? {
        if let token = await tokenFromKeychain() { return token }
        if let token = tokenFromCredentialsFile() { return token }
        return nil
    }

    private func tokenFromKeychain() async -> String? {
        await withCheckedContinuation { continuation in
            Task.detached(priority: .utility) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
                process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }
                process.waitUntilExit()

                guard process.terminationStatus == 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let jsonString = String(data: outputData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !jsonString.isEmpty
                else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: ClaudeLimitsClient.extractAccessToken(from: jsonString))
            }
        }
    }

    private func tokenFromCredentialsFile() -> String? {
        let credPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        guard let data = try? Data(contentsOf: credPath) else { return nil }
        guard let jsonString = String(data: data, encoding: .utf8) else { return nil }
        return ClaudeLimitsClient.extractAccessToken(from: jsonString)
    }

    private static nonisolated func extractAccessToken(from jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let oauth = obj["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else { return nil }
        return token
    }
}
