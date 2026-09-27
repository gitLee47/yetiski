import SwiftUI

/// Renders a bundled pixel-art sprite crisply (no blur from SwiftUI's default
/// smoothing) — the SwiftUI counterpart to `SpriteTextureLoader`'s
/// `filteringMode = .nearest`. Shared by the Locker (skins + weapons) and the
/// Yeti War weapon-select banner, since all three show the same loose PNGs.
struct PixelArtImage: View {
    let imageName: String

    var body: some View {
        if let uiImage = UIImage.loose(named: imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
        } else {
            Color.clear
        }
    }
}

extension UIImage {
    /// Loads a PNG from the bundle root by name, matching `SpriteTextureLoader`'s
    /// lookup — XcodeGen flattens `Resources/` into the bundle root rather than
    /// preserving subfolders, so no `subdirectory:` parameter is needed.
    static func loose(named name: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            assertionFailure("Missing sprite resource: \(name).png")
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}
