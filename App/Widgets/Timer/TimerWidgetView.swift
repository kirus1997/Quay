import QuayCore
import SwiftUI

struct TimerWidgetView: View {
    @EnvironmentObject private var model: TimerModel
    @State private var showCustom = false
    @State private var hours = 0
    @State private var minutes = 5
    @State private var seconds = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Timer")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(countdownLabel)
                        .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                        .accessibilityLabel("Timer \(countdownLabel)")
                }
                Spacer(minLength: 4)
                iconButton(
                    model.countdown.isRunning ? "pause.fill" : "play.fill",
                    label: model.countdown.isRunning ? "Pause timer" : "Start timer",
                    action: model.toggleCountdown
                )
                iconButton("arrow.counterclockwise", label: "Reset timer", action: model.resetCountdown)
            }

            HStack(spacing: 4) {
                ForEach(TimerPreset.quick) { preset in
                    Button(preset.name) {
                        model.setCountdown(preset.seconds)
                    }
                    .disabled(model.countdown.isRunning)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Button("Custom") {
                    showCustom.toggle()
                }
                .disabled(model.countdown.isRunning)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .background(
                    AnchorPopover(isPresented: $showCustom, size: CGSize(width: 240, height: 168), content: customForm)
                )
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Stopwatch")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(TimeFormatting.stopwatch(model.stopwatch.elapsed(at: model.displayedNow)))
                        .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                }
                Spacer(minLength: 4)
                iconButton(
                    model.stopwatch.isRunning ? "pause.fill" : "play.fill",
                    label: model.stopwatch.isRunning ? "Pause stopwatch" : "Start stopwatch",
                    action: model.toggleStopwatch
                )
                iconButton("arrow.counterclockwise", label: "Reset stopwatch", action: model.resetStopwatch)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 248, alignment: .leading)
        .background(WidgetPlate())
    }

    private var countdownLabel: String {
        if model.countdown.didComplete, !model.countdown.isRunning, model.countdown.remaining == 0 {
            return "Done"
        }
        return TimeFormatting.clock(model.countdown.remaining)
    }

    private var customForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Custom length")
                .font(.headline)
            HStack {
                numberField("Hours", value: $hours, range: 0...23)
                numberField("Minutes", value: $minutes, range: 0...59)
                numberField("Seconds", value: $seconds, range: 0...59)
            }
            Button("Set timer") {
                if let total = DurationInput.seconds(hours: hours, minutes: minutes, seconds: seconds) {
                    model.setCountdown(total)
                    showCustom = false
                }
            }
            .disabled(DurationInput.seconds(hours: hours, minutes: minutes, seconds: seconds) == nil)
        }
        .padding(14)
        .frame(width: 240, alignment: .leading)
    }

    private func numberField(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, value: value, format: .number)
                .frame(width: 52)
                .onChange(of: value.wrappedValue) { _, newValue in
                    value.wrappedValue = min(max(newValue, range.lowerBound), range.upperBound)
                }
        }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 22, height: 18)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }
}
