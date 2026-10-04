import GoogleMobileAds
import AppTrackingTransparency
import UIKit

/// Wraps Google AdMob's rewarded ad for the "Watch Ad — Free Continue" flow
/// (see `ContinueOfferView`).
///
/// Uses the real AdMob App ID and rewarded ad unit ID, registered under the
/// user's own AdMob account — see `project.yml`'s `GADApplicationIdentifier`
/// for the App ID side.
final class AdManager: NSObject {
    static let shared = AdManager()

    private let rewardedAdUnitID = "ca-app-pub-8714059521970500/8312979483"

    private var rewardedAd: GADRewardedAd?
    private var completion: ((Bool) -> Void)?

    private override init() {}

    /// Call once at app launch (mirrors `GameCenterManager.authenticate()`).
    /// Starts the Mobile Ads SDK, requests App Tracking Transparency
    /// authorization if not yet determined (required before any ad SDK that
    /// could access IDFA loads, per Apple's review guidelines), then
    /// preloads the first rewarded ad.
    func configure() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        requestTrackingIfNeeded()
        loadAd()
    }

    private func requestTrackingIfNeeded() {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        // Small delay so the system prompt doesn't appear before the app's
        // first screen is visible — Apple's own guidance.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }

    private func loadAd() {
        GADRewardedAd.load(withAdUnitID: rewardedAdUnitID, request: GADRequest()) { [weak self] ad, error in
            if let error {
                print("Rewarded ad failed to load: \(error.localizedDescription)")
                return
            }
            self?.rewardedAd = ad
            ad?.fullScreenContentDelegate = self
        }
    }

    /// Whether a rewarded ad is currently loaded and ready to present.
    var isReady: Bool { rewardedAd != nil }

    /// Presents the preloaded rewarded ad if one's ready; calls
    /// `completion(false)` immediately otherwise. `completion(true)` fires
    /// only if the reward was actually earned (ad watched to completion) —
    /// callers should treat `false` the same as "no ad available right now."
    func showRewardedAd(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let rewardedAd else {
            completion(false)
            return
        }
        self.completion = completion
        rewardedAd.present(fromRootViewController: viewController) { [weak self] in
            self?.completion?(true)
            self?.completion = nil
        }
    }
}

extension AdManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        // If completion is still set here, the reward callback above never
        // fired (e.g. dismissed before earning it) — report failure.
        completion?(false)
        completion = nil
        loadAd()
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        completion?(false)
        completion = nil
        loadAd()
    }
}
