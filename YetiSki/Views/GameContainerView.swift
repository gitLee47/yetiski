import SpriteKit
import SwiftUI

/// Hosts the `GameScene` via `SpriteView`, with the HUD and (when relevant)
/// the game-over screen layered on top.
struct GameContainerView: View {
    @EnvironmentObject var viewModel: GameViewModel

    @State private var scene: GameScene = {
        let scene = GameScene()
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SpriteView(scene: scene)
                    .ignoresSafeArea()

                // .id(runID) forces SwiftUI to tear down and recreate HUDView
                // (resetting its local banner @State) on every fresh/restarted
                // run, so a banner mid-display at the moment of a restart
                // can't carry over into the new run. Deliberately NOT keyed to
                // continueRunID — a continue keeps the rest of run state in
                // place, so an in-flight banner naturally finishing out is fine.
                HUDView()
                    .id(viewModel.runID)

                if viewModel.appState == .gameOver {
                    GameOverView()
                } else if viewModel.isOfferingContinue {
                    ContinueOfferView()
                } else if viewModel.isYetiWarBannerShown {
                    YetiWarWeaponSelectView()
                } else if viewModel.isPaused {
                    PauseOverlayView()
                }
            }
            .onAppear {
                scene.size = proxy.size
                scene.viewModel = viewModel
                scene.startRun()
            }
            .onChange(of: proxy.size) { _, newSize in
                scene.size = newSize
            }
            .onChange(of: viewModel.runID) { _, _ in
                // Fires for both a fresh game from the menu and a mid-run
                // restart — appState alone wouldn't change in the latter case.
                scene.startRun()
            }
            .onChange(of: viewModel.continueRunID) { _, _ in
                scene.continueRun()
            }
            .onChange(of: viewModel.yetiWarStartID) { _, _ in
                scene.beginYetiWar(weapon: viewModel.selectedWeapon)
            }
            .onChange(of: viewModel.isPaused) { _, paused in
                paused ? scene.pauseRun() : scene.resumeRun()
            }
        }
        .ignoresSafeArea()
    }
}
