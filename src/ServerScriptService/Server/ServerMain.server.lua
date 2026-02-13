--!strict
-- Server/ServerMain.server.lua
-- Phase 0-3: 서버 부팅 시 NetController만 초기화

local ServerScriptService = game:GetService("ServerScriptService")

local NetController = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Controllers"):WaitForChild("NetController"))

NetController.init()
