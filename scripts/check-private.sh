#!/usr/bin/env bash
# Fail if a file holds a string that must not be published.
#
# Generic checks always run: a home directory path of any user, and any email
# address that is not an example or noreply address.
#
# For your own word list (names, hosts, internal terms), create a local file
# that is NOT part of this repo. One extended regex per line. A '#' starts a
# comment.
#   default path: ~/.config/tmux-nvim-claude/private-patterns
#   override:     PRIVATE_PATTERNS_FILE=/path/to/file
#
# This script is excluded from the scan.
set -u
cd "$(dirname "$0")/.." || exit 2

PATTERN_FILE="${PRIVATE_PATTERNS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/tmux-nvim-claude/private-patterns}"
GENERIC='/Users/[A-Za-z0-9._-]+/|/home/[a-z_][a-z0-9_-]*/|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
ALLOW='/Users/Shared/|@example\.com|@users\.noreply\.github\.com|git@github\.com'

LOCAL=$(mktemp)
trap 'rm -f "$LOCAL"' EXIT
if [ -f "$PATTERN_FILE" ]; then
	grep -v -E '^[[:space:]]*(#|$)' "$PATTERN_FILE" >"$LOCAL" || true
fi

hits=""
while IFS= read -r f; do
	[ -f "$f" ] || continue
	h=$(grep -n -i -E "$GENERIC" "$f" /dev/null | grep -v -E "$ALLOW")
	if [ -s "$LOCAL" ]; then
		h=$(printf '%s\n%s\n' "$h" "$(grep -n -i -E -f "$LOCAL" "$f" /dev/null)" | sed '/^$/d')
	fi
	[ -n "$h" ] && hits="$hits$h"$'\n'
done < <(git ls-files -co --exclude-standard | grep -v '^scripts/check-private.sh$')

if [ -n "$hits" ]; then
	echo "Private strings found:" >&2
	printf '%s' "$hits" | cut -c1-160 >&2
	exit 1
fi

if [ -s "$LOCAL" ]; then
	echo "ok - no private strings (generic checks and $(wc -l <"$LOCAL" | tr -d ' ') local patterns)"
else
	echo "ok - no private strings (generic checks only; no local pattern file)"
fi
