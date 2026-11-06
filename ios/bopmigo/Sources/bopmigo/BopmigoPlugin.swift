import Flutter
import UIKit

/// The small native part of Bopmigo for Flutter: app and device details, and screenshot detection.
public class BopmigoPlugin: NSObject, FlutterPlugin {
  private var channel: FlutterMethodChannel?
  private var observer: NSObjectProtocol?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "bopmigo", binaryMessenger: registrar.messenger())
    let instance = BopmigoPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "info":
      let info = Bundle.main.infoDictionary ?? [:]
      result([
        "version": info["CFBundleShortVersionString"] as? String ?? "?",
        "build": info["CFBundleVersion"] as? String ?? "?",
        "name": info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? "App",
        "appId": Bundle.main.bundleIdentifier ?? "",
        "device": BopmigoPlugin.model(),
        "os": "iOS \(UIDevice.current.systemVersion)",
        "tester": BopmigoPlugin.isTester,
        "language": Locale.preferredLanguages.first ?? Locale.current.identifier,
        "timezone": TimeZone.current.identifier,
      ])
    case "watchScreenshots":
      let on = (call.arguments as? Bool) ?? false
      if let observer { NotificationCenter.default.removeObserver(observer); self.observer = nil }
      if on {
        observer = NotificationCenter.default.addObserver(forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main) { [weak self] _ in
          self?.channel?.invokeMethod("screenshot", arguments: nil)
        }
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Debug builds and TestFlight. People who install from the App Store are not testers.
  static var isTester: Bool {
    #if DEBUG
    return true
    #else
    return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    #endif
  }

  static func model() -> String {
    var info = utsname()
    uname(&info)
    let id = withUnsafeBytes(of: &info.machine) { raw in String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self) }
    if id == "x86_64" || id == "arm64" { return "\(UIDevice.current.model) (Simulator)" }
    return "\(UIDevice.current.model) (\(id))"
  }
}
