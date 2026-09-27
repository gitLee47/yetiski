import SwiftUI

struct MenuView: View {
    @EnvironmentObject var viewModel: GameViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.55, green: 0.78, blue: 0.98), Color(red: 0.92, green: 0.96, blue: 1.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 4) {
                    Text("Yeti")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(.blue)
                    Text("Ski")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(.orange)
                }

                Text("Dodge the slope. Outrun the yeti.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if viewModel.highScore > 0 {
                    Label("Best: \(viewModel.highScore) m", systemImage: "trophy.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }

                if viewModel.reviveTokens > 0 {
                    Label("\(viewModel.reviveTokens) Revive Token\(viewModel.reviveTokens == 1 ? "" : "s")", systemImage: "ticket.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }

                Spacer()

                Button {
                    viewModel.startNewGame()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.horizontal, 40)

                if GameCenterManager.shared.isAuthenticated {
                    Button {
                        GameCenterManager.shared.presentLeaderboard()
                    } label: {
                        Label("Leaderboard", systemImage: "list.number")
                    }
                    .padding(.bottom, 8)
                }

                Text("Tap the left or right side of the screen to steer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer(minLength: 40)
            }

            if viewModel.showDailyReward {
                DailyRewardView()
            }
        }
    }
}

#Preview {
    MenuView().environmentObject(GameViewModel())
}
