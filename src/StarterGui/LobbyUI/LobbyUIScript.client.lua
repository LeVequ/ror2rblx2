local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local screenGui = script.Parent
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = math.max(screenGui.DisplayOrder, 50)

local selectClassRemote = ReplicatedStorage:WaitForChild("SelectClassRemote", 10)
local toggleReadyRemote = ReplicatedStorage:WaitForChild("ToggleReadyRemote", 10)
local startGameRemote = ReplicatedStorage:WaitForChild("StartGameRemote", 10)
local completeTutorialRemote = ReplicatedStorage:WaitForChild("CompleteTutorialRemote", 10)
local showcaseRemote = ReplicatedStorage:WaitForChild("PlayShowcaseRemote", 10)
local gameStartedVal = ReplicatedStorage:WaitForChild("GameStarted", 10)

local function getOrCreate(className, name, parent, properties)
	local item = parent:FindFirstChild(name)
	if not item then item = Instance.new(className); item.Name = name; item.Parent = parent end
	if properties then for k, v in pairs(properties) do item[k] = v end end
	return item
end

local function stroke(instance, color, thickness, transparency)
	return getOrCreate("UIStroke", "Stroke", instance, {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
	})
end

-- LOBBY MAIN FRAME
local backdrop = getOrCreate("Frame", "LobbyBackdrop", screenGui, {
	Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0),
	BackgroundColor3 = Color3.fromRGB(5, 10, 18), BackgroundTransparency = 0.36,
	BorderSizePixel = 0, ZIndex = 0,
	Visible = player:GetAttribute("MainMenuDismissed") == true
})

local lobbyFrame = getOrCreate("Frame", "LobbyFrame", screenGui, {
	Size = UDim2.new(0, 760, 0, 500), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(10, 14, 22), BorderSizePixel = 0, ZIndex = 1,
	Visible = player:GetAttribute("MainMenuDismissed") == true
})
stroke(lobbyFrame, Color3.fromRGB(67, 186, 255), 1.5, 0.12)

local header = getOrCreate("Frame", "Header", lobbyFrame, {
	Size = UDim2.new(1, -24, 0, 64), Position = UDim2.new(0, 12, 0, 12),
	BackgroundColor3 = Color3.fromRGB(16, 32, 50), BorderSizePixel = 0
})
stroke(header, Color3.fromRGB(59, 128, 177), 1, 0.25)

getOrCreate("TextLabel", "LobbyTitle", header, {
	Size = UDim2.new(0, 330, 0, 30), Position = UDim2.new(0, 16, 0, 7), BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(235, 247, 255), TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.SourceSansBold, Text = "BYTEFORCE // DEPLOYMENT BAY"
})

getOrCreate("TextLabel", "LobbySubtitle", header, {
	Size = UDim2.new(0, 340, 0, 18), Position = UDim2.new(0, 16, 0, 37), BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(126, 171, 201), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.SourceSansSemibold, Text = "SELECT A CLASS  •  READY UP  •  DEPLOY"
})

-- TOP CORNER BUTTONS
local helpBtn = getOrCreate("TextButton", "HelpBtn", header, {
	Size = UDim2.new(0, 98, 0, 34), Position = UDim2.new(1, -322, 0.5, -17),
	BackgroundColor3 = Color3.fromRGB(28, 111, 167), TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 14,
	Font = Enum.Font.SourceSansBold, Text = "?  CONTROLS", ZIndex = 5, BorderSizePixel = 0
})

local storyBtn = getOrCreate("TextButton", "StoryBtn", header, {
	Size = UDim2.new(0, 108, 0, 34), Position = UDim2.new(1, -214, 0.5, -17),
	BackgroundColor3 = Color3.fromRGB(166, 100, 24), TextColor3 = Color3.fromRGB(255, 246, 224), TextSize = 14,
	Font = Enum.Font.SourceSansBold, Text = "STORY INTRO", ZIndex = 5, BorderSizePixel = 0
})

