import SwiftUI

/// Shared context-menu items for moving a task to a new day. Used by both the
/// in-popover Today list and the full Tasks window so the gesture is identical
/// everywhere. `onPickDate` is only offered when a date-picker host is available.
@MainActor @ViewBuilder
func rescheduleMenuItems(
    showsPickDate: Bool,
    onReschedule: @escaping (RescheduleTarget) -> Void,
    onPickDate: @escaping () -> Void
) -> some View {
    Button("Today") { onReschedule(.today) }
    Button("Tomorrow") { onReschedule(.tomorrow) }
    Button("This Weekend") { onReschedule(.weekend) }
    if showsPickDate {
        Button("Pick a Date…") { onPickDate() }
    }
    Divider()
    Button("Clear Date") { onReschedule(.clear) }
}

/// A small graphical date picker presented as a sheet for "Pick a Date…".
struct ReschedulePicker: View {
    let task: TaskItem
    let onPick: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(task: TaskItem, onPick: @escaping (Date) -> Void) {
        self.task = task
        self.onPick = onPick
        let initial = task.dueAt.map { Date(timeIntervalSince1970: Double($0) / 1000) } ?? Date()
        _date = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reschedule")
                .font(.system(.headline, design: .rounded))
            Text(task.title)
                .font(.callout)
                .foregroundStyle(Tokens.textSecondary)
                .lineLimit(2)
            DatePicker("Due date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Set Date") { onPick(date); dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .tint(Tokens.accent)
        .frame(width: 320)
    }
}
