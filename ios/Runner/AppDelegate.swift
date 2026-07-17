import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let messenger = controller.binaryMessenger

    // GraphHopper / Valhalla bridge
    FlutterMethodChannel(name: "ir.abtin.navigator/native_routing", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "isEngineReady":
          result(false) // set true when native engine is linked
        case "route":
          result(nil) // Dart A* fallback
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    // Vosk STT
    FlutterMethodChannel(name: "ir.abtin.navigator/vosk", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "isModelReady":
          result(false)
        case "start", "stop":
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    // CarPlay projection
    FlutterMethodChannel(name: "ir.abtin.navigator/car_projection", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "registerNavigationApp", "pushManeuver":
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Universal Links / custom scheme
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    // Dart DeeplinkParser handles abtin:// and geo:
    return super.application(app, open: url, options: options)
  }
}
