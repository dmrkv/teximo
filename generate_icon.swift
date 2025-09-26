#!/usr/bin/env swift

import Foundation

// This is a simple script to generate the app icon
// Run with: swift generate_icon.swift

print("Generating app icon...")

// Create a simple Swift script that will generate the icon
let iconScript = """
import Cocoa
import CoreGraphics

func createAppIcon() -> NSImage? {
    let size = NSSize(width: 1024, height: 1024)
    let image = NSImage(size: size)
    
    image.lockFocus()
    
    // Create the main rounded rectangle background (scaled down by 1px from top)
    let rect = NSRect(x: 64, y: 65, width: 896, height: 895) // Reduced height by 1px, moved down by 1px
    let path = NSBezierPath(roundedRect: rect, xRadius: 180, yRadius: 180)
    
    // Create gradient background (inverted - dark background)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0), // Dark gray
        NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)  // Very dark gray
    ])
    gradient?.draw(in: path, angle: 135)
    
    // Add subtle inner shadow effect
    let innerRect = NSRect(x: 80, y: 81, width: 864, height: 863) // Adjusted for new rect
    let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 160, yRadius: 160)
    NSColor.white.withAlphaComponent(0.1).setStroke() // Light stroke for dark background
    innerPath.lineWidth = 2
    innerPath.stroke()
    
    // Create the "T" with serif font (transparent/cutout effect)
    let font = NSFont(name: "Times New Roman", size: 650) ?? NSFont.systemFont(ofSize: 650, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.clear // Transparent T
    ]
    
    let text = "T"
    let textSize = text.size(withAttributes: attributes)
    let textRect = NSRect(
        x: (size.width - textSize.width) / 2,
        y: (size.height - textSize.height) / 2 - 20, // Keep T in same position
        width: textSize.width,
        height: textSize.height
    )
    
    // Create a mask for the T to cut it out of the background
    let maskImage = NSImage(size: size)
    maskImage.lockFocus()
    
    // Fill with black (opaque)
    NSColor.black.setFill()
    NSRect(origin: .zero, size: size).fill()
    
    // Draw T in white (transparent in final result)
    let maskAttributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    text.draw(in: textRect, withAttributes: maskAttributes)
    
    maskImage.unlockFocus()
    
    // Apply the mask to cut out the T
    let context = NSGraphicsContext.current?.cgContext
    context?.saveGState()
    
    // Draw the background
    gradient?.draw(in: path, angle: 135)
    
    // Apply mask to cut out T
    if let maskCGImage = maskImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        context?.clip(to: NSRect(origin: .zero, size: size), mask: maskCGImage)
        NSColor.clear.setFill() // This will be transparent
        NSRect(origin: .zero, size: size).fill()
    }
    
    context?.restoreGState()
    
    // Add subtle border
    NSColor.white.withAlphaComponent(0.2).setStroke() // Light border for dark background
    path.lineWidth = 4
    path.stroke()
    
    image.unlockFocus()
    return image
}

// Generate the icon
if let icon = createAppIcon() {
    // Save as PNG first
    let pngPath = "/Users/dima/Dev/teximo/Sources/Teximo/AppIcon.png"
    if let tiffData = icon.tiffRepresentation,
       let bitmapRep = NSBitmapImageRep(data: tiffData),
       let pngData = bitmapRep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: pngPath))
        print("Created AppIcon.png")
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
        let resizedIcon = NSImage(size: NSSize(width: size, height: size))
        resizedIcon.lockFocus()
        icon.draw(in: NSRect(origin: .zero, size: NSSize(width: size, height: size)), from: NSRect(origin: .zero, size: icon.size), operation: .sourceOver, fraction: 1.0)
        resizedIcon.unlockFocus()
        
        if let tiffData = resizedIcon.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            let filePath = "\\(iconsetPath)/\\(filename)"
            try? pngData.write(to: URL(fileURLWithPath: filePath))
            print("Created \\(filename)")
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
} else {
    print("Failed to create app icon")
}
"""

// Write the script to a temporary file and execute it
let tempScriptPath = "/tmp/generate_icon_temp.swift"
try? iconScript.write(toFile: tempScriptPath, atomically: true, encoding: .utf8)

let task = Process()
task.launchPath = "/usr/bin/swift"
task.arguments = [tempScriptPath]
task.launch()
task.waitUntilExit()

// Clean up
try? FileManager.default.removeItem(atPath: tempScriptPath)

print("Icon generation complete!")

