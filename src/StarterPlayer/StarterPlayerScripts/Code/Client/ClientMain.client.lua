--!strict
-- Code/Client/ClientMain.client.lua
-- Phase 0-3: 클라 부팅 시 NetClient만 초기화
-- Note: ClientMain과 NetClient는 같은 Client 폴더 안의 형제 → script.Parent 사용

local NetClient = require(script.Parent:WaitForChild("NetClient"))
NetClient.init()
