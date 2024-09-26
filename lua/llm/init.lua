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

	-- Retrieve model shortcuts from configuration
	local shortcuts = config.get_model_shortcuts()

	-- Iterate over model shortcuts and set keybindings for Normal and Visual modes
	for shortcut, model in pairs(shortcuts) do
		-- Normal mode keybinding
		vim.keymap.set("n", shortcut, function()
			api.open_hover_window_with_model(model)
		end, opts)

		-- Visual mode keybinding
		vim.keymap.set("v", shortcut, function()
			api.open_hover_window_with_model(model)
		end, opts)
	end
end

return M
