local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local function applyGenwinCheat(player)
	print("--- CHEAT ACTIVATED: GENWIN FOR " .. player.Name .. " ---")

	-- 1. Infinite Gold
	local stats = player:FindFirstChild("leaderstats")
	if stats and stats:FindFirstChild("Gold") then
		stats.Gold.Value = stats.Gold.Value + 99999
	end

	-- 2. God Mode HP & Super Speed
	if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		hum.MaxHealth = 999999
		hum.Health = 999999
		hum.WalkSpeed = 60
		hum.UseJumpPower = false
		hum.JumpHeight = 25
	end

	-- 3. Grant 10x Stacks of ALL Items!
	local buffs = player:FindFirstChild("Buffs") or Instance.new("Folder")
	buffs.Name = "Buffs"
	buffs.Parent = player

	local allItems = {
		"FirstStompens", "Dagger", "BunnyHoppers", 
		"PaulsJumpBoots", "CharliesFarsight", "Goblin", "Splitshot"
	}

	for _, itemName in ipairs(allItems) do
		local itemVal = buffs:FindFirstChild(itemName) or Instance.new("IntValue")
		itemVal.Name = itemName
		itemVal.Value = itemVal.Value + 10
		itemVal.Parent = buffs
	end
end

-- T1WIN: Teleport player to the closest teleporter
local function applyT1WinCheat(player)
	print("--- CHEAT ACTIVATED: T1WIN FOR " .. player.Name .. " ---")

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		print("T1WIN: No character to teleport.")
		return
	end

	local root = character.HumanoidRootPart
	local target = nil

	-- 1. Prefer the active teleporter in Workspace
	local activeTeleporter = Workspace:FindFirstChild("ActiveTeleporter")
	if activeTeleporter then
		target = activeTeleporter
	end

	-- 2. Fallback: nearest TeleporterSpawn node on the active map
	if not target then
		local map = Workspace:FindFirstChild("Map")
		local spawnNodes = map and map:FindFirstChild("SpawnNodes")
		if spawnNodes then
			local bestNode, bestDist = nil, math.huge
			for _, node in ipairs(spawnNodes:GetChildren()) do
				if string.find(node.Name, "TeleporterSpawn") then
					local dist = (node.Position - root.Position).Magnitude
					if dist < bestDist then
						bestDist = dist
						bestNode = node
					end
				end
			end
			target = bestNode
		end
	end

	if not target then
		print("T1WIN: No teleporter found.")
		return
	end

	-- Teleport player to the teleporter (slightly above it)
	local teleportPos = target.Position + Vector3.new(0, 4, 0)
	root.CFrame = CFrame.new(teleportPos)
	print("T1WIN: Teleported " .. player.Name .. " to " .. target.Name)
end

-- Listen for player input "genwin" / "t1win"
local function setupPlayerChat(player)
	player.Chatted:Connect(function(message)
		local msg = string.lower(message)
		if msg == "genwin" then
			applyGenwinCheat(player)
		elseif msg == "t1win" then
			applyT1WinCheat(player)
		end
	end)
end

Players.PlayerAdded:Connect(setupPlayerChat)
for _, p in ipairs(Players:GetPlayers()) do
	setupPlayerChat(p)
end