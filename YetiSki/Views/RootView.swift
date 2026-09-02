import SwiftUI

/// Switches between the menu and the game (which itself overlays the
/// game-over screen once a run ends) based on `GameViewModel.appState`.
struct RootView: View {
    @EnvironmentObject var viewModel: GameViewModel

    var body: some View {
        switch viewModel.appState {
        case .menu:
            MenuView()
        case .playing, .gameOver:
            GameContainerView()
        }
    }
}
