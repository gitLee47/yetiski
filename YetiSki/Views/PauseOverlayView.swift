import SwiftUI

/// Full-screen dimmed overlay shown while `GameViewModel.isPaused` is true.
/// Its opaque background also blocks taps from reaching the SpriteKit scene
/// underneath, so steering can't happen while paused.
struct PauseOverlayView: View {
    @EnvironmentObject var viewModel: GameViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Paused")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text("\(viewModel.distance) m")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                VStack(spacing: 12) {
                    Button {
                        viewModel.resume()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Button {
                        viewModel.startNewGame()
                    } label: {
                        Label("Restart", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)

                    Button {
                        viewModel.returnToMenu()
                    } label: {
                        Text("Main Menu")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
                .padding(.horizontal, 32)
            }
            .padding(.vertical, 40)
        }
    }
}

#Preview {
    PauseOverlayView().environmentObject(GameViewModel())
}
