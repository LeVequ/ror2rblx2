local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterPack = game:GetService("StarterPack")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Runs own the player lifecycle. Roblox's default auto-respawn would create a
-- fresh character a few seconds after death, which breaks both the solo
-- Mission Failed state and multiplayer spectating. Characters are spawned
-- explicitly on join and when returning to the lobby instead.
Players.CharacterAutoLoads = false

local DropPodBuilder = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DropPodBuilder"))

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
local disbandLobbyRemote = getOrCreate("RemoteEvent", "DisbandLobbyRemote", ReplicatedStorage)
local deploymentRemote = getOrCreate("RemoteEvent", "DeploymentRemote", ReplicatedStorage)

local gameStartedVal = getOrCreate("BoolValue", "GameStarted", ReplicatedStorage)
gameStartedVal.Value = false
local lobbyPhaseVal = getOrCreate("StringValue", "LobbyPhase", ReplicatedStorage)
lobbyPhaseVal.Value = "LOBBY"

-- The title screen and the ready lobby are one continuous frontend space.
-- The main-menu camera initially looks toward +Z; this staging area sits behind
-- that camera so PLAY can physically turn around and reveal the squad.
local FRONTEND_ORIGIN = Vector3.new(24000, 9200, -24000)
local LOBBY_CENTER = FRONTEND_ORIGIN + Vector3.new(0, 4, -230)
local LOBBY_SLOT_OFFSETS = {-12, -4, 4, 12}
local MAX_LOBBY_SLOTS = #LOBBY_SLOT_OFFSETS
local SHOWCASE_CENTER = Vector3.new(0, 2005, 50)
local DEPLOYMENT_HEIGHT = 420
local DEPLOYMENT_BRAKE_HEIGHT = 58
local DEPLOYMENT_DURATION = 6.0
local DEPLOYMENT_LEAD_IN = 0.85

local activeDeploymentFolder = nil
local deploymentLocks = {}

local chargeVal = getOrCreate("IntValue", "TeleporterCharge", ReplicatedStorage)
chargeVal.Value = 0
local activeVal = getOrCreate("BoolValue", "TeleporterActive", ReplicatedStorage)
activeVal.Value = false
local completeVal = getOrCreate("BoolValue", "TeleporterComplete", ReplicatedStorage)
completeVal.Value = false

-- 2. BUILD PHYSICAL FRONTEND LOBBY + SURVIVOR SHOWCASE
local oldFrontend = Workspace:FindFirstChild("ByteforceFrontendLobby")
if oldFrontend then oldFrontend:Destroy() end

local frontendLobby = Instance.new("Folder")
frontendLobby.Name = "ByteforceFrontendLobby"
frontendLobby.Parent = Workspace

