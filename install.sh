#!/usr/bin/env bash
# Install the carpe-audience skill into ~/.claude/skills (or $CLAUDE_HOME/skills if set).
#   ./install.sh          copy the skill (default; re-run to update)
#   ./install.sh --link   symlink it back to this checkout instead, so `git pull` updates it
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE="${CLAUDE_HOME:-$HOME/.claude}"
DST="$CLAUDE/skills/carpe-audience"
MODE="copy"
[ "${1:-}" = "--link" ] && MODE="link"

echo "Installing carpe-audience into $DST ($MODE mode)"
mkdir -p "$CLAUDE/skills"
rm -rf "$DST"
if [ "$MODE" = "link" ]; then
  ln -s "$HERE" "$DST"; echo "  linked  $DST -> $HERE"
else
  mkdir -p "$DST"
  cp -R "$HERE/SKILL.md" "$HERE/assets" "$HERE/references" "$DST/"; echo "  copied  $DST"
fi

cat <<MSG

Done. Check this machine's requirements (R packages, Quarto, Chrome, optional Gemini key):

  Rscript "$DST/assets/carpe_check_setup.R"            # add --install to install missing R packages

The R helpers find the skill through CARPE_SKILL (default ~/.claude/skills/carpe-audience).
Start a new Claude Code session and run: /carpe-audience plan
MSG
