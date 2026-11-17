# Rules for this repo

This repo is meant to be shared. Keep it free of private or employer-specific content.

## Before you commit

- Run `make check`. It runs shellcheck, stylua, a leak scan, and the tests.
- Put private strings in the local file `~/.config/tmux-nvim-claude/private-patterns`, never in the repo. `scripts/check-private.sh` reads it.
- Never add company names, internal service names, ticket keys, hostnames, or absolute home paths. Use `$HOME` or a placeholder such as `__REPO__`.
- Never add secrets or read secret files. The installer must not read or print them.

## Scripts

- Shell scripts must run on the macOS system bash (3.2). Do not use bash 4 features such as `mapfile` or associative arrays.
- The installer only creates symlinks. It must never overwrite a file without `--force`. It must never edit `settings.json`, `CLAUDE.md`, or shell files.
- Scripts that run inside a Claude session must not fail the caller for runtime problems. `nvim-open` exits 0 for those. It exits 2 for bad arguments.

## Neovim

- Lua uses tabs. Format with `stylua nvim`.
- lazy.nvim ignores `site/pack`. Keep the `dir =` spec as the main install path.

## Tests

- Tests must use their own tmux server (`tmux -L <name>`). Never use the default tmux server.
- Clean up every process and socket the test creates.

## Docs

- Write README text in short, simple sentences. Use direct commands.
- When behavior changes, update `README.md` and `doctor.sh` in the same commit.
