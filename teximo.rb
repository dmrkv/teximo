class Teximo < Formula
  desc "A beautiful macOS menu bar app for keyboard layout switching and text transliteration"
  homepage "https://github.com/dmrkv/teximo"
  url "https://github.com/dmrkv/teximo/releases/download/v1.0.0/Teximo-1.0.0-signed.dmg"
  sha256 "d4d93378627bd2f47417211fe63dd0763dcb68fed7587567dd16bddf588b2d4d"
  version "1.0.0"
  license "MIT"

  depends_on :macos => ">= :ventura"

  def install
    # Mount the DMG
    system "hdiutil", "attach", "-nobrowse", "-quiet", cached_download
    
    # Copy the app to the Applications folder
    system "cp", "-R", "/Volumes/Teximo/Teximo.app", "#{prefix}/"
    
    # Create a symlink in /usr/local/bin for easy access
    bin.install_symlink "#{prefix}/Teximo.app/Contents/MacOS/Teximo" => "teximo"
    
    # Unmount the DMG
    system "hdiutil", "detach", "-quiet", "/Volumes/Teximo"
  end

  def caveats
    <<~EOS
      🚨 IMPORTANT - Security Warning Fix:
      
      When you first try to launch Teximo, macOS will show a security warning:
      > "Teximo" cannot be opened because the developer cannot be verified.
      
      To fix this, you MUST:
      - Right-click on Teximo.app in Applications folder
      - Select "Open" from the context menu
      - Click "Open" in the security dialog
      
      This is a one-time step - after this, Teximo will launch normally!
      
      Teximo has been installed to:
        #{prefix}/Teximo.app
      
      You can also run it from the command line:
        teximo
    EOS
  end

  test do
    # Test that the app can be launched
    system "#{bin}/teximo", "--version"
  end
end
