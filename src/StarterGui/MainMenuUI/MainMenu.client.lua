local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local screenGui = script.Parent
local camera = workspace.CurrentCamera
local gameStartedVal = ReplicatedStorage:WaitForChild("GameStarted", 10)

screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 200

if player:GetAttribute("MainMenuDismissed") == nil then
	player:SetAttribute("MainMenuDismissed", false)
end

if player:GetAttribute("MainMenuDismissed") == true or (gameStartedVal and gameStartedVal.Value) then
	screenGui.Enabled = false
	return
end

-- Freeze normal character controls while the title screen owns focus. This keeps
-- WASD / arrows available for menu navigation and prevents the avatar from
-- wandering around the hidden sky lobby behind the scripted camera.
local menuControls = nil
local menuOwnsControls = true
task.spawn(function()
	local ok, controls = pcall(function()
		local playerScripts = player:WaitForChild("PlayerScripts", 5)
		local playerModule = playerScripts and playerScripts:WaitForChild("PlayerModule", 5)
		if not playerModule then return nil end
		return require(playerModule):GetControls()
	end)
	if ok and controls then
		menuControls = controls
		if menuOwnsControls then
			pcall(function() controls:Disable() end)
		else
			pcall(function() controls:Enable() end)
		end
	end
end)

-- Characters continue to exist in the real lobby while the front end is open,
-- but the title screen should never render them. LocalTransparencyModifier keeps
-- this presentation-only and avoids fighting the server's lobby state.
local hiddenCharacterState = {}
local characterConnections = {}
local playerConnections = {}

local function rememberAndHideCharacterObject(object)
	if hiddenCharacterState[object] then return end

	if object:IsA("BasePart") then
		hiddenCharacterState[object] = {Kind = "BasePart", Value = object.LocalTransparencyModifier}
		object.LocalTransparencyModifier = 1
	elseif object:IsA("Highlight") then
		hiddenCharacterState[object] = {Kind = "Highlight", Value = object.Enabled}
		object.Enabled = false
	elseif object:IsA("BillboardGui") then
		hiddenCharacterState[object] = {Kind = "BillboardGui", Value = object.Enabled}
		object.Enabled = false
	elseif object:IsA("Humanoid") then
		hiddenCharacterState[object] = {Kind = "Humanoid", Value = object.DisplayDistanceType}
		object.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function hideCharacter(character)
	if not character then return end
	for _, descendant in ipairs(character:GetDescendants()) do
		rememberAndHideCharacterObject(descendant)
	end

	if characterConnections[character] then
		characterConnections[character]:Disconnect()
	end
	characterConnections[character] = character.DescendantAdded:Connect(function(descendant)
		if menuOwnsControls then
			rememberAndHideCharacterObject(descendant)
		end
	end)
end

local function watchPlayerCharacter(targetPlayer)
	if targetPlayer.Character then
		hideCharacter(targetPlayer.Character)
	end
	if playerConnections[targetPlayer] then
		playerConnections[targetPlayer]:Disconnect()
	end
	playerConnections[targetPlayer] = targetPlayer.CharacterAdded:Connect(function(character)
		if menuOwnsControls then
			hideCharacter(character)
		end
	end)
end

for _, targetPlayer in ipairs(Players:GetPlayers()) do
	watchPlayerCharacter(targetPlayer)
end

local playerAddedConnection = Players.PlayerAdded:Connect(function(targetPlayer)
	watchPlayerCharacter(targetPlayer)
end)

local function restoreCharacterVisibility()
	for character, connection in pairs(characterConnections) do
		if connection then connection:Disconnect() end
		characterConnections[character] = nil
	end
	for targetPlayer, connection in pairs(playerConnections) do
		if connection then connection:Disconnect() end
		playerConnections[targetPlayer] = nil
	end
	if playerAddedConnection then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end

	for object, state in pairs(hiddenCharacterState) do
		if object and object.Parent then
			if state.Kind == "BasePart" then
				object.LocalTransparencyModifier = state.Value
			elseif state.Kind == "Highlight" or state.Kind == "BillboardGui" then
				object.Enabled = state.Value
			elseif state.Kind == "Humanoid" then
				object.DisplayDistanceType = state.Value
			end
		end
		hiddenCharacterState[object] = nil
	end
end

local function create(className, name, parent, properties)
	local instance = Instance.new(className)
	instance.Name = name
	if properties then
		for property, value in pairs(properties) do
			instance[property] = value
		end
	end
	instance.Parent = parent
	return instance
