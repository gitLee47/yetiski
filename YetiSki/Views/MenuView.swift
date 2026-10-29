import SwiftUI

struct MenuView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var showShop = false
    @ObservedObject private var remoteConfig = RemoteConfigManager.shared
    @ObservedObject private var adManager = AdManager.shared

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

                SeasonalBannerView()

                if viewModel.highScore > 0 {
                    Label("Best: \(viewModel.highScore) m", systemImage: "trophy.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }

                if viewModel.weeklyBest > 0 {
                    Label("This Week: \(viewModel.weeklyBest) m", systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }

                HStack(spacing: 16) {
                    if viewModel.reviveTokens > 0 {
                        Label("\(viewModel.reviveTokens)", systemImage: "ticket.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }
                    Label("\(viewModel.snowCoins)", systemImage: "snowflake")
                        .font(.subheadline.bold())
                        .foregroundStyle(.cyan)
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
                .tint(remoteConfig.accentColor ?? .blue)
                .padding(.horizontal, 40)

                Button {
                    showShop = true
                } label: {
                    Label("Locker", systemImage: "tshirt.fill")
                }
                .padding(.bottom, 8)

                if GameCenterManager.shared.isAuthenticated {
                    HStack(spacing: 20) {
                        Button {
                            GameCenterManager.shared.presentLeaderboard()
                        } label: {
                            Label("All-Time", systemImage: "list.number")
                        }
                        Button {
                            GameCenterManager.shared.presentLeaderboard(weekly: true)
                        } label: {
                            Label("This Week", systemImage: "calendar")
                        }
                    }
                    .padding(.bottom, 8)
                }

                Text("Tap the left or right side of the screen to steer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if adManager.isPrivacyOptionsRequired {
                    Button("Privacy Choices") {
                        adManager.presentPrivacyOptions()
                    }
                    .font(.footnote)
                }

                Spacer(minLength: 40)
            }

            if showShop {
                SkinShopView(onClose: { showShop = false })
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
