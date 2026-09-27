import Flutter
import UIKit
import receive_sharing_intent

// Flutter's scene lifecycle must forward both cold and warm share launches.
final class ShareSceneDelegate: FlutterSceneDelegate {
    private func consumePendingShare() {
        guard let defaults = UserDefaults(suiteName: "group.com.tbt.social.share"),
              defaults.data(forKey: "ShareKey") != nil,
              let url = URL(string: "ShareMedia-com.tbt.social:share") else { return }
        // Also handles a user opening TBT manually when iOS declines the
        // extension's request to open the containing app.
        _ = SwiftReceiveSharingIntentPlugin.instance.application(UIApplication.shared, didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey.url: url])
        defaults.removeObject(forKey: "ShareKey")
        defaults.removeObject(forKey: "ShareMessageKey")
    }
    override func sceneDidBecomeActive(_ scene: UIScene) {
        super.sceneDidBecomeActive(scene)
        consumePendingShare()
    }
    override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        for item in connectionOptions.urlContexts where SwiftReceiveSharingIntentPlugin.instance.hasMatchingSchemePrefix(url: item.url) {
            _ = SwiftReceiveSharingIntentPlugin.instance.application(UIApplication.shared, didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey.url: item.url])
        }
        consumePendingShare()
        super.scene(scene, willConnectTo: session, options: connectionOptions)
    }
    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for item in URLContexts where SwiftReceiveSharingIntentPlugin.instance.hasMatchingSchemePrefix(url: item.url) {
            _ = SwiftReceiveSharingIntentPlugin.instance.application(UIApplication.shared, open: item.url)
        }
        super.scene(scene, openURLContexts: URLContexts)
    }
}
