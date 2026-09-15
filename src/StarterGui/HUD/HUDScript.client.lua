local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local screenGui = script.Parent
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = math.max(screenGui.DisplayOrder, 20)
screenGui.Enabled = false

local C = {
	Ink = Color3.fromRGB(7, 11, 16), Panel = Color3.fromRGB(19, 28, 36),
	PanelSoft = Color3.fromRGB(31, 43, 52), Text = Color3.fromRGB(231, 240, 243),
	Muted = Color3.fromRGB(122, 143, 151), Accent = Color3.fromRGB(132, 207, 226),
	AccentSoft = Color3.fromRGB(74, 124, 137), Health = Color3.fromRGB(171, 215, 185),
	Warning = Color3.fromRGB(224, 191, 115), Danger = Color3.fromRGB(219, 112, 104),
}

local function make(className, name, parent, props)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local obj = Instance.new(className); obj.Name = name
	for k, v in pairs(props or {}) do obj[k] = v end
	obj.Parent = parent
	return obj
end

local function stroke(parent, color, transparency, thickness)
	return make("UIStroke", "Stroke", parent, {Color=color, Transparency=transparency or 0, Thickness=thickness or 1})
end

local function formatTime(sec)
	return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
end

local CLASS_SKILLS = {
	Gunner={M1="LASER",M2="HEAVY",Shift="DASH",R="STRIKE"},
	Ranger={M1="ARROW",M2="PIERCE",Shift="BLINK",R="RAIN"},
	Brawler={M1="FISTS",M2="PALM",Shift="FLASH",R="SLAM"},
	Weaver={M1="WEB",M2="SNARE",Shift="ZIP",R="SLAM"},
}

local itemRemote = ReplicatedStorage:FindFirstChild("ItemAcquiredRemote") or ReplicatedStorage:WaitForChild("ItemAcquiredRemote",5)
local returnLobbyRemote = ReplicatedStorage:FindFirstChild("ReturnLobbyRemote") or ReplicatedStorage:WaitForChild("ReturnLobbyRemote",5)
local elapsedTimeVal = ReplicatedStorage:FindFirstChild("ElapsedTime") or ReplicatedStorage:WaitForChild("ElapsedTime",5)
local threatTextVal = ReplicatedStorage:FindFirstChild("ThreatText") or ReplicatedStorage:WaitForChild("ThreatText",5)
local chargeVal = ReplicatedStorage:FindFirstChild("TeleporterCharge") or ReplicatedStorage:WaitForChild("TeleporterCharge",5)
local activeVal = ReplicatedStorage:FindFirstChild("TeleporterActive") or ReplicatedStorage:WaitForChild("TeleporterActive",5)
local gameStartedVal = ReplicatedStorage:FindFirstChild("GameStarted") or ReplicatedStorage:WaitForChild("GameStarted",5)

-- Small neutral reticle: visible enough to aim without becoming the visual focus.
local crosshair = make("Frame","Crosshair",screenGui,{Size=UDim2.new(0,4,0,4),Position=UDim2.new(.5,-2,.5,-2),BackgroundColor3=C.Text,BackgroundTransparency=.12,BorderSizePixel=0,ZIndex=10})
make("UICorner","Corner",crosshair,{CornerRadius=UDim.new(1,0)})
stroke(crosshair,Color3.fromRGB(10,15,20),.25,1)

-- Currency lives alone instead of being buried inside a sentence of run data.
local currencyPanel = make("Frame","CurrencyPanel",screenGui,{Size=UDim2.new(0,180,0,42),Position=UDim2.new(0,22,0,20),BackgroundColor3=C.Ink,BackgroundTransparency=.34,BorderSizePixel=0,ZIndex=4})
stroke(currencyPanel,C.AccentSoft,.7,1)
local goldLabel = make("TextLabel","GoldLabel",currencyPanel,{Size=UDim2.new(1,-20,1,0),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,Text="$0",TextColor3=C.Text,TextSize=18,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5})

