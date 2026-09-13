local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local screenGui = script.Parent

screenGui.ResetOnSpawn = false
screenGui.Enabled = false

local function getOrCreate(className, name, parent, properties)
	local item = parent:FindFirstChild(name)
	if not item then item = Instance.new(className); item.Name = name; item.Parent = parent end
	if properties then for k, v in pairs(properties) do item[k] = v end end
	return item
end

-- 1. CROSSHAIR
getOrCreate("Frame", "Crosshair", screenGui, {
	Size = UDim2.new(0, 6, 0, 6), Position = UDim2.new(0.5, -3, 0.5, -22),
	BackgroundColor3 = Color3.fromRGB(0, 255, 120), BorderSizePixel = 1, BorderColor3 = Color3.fromRGB(0, 0, 0),
	Visible = true
})

-- 2. TIMER & GOLD HEADER
local timerLabel = getOrCreate("TextLabel", "TimerLabel", screenGui, {
	Size = UDim2.new(0, 600, 0, 30), Position = UDim2.new(0.5, -300, 0, 5),
	BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 255, 255), TextScaled = true, Font = Enum.Font.SourceSansBold, Text = "TIME: 00:00 | THREAT: EASY | GOLD: $0",
	Visible = true
})

-- 3. CUSTOM HEALTH BAR
local healthBG = getOrCreate("Frame", "HealthBarBG", screenGui, {
	Size = UDim2.new(0, 250, 0, 30), Position = UDim2.new(0, 20, 1, -50), BackgroundColor3 = Color3.fromRGB(40, 40, 40), BorderSizePixel = 2,
	Visible = true
})
local healthFill = getOrCreate("Frame", "HealthBarFill", healthBG, {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(0, 220, 100), BorderSizePixel = 0})
local hpLabel = getOrCreate("TextLabel", "HPLabel", healthBG, {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 255, 255), TextScaled = true, Font = Enum.Font.SourceSansBold, Text = "100 / 100 HP", ZIndex = 2})

-- 4. ABILITY BAR (Bottom Right)
local abilityBar = getOrCreate("Frame", "AbilityBar", screenGui, {
	Size = UDim2.new(0, 320, 0, 65), Position = UDim2.new(1, -340, 1, -80), BackgroundTransparency = 1,
	Visible = true
})

local CLASS_SKILLS = {
	Gunner  = {M1 = "LASER",  M2 = "HEAVY",  Shift = "DASH",  R = "STRIKE"},
	Ranger  = {M1 = "ARROW",  M2 = "PIERCE", Shift = "BLINK", R = "RAIN"},
	Brawler = {M1 = "FISTS",  M2 = "PALM",   Shift = "FLASH", R = "SLAM"},
	Weaver  = {M1 = "WEB",    M2 = "SNARE",  Shift = "ZIP",   R = "SLAM"}
}

local skills = {{Key="M1"}, {Key="M2"}, {Key="SHIFT"}, {Key="R"}}
for i, skill in ipairs(skills) do
	local box = getOrCreate("Frame", "Skill_" .. skill.Key, abilityBar, {Size = UDim2.new(0, 70, 0, 60), Position = UDim2.new(0, (i - 1) * 80, 0, 0), BackgroundColor3 = Color3.fromRGB(30, 30, 30), BorderSizePixel = 2, BorderColor3 = Color3.fromRGB(255, 255, 255)})
	getOrCreate("TextLabel", "KeyLabel", box, {Size=UDim2.new(1,0,0.4,0), BackgroundTransparency=1, TextColor3=Color3.fromRGB(255,255,100), TextScaled=true, Font=Enum.Font.SourceSansBold, Text=skill.Key})
	getOrCreate("TextLabel", "NameLabel", box, {Size=UDim2.new(1,0,0.5,0), Position=UDim2.new(0,0,0.4,0), BackgroundTransparency=1, TextColor3=Color3.fromRGB(255,255,255), TextScaled=true, Font=Enum.Font.SourceSans, Text=""})
	getOrCreate("TextLabel", "CooldownLabel", box, {Size=UDim2.new(1,0,1,0), BackgroundColor3=Color3.fromRGB(0,0,0), BackgroundTransparency=0.5, TextColor3=Color3.fromRGB(255,80,80), TextScaled=true, Font=Enum.Font.SourceSansBold, Text="", Visible=false, ZIndex=3})
