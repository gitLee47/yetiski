import UIKit

/// A cosmetic skier appearance — jacket/head/ski colors only, no gameplay
/// effect. Unlocked with Snow Coins (earned from snowflake pickups) and
/// equipped from the Locker. Kept purely cosmetic so the leaderboard stays
/// fair — same model Subway Surfers/Temple Run use for their character shops.
enum SkierSkin: String, CaseIterable, Identifiable, Hashable {
    case classic
    case blaze
    case arctic
    case shadow
    case royal
    case golden

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .blaze: return "Blaze"
        case .arctic: return "Arctic"
        case .shadow: return "Shadow"
        case .royal: return "Royal"
        case .golden: return "Golden"
        }
    }

    /// Snow Coins cost to unlock. Classic is free — it's the starting skin.
    var cost: Int {
        switch self {
        case .classic: return 0
        case .blaze: return 50
        case .arctic: return 75
        case .shadow: return 100
        case .royal: return 150
        case .golden: return 300
        }
    }

    var jacketColor: UIColor {
        switch self {
        case .classic: return .systemBlue
        case .blaze: return UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)
        case .arctic: return UIColor(white: 0.95, alpha: 1)
        case .shadow: return UIColor(white: 0.15, alpha: 1)
        case .royal: return UIColor(red: 0.45, green: 0.2, blue: 0.75, alpha: 1)
        case .golden: return UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1)
        }
    }

    var headColor: UIColor {
        switch self {
        case .classic: return .systemOrange
        case .blaze: return UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
        case .arctic: return UIColor(red: 0.65, green: 0.85, blue: 1.0, alpha: 1)
        case .shadow: return UIColor(white: 0.5, alpha: 1)
        case .royal: return UIColor(red: 0.9, green: 0.75, blue: 0.2, alpha: 1)
        case .golden: return UIColor(red: 0.98, green: 0.85, blue: 0.4, alpha: 1)
        }
    }

    var skiColor: UIColor {
        switch self {
        case .classic: return .red
        case .blaze: return UIColor(red: 0.95, green: 0.5, blue: 0.1, alpha: 1)
        case .arctic: return UIColor(red: 0.2, green: 0.75, blue: 0.95, alpha: 1)
        case .shadow: return UIColor(red: 0.55, green: 0.1, blue: 0.15, alpha: 1)
        case .royal: return UIColor(red: 0.6, green: 0.3, blue: 0.85, alpha: 1)
        case .golden: return UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1)
        }
    }
}