-- RoR2-style run info cluster: time/difficulty/objective kept compact in one corner.
local runInfo = make("Frame","RunInfo",screenGui,{Size=UDim2.new(0,290,0,84),Position=UDim2.new(1,-312,0,20),BackgroundColor3=C.Ink,BackgroundTransparency=.26,BorderSizePixel=0,ZIndex=4})
stroke(runInfo,C.AccentSoft,.65,1)
local timerLabel = make("TextLabel","TimerLabel",runInfo,{Size=UDim2.new(.58,-8,0,32),Position=UDim2.new(0,12,0,8),BackgroundTransparency=1,Text="00:00",TextColor3=C.Text,TextSize=22,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5})
local threatLabel = make("TextLabel","ThreatLabel",runInfo,{Size=UDim2.new(.42,-12,0,26),Position=UDim2.new(.58,0,0,10),BackgroundColor3=Color3.fromRGB(76,142,94),BackgroundTransparency=.04,BorderSizePixel=0,Text="EASY",TextColor3=Color3.fromRGB(255,255,255),TextStrokeColor3=Color3.fromRGB(0,0,0),TextStrokeTransparency=.35,TextSize=11,Font=Enum.Font.GothamBold,ZIndex=5})
local threatStroke = stroke(threatLabel,Color3.fromRGB(42,79,52),.2,1)
local objectiveLabel = make("TextLabel","ObjectiveLabel",runInfo,{Size=UDim2.new(1,-24,0,30),Position=UDim2.new(0,12,0,45),BackgroundTransparency=1,Text="FIND AND ACTIVATE THE TELEPORTER",TextColor3=C.Muted,TextSize=10,Font=Enum.Font.GothamMedium,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,ZIndex=5})

-- Item list remains readable but no longer occupies a large middle-left dashboard.
local buffsPanel = make("Frame","BuffsPanel",screenGui,{Size=UDim2.new(0,300,0,118),Position=UDim2.new(0,22,0,72),BackgroundColor3=C.Ink,BackgroundTransparency=.58,BorderSizePixel=0,ZIndex=3})
local buffsTitle = make("TextLabel","BuffsTitle",buffsPanel,{Size=UDim2.new(1,-20,0,18),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,Text="ITEMS",TextColor3=Color3.fromRGB(255,255,255),TextStrokeColor3=Color3.fromRGB(0,0,0),TextStrokeTransparency=.15,TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=4})
local buffsListLabel = make("TextLabel","BuffsList",buffsPanel,{Size=UDim2.new(1,-20,1,-20),Position=UDim2.new(0,10,0,20),BackgroundTransparency=1,Text="NO ITEMS",TextColor3=Color3.fromRGB(255,255,255),TextStrokeColor3=Color3.fromRGB(0,0,0),TextStrokeTransparency=.12,TextSize=10,Font=Enum.Font.GothamMedium,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true,ZIndex=4})

-- Health anchors the lower-left without a large saturated green block.
local healthBG = make("Frame","HealthBarBG",screenGui,{Size=UDim2.new(0,320,0,38),Position=UDim2.new(0,22,1,-62),BackgroundColor3=C.Ink,BackgroundTransparency=.18,BorderSizePixel=0,ZIndex=5})
stroke(healthBG,C.AccentSoft,.58,1)
local healthTrack = make("Frame","HealthTrack",healthBG,{Size=UDim2.new(1,-18,0,7),Position=UDim2.new(0,9,1,-14),BackgroundColor3=Color3.fromRGB(42,54,61),BorderSizePixel=0,ZIndex=6})
local healthFill = make("Frame","HealthBarFill",healthTrack,{Size=UDim2.new(1,0,1,0),BackgroundColor3=C.Health,BorderSizePixel=0,ZIndex=7})
local hpLabel = make("TextLabel","HPLabel",healthBG,{Size=UDim2.new(1,-18,0,20),Position=UDim2.new(0,9,0,4),BackgroundTransparency=1,Text="100 / 100",TextColor3=C.Text,TextSize=12,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=7})
local classLabel = make("TextLabel","ClassLabel",healthBG,{Size=UDim2.new(.5,-9,0,20),Position=UDim2.new(.5,0,0,4),BackgroundTransparency=1,Text="GUNNER",TextColor3=C.Muted,TextSize=10,Font=Enum.Font.GothamMedium,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=7})

