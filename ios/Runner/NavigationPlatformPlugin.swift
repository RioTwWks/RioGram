import Flutter
import UIKit

final class NavigationPlatformPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "riogram/navigation_platform",
      binaryMessenger: registrar.messenger()
    )
    let instance = NavigationPlatformPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configureTabBar":
      let args = call.arguments as? [String: Any]
      let isTranslucent = args?["isTranslucent"] as? Bool ?? false
      configureTabBar(isTranslucent: isTranslucent)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func configureTabBar(isTranslucent: Bool) {
    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundEffect = nil
    appearance.shadowColor = UIColor.separator

    let tabBar = UITabBar.appearance()
    tabBar.isTranslucent = isTranslucent
    tabBar.standardAppearance = appearance
    if #available(iOS 15.0, *) {
      tabBar.scrollEdgeAppearance = appearance
    }
  }
}
