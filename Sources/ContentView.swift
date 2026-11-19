import SwiftUI

private let accent = Color(red: 0.45, green: 0.85, blue: 0.70)
private let warning = Color(red: 1.0, green: 0.62, blue: 0.30)

struct ContentView: View {
    @EnvironmentObject private var engine: FocusEngine
    @State private var showHistory = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                header
                Spacer(minLength: 0)
                ring
                Spacer(minLength: 0)
                controls
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
        .tint(accent)
        .sheet(isPresented: $showHistory) {
            HistoryView()
                .environmentObject(engine)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            StatTile(label: "Today", value: formatMinutes(engine.todayTotal))
            StatTile(label: "Streak", value: engine.streak == 1 ? "1 day" : "\(engine.streak) days")
            Button {
                showHistory = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .accessibilityLabel("History")
            .disabled(!isResting)
        }
    }

    // MARK: - Ring

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: progress)
            VStack(spacing: 8) {
                Text(bigText)
                    .font(.system(size: 60, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(caption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(36)
        }
        .frame(maxWidth: 300, maxHeight: 300)
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        switch engine.phase {
        case .idle:
            VStack(spacing: 16) {
                Picker("Goal", selection: $engine.goalMinutes) {
                    ForEach(FocusEngine.goalChoices, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
                BigButton(title: "Start", color: accent) { engine.arm() }
            }
        case .armed:
            BigButton(title: "Cancel", color: Color.white.opacity(0.15), textColor: .white) {
                engine.cancel()
            }
        case .focusing:
            Text("Pick the phone up to stop.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(height: 56)
        case .lifted:
            BigButton(title: "End session", color: Color.white.opacity(0.15), textColor: .white) {
                engine.giveUp()
            }
        case .finished:
            BigButton(title: "Done", color: accent) { engine.dismissResult() }
        }
    }

    // MARK: - Derived display values

    private var isResting: Bool {
        switch engine.phase {
        case .idle, .finished: return true
        case .armed, .focusing, .lifted: return false
        }
    }

    private var progress: CGFloat {
        switch engine.phase {
        case .idle, .armed:
            return 0
        case .focusing, .lifted:
            return CGFloat(min(1, engine.elapsed / engine.goal))
        case .finished(let session):
            return CGFloat(min(1, session.duration / max(1, session.goal)))
        }
    }

    private var ringColor: Color {
        switch engine.phase {
        case .lifted:
            return warning
        case .finished(let session):
            return session.completed ? accent : warning
        case .idle, .armed, .focusing:
            return accent
        }
    }

    private var bigText: String {
        switch engine.phase {
        case .idle:
            return formatClock(engine.goal)
        case .armed:
            return "Flip"
        case .focusing:
            return formatClock(engine.elapsed)
        case .lifted:
            return "\(Int(engine.graceLeft.rounded(.up)))"
        case .finished(let session):
            return formatClock(session.duration)
        }
    }

    private var caption: String {
        switch engine.phase {
        case .idle:
            return "The timer only runs while your phone lies face down."
        case .armed:
            return "Lay the phone face down to begin."
        case .focusing:
            return "Focusing. Goal \(engine.goalMinutes) min."
        case .lifted:
            return "Put it back down to keep your session."
        case .finished(let session):
            return session.completed ? "Goal reached. Nice work." : "Ended before the goal."
        }
    }
}

private struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct BigButton: View {
    let title: String
    let color: Color
    var textColor: Color = .black
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var engine: FocusEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if engine.sessions.isEmpty {
                    Text("No sessions yet. Flip your phone to start one.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(32)
                } else {
                    List {
                        ForEach(Array(engine.sessions.reversed())) { session in
                            HStack {
                                Image(systemName: session.completed ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundStyle(session.completed ? accent : warning)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.start.formatted(date: .abbreviated, time: .shortened))
                                    Text("Goal \(Int(session.goal / 60)) min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formatClock(session.duration))
                                    .monospacedDigit()
                            }
                        }
                        .onDelete { offsets in
                            engine.deleteSessions(at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