end

local function addStroke(parent, color, transparency, thickness)
	return create("UIStroke", "Stroke", parent, {
		Color = color,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
	})
end

local COLORS = {
	Ink = Color3.fromRGB(7, 12, 18),
	InkSoft = Color3.fromRGB(16, 24, 32),
	Panel = Color3.fromRGB(24, 34, 43),
	PanelSelected = Color3.fromRGB(188, 211, 220),
	Text = Color3.fromRGB(224, 236, 239),
	Muted = Color3.fromRGB(132, 151, 160),
	DarkText = Color3.fromRGB(19, 31, 38),
	Accent = Color3.fromRGB(132, 207, 226),
	AccentSoft = Color3.fromRGB(85, 143, 158),
}

-- Preserve the gameplay lighting and apply a temporary atmospheric title-screen grade.
local savedLighting = {
	Brightness = Lighting.Brightness,
	ClockTime = Lighting.ClockTime,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	FogColor = Lighting.FogColor,
	FogStart = Lighting.FogStart,
	FogEnd = Lighting.FogEnd,
}

Lighting.Brightness = 1.45
Lighting.ClockTime = 18.65
Lighting.Ambient = Color3.fromRGB(37, 51, 62)
Lighting.OutdoorAmbient = Color3.fromRGB(49, 64, 73)
Lighting.FogColor = Color3.fromRGB(73, 112, 126)
Lighting.FogStart = 52
Lighting.FogEnd = 535

local bloom = create("BloomEffect", "MainMenuBloom", Lighting, {
	Intensity = 0.45,
	Size = 34,
	Threshold = 1.1,
})
local colorGrade = create("ColorCorrectionEffect", "MainMenuColorGrade", Lighting, {
	Brightness = -0.04,
	Contrast = 0.12,
	Saturation = -0.23,
	TintColor = Color3.fromRGB(207, 226, 232),
})

local sceneFolder = create("Folder", "MainMenuScene_Client", workspace)

-- Keep the title-screen diorama completely separate from the physical sky lobby.
-- The lobby lives around Y ~= 2000; this scene is intentionally thousands of studs
-- away so real characters, lobby geometry, and showcase props can never drift into
-- the title camera's frustum.
local MENU_ORIGIN = Vector3.new(24000, 9200, -24000)

local function scenePart(name, size, cframe, color, material, transparency, shape)
	local part = create("Part", name, sceneFolder, {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = true,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = material or Enum.Material.Slate,
		Transparency = transparency or 0,
	})
	if shape then part.Shape = shape end
	return part
end

local baseY = MENU_ORIGIN.Y
scenePart(
	"DistantGround",
	Vector3.new(1250, 8, 1250),
	CFrame.new(MENU_ORIGIN + Vector3.new(0, -4, 250)),
	Color3.fromRGB(8, 13, 18),
	Enum.Material.Slate
)

-- Layer 1: chunky foreground silhouettes. These intentionally fill the bottom of
-- the frame and give the camera something close enough to create parallax.
local foregroundRocks = {
	{-235, 16, -52, 180, 38, 96, -9},
	{-92, 12, -34, 155, 29, 88, 7},
	{72, 15, -42, 170, 36, 92, -5},
	{222, 13, -56, 185, 31, 100, 8},
}

for index, data in ipairs(foregroundRocks) do
	local x, y, z, sx, sy, sz, rot = table.unpack(data)
	scenePart(
		"ForegroundRock" .. index,
		Vector3.new(sx, sy, sz),
		CFrame.new(MENU_ORIGIN + Vector3.new(x, y, z)) * CFrame.Angles(math.rad(-4), math.rad(rot), math.rad(rot * 0.18)),
		Color3.fromRGB(7, 11, 15),
		Enum.Material.Slate
	)
end

-- Layer 2: readable terrain masses. These provide the broad stepped ridgeline
-- that the original sparse spires were missing.
local midground = {
	{-285, 22, 128, 150, 44, 170, -8},
	{-150, 30, 155, 175, 60, 190, 4},
	{4, 24, 132, 140, 48, 175, -4},
	{142, 35, 168, 180, 70, 215, 7},
	{308, 20, 142, 165, 40, 180, -6},
}