-- IMPORTANT: AbilityBar, Skill_* and CooldownLabel names are integration API for weapon scripts.
local abilityBar = make("Frame","AbilityBar",screenGui,{Size=UDim2.new(0,354,0,76),Position=UDim2.new(1,-380,1,-100),BackgroundTransparency=1,ZIndex=5})
local skillKeys = {{id="M1",key="M1"},{id="M2",key="M2"},{id="SHIFT",key="SHIFT"},{id="R",key="R"}}
for i, info in ipairs(skillKeys) do
	local box = make("Frame","Skill_"..info.id,abilityBar,{Size=UDim2.new(0,80,0,72),Position=UDim2.new(0,(i-1)*90,0,0),BackgroundColor3=C.Panel,BackgroundTransparency=.08,BorderSizePixel=0,ZIndex=6})
	stroke(box,C.AccentSoft,.5,1)
	make("TextLabel","KeyLabel",box,{Size=UDim2.new(1,-10,0,18),Position=UDim2.new(0,5,0,5),BackgroundTransparency=1,Text=info.key,TextColor3=C.Accent,TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=7})
	make("TextLabel","NameLabel",box,{Size=UDim2.new(1,-10,0,22),Position=UDim2.new(0,5,1,-27),BackgroundTransparency=1,Text="",TextColor3=C.Text,TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=7})
	make("Frame","Glyph",box,{Size=UDim2.new(0,26,0,4),Position=UDim2.new(.5,-13,.5,-4),BackgroundColor3=C.AccentSoft,BackgroundTransparency=.22,BorderSizePixel=0,ZIndex=7})
	make("TextLabel","CooldownLabel",box,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.Ink,BackgroundTransparency=.15,Text="",TextColor3=C.Text,TextSize=18,Font=Enum.Font.GothamBold,Visible=false,ZIndex=9})
end

local teleporterPanel = make("Frame","TeleporterPanel",screenGui,{Size=UDim2.new(0,460,0,42),Position=UDim2.new(.5,-230,0,24),BackgroundColor3=C.Ink,BackgroundTransparency=.18,BorderSizePixel=0,Visible=false,ZIndex=6})
stroke(teleporterPanel,C.Warning,.48,1)
local teleporterLabel = make("TextLabel","TeleporterLabel",teleporterPanel,{Size=UDim2.new(1,-20,1,0),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,Text="",TextColor3=C.Warning,TextSize=12,Font=Enum.Font.GothamBold,ZIndex=7})

local bossBarBG = make("Frame","BossBarBG",screenGui,{Size=UDim2.new(0,520,0,30),Position=UDim2.new(.5,-260,0,74),BackgroundColor3=C.Ink,BackgroundTransparency=.12,BorderSizePixel=0,Visible=false,ZIndex=6})
stroke(bossBarBG,C.Danger,.35,1)
local bossBarFill = make("Frame","BossBarFill",bossBarBG,{Size=UDim2.new(1,0,0,4),Position=UDim2.new(0,0,1,-4),BackgroundColor3=C.Danger,BorderSizePixel=0,ZIndex=7})
local bossLabel = make("TextLabel","BossLabel",bossBarBG,{Size=UDim2.new(1,-16,1,-4),Position=UDim2.new(0,8,0,0),BackgroundTransparency=1,Text="MALWARE OVERLORD",TextColor3=C.Text,TextSize=11,Font=Enum.Font.GothamBold,ZIndex=7})

