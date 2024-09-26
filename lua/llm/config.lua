local M = {}

-- Default configuration
M.defaults = {
	models = {
		ollama_default = {
			model_name = "llama3.2", -- Replace with your specific Ollama model name
			url = "http://localhost:11434/api/generate",
			max_tokens = 150,
			temperature = 0.7,
			suffix = "",
			options = {
				-- Add any additional Ollama-specific parameters here
				-- For example:
				-- seed = 42,
				-- stop = {"\n", "user:"},
			},
		},
		-- Add more Ollama models as needed
	},
	default_model = "ollama_default",
	prompt = "Please assist me with the following code:",
	model_shortcuts = {
		["<leader>lg"] = "ollama_default",
		-- Define more shortcuts as needed
	},
}

M.settings = {}

-- Setup function to merge user configuration with defaults
function M.setup(user_config)
	M.settings = vim.tbl_deep_extend("force", {}, M.defaults, user_config or {})
end

-- Getter functions
function M.get_prompt()
	return M.settings.prompt
end

function M.get_selected_model()
	return M.settings.default_model
end

function M.get_model_config(model)
	return M.settings.models[model]
end

function M.get_model_shortcuts()
	return M.settings.model_shortcuts
end

return M
