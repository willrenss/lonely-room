// CrossPlatform.swift
// Shared UIKit ↔ AppKit compatibility layer
// Di iOS: UIKit sudah tersedia secara native, tidak perlu typealias
// Di macOS (jika ever built natively): gunakan AppKit alias

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit

// MARK: - UIKit → AppKit typealias (macOS only)
typealias UIColor = NSColor
typealias UIImage = NSImage

struct UIGraphicsImageRenderer {
    let size: CGSize
    init(size: CGSize) { self.size = size }

    func image(actions: (UIGraphicsImageRendererContext) -> Void) -> NSImage {
        let img = NSImage(size: size)
        img.lockFocus()
        let ctx = NSGraphicsContext.current!.cgContext
        actions(UIGraphicsImageRendererContext(cgContext: ctx, size: size))
        img.unlockFocus()
        return img
    }
}

struct UIGraphicsImageRendererContext {
    let cgContext: CGContext
    let size: CGSize
}
#endif
