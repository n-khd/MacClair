import SwiftUI

#if canImport(Sparkle)
import Sparkle

/// Contrôleur de mise à jour Sparkle.
///
/// Le code n'est compilé que lorsque `Sparkle.framework` est présent au moment de la compilation
/// (`SPARKLE_FRAMEWORK_DIR` dans `build-app.sh`). Une compilation locale sans le framework reste donc
/// possible : l'application se lance normalement, simplement sans recherche de mises à jour.
@MainActor
final class UpdateController: ObservableObject {
    private let controller: SPUStandardUpdaterController

    init() {
        // startingUpdater: true active la vérification automatique décrite par Info.plist
        // (SUFeedURL, SUPublicEDKey, SUEnableAutomaticChecks).
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
#endif
