import SwiftUI

/// Shown once per run, right when the skier would otherwise be game-over —
/// offers a revive via a banked token or a rewarded ad, before falling
/// through to the real Game Over screen. The "ad" here is a placeholder
/// simulation (a brief loading spinner); swap `simulateAd`'s body for a real
/// rewarded-ad SDK call (e.g. Google AdMob) once that's set up — everything
/// downstream (`GameViewModel.useAdRevive()`) already works either way.
struct ContinueOfferView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var secondsRemaining = 5
    @State private var isShowingAd = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            if isShowingAd {
                adPlaceholder
            } else {
                offerContent
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard !isShowingAd else { return }
            secondsRemaining -= 1
            if secondsRemaining <= 0 {
                viewModel.declineContinue()
            }
        }
    }

    private var offerContent: some View {
        VStack(spacing: 20) {
            Text("Keep Going?")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("\(secondsRemaining)")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            VStack(spacing: 12) {
                Button {
                    viewModel.useReviveToken()
                } label: {
                    Label("Use Revive Token (\(viewModel.reviveTokens) left)", systemImage: "ticket.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(viewModel.reviveTokens <= 0)

                Button {
                    simulateAd()
                } label: {
                    Label("Watch Ad — Free Continue", systemImage: "play.rectangle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button {
                    viewModel.declineContinue()
                } label: {
                    Text("No Thanks")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
            .padding(.horizontal, 32)
        }
    }

    private var adPlaceholder: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
            Text("Loading ad…")
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    /// Placeholder for a real rewarded-ad SDK call. Simulates a short ad
    /// break, then grants the continue exactly as a real ad's completion
    /// callback would.
    private func simulateAd() {
        isShowingAd = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            isShowingAd = false
            viewModel.useAdRevive()
        }
    }
}

#Preview {
    ContinueOfferView().environmentObject(GameViewModel())
}
