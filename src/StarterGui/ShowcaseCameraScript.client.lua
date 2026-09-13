local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local showcaseRemote = ReplicatedStorage:WaitForChild("PlayShowcaseRemote", 10)
local confirmDeployRemote = ReplicatedStorage:WaitForChild("ConfirmDeployRemote", 10)

local function getOrCreate(className, name, parent, properties)
	local item = parent:FindFirstChild(name)
	if not item then item = Instance.new(className); item.Name = name; item.Parent = parent end
	if properties then for k, v in pairs(properties) do item[k] = v end end
	return item
end

local screenGui = player:WaitForChild("PlayerGui"):WaitForChild("LobbyUI")

local showcaseCard = getOrCreate("Frame", "ShowcaseCard", screenGui, {
	Size = UDim2.new(0, 520, 0, 160), Position = UDim2.new(0.5, -260, 0.75, -80),
	BackgroundColor3 = Color3.fromRGB(15, 18, 25), BackgroundTransparency = 0.15, BorderSizePixel = 3, BorderColor3 = Color3.fromRGB(0, 180, 255), Visible = false, ZIndex = 20
})

local showcaseTitle = getOrCreate("TextLabel", "ShowcaseTitle", showcaseCard, {
	Size = UDim2.new(1, 0, 0, 35), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 220, 50), TextScaled = true, Font = Enum.Font.SourceSansBold, Text = "SURVIVOR SHOWCASE", ZIndex = 21
})

local showcaseDesc = getOrCreate("TextLabel", "ShowcaseDesc", showcaseCard, {
	Size = UDim2.new(1, -20, 0, 65), Position = UDim2.new(0, 10, 0, 38), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 255, 255), TextScaled = true, Font = Enum.Font.SourceSans, Text = "Ability Info", ZIndex = 21
})

local deployBtn = getOrCreate("TextButton", "DeployBtn", showcaseCard, {
	Size = UDim2.new(0, 240, 0, 40), Position = UDim2.new(0.5, -120, 1, -48), BackgroundColor3 = Color3.fromRGB(0, 180, 80), TextColor3 = Color3.fromRGB(255, 255, 255), TextScaled = true, Font = Enum.Font.SourceSansBold, Text = "READY TO DEPLOY ▶", Visible = false, ZIndex = 22
})

-- VISUAL DEMO HELPERS
local function demoBeam(rootPart, color, thickness)
	local beam = Instance.new("Part")
	beam.Size = Vector3.new(thickness, thickness, 30); beam.CFrame = rootPart.CFrame * CFrame.new(0, 1, -16)
	beam.BrickColor = BrickColor.new(color); beam.Material = Enum.Material.Neon; beam.Anchored = true; beam.CanCollide = false; beam.Parent = workspace
	local sound = Instance.new("Sound"); sound.SoundId = "rbxassetid://260430079"; sound.Volume = 0.5; sound.Parent = beam; sound:Play()
	game:GetService("Debris"):AddItem(beam, 0.25)
end

local function demoPunch(rootPart)
	rootPart.AssemblyLinearVelocity = rootPart.CFrame.LookVector * 25
	local ring = Instance.new("Part")
	ring.Size = Vector3.new(3, 3, 3); ring.CFrame = rootPart.CFrame * CFrame.new(0, 0, -3); ring.Shape = Enum.PartType.Ball; ring.Material = Enum.Material.Neon; ring.BrickColor = BrickColor.new("Deep orange"); ring.Anchored = true; ring.CanCollide = false; ring.Parent = workspace
	local sound = Instance.new("Sound"); sound.SoundId = "rbxassetid://130113322"; sound.Volume = 0.6; sound.Parent = ring; sound:Play()
	game:GetService("Debris"):AddItem(ring, 0.2)
end

local function demoWebLine(rootPart)
	local line = Instance.new("Part")
	line.Size = Vector3.new(0.3, 0.3, 25); line.CFrame = rootPart.CFrame * CFrame.new(0, 1, -12.5)
	line.BrickColor = BrickColor.new("White"); line.Material = Enum.Material.Neon; line.Anchored = true; line.CanCollide = false; line.Parent = workspace
	local sound = Instance.new("Sound"); sound.SoundId = "rbxassetid://12222170"; sound.Volume = 0.5; sound.Parent = line; sound:Play()
	game:GetService("Debris"):AddItem(line, 0.3)
end

local function demoDash(rootPart)
	task.spawn(function()
		local dashDir = rootPart.CFrame.LookVector * 45
		for i = 1, 5 do rootPart.AssemblyLinearVelocity = dashDir; task.wait(0.03) end
	end)
end

local function demoExplosion(rootPart)
	local targetPos = rootPart.Position + (rootPart.CFrame.LookVector * 15)
	local explosion = Instance.new("Explosion")
	explosion.Position = targetPos; explosion.BlastRadius = 10; explosion.BlastPressure = 0; explosion.Parent = workspace
end

