STYLUA := $(shell command -v stylua || echo $(HOME)/.local/share/nvim/mason/bin/stylua)
SH_FILES := bin/nvim-open bin/prune-worktrees bin/tmux-window-notify.sh install.sh doctor.sh \
	scripts/check-private.sh tests/nvim-open.test.sh tests/hook.test.sh claude/statusline-command.sh

.PHONY: check lint test private

check: lint private test

lint:
	@for f in $(SH_FILES); do bash -n $$f || exit 1; done
	@shellcheck -S warning $(SH_FILES)
	@$(STYLUA) --check nvim
	@jq empty claude/settings.template.json

private:
	@scripts/check-private.sh

test:
	@tests/hook.test.sh
	@tests/nvim-open.test.sh
