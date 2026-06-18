import GRDB
import Foundation

@MainActor
@Observable
final class NotesViewModel {
    var notes: [Note] = []
    var selectedId: String?

    private let db: StashDatabase
    private let store: NotesStore
    private var observationTask: Task<Void, Never>?

    init(db: StashDatabase, store: NotesStore) {
        self.db = db
        self.store = store
    }

    var selected: Note? { notes.first { $0.id == selectedId } }

    func startObserving() {
        guard observationTask == nil else { return }
        let observation = ValueObservation.tracking { db in
            try Note.order(Column("updated_at").desc, Column("id").desc).fetchAll(db)
        }
        observationTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await rows in observation.values(in: self.db.pool) {
                    self.notes = rows
                }
            } catch {
                #if DEBUG
                print("NotesViewModel observation error:", error)
                #endif
            }
        }
    }

    func newNote() async -> Note? {
        let id = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return try? await store.create(now: now, id: id)
    }

    func update(_ n: Note) async {
        try? await store.upsert(n)
    }

    func delete(_ n: Note) async {
        try? await store.delete(id: n.id)
    }
}
