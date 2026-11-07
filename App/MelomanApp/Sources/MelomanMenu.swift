import AppKit

/// Installs the standard AppKit edit commands into the responder chain.
/// Without a main menu, Cmd+V / Cmd+C may be ignored in NSTextField and NSTextView.
@MainActor
enum MelomanMenu {
    static func install() {
        let menu = NSMenu()
        addApplicationMenu(to: menu)
        addEditMenu(to: menu)
        NSApplication.shared.mainMenu = menu
    }

    private static func addApplicationMenu(to mainMenu: NSMenu) {
        let item = NSMenuItem(title: "Meloman", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Meloman")

        submenu.addItem(NSMenuItem(
            title: "О Meloman",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        ))
        submenu.addItem(.separator())
        submenu.addItem(NSMenuItem(
            title: "Выйти из Meloman",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        item.submenu = submenu
        mainMenu.addItem(item)
    }

    private static func addEditMenu(to mainMenu: NSMenu) {
        let item = NSMenuItem(title: "Правка", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Правка")

        // Nil target uses the current window's first responder and its field editor.
        submenu.addItem(command("Отменить", selector: "undo:", key: "z"))
        submenu.addItem(command("Повторить", selector: "redo:", key: "z", shift: true))
        submenu.addItem(.separator())
        submenu.addItem(command("Вырезать", selector: "cut:", key: "x"))
        submenu.addItem(command("Копировать", selector: "copy:", key: "c"))
        submenu.addItem(command("Вставить", selector: "paste:", key: "v"))
        submenu.addItem(command("Выделить всё", selector: "selectAll:", key: "a"))

        item.submenu = submenu
        mainMenu.addItem(item)
    }

    private static func command(
        _ title: String,
        selector: String,
        key: String,
        shift: Bool = false
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: Selector((selector)), keyEquivalent: key)
        item.target = nil
        item.keyEquivalentModifierMask = shift ? [.command, .shift] : [.command]
        return item
    }
}
