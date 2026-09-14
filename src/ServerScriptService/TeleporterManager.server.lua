local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

print("--- TeleporterManager Starting (Multi-Stage Enabled) ---")

local chargeVal = ReplicatedStorage:FindFirstChild("TeleporterCharge") or Instance.new("IntValue")
chargeVal.Name = "TeleporterCharge"; chargeVal.Value = 0; chargeVal.Parent = ReplicatedStorage

local activeVal = ReplicatedStorage:FindFirstChild("TeleporterActive") or Instance.new("BoolValue")
activeVal.Name = "TeleporterActive"; activeVal.Value = false; activeVal.Parent = ReplicatedStorage

local completeVal = ReplicatedStorage:FindFirstChild("TeleporterComplete") or Instance.new("BoolValue")
completeVal.Name = "TeleporterComplete"; completeVal.Value = false; completeVal.Parent = ReplicatedStorage

local currentStageVal = ReplicatedStorage:FindFirstChild("CurrentStage") or Instance.new("IntValue")
currentStageVal.Name = "CurrentStage"; currentStageVal.Value = 1; currentStageVal.Parent = ReplicatedStorage

local gameStartedVal = ReplicatedStorage:WaitForChild("GameStarted", 10)
local currentTeleporter = nil

local function resetAndReturnToLobby()
	chargeVal.Value = 0; activeVal.Value = false; completeVal.Value = false; currentStageVal.Value = 1
	local pods = Workspace:FindFirstChild("ByteforceDropPods")
	if pods then pods:Destroy() end
	for _, p in ipairs(Players:GetPlayers()) do
		p:SetAttribute("IsReady", false)
		if p.Character then
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health = hum.MaxHealth end
			if p.Character:FindFirstChild("HumanoidRootPart") then p.Character:PivotTo(CFrame.new(0, 2006, 0)) end
		end
	end
	if currentTeleporter then currentTeleporter:Destroy() end
	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj:FindFirstChild("EnemyAI") then obj:Destroy() end
	end
	if gameStartedVal then gameStartedVal.Value = false end
end

-- HELPER: FINDS MAP EVEN IF FOLDER HAS CUSTOM NAMES LIKE "Maps (SHOULD NOT BE TOUCHED...)"
local function getNextMapTemplate(nextStageNum)
	local mapsFolder = nil
	for _, child in ipairs(ReplicatedStorage:GetChildren()) do
		if string.find(string.lower(child.Name), "map") and child:IsA("Folder") then
			mapsFolder = child
			break
		end
	end

	if mapsFolder then
		-- 1. Try exact match (e.g. Stage2Map or Stage3Map)
		local exactMatch = mapsFolder:FindFirstChild("Stage" .. nextStageNum .. "Map")
		if exactMatch then return exactMatch end

		-- 2. Fallback: If testing with 1 map (like Stage3Map directly)
		for _, map in ipairs(mapsFolder:GetChildren()) do
			if map:IsA("Folder") or map:IsA("Model") then
				return map
			end
		end
	end

	return ReplicatedStorage:FindFirstChild("Stage" .. nextStageNum .. "Map")
end

