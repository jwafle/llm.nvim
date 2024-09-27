local M = {}
local config = require("llm.config")
local Job = require("plenary.job") -- Using plenary.nvim's Job module

-- State to keep track of the floating window and buffer
M.state = {
	buf = nil,
	win = nil,
	selected_model = nil,
}

-- Function to open the floating window with selected text and a specific model
function M.open_hover_window_with_model(model)
	-- Get selected text in visual mode
	local selected_text = M.get_visual_selection()
	if not selected_text or selected_text == "" then
		vim.notify("No text selected", vim.log.levels.WARN)
		return
	end

	vim.notify("Selected text: " .. selected_text, vim.log.levels.DEBUG)

	-- Create a new buffer
	local buf = vim.api.nvim_create_buf(false, true) -- (listed, scratch)
	if not buf then
		vim.notify("Failed to create buffer.", vim.log.levels.ERROR)
		return
	end
	M.state.buf = buf

	-- Define window dimensions
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.6)
	local row = math.floor((vim.o.lines - height) / 2 - 1)
	local col = math.floor((vim.o.columns - width) / 2)

	-- Window options
	local opts = {
		style = "minimal",
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
	}

	-- Create floating window
	local success, win = pcall(vim.api.nvim_open_win, buf, true, opts)
	if not success then
		vim.notify("Failed to open floating window.", vim.log.levels.ERROR)
		return
	end
	M.state.win = win

	-- Insert prompt and selected text
	local prompt = config.get_prompt()
	local initial_content = prompt .. "\n\n" .. selected_text
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(initial_content, "\n"))

	-- Set filetype for better syntax highlighting (optional)
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown") -- Example filetype

	-- Store the selected model
	M.state.selected_model = model

	-- Set keybindings inside the window
	M.set_window_keybindings(buf)
end

-- Function to open the floating window with the default model
function M.open_hover_window()
	local default_model = config.get_selected_model()
	M.open_hover_window_with_model(default_model)
end

-- Helper function to get visual selection
function M.get_visual_selection()
	-- Save current view
	local view = vim.fn.winsaveview()

	-- Get the current mode
	local mode = vim.fn.mode()

	-- If not in visual mode, notify and return
	if not (mode == "v" or mode == "V" or mode == "\22") then
		vim.notify("Please select text in visual mode first.", vim.log.levels.WARN)
		return nil
	end

	-- Get selection positions
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	-- Ensure start is before end
	if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
		start_pos, end_pos = end_pos, start_pos
	end

	local lines = vim.fn.getline(start_pos[2], end_pos[2])

	-- For block mode, get the columns and extract the block
	if mode == "\22" then
		local start_col = start_pos[3]
		local end_col = end_pos[3]
		-- Handle cases where end_col < start_col
		if end_col < start_col then
			start_col, end_col = end_col, start_col
		end
		local selected_block = {}
		for _, line in ipairs(lines) do
			-- Ensure columns are within line length
			local line_len = #line
			local s = math.max(start_col, 1)
			local e = math.min(end_col, line_len)
			local substring = string.sub(line, s, e)
			table.insert(selected_block, substring)
		end
		return table.concat(selected_block, "\n")
	else
		-- Line-wise or character-wise visual mode
		return table.concat(lines, "\n")
	end
end

-- Function to set keybindings inside the floating window
function M.set_window_keybindings(buf)
	-- <C-s> to send to LLM
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<C-s>",
		':lua require("llm.api").send_to_llm()<CR>',
		{ noremap = true, silent = true }
	)

	-- <C-c> to close the window
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<C-c>",
		':lua require("llm.api").close_hover_window()<CR>',
		{ noremap = true, silent = true }
	)
end

-- Function to send buffer content to LLM
function M.send_to_llm()
	local buf = M.state.buf
	if not buf or not vim.api.nvim_buf_is_loaded(buf) then
		vim.notify("No active LLM window.", vim.log.levels.ERROR)
		return
	end

	-- Get the content from the buffer
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local content = table.concat(lines, "\n")

	-- Split content into prompt and user text
	local prompt, user_text = content:match("^(.-)\n\n(.*)$")
	if not prompt or not user_text or user_text == "" then
		vim.notify("Invalid format. Ensure prompt and text are separated by two newlines.", vim.log.levels.ERROR)
		return
	end

	vim.notify("Prompt: " .. prompt, vim.log.levels.DEBUG)
	vim.notify("User Text: " .. user_text, vim.log.levels.DEBUG)

	-- Get the selected LLM model
	local model = M.state.selected_model or config.get_selected_model()
	vim.notify("Using model: " .. model, vim.log.levels.INFO)

	-- Send request to Ollama's /api/generate endpoint asynchronously using plenary.job with curl
	M.call_llm_api(model, prompt, user_text, function(response)
		-- Insert response into the buffer
		vim.schedule(function()
			-- Find the index to insert response
			local response_header = "Response:"
			local existing = vim.fn.search(response_header, "nw")
			if existing == 0 then
				vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "", response_header, response })
			else
				vim.api.nvim_buf_set_lines(buf, existing + 1, existing + 1, false, { response })
			end
		end)
	end)
end

-- Function to make API call to Ollama's /api/generate using plenary.job with curl
function M.call_llm_api(model, prompt, user_text, callback)
	-- Retrieve model configuration
	local model_config = config.get_model_config(model)
	if not model_config then
		vim.notify("Model configuration for '" .. model .. "' not found.", vim.log.levels.ERROR)
		return
	end

	local url = model_config.url

	if not url then
		vim.notify("API URL for model '" .. model .. "' is not configured.", vim.log.levels.ERROR)
		return
	end

	-- Prepare the request body
	local request_body = vim.json.encode({
		model = model_config.model_name,
		prompt = prompt .. "\n" .. user_text,
		stream = false, -- Disable streaming
		suffix = model_config.suffix,
		options = model_config.options,
	})

	-- Prepare headers
	local headers = {
		"-H",
		"Content-Type: application/json",
	}

	-- Use plenary.job to execute curl asynchronously
	Job:new({
		command = "curl",
		args = {
			"-s", -- Silent mode
			"-X",
			"POST",
			"-d",
			request_body,
			unpack(headers),
			url,
		},
		on_exit = function(j, return_val)
			if return_val ~= 0 then
				vim.schedule(function()
					vim.notify("Ollama API request failed.", vim.log.levels.ERROR)
				end)
				return
			end

			local response = table.concat(j:result(), "\n")

			local success, parsed = pcall(vim.json.decode, response)

			if not success then
				vim.schedule(function()
					vim.notify("Failed to parse JSON response: " .. parsed, vim.log.levels.ERROR)
				end)
				return
			end

			-- Extract the 'response' field from the API response
			if parsed.response and parsed.response ~= "" then
				callback(parsed.response)
			else
				vim.schedule(function()
					vim.notify("No response text received from Ollama API.", vim.log.levels.ERROR)
				end)
			end
		end,
	}):start()
end

-- Function to close the floating window
function M.close_hover_window()
	if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
		vim.api.nvim_win_close(M.state.win, true)
		vim.notify("Floating window closed.", vim.log.levels.INFO)
		M.state.win = nil
		M.state.buf = nil
		M.state.selected_model = nil
	else
		vim.notify("No active LLM window to close.", vim.log.levels.WARN)
	end
end

return M
