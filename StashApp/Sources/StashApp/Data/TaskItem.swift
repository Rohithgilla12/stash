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
    var dueAt: Int64?
    var orderIndex: Int64?
    var project: String
    var tags: [String]
    var repeatRule: String?
    var subs: [ChecklistItem]
    var source: TaskSource
    var createdAt: Int64
    var updatedAt: Int64

    init(
        id: String,
        title: String,
        done: Bool,
        priority: TaskPriority?,
        due: TaskDue?,
        dueAt: Int64? = nil,
        project: String,
        tags: [String],
        repeatRule: String?,
        subs: [ChecklistItem],
        source: TaskSource,
        createdAt: Int64,
        updatedAt: Int64,
        orderIndex: Int64? = nil
    ) {
        self.id = id
        self.title = title
        self.done = done
        self.priority = priority
        self.due = due
        self.dueAt = dueAt
        self.project = project
        self.tags = tags
        self.repeatRule = repeatRule
        self.subs = subs
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.orderIndex = orderIndex
    }

    static let databaseTableName = "tasks"

    enum CodingKeys: String, CodingKey {
        case id, title, done, priority, due, project, tags
        case dueAt = "due_at"
        case orderIndex = "order_index"
        case repeatRule = "repeat"
        case subs, source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