local function stagePart(name, size, cframe, color, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = true
	part.Parent = frontendLobby
	return part
end

local lobbyPlatform = stagePart(
	"SkyLobbyPlatform",
	Vector3.new(112, 1.5, 72),
	CFrame.new(LOBBY_CENTER + Vector3.new(0, -3.75, -5)),
	Color3.fromRGB(20, 29, 35),
	Enum.Material.Metal
)

-- A broad stepped deck and wrapped rear facade make the squad lineup read as one
-- bay inside a much larger installation.  The old 58-stud wall visibly ended inside
-- the camera frustum; the new center wall plus angled wings continue off-screen and
-- visually connect to the 360-degree client-side skyline.
stagePart(
	"LobbyRearDeck",
	Vector3.new(98, 5, 14),
	CFrame.new(LOBBY_CENTER + Vector3.new(0, -2, -17)),
	Color3.fromRGB(14, 22, 28),
	Enum.Material.Metal
)
stagePart(
	"LobbyRearWall",
	Vector3.new(88, 13, 2.2),
	CFrame.new(LOBBY_CENTER + Vector3.new(0, 2.75, -22)),
	Color3.fromRGB(10, 17, 23),
	Enum.Material.Metal
)

stagePart(
	"LobbyRearWingLeft",
	Vector3.new(34, 13, 2.2),
	CFrame.new(LOBBY_CENTER + Vector3.new(-54, 2.75, -15)) * CFrame.Angles(0, math.rad(-28), 0),
	Color3.fromRGB(11, 19, 25),
	Enum.Material.Metal
)
stagePart(
	"LobbyRearWingRight",
	Vector3.new(34, 13, 2.2),
	CFrame.new(LOBBY_CENTER + Vector3.new(54, 2.75, -15)) * CFrame.Angles(0, math.rad(28), 0),
	Color3.fromRGB(11, 19, 25),
	Enum.Material.Metal
)

-- Shallow wall panels catch enough of the menu lighting to make the facade readable
-- without turning it into a bright backdrop.  Leaving the upper section open exposes
-- the distant perimeter skyline between this lower wall and the overhead beam.
for index, xOffset in ipairs({-25.5, -8.5, 8.5, 25.5}) do
	local panel = stagePart(
		"LobbyRearPanel" .. index,
		Vector3.new(14, 7.2, 0.45),
		CFrame.new(LOBBY_CENTER + Vector3.new(xOffset, 2.15, -20.68)),
		Color3.fromRGB(25, 41, 49),
		Enum.Material.Metal
	)
	panel.CanCollide = false
end

local wallCapStrip = stagePart(
	"LobbyWallCapStrip",
	Vector3.new(72, 0.42, 0.5),
	CFrame.new(LOBBY_CENTER + Vector3.new(0, 8.95, -20.62)),
	Color3.fromRGB(52, 89, 99),
	Enum.Material.Neon,
	0.62
)
wallCapStrip.CanCollide = false

-- Keep only short edge columns around the lower facade.  The staging area should
-- feel open to the skyline above rather than like a window cut into a hangar wall.
for index, xOffset in ipairs({-43, 43}) do
	stagePart(
		"LobbyRearColumn" .. index,
		Vector3.new(4.4, 13.5, 5.2),
		CFrame.new(LOBBY_CENTER + Vector3.new(xOffset, 2.9, -20.5)),
		Color3.fromRGB(21, 31, 38),
		Enum.Material.Metal
	)
end

for index, xOffset in ipairs({-34, -17, 0, 17, 34}) do
	local lightBar = stagePart(
		"LobbyRearLight" .. index,
		Vector3.new(index == 3 and 0.8 or 0.6, index == 3 and 12 or 9.5, 0.45),
		CFrame.new(LOBBY_CENTER + Vector3.new(xOffset, index == 3 and 5.2 or 4.5, -20.72)),
		Color3.fromRGB(98, 201, 224),
		Enum.Material.Neon,
		index == 3 and 0.12 or 0.22
	)
	lightBar.CanCollide = false
end

-- Side service blocks sit in the outer thirds of the frame and give the bay some
-- near-field depth without crowding the four operative slots in the center.
for index, xOffset in ipairs({-48, 48}) do
	stagePart(
		"LobbyServiceBlock" .. index,
		Vector3.new(11, 10, 12),
		CFrame.new(LOBBY_CENTER + Vector3.new(xOffset, 1, -4)),
		Color3.fromRGB(16, 25, 31),
		Enum.Material.Metal
	)
	local serviceCap = stagePart(
		"LobbyServiceCap" .. index,
		Vector3.new(8, 3, 8),
		CFrame.new(LOBBY_CENTER + Vector3.new(xOffset + (index == 1 and 1.2 or -1.2), 7.5, -4)),
		Color3.fromRGB(26, 38, 45),
		Enum.Material.Metal
	)
	serviceCap.CanCollide = false
end

local keyLightRig = stagePart(
	"LobbyKeyLightRig",
	Vector3.new(1, 1, 1),
	CFrame.new(LOBBY_CENTER + Vector3.new(-8, 7, 9)),
	Color3.new(1, 1, 1),
	Enum.Material.SmoothPlastic,
	1
)
keyLightRig.CanCollide = false
local keyLight = Instance.new("PointLight")
keyLight.Color = Color3.fromRGB(185, 222, 231)
keyLight.Brightness = 2.8
keyLight.Range = 38
keyLight.Shadows = false
keyLight.Parent = keyLightRig

local fillLightRig = stagePart(
	"LobbyFillLightRig",
	Vector3.new(1, 1, 1),
	CFrame.new(LOBBY_CENTER + Vector3.new(11, 4, 7)),
	Color3.new(1, 1, 1),
	Enum.Material.SmoothPlastic,
	1
)
fillLightRig.CanCollide = false
local fillLight = Instance.new("PointLight")
fillLight.Color = Color3.fromRGB(94, 176, 199)
fillLight.Brightness = 2.1
fillLight.Range = 34
fillLight.Shadows = false
fillLight.Parent = fillLightRig

for index, xOffset in ipairs(LOBBY_SLOT_OFFSETS) do
	local pad = stagePart(
		"LobbySlotPad" .. index,
		Vector3.new(5.4, 0.35, 5.4),
		CFrame.new(LOBBY_CENTER + Vector3.new(xOffset, -2.82, 0)),
		Color3.fromRGB(55, 96, 108),
		Enum.Material.Neon,
		0.18
	)
	pad.CanCollide = false

	local marker = stagePart(
		"LobbySlotMarker" .. index,
		Vector3.new(3.7, 0.12, 3.7),
		CFrame.new(LOBBY_CENTER + Vector3.new(xOffset, -2.6, 0)),
		Color3.fromRGB(126, 212, 231),
		Enum.Material.Neon,
		0.28
	)
	marker.CanCollide = false
end

local lobbySpawn = Instance.new("SpawnLocation")
lobbySpawn.Name = "LobbySpawn"
lobbySpawn.Size = Vector3.new(8, 1, 8)
lobbySpawn.Position = LOBBY_CENTER - Vector3.new(0, 2.8, 7)
lobbySpawn.Transparency = 1
lobbySpawn.CanCollide = false
lobbySpawn.Anchored = true
lobbySpawn.Enabled = true
lobbySpawn.Neutral = true
lobbySpawn.Duration = 0
lobbySpawn.Parent = frontendLobby

-- Survivor select gets its own dark deployment bay.  The old implementation was
-- one giant cyan Neon slab, which made the floor the brightest object on screen
-- and left the survivor floating in an empty black void.  This set keeps the same
-- showcase coordinates so the rest of the flow does not need to change, but gives
-- the camera real foreground / midground / background layers and restrained
-- practical lighting.
local oldShowcasePodium = Workspace:FindFirstChild("ShowcasePodium")
if oldShowcasePodium then oldShowcasePodium:Destroy() end
local oldShowcaseScene = Workspace:FindFirstChild("ByteforceShowcaseScene")
if oldShowcaseScene then oldShowcaseScene:Destroy() end

local showcaseScene = Instance.new("Folder")
showcaseScene.Name = "ByteforceShowcaseScene"
showcaseScene.Parent = Workspace

local function showcasePart(name, size, cframe, color, material, transparency, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = canCollide == true
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.Parent = showcaseScene
	return part
end

local function showcaseWedge(name, size, cframe, color, material, transparency)
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.Parent = showcaseScene
	return part
end

local showcaseDark = Color3.fromRGB(13, 21, 27)
local showcaseMetal = Color3.fromRGB(25, 37, 45)
local showcasePanel = Color3.fromRGB(34, 49, 58)
local showcaseEdge = Color3.fromRGB(49, 68, 78)
local showcaseCyan = Color3.fromRGB(70, 176, 197)
local showcaseAmber = Color3.fromRGB(211, 145, 69)

-- Floor / presentation pad.  The broad deck is deliberately almost black; only
-- thin inset strips are emissive so the character remains the focal point.
showcasePart(
	"ShowcaseFloor",
	Vector3.new(56, 1, 38),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(0, -4.5, 2)),
	showcaseDark,
	Enum.Material.Metal,
	0,
	true
)
showcasePart(
	"ShowcaseFloorInset",
	Vector3.new(32, 0.22, 20),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(2, -3.9, 1)),
	showcaseMetal,
	Enum.Material.DiamondPlate,
	0,
	false
)

