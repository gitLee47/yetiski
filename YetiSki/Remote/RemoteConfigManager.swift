import Foundation
import UIKit
import SwiftUI

/// Fetches a small JSON manifest + PNGs from the public `gitLee47/yetiski`
/// repo (served as plain static files via raw.githubusercontent.com) so the
/// developer can push game-balance tweaks, menu theming, and new sprite art
/// without an App Store build. Consumed directly by `WeaponKind` (coin
/// cost/unlock level overrides), `SpriteTextureLoader` (sprite PNG
/// overrides), and `SeasonalBannerView`/`MenuView` (theme).
///
/// Unlike `StoreManager`, this is **not** `@MainActor` — `WeaponKind.coinCost`
/// is a plain synchronous computed property called from many non-isolated
/// contexts (enum logic, `GameViewModel`, SwiftUI view bodies), and actor
/// isolation would ripple outward into all of them. `@Published` writes are
/// instead explicitly dispatched onto the main thread.
///
/// Fetch failure, a malformed/unparseable manifest, or a schema version this
/// build doesn't understand all leave every override nil/empty — gameplay,
/// pricing, and sprites fall back to hardcoded defaults. Nothing is ever
/// blocked waiting on this.
final class RemoteConfigManager: ObservableObject {
    static let shared = RemoteConfigManager()

    private static let manifestURL = URL(string:
        "https://raw.githubusercontent.com/gitLee47/yetiski/main/RemoteConfig/config.json")!
    private static let supportedSchemaVersion = 1
    private static let maxAssetBytes = 3_000_000
    private static let assetDimensionRange = 4...1024

    @Published private(set) var manifest: RemoteConfigManifest?

    private let fileManager = FileManager.default

    private lazy var baseDirectory: URL = {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("RemoteConfig", isDirectory: true)
    }()
    private lazy var manifestFileURL = baseDirectory.appendingPathComponent("manifest.json")
    private lazy var assetsDirectory = baseDirectory.appendingPathComponent("assets", isDirectory: true)
    private lazy var sourcesFileURL = assetsDirectory.appendingPathComponent("_sources.json")

    private init() {}

    /// Call once at app launch (mirrors `GameCenterManager.authenticate()`).
    /// Synchronously loads whatever manifest is already cached on disk (so
    /// `WeaponKind`/`SpriteTextureLoader` reads shortly after launch see
    /// last session's overrides immediately, with no network wait), then
    /// kicks off an async network refresh.
    func start() {
        loadCachedManifestFromDisk()
        Task { await refresh() }
    }

    /// Fetches the manifest, validates it, caches it to disk, downloads any
    /// new/changed asset overrides, and invalidates `SpriteTextureLoader`'s
    /// in-memory cache for anything that changed. Never throws to the
    /// caller — every failure path just prints and returns, leaving
    /// `manifest` as whatever was already cached (possibly `nil`).
    func refresh() async {
        let data: Data
        do {
            var request = URLRequest(url: Self.manifestURL)
            request.timeoutInterval = 10
            let (fetched, _) = try await URLSession.shared.data(for: request)
            data = fetched
        } catch {
            print("RemoteConfigManager: manifest fetch failed: \(error.localizedDescription)")
            return
        }

        let decoded: RemoteConfigManifest
        do {
            decoded = try JSONDecoder().decode(RemoteConfigManifest.self, from: data)
        } catch {
            print("RemoteConfigManager: manifest decode failed: \(error.localizedDescription)")
            return
        }

        guard decoded.schemaVersion == Self.supportedSchemaVersion else {
            print("RemoteConfigManager: unsupported schemaVersion \(decoded.schemaVersion), ignoring")
            return
        }

        persist(data)
        await MainActor.run { self.manifest = decoded }

        await downloadAssetsIfNeeded(decoded.assetOverrides ?? [])
    }

    // MARK: - Theme

