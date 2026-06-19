import SwiftUI

struct FocusTab: View {
    @Bindable var timer: PomodoroTimer

    private enum Preset: String, CaseIterable {
        case standard = "25 / 5"
        case extended = "50 / 10"
    }

    @State private var preset: Preset = .standard

    private var totalDuration: Double {
        Double(timer.phaseDuration)
    }

    private var fraction: Double {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - Double(timer.remaining) / totalDuration
    }

    var body: some View {
        VStack(spacing: Space.lg) {
            Spacer(minLength: Space.sm)

            Text(timer.phase.label)
                .font(.rounded(13, .semibold))
                .foregroundStyle(Tokens.textSecondary)

            ZStack {
                Circle()
                    .stroke(Tokens.hairline, lineWidth: 8)

                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Tokens.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: fraction)

                Text(timer.display)
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Tokens.textPrimary)
            }
            .frame(width: 180, height: 180)

            HStack(spacing: Space.sm) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < (timer.completedFocusSessions % 4) ? Tokens.accent : Tokens.hairline)
                        .frame(width: 8, height: 8)
                }
            }

            HStack(spacing: Space.md) {
                Button { timer.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(Tokens.textSecondary)
                }
                .buttonStyle(.plain)

                Button {
                    if timer.isRunning { timer.pause() } else { timer.start() }
                } label: {
                    Text(timer.isRunning ? "Pause" : "Start")
                        .font(.rounded(15, .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 100, height: 38)
                        .background(Tokens.accent, in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
                }
                .buttonStyle(.plain)

                Button { timer.skip() } label: {
                    Image(systemName: "forward.end.fill")
                        .foregroundStyle(Tokens.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Picker("Duration", selection: $preset) {
                ForEach(Preset.allCases, id: \.self) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 160)
            .onChange(of: preset) { _, newValue in
                switch newValue {
                case .standard:
                    timer.focusDuration = 25 * 60
                    timer.shortBreakDuration = 5 * 60
                case .extended:
                    timer.focusDuration = 50 * 60
                    timer.shortBreakDuration = 10 * 60
                }
                timer.reset()
            }

            Spacer(minLength: Space.sm)
        }
        .padding(.horizontal, Space.lg)
    }
}
