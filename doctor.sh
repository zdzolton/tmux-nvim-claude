#!/usr/bin/env bash
# Check that the tools and links are in place. Prints no secrets.
set -u

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
fail=0

ok() { echo "ok    $1"; }
bad() { echo "FAIL  $1"; fail=1; }
warn() { echo "warn  $1"; }

for c in tmux nvim jq gh git; do
	command -v "$c" >/dev/null 2>&1 && ok "$c" || bad "$c is missing (brew install $c)"
done
for c in terminal-notifier ccusage bc claude; do
	command -v "$c" >/dev/null 2>&1 && ok "$c" || warn "$c is missing (optional; see README.md)"
done

case ":$PATH:" in
*":$BIN_DIR:"*) ok "$BIN_DIR is on PATH" ;;
*) bad "$BIN_DIR is not on PATH" ;;
esac

for c in nvim-open prune-worktrees; do
	command -v "$c" >/dev/null 2>&1 && ok "$c is on PATH" || bad "$c is not on PATH (run install.sh)"
done

[ -e "$CLAUDE_DIR/skills/pr-walkthrough/SKILL.md" ] && ok "pr-walkthrough skill" || bad "pr-walkthrough skill is not linked"
[ -e "$CLAUDE_DIR/snippets/tmux-nvim-claude/worktrees.md" ] && ok "CLAUDE.md snippets linked" || bad "snippets are not linked"

if nvim --headless -c 'lua vim.cmd(pcall(require, "tmux_review") and "qa" or "cq")' >/dev/null 2>&1; then
	ok "Neovim can load tmux_review"
else
	bad "Neovim cannot load tmux_review (run install.sh, or see README.md)"
fi

if [ -f "$CLAUDE_DIR/settings.json" ]; then
	grep -q 'tmux-window-notify' "$CLAUDE_DIR/settings.json" && ok "notify hooks in settings.json" || warn "notify hooks are not in settings.json"
	grep -q 'nvim-open' "$CLAUDE_DIR/settings.json" && ok "nvim-open is allowed in settings.json" || warn "nvim-open is not in the allow list (you will get a prompt per step)"
	grep -q 'statusline-command' "$CLAUDE_DIR/settings.json" && ok "status line set" || warn "status line is not set"
else
	warn "$CLAUDE_DIR/settings.json not found"
fi

[ -n "${TMUX:-}" ] && ok "running inside tmux" || warn "not inside tmux (nvim-open needs it)"
exit "$fail"
