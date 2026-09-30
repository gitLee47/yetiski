import SwiftUI

/// Lets the player buy Snow Coins with real money — presented as a sheet
/// from the Locker. A placeholder for real StoreKit 2 purchases (see
/// `CoinBundle`'s doc comment and `GameViewModel.purchaseCoinBundle(_:)`);
/// `simulatePurchase(_:)` fakes a brief checkout delay then "succeeds",
/// exactly like `ContinueOfferView.simulateAd()` fakes a rewarded ad. No
/// real payment is processed until this is wired to actual StoreKit
/// products under the developer account.
struct CoinShopView: View {
    @EnvironmentObject var viewModel: GameViewModel
    let onClose: () -> Void
    @State private var purchasingBundle: CoinBundle?

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Text("Get Snow Coins")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 24)

                Label("\(viewModel.snowCoins)", systemImage: "snowflake")
                    .font(.headline.bold())
                    .foregroundStyle(.cyan)

                if let purchasingBundle {
                    purchasingOverlay(for: purchasingBundle)
                } else {
                    VStack(spacing: 12) {
                        ForEach(CoinBundle.allCases) { bundle in
                            CoinBundleRow(bundle: bundle) {
                                simulatePurchase(bundle)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                Text("Placeholder store — no real payment is processed yet.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 12)
            }
        }
    }

    private func purchasingOverlay(for bundle: CoinBundle) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
            Text("Completing purchase…")
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    /// Placeholder for a real StoreKit 2 purchase sheet + transaction.
    /// Simulates a brief checkout delay, then credits the coins exactly as
    /// a real purchase's completion callback would.
    private func simulatePurchase(_ bundle: CoinBundle) {
        purchasingBundle = bundle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            viewModel.purchaseCoinBundle(bundle)
            purchasingBundle = nil
        }
    }
}

private struct CoinBundleRow: View {
    let bundle: CoinBundle
    let onBuy: () -> Void

    var body: some View {
        Button(action: onBuy) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bundle.displayName)
                        .font(.headline.bold())
                    Label("\(bundle.coinAmount)", systemImage: "snowflake")
                        .font(.subheadline)
                        .foregroundStyle(.cyan)
                }
                Spacer()
                Text(bundle.priceLabel)
                    .font(.headline.bold())
            }
            .padding(14)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(bundle.isBestValue ? .orange : .blue)
        .overlay(alignment: .topTrailing) {
            if bundle.isBestValue {
                Text("BEST VALUE")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.yellow, in: Capsule())
                    .foregroundStyle(.black)
                    .offset(x: -8, y: -8)
            }
        }
    }
}

#Preview {
    CoinShopView(onClose: {}).environmentObject(GameViewModel())
}
