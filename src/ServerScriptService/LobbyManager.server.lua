local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterPack = game:GetService("StarterPack")

print("--- LobbyManager Starting (Instant Load & Guaranteed Spawn) ---")

local function getOrCreate(className, name, parent)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

-- 1. INSTANTLY CREATE ALL REMOTES (PREVENTS CLIENT UI FROM STALLING)
local selectClassRemote = getOrCreate("RemoteEvent", "SelectClassRemote", ReplicatedStorage)
local toggleReadyRemote = getOrCreate("RemoteEvent", "ToggleReadyRemote", ReplicatedStorage)
local startGameRemote = getOrCreate("RemoteEvent", "StartGameRemote", ReplicatedStorage)
local returnLobbyRemote = getOrCreate("RemoteEvent", "ReturnLobbyRemote", ReplicatedStorage)
local showcaseRemote = getOrCreate("RemoteEvent", "PlayShowcaseRemote", ReplicatedStorage)
local confirmDeployRemote = getOrCreate("RemoteEvent", "ConfirmDeployRemote", ReplicatedStorage)
local playAgainRemote = getOrCreate("RemoteEvent", "PlayAgainRemote", ReplicatedStorage)
local completeTutorialRemote = getOrCreate("RemoteEvent", "CompleteTutorialRemote", ReplicatedStorage)

local gameStartedVal = getOrCreate("BoolValue", "GameStarted", ReplicatedStorage)
gameStartedVal.Value = false
local lobbyPhaseVal = getOrCreate("StringValue", "LobbyPhase", ReplicatedStorage)
lobbyPhaseVal.Value = "LOBBY"

local chargeVal = getOrCreate("IntValue", "TeleporterCharge", ReplicatedStorage)
chargeVal.Value = 0
local activeVal = getOrCreate("BoolValue", "TeleporterActive", ReplicatedStorage)
activeVal.Value = false
local completeVal = getOrCreate("BoolValue", "TeleporterComplete", ReplicatedStorage)
completeVal.Value = false

-- 2. BUILD PHYSICAL SKY LOBBY
local lobbyPlatform = Workspace:FindFirstChild("SkyLobbyPlatform")
if not lobbyPlatform then
	lobbyPlatform = Instance.new("Part")
	lobbyPlatform.Name = "SkyLobbyPlatform"
	lobbyPlatform.Size = Vector3.new(60, 2, 60)
	lobbyPlatform.Position = Vector3.new(0, 2000, 0)
	lobbyPlatform.BrickColor = BrickColor.new("Dark stone grey")
	lobbyPlatform.Material = Enum.Material.SmoothPlastic
	lobbyPlatform.Anchored = true
	lobbyPlatform.Parent = Workspace

	local lobbySpawn = Instance.new("SpawnLocation")
	lobbySpawn.Name = "LobbySpawn"
	lobbySpawn.Size = Vector3.new(12, 1, 12)
	lobbySpawn.Position = Vector3.new(0, 2001.5, 0)
	lobbySpawn.Anchored = true
	lobbySpawn.Enabled = true
	lobbySpawn.Neutral = true
	lobbySpawn.Parent = Workspace

	local podium = Instance.new("Part")
	podium.Name = "ShowcasePodium"
	podium.Size = Vector3.new(45, 2, 45)
	podium.Position = Vector3.new(0, 2001, 50)
	podium.BrickColor = BrickColor.new("Cyan")
	podium.Material = Enum.Material.Neon
	podium.Anchored = true
	podium.Parent = Workspace

	local wallHeight = 25
	local wallThickness = 2
	local wallOffsets = {Vector3.new(0, wallHeight/2, 30), Vector3.new(0, wallHeight/2, -30), Vector3.new(30, wallHeight/2, 0), Vector3.new(-30, wallHeight/2, 0)}
	local wallSizes = {Vector3.new(60, wallHeight, wallThickness), Vector3.new(60, wallHeight, wallThickness), Vector3.new(wallThickness, wallHeight, 60), Vector3.new(wallThickness, wallHeight, 60)}
	for i = 1, 4 do
		local wall = Instance.new("Part")
		wall.Name = "LobbyBarrierWall"
		wall.Size = wallSizes[i]
		wall.Position = Vector3.new(0, 2000, 0) + wallOffsets[i]
		wall.Transparency = 1
		wall.CanCollide = true
		wall.Anchored = true
		wall.Parent = Workspace
	end

	local pOffsets = {Vector3.new(0, wallHeight/2, 22.5), Vector3.new(0, wallHeight/2, -22.5), Vector3.new(22.5, wallHeight/2, 0), Vector3.new(-22.5, wallHeight/2, 0)}
	local pSizes = {Vector3.new(45, wallHeight, wallThickness), Vector3.new(45, wallHeight, wallThickness), Vector3.new(wallThickness, wallHeight, 45), Vector3.new(wallThickness, wallHeight, 45)}
	for i = 1, 4 do
		local pWall = Instance.new("Part")
		pWall.Name = "PodiumBarrierWall"
		pWall.Size = pSizes[i]
		pWall.Position = Vector3.new(0, 2001, 50) + pOffsets[i]
		pWall.Transparency = 1
		pWall.CanCollide = true
		pWall.Anchored = true
		pWall.Parent = Workspace
	end
