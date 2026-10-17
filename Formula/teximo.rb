class Teximo < Formula
  desc "macOS keyboard layout switching, transliteration, and native translation"
  homepage "https://github.com/dmrkv/teximo"
  url "https://github.com/dmrkv/teximo/releases/download/v1.8.0/Teximo-1.8.0.dmg"
  sha256 "dfb50487df3f28e8ed891d333129163e4097c1217d56816d65d65a7008bc46e2"
  version "1.8.0"
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
      Launch Teximo.app from #{prefix}/Teximo.app and allow Accessibility access
      in System Settings → Privacy & Security → Accessibility.

      Default shortcuts:
        ⌘⇧   Switch keyboard layouts
        ⌥⇧   Transliterate selected text
        ⌃⇧   Change text case
        ⌃⌥T  Translate selected text

      Configure shortcuts, keyboard layouts, and translation languages in Settings.
      Native translation requires macOS 15 or later.
    EOS
  end

  test do
    # Test that the app can be launched
    system "#{bin}/teximo", "--version"
  end
end
