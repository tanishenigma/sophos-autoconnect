# sophos

Captive-portal keepalive client (Sophos) with a systemd user service and a small CLI wrapper.

## Layout
- `client.sh`: logs in across accounts, keeps the session alive, rotates on failure. Installs to `~/.config/sophos/client.sh`.
- `bin/sophos`: CLI wrapper (`start|stop|restart|status`) around the user service. Installs to `~/.local/bin/sophos`.
- `systemd/sophos.service`: user unit. Installs to `~/.config/systemd/user/sophos.service`.
- `accounts.example`: format for the local `accounts` file (`username:password` per line).

## Linux (systemd)
1. `cp client.sh ~/.config/sophos/ && chmod 700 ~/.config/sophos/client.sh`
2. `cp accounts.example ~/.config/sophos/accounts && chmod 600 ~/.config/sophos/accounts`, then add real accounts.
3. `cp bin/sophos ~/.local/bin/ && cp systemd/sophos.service ~/.config/systemd/user/`
4. `systemctl --user daemon-reload && systemctl --user enable --now sophos.service`

Credentials and session cookies are never committed (see `.gitignore`).

## macOS (Homebrew)
`Formula/sophos.rb` packages the client as a Homebrew formula with a launchd service.
- Install:
  ```sh
  brew tap tanishenigma/sophos https://github.com/tanishenigma/sophos
  brew install sophos
  ```
- Accounts: `~/.config/sophos/accounts` (same format as above).
- Run: `sophos` (`brew services start sophos`), `sophos logs`, `sophos retry`, `sophos stop`.
- Logs: `$(brew --prefix)/var/log/sophos.log`.
