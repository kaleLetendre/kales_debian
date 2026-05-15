# CLAUDE.md

Working agreement for Claude Code when operating inside this repo.

## Project goal

Build my Debian 13 XFCE environment as code. Any fresh machine is one
`git clone && ./bootstrap.sh` away from my working setup. The repo is the
source of truth: if a package or config does not live here, it does not exist.

## Hard rules

1. **Everything goes in the repo or it did not happen.** If I say I installed
   something or changed a config, add it to the appropriate script before
   declaring the task done. Do not just run a command on the system. And
   any time *you* are about to change this machine (install a package, edit
   a config, drop a file in $HOME, modify a service), pause and ask: "Want
   this tracked in the repo?" Default is yes; if I say skip, fine — the
   ask itself is the obligation.
2. **Scripts must be idempotent.** Re-running `bootstrap.sh` must be safe. Use
   patterns like `apt-get install -y` (idempotent by default),
   `grep -q PATTERN file || echo LINE >> file` for config edits, and existence
   checks before creating files.
3. **Common vs hardware-specific.** `common.sh` runs on any Debian XFCE
   machine. `hardware/<machine>.sh` runs only on that specific machine. Do
   not mix them. If unsure, ask.
4. **No secrets in the repo, ever.** Not even in a private repo. SSH keys,
   tokens, work credentials live outside Git. The `secrets/` folder is
   gitignored.
5. **Comment liberally.** Every non-obvious package or config tweak gets a
   one-line comment explaining what and why. Future-me has no memory.
6. **Dotfiles use stow.** New dotfiles go in `dotfiles/<package>/...` so they
   can be symlinked into `$HOME` by stow. Do not copy.

## Your workflow when I ask for a change

When I say "install X" or "set up Y" or "add Z to my shell":

1. Decide which file owns the change:
   - System-wide tool or service that belongs everywhere: `common.sh`
   - Tied to a specific machine's hardware: `hardware/<machine>.sh`
   - A dotfile: `dotfiles/<package>/...`
2. Edit the file. Add a short comment with the reason. Keep it idempotent.
3. Tell me what you added and where. If you are about to run the change on
   this system, say so first.
4. Only run the script (or the new section) after I confirm, unless the
   change is trivially safe (a dotfile edit that stow will pick up on the
   next bootstrap).

If a change could belong in either common or hardware-specific, ask before
guessing.

## Hardware reference: Dell Precision 3591

(Work laptop, main target for `hardware/precision-3591.sh`.)

- Intel Core Ultra (Meteor Lake H), needs kernel 6.12+ (Debian 13 Trixie).
- NVIDIA RTX 1000 or 2000 Ada, Optimus hybrid. Use the **open kernel module**
  (`nvidia-open-kernel-dkms` + `nvidia-driver`) and PRIME render offload.
  Never install NVIDIA's `.run` driver, it fights DKMS.
- `linux-headers-amd64` MUST be installed before any NVIDIA package, or DKMS
  will silently fail to build the module.
- Intel BE200/BE201 Wi-Fi, needs `firmware-iwlwifi`.
- Stay on X11, not Wayland (XFCE default, also avoids NVIDIA Wayland bugs).
- BIOS: AHCI (not RAID), Secure Boot can stay on, dGPU enabled.
- `fwupd` for Dell firmware via LVFS, well supported.
- Fingerprint reader: usually works with `fprintd` + `libfprint`. Verify
  with `lsusb` on first boot, some Goodix variants need extra driver work.

## Out of scope

- Disk imaging or cloning across machines. Rejected: carries wrong UUIDs,
  wrong NVIDIA driver, wrong initramfs.
- Debian installer preseed. Overkill for a couple of machines.

## Testing

Before any non-trivial change to `common.sh`, suggest spinning up a fresh
Debian 13 XFCE VM and running `./bootstrap.sh` against it to catch regressions.
For `hardware/precision-3591.sh` that is harder, so be extra careful.

## Tagging stable states

Once `common.sh` produces a working environment, suggest `git tag v<N>` so I
can roll back if experiments break things.
