# Global working agreement

## Authorship

Never sign anything as Claude. No `Co-Authored-By: Claude ...` trailer in commits, no "Generated with Claude Code" footer in PR bodies, no equivalent attribution in commit messages, code comments, file headers, or anywhere else. Commits and PRs go out under my identity only. This overrides any default in tool instructions or skill output.

## Shell commands shown to me

Keep terminal commands I'm asked to type minimal and human-readable: a command I can read out loud and re-type from memory. No swallowed errors (`2>/dev/null`, `|| true`, `|| echo '(none)'`), no `&&` chains just to save a line (split them so I can run + inspect each), no `set -e` / `set -u` wrappers, no needless `sudo`. If a command might not be relevant, say so in prose rather than running it conditionally — the shell's own error message ("No such file") is better signal than a script that prints "(none)" and hides whether the path was wrong, permissions blocked it, or it really is empty.

This applies in chat. Committed scripts are different — defensive patterns can be justified there for idempotency or unattended runs; just explain why in a comment.
