import AudioToolbox
import CoreMotion
import Foundation
import UIKit

struct Session: Codable, Identifiable, Equatable {
    var id = UUID()
    let start: Date
    let duration: TimeInterval
    let goal: TimeInterval

    var completed: Bool { duration >= goal }
}

/// Drives a focus session: the timer only runs while the phone lies face down.
final class FocusEngine: ObservableObject {
    enum Phase: Equatable {
        case idle
        case armed
        case focusing
        case lifted
        case finished(Session)
    }

    static let goalChoices = [15, 25, 45, 60]
    static let graceSeconds: TimeInterval = 10

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var graceLeft: TimeInterval = 0
    @Published private(set) var sessions: [Session] = []
    @Published var goalMinutes: Int {
        didSet { UserDefaults.standard.set(goalMinutes, forKey: Keys.goal) }
    }

    private enum Keys {
        static let goal = "goalMinutes"
        static let sessions = "sessions"
    }

    private let motion = CMMotionManager()
    private var ticker: Timer?
    private var gravityZ: Double = -1
    private var faceDownSince: Date?
    private var startDate: Date?
    private var liftedAt: Date?
    private var goalReached = false

    var goal: TimeInterval { TimeInterval(goalMinutes * 60) }

    init() {
        let savedGoal = UserDefaults.standard.integer(forKey: Keys.goal)
        goalMinutes = FocusEngine.goalChoices.contains(savedGoal) ? savedGoal : 25
        if let data = UserDefaults.standard.data(forKey: Keys.sessions),
           let decoded = try? JSONDecoder().decode([Session].self, from: data) {
            sessions = decoded
        }
    }

    // MARK: - Controls

    func arm() {
        elapsed = 0
        goalReached = false
        faceDownSince = nil
        startDate = nil
        liftedAt = nil
        gravityZ = -1
        phase = .armed
        startSensors()
    }

    func cancel() {
        stopSensors()
        phase = .idle
    }

    func giveUp() {
        guard phase == .lifted else { return }
        finish(endingAt: liftedAt ?? Date())
    }

    func dismissResult() {
        phase = .idle
        elapsed = 0
    }

    func appDidBackground() {
        switch phase {
        case .armed:
            cancel()
        case .focusing:
            finish(endingAt: Date())
        case .lifted:
            finish(endingAt: liftedAt ?? Date())
        case .idle, .finished:
            break
        }
    }

    func deleteSessions(at offsets: IndexSet) {
        let newestFirst = Array(sessions.reversed())
        let ids = Set(offsets.map { newestFirst[$0].id })
        sessions.removeAll { ids.contains($0.id) }
        save()
    }

    // MARK: - Stats

    var todayTotal: TimeInterval {
        let calendar = Calendar.current
        return sessions
            .filter { calendar.isDateInToday($0.start) }
            .reduce(0) { $0 + $1.duration }
    }

    /// Consecutive days, ending today or yesterday, with at least one completed session.
    var streak: Int {
        let calendar = Calendar.current
        let days = Set(sessions.filter { $0.completed }.map { calendar.startOfDay(for: $0.start) })
        var day = calendar.startOfDay(for: Date())
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    // MARK: - Sensors

    private func startSensors() {
        UIApplication.shared.isIdleTimerDisabled = true
        // Face down on a table covers the proximity sensor, which blanks the screen for us.
        UIDevice.current.isProximityMonitoringEnabled = true

        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 0.1
            motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                if let z = data?.gravity.z {
                    self?.gravityZ = z
                }
            }
        }

        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopSensors() {
        ticker?.invalidate()
        ticker = nil
        motion.stopDeviceMotionUpdates()
        UIDevice.current.isProximityMonitoringEnabled = false
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func tick() {
        let now = Date()
        // Gravity z is about +1 with the screen facing the floor, -1 facing the ceiling.
        let isDown = gravityZ > 0.8
        let isUp = gravityZ < 0.5

        switch phase {
        case .armed:
            if isDown {
                if let since = faceDownSince {
                    if now.timeIntervalSince(since) >= 1 {
                        startDate = now
                        elapsed = 0
                        phase = .focusing
                        buzz(.success)
                    }
                } else {
                    faceDownSince = now
                }
            } else {
                faceDownSince = nil
            }

        case .focusing:
            guard let start = startDate else { return }
            elapsed = now.timeIntervalSince(start)
            if !goalReached && elapsed >= goal {
                goalReached = true
                vibrateGoalReached()
            }
            if isUp {
                if goalReached {
                    finish(endingAt: now)
                } else {
                    liftedAt = now
                    graceLeft = FocusEngine.graceSeconds
                    phase = .lifted
                    buzz(.warning)
                }
            }

        case .lifted:
            guard let lifted = liftedAt else { return }
            if isDown {
                liftedAt = nil
                phase = .focusing
                buzz(.success)
                return
            }
            graceLeft = max(0, FocusEngine.graceSeconds - now.timeIntervalSince(lifted))
            if graceLeft <= 0 {
                finish(endingAt: lifted)
            }

        case .idle, .finished:
            break
        }
    }

    private func finish(endingAt end: Date) {
        stopSensors()
        guard let start = startDate else {
            phase = .idle
            return
        }
        let session = Session(start: start, duration: max(0, end.timeIntervalSince(start)), goal: goal)
        elapsed = session.duration
        // Ignore accidental flips shorter than ten seconds.
        if session.duration >= 10 {
            sessions.append(session)
            save()
        }
        phase = .finished(session)
        buzz(session.completed ? .success : .error)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: Keys.sessions)
        }
    }

    // MARK: - Haptics

    private func buzz(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    /// Three long vibrations, strong enough to feel through a table.
    private func vibrateGoalReached() {
        for index in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.8) {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }
}

func formatClock(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval.rounded(.down)))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
}

func formatMinutes(_ interval: TimeInterval) -> String {
    let minutes = Int(interval / 60)
    if minutes >= 60 {
        return "\(minutes / 60)h \(minutes % 60)m"
    }
    return "\(minutes)m"
}
