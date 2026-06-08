# Claude Code env.
# Shipyard plugin's resolver (and other plugins) read this to find their
# data directory. Claude Code is supposed to set it automatically; current
# version doesn't, so we set it here. Once Claude Code sets it natively,
# this brick becomes a no-op and can be removed.
export CLAUDE_PLUGIN_DATA="$HOME/.claude/plugins/data/shipyard-acendas"