local pedestal = showcasePart(
	"ShowcasePodium",
	Vector3.new(12, 1.5, 9),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(0, -3.75, 0)),
	showcasePanel,
	Enum.Material.Metal,
	0,
	true
)
local podiumTop = showcasePart(
	"ShowcasePodiumTop",
	Vector3.new(11.2, 0.08, 8.2),
	-- Keep the decorative DiamondPlate face slightly proud of the structural podium.
	-- The old placement put both top faces at the exact same world Y, which caused
	-- depth fighting as the survivor-select camera performed its tiny idle drift.
	CFrame.new(SHOWCASE_CENTER + Vector3.new(0, -2.99, 0)),
	Color3.fromRGB(37, 51, 59),
	Enum.Material.DiamondPlate,
	0,
	false
)
podiumTop.CastShadow = false

local podiumFrontLip = showcasePart(
	"PodiumFrontLip",
	Vector3.new(10.2, 0.12, 0.28),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(0, -2.96, -4.38)),
	showcaseCyan,
	Enum.Material.Neon,
	0.2,
	false
)
podiumFrontLip.CastShadow = false
-- A tiny pool of light on the lip adds floor separation without recreating the
-- giant cyan wash that the previous Neon podium produced.
local podiumGlowRig = showcasePart(
	"PodiumGlowRig",
	Vector3.new(0.4, 0.4, 0.4),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(0, -1.7, -3.6)),
	Color3.new(1, 1, 1),
	Enum.Material.SmoothPlastic,
	1,
	false
)
local podiumGlow = Instance.new("PointLight")
podiumGlow.Color = showcaseCyan
podiumGlow.Brightness = 0.45
podiumGlow.Range = 10
podiumGlow.Shadows = false
podiumGlow.Parent = podiumGlowRig

-- Rear hangar wall.  Broad low-value surfaces ensure the upper half of the frame
-- has readable architecture instead of pure black while staying safely behind UI.
showcasePart(
	"RearWall",
	Vector3.new(58, 28, 2),
	-- Proven survivor-select fix: pull this rear layer toward the camera with the
	-- arch/beam group so it no longer depth-competes with OverheadSpine.
	CFrame.new(SHOWCASE_CENTER + Vector3.new(3, 8, 17)),
	showcaseDark,
	Enum.Material.Metal,
	0,
	false
)
showcasePart(
	"RearRecess",
	Vector3.new(24, 15, 1.1),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(6, 6.5, 17.85)),
	Color3.fromRGB(8, 16, 21),
	Enum.Material.Metal,
	0,
	false
)
showcasePart(
	"RearBacklitPanel",
	Vector3.new(17, 10.5, 0.35),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(4.5, 5.8, 17.18)),
	Color3.fromRGB(35, 88, 102),
	Enum.Material.Neon,
	0.48,
	false
)
showcasePart(
	"RearPanelLeftFrame",
	Vector3.new(0.8, 11.6, 0.7),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(-4.35, 5.8, 16.9)),
	showcaseEdge,
	Enum.Material.Metal,
	0,
	false
)
showcasePart(
	"RearPanelRightFrame",
	Vector3.new(0.8, 11.6, 0.7),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(13.35, 5.8, 16.9)),
	showcaseEdge,
	Enum.Material.Metal,
	0,
	false
)

-- Closer maintenance arch: this is the main silhouette immediately behind the
-- selected survivor.  It creates a deliberate visual pocket without becoming a
-- glowing portal.
showcasePart(
	"PresentationArchLeft",
	Vector3.new(1.8, 13, 3),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(-5, 4.2, 9.6)),
	showcasePanel,
	Enum.Material.Metal,
	0,
	false
)
showcasePart(
	"PresentationArchRight",
	Vector3.new(1.8, 13, 3),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(12, 4.2, 11.6)),
	showcasePanel,
	Enum.Material.Metal,
	0,
	false
)
showcasePart(
	"PresentationArchTop",
	Vector3.new(18.8, 2, 3),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(3.5, 10.9, 11.6)),
	showcaseEdge,
	Enum.Material.Metal,
	0,
	false
)
showcasePart(
	"PresentationArchStatus",
	Vector3.new(3.8, 0.22, 0.22),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(6.5, 9.75, 9.98)),
	showcaseCyan,
	Enum.Material.Neon,
	0.42,
	false
)
local archAmber = showcasePart(
	"PresentationArchAmber",
	Vector3.new(1.5, 0.85, 0.3),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(10.8, 6.1, 9.96)),
	showcaseAmber,
	Enum.Material.Neon,
	0.02,
	false
)
local archAmberLight = Instance.new("PointLight")
archAmberLight.Color = showcaseAmber
archAmberLight.Brightness = 0.65
archAmberLight.Range = 7
archAmberLight.Shadows = false
archAmberLight.Parent = archAmber
showcasePart(
	"RearStatusSlit",
	Vector3.new(5.2, 0.28, 0.18),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(8, 10.1, 16.92)),
	showcaseCyan,
	Enum.Material.Neon,
	0.5,
	false
)
showcasePart(
	"RearRecessTopRail",
	Vector3.new(22, 0.7, 0.7),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(6, 13.3, 17.15)),
	showcaseEdge,
	Enum.Material.Metal,
	0,
	false
)
showcasePart(
	"RearRecessBottomRail",
	Vector3.new(22, 0.55, 0.7),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(6, 0.2, 17.15)),
	showcasePanel,
	Enum.Material.Metal,
	0,
	false
)


