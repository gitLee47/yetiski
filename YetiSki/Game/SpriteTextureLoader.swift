import SpriteKit

/// Loads the pixel-art sprite PNGs bundled under `YetiSki/Resources/Sprites`
/// (see that folder's README for source/license). Uses the same loose-file
/// bundle lookup pattern as `SoundManager`, since XcodeGen's resource
/// grouping flattens `Resources/` into the bundle root rather than
/// preserving subfolders.
///
/// Sets `filteringMode = .nearest` on every texture — these sprites are
/// native 16×16 pixel art and are scaled up in-game, so linear filtering
/// would blur them into mush instead of keeping crisp pixel edges.
enum SpriteTextureLoader {
    private static var cache: [String: SKTexture] = [:]

    static func texture(named name: String) -> SKTexture {
        if let cached = cache[name] {
            return cached
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path)
        else {
            assertionFailure("Missing sprite resource: \(name).png")
            return SKTexture()
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        cache[name] = texture
        return texture
    }
}
