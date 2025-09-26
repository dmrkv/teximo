import Cocoa

class IconGenerator {
    static func createMenuBarIcon() -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Create rounded rectangle with white fill (1px smaller)
        let rect = NSRect(x: 1, y: 2, width: 15, height: 14) // 1px smaller in both dimensions
        let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        
        // Fill with white color
        NSColor.white.setFill()
        path.fill()
        
        // Draw T in black (this will be the "cutout" effect)
        let font = NSFont.systemFont(ofSize: 12, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        
        let text = "T"
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2 - 0.5, // Move T 0.5px left for better centering
            y: (size.height - textSize.height) / 2, // Move T 1px up (removed the -1)
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attributes)
        
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
