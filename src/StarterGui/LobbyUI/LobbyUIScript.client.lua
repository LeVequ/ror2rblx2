local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local screenGui = script.Parent
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = math.max(screenGui.DisplayOrder, 50)

local toggleReadyRemote = ReplicatedStorage:WaitForChild("ToggleReadyRemote", 10)
local completeTutorialRemote = ReplicatedStorage:WaitForChild("CompleteTutorialRemote", 10)
local lobbyPhaseVal = ReplicatedStorage:WaitForChild("LobbyPhase", 10)
local gameStartedVal = ReplicatedStorage:WaitForChild("GameStarted", 10)

local C = {
	Ink = Color3.fromRGB(7, 12, 18),
	Panel = Color3.fromRGB(24, 34, 43),
	PanelSelected = Color3.fromRGB(188, 211, 220),
	Text = Color3.fromRGB(224, 236, 239),
	Muted = Color3.fromRGB(132, 151, 160),
	DarkText = Color3.fromRGB(19, 31, 38),
	Accent = Color3.fromRGB(132, 207, 226),
	AccentSoft = Color3.fromRGB(85, 143, 158),
}

local function make(className, name, parent, props)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local obj = Instance.new(className)
	obj.Name = name
	for k, v in pairs(props or {}) do obj[k] = v end
	obj.Parent = parent
	return obj
end

local function stroke(parent, color, transparency)
	return make("UIStroke", "Stroke", parent, {Color = color, Thickness = 1, Transparency = transparency or 0})
end

local root = make("Frame", "LobbyRoot", screenGui, {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	Visible = false, ZIndex = 2,
})

local shade = make("Frame", "LobbyShade", root, {
	Size = UDim2.fromScale(.55, 1), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = .28, BorderSizePixel = 0, ZIndex = 2,
})
make("UIGradient", "Gradient", shade, {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, .05), NumberSequenceKeypoint.new(.75, .55), NumberSequenceKeypoint.new(1, 1),
	}),
})

local eyebrow = make("TextLabel", "Eyebrow", root, {
	Size = UDim2.new(0, 430, 0, 20), Position = UDim2.fromScale(.05, .07),
	BackgroundTransparency = 1, Text = "BYTEFORCE // SQUAD STAGING",
	TextColor3 = C.Accent, TextSize = 11, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
})

local title = make("TextLabel", "LobbyTitle", root, {
	Size = UDim2.new(0, 520, 0, 52), Position = UDim2.fromScale(.05, .092),
	BackgroundTransparency = 1, Text = "ASSEMBLE YOUR SQUAD",
	TextColor3 = C.Text, TextSize = 31, Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
})

local subtitle = make("TextLabel", "LobbySubtitle", root, {
	Size = UDim2.new(0, 470, 0, 42), Position = UDim2.fromScale(.05, .15),
	BackgroundTransparency = 1,
	Text = "READY UP. SURVIVOR SELECTION BEGINS WHEN THE FULL SQUAD IS READY.",
	TextColor3 = C.Muted, TextSize = 12, Font = Enum.Font.GothamMedium,
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 4,
})

local roster = make("Frame", "PlayerPanel", root, {
	Size = UDim2.new(0, 430, 0, 310), Position = UDim2.fromScale(.05, .235),
	BackgroundColor3 = C.Ink, BackgroundTransparency = .17,
	BorderSizePixel = 0, ZIndex = 3,
})
stroke(roster, C.AccentSoft, .58)

make("TextLabel", "RosterTitle", roster, {
	Size = UDim2.new(1, -28, 0, 34), Position = UDim2.new(0, 14, 0, 10),
	BackgroundTransparency = 1, Text = "SQUAD STATUS",
	TextColor3 = C.Text, TextSize = 13, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
})

local readyBtn = make("TextButton", "ReadyBtn", root, {
	Size = UDim2.new(0, 330, 0, 58), Position = UDim2.new(.05, 0, 1, -106),
	BackgroundColor3 = C.PanelSelected, BorderSizePixel = 0,
	AutoButtonColor = false, Text = "READY UP", TextColor3 = C.DarkText,
	TextSize = 16, Font = Enum.Font.GothamBold, ZIndex = 5,
})
stroke(readyBtn, C.Accent, .25)

local statusText = make("TextLabel", "StatusText", root, {
	Size = UDim2.new(0, 430, 0, 22), Position = UDim2.new(.05, 0, 1, -42),
	BackgroundTransparency = 1, Text = "WAITING FOR OPERATIVES",
	TextColor3 = C.Muted, TextSize = 10, Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
})

