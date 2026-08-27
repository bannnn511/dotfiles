# VM dotfiles

This repository is the reproducible record of tools and configuration installed on this VM.

## Restore on a new Ubuntu VM

```bash
git clone <repository-url> ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

The installer is intended to be safe to run repeatedly. Existing dotfiles are backed up with a `pre-dotfiles.<timestamp>` suffix before links are created.

## Recording future changes

Whenever software is installed, add it to the matching array in `bootstrap.sh`:

- `APT_PACKAGES`: packages installed with apt
- `SNAPS`: snap packages, optionally including `--classic`
- `NPM_GLOBAL_PACKAGES`: globally installed npm packages

Put managed user configuration files in `home/`, retaining their normal names (for example, `home/.bashrc`). Running `bootstrap.sh` links them into `$HOME`.

For tools with custom installers, add a small idempotent install function to `bootstrap.sh` and invoke it from `main`.
