import Cocoa

class IconGenerator {
    static func createMenuBarIcon() -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Create rounded rectangle stroke (no fill)
        let rect = NSRect(x: 1, y: 1, width: 16, height: 16)
        let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        
        // Stroke with dark color
        NSColor.controlTextColor.setStroke()
        path.lineWidth = 1.5
        path.stroke()
        
        // Draw "T" in dark color
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.controlTextColor
        ]
        
        let text = "T"
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2 - 1,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attributes)
        
        image.unlockFocus()
        
        // Make it a template image so it adapts to dark/light mode
        image.isTemplate = true
        
        return image
    }
}
