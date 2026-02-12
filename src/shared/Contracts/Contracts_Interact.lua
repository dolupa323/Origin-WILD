local C = {}

C.Error = {
	OK = "OK",
	VALIDATION_FAILED = "VALIDATION_FAILED",
	OUT_OF_RANGE = "OUT_OF_RANGE",
	COOLDOWN = "COOLDOWN",
	NOT_FOUND = "NOT_FOUND",
	DENIED = "DENIED",
	INTERNAL_ERROR = "INTERNAL_ERROR",
}

-- 서버가 인정하는 상호작용 대상 태그(Phase0 고정)
C.InteractableTag = "Interactable"

return C
