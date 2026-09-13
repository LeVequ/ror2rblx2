local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local chestTemplate = ReplicatedStorage:WaitForChild("Chest")
local itemRemote = ReplicatedStorage:WaitForChild("ItemAcquiredRemote")
local gameStartedVal = ReplicatedStorage:WaitForChild("GameStarted", 10)
local currentStageVal = ReplicatedStorage:WaitForChild("CurrentStage", 10)

-- === ITEM DEFINITIONS & LOOT TABLES ===
local LOOT_TABLE = {
	Common = {
		{Name = "FirstStompens", Title = "First Stompens", Desc = "+10% Movement Speed"},
		{Name = "Dagger", Title = "Dagger", Desc = "+12% Attack Speed"},
		{Name = "BunnyHoppers", Title = "Bunny Hoppers", Desc = "+12% Jump Height"}
	},
	Uncommon = {
		{Name = "PaulsJumpBoots", Title = "Paul's Jump Boots", Desc = "+30% Jump Height"},
		{Name = "CharliesFarsight", Title = "Charlie's Farsight", Desc = "+25% Attack Range"},
		{Name = "Goblin", Title = "Goblin", Desc = "+$4 Bonus Gold per Kill"}
	},
	Rare = {
		{Name = "Splitshot", Title = "Splitshot", Desc = "+12% Chance Ricochet (50% Dmg)"}
	}
}

local function rollRandomItem()
	local roll = math.random(1, 100)
	local rarity = (roll <= 5 and "Rare") or (roll <= 30 and "Uncommon") or "Common"
	local pool = LOOT_TABLE[rarity]
	return pool[math.random(1, #pool)], rarity
end

-- HELPER: SNAPS CHEST TO THE VISIBLE TOP SURFACE OF FLOOR MESH
local function getSurfaceCFrame(baseCFrame)
	local pos = baseCFrame.Position
	local rayStart = pos + Vector3.new(0, 60, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include

	local map = Workspace:FindFirstChild("Map")
	if map then
		raycastParams.FilterDescendantsInstances = {map, Workspace:FindFirstChild("Terrain")}
	end

	local result = Workspace:Raycast(rayStart, Vector3.new(0, -120, 0), raycastParams)
	if result then
		return CFrame.new(result.Position + Vector3.new(0, 1.5, 0))
	end
	return baseCFrame + Vector3.new(0, 1.5, 0)
end

-- HELPER: FIND THE ACTIVE MAP'S SPAWN NODES (loaded map in Workspace, else template in ReplicatedStorage.Maps)
local function getActiveMapSpawnNodes()
	-- Prefer the currently loaded map in Workspace
	local map = Workspace:FindFirstChild("Map")
	if map then
		local nodes = map:FindFirstChild("SpawnNodes")
		if nodes then return nodes end
	end

	-- Fall back to the current stage's map template in ReplicatedStorage.Maps
	local currentStage = ReplicatedStorage:FindFirstChild("CurrentStage")
	local stageNum = currentStage and currentStage.Value or 1
	local mapsFolder = ReplicatedStorage:FindFirstChild("Maps")
	local template = mapsFolder and mapsFolder:FindFirstChild("Stage" .. stageNum .. "Map")
	if template then
		return template:FindFirstChild("SpawnNodes")
	end
	return nil
end

-- FUNCTION TO SPAWN CHESTS FOR ACTIVE MAP
local function spawnChestsForCurrentMap()
	-- 1. Destroy old chests in Workspace
	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj.Name == "Chest" or (obj:IsA("Model") and obj:FindFirstChild("ProximityPrompt") and obj.ProximityPrompt.ObjectText == "Chest") then
			obj:Destroy()
		end
	end

	-- 2. Find current map's SpawnNodes folder
	local spawnNodesFolder = getActiveMapSpawnNodes()
	if not spawnNodesFolder then return end

	-- Collect all nodes named "ChestSpawn"
	local allChestNodes = {}
	for _, node in ipairs(spawnNodesFolder:GetChildren()) do
		if string.find(node.Name, "ChestSpawn") then
			table.insert(allChestNodes, node)
		end
	end

	-- Shuffle nodes
	for i = #allChestNodes, 2, -1 do
		local j = math.random(i)
		allChestNodes[i], allChestNodes[j] = allChestNodes[j], allChestNodes[i]
	end

	local playerCount = #game.Players:GetPlayers()
	local targetChestCount = (playerCount > 1) and 18 or 12

	-- Spawn chests on current map nodes
	for i = 1, math.min(targetChestCount, #allChestNodes) do
		local node = allChestNodes[i]
		local surfaceCF = getSurfaceCFrame(node.CFrame) -- SNAPS TO SURFACE!

		local newChest = chestTemplate:Clone()
		newChest:PivotTo(surfaceCF)
		newChest.Parent = Workspace

		local prompt = newChest:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				local stats = player:FindFirstChild("leaderstats")
				local goldVal = stats and stats:FindFirstChild("Gold")

				if goldVal and goldVal.Value >= 25 then
					goldVal.Value = goldVal.Value - 25
					prompt.Enabled = false

					if newChest:IsA("BasePart") then newChest.BrickColor = BrickColor.new("Bright green") end

					local sound = Instance.new("Sound")
					sound.SoundId = "rbxassetid://12222170"
					sound.Volume = 0.8; sound.Parent = newChest; sound:Play()

					local itemData, rarity = rollRandomItem()

					local buffs = player:FindFirstChild("Buffs") or Instance.new("Folder")
					buffs.Name = "Buffs"; buffs.Parent = player

					local itemVal = buffs:FindFirstChild(itemData.Name) or Instance.new("IntValue")
					itemVal.Name = itemData.Name; itemVal.Value = itemVal.Value + 1; itemVal.Parent = buffs

					if player.Character and player.Character:FindFirstChild("Humanoid") then
						local hum = player.Character.Humanoid
						hum.UseJumpPower = false
						if itemData.Name == "FirstStompens" then hum.WalkSpeed = 16 * (1 + 0.10 * itemVal.Value)
						elseif itemData.Name == "BunnyHoppers" then hum.JumpHeight = 7.2 * (1 + 0.12 * itemVal.Value)
						elseif itemData.Name == "PaulsJumpBoots" then hum.JumpHeight = 7.2 * (1 + 0.30 * itemVal.Value) end
					end

					itemRemote:FireClient(player, itemData.Title, itemData.Desc, rarity)
					task.wait(2)
					newChest:Destroy()
				end
			end)
		end
	end
	print("SUCCESS: Spawned " .. targetChestCount .. " chests snapped to floor surface!")
end

-- RE-RUN CHEST SPAWNER ON GAME START AND EVERY STAGE SWITCH
if gameStartedVal then
	gameStartedVal.Changed:Connect(function(started)
		if started then task.delay(1, spawnChestsForCurrentMap) end
	end)
end

if currentStageVal then
	currentStageVal.Changed:Connect(function(stageNum)
		task.delay(1, spawnChestsForCurrentMap)
	end)
end