end

-- 5. BUFFS / ITEMS LIST (Middle Left)
local buffsPanel = getOrCreate("Frame", "BuffsPanel", screenGui, {
	Size = UDim2.new(0, 230, 0, 160), Position = UDim2.new(0, 20, 0.45, 0), BackgroundColor3 = Color3.fromRGB(15, 15, 15), BackgroundTransparency = 0.4, BorderSizePixel = 2, BorderColor3 = Color3.fromRGB(0, 180, 255),
	Visible = true
})
getOrCreate("TextLabel", "BuffsTitle", buffsPanel, {Size = UDim2.new(1, 0, 0, 25), BackgroundColor3 = Color3.fromRGB(0, 100, 180), TextColor3 = Color3.fromRGB(255, 255, 255), TextScaled = true, Font = Enum.Font.SourceSansBold, Text = "ACQUIRED ITEMS"})
local buffsListLabel = getOrCreate("TextLabel", "BuffsList", buffsPanel, {Size = UDim2.new(1, -10, 1, -30), Position = UDim2.new(0, 5, 0, 28), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(200, 240, 255), TextSize = 13, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Text = "No items collected."})

-- 6. TELEPORTER PANEL & BOSS BAR
local teleporterPanel = getOrCreate("Frame", "TeleporterPanel", screenGui, {
	Size = UDim2.new(0, 450, 0, 35), Position = UDim2.new(0.5, -225, 0, 68), BackgroundColor3 = Color3.fromRGB(20, 20, 20), BackgroundTransparency = 0.3, BorderSizePixel = 2, BorderColor3 = Color3.fromRGB(255, 220, 50), Visible = false
})
local teleporterLabel = getOrCreate("TextLabel", "TeleporterLabel", teleporterPanel, {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 230, 80), TextScaled = true, Font = Enum.Font.SourceSansBold, Text = ""})

local bossBarBG = getOrCreate("Frame", "BossBarBG", screenGui, {
	Size = UDim2.new(0, 450, 0, 25), Position = UDim2.new(0.5, -225, 0, 38), BackgroundColor3 = Color3.fromRGB(40, 0, 0), BorderSizePixel = 2, BorderColor3 = Color3.fromRGB(255, 0, 0), Visible = false
})
local bossBarFill = getOrCreate("Frame", "BossBarFill", bossBarBG, {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(220, 0, 0), BorderSizePixel = 0})
local bossLabel = getOrCreate("TextLabel", "BossLabel", bossBarBG, {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 255, 255), TextScaled = true, Font = Enum.Font.SourceSansBold, Text = "MALWARE OVERLORD - 800 / 800 HP", ZIndex = 2})

-- 7. END-OF-RUN STATS SCREEN
local statsFrame = getOrCreate("Frame", "StatsFrame", screenGui, {
	Size = UDim2.new(0, 680, 0, 400), Position = UDim2.new(0.5, -340, 0.5, -200), BackgroundColor3 = Color3.fromRGB(15, 18, 24), BorderSizePixel = 3, BorderColor3 = Color3.fromRGB(255, 50, 50), Visible = false, ZIndex = 10
})
getOrCreate("TextLabel", "StatsTitle", statsFrame, {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(180, 40, 40), TextColor3 = Color3.fromRGB(255, 255, 255), TextScaled = true, Font = Enum.Font.SourceSansBold, Text = "RUN OVER - TEAM DEFEATED", ZIndex = 11})
local statsContainer = getOrCreate("Frame", "StatsContainer", statsFrame, {Size = UDim2.new(1, -30, 0, 280), Position = UDim2.new(0, 15, 0, 50), BackgroundTransparency = 1, ZIndex = 11})
local returnBtn = getOrCreate("TextButton", "ReturnBtn", statsFrame, {Size = UDim2.new(0, 240, 0, 45), Position = UDim2.new(0.5, -120, 1, -55), BackgroundColor3 = Color3.fromRGB(0, 180, 80), TextColor3 = Color3.fromRGB(255, 255, 255), TextScaled = true, Font = Enum.Font.SourceSansBold, Text = "RETURN TO LOBBY ▶", ZIndex = 12})