local pickupBanner = make("Frame","PickupBanner",screenGui,{Size=UDim2.new(0,330,0,66),Position=UDim2.new(0,-350,.32,0),BackgroundColor3=C.Ink,BackgroundTransparency=.12,BorderSizePixel=0,Visible=false,ZIndex=8})
stroke(pickupBanner,C.Accent,.45,1)
local bannerHeader = make("TextLabel","BannerHeader",pickupBanner,{Size=UDim2.new(1,-22,0,24),Position=UDim2.new(0,11,0,8),BackgroundTransparency=1,Text="",TextColor3=C.Text,TextSize=13,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=9})
local bannerDesc = make("TextLabel","BannerDesc",pickupBanner,{Size=UDim2.new(1,-22,0,24),Position=UDim2.new(0,11,0,32),BackgroundTransparency=1,Text="",TextColor3=C.Muted,TextSize=10,Font=Enum.Font.GothamMedium,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=9})

local statsFrame = make("Frame","StatsFrame",screenGui,{Size=UDim2.new(0,700,0,420),Position=UDim2.new(.5,-350,.5,-210),BackgroundColor3=C.Ink,BackgroundTransparency=.04,BorderSizePixel=0,Visible=false,ZIndex=30})
stroke(statsFrame,C.Danger,.28,1)
local statsTitle = make("TextLabel","StatsTitle",statsFrame,{Size=UDim2.new(1,-36,0,64),Position=UDim2.new(0,18,0,14),BackgroundTransparency=1,Text="MISSION FAILED",TextColor3=C.Text,TextSize=28,Font=Enum.Font.GothamBlack,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=31})
local statsSubtitle = make("TextLabel","StatsSubtitle",statsFrame,{Size=UDim2.new(1,-36,0,22),Position=UDim2.new(0,18,0,65),BackgroundTransparency=1,Text="SQUAD STATUS // SECTOR-0",TextColor3=C.Muted,TextSize=10,Font=Enum.Font.GothamMedium,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=31})
local statsContainer = make("Frame","StatsContainer",statsFrame,{Size=UDim2.new(1,-36,0,250),Position=UDim2.new(0,18,0,102),BackgroundTransparency=1,ZIndex=31})
local returnBtn = make("TextButton","ReturnBtn",statsFrame,{Size=UDim2.new(0,250,0,46),Position=UDim2.new(1,-268,1,-58),BackgroundColor3=Color3.fromRGB(190,214,221),BorderSizePixel=0,Text="RETURN TO LOBBY",TextColor3=Color3.fromRGB(18,30,36),TextSize=13,Font=Enum.Font.GothamBold,ZIndex=32})
local returnTransitioning = false

local spectatePanel = make("Frame","SpectatePanel",screenGui,{Size=UDim2.new(0,340,0,44),Position=UDim2.new(.5,-170,0,126),BackgroundColor3=C.Ink,BackgroundTransparency=.18,BorderSizePixel=0,Visible=false,ZIndex=20})
stroke(spectatePanel,C.AccentSoft,.45,1)
local spectateLabel = make("TextLabel","SpectateLabel",spectatePanel,{Size=UDim2.new(1,-20,1,0),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,Text="",TextColor3=C.Text,TextSize=11,Font=Enum.Font.GothamBold,ZIndex=21})

local function updateAbilityBarNames()
	local raw = player:GetAttribute("SelectedClass") or "Gunner"
	local cls = string.upper(string.sub(raw,1,1)) .. string.lower(string.sub(raw,2))
	local names = CLASS_SKILLS[cls] or CLASS_SKILLS[raw] or CLASS_SKILLS.Gunner
	local map = {M1=names.M1,M2=names.M2,SHIFT=names.Shift,R=names.R}
	for id, name in pairs(map) do
		local box=abilityBar:FindFirstChild("Skill_"..id)
		if box and box:FindFirstChild("NameLabel") then box.NameLabel.Text=tostring(name or "") end
	end
	classLabel.Text=string.upper(raw)
end

