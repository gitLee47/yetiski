import Foundation

/// Persists cross-run player progress: the revive-token bank and the daily
/// login streak. Kept separate from `HighScoreStore` since it's a different
/// concern (retention/economy vs. best score).
final class PlayerProgressStore {
    private let defaults: UserDefaults
    private let reviveTokensKey = "com.lijulee.yetiski.reviveTokens"
    private let dailyStreakKey = "com.lijulee.yetiski.dailyStreak"
    private let lastClaimDateKey = "com.lijulee.yetiski.lastClaimDate"
    private let snowCoinsKey = "com.lijulee.yetiski.snowCoins"
    private let unlockedSkinsKey = "com.lijulee.yetiski.unlockedSkins"
    private let selectedSkinKey = "com.lijulee.yetiski.selectedSkin"
    private let weeklyBestKey = "com.lijulee.yetiski.weeklyBestDistance"
    private let weeklyPeriodKey = "com.lijulee.yetiski.weeklyPeriodID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Persistent cosmetic currency, earned from snowflake pickups (separate
    /// from revive tokens, which are functional rather than cosmetic).
    var snowCoins: Int {
        get { defaults.integer(forKey: snowCoinsKey) }
        set { defaults.set(newValue, forKey: snowCoinsKey) }
    }

    /// Always includes `.classic` even before anything's been explicitly
    /// unlocked, since it's the free starting skin.
    var unlockedSkins: Set<SkierSkin> {
        get {
            let rawValues = defaults.stringArray(forKey: unlockedSkinsKey) ?? []
            let skins = Set(rawValues.compactMap(SkierSkin.init(rawValue:)))
            return skins.isEmpty ? [.classic] : skins
        }
        set { defaults.set(Array(newValue).map(\.rawValue), forKey: unlockedSkinsKey) }
    }

    var selectedSkin: SkierSkin {
        get {
            guard let raw = defaults.string(forKey: selectedSkinKey), let skin = SkierSkin(rawValue: raw) else {
                return .classic
            }
            return skin
        }
        set { defaults.set(newValue.rawValue, forKey: selectedSkinKey) }
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

    // MARK: - Weekly best

    /// This week's best distance so far — an always-winnable board that
    /// resets automatically at the start of each new calendar week, so it
    /// never gets demoralizing the way an all-time board eventually does.
    /// Rolls over to 0 lazily (on next read/write) rather than needing a
    /// background timer.
    func currentWeeklyBest() -> Int {
        rolloverWeekIfNeeded()
        return defaults.integer(forKey: weeklyBestKey)
    }

    /// Records a run's distance against this week's best. Returns whether it
    /// was a new weekly best.
    @discardableResult
    func recordWeeklyDistance(_ distance: Int) -> Bool {
        rolloverWeekIfNeeded()
        guard distance > defaults.integer(forKey: weeklyBestKey) else { return false }
        defaults.set(distance, forKey: weeklyBestKey)
        return true
    }

    private func rolloverWeekIfNeeded() {
        let weekID = Self.weekID(for: Date())
        guard defaults.string(forKey: weeklyPeriodKey) != weekID else { return }
        defaults.set(weekID, forKey: weeklyPeriodKey)
        defaults.set(0, forKey: weeklyBestKey)
    }

    private static func weekID(for date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(components.yearForWeekOfYear ?? 0)-W\(components.weekOfYear ?? 0)"
    }
}