-- 8. ITEM PICKUP BANNER
local pickupBanner = getOrCreate("Frame", "PickupBanner", screenGui, {
	Size = UDim2.new(0, 280, 0, 60), Position = UDim2.new(0, -300, 0.3, 0), BackgroundColor3 = Color3.fromRGB(15, 15, 20), BackgroundTransparency = 0.2, BorderSizePixel = 3, BorderColor3 = Color3.fromRGB(255, 255, 255), Visible = false
})
local bannerHeader = getOrCreate("TextLabel", "BannerHeader", pickupBanner, {Size = UDim2.new(1, -10, 0, 25), Position = UDim2.new(0, 5, 0, 2), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 255, 255), TextScaled = true, Font = Enum.Font.SourceSansBold, Text = ""})
local bannerDesc = getOrCreate("TextLabel", "BannerDesc", pickupBanner, {Size = UDim2.new(1, -10, 0, 25), Position = UDim2.new(0, 5, 0, 28), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(200, 200, 200), TextScaled = true, Font = Enum.Font.SourceSans, Text = ""})

-- REMOTES & VALUES
local itemRemote = ReplicatedStorage:FindFirstChild("ItemAcquiredRemote") or ReplicatedStorage:WaitForChild("ItemAcquiredRemote", 5)
local returnLobbyRemote = ReplicatedStorage:FindFirstChild("ReturnLobbyRemote") or ReplicatedStorage:WaitForChild("ReturnLobbyRemote", 5)
local elapsedTimeVal = ReplicatedStorage:FindFirstChild("ElapsedTime") or ReplicatedStorage:WaitForChild("ElapsedTime", 5)
local threatTextVal = ReplicatedStorage:FindFirstChild("ThreatText") or ReplicatedStorage:WaitForChild("ThreatText", 5)
local chargeVal = ReplicatedStorage:FindFirstChild("TeleporterCharge") or ReplicatedStorage:WaitForChild("TeleporterCharge", 5)
local activeVal = ReplicatedStorage:FindFirstChild("TeleporterActive") or ReplicatedStorage:WaitForChild("TeleporterActive", 5)
local gameStartedVal = ReplicatedStorage:FindFirstChild("GameStarted") or ReplicatedStorage:WaitForChild("GameStarted", 5)

