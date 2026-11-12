class Sophos < Formula
  desc "Captive-portal keepalive client for Sophos with account rotation"
  homepage "https://github.com/tanishenigma/sophos"
  url "https://github.com/tanishenigma/sophos.git", tag: "v0.1.0"
  license "MIT"
  head "https://github.com/tanishenigma/sophos.git", branch: "main"

  def install
    libexec.install "client.sh"
    bin.install "bin/sophos"
    pkgshare.install "accounts.example"
  end

  def post_install
    (var/"log").mkpath
  end

  def caveats
    <<~EOS
      Add accounts (username:password, one per line):
        mkdir -p ~/.config/sophos && chmod 700 ~/.config/sophos
        cp #{opt_pkgshare}/accounts.example ~/.config/sophos/accounts
        chmod 600 ~/.config/sophos/accounts

      Then start (also runs at login):
        sophos            # or: brew services start sophos
    EOS
  end

  service do
    run [opt_libexec/"client.sh"]
    keep_alive true
    log_path var/"log/sophos.log"
    error_log_path var/"log/sophos.log"
  end

  test do
    assert_match "Usage", shell_output("#{bin}/sophos help")
  end
end