for index, data in ipairs(midground) do
	local x, y, z, sx, sy, sz, rot = table.unpack(data)
	scenePart(
		"MidgroundMass" .. index,
		Vector3.new(sx, sy, sz),
		CFrame.new(MENU_ORIGIN + Vector3.new(x, y, z)) * CFrame.Angles(math.rad(-2), math.rad(rot), math.rad(rot * 0.12)),
		Color3.fromRGB(15 + index, 23 + index, 29 + index),
		Enum.Material.Slate
	)
end

local spires = {
	{-305, 122, 330, 50, 122, 54, -8},
	{-210, 91, 285, 32, 91, 38, 9},
	{-120, 162, 395, 42, 162, 44, -4},
	{-28, 84, 300, 30, 84, 46, 13},
	{92, 128, 360, 46, 128, 58, -9},
	{190, 96, 292, 38, 96, 40, 6},
	{292, 178, 430, 58, 178, 50, 11},
	{385, 104, 338, 34, 104, 40, -6},
}

for index, data in ipairs(spires) do
	local x, height, z, sx, sy, sz, rot = table.unpack(data)
	scenePart(
		"Spire" .. index,
		Vector3.new(sx, sy, sz),
		CFrame.new(MENU_ORIGIN + Vector3.new(x, height * 0.5, z)) * CFrame.Angles(0, math.rad(rot), math.rad(rot * 0.12)),
		Color3.fromRGB(18 + index, 26 + index, 31 + index),
		Enum.Material.Slate
	)
end

local moon = scenePart(
	"SignalMoon",
	Vector3.new(138, 138, 138),
	CFrame.new(MENU_ORIGIN + Vector3.new(-225, 155, 525)),
	Color3.fromRGB(129, 205, 224),
	Enum.Material.Neon,
	0.22,
	Enum.PartType.Ball
)
create("PointLight", "MoonGlow", moon, {
	Brightness = 2.8,
	Color = Color3.fromRGB(124, 207, 226),
	Range = 225,
})

-- Strong midground focal point: a damaged relay mast with restrained cyan light.
local relayBase = scenePart(
	"SignalRelayBase",
	Vector3.new(34, 8, 42),
	CFrame.new(MENU_ORIGIN + Vector3.new(118, 7, 118)) * CFrame.Angles(0, math.rad(-14), 0),
	Color3.fromRGB(19, 30, 37),
	Enum.Material.Metal
)
local relayMast = scenePart(
	"SignalRelayMast",
	Vector3.new(7, 72, 7),
	CFrame.new(MENU_ORIGIN + Vector3.new(118, 46, 118)) * CFrame.Angles(0, 0, math.rad(-5)),
	Color3.fromRGB(26, 40, 48),
	Enum.Material.Metal
)
local relayCore = scenePart(
	"SignalRelayCore",
	Vector3.new(13, 13, 13),
	CFrame.new(MENU_ORIGIN + Vector3.new(114, 72, 118)),
	Color3.fromRGB(117, 216, 235),
	Enum.Material.Neon,
	0.12,
	Enum.PartType.Ball
)
create("PointLight", "RelayGlow", relayCore, {
	Brightness = 3.2,
	Color = Color3.fromRGB(112, 218, 239),
	Range = 72,
})

for index = 1, 3 do
	local arm = scenePart(
		"RelayArm" .. index,
		Vector3.new(3, 26 + index * 4, 3),
		CFrame.new(MENU_ORIGIN + Vector3.new(114, 68, 118))
			* CFrame.Angles(math.rad(72), math.rad((index - 1) * 120), 0)
			* CFrame.new(0, 13, 0),
		Color3.fromRGB(41, 58, 66),
		Enum.Material.Metal
	)
	arm.CanCollide = false
end

-- Secondary focal shape: a low wreck silhouette offset to the right.
scenePart(
	"WreckHull",
	Vector3.new(68, 18, 30),
	CFrame.new(MENU_ORIGIN + Vector3.new(248, 15, 95)) * CFrame.Angles(math.rad(7), math.rad(-20), math.rad(3)),
	Color3.fromRGB(17, 27, 33),
	Enum.Material.Metal
)
local wreckLight = scenePart(
	"WreckLight",
	Vector3.new(10, 3, 3),
	CFrame.new(MENU_ORIGIN + Vector3.new(226, 21, 83)) * CFrame.Angles(0, math.rad(-20), 0),
	Color3.fromRGB(119, 211, 230),
	Enum.Material.Neon,
	0.16
)
create("PointLight", "WreckGlow", wreckLight, {
	Brightness = 1.8,
	Color = Color3.fromRGB(112, 202, 222),
	Range = 44,
})

