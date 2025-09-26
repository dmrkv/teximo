#!/bin/bash

# Teximo Installation Script
# This script installs Teximo using Homebrew

set -e

echo "🍺 Installing Teximo via Homebrew..."
echo "=================================="

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew is not installed. Please install Homebrew first:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# Install Teximo from the Homebrew tap
echo "📦 Installing Teximo from Homebrew tap..."
brew install dmrkv/teximo/teximo

echo ""
echo "✅ Teximo installed successfully!"
echo ""
echo "🚨 IMPORTANT - Security Warning Fix:"
echo "When you first launch Teximo, macOS will show a security warning:"
echo "> \"Teximo\" cannot be opened because the developer cannot be verified."
echo ""
echo "To fix this, you MUST:"
echo "1. Right-click on Teximo.app in Applications folder"
echo "2. Select \"Open\" from the context menu"
echo "3. Click \"Open\" in the security dialog"
echo ""
echo "This is a one-time step - after this, Teximo will launch normally!"
echo ""
echo "🎉 You can now launch Teximo from Applications or run 'teximo' from the command line."