end

-- 3. DISABLE ALL STAGE SPAWNS WHILE IN LOBBY
local function disableStageSpawns()
	for _, desc in ipairs(Workspace:GetDescendants()) do
		if desc:IsA("SpawnLocation") and desc.Name ~= "LobbySpawn" then
			desc.Enabled = false
		end
	end
end
disableStageSpawns()

local function giveClassWeaponAndHighlight(player, className, gameplayEnabled, refreshTools)
	local char = player.Character
	if not char or not char:FindFirstChildOfClass("Humanoid") then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local rootPart = char:FindFirstChild("HumanoidRootPart")

	-- Tool teardown is intentionally skipped for ordinary survivor switches.
	-- Entering the showcase already clears the player's tools once; destroying
	-- them again on every class click can fire equip/unequip presentation audio.
	if refreshTools ~= false then
		player.Backpack:ClearAllChildren()
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") then item:Destroy() end
		end
	end

	local toolName = "LaserGun"
	local highlightColor = Color3.fromRGB(0, 200, 255)
	local moveSpeed = 16
	local maxHealth = 100

	if className == "Ranger" then
		toolName = "RangerWeapon"
		maxHealth = 90
		moveSpeed = 20
		highlightColor = Color3.fromRGB(0, 255, 120)
	elseif className == "Brawler" then
		toolName = "BrawlerWeapon"
		maxHealth = 150
		moveSpeed = 18
		highlightColor = Color3.fromRGB(255, 120, 0)
	elseif className == "Weaver" then
		toolName = "WeaverWeapon"
		maxHealth = 100
		moveSpeed = 18
		highlightColor = Color3.fromRGB(180, 0, 255)
	else
		toolName = "LaserGun"
		maxHealth = 100
		moveSpeed = 16
	end

	-- Survivor select is presentation-only. Keep the real character completely
	-- stationary even if client controls briefly re-enable or a class swap races
	-- with the UI transition. Gameplay movement is restored only when the run starts.
	if gameplayEnabled == true then
		hum.MaxHealth = maxHealth
		hum.Health = maxHealth
		hum.WalkSpeed = moveSpeed
		hum.JumpHeight = 7.2
		hum.JumpPower = 50
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	else
		hum.WalkSpeed = 0
		hum.JumpHeight = 0
		hum.JumpPower = 0
		hum.Jump = false
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		if rootPart then
			rootPart.AssemblyLinearVelocity = Vector3.zero
			rootPart.AssemblyAngularVelocity = Vector3.zero
		end
	end

	local highlight = char:FindFirstChildOfClass("Highlight") or Instance.new("Highlight")
	highlight.FillColor = highlightColor
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = highlightColor
	highlight.Parent = char

	if gameplayEnabled == true then
		local toolTemplate = StarterPack:FindFirstChild(toolName) or ReplicatedStorage:FindFirstChild(toolName)
		if toolTemplate then
			local clone = toolTemplate:Clone()
			clone.Enabled = true
			clone.Parent = player.Backpack
		end

		task.delay(0.1, function()
			local tool = player.Backpack:FindFirstChildOfClass("Tool")
			if tool and hum then
				tool.Enabled = true
				hum:EquipTool(tool)
			end
		end)
	end
end

local function clearClassPresentation(player)
	player.Backpack:ClearAllChildren()
	if player.Character then
		for _, item in ipairs(player.Character:GetChildren()) do
			if item:IsA("Tool") or item:IsA("Highlight") then item:Destroy() end
		end
	end
end

local function movePlayersToShowcase()
	local lobbyPlayers = Players:GetPlayers()
	local count = #lobbyPlayers
	for index, p in ipairs(lobbyPlayers) do
		p:SetAttribute("ShowcaseConfirmed", false)
		if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local xOffset = (index - ((count + 1) / 2)) * 6
			local position = Vector3.new(xOffset, 2005, 50)
			p.Character:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, -12)))
			giveClassWeaponAndHighlight(p, p:GetAttribute("SelectedClass") or "Gunner", false)
		end
	end
