--!strict
-- Server/Controllers/NetController.lua
-- Phase 0-3: RemoteFunction Cmd + RemoteEvent Evt + requestId dedup(10s) + 라우팅 + Ping/Echo

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Protocol"))

type Result<T> = {
	ok: boolean,
	errorCode: string?,
	errorMessage: string?,
	data: T?,
}

type RequestPayload = {
	requestId: string?,
	[text: string]: any,
}

local NetController = {}

-- ---- Internal: Logging ----
local function _serverTimeMs(): number
	return math.floor(os.clock() * 1000)
end

local function _log(level: string, service: string, requestId: string?, userId: number?, message: string, data: string?)
	local t = _serverTimeMs()
	local rid = requestId and ("[" .. requestId .. "]") or "[]"
	local uid = userId and ("[u=" .. tostring(userId) .. "]") or "[]"
	local suffix = data and (" | data=" .. data) or ""
	print(("[T=%d][%s][%s]%s%s %s%s"):format(t, service, level, rid, uid, message, suffix))
end

local function _ok<T>(data: T?): Result<T>
	return { ok = true, data = data }
end

local function _err<T>(code: string, message: string?): Result<T>
	return { ok = false, errorCode = code, errorMessage = message }
end

-- ---- Internal: Dedup Cache (10s TTL) ----
local DEDUP_TTL_MS = 10_000

type CacheEntry = {
	tMs: number,
	result: any,
}

local _dedupCache: { [string]: CacheEntry } = {}

local function _dedupGet(requestId: string): any?
	local entry = _dedupCache[requestId]
	if not entry then
		return nil
	end
	if (_serverTimeMs() - entry.tMs) > DEDUP_TTL_MS then
		_dedupCache[requestId] = nil
		return nil
	end
	return entry.result
end

local function _dedupPut(requestId: string, result: any)
	_dedupCache[requestId] = { tMs = _serverTimeMs(), result = result }
end

local function _dedupPrune()
	-- 간단 prune: 호출마다 오래된 항목 제거(소규모라 충분)
	local now = _serverTimeMs()
	for rid, entry in pairs(_dedupCache) do
		if (now - entry.tMs) > DEDUP_TTL_MS then
			_dedupCache[rid] = nil
		end
	end
end

-- ---- Internal: Remotes ----
local _remotesFolder: Folder
local _cmd: RemoteFunction
local _evt: RemoteEvent

local function _getOrCreateRemotes()
	local folderName = Protocol.Remotes.FolderName
	local cmdName = Protocol.Remotes.CmdName
	local evtName = Protocol.Remotes.EvtName

	local folder = ReplicatedStorage:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = ReplicatedStorage
	end

	local cmd = folder:FindFirstChild(cmdName)
	if not cmd then
		local rf = Instance.new("RemoteFunction")
		rf.Name = cmdName
		rf.Parent = folder
		cmd = rf
	end

	local evt = folder:FindFirstChild(evtName)
	if not evt then
		local re = Instance.new("RemoteEvent")
		re.Name = evtName
		re.Parent = folder
		evt = re
	end

	_remotesFolder = folder :: Folder
	_cmd = cmd :: RemoteFunction
	_evt = evt :: RemoteEvent
end

-- ---- Internal: Handlers ----
type Handler = (player: Player, payload: RequestPayload) -> any

local _routes: { [string]: Handler } = {}

local function _registerRoutes()
	_routes[Protocol.Commands.Ping] = function(_player: Player, _payload: RequestPayload)
		return _ok({ serverTimeMs = _serverTimeMs() })
	end

	_routes[Protocol.Commands.Echo] = function(_player: Player, payload: RequestPayload)
		local text = payload.text
		if typeof(text) ~= "string" then
			return _err(Protocol.ErrorCodes.NET_BAD_REQUEST, "Echo requires payload.text:string")
		end
		return _ok({ text = text })
	end
end

-- ---- RemoteFunction entry ----
local function _onInvoke(player: Player, commandName: any, payload: any)
	_dedupPrune()

	if typeof(commandName) ~= "string" then
		return _err(Protocol.ErrorCodes.NET_BAD_REQUEST, "commandName must be string")
	end
	if typeof(payload) ~= "table" then
		return _err(Protocol.ErrorCodes.NET_BAD_REQUEST, "payload must be table")
	end

	local requestId = payload.requestId
	if typeof(requestId) ~= "string" or requestId == "" then
		_log("WARN", "NetController", nil, player.UserId, "Reject missing requestId", "cmd=" .. tostring(commandName))
		return _err(Protocol.ErrorCodes.NET_MISSING_REQUEST_ID, "requestId is required")
	end

	-- dedup hit
	local cached = _dedupGet(requestId)
	if cached ~= nil then
		_log("INFO", "NetController", requestId, player.UserId, "Dedup cache hit", "cmd=" .. commandName)
		return cached
	end

	local handler = _routes[commandName]
	if not handler then
		local res = _err(Protocol.ErrorCodes.NET_UNKNOWN_COMMAND, "Unknown command: " .. commandName)
		_dedupPut(requestId, res)
		_log("WARN", "NetController", requestId, player.UserId, "Unknown command", "cmd=" .. commandName)
		return res
	end

	_log("INFO", "NetController", requestId, player.UserId, "Request received", "cmd=" .. commandName)

	local okCall, res = pcall(handler, player, payload :: RequestPayload)
	if not okCall then
		local errRes = _err("NET_HANDLER_ERROR", tostring(res))
		_dedupPut(requestId, errRes)
		_log("ERROR", "NetController", requestId, player.UserId, "Handler crashed", "cmd=" .. commandName)
		return errRes
	end

	_dedupPut(requestId, res)
	_log("INFO", "NetController", requestId, player.UserId, "Request handled", "cmd=" .. commandName)

	return res
end

function NetController.init()
	_getOrCreateRemotes()
	_registerRoutes()

	_cmd.OnServerInvoke = _onInvoke

	_log("INFO", "NetController", nil, nil, "Initialized", "remotes=" .. _remotesFolder.Name)
end

return NetController
