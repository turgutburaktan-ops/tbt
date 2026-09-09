import Flutter
import UIKit
import receive_sharing_intent

// Flutter's scene lifecycle must forward both cold and warm share launches.
final class ShareSceneDelegate: FlutterSceneDelegate {
    override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        for item in connectionOptions.urlContexts where SwiftReceiveSharingIntentPlugin.instance.hasMatchingSchemePrefix(url: item.url) {
            _ = SwiftReceiveSharingIntentPlugin.instance.application(UIApplication.shared, didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey.url: item.url])
        }
        super.scene(scene, willConnectTo: session, options: connectionOptions)
    }
    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for item in URLContexts where SwiftReceiveSharingIntentPlugin.instance.hasMatchingSchemePrefix(url: item.url) {
            _ = SwiftReceiveSharingIntentPlugin.instance.application(UIApplication.shared, open: item.url)
        }
        super.scene(scene, openURLContexts: URLContexts)
    }
}