local minimizeBtn = getOrCreate("TextButton", "MinimizeBtn", header, {
	Size = UDim2.new(0, 86, 0, 34), Position = UDim2.new(1, -98, 0.5, -17),
	BackgroundColor3 = Color3.fromRGB(42, 50, 64), TextColor3 = Color3.fromRGB(220, 230, 240), TextSize = 13,
	Font = Enum.Font.SourceSansBold, Text = "MINIMIZE", ZIndex = 5, BorderSizePixel = 0
})

local restoreBtn = getOrCreate("TextButton", "RestoreBtn", screenGui, {
	Size = UDim2.new(0, 170, 0, 42), Position = UDim2.new(0, 18, 0, 18),
	BackgroundColor3 = Color3.fromRGB(20, 104, 164), TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 15,
	Font = Enum.Font.SourceSansBold, Text = "OPEN LOBBY", Visible = false, ZIndex = 15, BorderSizePixel = 0
})
stroke(restoreBtn, Color3.fromRGB(89, 190, 255), 1, 0.25)

local function setLobbyVisible(visible)
	local mainMenuDismissed = player:GetAttribute("MainMenuDismissed") == true
	local effectiveVisible = visible and mainMenuDismissed
	lobbyFrame.Visible = effectiveVisible
	backdrop.Visible = effectiveVisible
end

player:GetAttributeChangedSignal("MainMenuDismissed"):Connect(function()
	if player:GetAttribute("MainMenuDismissed") == true and (not gameStartedVal or gameStartedVal.Value == false) then
		setLobbyVisible(true)
	else
		setLobbyVisible(false)
		restoreBtn.Visible = false
	end
end)

minimizeBtn.MouseButton1Click:Connect(function()
	setLobbyVisible(false); restoreBtn.Visible = true
end)

restoreBtn.MouseButton1Click:Connect(function()
	setLobbyVisible(true); restoreBtn.Visible = false
end)

-- Left Panel: Character Choice
local classPanel = getOrCreate("Frame", "ClassPanel", lobbyFrame, {
	Size = UDim2.new(0, 355, 0, 305), Position = UDim2.new(0, 18, 0, 88),
	BackgroundColor3 = Color3.fromRGB(15, 20, 30), BorderSizePixel = 0
})
stroke(classPanel, Color3.fromRGB(55, 72, 92), 1, 0.2)

getOrCreate("TextLabel", "ClassTitle", classPanel, {
	Size = UDim2.new(1, -28, 0, 30), Position = UDim2.new(0, 14, 0, 8), BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(234, 242, 249), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.SourceSansBold, Text = "CHOOSE YOUR OPERATIVE"
})

local gunnerBtn = getOrCreate("TextButton", "GunnerBtn", classPanel, {
	Size = UDim2.new(1, -28, 0, 54), Position = UDim2.new(0, 14, 0, 46), BackgroundColor3 = Color3.fromRGB(22, 111, 178),
	TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.SourceSansBold, Text = "   GUNNER  •  Laser Cannon + Dash", BorderSizePixel = 0
})

local rangerBtn = getOrCreate("TextButton", "RangerBtn", classPanel, {
	Size = UDim2.new(1, -28, 0, 54), Position = UDim2.new(0, 14, 0, 108), BackgroundColor3 = Color3.fromRGB(30, 37, 50),
	TextColor3 = Color3.fromRGB(230, 238, 245), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.SourceSansBold, Text = "   RANGER  •  Energy Bow + Blink", BorderSizePixel = 0
})

local brawlerBtn = getOrCreate("TextButton", "BrawlerBtn", classPanel, {
	Size = UDim2.new(1, -28, 0, 54), Position = UDim2.new(0, 14, 0, 170), BackgroundColor3 = Color3.fromRGB(30, 37, 50),
	TextColor3 = Color3.fromRGB(230, 238, 245), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.SourceSansBold, Text = "   BRAWLER  •  Martial Arts + Strike", BorderSizePixel = 0
})

local weaverBtn = getOrCreate("TextButton", "WeaverBtn", classPanel, {
	Size = UDim2.new(1, -28, 0, 54), Position = UDim2.new(0, 14, 0, 232), BackgroundColor3 = Color3.fromRGB(30, 37, 50),
	TextColor3 = Color3.fromRGB(230, 238, 245), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.SourceSansBold, Text = "   WEAVER  •  Web Snare + Grapple", BorderSizePixel = 0
})

