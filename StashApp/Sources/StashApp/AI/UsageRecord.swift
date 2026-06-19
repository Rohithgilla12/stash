import Foundation

struct UsageRecord: Sendable, Equatable {
    let timestamp: Date
    let sessionId: String
    let repoPath: String
    let branch: String?
    let model: String
    let inputTokens: Int
    let outputTokens: Int
}
