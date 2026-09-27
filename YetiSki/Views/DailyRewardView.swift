import SwiftUI

/// Once-per-day login reward shown over the menu — a proven retention hook
/// (daily streak calendars) borrowed from casual games like Subway Surfers
/// and Candy Crush. Grants revive tokens, which the continue-offer prompt
/// spends to keep a run going after a hit.
struct DailyRewardView: View {
    @EnvironmentObject var viewModel: GameViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Day \(viewModel.pendingDailyRewardDay) Streak!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Image(systemName: "ticket.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text("+\(viewModel.pendingDailyRewardTokens) Revive Token\(viewModel.pendingDailyRewardTokens == 1 ? "" : "s")")
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text("Come back tomorrow to keep your streak going!")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Button {
                    viewModel.claimDailyReward()
                } label: {
                    Text("Claim")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.horizontal, 24)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    DailyRewardView().environmentObject(GameViewModel())
}
