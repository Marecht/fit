class Fit < Formula
  desc "Git workflow tool with safety checks and simplified commands"
  homepage "https://github.com/marecht/fit"
  url "https://github.com/marecht/fit/archive/refs/heads/main.tar.gz"
  version "1.0.0"
  sha256 ""
  license "MIT"

  depends_on "git"

  def install
    bin.install "fit.sh" => "fit"
    prefix.install "config"
    prefix.install "_fit"
    prefix.install "fit.bash"
    prefix.install "AGENT_DOCUMENTATION.md"
  end

  def post_install
    ohai "Run 'fit setup' to configure git identity, shell completion, and GitHub integration"
  end

  test do
    system "#{bin}/fit", "--help"
  end
end
