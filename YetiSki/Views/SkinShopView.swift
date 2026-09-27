import SwiftUI

/// The cosmetic shop ("Locker") — spend Snow Coins (earned from snowflake
/// pickups) to unlock and equip skier skins. Purely cosmetic, no gameplay
/// effect, which keeps the leaderboard fair while still giving players
/// something to grind toward — the same model Subway Surfers/Temple Run use
/// for their character shops.
struct SkinShopView: View {
    @EnvironmentObject var viewModel: GameViewModel
    let onClose: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Text("Locker")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Label("\(viewModel.snowCoins)", systemImage: "snowflake")
                        .font(.headline.bold())
                        .foregroundStyle(.cyan)
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 24)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(SkierSkin.allCases) { skin in
                            SkinCard(skin: skin)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

private struct SkinCard: View {
    @EnvironmentObject var viewModel: GameViewModel
    let skin: SkierSkin

    private var isUnlocked: Bool { viewModel.unlockedSkins.contains(skin) }
    private var isEquipped: Bool { viewModel.selectedSkin == skin }

    var body: some View {
        VStack(spacing: 10) {
            SkinPreviewImage(imageName: skin.previewImageName)
                .frame(height: 66)

            Text(skin.displayName)
                .font(.subheadline.bold())
                .foregroundStyle(.white)

            if isEquipped {
                Text("Equipped")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            } else if isUnlocked {
                Button {
                    viewModel.selectSkin(skin)
                } label: {
                    Text("Equip")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            } else {
                Button {
                    viewModel.purchaseSkin(skin)
                } label: {
                    Label("\(skin.cost)", systemImage: "snowflake")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.snowCoins >= skin.cost ? .cyan : .gray)
                .disabled(viewModel.snowCoins < skin.cost)
            }
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Renders a bundled pixel-art sprite crisply (no blur from SwiftUI's default
/// smoothing) — the SwiftUI counterpart to `SpriteTextureLoader`'s
/// `filteringMode = .nearest`, since the Locker's card previews are plain
/// SwiftUI, not SpriteKit.
private struct SkinPreviewImage: View {
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

private extension UIImage {
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

#Preview {
    SkinShopView(onClose: {}).environmentObject(GameViewModel())
}
