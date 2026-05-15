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

Now install the bare minimum needed to clone this repo and run Claude Code:

```
sudo apt update
sudo apt install -y git curl nodejs npm
```

### 4. Install Claude Code

See https://docs.claude.com/claude-code for the current install command.
Log in once it's installed.

### 5. Clone this repo

```
mkdir -p ~/code && cd ~/code
git clone git@github.com:kaleLetendre/kales_debian.git
cd kales_debian
```

(SSH key needs to be on GitHub for the clone. If not yet, use the HTTPS URL
for the initial clone and add the SSH key later.)

### 6. Run the bootstrap

```
./bootstrap.sh
```

`bootstrap.sh` auto-selects the right `hardware/<machine>.sh` based on the
DMI product name, runs `common.sh`, and stows any dotfile packages.

## Re-running

`bootstrap.sh` is idempotent. Re-run any time after pulling new changes or
after Claude adds a package. It only does work that has not been done.

## Tagging

Stable states get tagged (`git tag v<N>`) so a broken experiment can be
rolled back.
