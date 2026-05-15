# kales_debian

Build my Debian 13 XFCE environment as code. The repo is the source of truth:
any fresh machine should be one `git clone && ./bootstrap.sh` away from my
working setup.

## What this is

More than dotfiles. This repo manages:

- System packages (via `apt`)
- Services and daemons
- Hardware-specific setup (NVIDIA, firmware, fingerprint, etc.)
- Dotfiles, managed with GNU `stow`

## Layout

```
.
├── bootstrap.sh             # entry point, detects machine, runs the rest
├── common.sh                # packages and config for every machine
├── hardware/
│   └── precision-3591.sh    # Dell Precision 3591 specifics
├── dotfiles/                # stow packages, symlinked into $HOME
├── CLAUDE.md                # working agreement for Claude Code
└── secrets/                 # gitignored, never committed
```

## Fresh-install bootstrap order

1. Boot the Debian 13 Trixie netinst USB (Ventoy with the Debian ISO works).
2. Install Debian 13 XFCE with LUKS-encrypted LVM. Uncheck GNOME, check Xfce.
3. After first boot, in a terminal:
   ```
   sudo apt update
   sudo apt install -y git curl nodejs npm
   ```
4. Install Claude Code and log in. See https://docs.claude.com/claude-code.
5. Clone this repo:
   ```
   mkdir -p ~/code && cd ~/code
   git clone git@github.com:kaleLetendre/kales_debian.git
   cd kales_debian
   ```
6. Run the bootstrap:
   ```
   ./bootstrap.sh
   ```

## Re-running

`bootstrap.sh` is idempotent. Re-run any time after pulling new changes or
after Claude adds a package. It only does work that has not been done.

## Tagging

Stable states get tagged (`git tag v<N>`) so a broken experiment can be
rolled back.