local DIFFICULTY_STYLES = {
	["EASY"] = {
		Fill = Color3.fromRGB(76,142,94),
		Border = Color3.fromRGB(42,79,52),
	},
	["MEDIUM"] = {
		Fill = Color3.fromRGB(186,149,54),
		Border = Color3.fromRGB(105,82,28),
	},
	["HARD"] = {
		Fill = Color3.fromRGB(201,105,44),
		Border = Color3.fromRGB(113,57,23),
	},
	["VERY HARD"] = {
		Fill = Color3.fromRGB(183,63,55),
		Border = Color3.fromRGB(101,31,27),
	},
	["CRITICAL / IMPOSSIBLE"] = {
		Fill = Color3.fromRGB(145,45,86),
		Border = Color3.fromRGB(75,22,44),
	},
}

local function updateDifficultyStyle(threat)
	local style = DIFFICULTY_STYLES[threat] or DIFFICULTY_STYLES["EASY"]
	threatLabel.BackgroundColor3 = style.Fill
	threatLabel.TextColor3 = Color3.fromRGB(255,255,255)
	threatLabel.TextSize = threat == "CRITICAL / IMPOSSIBLE" and 8 or 11
	if threatStroke then threatStroke.Color = style.Border end
end

local function updateHUDDisplay()
	local sec=elapsedTimeVal and elapsedTimeVal.Value or 0
	local threat=string.upper(tostring(threatTextVal and threatTextVal.Value or "EASY"))
	local statsFolder=player:FindFirstChild("leaderstats")
	local gold=(statsFolder and statsFolder:FindFirstChild("Gold")) and statsFolder.Gold.Value or 0
	timerLabel.Text=formatTime(sec); threatLabel.Text=threat; goldLabel.Text="$"..tostring(gold)
	updateDifficultyStyle(threat)
	updateAbilityBarNames()
end

local function updateTeleporterDisplay()
	if activeVal and activeVal.Value then
		teleporterPanel.Visible=true
		local pct=chargeVal and chargeVal.Value or 0
		if pct>=100 then
			teleporterLabel.Text="TELEPORTER CHARGED // CLEAR REMAINING HOSTILES"
			teleporterLabel.TextColor3=C.Health; objectiveLabel.Text="CLEAR REMAINING HOSTILES"
		else
			local inRange=false
			local tp=workspace:FindFirstChild("ActiveTeleporter")
			local char=player.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
			if tp and hrp then inRange=(hrp.Position-tp.Position).Magnitude<=35 end
			teleporterLabel.Text=(inRange and "CHARGING TELEPORTER // " or "TELEPORTER PAUSED // ")..pct.."%"
			teleporterLabel.TextColor3=inRange and C.Warning or C.Danger
			objectiveLabel.Text=inRange and "REMAIN INSIDE THE TELEPORTER ZONE" or "RETURN TO THE TELEPORTER ZONE"
		end
	else
		teleporterPanel.Visible=false; objectiveLabel.Text="FIND AND ACTIVATE THE TELEPORTER"
	end
end

local ITEM_NAMES = {
	{Val="FirstStompens",Title="FIRST STOMPENS",Short="SPD"},{Val="Dagger",Title="DAGGER",Short="ATK"},
	{Val="BunnyHoppers",Title="BUNNY HOPPERS",Short="JMP"},{Val="PaulsJumpBoots",Title="PAUL'S JUMP BOOTS",Short="JMP+"},
	{Val="CharliesFarsight",Title="CHARLIE'S FARSIGHT",Short="RNG"},{Val="Goblin",Title="GOBLIN",Short="GLD"},
	{Val="Splitshot",Title="SPLITSHOT",Short="RICO"},
}

local function updateBuffsDisplay()
	local folder=player:FindFirstChild("Buffs")
	local parts={}
	if folder then
		for _, item in ipairs(ITEM_NAMES) do
			local val=folder:FindFirstChild(item.Val)
			if val and val.Value>0 then table.insert(parts,item.Short.." x"..val.Value.."  //  "..item.Title) end
		end
	end
	buffsListLabel.Text=#parts>0 and table.concat(parts,"\n") or "NO ITEMS ACQUIRED"
end

