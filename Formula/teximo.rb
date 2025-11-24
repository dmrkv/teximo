class Teximo < Formula
  desc "A seamless macOS menu bar app for keyboard layout switching and text transliteration"
  homepage "https://github.com/dmrkv/teximo"
  url "https://github.com/dmrkv/teximo/releases/download/v1.2.2/Teximo-1.5.0.dmg"
  sha256 "da1d8079d227671957fee5a97832aee6bb8965ad543535f12696543fab4d7ce6"
  version "1.5.0"
  license "MIT"


  def install
    # Mount the DMG
    system "hdiutil", "attach", "-nobrowse", "-quiet", cached_download
    
    # Find the actual volume name (macOS may rename it to "Teximo 1", "Teximo 2", etc.)
    volume_name = Dir.glob("/Volumes/Teximo*").first
    if volume_name.nil?
      odie "Could not find mounted Teximo volume"
    end
    
    # Copy the app to the Applications folder
    system "cp", "-R", "#{volume_name}/Teximo.app", "#{prefix}/"
    
    # Create a symlink in /usr/local/bin for easy access
    bin.install_symlink "#{prefix}/Teximo.app/Contents/MacOS/Teximo" => "teximo"
    
    # Unmount the DMG
    system "hdiutil", "detach", "-quiet", volume_name
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
      
      🎯 Hotkeys:
      - ⌘+Shift: Switch keyboard layouts
      - Ctrl+Shift: Transliterate selected text
      
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