    var accentColor: Color? {
        manifest?.theme?.accentColorHex.flatMap { Color(hex: $0) }
    }

    var bannerText: String? {
        guard let banner = manifest?.theme?.banner, banner.isVisible, !banner.text.isEmpty else {
            return nil
        }
        return banner.text
    }

    // MARK: - Weapon overrides

    /// `nil` if no override exists for this weapon at all.
    func weaponOverride(for weapon: WeaponKind) -> RemoteWeaponOverride? {
        manifest?.weaponOverrides?.first { $0.id == weapon.rawValue }
    }

    // MARK: - Asset overrides (consumed by SpriteTextureLoader)

    /// Disk file URL for a downloaded replacement of `spriteName`, if one
    /// has actually finished downloading and is present on disk. `nil`
    /// means "no override — use the bundled default."
    func cachedAssetFileURL(for spriteName: String) -> URL? {
        let url = assetsDirectory.appendingPathComponent("\(spriteName).png")
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Private: disk cache

    private func loadCachedManifestFromDisk() {
        guard let data = try? Data(contentsOf: manifestFileURL),
              let decoded = try? JSONDecoder().decode(RemoteConfigManifest.self, from: data),
              decoded.schemaVersion == Self.supportedSchemaVersion
        else {
            return
        }
        manifest = decoded
    }

    private func persist(_ rawData: Data) {
        do {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            try rawData.write(to: manifestFileURL, options: .atomic)
        } catch {
            print("RemoteConfigManager: failed to cache manifest to disk: \(error.localizedDescription)")
        }
    }

    private func loadSources() -> [String: String] {
        guard let data = try? Data(contentsOf: sourcesFileURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    private func saveSources(_ sources: [String: String]) {
        guard let data = try? JSONEncoder().encode(sources) else { return }
        try? data.write(to: sourcesFileURL, options: .atomic)
    }

    // MARK: - Private: asset download

    private func downloadAssetsIfNeeded(_ overrides: [RemoteAssetOverride]) async {
        guard !overrides.isEmpty else { return }
        var sources = loadSources()
        for override in overrides {
            await downloadAssetIfNeeded(override, sources: &sources)
        }
        saveSources(sources)
    }

    private func downloadAssetIfNeeded(_ override: RemoteAssetOverride, sources: inout [String: String]) async {
        let fileURL = assetsDirectory.appendingPathComponent("\(override.spriteName).png")
        let alreadyCurrent = sources[override.spriteName] == override.url
            && fileManager.fileExists(atPath: fileURL.path)
        guard !alreadyCurrent else { return }

        guard let remoteURL = URL(string: override.url) else {
            print("RemoteConfigManager: invalid asset URL for \(override.spriteName)")
            return
        }

        let data: Data
        do {
            var request = URLRequest(url: remoteURL)
            request.timeoutInterval = 15
            let (fetched, _) = try await URLSession.shared.data(for: request)
            data = fetched
        } catch {
            print("RemoteConfigManager: asset download failed for \(override.spriteName): \(error.localizedDescription)")
            return
        }

        guard data.count <= Self.maxAssetBytes else {
            print("RemoteConfigManager: asset \(override.spriteName) exceeds size cap, ignoring")
            return
        }
        guard let image = UIImage(data: data) else {
            print("RemoteConfigManager: asset \(override.spriteName) is not a valid image, ignoring")
            return
        }
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        guard Self.assetDimensionRange.contains(Int(pixelWidth)),
              Self.assetDimensionRange.contains(Int(pixelHeight))
        else {
            print("RemoteConfigManager: asset \(override.spriteName) has invalid dimensions, ignoring")
            return
        }

        do {
            try fileManager.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("RemoteConfigManager: failed to write asset \(override.spriteName): \(error.localizedDescription)")
            return
        }

        sources[override.spriteName] = override.url
        SpriteTextureLoader.invalidateCache(for: override.spriteName)
    }
}
