import SwiftUI

/// The Locker — spend Snow Coins (earned from snowflake pickups) to unlock
/// and equip skier skins ("Outfits") and Yeti War weapons ("Weapons").
/// Outfits are purely cosmetic, no gameplay effect, which keeps the
/// leaderboard fair while still giving players something to grind toward —
/// the same model Subway Surfers/Temple Run use for their character shops.
/// Weapons DO have a gameplay effect (during a Yeti War), but share the same
/// unlock-with-coins mechanic, plus an optional free level-based path.
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
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Outfits")
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(SkierSkin.allCases) { skin in
                                SkinCard(skin: skin)
                            }
                        }

                        SectionHeader(title: "Weapons")
                            .padding(.top, 8)
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(WeaponKind.allCases) { weapon in
                                WeaponCard(weapon: weapon)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline.bold())
            .foregroundStyle(.white.opacity(0.7))
    }
}

private struct SkinCard: View {
    @EnvironmentObject var viewModel: GameViewModel
    let skin: SkierSkin

    private var isUnlocked: Bool { viewModel.unlockedSkins.contains(skin) }
    private var isEquipped: Bool { viewModel.selectedSkin == skin }

    var body: some View {
        VStack(spacing: 10) {
            PixelArtImage(imageName: skin.previewImageName)
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
            }
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct WeaponCard: View {
    @EnvironmentObject var viewModel: GameViewModel
    let weapon: WeaponKind

    private var isUnlocked: Bool { viewModel.unlockedWeapons.contains(weapon) }
    private var isEquipped: Bool { viewModel.selectedWeapon == weapon }
    private var canAfford: Bool { viewModel.snowCoins >= weapon.coinCost }

    var body: some View {
        VStack(spacing: 10) {
            PixelArtImage(imageName: weapon.iconName)
                .frame(height: 66)

            Text(weapon.displayName)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if isEquipped {
                Text("Equipped")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            } else if isUnlocked {
                Button {
                    viewModel.selectWeapon(weapon)
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
                    viewModel.purchaseWeapon(weapon)
                } label: {
                    Label("\(weapon.coinCost)", systemImage: "snowflake")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(canAfford ? .cyan : .gray)

                // A weapon with a free level path also shows how to get it
                // without spending coins — the coin cost above is a rush-buy,
                // not the only way in.
                if let unlockLevel = weapon.unlockLevel {
                    Text("or reach Level \(unlockLevel)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    SkinShopView(onClose: {}).environmentObject(GameViewModel())
}
