--!strict
-- Shared/Net/Protocol.lua
-- Phase 0-3: NetProtocol v1 최소 작동 (Ping/Echo)

local Protocol = {}

Protocol.Remotes = {
	FolderName = "Remotes",
	CmdName = "Cmd", -- RemoteFunction
	EvtName = "Evt", -- RemoteEvent
}

Protocol.Commands = {
	Ping = "Net.Ping.Request",
	Echo = "Net.Echo.Request",
}

Protocol.Results = {
	Ping = "Net.Ping.Result",
	Echo = "Net.Echo.Result",
}

Protocol.ErrorCodes = {
	NET_UNKNOWN_COMMAND = "NET_UNKNOWN_COMMAND",
	NET_BAD_REQUEST = "NET_BAD_REQUEST",
	NET_MISSING_REQUEST_ID = "NET_MISSING_REQUEST_ID",
	NET_DUPLICATE_REQUEST_ID = "NET_DUPLICATE_REQUEST_ID", -- (캐시 hit일 때도 ok로 돌려줌. 이 코드는 보조용)
}

return Protocol