for index = 1, 11 do
	local x = -335 + index * 58
	local z = 190 + ((index * 73) % 245)
	local y = baseY + 34 + ((index * 29) % 86)
	local shard = scenePart(
		"FloatingShard" .. index,
		Vector3.new(5 + (index % 4) * 2, 15 + (index % 3) * 4, 5),
		CFrame.new(MENU_ORIGIN.X + x, y, MENU_ORIGIN.Z + z) * CFrame.Angles(math.rad(index * 13), math.rad(index * 29), math.rad(index * 7)),
		Color3.fromRGB(40, 57, 66),
		Enum.Material.Slate,
		0.22
	)
	shard:SetAttribute("MenuBaseY", y)
end

for index = 1, 15 do
	local x = -300 + index * 42
	local z = 45 + ((index * 91) % 355)
	local y = baseY + 35 + ((index * 37) % 118)
	local mote = scenePart(
		"SignalMote" .. index,
		Vector3.new(0.8 + (index % 3) * 0.35, 0.8 + (index % 3) * 0.35, 0.8 + (index % 3) * 0.35),
		CFrame.new(MENU_ORIGIN.X + x, y, MENU_ORIGIN.Z + z),
		Color3.fromRGB(130, 220, 235),
		Enum.Material.Neon,
		0.35,
		Enum.PartType.Ball
	)
	mote:SetAttribute("MenuBaseY", y)
end

-- Screen-space composition.
local root = create("Frame", "Root", screenGui, {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
})

local leftShade = create("Frame", "LeftShade", root, {
	Size = UDim2.fromScale(0.62, 1),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.18,
	BorderSizePixel = 0,
	ZIndex = 1,
})
create("UIGradient", "Gradient", leftShade, {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.04),
		NumberSequenceKeypoint.new(0.55, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	}),
})

local bottomShade = create("Frame", "BottomShade", root, {
	Size = UDim2.fromScale(1, 0.42),
	Position = UDim2.fromScale(0, 0.58),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.28,
	BorderSizePixel = 0,
	ZIndex = 1,
})
local bottomGradient = create("UIGradient", "Gradient", bottomShade, {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.1),
	}),
})

local logoGroup = create("Frame", "LogoGroup", root, {
	Size = UDim2.fromScale(0.64, 0.18),
	Position = UDim2.fromScale(0.5, 0.055),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	ZIndex = 3,
})

local title = create("TextLabel", "Title", logoGroup, {
	Size = UDim2.fromScale(1, 0.64),
	BackgroundTransparency = 1,
	Text = "BYTEFORCE",
	TextColor3 = COLORS.Text,
	TextTransparency = 1,
	TextStrokeColor3 = Color3.fromRGB(5, 10, 14),
	TextStrokeTransparency = 0.42,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	ZIndex = 3,
})
create("UITextSizeConstraint", "TitleSize", title, {
	MinTextSize = 30,
	MaxTextSize = 74,
})

local subtitle = create("TextLabel", "Subtitle", logoGroup, {
	Size = UDim2.fromScale(1, 0.24),
	Position = UDim2.fromScale(0, 0.62),
	BackgroundTransparency = 1,
	Text = "Z E R O   S I G N A L",
	TextColor3 = COLORS.Accent,
	TextTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	ZIndex = 3,
})
create("UITextSizeConstraint", "SubtitleSize", subtitle, {
	MinTextSize = 10,
	MaxTextSize = 20,
})

local logoLine = create("Frame", "LogoLine", logoGroup, {
	Size = UDim2.fromScale(0.36, 0.012),
	Position = UDim2.fromScale(0.32, 0.92),
	BackgroundColor3 = COLORS.AccentSoft,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 3,
})

local profile = create("Frame", "Profile", root, {
	Size = UDim2.new(0, 226, 0, 48),
	Position = UDim2.new(1, -248, 0, 22),
	BackgroundColor3 = COLORS.Ink,
	BackgroundTransparency = 0.72,
	BorderSizePixel = 0,
	ZIndex = 4,
})
addStroke(profile, COLORS.AccentSoft, 0.78, 1)

local avatar = create("ImageLabel", "Avatar", profile, {
	Size = UDim2.new(0, 32, 0, 32),
	Position = UDim2.new(0, 8, 0.5, -16),
	BackgroundColor3 = COLORS.Panel,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150",
	ZIndex = 5,
})
create("UICorner", "Corner", avatar, {CornerRadius = UDim.new(1, 0)})

