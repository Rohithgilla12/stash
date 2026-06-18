import SwiftUI

struct TasksWindow: View {
    @Bindable var model: TasksViewModel

    var body: some View {
        HSplitView {
            TasksSidebar(model: model)
                .frame(minWidth: 160, idealWidth: 180, maxWidth: 220)
            TasksMainPane(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 560, idealWidth: 560, minHeight: 580, idealHeight: 580)
        .background(Tokens.panelFill)
    }
}

private struct TasksSidebar: View {
    @Bindable var model: TasksViewModel

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider()
            List(TaskFilter.allCases, id: \.self, selection: Binding(
                get: { model.filter },
                set: { model.filter = $0 }
            )) { filter in
                SidebarFilterRow(
                    filter: filter,
                    count: countForFilter(filter),
                    isSelected: model.filter == filter
                )
                .tag(filter)
            }
            .listStyle(.sidebar)
        }
    }

    private var sidebarHeader: some View {
        HStack {
            Text("Tasks")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Tokens.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func countForFilter(_ filter: TaskFilter) -> Int {
        model.tasks.filter { TasksViewModel.matchesFilter($0, filter) }.count
    }
}

private struct SidebarFilterRow: View {
    let filter: TaskFilter
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: filterIcon)
                .foregroundStyle(isSelected ? Tokens.accent : Tokens.textTertiary)
                .frame(width: 16)
            Text(filterLabel)
                .font(.system(.callout).weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Tokens.accent : Tokens.textPrimary)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Tokens.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.06), in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    private var filterIcon: String {
        switch filter {
        case .today: "sun.max"
        case .upcoming: "calendar"
        case .all: "tray"
        case .done: "checkmark.circle"
        }
    }

    private var filterLabel: String {
        switch filter {
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .all: "All"
        case .done: "Completed"
        }
    }
}

private struct TasksMainPane: View {
    @Bindable var model: TasksViewModel
    @State private var quickAddText = ""

    private var filterTitle: String {
        switch model.filter {
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .all: "All Tasks"
        case .done: "Completed"
        }
    }

    private var openCount: Int {
        model.visible.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainHeader
            Divider()
            quickAddField
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            Divider()
            taskListContent
        }
    }

    private var mainHeader: some View {
        HStack(spacing: 8) {
            Text(filterTitle)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(Tokens.textPrimary)
            if model.filter != .done {
                Text("\(openCount) open")
                    .font(.system(.callout))
                    .foregroundStyle(Tokens.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var quickAddField: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill").foregroundStyle(Tokens.accent)
            TextField("Add a task…", text: $quickAddText)
                .textFieldStyle(.plain)
                .onSubmit {
                    let trimmed = quickAddText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    quickAddText = ""
                    Task { await model.add(trimmed) }
                }
        }
        .padding(8)
        .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
    }

    @ViewBuilder
    private var taskListContent: some View {
        if model.visible.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(Tokens.textTertiary.opacity(0.5))
                Text("No tasks here")
                    .font(.callout)
                    .foregroundStyle(Tokens.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(model.visible) { task in
                        FullTaskRow(task: task,
                            onToggle: { Task { await model.toggle(task) } },
                            onDelete: { Task { await model.delete(task) } }
                        )
                    }
                }
                .padding(12)
            }
        }
    }
}

private struct FullTaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var subsExpanded = false

    private var doneSubsCount: Int { task.subs.filter(\.done).count }
    private var totalSubs: Int { task.subs.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainRow
            if subsExpanded && !task.subs.isEmpty {
                subsList
            }
        }
        .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private var mainRow: some View {
        HStack(spacing: 8) {
            priorityDot
            checkboxButton
            titleText
            Spacer()
            chipRow
        }
        .padding(8)
    }

    private var priorityDot: some View {
        Circle()
            .fill(priorityColor)
            .frame(width: 7, height: 7)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high: Tokens.priorityHigh
        case .med: Tokens.priorityMed
        case .low: Tokens.priorityLow
        case nil: Tokens.priorityLow
        }
    }

    private var checkboxButton: some View {
        Button(action: onToggle) {
            Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.done ? Tokens.accent : Tokens.textTertiary)
                .font(.system(size: 16))
        }
        .buttonStyle(.plain)
    }

    private var titleText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(task.title)
                .font(.system(.callout))
                .foregroundStyle(task.done ? Tokens.textTertiary : Tokens.textPrimary)
                .strikethrough(task.done, color: Tokens.textTertiary)
                .lineLimit(1)
            if !task.project.isEmpty && task.project != "Inbox" {
                Text(task.project)
                    .font(.system(size: 10))
                    .foregroundStyle(Tokens.textTertiary)
            }
        }
    }

    private var chipRow: some View {
        HStack(spacing: 4) {
            ForEach(task.tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Tokens.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.07), in: Capsule())
            }
            if let rule = task.repeatRule {
                Text("↻ \(rule.capitalized)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Tokens.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.07), in: Capsule())
            }
            if totalSubs > 0 {
                Button {
                    subsExpanded.toggle()
                } label: {
                    Text("☑ \(doneSubsCount)/\(totalSubs)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Tokens.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.07), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            if let due = task.due {
                let isToday = due == .Today
                Text(due.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isToday ? Color.white : Tokens.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isToday ? Tokens.accent : Color.black.opacity(0.08),
                        in: Capsule()
                    )
            }
            if task.source == .claude {
                Text("✶ Claude")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Tokens.accent)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Tokens.accent.opacity(0.1), in: Capsule())
            }
        }
    }

    private var subsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(task.subs.indices, id: \.self) { idx in
                let sub = task.subs[idx]
                HStack(spacing: 6) {
                    Image(systemName: sub.done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(sub.done ? Tokens.accent : Tokens.textTertiary)
                        .font(.system(size: 13))
                    Text(sub.t)
                        .font(.system(.caption))
                        .foregroundStyle(sub.done ? Tokens.textTertiary : Tokens.textPrimary)
                        .strikethrough(sub.done, color: Tokens.textTertiary)
                }
            }
        }
        .padding(.leading, 38)
        .padding(.bottom, 8)
    }
}
