-- Net.lua
-- Phase0-0-2 (FINAL)
-- Server creates/remotes registry. Client never creates remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local CodeFolder = ReplicatedStorage:FindFirstChild("Code")
if not CodeFolder then
	error("[Net] ReplicatedStorage/Code not found (case-sensitive). Fix Rojo mapping.")
end

local RemotesFolder = CodeFolder:FindFirstChild("Remotes")
if not RemotesFolder then
	RemotesFolder = Instance.new("Folder")
	RemotesFolder.Name = "Remotes"
	RemotesFolder.Parent = CodeFolder
end

local Net = {}

-- Server-only: pre-create remote endpoints (contract)
function Net.Register(names: {string})
	assert(IS_SERVER, "Net.Register is server only")
	for _, name in ipairs(names) do
		local existing = RemotesFolder:FindFirstChild(name)
		if existing then
			if not existing:IsA("RemoteEvent") then
				error(("[Net] Name conflict: %s exists but is %s"):format(name, existing.ClassName))
			end
		else
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = RemotesFolder
		end
	end
end

local function getRemoteServer(name: string): RemoteEvent
	-- Server: create-on-demand allowed
	local r = RemotesFolder:FindFirstChild(name)
	if r then
		if r:IsA("RemoteEvent") then return r end
		error(("[Net] Name conflict: %s exists but is %s"):format(name, r.ClassName))
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = RemotesFolder
	return remote
end

local function getRemoteClient(name: string): RemoteEvent
	-- Client: NEVER create. Wait only.
	local r = RemotesFolder:WaitForChild(name)
	if not r:IsA("RemoteEvent") then
		error(("[Net] Remote %s exists but is %s"):format(name, r.ClassName))
	end
	return r
end

local function getRemote(name: string): RemoteEvent
	if IS_SERVER then
		return getRemoteServer(name)
	else
		return getRemoteClient(name)
	end
end

-- Client -> Server: Net.Fire("X", payload)
-- Server -> Client: Net.Fire("X", player, payload)
function Net.Fire(name: string, a, b)
	local remote = getRemote(name)
	if IS_SERVER then
		remote:FireClient(a, b)
	else
		remote:FireServer(a)
	end
end

function Net.Broadcast(name: string, payload)
	assert(IS_SERVER, "Broadcast is server only")
	local remote = getRemote(name)
	remote:FireAllClients(payload)
end

function Net.On(name: string, handler)
	local remote = getRemote(name)
	if IS_SERVER then
		remote.OnServerEvent:Connect(handler)
	else
		remote.OnClientEvent:Connect(handler)
	end
end

return Net
