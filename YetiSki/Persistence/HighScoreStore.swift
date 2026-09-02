import Foundation

/// Thin `UserDefaults` wrapper for the local high score. No account/backend needed.
final class HighScoreStore {
    private let key = "com.lijulee.yetiski.bestDistance"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var bestDistance: Int {
        get { defaults.integer(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}
