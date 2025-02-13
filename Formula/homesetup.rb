class Homesetup < Formula
  desc "HomeSetup - The ultimate Terminal experience"
  homepage "https://github.com/HS-Teams/homebrew-homesetup"
  url "https://github.com/HS-Teams/homebrew-homesetup/archive/v1.8.22.tar.gz"
  sha256 "5a2f2c42f0038167fccdaf59cc8af59cc3aa7c2c2d0f3532e5724098196bff7f"
  license "MIT"
  head "https://github.com/HS-Teams/homebrew-homesetup.git", branch: "master"

  depends_on "git"
  depends_on "curl"
  depends_on "ruby"
  depends_on "rsync"
  depends_on "mkdir"
  depends_on "vim"
  depends_on "gawk"
  depends_on "make"
  depends_on "gcc"
  depends_on "hexdump"
  depends_on "tree"
  depends_on "pcregrep"
  depends_on "gpg"
  depends_on "base64"
  depends_on "perl"
  depends_on "ruby"
  depends_on "python@3.11"
  depends_on "pip3"
  depends_on "pbcopy"
  depends_on "jq"
  depends_on "sqlite3"
  depends_on "hunspell"
  depends_on "bat"
  depends_on "fd"
  depends_on "delta"
  depends_on "tldr"
  depends_on "zoxide"
  depends_on "fzf"
  depends_on "gtrash"
  depends_on "atuin"
  depends_on "glow"
  depends_on "btop"


  def install
    system "bash", "-c", "curl -o- https://raw.githubusercontent.com/yorevs/homesetup/master/install.bash | bash"
  end

  test do
    system "#{ENV['HOME']}/HomeSetup/bin/apps/bash/hhs-app/hhs.bash", "--version"
  end
end
