import Foundation

struct UsageRecord: Sendable, Equatable {
    let timestamp: Date
    let sessionId: String
    let repoPath: String
    let branch: String?
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int

    var totalTokens: Int { inputTokens + cacheCreationTokens + cacheReadTokens + outputTokens }
}
