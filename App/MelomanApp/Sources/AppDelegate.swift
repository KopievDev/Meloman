import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1160, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Meloman"
        window.minSize = NSSize(width: 900, height: 610)
        window.center()
        window.contentViewController = WorkspaceViewController()
        window.makeKeyAndOrderFront(nil)
        mainWindow = window

        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }
}
