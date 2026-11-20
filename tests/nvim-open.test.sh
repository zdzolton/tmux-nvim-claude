#!/usr/bin/env bash
# Test bin/nvim-open on a private tmux server. It never touches your own tmux.
set -u

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
WORK=$(mktemp -d)
SOCK="tnc-test-$$"
REAL_NVIM=$(command -v nvim)
fail=0

T() { tmux -L "$SOCK" -f /dev/null "$@"; }
ok() { echo "ok   - $1"; }
bad() { echo "FAIL - $1"; fail=1; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
cleanup() { T kill-server 2>/dev/null; rm -f "${TMUX%%,*}"; rm -rf "$WORK"; }
trap cleanup EXIT

# Wrapper so the Neovim started by nvim-open skips your config and loads the plugin from this repo.
mkdir -p "$WORK/bin"
cat >"$WORK/bin/nvim" <<WRAP
#!/usr/bin/env bash
for a in "\$@"; do [ "\$a" = "--server" ] && exec "$REAL_NVIM" "\$@"; done
exec "$REAL_NVIM" -u NORC -i NONE --cmd "set rtp+=$REPO/nvim" "\$@"
WRAP
chmod +x "$WORK/bin/nvim"
export PATH="$WORK/bin:$PATH"

printf 'a\nb\nc\nd\ne\nf\n' >"$WORK/one.txt"
printf 'x\ny\nz\n' >"$WORK/two.txt"
seq 1 200 >"$WORK/long.txt"

T new-session -d -s t -x 200 -y 50 -c "$WORK" "sleep 600"
TMUX=$(T display-message -p '#{socket_path},#{pid},0')
TMUX_PANE=$(T list-panes -t t -F '#{pane_id}' | head -1)
export TMUX TMUX_PANE
win=$(T display-message -p -t "$TMUX_PANE" '#{window_id}')
panes() { T list-panes -t "$win" | wc -l | tr -d ' '; }
sock() { T show-options -wqv -t "$win" @nvim_server; }
q() { nvim --server "$(sock)" --remote-expr "$1"; }
marks() { q 'luaeval("#vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace(\"tmux_review_hunk\"), 0, -1, {})")'; }

"$REPO/bin/nvim-open" "$WORK/one.txt" 2-4
check "starts a split when the window has no Neovim" "$(panes)" "2"
nvim_pane=$(T list-panes -t "$win" -F '#{pane_id}' | grep -v "^$TMUX_PANE$" | head -1)
left_of() { T display-message -p -t "$1" '#{pane_left}'; }
width_of() { T display-message -p -t "$1" '#{pane_width}'; }
check "puts the new pane on the left of Claude" "$([ "$(left_of "$nvim_pane")" -lt "$(left_of "$TMUX_PANE")" ] && echo yes)" "yes"
check "gives the new pane about 60% of the width" "$([ "$(width_of "$nvim_pane")" -ge 115 ] && [ "$(width_of "$nvim_pane")" -le 125 ] && echo yes)" "yes"
check "registers the socket on the window" "$([ -S "$(sock)" ] && echo yes)" "yes"
check "opens the file" "$(q 'bufname("%")')" "$WORK/one.txt"
check "moves to the first line" "$(q 'line(".")')" "2"
check "highlights the range" "$(marks)" "3"

"$REPO/bin/nvim-open" "$WORK/two.txt" 3
check "reuses the Neovim for the next call" "$(panes)" "2"
check "opens the second file" "$(q 'bufname("%")')" "$WORK/two.txt"
check "uses one tab per file" "$(q 'tabpagenr("$")')" "2"
check "clears the old highlight" "$(marks)" "1"

T set-option -w -u -t "$win" @nvim_server
"$REPO/bin/nvim-open" "$WORK/one.txt" 5
check "finds an unregistered Neovim without a new split" "$(panes)" "2"
check "registers it again" "$([ -S "$(sock)" ] && echo yes)" "yes"
check "opens the file after the fallback" "$(q 'line(".")')" "5"

"$REPO/bin/nvim-open" "$WORK/one.txt" 99-120
check "clamps a range past the end of the file" "$(q 'line(".")')" "6"

"$REPO/bin/nvim-open" "$WORK/long.txt" 10-11 50-60
check "highlights only the given ranges" "$(marks)" "13"
check "puts the cursor on the first range" "$(q 'line(".")')" "10"

"$REPO/bin/nvim-open" --focus 50
check "focus moves the cursor" "$(q 'line(".")')" "50"
check "focus keeps the highlights" "$(marks)" "13"

"$REPO/bin/nvim-open" "$WORK/long.txt" 10-100
check "shortens a long range" "$(marks)" "5"

"$REPO/bin/nvim-open" "$WORK/one.txt" 1-2-3 2>/dev/null
check "rejects a bad range with exit 2" "$?" "2"

"$REPO/bin/nvim-open" relative/path 1 2>/dev/null
check "rejects a relative path with exit 2" "$?" "2"

env -u TMUX -u TMUX_PANE "$REPO/bin/nvim-open" "$WORK/one.txt" 1 2>/dev/null
check "exits 0 outside tmux" "$?" "0"

exit "$fail"
