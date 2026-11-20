# tmux-nvim-claude

A setup for reviewing code with Claude Code and Neovim side by side in tmux.

- Claude walks through a diff one hunk at a time.
- For each hunk, Neovim jumps to the file and line. It highlights the changed range.
- You never pick a file or type a line number.

Extras in the same setup: window notifications, a live status line with cost, worktree cleanup, and notes for two outside tools.

## How the hunk sync works

```
Neovim pane (same tmux window)               Claude Code pane
  tmux-review plugin                           pr-walkthrough skill
    | at startup:                                | runs for each step
    |   tmux set-option -w @nvim_server <socket> v
    |                                          nvim-open <abs-path> <range>...
  tab drop <path>, centre line,   <---- RPC ---- | reads @nvim_server
  highlight range                                v
                                               no Neovim in the window? It opens a split on the left with one.
```

Each Neovim registers its own RPC socket on its tmux window. The script reads that option, so many windows work side by side.

## Requirements

- macOS. `terminal-notifier`, `launchd`, and the BSD `ps` flags are macOS only.
- `tmux`, `nvim` (0.10 or newer), `jq`, `gh`, `git`. Run `brew bundle` in this repo to install them.
- Claude Code. It must run inside tmux, because `nvim-open` finds Neovim through the tmux window.
- Optional: `ccusage` for the cost in the status line. For example: `npm install -g ccusage`

Tested on macOS with Claude Code 2.1.326, Neovim 0.11.6, and tmux 3.6a.

## Install

```bash
git clone https://github.com/zdzolton/tmux-nvim-claude ~/code/tmux-nvim-claude
cd ~/code/tmux-nvim-claude
./install.sh --dry-run     # look first
./install.sh
./doctor.sh
```

`doctor.sh` shows warnings until you finish the three steps below. That is expected.

`install.sh` only creates symlinks. It skips any file that already exists. Use `--force` to replace one. The old file moves to `~/.tmux-nvim-claude-backups/<time>/`, outside any folder that Claude Code or Neovim scans. `./install.sh --uninstall` removes the links.

It never edits your `settings.json`, `CLAUDE.md`, or shell files. Do these steps by hand.

**1. Neovim plugin.**

With lazy.nvim, write a plugin spec into your config:

```bash
./install.sh --print-nvim-spec > ~/.config/nvim/lua/plugins/tmux-review.lua
```

The spec skips itself when the repo is not on disk. This keeps a shared config clean on a machine that does not have this repo. Without that guard, lazy.nvim prints an error on every start. If you keep your config in git, replace the printed path with a portable default such as `"~/code/tmux-nvim-claude"`. The `TMUX_NVIM_CLAUDE_DIR` environment variable overrides it.

With no plugin manager, run `./install.sh --nvim-pack`. lazy.nvim ignores Neovim's native pack folder, so do not use that option with lazy.nvim.

**2. Claude Code settings.** Print the settings with your real paths:

```bash
./install.sh --print-settings
```

Merge the `hooks`, `statusLine`, and `permissions` keys into `~/.claude/settings.json`. If you already have a `hooks` key, merge the arrays. Do not replace them.

| Key | What it does |
|-----|--------------|
| `Notification` and `Stop` hooks | macOS notification when Claude needs you or finishes. It shows the tmux window name. |
| `PreToolUse` hook | Allows read-only `git -C <repo>` commands in `CODE_DIR` with no prompt. It still asks for any command with an option that can write a file or run a program (`--output`, `--ext-diff`, `--no-index`). |
| `statusLine` | Directory, model, context percent, and cost (needs `ccusage`). |
| `permissions.allow` | Lets `nvim-open` run with no prompt, with any arguments. It only opens files in your own Neovim. Without this rule, you get a prompt on every step. |

`CODE_DIR` is the folder that holds your repos. It defaults to `~/code`. Set it before you print the settings: `CODE_DIR=~/src ./install.sh --print-settings`

**3. CLAUDE.md.** Add these lines to your user-level `~/.claude/CLAUDE.md`:

```
@~/.claude/snippets/tmux-nvim-claude/worktrees.md
@~/.claude/snippets/tmux-nvim-claude/pr-walkthrough.md
```

- `pr-walkthrough.md` tells Claude when to offer a walkthrough. It is the one you need.
- `worktrees.md` is optional. It sets a worktree-per-feature habit and tells Claude to run `prune-worktrees`.

Both the `~` form and a full path work there. Use the user-level file. A project-level `CLAUDE.md` cannot load files outside its project without an approval step.

## Use it

1. Open a tmux window. Run `claude` in one pane. Neovim can be in another pane of the same window. If it is not, the first step opens one.
2. Ask for a review. For example: "Walk me through my local diff" or "Review PR 123 hunk by hunk".
3. Claude states the controls and shows step 1. Neovim jumps to the hunk.
4. Type a control word:

| Word | Effect |
|------|--------|
| `next` | Go to the next hunk. |
| `back` | Revisit the last hunk. |
| `skip` | Pass the current hunk. |
| `jump to <file>` | Move to another file. |
| `stop` or `done` | End early. Claude lists the steps it did not review and the concerns it noted. |

A step looks like this:

```
Step 2/6 — lines 40-52 in billing/InvoiceService.java

Changed: 40-44, 50-52 (6 added, 1 removed)

The method now rounds each line item before it sums the total.

Code check:
- The rounding mode matches the one in the tax helper.

Concerns:
- Existing invoices keep the old totals. No migration is included.

Say next to continue.
```

