import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    enableFirebaseDebugViewForDev()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // Enables Firebase Analytics DebugView when the active GoogleService-Info.plist
  // points at the dev Firebase project. Equivalent to launching with `-FIRDebugEnabled`,
  // but works for `flutter run --flavor dev` (which doesn't pass scheme args).
  private func enableFirebaseDebugViewForDev() {
    guard
      let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
      let dict = NSDictionary(contentsOfFile: path),
      let projectId = dict["PROJECT_ID"] as? String,
      projectId.hasSuffix("-dev")
    else { return }
    UserDefaults.standard.set(true, forKey: "/google/firebase/debug_mode")
    UserDefaults.standard.set(true, forKey: "/google/measurement/debug_mode")
  }
}
