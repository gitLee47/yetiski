import SwiftUI
import UIKit

struct GameOverView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var shareImageURL: URL?

    private var isNewHighScore: Bool { viewModel.distance >= viewModel.highScore && viewModel.distance > 0 }
    private var isNewWeeklyBest: Bool { viewModel.distance >= viewModel.weeklyBest && viewModel.distance > 0 }

    private var shareText: String {
        "I skied \(viewModel.distance) m in YetiSki! \(viewModel.deathCaption) Can you beat me? 🎿🏔️"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 16) {
                Text(viewModel.wasCaughtByYeti ? "Eaten by the Yeti!" : "Wipeout!")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text(viewModel.deathCaption)
                    .font(.subheadline.italic())
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 4) {
                    Text("\(viewModel.distance) m")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    if isNewHighScore {
                        Label("New Best!", systemImage: "star.fill")
                            .font(.headline)
                            .foregroundStyle(.yellow)
                    } else if isNewWeeklyBest {
                        Label("New Weekly Best!", systemImage: "calendar.badge.checkmark")
                            .font(.headline)
                            .foregroundStyle(.cyan)
                    } else {
                        Text("Best: \(viewModel.highScore) m")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    if !isNewHighScore && !isNewWeeklyBest {
                        Text("This Week: \(viewModel.weeklyBest) m")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }

                VStack(spacing: 12) {
                    if let shareImageURL {
                        ShareLink(
                            item: shareImageURL,
                            subject: Text("YetiSki"),
                            message: Text(shareText)
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }

                    Button {
                        viewModel.startNewGame()
                    } label: {
                        Label("Play Again", systemImage: "arrow.clockwise")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Button {
                        viewModel.returnToMenu()
                    } label: {
                        Text("Main Menu")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)

                    if GameCenterManager.shared.isAuthenticated {
                        HStack(spacing: 20) {
                            Button {
                                GameCenterManager.shared.presentLeaderboard()
                            } label: {
                                Label("All-Time", systemImage: "list.number")
                            }
                            Button {
                                GameCenterManager.shared.presentLeaderboard(weekly: true)
                            } label: {
                                Label("This Week", systemImage: "calendar")
                            }
                        }
                        .tint(.white)
                    }
                }
                .padding(.horizontal, 32)
            }
            .padding(.vertical, 40)
        }
        .onAppear(perform: renderShareCard)
    }

    /// Renders `ScoreCardView` off-screen into a PNG in the temp directory
    /// so `ShareLink` has a concrete file to hand to the share sheet.
    private func renderShareCard() {
        let card = ScoreCardView(
            distance: viewModel.distance,
            isNewHighScore: isNewHighScore,
            caption: viewModel.deathCaption,
            wasCaughtByYeti: viewModel.wasCaughtByYeti
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        guard let uiImage = renderer.uiImage, let data = uiImage.pngData() else { return }

        if let previousURL = shareImageURL {
            try? FileManager.default.removeItem(at: previousURL)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("yetiski_share_\(UUID().uuidString).png")
        do {
            try data.write(to: url)
            shareImageURL = url
        } catch {
            shareImageURL = nil
        }
    }
}

#Preview {
    GameOverView().environmentObject(GameViewModel())
}
