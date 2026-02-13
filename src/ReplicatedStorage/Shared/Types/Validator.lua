--!strict
-- Shared/Types/Validator.lua
-- Phase 0-2: 최소 유틸. Phase 1-4 DataService에서 본격 사용.

local Validator = {}

export type Result<T> = {
	ok: boolean,
	errorCode: string?,
	errorMessage: string?,
	data: T?,
}

function Validator.ok<T>(data: T?): Result<T>
	return { ok = true, data = data }
end

function Validator.err<T>(code: string, message: string?): Result<T>
	return { ok = false, errorCode = code, errorMessage = message }
end

-- placeholder: later add schema checks
function Validator.validate(_schema: any, _value: any): Result<any>
	return Validator.ok()
end

return Validator