local function renderEndStats()
	for _, child in ipairs(statsContainer:GetChildren()) do child:Destroy() end
	local sec=elapsedTimeVal and elapsedTimeVal.Value or 0
	for i, p in ipairs(Players:GetPlayers()) do
		local cls=p:GetAttribute("SelectedClass") or "Gunner"; local kills=p:GetAttribute("Kills") or 0; local totalGold=p:GetAttribute("TotalGoldEarned") or 0
		local itemTotal=0; local folder=p:FindFirstChild("Buffs"); if folder then for _,v in ipairs(folder:GetChildren()) do itemTotal+=v.Value end end
		local card=Instance.new("Frame"); card.Name="PlayerCard"; card.Size=UDim2.new(1,0,0,54); card.Position=UDim2.new(0,0,0,(i-1)*60); card.BackgroundColor3=C.Panel; card.BackgroundTransparency=.08; card.BorderSizePixel=0; card.ZIndex=31; card.Parent=statsContainer
		local avatar=Instance.new("ImageLabel"); avatar.Size=UDim2.new(0,40,0,40); avatar.Position=UDim2.new(0,7,.5,-20); avatar.Image="rbxthumb://type=AvatarHeadShot&id="..p.UserId.."&w=150&h=150"; avatar.BackgroundTransparency=1; avatar.ZIndex=32; avatar.Parent=card
		local info=Instance.new("TextLabel"); info.Size=UDim2.new(1,-60,1,0); info.Position=UDim2.new(0,56,0,0); info.BackgroundTransparency=1; info.TextColor3=C.Text; info.TextSize=11; info.Font=Enum.Font.GothamBold; info.TextXAlignment=Enum.TextXAlignment.Left; info.ZIndex=32; info.Text=string.upper(p.Name).."  //  "..string.upper(cls).."\nTIME "..formatTime(sec).."     KILLS "..kills.."     GOLD $"..totalGold.."     ITEMS "..itemTotal; info.Parent=card
	end
end

local spectating = false
local spectateTarget = nil

local function getHumanoid(targetPlayer)
	local character = targetPlayer and targetPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function getLivingTeammates()
	local living = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local humanoid = getHumanoid(other)
			if humanoid and humanoid.Health > 0 then
				table.insert(living, other)
			end
		end
	end
	return living
end

local function stopSpectating(restoreLocalCamera)
	spectating = false
	spectateTarget = nil
	spectatePanel.Visible = false

	if restoreLocalCamera then
		local humanoid = getHumanoid(player)
		if humanoid and humanoid.Health > 0 then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
	end
end

local function showMissionFailed()
	stopSpectating(false)
	statsTitle.Text = "MISSION FAILED"
	renderEndStats()
	statsFrame.Visible = true
end

local function evaluateDeathState()
	if not gameStartedVal or not gameStartedVal.Value then return end

	local localHumanoid = getHumanoid(player)
	if localHumanoid and localHumanoid.Health > 0 then
		return
	end

	local living = getLivingTeammates()
	if #living == 0 then
		showMissionFailed()
		return
	end

	statsFrame.Visible = false
	spectating = true

	local targetStillAlive = false
	if spectateTarget then
		for _, livingPlayer in ipairs(living) do
			if livingPlayer == spectateTarget then
				targetStillAlive = true
				break
			end
		end
	end
	if not targetStillAlive then
		spectateTarget = living[1]
	end

	local targetHumanoid = getHumanoid(spectateTarget)
	if targetHumanoid then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = targetHumanoid
		spectateLabel.Text = "SPECTATING // " .. string.upper(spectateTarget.DisplayName)
		spectatePanel.Visible = true
	end
end

local function watchPlayerDeath(targetPlayer)
	local function watchCharacter(character)
		task.spawn(function()
			local humanoid = character:WaitForChild("Humanoid", 10)
			if not humanoid then return end
			humanoid.Died:Connect(function()
				task.defer(evaluateDeathState)
			end)
		end)
	end

	if targetPlayer.Character then watchCharacter(targetPlayer.Character) end
	targetPlayer.CharacterAdded:Connect(watchCharacter)
end

for _, observedPlayer in ipairs(Players:GetPlayers()) do
	watchPlayerDeath(observedPlayer)
