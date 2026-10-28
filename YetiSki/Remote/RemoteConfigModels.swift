import Foundation

/// The JSON manifest shape served from `RemoteConfig/config.json` in the
/// `gitLee47/yetiski` repo (via `raw.githubusercontent.com`). See
/// `RemoteConfigManager` for how this gets fetched, cached, and applied.
struct RemoteConfigManifest: Codable {
    let schemaVersion: Int
    let theme: RemoteThemeConfig?
    let weaponOverrides: [RemoteWeaponOverride]?
    let assetOverrides: [RemoteAssetOverride]?
}

struct RemoteThemeConfig: Codable {
    let accentColorHex: String?
    let banner: RemoteBannerConfig?
}

struct RemoteBannerConfig: Codable {
    let isVisible: Bool
    let text: String
}

/// An override for one `WeaponKind` (matched by `id == WeaponKind.rawValue`).
/// `coinCost` and `unlockLevel` are independently optional.
///
/// `unlockLevel` needs three states — key absent (don't touch the hardcoded
/// default), key present with a number (override to it), key present as
/// `null` (explicitly remove the free-unlock path) — which a plain `Int?`
/// can't express via `decodeIfPresent` alone, hence the manual `init(from:)`
/// and the separate `hasUnlockLevelOverride` flag.
struct RemoteWeaponOverride: Codable {
    let id: String
    let coinCost: Int?
    let hasUnlockLevelOverride: Bool
    let unlockLevel: Int?

    private enum CodingKeys: String, CodingKey {
        case id, coinCost, unlockLevel
    }

    init(id: String, coinCost: Int?, hasUnlockLevelOverride: Bool, unlockLevel: Int?) {
        self.id = id
        self.coinCost = coinCost
        self.hasUnlockLevelOverride = hasUnlockLevelOverride
        self.unlockLevel = unlockLevel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        coinCost = try container.decodeIfPresent(Int.self, forKey: .coinCost)
        hasUnlockLevelOverride = container.contains(.unlockLevel)
        unlockLevel = try container.decodeIfPresent(Int.self, forKey: .unlockLevel)
    }
}

/// `spriteName` matches the exact string already passed to
/// `SpriteTextureLoader.texture(named:)` (e.g. `"sprite_yeti_1"`) — the
/// downloaded file is cached locally under that name, decoupled from
/// whatever filename `url` happens to use.
struct RemoteAssetOverride: Codable {
    let spriteName: String
    let url: String
}
