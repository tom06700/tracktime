import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let navigationRegistrar = engineBridge.applicationRegistrar
    navigationRegistrar.register(
      NitrateNavigationFactory(messenger: navigationRegistrar.messenger()),
      withId: "nitrate/native_navigation"
    )
    FlutterMethodChannel(
      name: "nitrate/native_navigation",
      binaryMessenger: navigationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      guard call.method == "isAvailable" else {
        result(FlutterMethodNotImplemented)
        return
      }
      if #available(iOS 26.0, *) { result(true) } else { result(false) }
    }
    let channel = FlutterMethodChannel(
      name: "nitrate/notification_permission",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      let center = UNUserNotificationCenter.current()
      func replyStatus() {
        center.getNotificationSettings { settings in
          let value: String
          switch settings.authorizationStatus {
          case .notDetermined: value = "notDetermined"
          case .denied: value = "denied"
          case .authorized: value = "authorized"
          case .provisional: value = "provisional"
          default:
            if #available(iOS 14.0, *), settings.authorizationStatus == .ephemeral {
              value = "provisional"
            } else {
              value = "unavailable"
            }
          }
          DispatchQueue.main.async { result(value) }
        }
      }
      switch call.method {
      case "status": replyStatus()
      case "request":
        center.getNotificationSettings { settings in
          guard settings.authorizationStatus == .notDetermined else {
            replyStatus()
            return
          }
          center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
              DispatchQueue.main.async {
                result(FlutterError(code: "PERMISSION", message: error.localizedDescription, details: nil))
              }
            } else {
              replyStatus()
            }
          }
        }
      case "openSettings":
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
}
