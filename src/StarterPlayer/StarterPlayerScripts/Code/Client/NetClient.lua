--!strict
-- StarterPlayerScripts/Code/Client/NetClient.lua
-- Phase 0-3: Cmd(RemoteFunction) 호출 래퍼 + requestId 생성

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Protocol"))

type Result<T> = {
	ok: boolean,
	errorCode: string?,
	errorMessage: string?,
	data: T?,
}

local NetClient = {}

local _cmd: RemoteFunction? = nil
local _evt: RemoteEvent? = nil

local function _getRemotes()
	local folder = ReplicatedStorage:WaitForChild(Protocol.Remotes.FolderName)
	_cmd = folder:WaitForChild(Protocol.Remotes.CmdName) :: RemoteFunction
	_evt = folder:WaitForChild(Protocol.Remotes.EvtName) :: RemoteEvent
end

local function _newRequestId(): string
	return HttpService:GenerateGUID(false)
end

function NetClient.request<T>(commandName: string, payload: { [string]: any }?): Result<T>
	if not _cmd then
		_getRemotes()
	end
	local p = payload or {}
	p.requestId = p.requestId or _newRequestId()

	-- InvokeServer(commandName, payload)
	local res = (_cmd :: RemoteFunction):InvokeServer(commandName, p)
	return res
end

function NetClient.init()
	_getRemotes()

	-- Phase 0-3에서는 이벤트는 "받기만" (0-3 DoD에는 필수 아님)
	(_evt :: RemoteEvent).OnClientEvent:Connect(function(eventName: any, eventPayload: any)
		print("[NetClient] Event:", eventName, eventPayload)
	end)

	-- Sanity log
	print("[NetClient] Initialized. Remotes ready.")
end

return NetClient
