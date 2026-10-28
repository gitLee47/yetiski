import SwiftUI

/// A small, optional banner driven entirely by `RemoteConfigManager` — shown
/// on the menu for a seasonal/event message. Renders nothing before a
/// manifest has loaded, or whenever the manifest's banner is absent/hidden.
struct SeasonalBannerView: View {
    @ObservedObject private var remoteConfig = RemoteConfigManager.shared

    var body: some View {
        if let text = remoteConfig.bannerText {
            Text(text)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(remoteConfig.accentColor ?? .orange, in: Capsule())
                .transition(.opacity)
        }
    }
}

#Preview {
    SeasonalBannerView()
}
