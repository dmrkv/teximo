import Cocoa

class AccessibilityPermissionWindow: NSWindowController {
    private var permissionWindow: NSWindow!
    private var onPermissionGranted: (() -> Void)?
    private var permissionCheckTimer: Timer?
    
    init(onPermissionGranted: (() -> Void)? = nil) {
        self.onPermissionGranted = onPermissionGranted
        super.init(window: nil)
        setupWindow()
        startPermissionChecking()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        // Create a beautiful window
        permissionWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        permissionWindow.title = "Teximo"
        permissionWindow.titlebarAppearsTransparent = true
        permissionWindow.isMovableByWindowBackground = true
        permissionWindow.center()
        permissionWindow.level = .floating
        
        // Create the main view
        let mainView = NSView()
        mainView.wantsLayer = true
        mainView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        mainView.layer?.cornerRadius = 12
        
        // Create the content view
        let contentView = createContentView()
        mainView.addSubview(contentView)
        
        // Set up constraints
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: mainView.topAnchor, constant: 20),
            contentView.leadingAnchor.constraint(equalTo: mainView.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: mainView.trailingAnchor, constant: -20),
            contentView.bottomAnchor.constraint(equalTo: mainView.bottomAnchor, constant: -20)
        ])
        
        permissionWindow.contentView = mainView
        self.window = permissionWindow
    }
    
    private func createContentView() -> NSView {
        let containerView = NSView()
        
        // App icon - use the main app icon instead of menu bar icon
        let iconView = NSImageView()
        if let appIcon = NSImage(named: "AppIcon") {
            iconView.image = appIcon
        } else {
            // Fallback to a simple "T" icon with black text on white background
            let iconSize = NSSize(width: 64, height: 64)
            let iconImage = NSImage(size: iconSize)
            iconImage.lockFocus()
            
            // White background
            NSColor.white.setFill()
            NSRect(origin: .zero, size: iconSize).fill()
            
            // Black "T" in the center
            let font = NSFont.systemFont(ofSize: 48, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            let text = "T"
            let textSize = text.size(withAttributes: attributes)
            let textRect = NSRect(
                x: (iconSize.width - textSize.width) / 2,
                y: (iconSize.height - textSize.height) / 2 - 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
            
            iconImage.unlockFocus()
            iconView.image = iconImage
        }
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconView)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Accessibility Permission Required")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Description
        let descriptionLabel = NSTextField(wrappingLabelWithString: """
        Teximo needs accessibility permissions to:
        • Switch keyboard layouts with ⌘+Shift
        • Transliterate text with Ctrl+Shift
        
        Please follow the steps below to enable these permissions.
        """)
        descriptionLabel.font = NSFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.alignment = .left
        descriptionLabel.maximumNumberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(descriptionLabel)
        
        // Steps container
        let stepsContainer = createStepsContainer()
        containerView.addSubview(stepsContainer)
        
        // Buttons container
        let buttonsContainer = createButtonsContainer()
        containerView.addSubview(buttonsContainer)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Icon
            iconView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            iconView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // Description
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // Steps
            stepsContainer.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 20),
            stepsContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stepsContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // Buttons
            buttonsContainer.topAnchor.constraint(equalTo: stepsContainer.bottomAnchor, constant: 20),
            buttonsContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            buttonsContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            buttonsContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    private func createStepsContainer() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let steps = [
            "1. Click 'Open System Settings' below",
            "2. Navigate to Privacy & Security → Accessibility",
            "3. Find 'Teximo' in the list and check the box"
        ]
        
        var previousView: NSView?
        
        for (index, step) in steps.enumerated() {
            let stepView = createStepView(number: index + 1, text: step)
            container.addSubview(stepView)
            
            NSLayoutConstraint.activate([
                stepView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                stepView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])
            
            if let previous = previousView {
                stepView.topAnchor.constraint(equalTo: previous.bottomAnchor, constant: 16).isActive = true
            } else {
                stepView.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
            }
            
            previousView = stepView
        }
        
        if let last = previousView {
            last.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
        }
        
        return container
    }
    
    private func createStepView(number: Int, text: String) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Step text (no number circle, just the text)
        let textLabel = NSTextField(labelWithString: text)
        textLabel.font = NSFont.systemFont(ofSize: 13)
        textLabel.textColor = .labelColor
        textLabel.alignment = .left
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textLabel)
        
        NSLayoutConstraint.activate([
            // Text
            textLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            textLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            textLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        return container
    }
    
    private func createButtonsContainer() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Open System Settings button
        let openSettingsButton = NSButton(title: "Open System Settings", target: self, action: #selector(openSystemSettings))
        openSettingsButton.bezelStyle = .rounded
        openSettingsButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        openSettingsButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(openSettingsButton)
        
        // Check Again button (fallback if auto-detection doesn't work)
        let checkAgainButton = NSButton(title: "Check Again", target: self, action: #selector(checkPermissionAgain))
        checkAgainButton.bezelStyle = .rounded
        checkAgainButton.font = NSFont.systemFont(ofSize: 14)
        checkAgainButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(checkAgainButton)
        
        // Quit button
        let quitButton = NSButton(title: "Quit", target: self, action: #selector(quitApp))
        quitButton.bezelStyle = .rounded
        quitButton.font = NSFont.systemFont(ofSize: 14)
        quitButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(quitButton)
        
        NSLayoutConstraint.activate([
            // Open Settings button
            openSettingsButton.topAnchor.constraint(equalTo: container.topAnchor),
            openSettingsButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            openSettingsButton.widthAnchor.constraint(equalToConstant: 180),
            openSettingsButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Check Again button
            checkAgainButton.topAnchor.constraint(equalTo: openSettingsButton.bottomAnchor, constant: 8),
            checkAgainButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            checkAgainButton.widthAnchor.constraint(equalToConstant: 120),
            checkAgainButton.heightAnchor.constraint(equalToConstant: 28),
            
            // Quit button
            quitButton.topAnchor.constraint(equalTo: openSettingsButton.bottomAnchor, constant: 8),
            quitButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            quitButton.widthAnchor.constraint(equalToConstant: 80),
            quitButton.heightAnchor.constraint(equalToConstant: 28),
            
            // Container height
            container.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        return container
    }
    
    @objc private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func checkPermissionAgain() {
        if AccessibilityHelper.ensurePermission(promptIfNeeded: false) {
            // Permission granted! Restart the app
            print("[Teximo] Permission granted, restarting app...")
            restartApp()
        } else {
            // Still no permission, show a brief message
            let alert = NSAlert()
            alert.messageText = "Permission Not Yet Granted"
            alert.informativeText = "Please make sure to check the box next to 'Teximo' in the Accessibility settings and try again."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func restartApp() {
        // Close the permission window
        permissionWindow.close()
        
        // Get the current app path
        let appPath = Bundle.main.bundlePath
        
        // Create a script to restart the app
        let script = """
        #!/bin/bash
        sleep 1
        open "\(appPath)"
        """
        
        // Write script to temporary file
        let tempScriptPath = "/tmp/teximo_restart.sh"
        try? script.write(toFile: tempScriptPath, atomically: true, encoding: .utf8)
        
        // Make script executable
        let task = Process()
        task.launchPath = "/bin/chmod"
        task.arguments = ["+x", tempScriptPath]
        task.launch()
        task.waitUntilExit()
        
        // Execute restart script
        let restartTask = Process()
        restartTask.launchPath = "/bin/bash"
        restartTask.arguments = [tempScriptPath]
        restartTask.launch()
        
        // Quit current instance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    func showWindow() {
        permissionWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func startPermissionChecking() {
        // Check permissions every 2 seconds
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPermissionStatus()
        }
    }
    
    private func checkPermissionStatus() {
        if AccessibilityHelper.ensurePermission(promptIfNeeded: false) {
            // Permission granted! Stop checking and restart app
            print("[Teximo] Permission detected, restarting app...")
            permissionCheckTimer?.invalidate()
            permissionCheckTimer = nil
            restartApp()
        }
    }
    
    deinit {
        permissionCheckTimer?.invalidate()
    }
}
