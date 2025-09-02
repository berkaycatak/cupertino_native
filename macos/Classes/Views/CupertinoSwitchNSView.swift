import FlutterMacOS
import Cocoa
import SwiftUI

class CupertinoSwitchNSView: NSView {
  private let channel: FlutterMethodChannel
  private let hostingController: NSHostingController<CupertinoSwitchView>

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeSwitch_\(viewId)", binaryMessenger: messenger)

    var initialValue: Bool = false
    var enabled: Bool = true
    var isDark: Bool = false
    if let dict = args as? [String: Any] {
      if let v = dict["value"] as? NSNumber { initialValue = v.boolValue }
      if let v = dict["enabled"] as? NSNumber { enabled = v.boolValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
    }

    var channelRef: FlutterMethodChannel? = nil
    let model = SwitchModel(value: initialValue, enabled: enabled) { newValue in
      channelRef?.invokeMethod("valueChanged", arguments: ["value": newValue])
    }
    self.hostingController = NSHostingController(rootView: CupertinoSwitchView(model: model))
    super.init(frame: .zero)

    channelRef = self.channel

    hostingController.view.wantsLayer = true
    hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
    hostingController.view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    addSubview(hostingController.view)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setValue":
        if let args = call.arguments as? [String: Any], let value = (args["value"] as? NSNumber)?.boolValue {
          model.value = value
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing value", details: nil)) }
      case "setEnabled":
        if let args = call.arguments as? [String: Any], let enabled = (args["enabled"] as? NSNumber)?.boolValue {
          model.enabled = enabled
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          self.hostingController.view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) {
    return nil
  }
}
