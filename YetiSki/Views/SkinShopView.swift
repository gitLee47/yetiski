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
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(skin.jacketColor))
                    .frame(width: 46, height: 40)
                Circle()
                    .fill(Color(skin.headColor))
                    .frame(width: 30, height: 30)
                    .offset(y: -28)
                HStack(spacing: 12) {
                    Capsule().fill(Color(skin.skiColor)).frame(width: 6, height: 28)
                    Capsule().fill(Color(skin.skiColor)).frame(width: 6, height: 28)
                }
                .offset(y: 26)
            }
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

#Preview {
    SkinShopView(onClose: {}).environmentObject(GameViewModel())
}