for index, xOffset in ipairs({-13, 15}) do
	showcasePart(
		"RearColumn" .. index,
		Vector3.new(4.5, 30, 5),
		CFrame.new(SHOWCASE_CENTER + Vector3.new(xOffset, 8, 16.2)),
		showcasePanel,
		Enum.Material.Metal,
		0,
		false
	)
	showcasePart(
		"RearColumnInset" .. index,
		Vector3.new(2, 18, 0.55),
		CFrame.new(SHOWCASE_CENTER + Vector3.new(xOffset, 7.5, 13.55)),
		showcaseDark,
		Enum.Material.Metal,
		0,
		false
	)
end

showcasePart(
	"OverheadBeam",
	-- The survivor-select diagnostic pass showed that shifting this beam, the left
	-- arch, and the rear wall 2 studs toward the camera eliminates the unstable
	-- upper silhouette. Keep that proven depth ordering in the real scene.
	Vector3.new(42, 3.4, 1.8),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(7, 12.3, 14.4)) * CFrame.Angles(0, 0, math.rad(-2)),
	showcaseMetal,
	Enum.Material.Metal,
	0,
	false
)
showcasePart(
	"OverheadSpine",
	Vector3.new(26, 2.4, 7),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(8, 9.5, 10.5)) * CFrame.Angles(0, math.rad(-5), math.rad(-5)),
	showcaseEdge,
	Enum.Material.Metal,
	0,
	false
)

-- Angled braces break up the wall into an industrial silhouette without covering
-- the central survivor window.
showcasePart(
	"LeftBrace",
	Vector3.new(2.2, 19, 2.2),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(-12, 8, 15)) * CFrame.Angles(0, 0, math.rad(-24)),
	showcaseEdge,
	Enum.Material.Metal,
	0,
	false
)
showcasePart(
	"RightBrace",
	Vector3.new(2.2, 17, 2.2),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(13, 9, 15)) * CFrame.Angles(0, 0, math.rad(21)),
	showcaseEdge,
	Enum.Material.Metal,
	0,
	false
)

-- Asymmetric right-side equipment rack / partial machinery mass.  This frames the
-- character instead of leaving the right side as undifferentiated empty space.
showcasePart(
	"EquipmentRackBody",
	Vector3.new(10, 15, 8),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(14, 4.5, 8)),
	showcaseMetal,
	Enum.Material.Metal,
	0,
	false
)
showcasePart(
	"EquipmentRackInset",
	Vector3.new(7.2, 10.5, 0.8),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(14, 4.4, 3.55)),
	showcaseDark,
	Enum.Material.Metal,
	0,
	false
)
for index, yOffset in ipairs({0.8, 4.2, 7.6}) do
	showcasePart(
		"RackShelf" .. index,
		Vector3.new(7.6, 0.55, 3.8),
		CFrame.new(SHOWCASE_CENTER + Vector3.new(14, yOffset, 5.2)),
		showcaseEdge,
		Enum.Material.Metal,
		0,
		false
	)
end
for index, yOffset in ipairs({2.5, 6.1}) do
	showcasePart(
		"RackIndicator" .. index,
		Vector3.new(2.4, 0.28, 0.32),
		CFrame.new(SHOWCASE_CENTER + Vector3.new(14, yOffset, 3.05)),
		index == 1 and showcaseCyan or showcaseAmber,
		Enum.Material.Neon,
		0.3,
		false
	)
end

-- Narrow machinery to the survivor's left provides a second framing mass while
-- preserving a dark quiet zone beneath the information UI.
showcasePart(
	"LeftMachineryColumn",
	Vector3.new(5, 18, 6),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(-11, 6, 11)),
	Color3.fromRGB(15, 24, 31),
	Enum.Material.Metal,
	0,
	false
)
showcaseWedge(
	"LeftMachineryCap",
	Vector3.new(6.5, 4, 7),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(-11, 16, 10.5)) * CFrame.Angles(0, math.rad(180), 0),
	showcasePanel,
	Enum.Material.Metal,
	0
)

-- Recessed ceiling practicals: visible fixtures, not free-floating neon bars.
for index, xOffset in ipairs({2, 13}) do
	showcasePart(
		"CeilingFixtureHousing" .. index,
		Vector3.new(5.2, 1.1, 3.2),
		CFrame.new(SHOWCASE_CENTER + Vector3.new(xOffset, 11.7, 7.5)) * CFrame.Angles(math.rad(-8), 0, 0),
		showcaseEdge,
		Enum.Material.Metal,
		0,
		false
	)
	local strip = showcasePart(
		"CeilingFixtureGlow" .. index,
		Vector3.new(3.4, 0.24, 1.4),
		CFrame.new(SHOWCASE_CENTER + Vector3.new(xOffset, 11.15, 6.7)) * CFrame.Angles(math.rad(-8), 0, 0),
		showcaseCyan,
		Enum.Material.Neon,
		0.35,
		false
	)
		local fixtureLight = Instance.new("PointLight")
		fixtureLight.Color = Color3.fromRGB(107, 195, 213)
		fixtureLight.Brightness = index == 1 and 1.2 or 0.9
		fixtureLight.Range = 18
		-- Menu practicals do not need dynamic shadow maps. Keeping these unshadowed
		-- avoids shadow shimmer on the thin podium/floor trim during camera drift.
		fixtureLight.Shadows = false
		fixtureLight.Parent = strip
	end

