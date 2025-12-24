class Meetingalert < Formula
  desc "Menu bar app that shows upcoming meetings and auto-opens Zoom links"
  homepage "https://github.com/yourusername/MeetingAlert"
  url "https://github.com/yourusername/MeetingAlert/releases/download/v1.0/MeetingAlert-1.0.zip"
  sha256 "1617ae374005cb3808256fa21d75f5b02d816151c1df6962468cd0a5a14f86dc"
  version "1.0"
  license "MIT"

  depends_on :macos => ">= :ventura" # macOS 13.0+

  def install
    # Copy the app to Applications folder
    prefix.install "MeetingAlert.app"
    
    # Create a symlink or wrapper script if needed
    bin.install_symlink prefix/"MeetingAlert.app/Contents/MacOS/MeetingAlert"
  end

  def caveats
    <<~EOS
      MeetingAlert has been installed to #{opt_prefix}/MeetingAlert.app
      
      To start using it:
      1. Open #{opt_prefix}/MeetingAlert.app
      2. Grant calendar permissions when prompted
      3. Look for the app icon in your menu bar
      
      The app will appear in your menu bar showing upcoming meetings.
      Click it to see a list of events and auto-open Zoom links.
    EOS
  end

  test do
    # Test that the app exists
    assert_predicate prefix/"MeetingAlert.app", :exist?
  end
end

