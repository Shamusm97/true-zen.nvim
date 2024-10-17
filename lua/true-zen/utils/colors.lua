local M = {}
---@param hex_str string hexadecimal value of a color
local hex_to_rgb = function(hex_str)
	local hex = "[abcdef0-9][abcdef0-9]"
	local pat = "^#(" .. hex .. ")(" .. hex .. ")(" .. hex .. ")$"
	hex_str = string.lower(hex_str)

	assert(string.find(hex_str, pat) ~= nil, "hex_to_rgb: invalid hex_str: " .. tostring(hex_str))

	local red, green, blue = string.match(hex_str, pat)
	return { tonumber(red, 16), tonumber(green, 16), tonumber(blue, 16) }
end

function M.highlight(group, color, force)
	if color.link then
		vim.api.nvim_set_hl(0, group, {
			link = color.link,
		})
	else
		if color.style then
			for _, style in ipairs(color.style) do
				color[style] = true
			end
		end
		color.style = nil
		if force then
			vim.cmd("hi " .. group .. " guifg=" .. (color.fg or "NONE") .. " guibg=" .. (color.bg or "NONE"))
			return
		end
		vim.api.nvim_set_hl(0, group, color)
	end
end

-- TODO: is this the correct way to do this?
function M.get_hl_fbs_hex(name)
	-- Check if the highlight exists
    local hl = vim.api.nvim_get_hl(0, { name = name })
    if not hl then return nil end

	-- Get the foreground, background, and special colors
	-- and convert them to hex format
    local color_keys = { "foreground", "background", "special" }
    for _, key in ipairs(color_keys) do
        if hl[key] then
            hl[key] = string.format("#%06x", hl[key])
        end
    end
    return hl
end

---@param fg string forecrust color
---@param bg string background color
---@param alpha number number between 0 and 1. 0 results in bg, 1 results in fg
function M.blend(fg, bg, alpha)
	bg = hex_to_rgb(bg)
	fg = hex_to_rgb(fg)

	local blendChannel = function(i)
		local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
		return math.floor(math.min(math.max(0, ret), 255) + 0.5)
	end

	return string.format("#%02X%02X%02X", blendChannel(1), blendChannel(2), blendChannel(3))
end

function M.darken(hex, amount, bg)
	return M.blend(hex, bg or M.bg, math.abs(amount))
end

function M.lighten(hex, amount, fg)
	return M.blend(hex, fg or M.fg, math.abs(amount))
end

return M
