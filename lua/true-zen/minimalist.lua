local M = {}

M.running = false
local colors = require("true-zen.utils.colors")
local data = require("true-zen.utils.data")
local config = require("true-zen.config").options
local IGNORED_BUF_TYPES = data.set_of(config.modes.minimalist.ignored_buf_types)

local original_opts = {}

vim.api.nvim_create_augroup("TrueZenMinimalist", {})

-- reference: https://vim.fandom.com/wiki/Run_a_command_in_multiple_buffers
local function alldo(run)
    -- Store current state
    local current_tab = vim.fn.tabpagenr()
    local current_win = vim.api.nvim_get_current_win()
    local current_buf = vim.api.nvim_get_current_buf()

    -- Get list of all buffers
    local buffers = vim.api.nvim_list_bufs()

    -- Function to check if a buffer is valid for our operations
    local function is_valid_buffer(buf)
        return vim.api.nvim_buf_is_valid(buf) and
               vim.bo[buf].modifiable and
               vim.bo[buf].buflisted and
               vim.bo[buf].bufhidden == ""
    end

    -- Iterate through each command in the run table
    for _, command in ipairs(run) do
        for _, buf in ipairs(buffers) do
            if is_valid_buffer(buf) then
                -- Set buffer in current window
                vim.api.nvim_win_set_buf(current_win, buf)

                -- Execute the command
                vim.cmd(command)
            end
        end
    end

    -- Clear any potential window-local variable
    vim.w.tz_buffer = nil

    -- Restore original state
    vim.api.nvim_set_current_tabpage(current_tab)
    vim.api.nvim_set_current_win(current_win)
    vim.api.nvim_set_current_buf(current_buf)
end

local function save_opts()
    local current_tab = vim.api.nvim_get_current_tabpage()
    local windows = vim.api.nvim_tabpage_list_wins(current_tab)

    -- Find a suitable window (one that doesn't have an ignored buffer type)
    local suitable_window = nil
    for _, win in ipairs(windows) do
        local buftype = vim.api.nvim_get_option_value("buftype", { win = win })
        if not IGNORED_BUF_TYPES[buftype] then
            suitable_window = win
            break
        end
    end

    -- If no suitable window found, use the first window
    suitable_window = suitable_window or windows[1]

    -- Save original options
	for user_opt, new_val in pairs(config.modes.minimalist.options) do
		local original_value = vim.o[user_opt]
		original_opts[user_opt] = original_value
		vim.o[user_opt] = new_val
	end

    -- Save original highlight groups
    original_opts.highlights = {
        StatusLine = M.get_hl_fbs_hex("StatusLine"),
        StatusLineNC = M.get_hl_fbs_hex("StatusLineNC"),
        TabLine = M.get_hl_fbs_hex("TabLine"),
        TabLineFill = M.get_hl_fbs_hex("TabLineFill"),
    }
end

function M.on()
	data.do_callback("minimalist", "open", "pre")

	save_opts()

	if config.modes.minimalist.options.number == false then
		alldo({ "set nonumber" })
	end

	if config.modes.minimalist.options.relativenumber == false then
		alldo({ "set norelativenumber" })
	end

	-- fully hide statusline and tabline
	local base = colors.get_hl_fbs_hex("Normal")["background"] or "NONE"
	for hi_group, _ in pairs(original_opts["highlights"]) do
		colors.highlight(hi_group, { bg = base, fg = base }, true)
	end

	if config.integrations.tmux == true then
		require("true-zen.integrations.tmux").on()
	end

	M.running = true
	data.do_callback("minimalist", "open", "pos")
end

function M.off()
	data.do_callback("minimalist", "close", "pre")

	vim.api.nvim_create_augroup("TrueZenMinimalist", {})

	if original_opts.number == true then
		alldo({ "set number" })
	end

	if original_opts.relativenumber == true then
		alldo({ "set relativenumber" })
	end

	original_opts.number = nil
	original_opts.relativenumber = nil

	for original_opt_key, original_opt_value in pairs(original_opts) do
		if original_opt_key ~= "highlights" then
			if not pcall(vim.vim.cmd, "set " .. original_opt_key .. "=" .. original_opt_value) then
				-- If vim.vim.cmd throws an error it's probably a "1" that represents a boolean value
				-- Then we must use "set $OPTION_NAME" or "set no$OPTION_NAME"
				-- For example for showmode we do "set showmode" or "set noshowmode"
				if original_opt_value == 1 then
					vim.vim.cmd("set " .. original_opt_key)
				else
					vim.vim.cmd("set no" .. original_opt_key)
				end
			end
		end
	end

	for hi_group, props in pairs(original_opts["highlights"]) do
		colors.highlight(hi_group, { fg = props.foreground, bg = props.background }, true)
	end

	if config.integrations.tmux == true then
		require("true-zen.integrations.tmux").off()
	end

	M.running = false
	data.do_callback("minimalist", "close", "pos")
end

function M.toggle()
	if M.running then
		M.off()
	else
		M.on()
	end
end

return M
