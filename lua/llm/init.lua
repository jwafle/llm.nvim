local M = {}
local api = require("llm.api")
local config = require("llm.config")

-- Setup function to configure the plugin
function M.setup(user_config)
	-- Merge user configuration with default configuration
	config.setup(user_config)

	-- Define keybindings for each model
	M.define_keybindings()
end

-- Function to define keybindings based on user configuration
function M.define_keybindings()
	local opts = { noremap = true, silent = true }

	-- Iterate over model shortcuts and set keybindings
	local shortcuts = config.get_model_shortcuts()
	for shortcut, model in pairs(shortcuts) do
		vim.api.nvim_set_keymap(
			"v",
			shortcut,
			string.format(':lua require("llm.api").open_hover_window_with_model("%s")<CR>', model),
			opts
		)
	end
end

return M