end
Players.PlayerAdded:Connect(watchPlayerDeath)
Players.PlayerRemoving:Connect(function()
	task.defer(evaluateDeathState)
end)

local function updateHealth(humanoid)
	local hp=math.max(0,humanoid.Health); local max=math.max(1,humanoid.MaxHealth)
	healthFill.Size=UDim2.new(math.clamp(hp/max,0,1),0,1,0); hpLabel.Text=math.floor(hp).." / "..math.floor(max)
end

local boundHumanoid
local function bindCharacter(character)
	local humanoid=character and character:WaitForChild("Humanoid",10)
	if not humanoid then return end
	boundHumanoid=humanoid; updateHealth(humanoid)
	humanoid.HealthChanged:Connect(function() if boundHumanoid==humanoid then updateHealth(humanoid) end end)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function() if boundHumanoid==humanoid then updateHealth(humanoid) end end)
	humanoid.Died:Connect(function()
			if gameStartedVal and gameStartedVal.Value then task.defer(evaluateDeathState) end
		end)
	task.delay(.5,function()
		if not humanoid.Parent then return end
		local gun=player.Backpack:FindFirstChildOfClass("Tool") or character:FindFirstChildOfClass("Tool")
		if gun then humanoid:EquipTool(gun) end
	end)
end

if itemRemote then
	itemRemote.OnClientEvent:Connect(function(titleText,desc,rarity)
		local colors={Common=C.Text,Uncommon=C.Health,Rare=C.Danger}; local color=colors[rarity] or C.Text
		local line=pickupBanner:FindFirstChild("Stroke"); if line then line.Color=color end
		bannerHeader.TextColor3=color; bannerHeader.Text=string.upper(titleText); bannerDesc.Text=desc
		pickupBanner.Visible=true
		TweenService:Create(pickupBanner,TweenInfo.new(.24,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(0,22,.32,0)}):Play()
		task.delay(3.2,function()
			local out=TweenService:Create(pickupBanner,TweenInfo.new(.24,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.new(0,-350,.32,0)})
			out:Play(); out.Completed:Once(function() pickupBanner.Visible=false end)
		end)
	end)
end

returnBtn.MouseButton1Click:Connect(function()
	if returnTransitioning or not returnLobbyRemote then return end
	returnTransitioning = true
	returnBtn.Active = false
	returnBtn.Text = "RETURNING..."
	-- The shared frontend transition controller owns the actual blackout. Keeping
	-- that responsibility out of the gameplay HUD prevents competing tweens/state.
	returnLobbyRemote:FireServer("REQUEST")
end)
player:GetAttributeChangedSignal("SelectedClass"):Connect(updateAbilityBarNames)
if elapsedTimeVal then elapsedTimeVal.Changed:Connect(updateHUDDisplay) end
if threatTextVal then threatTextVal.Changed:Connect(updateHUDDisplay) end
if player.Character then bindCharacter(player.Character) end
player.CharacterAdded:Connect(bindCharacter)

task.spawn(function()
	local leaderstats=player:WaitForChild("leaderstats",10)
	local gold=leaderstats and leaderstats:WaitForChild("Gold",10)
	if gold then gold.Changed:Connect(updateHUDDisplay) end
	updateHUDDisplay()
end)

task.spawn(function()
	while task.wait(.35) do updateTeleporterDisplay(); updateBuffsDisplay() end
end)

if gameStartedVal then
	gameStartedVal.Changed:Connect(function(started)
		screenGui.Enabled=started==true
		if not started then
			returnTransitioning=false
			returnBtn.Active=true
			returnBtn.Text="RETURN TO LOBBY"
			statsFrame.Visible=false
			teleporterPanel.Visible=false
			stopSpectating(false)
		end
		if started and boundHumanoid then updateHealth(boundHumanoid) end
	end)
end

screenGui.Enabled=gameStartedVal and gameStartedVal.Value==true or false
updateHUDDisplay(); updateBuffsDisplay(); updateTeleporterDisplay()
