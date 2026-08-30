import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // SET DEFAULT WINDOW SIZE TO 1280x720 AND CENTER ON SCREEN
    let defaultWidth: CGFloat = 1280
    let defaultHeight: CGFloat = 720
    let screenSize = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1920, height: 1080)
    let width = min(defaultWidth, screenSize.width * 0.95)
    let height = min(defaultHeight, screenSize.height * 0.95)
    let rect = NSRect(
      x: (screenSize.width - width) / 2,
      y: (screenSize.height - height) / 2,
      width: width,
      height: height
    )
    self.setFrame(rect, display: true)
    self.minSize = NSSize(width: 960, height: 540)
    self.center()

    // FULLSCREEN BEHAVIOR
    self.collectionBehavior.insert(.fullScreenPrimary)

    // F11 KEY LISTENER FOR TOGGLING FULLSCREEN
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      if event.keyCode == 103 { // F11
        self?.toggleFullScreen(nil)
        return nil
      }
      return event
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
