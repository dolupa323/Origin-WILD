--!strict
-- Shared/Util/Table.lua

local TableUtil = {}

function TableUtil.shallowCopy<T>(t: { [any]: any }): { [any]: any }
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

return TableUtil
