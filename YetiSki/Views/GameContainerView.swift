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

                HUDView()
                    .allowsHitTesting(false)

                if viewModel.appState == .gameOver {
                    GameOverView()
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
            .onChange(of: viewModel.appState) { _, newState in
                if newState == .playing {
                    scene.startRun()
                }
            }
        }
        .ignoresSafeArea()
    }
}