create("TextLabel", "Username", profile, {
	Size = UDim2.new(1, -54, 0, 20),
	Position = UDim2.new(0, 50, 0, 5),
	BackgroundTransparency = 1,
	Text = string.upper(player.DisplayName),
	TextColor3 = COLORS.Text,
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
})

create("TextLabel", "Status", profile, {
	Size = UDim2.new(1, -54, 0, 15),
	Position = UDim2.new(0, 50, 0, 26),
	BackgroundTransparency = 1,
	Text = "ONLINE // READY",
	TextColor3 = COLORS.Accent,
	TextSize = 9,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
})

local nav = create("Frame", "Navigation", root, {
	Size = UDim2.new(0.30, 0, 0, 276),
	Position = UDim2.fromScale(0.052, 0.525),
	AnchorPoint = Vector2.new(0, 0.5),
	BackgroundTransparency = 1,
	ZIndex = 4,
})
create("UISizeConstraint", "NavSize", nav, {
	MinSize = Vector2.new(255, 260),
	MaxSize = Vector2.new(390, 290),
})
create("UIListLayout", "List", nav, {
	FillDirection = Enum.FillDirection.Vertical,
	HorizontalAlignment = Enum.HorizontalAlignment.Left,
	VerticalAlignment = Enum.VerticalAlignment.Top,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 4),
})

local menuEntries = {
	{Key = "PLAY", Label = "PLAY", Description = "Enter the deployment bay and prepare a run."},
	{Key = "SURVIVORS", Label = "SURVIVORS", Description = "Review available operatives and combat roles."},
	{Key = "LOGBOOK", Label = "LOGBOOK", Description = "Review recovered mission records and objectives."},
	{Key = "SETTINGS", Label = "SETTINGS", Description = "Configure presentation and control options."},
	{Key = "CREDITS", Label = "CREDITS", Description = "Project information and acknowledgements."},
}

local buttons = {}
local selectedIndex = 1
local transitioning = false
local activeSectionKey = nil
local sectionTweenGeneration = 0
local sectionTweens = {}

for index, entry in ipairs(menuEntries) do
	local row = create("TextButton", entry.Key, nav, {
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = index,
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
		ZIndex = 4,
	})
	addStroke(row, COLORS.AccentSoft, 1, 1)

	local accent = create("Frame", "Accent", row, {
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = COLORS.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
	})

	local numberLabel = create("TextLabel", "Number", row, {
		Size = UDim2.new(0, 38, 1, 0),
		Position = UDim2.new(0, 13, 0, 0),
		BackgroundTransparency = 1,
		Text = string.format("%02d", index),
		TextColor3 = COLORS.Muted,
		TextTransparency = 1,
		TextSize = 9,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	})

	local label = create("TextLabel", "Label", row, {
		Size = UDim2.new(1, -62, 1, 0),
		Position = UDim2.new(0, 52, 0, 0),
		BackgroundTransparency = 1,
		Text = entry.Label,
		TextColor3 = COLORS.Text,
		TextTransparency = 1,
		TextSize = 19,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	})

	buttons[index] = {
		Button = row,
		Label = label,
		Number = numberLabel,
		Accent = accent,
		Entry = entry,
	}
end

local description = create("TextLabel", "Description", root, {
	Size = UDim2.new(0.38, 0, 0, 52),
	Position = UDim2.fromScale(0.052, 0.755),
	BackgroundTransparency = 1,
	Text = menuEntries[1].Description,
	TextColor3 = COLORS.Muted,
	TextTransparency = 1,
	TextSize = 13,
	Font = Enum.Font.GothamMedium,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 4,
})

local sectionPanel = create("Frame", "SectionPanel", root, {
	Size = UDim2.fromScale(0.40, 0.30),
	Position = UDim2.fromScale(0.39, 0.53),
	BackgroundColor3 = COLORS.Ink,
	BackgroundTransparency = 0.18,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 8,
})
addStroke(sectionPanel, COLORS.AccentSoft, 0.42, 1)

local sectionTitle = create("TextLabel", "SectionTitle", sectionPanel, {
	Size = UDim2.new(1, -44, 0, 48),
	Position = UDim2.new(0, 22, 0, 16),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = COLORS.Text,
	TextSize = 24,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 9,
})

local sectionBody = create("TextLabel", "SectionBody", sectionPanel, {
	Size = UDim2.new(1, -44, 1, -82),
	Position = UDim2.new(0, 22, 0, 68),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = COLORS.Muted,
	TextSize = 14,
	Font = Enum.Font.GothamMedium,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 9,
})