end

local function allPlayersReady(excludedPlayer)
	local currentPlayers = Players:GetPlayers()
	local considered = 0
	for _, p in ipairs(currentPlayers) do
		if p ~= excludedPlayer then
			considered += 1
			if p:GetAttribute("IsReady") ~= true then return false end
		end
	end
	return considered > 0
end

local function beginSurvivorSelect(excludedPlayer)
	if lobbyPhaseVal.Value ~= "LOBBY" or gameStartedVal.Value then return end
	if not allPlayersReady(excludedPlayer) then return end
	lobbyPhaseVal.Value = "SURVIVOR_SELECT"
	movePlayersToShowcase()
	showcaseRemote:FireAllClients()
end

local function resetPlayerStats(player)
	player:SetAttribute("IsReady", false)
	player:SetAttribute("ShowcaseConfirmed", false)
	player:SetAttribute("Kills", 0)
	player:SetAttribute("TotalGoldEarned", 0)

	if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Gold") then
		player.leaderstats.Gold.Value = 0
	end
	local buffs = player:FindFirstChild("Buffs")
	if buffs then buffs:ClearAllChildren() end
		if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
			local hum = player.Character:FindFirstChildOfClass("Humanoid")
			hum.WalkSpeed = 16
			hum.JumpHeight = 7.2
			hum.JumpPower = 50
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			hum.Health = hum.MaxHealth
		end
end

-- GUARANTEED TELEPORT: WAITS FOR HUMANOIDROOTPART INSTEAD OF GUESSING TIME
local function onCharacterAdded(player, character)
	if not gameStartedVal.Value then
		task.spawn(function()
			local root = character:WaitForChild("HumanoidRootPart", 10)
			if root and not gameStartedVal.Value then
				if lobbyPhaseVal.Value == "SURVIVOR_SELECT" then
					local playersNow = Players:GetPlayers()
					local index = table.find(playersNow, player) or #playersNow
					local count = math.max(#playersNow, 1)
					local xOffset = (index - ((count + 1) / 2)) * 6
					local position = Vector3.new(xOffset, 2005, 50)
					character:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, -12)))
					giveClassWeaponAndHighlight(player, player:GetAttribute("SelectedClass") or "Gunner", false)
				else
					root.CFrame = CFrame.new(0, 2006, 0)
					clearClassPresentation(player)
				end
			end
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("SelectedClass", "Gunner")
	player:SetAttribute("IsReady", false)
	player:SetAttribute("ShowcaseConfirmed", false)
	player:SetAttribute("Kills", 0)
	player:SetAttribute("TotalGoldEarned", 0)
	if player.Character then onCharacterAdded(player, player.Character) end
	player.CharacterAdded:Connect(function(char) onCharacterAdded(player, char) end)
end)

for _, p in ipairs(Players:GetPlayers()) do
	p:SetAttribute("SelectedClass", "Gunner")
	p:SetAttribute("IsReady", false)
	p:SetAttribute("ShowcaseConfirmed", false)
	p:SetAttribute("Kills", 0)
	p:SetAttribute("TotalGoldEarned", 0)
	if p.Character then onCharacterAdded(p, p.Character) end
	p.CharacterAdded:Connect(function(char) onCharacterAdded(p, char) end)
end

selectClassRemote.OnServerEvent:Connect(function(player, className)
	if lobbyPhaseVal.Value == "SURVIVOR_SELECT" and not gameStartedVal.Value and player:GetAttribute("ShowcaseConfirmed") ~= true then
		if className ~= "Gunner" and className ~= "Ranger" and className ~= "Brawler" and className ~= "Weaver" then return end
		player:SetAttribute("SelectedClass", className)
		player:SetAttribute("ShowcaseConfirmed", false)
		-- The showcase has no active weapon. Only update stats/highlight here;
		-- do not repeatedly destroy tools, which was producing the switch sound.
		giveClassWeaponAndHighlight(player, className, false, false)
	end
end)

toggleReadyRemote.OnServerEvent:Connect(function(player)
	if lobbyPhaseVal.Value == "LOBBY" and not gameStartedVal.Value then
		player:SetAttribute("IsReady", not (player:GetAttribute("IsReady") or false))
		beginSurvivorSelect()
	end
end)

local function returnAllToLobby()
	gameStartedVal.Value = false
	lobbyPhaseVal.Value = "LOBBY"
	chargeVal.Value = 0
	activeVal.Value = false
	completeVal.Value = false
	disableStageSpawns()

	for _, p in ipairs(Players:GetPlayers()) do
		resetPlayerStats(p)
		if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			p.Character:PivotTo(CFrame.new(0, 2006, 0))
		end
		clearClassPresentation(p)
	end

	if Workspace:FindFirstChild("ActiveTeleporter") then Workspace.ActiveTeleporter:Destroy() end
	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj:FindFirstChild("EnemyAI") then obj:Destroy() end
	end
