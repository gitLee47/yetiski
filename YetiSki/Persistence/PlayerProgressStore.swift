import Foundation

/// Persists cross-run player progress: the revive-token bank and the daily
/// login streak. Kept separate from `HighScoreStore` since it's a different
/// concern (retention/economy vs. best score).
final class PlayerProgressStore {
    private let defaults: UserDefaults
    private let reviveTokensKey = "com.lijulee.yetiski.reviveTokens"
    private let dailyStreakKey = "com.lijulee.yetiski.dailyStreak"
    private let lastClaimDateKey = "com.lijulee.yetiski.lastClaimDate"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var reviveTokens: Int {
        get { defaults.integer(forKey: reviveTokensKey) }
        set { defaults.set(newValue, forKey: reviveTokensKey) }
    }

    var dailyStreak: Int {
        get { defaults.integer(forKey: dailyStreakKey) }
        set { defaults.set(newValue, forKey: dailyStreakKey) }
    }

    private var lastClaimDate: Date? {
        get { defaults.object(forKey: lastClaimDateKey) as? Date }
        set { defaults.set(newValue, forKey: lastClaimDateKey) }
    }

    /// Whether a new daily reward is available to claim right now (i.e. we
    /// haven't already claimed today's).
    var isDailyRewardAvailable: Bool {
        guard let lastClaimDate else { return true }
        return !Calendar.current.isDateInToday(lastClaimDate)
    }

    /// The streak day this claim would be — continuing the streak if the
    /// last claim was yesterday, resetting to day 1 otherwise (missed a day,
    /// or this is the very first launch) — plus the token reward for that
    /// day. Streak cycles every 7 days, with a bigger payout on day 7.
    func pendingRewardInfo() -> (day: Int, tokens: Int) {
        let day: Int
        if let lastClaimDate, Calendar.current.isDateInYesterday(lastClaimDate) {
            day = dailyStreak + 1
        } else {
            day = 1
        }
        let cycleDay = ((day - 1) % 7) + 1
        let tokens = cycleDay == 7 ? 3 : 1
        return (day, tokens)
    }

    /// Applies today's claim: bumps the streak, banks the tokens, and stamps
    /// today's date so `isDailyRewardAvailable` goes false until tomorrow.
    /// Returns the number of tokens granted.
    @discardableResult
    func claim() -> Int {
        let (day, tokens) = pendingRewardInfo()
        dailyStreak = day
        reviveTokens += tokens
        lastClaimDate = Date()
        return tokens
    }
}