local classButtons = {
	Gunner = {button = gunnerBtn, color = Color3.fromRGB(22, 111, 178)},
	Ranger = {button = rangerBtn, color = Color3.fromRGB(24, 142, 105)},
	Brawler = {button = brawlerBtn, color = Color3.fromRGB(184, 92, 28)},
	Weaver = {button = weaverBtn, color = Color3.fromRGB(125, 67, 174)},
}
local idleClassColor = Color3.fromRGB(30, 37, 50)

local function selectClass(className)
	if selectClassRemote then selectClassRemote:FireServer(className) end
	for name, data in pairs(classButtons) do
		data.button.BackgroundColor3 = name == className and data.color or idleClassColor
	end
end

gunnerBtn.MouseButton1Click:Connect(function()
	selectClass("Gunner")
end)

rangerBtn.MouseButton1Click:Connect(function()
	selectClass("Ranger")
end)

brawlerBtn.MouseButton1Click:Connect(function()
	selectClass("Brawler")
end)

weaverBtn.MouseButton1Click:Connect(function()
	selectClass("Weaver")
end)

-- Right Panel: Player Roster
local playerPanel = getOrCreate("Frame", "PlayerPanel", lobbyFrame, {
	Size = UDim2.new(0, 355, 0, 305), Position = UDim2.new(0, 387, 0, 88),
	BackgroundColor3 = Color3.fromRGB(15, 20, 30), BorderSizePixel = 0
})
stroke(playerPanel, Color3.fromRGB(55, 72, 92), 1, 0.2)

getOrCreate("TextLabel", "RosterTitle", playerPanel, {
	Size = UDim2.new(1, -28, 0, 30), Position = UDim2.new(0, 14, 0, 8), BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(234, 242, 249), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.SourceSansBold, Text = "SQUAD STATUS"
})

local function updatePlayerRoster()
	for _, child in ipairs(playerPanel:GetChildren()) do if child.Name == "PlayerCard" then child:Destroy() end end
	for i, p in ipairs(Players:GetPlayers()) do
		local card = Instance.new("Frame")
		card.Name = "PlayerCard"
		card.Size = UDim2.new(1, -28, 0, 54); card.Position = UDim2.new(0, 14, 0, 46 + (i - 1) * 60)
		card.BackgroundColor3 = Color3.fromRGB(23, 30, 42); card.BorderSizePixel = 0; card.Parent = playerPanel
		local avatar = Instance.new("ImageLabel")
		avatar.Size = UDim2.new(0, 42, 0, 42); avatar.Position = UDim2.new(0, 6, 0.5, -21); avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. p.UserId .. "&w=150&h=150"; avatar.BackgroundTransparency = 1; avatar.Parent = card
		local cls = p:GetAttribute("SelectedClass") or "Gunner"
		local isReady = p:GetAttribute("IsReady") == true
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -150, 0, 24); nameLabel.Position = UDim2.new(0, 56, 0, 5); nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(240, 246, 252); nameLabel.TextSize = 15; nameLabel.Font = Enum.Font.SourceSansBold; nameLabel.TextXAlignment = Enum.TextXAlignment.Left; nameLabel.Text = p.Name; nameLabel.Parent = card
		local classLabel = Instance.new("TextLabel")
		classLabel.Size = UDim2.new(1, -150, 0, 18); classLabel.Position = UDim2.new(0, 56, 0, 28); classLabel.BackgroundTransparency = 1
		classLabel.TextColor3 = Color3.fromRGB(136, 159, 180); classLabel.TextSize = 12; classLabel.Font = Enum.Font.SourceSansSemibold; classLabel.TextXAlignment = Enum.TextXAlignment.Left; classLabel.Text = string.upper(cls); classLabel.Parent = card
		local status = Instance.new("TextLabel")
		status.Size = UDim2.new(0, 82, 0, 28); status.Position = UDim2.new(1, -90, 0.5, -14); status.BackgroundColor3 = isReady and Color3.fromRGB(27, 126, 83) or Color3.fromRGB(57, 66, 80)
		status.TextColor3 = isReady and Color3.fromRGB(225, 255, 239) or Color3.fromRGB(205, 215, 225); status.TextSize = 12; status.Font = Enum.Font.SourceSansBold; status.Text = isReady and "READY" or "WAITING"; status.BorderSizePixel = 0; status.Parent = card
	end
