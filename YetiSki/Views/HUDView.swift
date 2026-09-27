import SwiftUI

/// Score + lives overlay shown during gameplay. Mostly non-interactive (taps
/// pass through to the SpriteKit scene for steering) — only the restart
/// button below opts back into hit-testing.
struct HUDView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var showLevelBanner = false
    @State private var unlockedWeaponBanner: WeaponKind?
    @State private var warResultToast: YetiWarResult?

    var body: some View {
        ZStack {
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(viewModel.distance) m")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text("Level \(viewModel.level)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                        if viewModel.highScore > 0 {
                            Text("Best \(viewModel.highScore) m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(spacing: 4) {
                            ForEach(0..<GameConstants.maxLives, id: \.self) { index in
                                Image(systemName: "figure.skiing.downhill")
                                    .foregroundStyle(index < viewModel.lives ? .blue : .gray.opacity(0.3))
                            }
                        }
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .allowsHitTesting(false)

                        if viewModel.appState == .playing && !viewModel.isPaused {
                            HStack(spacing: 8) {
                                HUDIconButton(systemName: "pause.fill", accessibilityLabel: "Pause") {
                                    viewModel.pause()
                                }
                                HUDIconButton(systemName: "arrow.counterclockwise", accessibilityLabel: "Restart") {
                                    viewModel.startNewGame()
                                }
                            }
                        }
                    }
                }
                .padding()

                if viewModel.shieldActive || viewModel.speedBoostActive {
                    HStack(spacing: 6) {
                        if viewModel.shieldActive {
                            BuffIcon(systemName: "shield.fill", color: .blue)
                        }
                        if viewModel.speedBoostActive {
                            BuffIcon(systemName: "bolt.fill", color: .green)
                        }
                    }
                    .allowsHitTesting(false)
                }

                if viewModel.yetiWarActive {
                    YetiWarHUDRow(timeRemaining: viewModel.yetiWarTimeRemaining, kills: viewModel.yetiWarKillCount)
                        .allowsHitTesting(false)
                }

                Spacer()
            }

            if showLevelBanner {
                LevelUpBanner(level: viewModel.level)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            if let weapon = unlockedWeaponBanner {
                WeaponUnlockedBanner(weapon: weapon)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            if let result = warResultToast {
                YetiWarResultToast(result: result)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: viewModel.level) { _, newLevel in
            // Skip the initial assignment when a run starts at level 1.
            guard newLevel > 1 else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                showLevelBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showLevelBanner = false
                }
            }
        }
        .onChange(of: viewModel.weaponJustUnlocked) { _, weapon in
            guard let weapon else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                unlockedWeaponBanner = weapon
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeOut(duration: 0.3)) {
                    unlockedWeaponBanner = nil
                }
            }
        }
        .onChange(of: viewModel.yetiWarResult) { _, result in
            guard let result else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                warResultToast = result
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    warResultToast = nil
                }
            }
        }
    }
}

/// Small circular icon button used for the in-HUD pause/restart controls.
private struct HUDIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.black.opacity(0.35), in: Circle())
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Small icon shown while a timed powerup (shield/speed boost) is active.
private struct BuffIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color, in: Circle())
    }
}

/// Brief celebratory banner shown when the survival-time level advances.
private struct LevelUpBanner: View {
    let level: Int

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.largeTitle)
            Text("Level \(level)!")
                .font(.system(.title, design: .rounded, weight: .heavy))
        }
        .foregroundStyle(.white)
        .padding(24)
        .background(.blue.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 12)
    }
}

/// Countdown + kill count shown while a Yeti War is active.
private struct YetiWarHUDRow: View {
    let timeRemaining: TimeInterval
    let kills: Int

    var body: some View {
        HStack(spacing: 10) {
            Label("\(Int(timeRemaining.rounded(.up)))s", systemImage: "timer")
            Label("\(kills)", systemImage: "scope")
        }
        .font(.caption.bold())
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.red.opacity(0.85), in: Capsule())
    }
}

/// Brief celebratory banner shown when a weapon is auto-unlocked by level.
private struct WeaponUnlockedBanner: View {
    let weapon: WeaponKind

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "lock.open.fill")
                .font(.largeTitle)
            Text("\(weapon.displayName) Unlocked!")
                .font(.system(.title3, design: .rounded, weight: .heavy))
        }
        .foregroundStyle(.white)
        .padding(24)
        .background(.orange.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 12)
    }
}

/// Brief summary toast shown once a Yeti War ends.
private struct YetiWarResultToast: View {
    let result: YetiWarResult

    var body: some View {
        VStack(spacing: 4) {
            Text("Yeti War Survived!")
                .font(.system(.title3, design: .rounded, weight: .heavy))
            Text("\(result.kills) kills · +\(result.bonusCoins) 🔷")
                .font(.subheadline.bold())
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(.purple.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 12)
    }
}

#Preview {
    HUDView().environmentObject(GameViewModel())
}
