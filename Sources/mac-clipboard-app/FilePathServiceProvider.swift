import AppKit

@MainActor
final class FilePathServiceProvider: NSObject {
    private let preferences: PreferencesModel

    init(preferences: PreferencesModel) {
        self.preferences = preferences
    }

    @objc func copyFilePath(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard preferences.enableCopyFilePath else {
            error.pointee = "Disabled"
            return
        }
        var paths: [String] = []
        if let objects = pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            paths = objects.map { $0.path }
        }
        if paths.isEmpty, let list = pboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            paths = list
        }
        guard !paths.isEmpty else {
            error.pointee = "No file path found"
            return
        }
        let text = paths.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
