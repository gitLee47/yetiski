import SwiftUI

struct GameOverView: View {
    @EnvironmentObject var viewModel: GameViewModel

    private var isNewHighScore: Bool { viewModel.distance >= viewModel.highScore && viewModel.distance > 0 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 20) {
                Text(viewModel.wasCaughtByYeti ? "Eaten by the Yeti!" : "Wipeout!")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                VStack(spacing: 4) {
                    Text("\(viewModel.distance) m")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    if isNewHighScore {
                        Label("New Best!", systemImage: "star.fill")
                            .font(.headline)
                            .foregroundStyle(.yellow)
                    } else {
                        Text("Best: \(viewModel.highScore) m")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                VStack(spacing: 12) {
                    Button {
                        viewModel.startNewGame()
                    } label: {
                        Label("Play Again", systemImage: "arrow.clockwise")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Button {
                        viewModel.returnToMenu()
                    } label: {
                        Text("Main Menu")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)

                    if GameCenterManager.shared.isAuthenticated {
                        Button {
                            GameCenterManager.shared.presentLeaderboard()
                        } label: {
                            Label("Leaderboard", systemImage: "list.number")
                        }
                        .tint(.white)
                    }
                }
                .padding(.horizontal, 32)
            }
            .padding(.vertical, 40)
        }
    }
}

#Preview {
    GameOverView().environmentObject(GameViewModel())
}
