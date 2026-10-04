import StoreKit

/// Wraps StoreKit 2 for the Snow Coin bundle purchases (see `CoinBundle`).
///
/// For local testing, the `YetiSki` scheme's Debug run configuration points
/// at `YetiSki/Products.storekit` (a local test product catalog — see
/// `project.yml`'s `storeKitConfiguration`), so the full real purchase flow
/// works in the simulator with no App Store Connect setup and no real money.
///
/// Setup required before this does anything for real (production/TestFlight):
/// 1. In App Store Connect, add 4 consumable in-app purchases with the exact
///    product identifiers in `CoinBundle.productID` (com.lijulee.yetiski.
///    coins.small/medium/large/mega) and prices matching `CoinBundle`'s
///    nominal tiers.
/// 2. Remove the scheme's `storeKitConfiguration` (or build via a scheme
///    that doesn't set it) so Release/TestFlight builds go through the real
///    sandbox/production App Store instead of the local test catalog.
/// Until then, `products` stays empty outside of local testing and
/// `purchase(_:)` fails gracefully — no coins are credited, no crash.
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published private(set) var products: [Product] = []

    private var updateListenerTask: Task<Void, Never>?

    private init() {}

    /// Call once at app launch (mirrors `GameCenterManager.authenticate()`).
    func start() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
    }

    private func loadProducts() async {
        do {
            products = try await Product.products(for: CoinBundle.allCases.map(\.productID))
        } catch {
            print("Failed to load Snow Coin products: \(error.localizedDescription)")
        }
    }

    /// Purchases a bundle's real StoreKit product. Returns `true` only once
    /// the transaction is verified and finished — callers should credit
    /// coins (`GameViewModel.purchaseCoinBundle(_:)`) only on `true`.
    func purchase(_ bundle: CoinBundle) async -> Bool {
        guard let product = products.first(where: { $0.id == bundle.productID }) else { return false }

        guard let result = try? await product.purchase() else { return false }

        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return false }
            await transaction.finish()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Finishes any transaction that completes outside a direct `purchase(_:)`
    /// call (e.g. Ask to Buy approval arriving later) — standard StoreKit 2
    /// practice, started once at launch and kept alive for the app's lifetime.
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
            }
        }
    }
}
