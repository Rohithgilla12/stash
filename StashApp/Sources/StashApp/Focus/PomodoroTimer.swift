import Foundation
import AppKit

@MainActor @Observable final class PomodoroTimer {
    enum Phase {
        case focus, shortBreak, longBreak
        var label: String {
            switch self {
            case .focus: "Focus"
            case .shortBreak: "Break"
            case .longBreak: "Long Break"
            }
        }
    }

    var phase: Phase = .focus
    var remaining: Int = 25 * 60
    var isRunning: Bool = false
    var completedFocusSessions: Int = 0

    var focusDuration: Int = 25 * 60
    var shortBreakDuration: Int = 5 * 60
    var longBreakDuration: Int = 15 * 60

    nonisolated(unsafe) private var ticker: Task<Void, Never>?

    var display: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    var menuBarTitle: String {
        isRunning ? "🍅 \(display)" : ""
    }

    var phaseDuration: Int {
        switch phase {
        case .focus: focusDuration
        case .shortBreak: shortBreakDuration
        case .longBreak: longBreakDuration
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        ticker = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.isRunning else { break }
                self.tick()
            }
        }
    }

    func pause() {
        isRunning = false
        ticker?.cancel()
        ticker = nil
    }

    func reset() {
        pause()
        remaining = duration(for: phase)
    }

    func skip() {
        let wasRunning = isRunning
        pause()
        advancePhase()
        if wasRunning { start() }
    }

    private func tick() {
        if remaining > 0 {
            remaining -= 1
        } else {
            NSSound(named: "Glass")?.play()
            if phase == .focus { completedFocusSessions += 1 }
            advancePhase()
            isRunning = false
            ticker?.cancel()
            ticker = nil
        }
    }

    private func advancePhase() {
        switch phase {
        case .focus:
            phase = (completedFocusSessions % 4 == 0 && completedFocusSessions > 0)
                ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            phase = .focus
        }
        remaining = duration(for: phase)
    }

    private func duration(for phase: Phase) -> Int {
        switch phase {
        case .focus: focusDuration
        case .shortBreak: shortBreakDuration
        case .longBreak: longBreakDuration
        }
    }

    deinit {
        ticker?.cancel()
    }
}