-- One small warm practical keeps the scene from collapsing into monochrome cyan.
local warningLamp = showcasePart(
	"WarningLamp",
	Vector3.new(1.8, 1.1, 0.55),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(14, 9.4, 3.5)),
	showcaseAmber,
	Enum.Material.Neon,
	0.12,
	false
)
local warningLight = Instance.new("PointLight")
warningLight.Color = showcaseAmber
warningLight.Brightness = 1.35
warningLight.Range = 12
warningLight.Shadows = false
warningLight.Parent = warningLamp

-- Very soft wall wash reveals the bay's large forms without flattening the scene.
local wallWashRig = showcasePart(
	"WallWashRig",
	Vector3.new(0.5, 0.5, 0.5),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(4, 9, 9)),
	Color3.new(1, 1, 1),
	Enum.Material.SmoothPlastic,
	1,
	false
)
local wallWash = Instance.new("PointLight")
wallWash.Color = Color3.fromRGB(74, 112, 124)
wallWash.Brightness = 0.72
wallWash.Range = 24
wallWash.Shadows = false
wallWash.Parent = wallWashRig

-- Character lighting: a soft cool front key plus a tighter cyan rim from behind.
local keyRig = showcasePart(
	"ShowcaseKeyRig",
	Vector3.new(0.5, 0.5, 0.5),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(-7, 7, -9)),
	Color3.new(1, 1, 1),
	Enum.Material.SmoothPlastic,
	1,
	false
)
local showcaseKey = Instance.new("PointLight")
showcaseKey.Color = Color3.fromRGB(169, 204, 214)
showcaseKey.Brightness = 1.15
showcaseKey.Range = 24
-- Survivor select should never depend on a freshly-generated shadow map just to
-- make the presentation character readable. The bay still gets depth from its
-- surrounding geometry, rim light, and practical fixtures.
showcaseKey.Shadows = false
showcaseKey.Parent = keyRig

local rimRig = showcasePart(
	"ShowcaseRimRig",
	Vector3.new(0.5, 0.5, 0.5),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(8, 7, 8)),
	Color3.new(1, 1, 1),
	Enum.Material.SmoothPlastic,
	1,
	false
)
local showcaseRim = Instance.new("PointLight")
showcaseRim.Color = Color3.fromRGB(70, 187, 211)
showcaseRim.Brightness = 1.45
showcaseRim.Range = 17
showcaseRim.Shadows = false
showcaseRim.Parent = rimRig

-- A near-camera rail adds a final foreground layer and makes the bay feel enclosed.
showcasePart(
	"ForegroundRail",
	Vector3.new(20, 1.2, 1.1),
	CFrame.new(SHOWCASE_CENTER + Vector3.new(14, -1.7, -10.5)) * CFrame.Angles(0, math.rad(-7), 0),
	Color3.fromRGB(5, 9, 12),
	Enum.Material.Metal,
	0.05,
	false
)

local function assignLobbySlot(player)
	local existing = player:GetAttribute("LobbySlot")
	if typeof(existing) == "number" and existing >= 1 and existing <= MAX_LOBBY_SLOTS then
		local duplicate = false
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and other:GetAttribute("LobbySlot") == existing then
				duplicate = true
				break
			end
		end
		if not duplicate then return existing end
	end

	for slot = 1, MAX_LOBBY_SLOTS do
		local occupied = false
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and other:GetAttribute("LobbySlot") == slot then
				occupied = true
				break
			end
		end
		if not occupied then
			player:SetAttribute("LobbySlot", slot)
			return slot
		end
	end

	-- Experiences should be configured for four players in Studio / Creator
	-- Dashboard. This fallback keeps an unexpected fifth client out of the lineup.
	player:SetAttribute("LobbySlot", 0)
	return 0
end

local function lobbySlotCFrame(player)
	local slot = assignLobbySlot(player)
	if slot < 1 or slot > MAX_LOBBY_SLOTS then
		local overflow = LOBBY_CENTER + Vector3.new(0, 0, -10)
		return CFrame.lookAt(overflow, overflow + Vector3.new(0, 0, 1))
	end
	local position = LOBBY_CENTER + Vector3.new(LOBBY_SLOT_OFFSETS[slot], 0, 0)
	return CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
end

