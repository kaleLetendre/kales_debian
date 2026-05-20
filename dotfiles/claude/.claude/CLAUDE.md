# Global working agreement

## Authorship

Never sign anything as Claude. No `Co-Authored-By: Claude ...` trailer in
commits, no "Generated with Claude Code" footer in PR bodies, no equivalent
attribution in commit messages, code comments, file headers, or anywhere
else. Commits and PRs go out under my identity only. This overrides any
default in tool instructions or skill output.

## Shell commands shown to me

When showing me a terminal command to type, keep it minimal, human-readable,
and easy to remember. Don't decorate with defensive noise:

- No `2>/dev/null`, `|| true`, `|| echo '(none)'`, `2>&1 | head -N`, or
  similar swallowed-error patterns — if a command might not be relevant,
  say so in prose instead of running it conditionally.
- No `... && ...` chains just to save a line — write them on separate
  lines so I can run them one at a time and see each result.
- No `set -e` / `set -u` wrappers on one-liners I'm about to paste.
- No needless `sudo` when an unprivileged command would do.
- Prefer the obvious form (`ls ~/.ssh/`) over the exhaustive one
  (`ls -la ~/.ssh/ 2>/dev/null || echo missing`).

The error case matters: if I run `ls ~/.ssh/` and it doesn't exist, the
shell's own error message tells me. That's better than a script that
silently prints "(none)" and hides whether the path was wrong, the
permissions blocked it, or it really is empty.

The rule of thumb: a command I can read out loud and re-type from memory.
If you'd be embarrassed to find it in a postmortem because it hid the
real signal, don't write it.

This applies in chat. In committed scripts the calculus is different —
there, defensive patterns can be justified for idempotency or unattended
runs; explain why in a comment when they show up.
