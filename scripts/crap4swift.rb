# Homebrew formula for crap4swift
# Install: brew install pproenca/tap/crap4swift
#
# To set up the tap:
#   1. Create repo github.com/pproenca/homebrew-tap
#   2. Copy this file to Formula/crap4swift.rb
#   3. Update the url and sha256 for each release
#
class Crap4swift < Formula
  desc "CRAP (Change Risk Anti-Pattern) scores for Swift code"
  homepage "https://github.com/pproenca/crap4swift"
  url "https://github.com/pproenca/crap4swift/releases/download/v0.1.0/crap4swift-macos-arm64.tar.gz"
  sha256 "PLACEHOLDER"
  license "MIT"

  depends_on :macos
  depends_on arch: :arm64

  def install
    bin.install "crap4swift"
  end

  test do
    assert_match "USAGE", shell_output("#{bin}/crap4swift --help", 0)
  end
end