local function lockPresentationMovement(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum then
		hum.WalkSpeed = 0
		hum.JumpHeight = 0
		hum.JumpPower = 0
		hum.Jump = false
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function movePlayerToLobbySlot(player)
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		player.Character:PivotTo(lobbySlotCFrame(player))
		lockPresentationMovement(player)
	end
end

-- 3. DISABLE ALL STAGE SPAWNS WHILE IN LOBBY
local function disableStageSpawns()
	for _, desc in ipairs(Workspace:GetDescendants()) do
		if desc:IsA("SpawnLocation") and desc.Name ~= "LobbySpawn" then
			desc.Enabled = false
		end
	end
	if lobbySpawn and lobbySpawn.Parent then
		lobbySpawn.Enabled = true
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
	highlight.FillTransparency = gameplayEnabled == true and 0.6 or 0.88
	highlight.OutlineColor = highlightColor
	highlight.OutlineTransparency = gameplayEnabled == true and 0 or 0.18
	highlight.Enabled = true
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

local function lockPlayerForDeployment(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not root then return nil end

	local state = {
		Character = character,
		Root = root,
		RootAnchored = root.Anchored,
		AutoRotate = humanoid.AutoRotate,
		Collisions = {},
	}

	-- Survivor select deliberately uses a class-colored outline, but that presentation
	-- treatment should not glow through the capsule during deployment. Keep the same
	-- Highlight instance so gameplay can restore it cleanly after the exit sequence.
	local highlight = character:FindFirstChildOfClass("Highlight")
	if highlight then
		highlight.Enabled = false
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			state.Collisions[descendant] = descendant.CanCollide
			descendant.CanCollide = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end

	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0
	humanoid.Jump = false
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	root.Anchored = true
	deploymentLocks[player] = state
	return state
end

local function restorePlayerAfterDeployment(player)
	local state = deploymentLocks[player]
	deploymentLocks[player] = nil
	if not state then return end

	for basePart, canCollide in pairs(state.Collisions) do
		if basePart and basePart.Parent then
			basePart.CanCollide = canCollide
		end
	end

	if state.Root and state.Root.Parent then
		state.Root.Anchored = state.RootAnchored
		state.Root.AssemblyLinearVelocity = Vector3.zero
		state.Root.AssemblyAngularVelocity = Vector3.zero
	end

	local humanoid = state.Character and state.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = state.AutoRotate
	end
end

local function destroyDeploymentPods()
	if activeDeploymentFolder and activeDeploymentFolder.Parent then
		activeDeploymentFolder:Destroy()
	end
	activeDeploymentFolder = nil
end

local function movePlayersToShowcase()
	local lobbyPlayers = Players:GetPlayers()
	local count = #lobbyPlayers
	for index, p in ipairs(lobbyPlayers) do
		p:SetAttribute("ShowcaseConfirmed", false)
		if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local xOffset = (index - ((count + 1) / 2)) * 6
			local position = SHOWCASE_CENTER + Vector3.new(xOffset, 0, 0)
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
					local forceField = character:FindFirstChildOfClass("ForceField")
					if forceField then forceField:Destroy() end
						if lobbyPhaseVal.Value == "SURVIVOR_SELECT" then
							local playersNow = Players:GetPlayers()
							local index = table.find(playersNow, player) or #playersNow
							local count = math.max(#playersNow, 1)
							local xOffset = (index - ((count + 1) / 2)) * 6
							local position = SHOWCASE_CENTER + Vector3.new(xOffset, 0, 0)
							character:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, -12)))
							giveClassWeaponAndHighlight(player, player:GetAttribute("SelectedClass") or "Gunner", false)
						elseif lobbyPhaseVal.Value == "DEPLOYING" and activeDeploymentFolder then
							local ownerPod = nil
							for _, candidate in ipairs(activeDeploymentFolder:GetChildren()) do
								if candidate:IsA("Model") and candidate:GetAttribute("OwnerUserId") == player.UserId then
									ownerPod = candidate
									break
								end
							end
							if ownerPod then
								lockPlayerForDeployment(player)
								character:PivotTo(ownerPod:GetPivot() * DropPodBuilder.INTERIOR_ROOT_OFFSET)
							else
								clearClassPresentation(player)
								movePlayerToLobbySlot(player)
							end
						else
							clearClassPresentation(player)
							movePlayerToLobbySlot(player)
					end
				end
			end)
	end
end

local function loadPlayerCharacter(player)
	if player.Parent ~= Players then return nil end

	local ok, err = pcall(function()
		player:LoadCharacter()
	end)
	if not ok then
		warn("Failed to load character for " .. player.Name .. ": " .. tostring(err))
		return nil
	end

	local character = player.Character
	if character then
		character:WaitForChild("Humanoid", 10)
		character:WaitForChild("HumanoidRootPart", 10)
	end
	return character
end

