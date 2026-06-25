import Foundation

struct UsageRecord: Sendable, Equatable {
    let timestamp: Date
    let sessionId: String
    let repoPath: String
    let branch: String?
    let model: String
    let rawInputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let outputTokens: Int

    var inputTokens: Int { rawInputTokens + cacheCreationTokens + cacheReadTokens }
    var totalTokens: Int { inputTokens + outputTokens }
}
