import Testing
@testable import StashApp

@MainActor
struct PomodoroTimerTests {
    @Test func testDisplayFormatsMmSs() {
        let t = PomodoroTimer()
        t.remaining = 1500
        #expect(t.display == "25:00")
        t.remaining = 61
        #expect(t.display == "01:01")
        t.remaining = 0
        #expect(t.display == "00:00")
    }

    @Test func testMenuBarTitleWhenRunning() {
        let t = PomodoroTimer()
        t.remaining = 1500
        t.isRunning = true
        #expect(t.menuBarTitle == "🍅 25:00")
    }

    @Test func testMenuBarTitleWhenStopped() {
        let t = PomodoroTimer()
        #expect(t.menuBarTitle == "")
    }

    @Test func testSkipFromFocusGoesToShortBreak() {
        let t = PomodoroTimer()
        // completedFocusSessions == 0, phase == .focus
        t.skip()
        #expect(t.phase == .shortBreak)
        #expect(t.remaining == t.shortBreakDuration)
    }

    @Test func testSkipToLongBreakAfterFourSessions() {
        let t = PomodoroTimer()
        t.completedFocusSessions = 4  // multiple of 4, >0
        t.phase = .focus
        t.skip()
        #expect(t.phase == .longBreak)
        #expect(t.remaining == t.longBreakDuration)
    }

    @Test func testSkipFromBreakGoesToFocus() {
        let t = PomodoroTimer()
        t.phase = .shortBreak
        t.skip()
        #expect(t.phase == .focus)
        #expect(t.remaining == t.focusDuration)
    }

    @Test func testResetRestoresDurationAndStops() {
        let t = PomodoroTimer()
        t.remaining = 10
        t.isRunning = true
        // Don't actually call start() (that spawns async task); just verify reset logic:
        t.isRunning = true
        t.reset()
        #expect(t.remaining == t.focusDuration)
        #expect(!t.isRunning)
    }

    @Test func testPhaseDurationMatchesFocusDuration() {
        let t = PomodoroTimer()
        #expect(t.phaseDuration == 25 * 60)
        t.phase = .shortBreak
        #expect(t.phaseDuration == 5 * 60)
        t.phase = .longBreak
        #expect(t.phaseDuration == 15 * 60)
    }
}
