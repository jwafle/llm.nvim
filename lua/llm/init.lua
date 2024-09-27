local M = {}
local api = require("llm.api")

function M.create_llm(opts, make_curl_args_fn, handle_data_fn)
	api.invoke_llm_and_stream_into_editor(opts, make_curl_args_fn, handle_data_fn)
end

return M
