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
        try pool.write { try task.save($0) }
    }

    func setDone(id: String, done: Bool) throws {
        try pool.write { db in
            try db.execute(
                sql: "UPDATE tasks SET done = ? WHERE id = ?",
                arguments: [done, id]
            )
        }
    }

    func delete(id: String) throws {
        try pool.write { try TaskItem.deleteOne($0, key: id) }
    }

    @discardableResult
    func create(title: String, due: TaskDue, now: Int64, id: String) throws -> TaskItem {
        let task = TaskItem(
            id: id,
            title: title,
            done: false,
            priority: nil,
            due: due,
            project: "Inbox",
            tags: [],
            repeatRule: nil,
            subs: [],
            source: .you,
            createdAt: now,
            updatedAt: now
        )
        try upsert(task)
        return task
    }
}
