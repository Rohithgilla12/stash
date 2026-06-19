import SwiftUI

struct TasksWindow: View {
    @Bindable var model: TasksViewModel

    var body: some View {
        NavigationSplitView {
            List(TaskFilter.allCases, id: \.self, selection: Binding(
                get: { model.filter as TaskFilter? },
                set: { model.filter = $0 ?? .all }
            )) { filter in
                SidebarFilterRow(
                    filter: filter,
                    count: countForFilter(filter),
                    isSelected: model.filter == filter
                )
                .tag(filter)
            }
            .listStyle(.sidebar)
            .tint(Tokens.accent)
            .navigationTitle("Tasks")
        } detail: {
            TasksMainPane(model: model)
        }
        .tint(Tokens.accent)
        .frame(minWidth: 560, idealWidth: 560, minHeight: 580, idealHeight: 580)
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
                .foregroundStyle(isSelected ? Tokens.accent : Color(nsColor: .tertiaryLabelColor))
                .frame(width: 16)
            Text(filterLabel)
                .font(.system(.callout).weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Tokens.accent : Color.primary)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
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
                .foregroundStyle(.primary)
            if model.filter != .done {
                Text("\(openCount) open")
                    .font(.system(.callout))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
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
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor).opacity(0.5))
                Text("No tasks here")
                    .font(.callout)
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
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
                .foregroundStyle(task.done ? Tokens.accent : Color(nsColor: .tertiaryLabelColor))
                .font(.system(size: 16))
        }
        .buttonStyle(.plain)
    }

    private var titleText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(task.title)
                .font(.system(.callout))
                .foregroundStyle(task.done ? Color(nsColor: .tertiaryLabelColor) : Color.primary)
                .strikethrough(task.done, color: Color(nsColor: .tertiaryLabelColor))
                .lineLimit(1)
            if !task.project.isEmpty && task.project != "Inbox" {
                Text(task.project)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            }
        }
    }

    private var chipRow: some View {
        HStack(spacing: 4) {
            ForEach(task.tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.07), in: Capsule())
            }
            if let rule = task.repeatRule {
                Text("↻ \(rule.capitalized)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
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
                    .foregroundStyle(isToday ? Color.white : .secondary)
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
                        .foregroundStyle(sub.done ? Tokens.accent : Color(nsColor: .tertiaryLabelColor))
                        .font(.system(size: 13))
                    Text(sub.t)
                        .font(.system(.caption))
                        .foregroundStyle(sub.done ? Color(nsColor: .tertiaryLabelColor) : Color.primary)
                        .strikethrough(sub.done, color: Color(nsColor: .tertiaryLabelColor))
                }
            }
        }
        .padding(.leading, 38)
        .padding(.bottom, 8)
    }
}
