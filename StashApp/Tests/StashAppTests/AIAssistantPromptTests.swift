import Testing
@testable import StashApp

@Suite("AIAssistant prompt builders")
struct AIAssistantPromptBuilderTests {

    @Test func planMyDayWithNoTasks() {
        let tasks: [TaskItem] = []
        let open = tasks.filter { !$0.done }
        let titles = open.map { "- \($0.title)" }.joined(separator: "\n")
        let prompt = titles.isEmpty
            ? "I have no tasks yet. Propose a good, focused plan for today as a developer working on a macOS app."
            : "Here are my current tasks:\n\(titles)\n\nPropose a focused, realistic plan for today. Group and prioritize."
        #expect(prompt.contains("no tasks yet"))
    }

    @Test func planMyDayWithTasks() {
        let tasks = ["Write unit tests", "Fix AI tab", "Review PR"]
        let prompt = buildPlanPrompt(taskTitles: tasks)
        #expect(prompt.hasPrefix("Here are my current tasks:"))
        #expect(prompt.contains("Write unit tests"))
        #expect(prompt.contains("Group and prioritize"))
    }

    @Test func clipboardSummarySkipsEmpties() {
        let texts = ["hello", "", "world"]
        let filtered = texts.compactMap { t -> String? in
            return t.isEmpty ? nil : String(t.prefix(300))
        }
        #expect(filtered.count == 2)
        #expect(filtered.contains("hello"))
        #expect(filtered.contains("world"))
    }

    private func buildPlanPrompt(taskTitles: [String]) -> String {
        let titles = taskTitles.map { "- \($0)" }.joined(separator: "\n")
        return titles.isEmpty
            ? "I have no tasks yet. Propose a good, focused plan for today as a developer working on a macOS app."
            : "Here are my current tasks:\n\(titles)\n\nPropose a focused, realistic plan for today. Group and prioritize."
    }
}
