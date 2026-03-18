import AppKit

extension NSImage {
    func resizedToFit(maxSize: CGFloat) -> NSImage {
        let originalSize = size
        if originalSize.width <= maxSize, originalSize.height <= maxSize {
            return self
        }

        let ratio = min(maxSize / originalSize.width, maxSize / originalSize.height)
        let newSize = CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio)

        let img = NSImage(size: newSize)
        img.lockFocus()
        defer { img.unlockFocus() }
        draw(in: CGRect(origin: .zero, size: newSize), from: CGRect(origin: .zero, size: originalSize), operation: .copy, fraction: 1)
        return img
    }
}

