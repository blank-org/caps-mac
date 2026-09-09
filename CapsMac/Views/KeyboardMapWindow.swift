import AppKit
import WebKit

/// In-app window that shows the Caps keyboard map SVG (Windows Caps+=).
final class KeyboardMapWindowController: NSWindowController, NSWindowDelegate {
    static let shared = KeyboardMapWindowController()

    private var webView: WKWebView?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 430),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Caps Keyboard Map"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 720, height: 280)
        window.center()
        super.init(window: window)
        window.delegate = self

        let webView = WKWebView(frame: window.contentView?.bounds ?? .zero)
        webView.autoresizingMask = [.width, .height]
        window.contentView = webView
        self.webView = webView
        loadMap()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showMap() {
        NSApp.activate(ignoringOtherApps: true)
        loadMap()
        window?.makeKeyAndOrderFront(nil)
    }

    private func loadMap() {
        guard let url = Bundle.main.url(forResource: "keyboard-map-tks", withExtension: "svg") else {
            fputs("CapsMac: keyboard-map-tks.svg is missing from the app bundle.\n", stderr)
            return
        }
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
          html, body { margin: 0; height: 100%; background: #505050; }
          body { display: flex; align-items: center; justify-content: center; }
          img { width: 96%; height: auto; }
        </style>
        </head>
        <body>
          <img src="keyboard-map-tks.svg" alt="Caps keyboard map">
        </body>
        </html>
        """
        webView?.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    }
}
