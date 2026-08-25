import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    titlebarAppearsTransparent = false
    titleVisibility = .visible
    isOpaque = true
    backgroundColor = NSColor.windowBackgroundColor
    contentMinSize = NSSize(width: 800, height: 480)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