Claude does not print code. Neovim shows the code, with the changed range highlighted.

## What you get

| Piece | Where | Purpose |
|-------|-------|---------|
| `nvim-open` | `bin/` | Opens a file and line range in the Neovim of the current tmux window. |
| `tmux-review` | `nvim/` | Neovim plugin. Registers the socket and does the open and highlight. |
| `pr-walkthrough` | `skills/` | The hunk-by-hunk review skill. It calls `nvim-open` for each step. |
| `prune-worktrees` | `bin/` | Removes worktrees and local branches whose PR is merged or closed. |
| `tmux-window-notify.sh` | `bin/` | Notification script for the hooks. |
| `statusline-command.sh` | `claude/` | Status line with context and cost. |
| `tmux_namer_cost.py` | `tools/` | Cost report for the window namer (see below). |

### `nvim-open`

```
nvim-open <abs-path> <range>...
nvim-open --focus <line>
```

- The path must be absolute.
- A range is `N` or `FIRST-LAST`. Pass several ranges to highlight several blocks, for example `nvim-open /abs/File.java 72-73 508-533`. The cursor goes to the first range.
- A range of more than 40 lines shows its first 3 lines and its last line. A note on the third line says how many lines are hidden.
- `--focus <line>` moves the cursor in the current file and keeps the highlights. Use it to step between ranges.
- It exits 0 on runtime problems, so it never blocks a review. It prints the reason on stderr.
- If the window has a Neovim but no registered socket, it finds the socket through the process tree and registers it.
- If the window has no Neovim, it opens a split on the left (60% of the width) and keeps focus on Claude.

### `prune-worktrees`

Run it from the folder that holds your repos, outside any worktree. It removes a worktree only when the PR is merged, the tree is clean, and your HEAD equals the PR head. In a terminal it asks before anything riskier. Use `--dry-run` to see the plan and `--no-prompt` to never ask. `CODE_DIR` sets the folder to scan (default `~/code`). It needs an authenticated `gh`.

## Extras that live in other repos

### Window namer

[claude-tmux-namer](https://github.com/cosgroveb/claude-tmux-namer) is a Claude Code plugin by someone else. After each reply, it renames the tmux window with a short phrase. Install it from the upstream repo, from inside Claude Code. This needs no SSH key. Restart running sessions afterward.

```
/plugin marketplace add cosgroveb/claude-tmux-namer
/plugin install tmux-window-namer@claude-tmux-namer
```

It logs cost to `~/.local/share/claude-tmux-namer/cost.log`. To summarize it:

```bash
python3 tools/tmux_namer_cost.py ~/.local/share/claude-tmux-namer/cost.log
```

### Session resume

[tmux-claude-resume](https://github.com/zdzolton/tmux-claude-resume) saves your Claude Code sessions (and Neovim buffers) in tmux. After a reboot, one command restores them.

1. Clone it and make the scripts executable:

   ```bash
   git clone https://github.com/zdzolton/tmux-claude-resume ~/code/tmux-claude-resume
   chmod +x ~/code/tmux-claude-resume/*.sh
   ```

2. Install the autosave agent. It saves every 5 minutes and at login. Follow the "Autosave" section of its README. It has a plist template and the commands to render and load it.

3. Check it: `launchctl print gui/$(id -u)/local.tmux-claude-resume.save`

4. After a reboot, run `~/code/tmux-claude-resume/restore-tmux-claude-sessions.sh`

Logs go to `~/Library/Logs/tmux-claude-resume-save.log`.

## Troubleshooting

Run `./doctor.sh` first. It checks tools, links, and settings.

| Symptom | Cause and fix |
|---------|---------------|
| Every step opens a new split with a new Neovim | The old Neovim has no socket on its window and the fallback missed it. Close the extra pane and run `nvim-open` again. If it persists, restart Neovim after you add the plugin. |
| `Neovim cannot load tmux_review` | With lazy.nvim, add the spec (`--print-nvim-spec`). The `--nvim-pack` option does not work with lazy.nvim. |
| A permission prompt on every step | Add `Bash(nvim-open:*)` to `permissions.allow`. |
| Nothing happens, and no error | You are not in tmux. `nvim-open` needs `$TMUX` and `$TMUX_PANE`. |
| `nvim-open: Neovim runs in this window but its socket was not found` | The window has a Neovim that the script cannot reach. Restart that Neovim. |

## Development

```bash
make check      # shellcheck, stylua, leak scan, and tests
make test       # tests only
```

The leak scan always runs generic checks (home paths and email addresses). It also reads your own list of words that must never appear, such as company names, internal hosts, and ticket keys.

To set up the list:

```bash
mkdir -p ~/.config/tmux-nvim-claude
cp scripts/private-patterns.example ~/.config/tmux-nvim-claude/private-patterns
```

Edit the copy. Use one regex per line. Keep the copy out of the repo. The example file holds placeholder words only.

The list lives on your machine. CI and other clones run only the generic checks. If you accept changes from others, review them for these words yourself, or share the list with them in private.

The tests run on a separate tmux server (`tmux -L`). They never touch your own tmux. See `CLAUDE.md` for the rules for this repo.

## License

BSD 2-Clause. See `LICENSE`.

## Limits

- For a hunk with several change blocks, only the header range is highlighted.
- Paths that contain `"` or `\` are not supported.
