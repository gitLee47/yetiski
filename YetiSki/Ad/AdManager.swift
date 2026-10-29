import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency
import UIKit

/// Wraps Google AdMob's rewarded ad for the "Watch Ad — Free Continue" flow
/// (see `ContinueOfferView`), plus the GDPR/US-state consent flow via Google's
/// User Messaging Platform that has to run before any ad loads.
///
/// Uses the real AdMob App ID and rewarded ad unit ID, registered under the
/// user's own AdMob account — see `project.yml`'s `GADApplicationIdentifier`
/// for the App ID side. The consent form itself is configured in AdMob's
/// "Privacy & messaging" dashboard, not in code; until a message is published
/// there, players in regulated regions simply get no ads.
final class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()

    private let rewardedAdUnitID = "ca-app-pub-8714059521970500/8312979483"

    /// Whether to show a "Privacy Choices" entry point (see `MenuView`) —
    /// Google requires one for players whose consent was collected via the
    /// form, so they can change their choice later.
    @Published private(set) var isPrivacyOptionsRequired = false

    private var rewardedAd: GADRewardedAd?
    private var completion: ((Bool) -> Void)?
    private var hasStartedSDK = false

    private override init() {}

    /// Call once at app launch (mirrors `GameCenterManager.authenticate()`).
    /// Tags requests as not child-directed / not under-age-of-consent
    /// (YetiSki carries a 9+ general-audience rating), then gathers consent:
    /// refreshes consent info, presents Google's consent form if this player
    /// needs one, requests App Tracking Transparency, and only then starts
    /// the Mobile Ads SDK and preloads the first rewarded ad.
    func configure() {
        let requestConfiguration = GADMobileAds.sharedInstance().requestConfiguration
        requestConfiguration.tagForChildDirectedTreatment = NSNumber(value: false)
        requestConfiguration.tagForUnderAgeOfConsent = NSNumber(value: false)

        // Consent given in a previous session already permits ads — don't
        // make the player wait on the network round-trip below for them.
        if UMPConsentInformation.sharedInstance.canRequestAds {
            startSDKIfNeeded()
        }

        let parameters = UMPRequestParameters()
        parameters.tagForUnderAgeOfConsent = false
        UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            if let error {
                print("Consent info update failed: \(error.localizedDescription)")
                self?.finishConsentFlow()
                return
            }
            self?.presentConsentFormIfRequired(attempt: 0)
        }
    }

    /// Re-opens Google's consent form so the player can change their choice.
    /// Only meaningful while `isPrivacyOptionsRequired` is true.
    func presentPrivacyOptions() {
        guard let viewController = Self.topViewController() else { return }
        UMPConsentForm.presentPrivacyOptionsForm(from: viewController) { error in
            if let error {
                print("Privacy options form failed: \(error.localizedDescription)")
            }
        }
    }

    /// The consent info update can finish before SwiftUI has a window up at
    /// launch, so retry briefly until there's a view controller to present on.
    private func presentConsentFormIfRequired(attempt: Int) {
        guard let viewController = Self.topViewController() else {
            guard attempt < 10 else {
                finishConsentFlow()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.presentConsentFormIfRequired(attempt: attempt + 1)
            }
            return
        }
        UMPConsentForm.loadAndPresentIfRequired(from: viewController) { [weak self] error in
            if let error {
                print("Consent form failed: \(error.localizedDescription)")
            }
            self?.finishConsentFlow()
        }
    }

    private func finishConsentFlow() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isPrivacyOptionsRequired =
                UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus == .required
            // Google's recommended order: GDPR consent first, then ATT.
            requestTrackingIfNeeded { [weak self] in
                guard UMPConsentInformation.sharedInstance.canRequestAds else { return }
                self?.startSDKIfNeeded()
            }
        }
    }

    private func requestTrackingIfNeeded(then completion: @escaping () -> Void) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            completion()
            return
        }
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async(execute: completion)
        }
    }

    private func startSDKIfNeeded() {
        guard !hasStartedSDK else { return }
        hasStartedSDK = true
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        loadAd()
    }

    private static func topViewController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
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
