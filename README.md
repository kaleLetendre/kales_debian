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
├── bootstrap.sh             # entry point, iterates setup/, hardware/, dotfiles/
├── setup/                   # numbered modules, one concern per file
│   ├── 10-git-and-ssh.sh    # git identity + SSH key + GitHub auth
│   ├── 20-base-packages.sh  # apt: git, curl, stow, tmux, build-essential, ...
│   └── 30-claude-code.sh    # Claude Code via Anthropic's signed apt repo
├── hardware/
│   └── precision-3591.sh    # Dell Precision 3591 specifics
├── dotfiles/                # stow packages, symlinked into $HOME
├── CLAUDE.md                # working agreement for Claude Code
└── secrets/                 # gitignored, never committed
```

Adding a new install or config means adding a new numbered file to `setup/`.
`bootstrap.sh` picks it up automatically.

## Fresh-install bootstrap order

### 0. Prep a Ventoy USB (one time, on any machine)

1. Download the latest Ventoy Linux tarball from
   https://github.com/ventoy/Ventoy/releases.
2. Extract and install to the USB (replace `/dev/sdX` with your stick):
   ```
   sudo bash Ventoy2Disk.sh -i -g /dev/sdX
   ```
   `-i` install, `-g` GPT partition style. Secure Boot support is on by
   default in recent Ventoy versions. This **wipes the USB**.
3. Download the Debian 13 amd64 netinst ISO from
   https://www.debian.org/distrib/ and copy it to the `Ventoy` exFAT
   partition. The standard netinst includes non-free firmware since
   Debian 12, so no separate `-firmware-` ISO is needed.

### 1. BIOS settings (on the target laptop)

For the Dell Precision 3591 (and similar modern UEFI laptops):

- **Storage mode: AHCI** (not RAID). Linux needs this to see the NVMe.
- **Secure Boot: on** is fine. Debian supports it out of the box.
- **dGPU: enabled** so NVIDIA is available.
- Boot the Ventoy USB. On ThinkPads tap **F12**, on Dells tap **F12**, for
  the one-time boot menu.

### 2. Install Debian 13 Trixie XFCE

- Use the Debian installer's **guided encrypted LVM** (LUKS full-disk
  encryption).
- **Skip a swap partition.** Use a swapfile or zram later.
- In `tasksel`: **uncheck GNOME**, **check Xfce**. Optionally uncheck
  "Debian desktop environment" for a leaner base.

### 3. After first boot

**First, add your user to the sudo group.** If you set a root password during
install, the Debian installer does NOT add your user to `sudo`. (Leaving the
root password blank would have added you automatically, but the installer
prompts for one and most people fill it in.)

Symptom: `sudo anything` says "user is not in the sudoers file."

Fix, in a terminal:

```
su -
# enter the root password you set during install
usermod -aG sudo "$(logname)"
exit
```

Then **log out of XFCE and log back in** (or reboot) so the new group
membership takes effect. Confirm with `groups`, you should see `sudo` listed.

Install just enough to clone the repo. Everything else (Claude Code, base
packages, SSH, identity, hardware tweaks, dotfiles) is handled by
`bootstrap.sh`.

```
sudo apt update
sudo apt install -y git
```

### 4. Clone this repo

A fresh machine has no SSH key yet, so the first clone uses HTTPS. The
bootstrap will generate a key, walk you through adding it to GitHub, and
flip `origin` over to SSH for everything after that.

```
mkdir -p ~/code && cd ~/code
git clone https://github.com/kaleLetendre/kales_debian.git
cd kales_debian
```

### 5. Run the bootstrap

```
./bootstrap.sh
```

What it does, in order:

1. Iterates `setup/*.sh` in lex order. Currently:
   - `10-git-and-ssh.sh` — sets global git `user.email`/`user.name`,
     generates an `ed25519` key, pins `github.com` in `known_hosts`, and on
     first run pauses while you paste the pubkey into
     `https://github.com/settings/ssh/new`. Once auth works it flips
     `origin` from HTTPS to SSH.
   - `20-base-packages.sh` — apt-installs the base CLI toolkit.
   - `30-claude-code.sh` — installs Claude Code from Anthropic's signed apt
     repo (GPG fingerprint pinned in-script).
2. Runs `hardware/<machine>.sh` matched by DMI product name, if present.
3. Stows every package under `dotfiles/`.

The only step that pauses for input is the GitHub key paste on first run
of a new machine. Everything else is unattended.

## Re-running

`bootstrap.sh` is idempotent. Re-run any time after pulling new changes or
after Claude adds a package. It only does work that has not been done.

## Tagging

Stable states get tagged (`git tag v<N>`) so a broken experiment can be
rolled back.