create("TextLabel", "Build", root, {
	Size = UDim2.new(0, 310, 0, 26),
	Position = UDim2.new(0, 24, 1, -42),
	BackgroundTransparency = 1,
	Text = "BYTEFORCE // EARLY BUILD 0.1",
	TextColor3 = Color3.fromRGB(103, 123, 132),
	TextSize = 10,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 4,
})

create("TextLabel", "InputHint", root, {
	Size = UDim2.new(0, 430, 0, 28),
	Position = UDim2.new(1, -454, 1, -44),
	BackgroundTransparency = 1,
	Text = "W/S  OR  ↑/↓   SELECT     ENTER / A   CONFIRM",
	TextColor3 = Color3.fromRGB(114, 134, 143),
	TextSize = 10,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 4,
})

local transition = create("Frame", "Transition", root, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	ZIndex = 100,
})

local sectionCopy = {
	SURVIVORS = "GUNNER  //  rapid ranged pressure and tactical dash\nRANGER  //  precision fire and blink mobility\nBRAWLER  //  durable close-range burst damage\nWEAVER  //  control tools, grapple movement, and crowd setup",
	LOGBOOK = "MISSION: reclaim Sector-0 from the ZERO infection.\n\nRecovered records will eventually track enemies, items, stages, run milestones, and discovery progress.",
	SETTINGS = "The title screen already supports mouse, keyboard, and controller navigation.\n\nFull gameplay audio, camera, sensitivity, and accessibility settings can be wired here in a later pass.",
	CREDITS = "BYTEFORCE\nA Roblox action-roguelike prototype inspired by the pacing and presentation language of Risk of Rain.\n\nBuilt around the current operative, item, teleporter, and run systems.",
}

local function tween(instance, duration, properties, style, direction)
	local tw = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		properties
	)
	tw:Play()
	return tw
end

local function cancelSectionTweens()
	for _, activeTween in ipairs(sectionTweens) do
		pcall(function()
			activeTween:Cancel()
		end)
	end
	table.clear(sectionTweens)
end

local function tweenSection(instance, duration, properties, style, direction)
	local tw = tween(instance, duration, properties, style, direction)
	table.insert(sectionTweens, tw)
	return tw
end

