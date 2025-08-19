import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var localeChannel: FlutterMethodChannel?
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    
    // Setup locale channel
    if let mainWindow = NSApplication.shared.windows.first,
       let contentView = mainWindow.contentView,
       let flutterView = contentView.subviews.first(where: { $0 is FlutterView }) as? FlutterView {
      setupLocaleChannel(with: flutterView.engine.binaryMessenger)
    }
  }
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  private func setupLocaleChannel(with messenger: FlutterBinaryMessenger) {
    localeChannel = FlutterMethodChannel(
      name: "captainvfr/locale",
      binaryMessenger: messenger
    )
    
    localeChannel?.setMethodCallHandler { call, result in
      switch call.method {
      case "getSystemLanguage":
        let systemLanguage = self.getSystemLanguage()
        print("🌍 macOS System language detected: \(systemLanguage)")
        result(systemLanguage)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func getSystemLanguage() -> String {
    let preferredLanguages = NSLocale.preferredLanguages
    
    if let firstLanguage = preferredLanguages.first {
      // Extract just the language code (e.g., "en-US" becomes "en")
      let languageCode = String(firstLanguage.prefix(2))
      return languageCode
    }
    
    // Fallback to system locale
    let systemLocale = NSLocale.current
    if let languageCode = systemLocale.languageCode {
      return languageCode
    }
    
    // Ultimate fallback to English
    return "en"
  }
}
