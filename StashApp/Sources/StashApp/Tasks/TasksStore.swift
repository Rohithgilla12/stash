import Foundation
import GRDB

actor TasksStore {
    private let pool: any DatabaseWriter

    init(pool: any DatabaseWriter) {
        self.pool = pool
    }

    func all() throws -> [TaskItem] {
        try pool.read { db in
            try TaskItem.order(Column("created_at").desc, Column("id").desc).fetchAll(db)
        }
    }

    func upsert(_ task: TaskItem) throws {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        var updated = task
        updated.updatedAt = now
        try pool.write { try updated.save($0) }
    }

    func setDone(id: String, done: Bool) throws {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        try pool.write { db in
            try db.execute(
                sql: "UPDATE tasks SET done = ?, updated_at = ? WHERE id = ?",
                arguments: [done, now, id]
            )
        }
    }

    func delete(id: String) throws {
        try pool.write { try TaskItem.deleteOne($0, key: id) }
    }

    @discardableResult
    func create(
        title: String,
        due: TaskDue,
        now: Int64,
        id: String,
        dueAt: Int64? = nil,
        priority: TaskPriority? = nil,
        repeatRule: String? = nil
    ) throws -> TaskItem {
        let task = TaskItem(
            id: id,
            title: title,
            done: false,
            priority: priority,
            due: due,
            dueAt: dueAt,
            project: "Inbox",
            tags: [],
            repeatRule: repeatRule,
            subs: [],
            source: .you,
            createdAt: now,
            updatedAt: now
        )
        try upsert(task)
        return task
    }
}