-- LOADS NEW MAP, ANCHORS ALL PARTS, AND FINDS SAFE FLOOR SURFACE
local function loadAndPrepareMap(mapTemplate)
	local pods = Workspace:FindFirstChild("ByteforceDropPods")
	if pods then pods:Destroy() end
	if Workspace:FindFirstChild("Map") then Workspace.Map:Destroy() end

	local newMap = mapTemplate:Clone()
	newMap.Name = "Map"
	newMap.Parent = Workspace

	-- 1. Force Anchor & Solid Collision on imported parts
	for _, desc in ipairs(newMap:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = true
		end
	end

	-- 2. Find SpawnLocation or Map Center
	local spawnPart = newMap:FindFirstChild("SpawnNodes") and newMap.SpawnNodes:FindFirstChild("SpawnLocation")
	if not spawnPart then spawnPart = newMap:FindFirstChild("SpawnLocation") or newMap:FindFirstChildOfClass("SpawnLocation") end

	local basePos = Vector3.new(0, 10, 0)
	if spawnPart then basePos = spawnPart.Position
	elseif newMap:IsA("Model") then
		local cf, _ = newMap:GetBoundingBox()
		basePos = cf.Position
	end

	-- 3. Raycast down to find top floor surface
	local rayStart = basePos + Vector3.new(0, 200, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = {newMap, Workspace:FindFirstChild("Terrain")}

	local result = Workspace:Raycast(rayStart, Vector3.new(0, -400, 0), raycastParams)
	if result then
		return result.Position + Vector3.new(0, 15, 0)
	else
		return basePos + Vector3.new(0, 20, 0)
	end
end

-- HELPER: SNAPS TELEPORTER TO SURFACE
local function getSurfaceCFrame(baseCFrame)
	local pos = baseCFrame.Position
	local rayStart = pos + Vector3.new(0, 60, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include

	local map = Workspace:FindFirstChild("Map")
	if map then raycastParams.FilterDescendantsInstances = {map, Workspace:FindFirstChild("Terrain")} end

	local result = Workspace:Raycast(rayStart, Vector3.new(0, -120, 0), raycastParams)
	if result then return CFrame.new(result.Position + Vector3.new(0, 1.5, 0)) end
	return baseCFrame + Vector3.new(0, 1.5, 0)
end

-- SPAWN TELEPORTER ON RANDOM NODE IN CURRENT ACTIVE MAP
local function spawnFreshTeleporter()
	if currentTeleporter then currentTeleporter:Destroy() end

	local map = Workspace:FindFirstChild("Map")
	local spawnNodes = map and map:FindFirstChild("SpawnNodes")

	local teleporterNodes = {}
	if spawnNodes then
		for _, node in ipairs(spawnNodes:GetChildren()) do
			if string.find(node.Name, "TeleporterSpawn") then table.insert(teleporterNodes, node) end
		end
	end

	local chosenNode = (#teleporterNodes > 0) and teleporterNodes[math.random(1, #teleporterNodes)] or nil
	local baseCFrame = chosenNode and chosenNode.CFrame or CFrame.new(0, 10, 0)
	local surfaceCFrame = getSurfaceCFrame(baseCFrame)

	local teleporter = Instance.new("Part")
	teleporter.Name = "ActiveTeleporter"
	teleporter.Size = Vector3.new(12, 3, 12)
	teleporter.CFrame = surfaceCFrame
	teleporter.BrickColor = BrickColor.new("Bright red")
	teleporter.Material = Enum.Material.Neon
	teleporter.Anchored = true; teleporter.CanCollide = true; teleporter.Parent = Workspace
	currentTeleporter = teleporter

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Teleporter"; prompt.ActionText = "Start Event (Hold E)"; prompt.HoldDuration = 0.3; prompt.RequiresLineOfSight = false; prompt.Parent = teleporter

	prompt.Triggered:Connect(function(player)
		prompt.Enabled = false
		teleporter.BrickColor = BrickColor.new("Bright yellow")
		activeVal.Value = true

		-- Spawn Boss
		local enemyTemplate = ReplicatedStorage:FindFirstChild("Enemy")
		if enemyTemplate then
			local boss = enemyTemplate:Clone()
			boss.Name = "MalwareOverlord"
			if boss:IsA("Model") then boss:ScaleTo(2.5) end
			local hum = boss:FindFirstChildOfClass("Humanoid")
			if hum then hum.MaxHealth = 800; hum.Health = 800 end
			boss:PivotTo(CFrame.new(teleporter.Position + Vector3.new(0, 12, 0)))
			boss.Parent = Workspace

			local bossRef = ReplicatedStorage:FindFirstChild("ActiveBoss") or Instance.new("ObjectValue")
			bossRef.Name = "ActiveBoss"; bossRef.Value = boss; bossRef.Parent = ReplicatedStorage

			task.spawn(function()
				while boss and boss.Parent and hum.Health > 0 do
					task.wait(6)
					local root = boss.PrimaryPart or boss:FindFirstChild("HumanoidRootPart")
					if root then
						local slamPos = root.Position
						local ring = Instance.new("Part")
						ring.Size = Vector3.new(2, 2, 2); ring.CFrame = CFrame.new(slamPos - Vector3.new(0, 3, 0)); ring.Shape = Enum.PartType.Ball; ring.Material = Enum.Material.Neon; ring.BrickColor = BrickColor.new("Bright red"); ring.Anchored = true; ring.CanCollide = false; ring.Parent = Workspace
						local sound = Instance.new("Sound"); sound.SoundId = "rbxassetid://130113322"; sound.Volume = 1; sound.Parent = ring; sound:Play()

						task.spawn(function()
							for i = 1, 20 do ring.Size = ring.Size + Vector3.new(3, 0.5, 3); ring.Transparency = i / 20; task.wait(0.02) end
							ring:Destroy()
						end)

						for _, p in ipairs(Players:GetPlayers()) do
							if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
								if (p.Character.HumanoidRootPart.Position - slamPos).Magnitude <= 30 and p.Character:FindFirstChildOfClass("Humanoid") then
									p.Character:FindFirstChildOfClass("Humanoid"):TakeDamage(25)
								end
							end
						end
					end
				end
			end)
		end

		-- Charge Loop (0% -> 100%)
		task.spawn(function()
			while chargeVal.Value < 100 do
				task.wait(1)
				local playerNearby = false
				for _, p in ipairs(Players:GetPlayers()) do
					if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
						if (p.Character.HumanoidRootPart.Position - teleporter.Position).Magnitude <= 35 then playerNearby = true; break end
					end
				end
				if playerNearby then chargeVal.Value = math.min(100, chargeVal.Value + 2) end
			end

			-- === EVENT COMPLETE: STAGE SWITCHING ===
			teleporter.BrickColor = BrickColor.new("Bright green")
			completeVal.Value = true

			local nextStageNum = currentStageVal.Value + 1
			print("STAGE " .. currentStageVal.Value .. " COMPLETE! LOADING NEXT STAGE IN 5 SECONDS...")

			task.wait(5)

			-- Check if next stage map exists
			local nextMapTemplate = getNextMapTemplate(nextStageNum)

			if nextMapTemplate and currentStageVal.Value < 2 then
				-- TRANSITION TO NEXT MAP!
				currentStageVal.Value = nextStageNum
				local safePos = loadAndPrepareMap(nextMapTemplate)

				for _, p in ipairs(Players:GetPlayers()) do
					if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
						p.Character:PivotTo(CFrame.new(safePos))
					end
				end

				chargeVal.Value = 0; activeVal.Value = false; completeVal.Value = false
				task.delay(1, function() spawnFreshTeleporter() end)
				print("SUCCESSFULLY LOADED NEXT STAGE: " .. nextMapTemplate.Name .. "!")
			else
				-- ALL STAGES FINISHED OR NO NEXT MAP: RETURN TO SKY LOBBY
				print("ALL STAGES COMPLETED! RETURNING TO SKY LOBBY.")
				resetAndReturnToLobby()
			end
		end)
	end)
end

-- SPAWN TELEPORTER WHEN GAME STARTS
if gameStartedVal then
	gameStartedVal.Changed:Connect(function(started)
		if started then task.delay(0.5, function() spawnFreshTeleporter() end) end
	end)
end
