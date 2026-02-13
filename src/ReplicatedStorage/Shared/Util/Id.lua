--!strict
-- Shared/Util/Id.lua

local HttpService = game:GetService("HttpService")

local Id = {}

function Id.newRequestId(): string
	-- requestId는 Phase 0-3에서 필수 사용
	return HttpService:GenerateGUID(false)
end

return Id
