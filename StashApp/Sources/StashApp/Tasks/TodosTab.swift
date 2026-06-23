import SwiftUI

struct TodosTab: View {
    @Bindable var model: TasksViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var quickAddText = ""

    private var todayCount: Int {
        model.tasks.filter { TasksViewModel.matchesFilter($0, .today) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            quickAddField
            sectionHeader
            taskList
            actionButtons
        }
    }

    private var quickAddField: some View {
        VStack(alignment: .leading, spacing: 4) {
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
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
            Text(#"Try: "pay rent fri 9am !high"  ·  "standup every weekday 9am""#)
                .font(.system(.caption2))
                .foregroundStyle(Tokens.textTertiary)
                .padding(.horizontal, 2)
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text("Today · \(todayCount) open")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Tokens.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var taskList: some View {
        let todayTasks = model.tasks.filter { TasksViewModel.matchesFilter($0, .today) }
        if todayTasks.isEmpty {
            Text("No tasks for today")
                .font(.callout)
                .foregroundStyle(Tokens.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else {
            ForEach(todayTasks) { task in
                TaskRowView(task: task) {
                    Task { await model.toggle(task) }
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                openWindow.openActivating(id: "tasks")
            } label: {
                HStack(spacing: 4) {
                    Text("Open all tasks")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                    Text("↗")
                        .font(.caption)
                }
                .foregroundStyle(Tokens.accent)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {} label: {
                HStack(spacing: 4) {
                    Text("✦")
                        .font(.caption2)
                    Text("Generate my day")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                }
                .foregroundStyle(Tokens.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Ask Claude via MCP to plan your day")
        }
        .padding(.top, 4)
    }
}

struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            priorityDot
            checkboxButton
            titleText
            Spacer()
            if task.repeatRule != nil {
                Text("↻")
                    .font(.system(size: 10))
                    .foregroundStyle(Tokens.textSecondary)
            }
            duePill
            if task.source == .claude {
                claudeBadge
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
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
        case nil: Color.clear
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
        Text(task.title)
            .font(.system(.callout))
            .foregroundStyle(task.done ? Tokens.textTertiary : Tokens.textPrimary)
            .strikethrough(task.done, color: Tokens.textTertiary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var duePill: some View {
        if let dueAt = task.dueAt {
            let date = Date(timeIntervalSince1970: Double(dueAt) / 1000)
            let label = TaskQuickParse.formatDue(date, now: Date())
            let isToday = Calendar.current.isDateInToday(date)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isToday ? Color.white : Tokens.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    isToday ? Tokens.accent : Color.primary.opacity(0.10),
                    in: Capsule()
                )
        } else if let due = task.due {
            let isToday = due == .Today
            Text(due.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isToday ? Color.white : Tokens.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    isToday ? Tokens.accent : Color.primary.opacity(0.10),
                    in: Capsule()
                )
        }
    }

    private var claudeBadge: some View {
        Text("✶ Claude")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Tokens.accent)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Tokens.accent.opacity(0.1), in: Capsule())
    }
}

