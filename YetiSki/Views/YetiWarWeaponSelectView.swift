import SwiftUI

/// Shown the moment `GameScene` decides a Yeti War should start — pauses the
/// scene (mirrors `ContinueOfferView`'s role for the continue-offer flow) and
/// doubles as the weapon shop: locked weapons can be rush-bought with Snow
/// Coins right here, in addition to the Locker's dedicated Weapons section.
struct YetiWarWeaponSelectView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var selection: WeaponKind = .machineGun

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    Text("🐺 Yeti War Incoming!")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Choose your weapon")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 12)

                Label("\(viewModel.snowCoins)", systemImage: "snowflake")
                    .font(.headline.bold())
                    .foregroundStyle(.cyan)

                // Scrolls — 10 weapons (5 rows) no longer fit in a fixed
                // VStack alongside the header and button on one screen.
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(WeaponKind.allCases) { weapon in
                            WeaponChoiceCard(weapon: weapon, isSelected: selection == weapon) {
                                selection = weapon
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Button {
                    viewModel.confirmYetiWarWeapon(selection)
                } label: {
                    Label("Start War", systemImage: "bolt.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            // Default to whatever's already equipped, as long as it's still
            // owned (it always will be, but this is cheap insurance).
            selection = viewModel.unlockedWeapons.contains(viewModel.selectedWeapon) ? viewModel.selectedWeapon : .machineGun
        }
    }
}

private struct WeaponChoiceCard: View {
    @EnvironmentObject var viewModel: GameViewModel
    let weapon: WeaponKind
    let isSelected: Bool
    let onSelect: () -> Void

    private var isUnlocked: Bool { viewModel.unlockedWeapons.contains(weapon) }
    private var canAfford: Bool { viewModel.snowCoins >= weapon.coinCost }

    var body: some View {
        VStack(spacing: 8) {
            PixelArtImage(imageName: weapon.iconName)
                .frame(height: 56)
                .opacity(isUnlocked ? 1 : 0.4)
                .overlay(alignment: .topTrailing) {
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

            Text(weapon.displayName)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if isUnlocked {
                Button(action: onSelect) {
                    Text(isSelected ? "Selected" : "Select")
                        .font(.caption2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .tint(isSelected ? .green : .blue)
            } else {
                // The coin rush-buy is always available, even for a weapon
                // that also has a free level path not yet reached — matching
                // the original "all of them can be unlocked with coins" rule
                // (the Locker's Weapons section works the same way).
                Button {
                    if viewModel.purchaseWeapon(weapon) {
                        onSelect()
                    }
                } label: {
                    Label("\(weapon.coinCost)", systemImage: "snowflake")
                        .font(.caption2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .tint(canAfford ? .cyan : .gray)

                if let unlockLevel = weapon.unlockLevel {
                    Text("or Level \(unlockLevel)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .padding(10)
        .background(
            isSelected ? Color.blue.opacity(0.35) : Color.white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }
}

#Preview {
    YetiWarWeaponSelectView().environmentObject(GameViewModel())
}
