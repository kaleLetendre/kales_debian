# SSH keys

How I set up SSH on a fresh machine, and how to add passwordless access to a
new box (a server, another laptop) by hand.

## What the repo manages

`setup/10-git-and-ssh.sh` generates two ed25519 keys and writes their
`~/.ssh/config` host blocks (sentinel-fenced, so re-runs only append once):

- `~/.ssh/id_ed25519` — personal / GitHub
- `~/.ssh/id_ed25519_caracal` — work / Bitbucket (the `caracal` host alias)

That covers the keys and the git remotes. Connecting to a **specific server**
is deliberately *not* in the repo — those aliases (IPs, usernames, which box)
are per-machine and would be wrong on the next clone. Add them by hand as
below.

## Add passwordless access to a server

Say the box answers at `kl@<ip>` with a password today and you want
`ssh <name>` to just work.

1. Add a host alias to `~/.ssh/config`:

   ```
   Host <name>
       HostName <ip>
       User kl
       IdentityFile ~/.ssh/id_ed25519
       IdentitiesOnly yes
   ```

   `IdentitiesOnly yes` stops ssh-agent from offering every loaded key on each
   connection (repeated wrong-key attempts can lock an account).

2. Copy your public key over (prompts once for the server password):

   ```
   ssh-copy-id -i ~/.ssh/id_ed25519.pub <name>
   ```

3. Test that key auth works with no password prompt:

   ```
   ssh -o BatchMode=yes <name> 'whoami; hostname'
   ```

   `BatchMode=yes` disables the password fallback, so a clean success proves
   the key — not a password — got you in.

## Tailnet boxes

For a server reached over Tailscale, the `HostName` can be either its tailnet
IP (`100.x.y.z`, stable per-node) or its MagicDNS name
(`<host>.tailf19ac6.ts.net`). The MagicDNS name is more portable, but note
that if a hostname is already taken by an old/offline node, Tailscale appends
`-1` to the new one — check `tailscale status` for the real name before
wiring the alias. Server-side Tailscale + sshd setup lives in
`server/10-tailscale-ssh.sh`.

## Where the wiring lives

Key generation and the git host blocks: `setup/10-git-and-ssh.sh`. This file
is just the runbook for the manual, per-machine part.
