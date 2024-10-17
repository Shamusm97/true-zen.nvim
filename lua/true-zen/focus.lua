local M = {}

M.running = false
M.prev_tabno = nil
local data = require("true-zen.utils.data")
local echo = require("true-zen.utils.echo")

function M.on()
	data.do_callback("focus", "open", "pre")

	if vim.fn.winnr("$") == 1 then
		echo("there is only one window open", "error")
		return
	end

	M.prev_tabnr = vim.fn.tabpagenr()

	local current_buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_command('tabnew')
	vim.api.nvim_set_current_buf(current_buf)

	M.running = true

	data.do_callback("focus", "open", "pos")
end

function M.off()
	data.do_callback("focus", "close", "pre")

	vim.cmd("tabclose")
	if M.prev_tabnr ~= nil then
		vim.api.tabpage.set(M.prev_tabnr)
	end
	M.running = false

	data.do_callback("focus", "close", "pos")
end

function M.toggle()
	if M.running then
		M.off()
	else
		M.on()
	end
end

return M
