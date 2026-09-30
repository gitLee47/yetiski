import Foundation

/// A real-money Snow Coin bundle — a placeholder for real StoreKit 2
/// products (see `GameViewModel.purchaseCoinBundle(_:)` and
/// `CoinShopView.simulatePurchase(_:)`, which mirror `ContinueOfferView`'s
/// "fake it until App Store Connect is set up" pattern for the ad-revive
/// flow). No real payment is processed until this is wired to actual
/// StoreKit products under the developer account.
///
/// Sizes are deliberately anchored to `WeaponKind`'s coin costs rather than
/// picked arbitrarily, so the currency and the weapon ladder read as one
/// coherent economy: `.small` exactly affords Shotgun (200), `.large`
/// exactly affords Acid Sprayer (1500) — real money buys a specific,
/// legible thing, not just a vague pile of currency. Most weapons also have
/// a free (grind-or-level) path — money is a shortcut there — but four are
/// coin-only (`.iceCannon`, `.acidSprayer`, `.gravityPulse`, `.pulseBlade`),
/// so for those, a bundle purchase (or enough free-earned coins) is the
/// only way in. Price-per-coin improves at each tier (verify this still
/// holds if the amounts or weapon costs change again), so buying bigger is
/// always the better deal, never just a bigger number.
enum CoinBundle: String, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case mega

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "Snowball"
        case .medium: return "Snow Pile"
        case .large: return "Snowdrift"
        case .mega: return "Avalanche"
        }
    }

    var coinAmount: Int {
        switch self {
        case .small: return 200
        case .medium: return 900
        case .large: return 1500
        case .mega: return 3000
        }
    }

    /// Display-only placeholder price — real pricing comes from StoreKit's
    /// own localized product price once real IAP products exist; this
    /// never reaches a payment processor. Per-coin price strictly improves
    /// small -> mega (≈1.0¢, 0.78¢, 0.73¢, 0.67¢ per coin).
    var priceLabel: String {
        switch self {
        case .small: return "$1.99"
        case .medium: return "$6.99"
        case .large: return "$10.99"
        case .mega: return "$19.99"
        }
    }

    /// Highlighted as the best-value pick in `CoinShopView` — exactly
    /// affords Acid Sprayer and comfortably affords Ice Cannon too, at a
    /// meaningfully better per-coin price than the smaller bundles.
    var isBestValue: Bool { self == .large }
}
