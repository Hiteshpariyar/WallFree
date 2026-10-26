import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var desktopChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerDesktopWallpaperChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  private func registerDesktopWallpaperChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.wallfree/desktop", binaryMessenger: messenger)
    desktopChannel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "applyWallpaper" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let path = call.arguments as? String, !path.isEmpty else {
        result(FlutterError(code: "invalid_arguments", message: "A wallpaper file path is required.", details: nil))
        return
      }

      let imageURL = URL(fileURLWithPath: path)
      do {
        for screen in NSScreen.screens {
          try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [:])
        }
        result(nil)
      } catch {
        result(FlutterError(code: "apply_failed", message: error.localizedDescription, details: nil))
      }
    }
  }
}
