import GameKit
import UIKit

/// Handles Game Center authentication and the "best distance" leaderboards —
/// both an all-time board and a recurring weekly one, so there's always a
/// winnable competition even once the all-time board gets dominated by early
/// players (the same reasoning behind `PlayerProgressStore`'s local weekly
/// best, which works without any of this being configured).
///
/// Setup required before this does anything useful:
/// 1. In App Store Connect, add a Game Center leaderboard with the identifier
///    in `leaderboardID`, AND a *recurring* (weekly, resets Monday) one with
///    the identifier in `weeklyLeaderboardID`.
/// 2. Sign in with a sandbox Game Center account on the test device/simulator.
/// Until then, authentication silently fails and score submission is skipped —
/// gameplay is unaffected either way.
final class GameCenterManager: NSObject {
    static let shared = GameCenterManager()

    /// Must match the leaderboard identifiers configured in App Store Connect.
    static let leaderboardID = "com.lijulee.yetiski.bestdistance"
    static let weeklyLeaderboardID = "com.lijulee.yetiski.weeklybestdistance"

    private(set) var isAuthenticated = false

    private override init() {}

    /// Call once on app launch (e.g. from `YetiSkiApp.init`).
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            if let viewController {
                Self.presentAuthViewController(viewController)
            } else if GKLocalPlayer.local.isAuthenticated {
                self?.isAuthenticated = true
            } else {
                self?.isAuthenticated = false
                if let error {
                    print("Game Center authentication failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Submits to both the all-time and weekly leaderboards — Game Center
    /// itself handles the weekly one's reset once it's configured as
    /// recurring in App Store Connect.
    func submit(distance: Int) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(
            distance,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [Self.leaderboardID, Self.weeklyLeaderboardID]
        ) { error in
            if let error {
                print("Game Center score submission failed: \(error.localizedDescription)")
            }
        }
    }

    /// Presents Game Center's own leaderboard UI. `weekly: true` shows the
    /// recurring weekly board instead of the all-time one.
    func presentLeaderboard(weekly: Bool = false) {
        guard isAuthenticated,
              let rootViewController = UIApplication.shared.connectedScenes
                  .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                  .first
        else { return }

        let gcViewController = GKGameCenterViewController(
            leaderboardID: weekly ? Self.weeklyLeaderboardID : Self.leaderboardID,
            playerScope: .global,
            timeScope: weekly ? .week : .allTime
        )
        gcViewController.gameCenterDelegate = self
        rootViewController.present(gcViewController, animated: true)
    }

    private static func presentAuthViewController(_ viewController: UIViewController) {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first
        else { return }
        rootViewController.present(viewController, animated: true)
    }
}

extension GameCenterManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
