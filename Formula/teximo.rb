class Teximo < Formula
  desc "macOS keyboard layout switching, transliteration, and native translation"
  homepage "https://github.com/dmrkv/teximo"
  url "https://github.com/dmrkv/teximo/releases/download/v1.8.0/Teximo-1.8.0.zip"
  sha256 "07bfddbda2bd634c044cb0eb66850e427e997d5b5da73568ba9bfd2a79a6172c"
  version "1.8.0"
  license "MIT"

  # Preserve the notarized app bundle during Homebrew's cleanup.
  skip_clean "Teximo.app"

  def install
    prefix.install "Teximo.app"
    (bin/"teximo").write <<~SH
      #!/bin/bash
      exec "#{prefix}/Teximo.app/Contents/MacOS/Teximo" "$@"
    SH
    (bin/"teximo").chmod 0755
  end

  def caveats
    <<~EOS
      Launch the Homebrew-managed app with:
        open "#{opt_prefix}/Teximo.app"

      Allow Accessibility access in System Settings → Privacy & Security.
      Quit any older manual or development copy before launching this one.

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
    assert_equal version.to_s, shell_output("#{bin}/teximo --version").strip
  end
end