local function setSelected(index)
	if transitioning then return end
	index = ((index - 1) % #buttons) + 1
	selectedIndex = index
	description.Text = buttons[index].Entry.Description

	for buttonIndex, data in ipairs(buttons) do
		local selected = buttonIndex == index
		tween(data.Button, 0.12, {
			BackgroundColor3 = selected and COLORS.PanelSelected or COLORS.Panel,
			BackgroundTransparency = selected and 0.12 or 0.46,
		})
		tween(data.Label, 0.12, {
			TextColor3 = selected and COLORS.DarkText or COLORS.Text,
		})
		tween(data.Number, 0.12, {
			TextColor3 = selected and COLORS.DarkText or COLORS.Muted,
		})
		tween(data.Accent, 0.12, {
			BackgroundTransparency = selected and 0 or 1,
		})
		local stroke = data.Button:FindFirstChild("Stroke")
		if stroke then
			tween(stroke, 0.12, {Transparency = selected and 0.22 or 0.72})
		end
	end

	if UserInputService.GamepadEnabled then
		pcall(function()
			game:GetService("GuiService").SelectedObject = buttons[index].Button
		end)
	end
end

local function openSection(key)
	if transitioning then return end

	sectionTweenGeneration += 1
	cancelSectionTweens()
	activeSectionKey = key
	sectionPanel.Visible = true
	sectionTitle.Text = key
	sectionBody.Text = sectionCopy[key] or "Additional systems will be available here later."

	-- If this is a direct switch from another section, keep the panel anchored and
	-- only refresh the contents. This feels immediate and avoids a full close/open
	-- animation every time the user clicks a different menu entry.
	if sectionPanel.BackgroundTransparency < 0.95 then
		sectionPanel.Position = UDim2.fromScale(0.39, 0.53)
		sectionTitle.TextTransparency = 0.35
		sectionBody.TextTransparency = 0.35
		tweenSection(sectionPanel, 0.11, {
			Position = UDim2.fromScale(0.39, 0.53),
			BackgroundTransparency = 0.18,
		})
		tweenSection(sectionTitle, 0.11, {TextTransparency = 0})
		tweenSection(sectionBody, 0.14, {TextTransparency = 0})
		return
	end

	sectionPanel.Position = UDim2.fromScale(0.405, 0.55)
	sectionPanel.BackgroundTransparency = 1
	sectionTitle.TextTransparency = 1
	sectionBody.TextTransparency = 1
	tweenSection(sectionPanel, 0.18, {
		Position = UDim2.fromScale(0.39, 0.53),
		BackgroundTransparency = 0.18,
	})
	tweenSection(sectionTitle, 0.16, {TextTransparency = 0})
	tweenSection(sectionBody, 0.2, {TextTransparency = 0})
end

local function closeSection()
	if not activeSectionKey then return end

	activeSectionKey = nil
	sectionTweenGeneration += 1
	local closeGeneration = sectionTweenGeneration
	cancelSectionTweens()

	local closeTween = tweenSection(sectionPanel, 0.13, {
		Position = UDim2.fromScale(0.405, 0.55),
		BackgroundTransparency = 1,
	})
	closeTween.Completed:Once(function()
		if closeGeneration == sectionTweenGeneration and activeSectionKey == nil then
			sectionPanel.Visible = false
		end
	end)
end

local cameraBindName = "ByteforceMainMenuCamera"
local startTime = os.clock()
camera.CameraType = Enum.CameraType.Scriptable

RunService:BindToRenderStep(cameraBindName, Enum.RenderPriority.Camera.Value + 1, function()
	if transitioning or not screenGui.Enabled then return end

	local t = os.clock() - startTime
	local mouse = UserInputService:GetMouseLocation()
	local viewport = camera.ViewportSize
	local xRatio = viewport.X > 0 and (mouse.X / viewport.X - 0.5) or 0
	local yRatio = viewport.Y > 0 and (mouse.Y / viewport.Y - 0.5) or 0

	-- Lower, slower framing: foreground rock silhouettes occupy the bottom edge,
	-- while the relay and skyline sit in the middle distance. Mouse parallax is
	-- deliberately restrained so the scene feels cinematic instead of floaty.
	local position = MENU_ORIGIN + Vector3.new(
		math.sin(t * 0.072) * 3.6,
		52 + math.sin(t * 0.05) * 1.15,
		-138 + math.cos(t * 0.06) * 2.0
	)
	local target = MENU_ORIGIN + Vector3.new(
		xRatio * 5.5 + math.sin(t * 0.035) * 3.2,
		34 - yRatio * 2.7,
		166
	)
	camera.CFrame = CFrame.lookAt(position, target)
	camera.FieldOfView = 61

	for _, object in ipairs(sceneFolder:GetChildren()) do
		local baseObjectY = object:GetAttribute("MenuBaseY")
		if baseObjectY then
			local offset = math.sin(t * 0.38 + object.Position.X * 0.018) * 1.6
			local current = object.Position
			object.Position = Vector3.new(current.X, baseObjectY + offset, current.Z)
		end
	end
end)

local function restoreWorldPresentation()
	menuOwnsControls = false
	ContextActionService:UnbindAction("ByteforceMainMenuInput")
	RunService:UnbindFromRenderStep(cameraBindName)
	restoreCharacterVisibility()
	if sceneFolder and sceneFolder.Parent then sceneFolder:Destroy() end
	if bloom and bloom.Parent then bloom:Destroy() end
	if colorGrade and colorGrade.Parent then colorGrade:Destroy() end
	if menuControls then
		pcall(function() menuControls:Enable() end)
	end

	for property, value in pairs(savedLighting) do
		Lighting[property] = value
	end

	pcall(function()
		StarterGui:SetCore("TopbarEnabled", true)
	end)
end

local function enterLobby()
	if transitioning then return end
	transitioning = true
	activeSectionKey = nil
	sectionTweenGeneration += 1
	cancelSectionTweens()
	sectionPanel.Visible = false

	for _, data in ipairs(buttons) do
		data.Button.Active = false
	end

	tween(description, 0.16, {TextTransparency = 1})
	tween(logoGroup, 0.22, {Position = UDim2.fromScale(0.5, 0.035)})
	tween(title, 0.18, {TextTransparency = 0.45})
	tween(subtitle, 0.18, {TextTransparency = 0.6})

	local fade = tween(transition, 0.38, {BackgroundTransparency = 0})
	fade.Completed:Wait()

	restoreWorldPresentation()
	-- Lobby presentation takes ownership immediately after the menu. Keep the
	-- camera scriptable and keep PlayerModule controls disabled so there is no
	-- one-frame gap where the avatar can move between front-end states.
	if menuControls then
		pcall(function() menuControls:Disable() end)
	end
	camera.CameraType = Enum.CameraType.Scriptable

	player:SetAttribute("MainMenuDismissed", true)
	RunService.RenderStepped:Wait()

	local reveal = tween(transition, 0.44, {BackgroundTransparency = 1})
	reveal.Completed:Wait()
	screenGui.Enabled = false
end

local function activateSelected()
	if transitioning then return end
	local key = buttons[selectedIndex].Entry.Key
	if key == "PLAY" then
		task.spawn(enterLobby)
	elseif activeSectionKey == key then
		closeSection()
	else
		openSection(key)
	end
end

for index, data in ipairs(buttons) do
	data.Button.MouseEnter:Connect(function()
		setSelected(index)
	end)
	data.Button.Activated:Connect(function()
		setSelected(index)
		activateSelected()
	end)
end

local function handleMenuInput(_, inputState, inputObject)
	if not screenGui.Enabled or transitioning then
		return Enum.ContextActionResult.Pass
	end
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end

	local keyCode = inputObject.KeyCode
	if keyCode == Enum.KeyCode.Escape or keyCode == Enum.KeyCode.ButtonB then
		if activeSectionKey then
			closeSection()
		end
		return Enum.ContextActionResult.Sink
	end

	if keyCode == Enum.KeyCode.Up
		or keyCode == Enum.KeyCode.W
		or keyCode == Enum.KeyCode.DPadUp then
		setSelected(selectedIndex - 1)
		return Enum.ContextActionResult.Sink
	elseif keyCode == Enum.KeyCode.Down
		or keyCode == Enum.KeyCode.S
		or keyCode == Enum.KeyCode.DPadDown then
		setSelected(selectedIndex + 1)
		return Enum.ContextActionResult.Sink
	elseif keyCode == Enum.KeyCode.Return
		or keyCode == Enum.KeyCode.Space
		or keyCode == Enum.KeyCode.ButtonA then
		activateSelected()
		return Enum.ContextActionResult.Sink
	end

	return Enum.ContextActionResult.Pass
end

ContextActionService:BindActionAtPriority(
	"ByteforceMainMenuInput",
	handleMenuInput,
	false,
	10000,
	Enum.KeyCode.Escape,
	Enum.KeyCode.ButtonB,
	Enum.KeyCode.Up,
	Enum.KeyCode.W,
	Enum.KeyCode.DPadUp,
	Enum.KeyCode.Down,
	Enum.KeyCode.S,
	Enum.KeyCode.DPadDown,
	Enum.KeyCode.Return,
	Enum.KeyCode.Space,
	Enum.KeyCode.ButtonA
)

if gameStartedVal then
	gameStartedVal.Changed:Connect(function(started)
		if started and screenGui.Enabled and not transitioning then
			player:SetAttribute("MainMenuDismissed", true)
			restoreWorldPresentation()
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			camera.CameraType = Enum.CameraType.Custom
			if humanoid then camera.CameraSubject = humanoid end
			camera.FieldOfView = 70
			screenGui.Enabled = false
		end
	end)
end

pcall(function()
	StarterGui:SetCore("TopbarEnabled", false)
end)

-- Intro sequence.
screenGui.Enabled = true
setSelected(1)

tween(transition, 0.75, {BackgroundTransparency = 1}, Enum.EasingStyle.Sine)
tween(title, 0.55, {TextTransparency = 0}, Enum.EasingStyle.Quad)
task.delay(0.11, function()
	tween(subtitle, 0.48, {TextTransparency = 0})
	tween(logoLine, 0.5, {BackgroundTransparency = 0.26})
end)

for index, data in ipairs(buttons) do
	data.Button.Position = UDim2.new(0, -22, 0, 0)
	task.delay(0.18 + (index - 1) * 0.055, function()
		tween(data.Button, 0.25, {Position = UDim2.new(0, 0, 0, 0)})
		tween(data.Label, 0.26, {TextTransparency = 0})
		tween(data.Number, 0.26, {TextTransparency = 0})
		if index == selectedIndex then
			setSelected(selectedIndex)
		else
			tween(data.Button, 0.24, {BackgroundTransparency = 0.46})
		end
	end)
end

task.delay(0.36, function()
	tween(description, 0.35, {TextTransparency = 0})
end)
