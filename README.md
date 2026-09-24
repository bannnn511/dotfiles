# Dotfiles

This repository is the reproducible record of tools and configuration installed on macOS or an Ubuntu/Debian VM. [mise](https://mise.jdx.dev/) manages system packages, development tools, and dotfile links.

## Restore a cloned checkout

```bash
git clone <repository-url> ~/dotfiles
cd ~/dotfiles
./bootstrap.sh --dry-run
./bootstrap.sh
```

`bootstrap.sh` installs mise when necessary and then runs `mise bootstrap`. The setup is idempotent. mise refuses to replace conflicting dotfiles; inspect or move those files before applying, rather than forcing replacement without review.

If mise is already installed, run it directly:

```bash
mise trust
mise bootstrap --dry-run
mise bootstrap
mise bootstrap status
```

To bootstrap without cloning the repository yourself:

```bash
curl -fsSL https://mise.run | sh
~/.local/bin/mise bootstrap --from https://github.com/bannnn511/dotfiles.git
```

## Recording future changes

Edit `mise.toml` when adding software:

- Add versioned development tools to `[tools]`.
- Add host packages to `[bootstrap.packages]` with their manager prefix, such as `apt:` or `brew:`.

Put managed user configuration files in `home/`, retaining their normal paths. `mise bootstrap` links Git-tracked files from that directory into `$HOME` while leaving other files alone.

The bootstrap also links `mise.toml` to `~/.config/mise/config.toml`, making the declared tools available outside this repository.

Preview changes with `mise bootstrap --dry-run` before applying them.
