local M = {}
local api = require("llm.api")

for k, v in pairs(api) do
	M[k] = v
end

return M
