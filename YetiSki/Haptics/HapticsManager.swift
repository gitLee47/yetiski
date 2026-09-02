import UIKit

/// Wraps the Taptic Engine feedback generators used throughout the game.
final class HapticsManager {
    static let shared = HapticsManager()

    private let notification = UINotificationFeedbackGenerator()
    private let impact = UIImpactFeedbackGenerator(style: .light)

    private init() {}

    /// Light tap when steering into a new lane.
    func laneChange() {
        impact.impactOccurred()
    }

    /// Buzz when the skier hits a stone/hole/tree.
    func crashImpact() {
        notification.notificationOccurred(.warning)
    }

    /// Stronger buzz when the run ends.
    func gameOverImpact() {
        notification.notificationOccurred(.error)
    }

    /// Positive buzz when the difficulty level advances.
    func levelUp() {
        notification.notificationOccurred(.success)
    }
}
