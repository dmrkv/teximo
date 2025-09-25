import Cocoa
import CoreGraphics

enum AppIconGenerator {
    static func createAppIcon() -> NSImage? {
        let size = NSSize(width: 1024, height: 1024)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Create the main rounded rectangle background
        let rect = NSRect(x: 64, y: 64, width: 896, height: 896)
        let path = NSBezierPath(roundedRect: rect, xRadius: 180, yRadius: 180)
        
        // Create gradient background
        let gradient = NSGradient(colors: [
            NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0), // Light gray
            NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)  // Very light gray
        ])
        gradient?.draw(in: path, angle: 135)
        
        // Add subtle inner shadow effect
        let innerRect = NSRect(x: 80, y: 80, width: 864, height: 864)
        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 160, yRadius: 160)
        NSColor.black.withAlphaComponent(0.05).setStroke()
        innerPath.lineWidth = 2
        innerPath.stroke()
        
        // Create the "T" with serif font
        let font = NSFont(name: "Times New Roman", size: 650) ?? NSFont.systemFont(ofSize: 650, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        
        let text = "T"
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2 - 20, // Better vertical centering
            width: textSize.width,
            height: textSize.height
        )
        
        // Add text shadow for depth
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSSize(width: 8, height: -8)
        shadow.shadowBlurRadius = 20
        
        var textAttributes = attributes
        textAttributes[.shadow] = shadow
        text.draw(in: textRect, withAttributes: textAttributes)
        
        // Add subtle border
        NSColor.black.withAlphaComponent(0.1).setStroke()
        path.lineWidth = 4
        path.stroke()
        
        image.unlockFocus()
        return image
    }
    
    static func createIconSet() {
        let icon = createAppIcon()
        guard let icon = icon else {
            print("Failed to create app icon")
            return
        }
        
        // Create the .iconset directory structure
        let iconsetPath = "/Users/dima/Dev/teximo/Sources/Teximo/AppIcon.iconset"
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true, attributes: nil)
        
        // Generate different sizes
        let sizes = [
            (16, "icon_16x16.png"),
            (32, "icon_16x16@2x.png"),
            (32, "icon_32x32.png"),
            (64, "icon_32x32@2x.png"),
            (128, "icon_128x128.png"),
            (256, "icon_128x128@2x.png"),
            (256, "icon_256x256.png"),
            (512, "icon_256x256@2x.png"),
            (512, "icon_512x512.png"),
            (1024, "icon_512x512@2x.png")
        ]
        
        for (size, filename) in sizes {
            let resizedIcon = resizeImage(icon, to: NSSize(width: size, height: size))
            if let tiffData = resizedIcon?.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                let filePath = "\(iconsetPath)/\(filename)"
                try? pngData.write(to: URL(fileURLWithPath: filePath))
                print("Created \(filename)")
            }
        }
        
        // Create the .icns file
        let icnsPath = "/Users/dima/Dev/teximo/Sources/Teximo/AppIcon.icns"
        let task = Process()
        task.launchPath = "/usr/bin/iconutil"
        task.arguments = ["-c", "icns", iconsetPath, "-o", icnsPath]
        task.launch()
        task.waitUntilExit()
        
        if task.terminationStatus == 0 {
            print("Successfully created AppIcon.icns")
        } else {
            print("Failed to create .icns file")
        }
    }
    
    private static func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage? {
        let resizedImage = NSImage(size: size)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
        resizedImage.unlockFocus()
        return resizedImage
    }
}

