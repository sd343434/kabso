import AVFoundation
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
    // D243: a live's second camera keeps the screen on (it sits untouched).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KabsoScreen") {
      let channel = FlutterMethodChannel(
        name: "com.kabso/screen", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        if call.method == "keepOn" {
          UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) ?? false
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    // v1.136-social (D384, CONVENTIONS §10.173.2): a picked video's frames at
    // given times for the VIP animated picture (AVAssetImageGenerator, zero
    // tolerance, the track's rotation applied). Off the main thread.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KabsoVideoFrames") {
      let channel = FlutterMethodChannel(
        name: "com.kabso/video_frames", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "extract" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          let times = args["timesMs"] as? [NSNumber],
          let outDir = args["outDir"] as? String
        else {
          result(FlutterError(code: "bad_args", message: nil, details: nil))
          return
        }
        let maxSide = (args["maxSide"] as? NSNumber)?.intValue ?? 0
        DispatchQueue.global(qos: .userInitiated).async {
          let paths = VideoFrames.extract(
            path: path, timesMs: times.map { $0.int64Value }, maxSide: maxSide, outDir: outDir)
          DispatchQueue.main.async {
            if let paths = paths {
              result(paths)
            } else {
              result(FlutterError(code: "unreadable", message: nil, details: nil))
            }
          }
        }
      }
    }
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

/// D384: the frames of a picked video at given times (milliseconds) — the
/// exact frame (zero tolerance), upright (the track's preferred transform),
/// at most `maxSide` on its longer side — written as JPEG files into
/// `outDir`; a time with no frame gives NSNull. Nil when the video cannot be
/// read.
enum VideoFrames {
  static func extract(path: String, timesMs: [Int64], maxSide: Int, outDir: String) -> [Any]? {
    let url = path.hasPrefix("file://") ? URL(string: path)! : URL(fileURLWithPath: path)
    let asset = AVURLAsset(url: url)
    guard !asset.tracks(withMediaType: .video).isEmpty else { return nil }
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    if maxSide > 0 {
      generator.maximumSize = CGSize(width: maxSide, height: maxSide)
    }
    let dir = URL(fileURLWithPath: outDir, isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    var out: [Any] = []
    for (i, ms) in timesMs.enumerated() {
      let time = CMTime(value: ms, timescale: 1000)
      guard let image = try? generator.copyCGImage(at: time, actualTime: nil),
        let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.9)
      else {
        out.append(NSNull())
        continue
      }
      let file = dir.appendingPathComponent("d384_frame_\(UUID().uuidString)_\(i).jpg")
      if (try? data.write(to: file)) != nil {
        out.append(file.path)
      } else {
        out.append(NSNull())
      }
    }
    return out
  }
}
