#!/usr/bin/env bash
# Link this repo into your home directory. Print the rest, and never edit
# ~/.claude/settings.json, ~/.claude/CLAUDE.md, or your shell files.
# Works with the macOS system bash (3.2).
set -u

REPO=$(cd "$(dirname "$0")" && pwd -P)
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
NVIM_PACK="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/tmux-nvim-claude/start/tmux-review"
CODE_DIR="${CODE_DIR:-$HOME/code}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.tmux-nvim-claude-backups}/$(date +%Y%m%d%H%M%S)"

DRY=0
FORCE=0
PACK=0
MODE=install

usage() {
	cat <<'USAGE'
Usage: install.sh [--dry-run] [--force] [--uninstall]
       install.sh --print-settings
       install.sh --print-nvim-spec

  (no flag)         Symlink scripts, skill, snippets, and the Neovim plugin.
  --dry-run         Show what would change. Change nothing.
  --force           Replace an existing file. The old file moves to
                    ~/.tmux-nvim-claude-backups/<time>/. It never stays in a folder that
                    Claude Code or Neovim scans.
  --uninstall       Remove the symlinks that point into this repo.
  --print-settings  Print the Claude Code settings to merge by hand.
                    CODE_DIR sets the folder that holds your repos (default ~/code).
  --print-nvim-spec Print the lazy.nvim plugin spec for the Neovim part.
  --nvim-pack       Link the Neovim part into Neovim's native pack folder. Use this
                    only if you do not use lazy.nvim. lazy.nvim ignores that folder.
USAGE
}

for arg in "$@"; do
	case "$arg" in
	--dry-run) DRY=1 ;;
	--force) FORCE=1 ;;
	--uninstall) MODE=uninstall ;;
	--print-settings) MODE=settings ;;
	--print-nvim-spec) MODE=nvimspec ;;
	--nvim-pack) PACK=1 ;;
	-h | --help) usage; exit 0 ;;
	*) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
	esac
done

run() {
	if [ "$DRY" = 1 ]; then echo "  would run: $*"; else "$@"; fi
}

link() {
	local src=$1 dst=$2 cur
	if [ -L "$dst" ]; then
		cur=$(readlink "$dst")
		if [ "$cur" = "$src" ]; then
			echo "  ok      $dst"
			return 0
		fi
		if [ "$FORCE" = 0 ]; then
			echo "  skip    $dst (links to $cur; use --force)"
			return 0
		fi
		run rm "$dst"
	elif [ -e "$dst" ]; then
		if [ "$FORCE" = 0 ]; then
			echo "  skip    $dst (exists; use --force)"
			return 0
		fi
		run mkdir -p "$BACKUP_DIR"
		run mv "$dst" "$BACKUP_DIR/$(basename "$dst")"
		[ "$DRY" = 1 ] && echo "  would back up $dst -> $BACKUP_DIR/" || echo "  backup  $dst -> $BACKUP_DIR/"
	fi
	run mkdir -p "$(dirname "$dst")"
	run ln -s "$src" "$dst"
	[ "$DRY" = 1 ] && echo "  would link $dst" || echo "  linked  $dst"
}

unlink_ours() {
	local dst=$1 cur
	[ -L "$dst" ] || return 0
	cur=$(readlink "$dst")
	case "$cur" in
	"$REPO"/*) run rm "$dst"; echo "  removed $dst" ;;
	*) echo "  keep    $dst (does not point into this repo)" ;;
	esac
}

PAIRS="
$REPO/bin/nvim-open|$BIN_DIR/nvim-open
$REPO/bin/prune-worktrees|$BIN_DIR/prune-worktrees
$REPO/skills/pr-walkthrough|$CLAUDE_DIR/skills/pr-walkthrough
$REPO/claude/snippets|$CLAUDE_DIR/snippets/tmux-nvim-claude
"
PACK_PAIR="$REPO/nvim|$NVIM_PACK"
[ "$PACK" = 1 ] && PAIRS="$PAIRS$PACK_PAIR
"

render() {
	sed -e "s|__REPO__|$REPO|g" -e "s|__CODE_DIR__|$CODE_DIR|g" "$1"
}

case "$MODE" in
settings)
	render "$REPO/claude/settings.template.json"
	exit 0
	;;
nvimspec)
	cat <<SPEC
local dir = vim.fn.expand(vim.env.TMUX_NVIM_CLAUDE_DIR or "$REPO") .. "/nvim"

-- Without this guard, lazy.nvim errors on every start when the repo is not cloned.
if not vim.uv.fs_stat(dir) then
	return {}
end

return { dir = dir, name = "tmux-review" }
SPEC
	exit 0
	;;
uninstall)
	echo "Removing links:"
	echo "$PAIRS$PACK_PAIR" | while IFS='|' read -r src dst; do
		[ -n "$dst" ] && unlink_ours "$dst"
	done
	exit 0
	;;
esac

[ "$DRY" = 1 ] && echo "(dry run)"
echo "Linking:"
echo "$PAIRS" | while IFS='|' read -r src dst; do
	[ -n "$dst" ] && link "$src" "$dst"
done

cat <<NEXT

Next steps (by hand):
  1. Check that $BIN_DIR is on your PATH.
  2. Merge the Claude Code settings. Print them with:
       $REPO/install.sh --print-settings
     Merge the "hooks", "statusLine", and "permissions" keys into $CLAUDE_DIR/settings.json.
  3. Add these lines to $CLAUDE_DIR/CLAUDE.md:
       @$CLAUDE_DIR/snippets/tmux-nvim-claude/worktrees.md
       @$CLAUDE_DIR/snippets/tmux-nvim-claude/pr-walkthrough.md
  4. Add the Neovim part.
       lazy.nvim:  $REPO/install.sh --print-nvim-spec > <your nvim config>/lua/plugins/tmux-review.lua
       no manager: $REPO/install.sh --nvim-pack
  5. Install the extras. See README.md (window namer, session resume, ccusage).
  6. Run: $REPO/doctor.sh
NEXT
