class Meetingalert < Formula
  desc "Menu bar app that shows upcoming meetings and auto-opens Zoom links"
  homepage "https://github.com/AkhilaShanmukha/MeetingAlert"
  url "https://github.com/AkhilaShanmukha/MeetingAlert/releases/download/v1.1/MeetingAlert-1.1.zip"
  sha256 "803589269e6dea59766e6e8c8c16ac665789561bf8c28f69ed9d950e4f41bdb7"
  version "1.1"
  license "MIT"

  depends_on macos: :ventura # macOS 13.0+

  def install
    # Homebrew extracts the ZIP so that buildpath IS the MeetingAlert.app directory
    # (buildpath contains Contents/, .brew_home, etc.)
    # Verify it's an app bundle by checking for Contents directory
    unless (buildpath/"Contents").directory?
      raise "Not a valid app bundle. Contents of #{buildpath}: #{buildpath.children.map(&:basename).join(', ')}"
    end
    
    # Copy buildpath (which is the app bundle) to prefix
    prefix.mkpath
    cp_r buildpath, prefix/"MeetingAlert.app"
  end

  def caveats
    <<~EOS
      MeetingAlert has been installed to #{opt_prefix}/MeetingAlert.app
      
      To start using it:
      1. Run: open #{opt_prefix}/MeetingAlert.app
      2. Grant calendar permissions when prompted
      3. Look for the app icon in your menu bar
      
      Optional: To add to Applications folder:
        ln -sf #{opt_prefix}/MeetingAlert.app /Applications/MeetingAlert.app
      
      The app will appear in your menu bar showing upcoming meetings.
      Click it to see a list of events and auto-open Zoom links.
    EOS
  end

  test do
    # Test that the app exists
    assert_predicate prefix/"MeetingAlert.app", :exist?
  end
end