local helpBtn = make("TextButton", "HelpBtn", root, {
	Size = UDim2.new(0, 112, 0, 34), Position = UDim2.new(1, -142, 0, 28),
	BackgroundColor3 = C.Panel, BorderSizePixel = 0, Text = "CONTROLS",
	TextColor3 = C.Text, TextSize = 10, Font = Enum.Font.GothamBold, ZIndex = 5,
})
stroke(helpBtn, C.AccentSoft, .62)

local tutorial = make("Frame", "TutorialModal", screenGui, {
	Size = UDim2.new(0, 540, 0, 330), Position = UDim2.new(.5, -270, .5, -165),
	BackgroundColor3 = C.Ink, BorderSizePixel = 0, Visible = false, ZIndex = 30,
})
stroke(tutorial, C.Accent, .32)
make("TextLabel", "Title", tutorial, {
	Size = UDim2.new(1, -32, 0, 44), Position = UDim2.new(0, 16, 0, 14),
	BackgroundTransparency = 1, Text = "COMBAT CONTROLS", TextColor3 = C.Text,
	TextSize = 20, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31,
})
make("TextLabel", "Body", tutorial, {
	Size = UDim2.new(1, -32, 1, -116), Position = UDim2.new(0, 16, 0, 68),
	BackgroundTransparency = 1,
	Text = "M1  PRIMARY\nM2  SECONDARY\nSHIFT  UTILITY\nR  SPECIAL\n\nFind and activate the teleporter, remain inside its charge zone, then eliminate remaining hostiles.",
	TextColor3 = C.Muted, TextSize = 13, Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 31,
})
local closeTutorial = make("TextButton", "CloseTutorial", tutorial, {
	Size = UDim2.new(0, 180, 0, 42), Position = UDim2.new(1, -196, 1, -58),
	BackgroundColor3 = C.PanelSelected, BorderSizePixel = 0, Text = "CLOSE",
	TextColor3 = C.DarkText, TextSize = 12, Font = Enum.Font.GothamBold, ZIndex = 31,
})

local controls
local lobbyActive = false
local cameraBind = "ByteforceLobbyCamera"
local inputBind = "ByteforceLobbyInput"
local cameraGeneration = 0

local function getControls()
	if controls then return controls end
	local ok, result = pcall(function()
		local ps = player:WaitForChild("PlayerScripts", 3)
		local pm = ps and ps:WaitForChild("PlayerModule", 3)
		return pm and require(pm):GetControls()
	end)
	if ok then controls = result end
	return controls
end

local function setControlsEnabled(enabled)
	local c = getControls()
	if not c then return end
	pcall(function() if enabled then c:Enable() else c:Disable() end end)
end

local function stopLobbyCamera()
	RunService:UnbindFromRenderStep(cameraBind)
end

local function lobbyTarget(rootPart, drift)
	local focus = rootPart.Position + Vector3.new(0, 1.6, 0)
	local pos = (rootPart.CFrame * CFrame.new(4.8 + drift, 2.7, -10.5)).Position
	return CFrame.lookAt(pos, focus)
end

