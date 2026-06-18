import GRDB
import Foundation

enum TaskPriority: String, Codable, Sendable { case high, med, low }
enum TaskDue: String, Codable, Sendable { case Today, Tomorrow, Upcoming }
enum TaskSource: String, Codable, Sendable { case you, claude }

struct TaskItem: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable, Equatable {
    var id: String
    var title: String
    var done: Bool
    var priority: TaskPriority?
    var due: TaskDue?
    var project: String
    var tags: [String]
    var repeatRule: String?
    var subs: [ChecklistItem]
    var source: TaskSource
    var createdAt: Int64
    var updatedAt: Int64

    static let databaseTableName = "tasks"

    enum CodingKeys: String, CodingKey {
        case id, title, done, priority, due, project, tags
        case repeatRule = "repeat"
        case subs, source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
