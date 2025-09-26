#!/bin/bash

# Script to help upload DMG to GitHub release
# You'll need to do this manually through the GitHub web interface

echo "🚀 Teximo DMG Upload Helper"
echo "=========================="
echo ""
echo "📁 DMG file location:"
echo "   $(pwd)/build/Teximo-1.0.0-signed.dmg"
echo ""
echo "📏 File size:"
ls -lh build/Teximo-1.0.0-signed.dmg
echo ""
echo "🌐 GitHub Release URL:"
echo "   https://github.com/dmrkv/teximo/releases/tag/v1.0.0"
echo ""
echo "📋 Steps to upload:"
echo "1. Go to the GitHub release URL above"
echo "2. Click 'Edit' (pencil icon)"
echo "3. Scroll down to 'Attach binaries'"
echo "4. Drag and drop the DMG file from:"
echo "   $(pwd)/build/Teximo-1.0.0-signed.dmg"
echo "5. Click 'Update release'"
echo ""
echo "✅ Done! Your friends can now download the app with clear instructions."