local function startLobbyCamera()
	cameraGeneration += 1
	local mine = cameraGeneration
	stopLobbyCamera()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	lobbyActive = true
	setControlsEnabled(false)
	camera.CameraType = Enum.CameraType.Scriptable
	local startCF = camera.CFrame
	local targetCF = lobbyTarget(hrp, 0)
	local startFov = camera.FieldOfView
	local started = os.clock()
	RunService:BindToRenderStep(cameraBind, Enum.RenderPriority.Camera.Value + 1, function()
		if not lobbyActive or mine ~= cameraGeneration or not hrp.Parent then return end
		local elapsed = os.clock() - started
		if elapsed < .85 then
			local a = TweenService:GetValue(math.clamp(elapsed / .85, 0, 1), Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			camera.CFrame = startCF:Lerp(targetCF, a)
			camera.FieldOfView = startFov + (52 - startFov) * a
		else
			local drift = math.sin(elapsed * .25) * .32
			camera.CFrame = lobbyTarget(hrp, drift)
			camera.FieldOfView = 52
		end
	end)
end

local function stopLobbyPresentation()
	lobbyActive = false
	cameraGeneration += 1
	stopLobbyCamera()
	ContextActionService:UnbindAction(inputBind)
	pcall(function() if GuiService.SelectedObject == readyBtn then GuiService.SelectedObject = nil end end)
	root.Visible = false
	tutorial.Visible = false
end

local function refreshReady()
	local ready = player:GetAttribute("IsReady") == true
	readyBtn.Text = ready and "READY // CLICK TO UNREADY" or "READY UP"
	readyBtn.BackgroundColor3 = ready and C.Panel or C.PanelSelected
	readyBtn.TextColor3 = ready and C.Accent or C.DarkText
	local total, readyCount = 0, 0
	for _, p in ipairs(Players:GetPlayers()) do
		total += 1
		if p:GetAttribute("IsReady") == true then readyCount += 1 end
	end
	statusText.Text = string.format("%d / %d OPERATIVES READY", readyCount, total)
end

local function refreshRoster()
	for _, child in ipairs(roster:GetChildren()) do
		if child.Name == "PlayerCard" then child:Destroy() end
	end
	for i, p in ipairs(Players:GetPlayers()) do
		local card = Instance.new("Frame")
		card.Name = "PlayerCard"
		card.Size = UDim2.new(1, -28, 0, 54)
		card.Position = UDim2.new(0, 14, 0, 48 + (i - 1) * 61)
		card.BackgroundColor3 = C.Panel
		card.BackgroundTransparency = .08
		card.BorderSizePixel = 0
		card.ZIndex = 4
		card.Parent = roster

		local avatar = Instance.new("ImageLabel")
		avatar.Size = UDim2.new(0, 40, 0, 40)
		avatar.Position = UDim2.new(0, 7, .5, -20)
		avatar.BackgroundTransparency = 1
		avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. p.UserId .. "&w=150&h=150"
		avatar.ZIndex = 5
		avatar.Parent = card

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -150, 1, 0)
		name.Position = UDim2.new(0, 58, 0, 0)
		name.BackgroundTransparency = 1
		name.Text = string.upper(p.DisplayName)
		name.TextColor3 = C.Text
		name.TextSize = 12
		name.Font = Enum.Font.GothamBold
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.ZIndex = 5
		name.Parent = card

		local ready = p:GetAttribute("IsReady") == true
		local state = Instance.new("TextLabel")
		state.Size = UDim2.new(0, 88, 0, 28)
		state.Position = UDim2.new(1, -98, .5, -14)
		state.BackgroundColor3 = ready and C.PanelSelected or C.Ink
		state.BorderSizePixel = 0
		state.Text = ready and "READY" or "WAITING"
		state.TextColor3 = ready and C.DarkText or C.Muted
		state.TextSize = 10
		state.Font = Enum.Font.GothamBold
		state.ZIndex = 5
		state.Parent = card
	end
	refreshReady()
end

local function showLobby()
	if player:GetAttribute("MainMenuDismissed") ~= true then return end
	if lobbyPhaseVal.Value ~= "LOBBY" or gameStartedVal.Value then return end
	root.Visible = true
	refreshRoster()
	ContextActionService:BindActionAtPriority(inputBind, function(_, state, input)
		if not lobbyActive then return Enum.ContextActionResult.Pass end
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			if toggleReadyRemote then toggleReadyRemote:FireServer() end
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, 8500, Enum.KeyCode.Return, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	if UserInputService.GamepadEnabled then pcall(function() GuiService.SelectedObject = readyBtn end) end
	startLobbyCamera()
end

readyBtn.Activated:Connect(function()
	if lobbyPhaseVal.Value == "LOBBY" and toggleReadyRemote then toggleReadyRemote:FireServer() end
end)
helpBtn.Activated:Connect(function() tutorial.Visible = true end)
closeTutorial.Activated:Connect(function()
	tutorial.Visible = false
	if completeTutorialRemote then completeTutorialRemote:FireServer() end
end)

player:GetAttributeChangedSignal("MainMenuDismissed"):Connect(function()
	if player:GetAttribute("MainMenuDismissed") == true then showLobby() else stopLobbyPresentation() end
end)
player:GetAttributeChangedSignal("IsReady"):Connect(refreshRoster)

lobbyPhaseVal.Changed:Connect(function(phase)
	if phase == "LOBBY" then
		showLobby()
	elseif phase == "SURVIVOR_SELECT" then
		stopLobbyPresentation()
	elseif phase == "RUN" then
		stopLobbyPresentation()
	end
end)

Players.PlayerAdded:Connect(function(p)
	p:GetAttributeChangedSignal("IsReady"):Connect(refreshRoster)
	refreshRoster()
end)
Players.PlayerRemoving:Connect(refreshRoster)
for _, p in ipairs(Players:GetPlayers()) do
	p:GetAttributeChangedSignal("IsReady"):Connect(refreshRoster)
end

gameStartedVal.Changed:Connect(function(started)
	if started then stopLobbyPresentation() end
end)

if player:GetAttribute("MainMenuDismissed") == true and lobbyPhaseVal.Value == "LOBBY" then showLobby() end

script.Destroying:Connect(function()
	stopLobbyPresentation()
	if lobbyPhaseVal.Value == "RUN" then setControlsEnabled(true) end
end)
