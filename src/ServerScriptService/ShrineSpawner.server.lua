local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local itemRemote = ReplicatedStorage:WaitForChild("ItemAcquiredRemote")
local gameStartedVal = ReplicatedStorage:WaitForChild("GameStarted", 10)
local currentStageVal = ReplicatedStorage:WaitForChild("CurrentStage", 10)

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

local function rollItem()
	local roll = math.random(1, 100)
	local rarity = (roll <= 5 and "Rare") or (roll <= 30 and "Uncommon") or "Common"
	local pool = LOOT_TABLE[rarity]
	return pool[math.random(1, #pool)], rarity
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

-- FUNCTION TO SPAWN SHRINES FOR ACTIVE MAP
local function spawnShrinesForCurrentMap()
	-- 1. Destroy old shrines in Workspace
	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj.Name == "ShrineOfChance" then obj:Destroy() end
	end

	-- 2. Find current map's SpawnNodes folder
	local spawnNodesFolder = getActiveMapSpawnNodes()
	if not spawnNodesFolder then return end

	local allNodes = spawnNodesFolder:GetChildren()
	local shrineCount = 0

	for _, node in ipairs(allNodes) do
		if string.find(node.Name, "ChestSpawn") and math.random(1, 3) == 1 then
			if shrineCount >= 2 then break end
			shrineCount = shrineCount + 1

			local shrine = Instance.new("Part")
			shrine.Name = "ShrineOfChance"
			shrine.Size = Vector3.new(4, 10, 4)
			shrine.CFrame = node.CFrame + Vector3.new(0, 4, 0)
			shrine.BrickColor = BrickColor.new("Deep blue")
			shrine.Material = Enum.Material.Marble
			shrine.Anchored = true; shrine.CanCollide = true
			shrine.Parent = Workspace

			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText = "Shrine of Chance"
			prompt.ActionText = "Offer ($20 Gold)"
			prompt.HoldDuration = 0.5
			prompt.RequiresLineOfSight = false
			prompt.Parent = shrine

			local shrineCost = 20
			local itemsWon = 0

			prompt.Triggered:Connect(function(player)
				local stats = player:FindFirstChild("leaderstats")
				local goldVal = stats and stats:FindFirstChild("Gold")

				if goldVal and goldVal.Value >= shrineCost then
					goldVal.Value = goldVal.Value - shrineCost
					shrineCost = math.floor(shrineCost * 1.5)

					if math.random(1, 2) == 1 then
						itemsWon = itemsWon + 1
						local itemData, rarity = rollItem()

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

						if itemsWon >= 2 then
							prompt.Enabled = false
							shrine.BrickColor = BrickColor.new("Dark stone grey")
						else
							prompt.ActionText = "Offer ($" .. shrineCost .. " Gold)"
						end
					else
						itemRemote:FireClient(player, "SHRINE OF CHANCE", "You offer to the shrine, but gain nothing.", "Common")
						prompt.ActionText = "Offer ($" .. shrineCost .. " Gold)"
					end
				end
			end)
		end
	end
	print("SUCCESS: Spawned Shrines of Chance for current stage!")
end

if gameStartedVal then
	gameStartedVal.Changed:Connect(function(started)
		if started then task.delay(1, spawnShrinesForCurrentMap) end
	end)
end

if currentStageVal then
	currentStageVal.Changed:Connect(function(stageNum)
		task.delay(1, spawnShrinesForCurrentMap)
	end)
end