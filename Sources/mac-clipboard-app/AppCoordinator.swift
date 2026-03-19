import AppKit
import Carbon.HIToolbox
import Combine
import CoreServices

@MainActor
final class AppCoordinator: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private lazy var store = ClipboardHistoryStore(maxEntries: preferences.historyLimit)
    private let monitor = PasteboardMonitor()
    private let preferences = PreferencesModel()
    private let hotKeyManager = HotKeyManager()
    private let loginItemManager = LoginItemManager()
    private lazy var serviceProvider = FilePathServiceProvider(preferences: preferences)
    private let permissionsWindow = PermissionsWindowController()
    private lazy var preferencesWindow = PreferencesWindowController(preferences: preferences) { [weak self] hotKey in
        self?.hotKeyManager.register(hotKey)
    }
    private lazy var popup = PopupWindowController(store: store) { [weak self] entry in
        guard let self else { return }
        self.applySelection(entry)
    }
    private var previousFrontmostApp: NSRunningApplication?
    private weak var loginItemMenuItem: NSMenuItem?
    private var cancellables = Set<AnyCancellable>()

    func start() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "sclip"
        statusItem.menu = makeMenu()
        self.statusItem = statusItem

        store.updateMaxEntries(preferences.historyLimit)
        store.loadFromDisk()
        monitor.onNewItems = { [weak self] items in
            guard let self else { return }
            let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            self.store.addSnapshot(from: items, sourceAppBundleIdentifier: sourceApp)
        }
        monitor.start()

        preferences.$historyLimit
            .sink { [weak self] limit in
                self?.store.updateMaxEntries(limit)
            }
            .store(in: &cancellables)

        preferences.$enableCopyFilePath
            .sink { [weak self] enabled in
                self?.updateServices(enabled: enabled)
            }
            .store(in: &cancellables)

        updateServices(enabled: preferences.enableCopyFilePath)

        LocalizationCenter.shared.$language
            .sink { [weak self] _ in
                guard let self else { return }
                self.statusItem?.menu = self.makeMenu()
            }
            .store(in: &cancellables)

        hotKeyManager.onTrigger = { [weak self] in
            guard let self else { return }
            self.previousFrontmostApp = NSWorkspace.shared.frontmostApplication
            let granted = PermissionsCenter.requestAccessibilityIfNeeded()
            if !granted {
                self.permissionsWindow.show()
            }
            self.popup.toggle()
        }
        hotKeyManager.register(preferences.hotKey)
    }

    func stop() {
        monitor.stop()
        hotKeyManager.unregister()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let openItem = NSMenuItem(title: L("menu.open_history"), action: #selector(openHistory), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let loginItem = NSMenuItem(title: L("menu.launch_at_login"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItemMenuItem = loginItem
        menu.addItem(loginItem)

        let settingsItem = NSMenuItem(title: L("menu.settings"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let permissionsItem = NSMenuItem(title: L("menu.permissions"), action: #selector(openPermissions), keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L("menu.quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func openHistory() {
        previousFrontmostApp = NSWorkspace.shared.frontmostApplication
        popup.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func openSettings() {
        preferencesWindow.show()
    }

    @objc private func openPermissions() {
        _ = PermissionsCenter.requestAccessibilityIfNeeded()
        permissionsWindow.show()
    }

    @objc private func toggleLaunchAtLogin() {
        let next = !loginItemManager.isEnabled()
        loginItemManager.setEnabled(next)
        updateLaunchAtLoginMenuItem()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateLaunchAtLoginMenuItem()
    }

    private func updateLaunchAtLoginMenuItem() {
        guard let item = loginItemMenuItem else { return }
        let enabled = loginItemManager.isEnabled()
        item.state = enabled ? .on : .off
        item.isEnabled = loginItemManager.availability == .ready
        if loginItemManager.availability == .requiresAppBundle {
            item.title = L("menu.launch_at_login_requires_app")
        } else {
            item.title = L("menu.launch_at_login")
        }
    }

    private func updateServices(enabled: Bool) {
        if enabled {
            registerServices()
            NSApp.servicesProvider = serviceProvider
        } else {
            NSApp.servicesProvider = nil
        }
        NSUpdateDynamicServices()
    }

    private func registerServices() {
        let url = Bundle.main.bundleURL as CFURL
        LSRegisterURL(url, true)
    }

    private func applySelection(_ entry: ClipboardHistoryEntry) {
        store.writeEntryToPasteboard(entry)
        monitor.ignoreCurrentChangeCount()

        if let app = previousFrontmostApp {
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }

        if preferences.autoPasteAfterSelection {
            if PermissionsCenter.isAccessibilityGranted() {
                KeystrokeSender.pasteCommandV()
            } else {
                permissionsWindow.show()
            }
        }
    }
}
