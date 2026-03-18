import AppKit
import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager {
    enum Availability {
        case ready
        case requiresAppBundle
    }

    private let bundleIDFallback: String

    init(bundleIDFallback: String = "com.example.ClipHistory") {
        self.bundleIDFallback = bundleIDFallback
    }

    var availability: Availability {
        isRunningFromAppBundle ? .ready : .requiresAppBundle
    }

    func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return launchAgentExists()
    }

    func setEnabled(_ enabled: Bool) {
        guard availability == .ready else {
            NSSound.beep()
            return
        }

        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSSound.beep()
            }
            return
        }

        if enabled {
            installLaunchAgent()
        } else {
            uninstallLaunchAgent()
        }
    }

    private var isRunningFromAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    private func launchAgentExists() -> Bool {
        guard let url = launchAgentPlistURL() else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func installLaunchAgent() {
        guard let url = launchAgentPlistURL() else { return }
        guard let appPath = Bundle.main.bundleURL.path.removingPercentEncoding else { return }

        let dict: [String: Any] = [
            "Label": launchAgentLabel(),
            "ProgramArguments": ["/usr/bin/open", "-a", appPath],
            "RunAtLoad": true,
            "KeepAlive": false,
            "LimitLoadToSessionType": "Aqua",
        ]

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
            _ = runLaunchctl(["bootout", "gui/\(getuid())", url.path])
            _ = runLaunchctl(["bootstrap", "gui/\(getuid())", url.path])
        } catch {
            NSSound.beep()
        }
    }

    private func uninstallLaunchAgent() {
        guard let url = launchAgentPlistURL() else { return }
        _ = runLaunchctl(["bootout", "gui/\(getuid())", url.path])
        try? FileManager.default.removeItem(at: url)
    }

    private func launchAgentPlistURL() -> URL? {
        guard let bundleID = Bundle.main.bundleIdentifier ?? bundleIDFallback as String? else { return nil }
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
        return dir.appendingPathComponent("\(bundleID).plist", isDirectory: false)
    }

    private func launchAgentLabel() -> String {
        Bundle.main.bundleIdentifier ?? bundleIDFallback
    }

    private func runLaunchctl(_ args: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = args
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return 1
        }
    }
}