end

-- Bottom Bar: Ready & Play Buttons
local readyBtn = getOrCreate("TextButton", "ReadyBtn", lobbyFrame, {
	Size = UDim2.new(0, 230, 0, 62), Position = UDim2.new(0.5, -242, 0, 417), BackgroundColor3 = Color3.fromRGB(174, 101, 26),
	TextColor3 = Color3.fromRGB(255, 250, 240), TextSize = 20, Font = Enum.Font.SourceSansBold, Text = "READY UP", BorderSizePixel = 0
})
stroke(readyBtn, Color3.fromRGB(232, 167, 79), 1, 0.35)

local playBtn = getOrCreate("TextButton", "PlayBtn", lobbyFrame, {
	Size = UDim2.new(0, 250, 0, 62), Position = UDim2.new(0.5, 12, 0, 417), BackgroundColor3 = Color3.fromRGB(16, 151, 91),
	TextColor3 = Color3.fromRGB(240, 255, 247), TextSize = 20, Font = Enum.Font.SourceSansBold, Text = "DEPLOY SQUAD  ▶", BorderSizePixel = 0
})
stroke(playBtn, Color3.fromRGB(84, 220, 151), 1, 0.35)

local function refreshReadyButton()
	local isReady = player:GetAttribute("IsReady") == true
	readyBtn.Text = isReady and "READY ✓" or "READY UP"
	readyBtn.BackgroundColor3 = isReady and Color3.fromRGB(26, 126, 83) or Color3.fromRGB(174, 101, 26)
end

refreshReadyButton()
player:GetAttributeChangedSignal("IsReady"):Connect(refreshReadyButton)

readyBtn.MouseButton1Click:Connect(function() if toggleReadyRemote then toggleReadyRemote:FireServer() end end)
playBtn.MouseButton1Click:Connect(function() if startGameRemote then startGameRemote:FireServer() end end)

-- CONTROLS TUTORIAL MODAL
local tutorialModal = getOrCreate("Frame", "TutorialModal", screenGui, {
	Size = UDim2.new(0, 550, 0, 360), Position = UDim2.new(0.5, -275, 0.5, -180), BackgroundColor3 = Color3.fromRGB(15, 18, 24), BorderSizePixel = 3, BorderColor3 = Color3.fromRGB(255, 220, 50), Visible = false, ZIndex = 10
})
getOrCreate("TextLabel", "TutTitle", tutorialModal, {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(200, 150, 0), TextColor3 = Color3.fromRGB(255, 255, 255), TextScaled = true, Font = Enum.Font.SourceSansBold, Text = "HOW TO PLAY BYTEFORCE"})
getOrCreate("TextLabel", "TutBody", tutorialModal, {
	Size = UDim2.new(1, -30, 1, -110), Position = UDim2.new(0, 15, 0, 50), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(230, 230, 230), TextSize = 15, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	Text = "• M1 (Hold): Auto Laser Shot\n• M2 (Right Click): Heavy Piercing Shot\n• Shift: Tactical Dash | R: Orbital Strike\n\n1. Defeat Malware to farm Gold.\n2. Buy Data Caches ($25 Gold) for stackable Items!\n3. Hold [E] inside Teleporter Zone to charge patch node!\n4. Defeat Malware Overlord to clear stage!"
})
local closeTutBtn = getOrCreate("TextButton", "CloseTutBtn", tutorialModal, {
	Size = UDim2.new(0, 200, 0, 45), Position = UDim2.new(0.5, -100, 1, -55), BackgroundColor3 = Color3.fromRGB(0, 180, 80), TextColor3 = Color3.fromRGB(255, 255, 255), TextScaled = true, Font = Enum.Font.SourceSansBold, Text = "GOT IT! ▶", ZIndex = 11
})

helpBtn.MouseButton1Click:Connect(function() tutorialModal.Visible = true end)
closeTutBtn.MouseButton1Click:Connect(function()
	tutorialModal.Visible = false
	if completeTutorialRemote then completeTutorialRemote:FireServer() end
end)

