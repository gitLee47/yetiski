import SwiftUI

/// Score + lives overlay shown during gameplay. Non-interactive (taps pass
/// through to the SpriteKit scene for steering).
struct HUDView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var showLevelBanner = false

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

                    Spacer()

                    HStack(spacing: 4) {
                        ForEach(0..<GameConstants.startingLives, id: \.self) { index in
                            Image(systemName: "figure.skiing.downhill")
                                .foregroundStyle(index < viewModel.lives ? .blue : .gray.opacity(0.3))
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding()

                Spacer()
            }

            if showLevelBanner {
                LevelUpBanner(level: viewModel.level)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
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

#Preview {
    HUDView().environmentObject(GameViewModel())
}