if itemRemote then
	itemRemote.OnClientEvent:Connect(function(title, desc, rarity)
		local colorMap = {Common=Color3.fromRGB(220,220,220), Uncommon=Color3.fromRGB(80,255,100), Rare=Color3.fromRGB(255,80,80)}
		local borderColor = colorMap[rarity] or Color3.fromRGB(255,255,255)
		pickupBanner.BorderColor3 = borderColor; bannerHeader.TextColor3 = borderColor; bannerHeader.Text = title:upper(); bannerDesc.Text = desc
		pickupBanner.Visible = true; pickupBanner:TweenPosition(UDim2.new(0, 20, 0.3, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
		task.delay(3.5, function()
			pickupBanner:TweenPosition(UDim2.new(0, -300, 0.3, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.3, true, function() pickupBanner.Visible = false end)
		end)
	end)
end

local function updateAbilityBarNames()
	local rawCls = player:GetAttribute("SelectedClass") or "Gunner"
	local cls = string.upper(string.sub(rawCls, 1, 1)) .. string.lower(string.sub(rawCls, 2))
	local names = CLASS_SKILLS[cls] or CLASS_SKILLS[rawCls] or CLASS_SKILLS.Gunner

	local boxM1 = abilityBar:FindFirstChild("Skill_M1")
	if boxM1 and boxM1:FindFirstChild("NameLabel") then boxM1.NameLabel.Text = tostring(names and names.M1 or "LASER") end
	local boxM2 = abilityBar:FindFirstChild("Skill_M2")
	if boxM2 and boxM2:FindFirstChild("NameLabel") then boxM2.NameLabel.Text = tostring(names and names.M2 or "HEAVY") end
	local boxShift = abilityBar:FindFirstChild("Skill_SHIFT")
	if boxShift and boxShift:FindFirstChild("NameLabel") then boxShift.NameLabel.Text = tostring(names and (names.Shift or names.SHIFT) or "DASH") end
	local boxR = abilityBar:FindFirstChild("Skill_R")
	if boxR and boxR:FindFirstChild("NameLabel") then boxR.NameLabel.Text = tostring(names and names.R or "STRIKE") end
end

local function renderEndStats()
	for _, child in ipairs(statsContainer:GetChildren()) do child:Destroy() end
	local sec = elapsedTimeVal and elapsedTimeVal.Value or 0
	local timeString = string.format("%02d:%02d", math.floor(sec / 60), sec % 60)

	for i, p in ipairs(Players:GetPlayers()) do
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 60); card.Position = UDim2.new(0, 0, 0, (i - 1) * 65)
		card.BackgroundColor3 = Color3.fromRGB(28, 32, 42); card.BorderSizePixel = 1; card.BorderColor3 = Color3.fromRGB(60, 65, 80); card.ZIndex = 11; card.Parent = statsContainer

		local avatar = Instance.new("ImageLabel")
		avatar.Size = UDim2.new(0, 50, 0, 50); avatar.Position = UDim2.new(0, 5, 0.5, -25)
		avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. p.UserId .. "&w=150&h=150"; avatar.BackgroundTransparency = 1; avatar.ZIndex = 12; avatar.Parent = card

		local cls = p:GetAttribute("SelectedClass") or "Gunner"
		local kills = p:GetAttribute("Kills") or 0
		local totalGold = p:GetAttribute("TotalGoldEarned") or 0
		local itemTotal = 0
		local buffsFolder = p:FindFirstChild("Buffs")
		if buffsFolder then for _, item in ipairs(buffsFolder:GetChildren()) do itemTotal = itemTotal + item.Value end end

		local info = Instance.new("TextLabel")
		info.Size = UDim2.new(1, -65, 1, 0); info.Position = UDim2.new(0, 60, 0, 0); info.BackgroundTransparency = 1
		info.TextColor3 = Color3.fromRGB(255, 255, 255); info.TextSize = 14; info.Font = Enum.Font.SourceSansBold
		info.TextXAlignment = Enum.TextXAlignment.Left; info.ZIndex = 12
		info.Text = p.Name .. " (" .. cls .. ")\n• Time: " .. timeString .. "  |  • Kills: " .. kills .. "  |  • Gold: $" .. totalGold .. "  |  • Items: " .. itemTotal
		info.Parent = card
	end
end

returnBtn.MouseButton1Click:Connect(function()
	statsFrame.Visible = false
	if returnLobbyRemote then returnLobbyRemote:FireServer() end
end)

local function formatTime(sec) return string.format("%02d:%02d", math.floor(sec / 60), sec % 60) end

local function updateHUDDisplay()
	local sec = elapsedTimeVal and elapsedTimeVal.Value or 0
	local threat = threatTextVal and threatTextVal.Value or "EASY"
	local gold = (player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Gold")) and player.leaderstats.Gold.Value or 0
	timerLabel.Text = "TIME: " .. formatTime(sec) .. " | THREAT: " .. threat .. " | GOLD: $" .. gold
	updateAbilityBarNames()
end

local function updateTeleporterDisplay()
	if activeVal and activeVal.Value then
		teleporterPanel.Visible = true
		local pct = chargeVal and chargeVal.Value or 0
		if pct >= 100 then
			teleporterLabel.Text = "✅ TELEPORTER CHARGED! (CLEAR ENEMIES)"
			teleporterLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		else
			local inRange = false
			local activeTeleporter = workspace:FindFirstChild("ActiveTeleporter")
			if activeTeleporter and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				if (player.Character.HumanoidRootPart.Position - activeTeleporter.Position).Magnitude <= 35 then inRange = true end
			end
			if inRange then
				teleporterLabel.Text = "⚡ IN ZONE - CHARGING: " .. pct .. "%"
				teleporterLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
			else
				teleporterLabel.Text = "⚠️ OUTSIDE ZONE - PAUSED (" .. pct .. "%)"
				teleporterLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			end
		end
	else
		teleporterPanel.Visible = false
	end
end

local function updateBuffsDisplay()
	local buffsFolder = player:FindFirstChild("Buffs")
	if buffsFolder then
		local text = ""
		local itemNames = {
			{Val="FirstStompens", Title="First Stompens (+10% Speed)"},
			{Val="Dagger", Title="Dagger (+12% Atk Speed)"},
			{Val="BunnyHoppers", Title="Bunny Hoppers (+12% Jump)"},
			{Val="PaulsJumpBoots", Title="Paul's Jump Boots (+30% Jump)"},
			{Val="CharliesFarsight", Title="Charlie's Farsight (+25% Range)"},
			{Val="Goblin", Title="Goblin (+$4 Bonus Gold)"},
			{Val="Splitshot", Title="Splitshot (+12% Ricochet)"}
		}
		for _, item in ipairs(itemNames) do
			local val = buffsFolder:FindFirstChild(item.Val)
			if val and val.Value > 0 then text = text .. "• " .. item.Title .. " x" .. val.Value .. "\n" end
		end
		if text == "" then text = "No items collected." end
		buffsListLabel.Text = text
	else
		buffsListLabel.Text = "No items collected."
	end
end

task.spawn(function()
	while task.wait(0.5) do
		updateTeleporterDisplay()
		updateBuffsDisplay()
	end
end)

local function bindHealthAndBuffs(character)
	if not character then return end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.HealthChanged:Connect(function()
			local hp = math.max(0, humanoid.Health)
			healthFill.Size = UDim2.new(hp / humanoid.MaxHealth, 0, 1, 0)
			hpLabel.Text = math.floor(hp) .. " / " .. math.floor(humanoid.MaxHealth) .. " HP"
		end)
		humanoid.Died:Connect(function()
			if gameStartedVal and gameStartedVal.Value then
				renderEndStats()
				statsFrame.Visible = true
			end
		end)
	end

	task.delay(0.5, function()
		local gun = player.Backpack:FindFirstChildOfClass("Tool") or player.Character:FindFirstChildOfClass("Tool")
		if gun and humanoid then humanoid:EquipTool(gun) end
	end)
end

if elapsedTimeVal then elapsedTimeVal.Changed:Connect(updateHUDDisplay) end

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if leaderstats then
		local goldVal = leaderstats:WaitForChild("Gold", 10)
		if goldVal then goldVal.Changed:Connect(updateHUDDisplay) end
	end
	updateHUDDisplay()
end)

if player.Character then bindHealthAndBuffs(player.Character) end
player.CharacterAdded:Connect(bindHealthAndBuffs)

if gameStartedVal then
	gameStartedVal.Changed:Connect(function(started)
		screenGui.Enabled = started == true
		if not started then statsFrame.Visible = false end
	end)
end

screenGui.Enabled = gameStartedVal and gameStartedVal.Value == true or false
updateHUDDisplay(); updateBuffsDisplay()
print("SUCCESS: Clean HUD System Active!")
