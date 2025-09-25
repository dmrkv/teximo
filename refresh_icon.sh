#!/bin/bash

echo "Refreshing app icon..."

# Kill the app if running
pkill -x Teximo 2>/dev/null || true
sleep 1

# Remove from Accessibility if it exists
echo "Removing from Accessibility settings..."
osascript -e 'tell application "System Events" to tell process "System Settings" to if exists then quit'
sleep 1

# Clear icon cache (user level)
echo "Clearing icon cache..."
rm -rf ~/Library/Caches/com.apple.iconservices.store 2>/dev/null || true
rm -rf ~/Library/Caches/com.apple.iconservices 2>/dev/null || true

# Re-register the app
echo "Re-registering app with Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f ~/Library/Developer/Xcode/DerivedData/Teximo-gtmgabbepyjoeiahwbahginscqfi/Build/Products/Debug/Teximo.app

# Launch the app
echo "Launching app..."
open -n ~/Library/Developer/Xcode/DerivedData/Teximo-gtmgabbepyjoeiahwbahginscqfi/Build/Products/Debug/Teximo.app

echo "Done! Now go to System Settings > Privacy & Security > Accessibility and add Teximo again."
echo "The icon should now appear correctly."

