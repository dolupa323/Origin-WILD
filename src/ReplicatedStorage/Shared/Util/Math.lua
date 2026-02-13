--!strict
-- Shared/Util/Math.lua

local MathUtil = {}

function MathUtil.clamp(n: number, minV: number, maxV: number): number
	if n < minV then return minV end
	if n > maxV then return maxV end
	return n
end

return MathUtil
