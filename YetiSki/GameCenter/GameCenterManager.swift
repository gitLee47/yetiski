import GameKit
import UIKit

/// Handles Game Center authentication and the "best distance" leaderboard.
///
/// Setup required before this does anything useful:
/// 1. In App Store Connect, add a Game Center leaderboard to this app with the
///    identifier below (`leaderboardID`).
/// 2. Sign in with a sandbox Game Center account on the test device/simulator.
/// Until then, authentication silently fails and score submission is skipped —
/// gameplay is unaffected either way.
final class GameCenterManager: NSObject {
    static let shared = GameCenterManager()

    /// Must match the leaderboard identifier configured in App Store Connect.
    static let leaderboardID = "com.lijulee.yetiski.bestdistance"

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

    func submit(distance: Int) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(
            distance,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [Self.leaderboardID]
        ) { error in
            if let error {
                print("Game Center score submission failed: \(error.localizedDescription)")
            }
        }
    }

    /// Presents Game Center's own leaderboard UI.
    func presentLeaderboard() {
        guard isAuthenticated,
              let rootViewController = UIApplication.shared.connectedScenes
                  .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                  .first
        else { return }

        let gcViewController = GKGameCenterViewController(
            leaderboardID: Self.leaderboardID,
            playerScope: .global,
            timeScope: .allTime
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
