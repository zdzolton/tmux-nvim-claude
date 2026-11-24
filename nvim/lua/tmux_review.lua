local M = {}

local ns = vim.api.nvim_create_namespace("tmux_review_hunk")

-- A tmux window option lets an external script find this instance's RPC socket.
function M.register()
	if not vim.env.TMUX then
		return
	end
	vim.api.nvim_create_autocmd("VimEnter", {
		group = vim.api.nvim_create_augroup("tmux_review_register", { clear = true }),
		callback = function()
			vim.system({ "tmux", "set-option", "-w", "-t", vim.env.TMUX_PANE, "@nvim_server", vim.v.servername })
		end,
	})
end

function M.clear()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	end
end

local MAX_RANGE = 40
local HEAD_LINES = 3

local function mark(buf, line)
	vim.api.nvim_buf_set_extmark(buf, ns, line - 1, 0, { line_hl_group = "Visual", priority = 200 })
end

-- A long range would fill the screen and hide the code. Show its start and its last line.
local function highlight(buf, first, last)
	if last - first + 1 <= MAX_RANGE then
		for line = first, last do
			mark(buf, line)
		end
		return
	end
	local head_last = first + HEAD_LINES - 1
	for line = first, head_last do
		mark(buf, line)
	end
	local hidden = last - head_last - 1
	vim.api.nvim_buf_set_extmark(buf, ns, head_last - 1, 0, {
		virt_text = { { ("  … %d more lines, to line %d"):format(hidden, last), "Comment" } },
		virt_text_pos = "eol",
	})
	mark(buf, last)
end

--- Open a file in a tab and highlight line ranges.
--- Put the cursor on the first range.
--- Set the tab directory to the git root of the file, if it has one.
--- Returns an empty string because it is called through `--remote-expr`.
---@param path string absolute file path
---@param ranges integer[][] list of `{first, last}` pairs
function M.open(path, ranges)
	M.clear()
	vim.cmd("tab drop " .. vim.fn.fnameescape(path))
	-- Language servers that root at the cwd must see the worktree that holds the file.
	local root = vim.fs.root(path, ".git")
	if root then
		vim.cmd("tcd " .. vim.fn.fnameescape(root))
	end
	local buf = vim.api.nvim_get_current_buf()
	local count = vim.api.nvim_buf_line_count(buf)
	local cursor
	for _, range in ipairs(ranges) do
		local first = math.max(1, math.min(range[1], count))
		local last = math.max(first, math.min(range[2], count))
		cursor = cursor or first
		highlight(buf, first, last)
	end
	vim.api.nvim_win_set_cursor(0, { cursor or 1, 0 })
	vim.cmd("normal! zz")
	vim.cmd("redraw")
	return ""
end

--- Move the cursor to a line in the current buffer. Keep the highlights.
--- Returns an empty string because it is called through `--remote-expr`.
---@param line integer
function M.focus(line)
	local count = vim.api.nvim_buf_line_count(0)
	vim.api.nvim_win_set_cursor(0, { math.max(1, math.min(line, count)), 0 })
	vim.cmd("normal! zz")
	vim.cmd("redraw")
	return ""
end

return M
