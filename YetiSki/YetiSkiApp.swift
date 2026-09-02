import SwiftUI

@main
struct YetiSkiApp: App {
    @StateObject private var viewModel = GameViewModel()

    init() {
        GameCenterManager.shared.authenticate()
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
