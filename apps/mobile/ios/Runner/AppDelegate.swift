import Flutter
import Security
import UIKit

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
    // D223 (CONVENTIONS §10.75): the stable device id for «at most 2 accounts
    // created per device».
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KabsoDeviceId") {
      let channel = FlutterMethodChannel(
        name: "com.kabso/device_id", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        if call.method == "stableId" {
          result(DeviceId.stable())
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}

/// D223: a UUID kept in the Keychain (it survives deleting and reinstalling
/// the app, unlike `identifierForVendor` once no other app of the vendor is
/// left), seeded from `identifierForVendor` on first use. `ThisDeviceOnly`:
/// never moved to another phone by a backup. The app hashes it with a salt
/// before sending; the raw value never leaves the phone. Erasing the phone
/// gives a new one.
enum DeviceId {
  private static let service = "com.kabso.device-id"
  private static let account = "stable-id"

  static func stable() -> String? {
    if let saved = read() { return saved }
    let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    return write(id) ? id : (read() ?? id)
  }

  private static func read() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data, let id = String(data: data, encoding: .utf8), !id.isEmpty
    else { return nil }
    return id
  }

  private static func write(_ id: String) -> Bool {
    let attributes: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecValueData as String: Data(id.utf8),
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
  }
}