-- 3D AVATAR STORY INTRO MODAL & CUTSCENE
local storyModal = getOrCreate("Frame", "StoryModal", screenGui, {
	Size = UDim2.new(0, 580, 0, 110), Position = UDim2.new(0.5, -290, 0.75, -50),
	BackgroundColor3 = Color3.fromRGB(15, 18, 24), BackgroundTransparency = 0.15, BorderSizePixel = 3, BorderColor3 = Color3.fromRGB(200, 120, 0), Visible = false, ZIndex = 20
})

local storyText = getOrCreate("TextLabel", "StoryText", storyModal, {
	Size = UDim2.new(1, -20, 1, -35), Position = UDim2.new(0, 10, 0, 5),
	BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 220, 100), TextScaled = true, Font = Enum.Font.SourceSansBold, Text = "Story Subtitle", ZIndex = 21
})

local closeStoryBtn = getOrCreate("TextButton", "CloseStoryBtn", storyModal, {
	Size = UDim2.new(0, 120, 0, 25), Position = UDim2.new(1, -125, 1, -28),
	BackgroundColor3 = Color3.fromRGB(180, 40, 40), TextColor3 = Color3.fromRGB(255, 255, 255), TextScaled = true, Font = Enum.Font.SourceSansBold, Text = "SKIP [X]", ZIndex = 22
})

local isPlayingStory = false

local function play3DStoryCutscene()
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local root = char.HumanoidRootPart

	isPlayingStory = true
	setLobbyVisible(false)
	restoreBtn.Visible = false

	camera.CameraType = Enum.CameraType.Scriptable
	local startPos = root.CFrame * Vector3.new(-6, 2, -10)
	local endPos = root.CFrame * Vector3.new(6, 1.5, -8)
	camera.CFrame = CFrame.new(startPos, root.Position + Vector3.new(0, 1.5, 0))

	local tweenInfo = TweenInfo.new(12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(camera, tweenInfo, { CFrame = CFrame.new(endPos, root.Position + Vector3.new(0, 1.5, 0)) })
	tween:Play()

	storyModal.Visible = true

	local dialogueLines = {
		"AETHEL-9... Humanity's supercomputer protected global networks for decades.",
		"Until the rogue virus ZERO breached our core firewalls and blacked out the grid.",
		"Worldwide connectivity collapsed in seconds. Zero claimed full control.",
		"Sentinel deployed Emergency Drop Pods from the Sky Hub to reclaim Sector-0.",
		"Operative... your mission is clear: defeat Malware Overlord and DELETE ZERO!"
	}

	for _, line in ipairs(dialogueLines) do
		if not isPlayingStory then break end
		storyText.Text = line

		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://12222170"; sound.Volume = 0.3; sound.Parent = screenGui; sound:Play()
		game:GetService("Debris"):AddItem(sound, 1)

		task.wait(2.8)
	end

	isPlayingStory = false
	storyModal.Visible = false
	camera.CameraType = Enum.CameraType.Custom
	if not gameStartedVal.Value then
		setLobbyVisible(true)
	end
end

storyBtn.MouseButton1Click:Connect(play3DStoryCutscene)
closeStoryBtn.MouseButton1Click:Connect(function()
	isPlayingStory = false
	storyModal.Visible = false
	camera.CameraType = Enum.CameraType.Custom
	if not gameStartedVal.Value then
		setLobbyVisible(true)
	end
end)

if showcaseRemote then showcaseRemote.OnClientEvent:Connect(function() setLobbyVisible(false); restoreBtn.Visible = false; isPlayingStory = false; storyModal.Visible = false end) end

if gameStartedVal then
	gameStartedVal.Changed:Connect(function(started)
		screenGui.Enabled = true
		setLobbyVisible(not started)
		restoreBtn.Visible = false
		if started then tutorialModal.Visible = false; storyModal.Visible = false; isPlayingStory = false end
	end)
end

if not gameStartedVal or gameStartedVal.Value == false then setLobbyVisible(true) end

task.spawn(function()
	while task.wait(0.5) do updatePlayerRoster() end
end)