end

returnLobbyRemote.OnServerEvent:Connect(returnAllToLobby)

playAgainRemote.OnServerEvent:Connect(function(player)
	returnAllToLobby()
end)

local function findStage1Spawn()
	local spawn = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("SpawnNodes") and Workspace.Map.SpawnNodes:FindFirstChild("SpawnLocation")
	if not spawn then spawn = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("SpawnLocation") end
	if not spawn then spawn = Workspace:FindFirstChild("SpawnLocation") or Workspace:FindFirstChildOfClass("SpawnLocation") end
	return spawn
end

local function tryStartRun(excludedPlayer)
	if lobbyPhaseVal.Value ~= "SURVIVOR_SELECT" or gameStartedVal.Value then return end
	local currentPlayers = Players:GetPlayers()
	local considered = 0
	for _, p in ipairs(currentPlayers) do
		if p ~= excludedPlayer then
			considered += 1
			if p:GetAttribute("ShowcaseConfirmed") ~= true then return end
		end
	end
	if considered == 0 then return end

	lobbyPhaseVal.Value = "RUN"
	gameStartedVal.Value = true
	local stage1Spawn = findStage1Spawn()
	if stage1Spawn and stage1Spawn:IsA("SpawnLocation") then
		stage1Spawn.Enabled = true
	end

	local targetCFrame = stage1Spawn and (stage1Spawn.CFrame + Vector3.new(0, 1, 0)) or CFrame.new(0, 15, 0)

	local podFloor = Instance.new("Part")
	podFloor.Name = "DropPodFloor"
	podFloor.Size = Vector3.new(8, 1, 8)
	podFloor.CFrame = targetCFrame
	podFloor.BrickColor = BrickColor.new("Dark stone grey")
	podFloor.Material = Enum.Material.Metal
	podFloor.Anchored = true
	podFloor.CanCollide = true
	podFloor.Parent = Workspace

	local podShell = Instance.new("Part")
	podShell.Name = "DropPodShell"
	podShell.Size = Vector3.new(8, 9, 8)
	podShell.CFrame = targetCFrame + Vector3.new(0, 4.5, 0)
	podShell.BrickColor = BrickColor.new("Really black")
	podShell.Material = Enum.Material.Glass
	podShell.Transparency = 0.4
	podShell.Anchored = true
	podShell.CanCollide = false
	podShell.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Drop Pod"
	prompt.ActionText = "Open Pod Hatch (Hold E)"
	prompt.HoldDuration = 0.6
	prompt.RequiresLineOfSight = false
	prompt.Parent = podFloor

	for _, p in ipairs(currentPlayers) do
		local selectedCls = p:GetAttribute("SelectedClass") or "Gunner"
		giveClassWeaponAndHighlight(p, selectedCls, true)
		if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			p.Character:PivotTo(targetCFrame + Vector3.new(0, 3, 0))
		end
	end

	prompt.Triggered:Connect(function(triggerPlayer)
		prompt.Enabled = false
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://130113322"
		sound.Volume = 0.8
		sound.Parent = podFloor
		sound:Play()
		task.spawn(function()
			for i = 1, 10 do
				podShell.Transparency = 0.4 + (i / 10 * 0.6)
				podFloor.Transparency = i / 10
				task.wait(0.04)
			end
			podShell:Destroy()
			podFloor:Destroy()
		end)
	end)
end

confirmDeployRemote.OnServerEvent:Connect(function(player)
	if lobbyPhaseVal.Value ~= "SURVIVOR_SELECT" or gameStartedVal.Value then return end
	player:SetAttribute("ShowcaseConfirmed", true)
	tryStartRun()
end)

startGameRemote.OnServerEvent:Connect(function(player)
	-- Legacy remote retained so old clients do not error. Progression is automatic
	-- once every connected player is ready in the LOBBY phase.
	beginSurvivorSelect()
end)

Players.PlayerRemoving:Connect(function(leavingPlayer)
	task.defer(function()
		if lobbyPhaseVal.Value == "LOBBY" then
			beginSurvivorSelect(leavingPlayer)
		elseif lobbyPhaseVal.Value == "SURVIVOR_SELECT" and not gameStartedVal.Value then
			tryStartRun(leavingPlayer)
		end
	end)
end)

print("SUCCESS: LobbyManager running with instantaneous client UI sync!")