local CLASS_SHOWCASES = {
	Gunner = {
		M1 = "Auto Laser Cannon: Fires rapid energy rounds to melt malware.",
		M2 = "Heavy Piercing Shot: High-damage charged blast that pierces heavy enemies.",
		Shift = "Tactical Dash: Sustained roll to dodge heavy attacks.",
		R = "Orbital Strike: High-yield explosion called down at crosshair target."
	},
	Ranger = {
		M1 = "Seeking Energy Arrows: Rapid homing energy arrows with long range.",
		M2 = "Piercing Arrow: Charged energy arrow dealing 45 Damage.",
		Shift = "Blink Step: Instant 35-stud teleport forward.",
		R = "Arrow Rain: Calls down a barrage of energy arrows dealing 120 AoE Damage."
	},
	Brawler = {
		M1 = "Iron Fist Combo: Fast 3-hit martial arts melee combo.",
		M2 = "Mountain Splitter: Explosive charging palm strike (60 Dmg + Shockwave).",
		Shift = "Gale Flash Step: High-speed martial arts dash forward.",
		R = "Eight-Pole Spirit Slam: Leaps and slams down with a 140 AoE Martial Shockwave!"
	},
	Weaver = {
		M1 = "Web Shooters: Rapid white web energy rounds dealing 14 Damage.",
		M2 = "Web Snare: Heavy web cluster dealing 45 Dmg + Pins enemy for 1.5s!",
		Shift = "Grapple Zip: Web line that zips character forward at high speed.",
		R = "Web Slam: Pulls nearby enemies in and triggers a 130 AoE Web Burst!"
	}
}

-- FRONT-FACING CAMERA SHOWCASE ORBIT
local function playShowcaseCutscene()
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local root = char.HumanoidRootPart

	camera.CameraType = Enum.CameraType.Scriptable

	-- FRONT-FACING CAMERA ORBIT (Pans across the FRONT of the character)
	local startPos = root.CFrame * Vector3.new(-8, 2, -12)
	local endPos = root.CFrame * Vector3.new(8, 2, -10)

	camera.CFrame = CFrame.new(startPos, root.Position + Vector3.new(0, 1.5, 0))

	local tweenInfo = TweenInfo.new(16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(camera, tweenInfo, { CFrame = CFrame.new(endPos, root.Position + Vector3.new(0, 1.5, 0)) })
	tween:Play()

	showcaseCard.Visible = true; deployBtn.Visible = false
	local chosenClass = player:GetAttribute("SelectedClass") or "Gunner"
	local data = CLASS_SHOWCASES[chosenClass] or CLASS_SHOWCASES.Gunner

	showcaseTitle.Text = "DEPLOYING: " .. chosenClass:upper()
	showcaseDesc.Text = "Class Overview: Loadout verified for Sector-0 deployment."
	task.wait(3)

	showcaseTitle.Text = "BASIC MOVEMENT & CONTROLS"
	showcaseDesc.Text = "WASD / Joystick: Navigate Terrain\nSPACEBAR: Jump / High Ground Traversal"
	task.wait(3)

	showcaseTitle.Text = "PRIMARY ATTACK [M1 / HOLD CLICK]"
	showcaseDesc.Text = data.M1
	if chosenClass == "Brawler" then demoPunch(root) elseif chosenClass == "Weaver" then demoWebLine(root) else demoBeam(root, "Bright green", 0.4) end
	task.wait(3)

	showcaseTitle.Text = "SECONDARY ATTACK [M2 / RIGHT CLICK]"
	showcaseDesc.Text = data.M2
	if chosenClass == "Brawler" then demoPunch(root) elseif chosenClass == "Weaver" then demoWebLine(root) else demoBeam(root, "Bright yellow", 1.2) end
	task.wait(3)

	showcaseTitle.Text = "UTILITY ABILITY [LEFT SHIFT]"
	showcaseDesc.Text = data.Shift
	demoDash(root)
	task.wait(3)

	showcaseTitle.Text = "SPECIAL ABILITY [R KEY]"
	showcaseDesc.Text = data.R
	demoExplosion(root)
	task.wait(3)

	showcaseTitle.Text = "LOADOUT VERIFIED"
	showcaseDesc.Text = "Click DEPLOY when you are ready to drop into Sector-0!"
	deployBtn.Visible = true; deployBtn.Text = "DEPLOY ▶ (WAITING...)"
end

deployBtn.MouseButton1Click:Connect(function()
	deployBtn.Text = "WAITING FOR TEAM..."
	deployBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
	if confirmDeployRemote then confirmDeployRemote:FireServer() end
end)

if showcaseRemote then showcaseRemote.OnClientEvent:Connect(playShowcaseCutscene) end

local gameStartedVal = ReplicatedStorage:WaitForChild("GameStarted", 10)
if gameStartedVal then
	gameStartedVal.Changed:Connect(function(started)
		if started then
			showcaseCard.Visible = false; deployBtn.Visible = false
			camera.CameraType = Enum.CameraType.Custom
		end
	end)
end