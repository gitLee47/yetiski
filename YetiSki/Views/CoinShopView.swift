import SwiftUI
import StoreKit

/// Lets the player buy Snow Coins with real money — presented as a sheet
/// from the Locker. Purchases go through real StoreKit 2 (`StoreManager`);
/// see its doc comment for the local-testing setup (`Products.storekit`)
/// and what's needed for this to work in production.
struct CoinShopView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @ObservedObject private var storeManager = StoreManager.shared
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
                            CoinBundleRow(bundle: bundle, priceLabel: priceLabel(for: bundle)) {
                                purchase(bundle)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
        }
    }

    /// Prefers the real, localized StoreKit price once the product's
    /// loaded; falls back to `CoinBundle.priceLabel`'s nominal placeholder
    /// if it hasn't (e.g. no network yet).
    private func priceLabel(for bundle: CoinBundle) -> String {
        storeManager.products.first(where: { $0.id == bundle.productID })?.displayPrice ?? bundle.priceLabel
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

    /// Runs a real StoreKit 2 purchase via `StoreManager`; only credits
    /// coins (`GameViewModel.purchaseCoinBundle(_:)`) once it actually
    /// succeeds — a cancelled/pending/failed purchase credits nothing.
    private func purchase(_ bundle: CoinBundle) {
        purchasingBundle = bundle
        Task {
            let success = await storeManager.purchase(bundle)
            if success {
                viewModel.purchaseCoinBundle(bundle)
            }
            purchasingBundle = nil
        }
    }
}

private struct CoinBundleRow: View {
    let bundle: CoinBundle
    let priceLabel: String
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
                Text(priceLabel)
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
