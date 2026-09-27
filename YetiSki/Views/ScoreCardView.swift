import SwiftUI

/// Compact shareable card summarizing a finished run — rendered off-screen
/// via `ImageRenderer` in `GameOverView` and shared as an image through
/// `ShareLink`. Not shown directly in the live view hierarchy.
struct ScoreCardView: View {
    let distance: Int
    let isNewHighScore: Bool
    let caption: String
    let wasCaughtByYeti: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.15, green: 0.4, blue: 0.85), Color(red: 0.55, green: 0.78, blue: 0.98)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 14) {
                Text(wasCaughtByYeti ? "🥶" : "💥")
                    .font(.system(size: 56))

                VStack(spacing: -6) {
                    Text("Yeti")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Ski")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.orange)
                }

                Text("\(distance) m")
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                if isNewHighScore {
                    Label("New Best!", systemImage: "star.fill")
                        .font(.headline.bold())
                        .foregroundStyle(.yellow)
                }

                Text(caption)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Spacer().frame(height: 6)

                Text("Can you beat me?")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(28)
        }
        .frame(width: 400, height: 480)
    }
}

#Preview {
    ScoreCardView(distance: 2533, isNewHighScore: true, caption: "The yeti wanted a snack.", wasCaughtByYeti: true)
}