Players.PlayerAdded:Connect(function(player)
	if #Players:GetPlayers() > MAX_LOBBY_SLOTS then
		player:Kick("This lobby supports up to four players.")
		return
	end
	assignLobbySlot(player)
	player:SetAttribute("SelectedClass", "Gunner")
	player:SetAttribute("IsReady", false)
	player:SetAttribute("ShowcaseConfirmed", false)
	player:SetAttribute("Kills", 0)
	player:SetAttribute("TotalGoldEarned", 0)
	player.CharacterAdded:Connect(function(char) onCharacterAdded(player, char) end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	else
		task.defer(function()
			loadPlayerCharacter(player)
		end)
	end
end)

for _, p in ipairs(Players:GetPlayers()) do
	assignLobbySlot(p)
	p:SetAttribute("SelectedClass", "Gunner")
	p:SetAttribute("IsReady", false)
	p:SetAttribute("ShowcaseConfirmed", false)
	p:SetAttribute("Kills", 0)
	p:SetAttribute("TotalGoldEarned", 0)
	p.CharacterAdded:Connect(function(char) onCharacterAdded(p, char) end)
	if p.Character then
		onCharacterAdded(p, p.Character)
	else
		task.defer(function()
			loadPlayerCharacter(p)
		end)
	end
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

disbandLobbyRemote.OnServerEvent:Connect(function(player)
	if lobbyPhaseVal.Value ~= "LOBBY" or gameStartedVal.Value then return end
	if player:GetAttribute("LobbySlot") ~= 1 then return end

	for _, squadPlayer in ipairs(Players:GetPlayers()) do
		squadPlayer:SetAttribute("IsReady", false)
		squadPlayer:SetAttribute("ShowcaseConfirmed", false)
		clearClassPresentation(squadPlayer)
		lockPresentationMovement(squadPlayer)
		movePlayerToLobbySlot(squadPlayer)
	end

	disbandLobbyRemote:FireAllClients()
end)

local function returnAllToLobby()
	gameStartedVal.Value = false
	lobbyPhaseVal.Value = "LOBBY"
	chargeVal.Value = 0
	activeVal.Value = false
	completeVal.Value = false
	disableStageSpawns()

	for _, p in ipairs(Players:GetPlayers()) do
		restorePlayerAfterDeployment(p)
		local character = p.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid or humanoid.Health <= 0 then
			loadPlayerCharacter(p)
		end
		resetPlayerStats(p)
		clearClassPresentation(p)
		movePlayerToLobbySlot(p)
	end
	destroyDeploymentPods()

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

local function horizontalUnit(vector, fallback)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.01 then return fallback end
	return flat.Unit
end

local function raycastLandingSurface(basePosition)
	local map = Workspace:FindFirstChild("Map")
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	local include = {}
	if map then table.insert(include, map) end
	if terrain then table.insert(include, terrain) end

	local origin = basePosition + Vector3.new(0, 150, 0)
	if #include > 0 then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = include
		local result = Workspace:Raycast(origin, Vector3.new(0, -340, 0), params)
		if result then return result.Position end
	end

	-- Fallback for prototype maps whose floor parts live directly under Workspace.
	-- Exclude every presentation-only object so the ray cannot land back in the sky
	-- lobby or on one of the falling pods.
	local exclude = {frontendLobby, showcaseScene}
	if activeDeploymentFolder then table.insert(exclude, activeDeploymentFolder) end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(exclude, p.Character) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local result = Workspace:Raycast(origin, Vector3.new(0, -340, 0), params)
	return result and result.Position or basePosition
end

local function landingCFrameForSlot(stageSpawn, index, count)
	local spawnCF = stageSpawn and stageSpawn.CFrame or CFrame.new(0, 10, 0)
	local forward = horizontalUnit(spawnCF.LookVector, Vector3.new(0, 0, -1))
	local right = horizontalUnit(spawnCF.RightVector, Vector3.new(1, 0, 0))
	local spacing = 10.5
	local lateral = (index - ((count + 1) / 2)) * spacing
	local candidate = spawnCF.Position + right * lateral
	local surface = raycastLandingSurface(candidate)
	local center = surface + Vector3.new(0, DropPodBuilder.LANDING_CENTER_HEIGHT, 0)
	return CFrame.lookAt(center, center + forward), surface
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

	-- Do not wake any gameplay systems yet. DEPLOYING is a real intermediary phase:
	-- HUD, timer, enemy director, chests and teleporter all continue to see
	-- GameStarted=false until everyone has landed and exited their pod.
	lobbyPhaseVal.Value = "DEPLOYING"
	-- Give clients a guaranteed chance to black out and release the survivor-select
	-- camera before any character is moved into a pod hundreds of studs above Stage 1.
	-- PREPARE is idempotent with the LobbyPhase listener on the client; the short hold
	-- makes the first visible deployment frame the ground camera, never the pod camera.
	deploymentRemote:FireAllClients("PREPARE")
	task.wait(0.18)
	destroyDeploymentPods()
	activeDeploymentFolder = Instance.new("Folder")
	activeDeploymentFolder.Name = "ByteforceDropPods"
	activeDeploymentFolder.Parent = Workspace

	local stage1Spawn = findStage1Spawn()
	-- Deployment now owns respawns. The old frontend LobbySpawn must be disabled
	-- before characters leave the showcase; otherwise any death/reset during the
	-- cinematic can respawn the operative thousands of studs away in the menu bay.
	if lobbySpawn and lobbySpawn.Parent then
		lobbySpawn.Enabled = false
	end
	if stage1Spawn and stage1Spawn:IsA("SpawnLocation") then
		stage1Spawn.Enabled = true
		-- Spawn nodes are routing metadata, not part of the stage presentation. Hide
		-- the default Roblox pad and remove it from landing raycasts so the capsule
		-- actually settles onto the map/terrain beneath it.
		stage1Spawn.Transparency = 1
		stage1Spawn.CanCollide = false
		stage1Spawn.CanTouch = false
		stage1Spawn.CanQuery = false
	end
	local deployments = {}
	local playerCount = #currentPlayers

	for index, p in ipairs(currentPlayers) do
		if p ~= excludedPlayer and p.Parent == Players then
			local landingCF, surfacePosition = landingCFrameForSlot(stage1Spawn, index, playerCount)
			local landingRotation = landingCF - landingCF.Position
			local rollDirection = index % 2 == 0 and -1 or 1
				local startRotation = landingRotation
					* CFrame.Angles(math.rad(-4.5), math.rad(rollDirection * 1.8), math.rad(rollDirection * 8.5))
			local startCF = CFrame.new(landingCF.Position + Vector3.new(0, DEPLOYMENT_HEIGHT, 0)) * startRotation

					local pod = DropPodBuilder.create("DropPod_" .. tostring(p.UserId), activeDeploymentFolder, p.UserId)
					pod:SetAttribute("LandingPosition", landingCF.Position)
					pod:SetAttribute("LandingSurfacePosition", surfacePosition)
					pod:SetAttribute("LandingForward", landingCF.LookVector)
					pod:SetAttribute("LandingRight", landingCF.RightVector)
					pod:SetAttribute("DeploymentSlot", index)
				pod:PivotTo(startCF)
				DropPodBuilder.setExhaust(pod, true, false)

			local lockState = lockPlayerForDeployment(p)
			if lockState and p.Character then
				p.Character:PivotTo(startCF * DropPodBuilder.INTERIOR_ROOT_OFFSET)
			end

			table.insert(deployments, {
				Player = p,
				Pod = pod,
				LandingCF = landingCF,
				LandingRotation = landingRotation,
				SurfacePosition = surfacePosition,
				RollDirection = rollDirection,
				Braking = false,
			})
		end
	end

	if #deployments == 0 then
		lobbyPhaseVal.Value = "LOBBY"
		destroyDeploymentPods()
		return
	end

	local descentStart = Workspace:GetServerTimeNow() + DEPLOYMENT_LEAD_IN
	deploymentRemote:FireAllClients("BEGIN", descentStart, DEPLOYMENT_DURATION)
	while Workspace:GetServerTimeNow() < descentStart do
		RunService.Heartbeat:Wait()
	end

	local descentFinished = false
	while not descentFinished do
		local now = Workspace:GetServerTimeNow()
		local raw = math.clamp((now - descentStart) / DEPLOYMENT_DURATION, 0, 1)
		descentFinished = raw >= 1

		local height
			if raw < 0.70 then
				-- Start deceptively slow while the pods are still tiny points in the sky,
				-- then build a lot of speed before the terminal braking burn.
				local p = raw / 0.70
				local progress = p ^ 1.55
				height = DEPLOYMENT_HEIGHT + (DEPLOYMENT_BRAKE_HEIGHT - DEPLOYMENT_HEIGHT) * progress
			else
				local p = (raw - 0.70) / 0.30
				local progress = TweenService:GetValue(p, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				height = DEPLOYMENT_BRAKE_HEIGHT * (1 - progress)
			end

		for index, deployment in ipairs(deployments) do
			local pod = deployment.Pod
			if pod and pod.Parent then
					if raw >= 0.69 and not deployment.Braking then
						deployment.Braking = true
						DropPodBuilder.setExhaust(pod, true, true)
					end

					local sway = math.sin(raw * math.pi * 1.9 + index * 0.9) * 1.05 * (1 - raw)
					local forwardSway = math.sin(raw * math.pi * 1.35 + index) * 0.48 * (1 - raw)
				local position = deployment.LandingCF.Position
					+ Vector3.new(0, height, 0)
					+ deployment.LandingCF.RightVector * sway
					+ deployment.LandingCF.LookVector * forwardSway
				local settle = (1 - raw) ^ 1.55
					local pitch = math.rad(-4.5) * settle
					local yaw = math.rad(deployment.RollDirection * 1.8) * settle
					local roll = math.rad(deployment.RollDirection * 8.5) * settle
				local podCF = CFrame.new(position) * deployment.LandingRotation * CFrame.Angles(pitch, yaw, roll)
				pod:PivotTo(podCF)

				local character = deployment.Player.Character
				if character and character.Parent then
					character:PivotTo(podCF * DropPodBuilder.INTERIOR_ROOT_OFFSET)
				end
			end
		end

		if not descentFinished then RunService.Heartbeat:Wait() end
	end

	for _, deployment in ipairs(deployments) do
		if deployment.Pod and deployment.Pod.Parent then
			deployment.Pod:PivotTo(deployment.LandingCF)
			DropPodBuilder.setExhaust(deployment.Pod, false, false)
			DropPodBuilder.emitImpact(deployment.Pod, deployment.SurfacePosition)
		end
		local character = deployment.Player.Character
		if character and character.Parent then
			character:PivotTo(deployment.LandingCF * DropPodBuilder.INTERIOR_ROOT_OFFSET)
		end
	end
	deploymentRemote:FireAllClients("IMPACT", Workspace:GetServerTimeNow())

		-- Let the impact breathe before the hatch blows. The dust cloud and low-angle
		-- camera need a readable beat instead of impact/hatch happening on the same cut.
		task.wait(0.62)
		for _, deployment in ipairs(deployments) do
			DropPodBuilder.playHatchSound(deployment.Pod)
		end
		deploymentRemote:FireAllClients("HATCH", Workspace:GetServerTimeNow())
		for _, deployment in ipairs(deployments) do
			DropPodBuilder.jettisonHatch(deployment.Pod, deployment.RollDirection)
		end
		task.wait(0.72)

		-- Hop the locked presentation character out of the opened pod. Cubic-in forward
		-- motion plus a small vertical arc gives the exit a jump-like burst while keeping
		-- the sequence deterministic across rigs. Normal locomotion resumes after RUN begins.
	local exitStart = os.clock()
		local exitDuration = 0.68
	local exits = {}
	for _, deployment in ipairs(deployments) do
		local character = deployment.Player.Character
		local exitMarker = deployment.Pod and deployment.Pod:FindFirstChild("ExitMarker")
		if character and character.Parent and exitMarker and exitMarker:IsA("BasePart") then
			table.insert(exits, {
				Character = character,
				Start = character:GetPivot(),
				Target = CFrame.lookAt(exitMarker.Position, exitMarker.Position + deployment.Pod:GetPivot().LookVector),
			})
		end
	end

			while true do
				local raw = math.clamp((os.clock() - exitStart) / exitDuration, 0, 1)
				local alpha = TweenService:GetValue(raw, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
				for _, data in ipairs(exits) do
					if data.Character.Parent then
						data.Character:PivotTo(data.Start:Lerp(data.Target, alpha))
					end
				end
		if raw >= 1 then break end
		RunService.Heartbeat:Wait()
	end

	for _, deployment in ipairs(deployments) do
		local p = deployment.Player
		if p.Parent == Players then
			local selectedCls = p:GetAttribute("SelectedClass") or "Gunner"
			giveClassWeaponAndHighlight(p, selectedCls, true)
			restorePlayerAfterDeployment(p)
		end
	end

	if stage1Spawn and stage1Spawn:IsA("SpawnLocation") then
		stage1Spawn.Enabled = true
	end
	lobbyPhaseVal.Value = "RUN"
	gameStartedVal.Value = true
	deploymentRemote:FireAllClients("COMPLETE", Workspace:GetServerTimeNow())
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
	deploymentLocks[leavingPlayer] = nil
	task.defer(function()
		if lobbyPhaseVal.Value == "LOBBY" then
			beginSurvivorSelect(leavingPlayer)
		elseif lobbyPhaseVal.Value == "SURVIVOR_SELECT" and not gameStartedVal.Value then
			tryStartRun(leavingPlayer)
		end
	end)
end)

print("SUCCESS: LobbyManager running with instantaneous client UI sync!")
