import GRDB

actor NotesStore {
    private let pool: any DatabaseWriter

    init(pool: any DatabaseWriter) {
        self.pool = pool
    }

    func all() throws -> [Note] {
        try pool.read { db in
            try Note.order(Column("updated_at").desc, Column("id").desc).fetchAll(db)
        }
    }

    func upsert(_ note: Note) throws {
        try pool.write { try note.save($0) }
    }

    func delete(id: String) throws {
        try pool.write { try Note.deleteOne($0, key: id) }
    }

    @discardableResult
    func create(now: Int64, id: String) throws -> Note {
        let note = Note(
            id: id,
            title: "",
            body: "",
            color: "#fdf0c2",
            accent: "#c8642f",
            kind: .text,
            items: [],
            onDesktop: false,
            createdAt: now,
            updatedAt: now
        )
        try upsert(note)
        return note
    }
}
