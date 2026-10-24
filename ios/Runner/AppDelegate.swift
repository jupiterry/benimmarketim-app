import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Google Maps anahtarı Dart'tan gelir (--dart-define=MAPS_API_KEY);
    // repoda tutulmaz. Bkz. lib/services/maps_config.dart
    if let registrar = self.registrar(forPlugin: "BenimMarketimMaps") {
      let channel = FlutterMethodChannel(
        name: "benimmarketim/maps", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        if call.method == "setApiKey", let key = call.arguments as? String, !key.isEmpty {
          GMSServices.provideAPIKey(key)
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
