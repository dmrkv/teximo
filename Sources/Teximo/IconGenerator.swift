import Cocoa

class IconGenerator {
    static func createMenuBarIcon() -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Create rounded rectangle with white fill (scaled down by 1px from top)
        let rect = NSRect(x: 1, y: 2, width: 16, height: 15) // Reduced height by 1px, moved down by 1px
        let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        
        // Fill with white color
        NSColor.white.setFill()
        path.fill()
        
        // Create a mask for the T to cut it out
        let maskImage = NSImage(size: size)
        maskImage.lockFocus()
        
        // Fill with black (opaque)
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw T in white (transparent in final result)
        let font = NSFont.systemFont(ofSize: 12, weight: .bold)
        let maskAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        
        let text = "T"
        let textSize = text.size(withAttributes: maskAttributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2 - 1, // Keep T in same position
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: maskAttributes)
        maskImage.unlockFocus()
        
        // Apply the mask to cut out the T
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        
        // Draw the white background
        NSColor.white.setFill()
        path.fill()
        
        // Apply mask to cut out T
        if let maskCGImage = maskImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context?.clip(to: NSRect(origin: .zero, size: size), mask: maskCGImage)
            NSColor.clear.setFill() // This will be transparent
            NSRect(origin: .zero, size: size).fill()
        }
        
        context?.restoreGState()
        
        // Add subtle border
        NSColor.black.withAlphaComponent(0.2).setStroke()
        path.lineWidth = 0.5
        path.stroke()
        
        image.unlockFocus()
        
        // Don't make it a template image since we want the specific white design
        image.isTemplate = false
        
        return image
    }
}
