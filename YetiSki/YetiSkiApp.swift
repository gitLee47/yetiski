import SwiftUI

@main
struct YetiSkiApp: App {
    @StateObject private var viewModel = GameViewModel()

    init() {
        GameCenterManager.shared.authenticate()
        AdManager.shared.configure()
        Task { @MainActor in
            StoreManager.shared.start()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
