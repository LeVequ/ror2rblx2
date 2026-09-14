local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local DropPodBuilder = {}

DropPodBuilder.LANDING_CENTER_HEIGHT = 4.7
DropPodBuilder.INTERIOR_ROOT_OFFSET = CFrame.new(0, 1.15, -0.1)

local COLORS = {
	Dark = Color3.fromRGB(17, 23, 28),
	Metal = Color3.fromRGB(43, 53, 59),
	Armor = Color3.fromRGB(66, 78, 84),
	Edge = Color3.fromRGB(91, 105, 112),
	Blue = Color3.fromRGB(45, 126, 153),
	Cyan = Color3.fromRGB(102, 211, 232),
	Amber = Color3.fromRGB(232, 157, 63),
}

local function part(parent, name, size, cf, color, material, transparency, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color or COLORS.Metal
	p.Material = material or Enum.Material.Metal
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = true
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

local function wedge(parent, name, size, cf, color, material, transparency)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color or COLORS.Metal
	p.Material = material or Enum.Material.Metal
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = true
	p.Parent = parent
	return p
end

local function cylinder(parent, name, height, diameter, cf, color, material, transparency)
	return part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		transparency,
		Enum.PartType.Cylinder
	)
end

local function addPointLight(parent, name, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Name = name
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = parent
	return light
end

local function addExhaustEmitter(parent, name, rate, speed, lifetime, size)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Enabled = false
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(speed * 0.82, speed * 1.15)
	emitter.Lifetime = NumberRange.new(lifetime * 0.8, lifetime * 1.2)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-80, 80)
	emitter.LightEmission = 0.72
	emitter.LightInfluence = 0.15
	emitter.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(196, 239, 255)),
		ColorSequenceKeypoint.new(0.22, Color3.fromRGB(96, 197, 229)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 72, 82)),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.35, 0.28),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.55),
		NumberSequenceKeypoint.new(0.4, size),
		NumberSequenceKeypoint.new(1, size * 1.65),
	})
	emitter.Acceleration = Vector3.new(0, -18, 0)
	emitter.Parent = parent
	return emitter
end

function DropPodBuilder.create(name, parent, ownerUserId)
	local model = Instance.new("Model")
	model.Name = name or "ByteforceDropPod"
	model:SetAttribute("OwnerUserId", ownerUserId or 0)
	model:SetAttribute("DeploymentPod", true)
	model.Parent = parent

	local root = part(model, "Root", Vector3.new(1, 1, 1), CFrame.new(), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	root.CastShadow = false
	model.PrimaryPart = root

	-- Central pressure hull. The boxy Roblox geometry is broken into layered armor
	-- and tapered pieces so the silhouette reads like a compact orbital capsule.
	part(model, "HullCore", Vector3.new(5.8, 7.6, 5.4), CFrame.new(0, 1.05, 0), COLORS.Metal, Enum.Material.Metal)
	part(model, "HullInset", Vector3.new(4.8, 6.7, 5.62), CFrame.new(0, 0.9, 0.08), COLORS.Dark, Enum.Material.Metal)
	part(model, "UpperBand", Vector3.new(6.3, 0.82, 5.7), CFrame.new(0, 4.05, 0), COLORS.Blue, Enum.Material.Metal)
	part(model, "LowerBand", Vector3.new(6.15, 0.58, 5.62), CFrame.new(0, -2.08, 0), COLORS.Blue, Enum.Material.Metal)

	-- Tapered shoulders / roof cap.
	wedge(model, "ShoulderL", Vector3.new(1.25, 5.5, 5.6), CFrame.new(-3.25, 1.6, 0) * CFrame.Angles(0, math.rad(90), math.rad(-8)), COLORS.Armor)
	wedge(model, "ShoulderR", Vector3.new(1.25, 5.5, 5.6), CFrame.new(3.25, 1.6, 0) * CFrame.Angles(0, math.rad(-90), math.rad(8)), COLORS.Armor)
	part(model, "RoofCap", Vector3.new(4.7, 1.25, 4.7), CFrame.new(0, 5.35, 0.15), COLORS.Armor, Enum.Material.Metal)
	wedge(model, "RoofFront", Vector3.new(4.75, 1.7, 1.45), CFrame.new(0, 4.95, -2.55) * CFrame.Angles(math.rad(90), 0, math.rad(180)), COLORS.Edge)
	wedge(model, "RoofRear", Vector3.new(4.75, 1.7, 1.45), CFrame.new(0, 4.95, 2.55) * CFrame.Angles(math.rad(-90), 0, 0), COLORS.Armor)

	-- Lower skirt and landing feet.
	part(model, "LowerSkirt", Vector3.new(5.15, 1.25, 4.75), CFrame.new(0, -3.0, 0.2), COLORS.Dark, Enum.Material.Metal)
	part(model, "FootL", Vector3.new(2.25, 0.65, 2.45), CFrame.new(-2.05, -4.16, 0.35) * CFrame.Angles(0, math.rad(-5), 0), COLORS.Dark, Enum.Material.Metal)
	part(model, "FootR", Vector3.new(2.25, 0.65, 2.45), CFrame.new(2.05, -4.16, 0.35) * CFrame.Angles(0, math.rad(5), 0), COLORS.Dark, Enum.Material.Metal)
	part(model, "FootBraceL", Vector3.new(0.52, 1.9, 0.62), CFrame.new(-2.05, -3.38, 0.35) * CFrame.Angles(0, 0, math.rad(-8)), COLORS.Edge)
	part(model, "FootBraceR", Vector3.new(0.52, 1.9, 0.62), CFrame.new(2.05, -3.38, 0.35) * CFrame.Angles(0, 0, math.rad(8)), COLORS.Edge)

	-- Side armor rails and readable cyan status strips.
	part(model, "RailL", Vector3.new(0.52, 6.4, 0.85), CFrame.new(-3.2, 0.7, 1.45) * CFrame.Angles(0, 0, math.rad(-4)), COLORS.Edge)
	part(model, "RailR", Vector3.new(0.52, 6.4, 0.85), CFrame.new(3.2, 0.7, 1.45) * CFrame.Angles(0, 0, math.rad(4)), COLORS.Edge)
	local statusL = part(model, "StatusL", Vector3.new(0.24, 2.9, 0.18), CFrame.new(-3.25, 1.05, -1.75), COLORS.Cyan, Enum.Material.Neon, 0.08)
	local statusR = part(model, "StatusR", Vector3.new(0.24, 2.9, 0.18), CFrame.new(3.25, 1.05, -1.75), COLORS.Cyan, Enum.Material.Neon, 0.08)
	addPointLight(statusL, "StatusGlow", COLORS.Cyan, 1.25, 11)
	addPointLight(statusR, "StatusGlow", COLORS.Cyan, 1.25, 11)

	local warning = part(model, "WarningLamp", Vector3.new(0.8, 0.38, 0.25), CFrame.new(2.15, 4.58, -2.52), COLORS.Amber, Enum.Material.Neon, 0.04)
	addPointLight(warning, "WarningGlow", COLORS.Amber, 1.6, 9)

	-- Hatch is its own nested model so the server can jettison it without having to
	-- individually tween every decorative layer.
	local hatch = Instance.new("Model")
	hatch.Name = "HatchAssembly"
	hatch.Parent = model
	local hatchRoot = part(hatch, "HatchRoot", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0.75, -2.98), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	hatchRoot.CastShadow = false
	hatch.PrimaryPart = hatchRoot
	part(hatch, "HatchFrame", Vector3.new(4.9, 6.7, 0.32), CFrame.new(0, 0.75, -3.04), COLORS.Edge, Enum.Material.Metal)
	part(hatch, "HatchPlate", Vector3.new(4.35, 6.05, 0.42), CFrame.new(0, 0.72, -3.27), COLORS.Dark, Enum.Material.Metal)
	part(hatch, "HatchInset", Vector3.new(3.1, 4.45, 0.22), CFrame.new(0, 0.72, -3.51), COLORS.Metal, Enum.Material.Metal)
	part(hatch, "HatchBand", Vector3.new(3.65, 0.45, 0.2), CFrame.new(0, 2.05, -3.64), COLORS.Blue, Enum.Material.Metal)
	part(hatch, "HatchStripe", Vector3.new(2.5, 0.16, 0.13), CFrame.new(0, 2.05, -3.77), COLORS.Cyan, Enum.Material.Neon, 0.08)
	part(hatch, "HatchLatchL", Vector3.new(0.38, 1.05, 0.2), CFrame.new(-1.68, 0.68, -3.62), COLORS.Edge, Enum.Material.Metal)
	part(hatch, "HatchLatchR", Vector3.new(0.38, 1.05, 0.2), CFrame.new(1.68, 0.68, -3.62), COLORS.Edge, Enum.Material.Metal)

	-- Twin underslung thrusters. They are deliberately inset so the exhaust is seen
	-- during the chase shot without making the pod look like a conventional rocket.
	for index, x in ipairs({-1.55, 1.55}) do
		local thruster = cylinder(model, "Thruster" .. index, 1.15, 1.35, CFrame.new(x, -3.85, 1.0), COLORS.Edge, Enum.Material.Metal)
		local glow = cylinder(model, "ThrusterGlow" .. index, 0.22, 0.98, CFrame.new(x, -4.46, 1.0), COLORS.Cyan, Enum.Material.Neon, 0.12)
		glow.CastShadow = false
		addPointLight(glow, "ThrusterLight", COLORS.Cyan, 0, 13)

		local attachment = Instance.new("Attachment")
		attachment.Name = "ExhaustAttachment"
		attachment.CFrame = CFrame.Angles(0, 0, math.rad(180))
		attachment.Parent = glow
		addExhaustEmitter(attachment, "Exhaust", 72, 18, 0.42, 0.92)
	end

	-- Exit marker is invisible and follows the model. At rest this places the root
	-- just outside the hatch with the character's feet on the landing surface.
	local exit = part(model, "ExitMarker", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, -1.55, -8.0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	exit.CastShadow = false

	local impactAnchor = part(model, "ImpactAnchor", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, -4.58, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	impactAnchor.CastShadow = false
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "ImpactDust"
	dust.Enabled = false
	dust.Rate = 0
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Speed = NumberRange.new(13, 24)
	dust.Lifetime = NumberRange.new(0.55, 1.15)
	dust.SpreadAngle = Vector2.new(82, 82)
	dust.Rotation = NumberRange.new(0, 360)
	dust.RotSpeed = NumberRange.new(-95, 95)
	dust.Acceleration = Vector3.new(0, -22, 0)
	dust.LightInfluence = 0.65
	dust.Color = ColorSequence.new(Color3.fromRGB(111, 106, 98), Color3.fromRGB(53, 54, 54))
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.45, 0.42),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.5, 2.1),
		NumberSequenceKeypoint.new(1, 3.4),
	})
	dust.Parent = impactAnchor

	local impactSound = Instance.new("Sound")
	impactSound.Name = "ImpactSound"
	impactSound.SoundId = "rbxassetid://130113322"
	impactSound.Volume = 0.72
	impactSound.PlaybackSpeed = 0.78
	impactSound.RollOffMaxDistance = 115
	impactSound.Parent = impactAnchor

	local hatchSound = Instance.new("Sound")
	hatchSound.Name = "HatchSound"
	hatchSound.SoundId = "rbxassetid://130113322"
	hatchSound.Volume = 0.42
	hatchSound.PlaybackSpeed = 1.18
	hatchSound.RollOffMaxDistance = 80
	hatchSound.Parent = hatchRoot

	return model
end

function DropPodBuilder.setExhaust(model, enabled, braking)
	if not model then return end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") and descendant.Name == "Exhaust" then
			descendant.Enabled = enabled
			descendant.Rate = braking and 190 or 62
			descendant.Speed = braking and NumberRange.new(28, 39) or NumberRange.new(14, 21)
			descendant.Lifetime = braking and NumberRange.new(0.55, 0.85) or NumberRange.new(0.32, 0.52)
		elseif descendant:IsA("PointLight") and descendant.Name == "ThrusterLight" then
			descendant.Brightness = enabled and (braking and 7.5 or 1.8) or 0
			descendant.Range = braking and 30 or 12
		end
	end
end

function DropPodBuilder.jettisonHatch(model, sideDirection)
	local hatch = model and model:FindFirstChild("HatchAssembly")
	if not hatch or not hatch:IsA("Model") then return nil end
	local root = hatch.PrimaryPart or hatch:FindFirstChild("HatchRoot")
	if not root or not root:IsA("BasePart") then return nil end

	-- The hatch was built from individually anchored presentation pieces. Weld it into
	-- one physical assembly before releasing the anchors so gravity can take over.
	for _, piece in ipairs(hatch:GetDescendants()) do
		if piece:IsA("BasePart") and piece ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "HatchJettisonWeld"
			weld.Part0 = root
			weld.Part1 = piece
			weld.Parent = root
		end
	end

	-- Detach it from the pod hierarchy before enabling physics. Only the broad plate
	-- collides, which lets the door tumble/bounce on terrain without becoming a cage
	-- of small collision boxes around the exiting player.
	local podParent = model.Parent
	hatch.Parent = podParent or workspace
	for _, piece in ipairs(hatch:GetDescendants()) do
		if piece:IsA("BasePart") then
			piece.Anchored = false
			piece.CanCollide = piece.Name == "HatchPlate"
			piece.CanTouch = false
			piece.CanQuery = false
			piece.Massless = piece ~= root and piece.Name ~= "HatchPlate"
		end
	end
	root.Anchored = false
	root.CanCollide = false
	root.Massless = false

	local podCF = model:GetPivot()
	local side = (sideDirection or 1) >= 0 and 1 or -1
	root.AssemblyLinearVelocity = podCF.LookVector * 46
		+ podCF.RightVector * (7 * side)
		+ Vector3.new(0, 13, 0)
	root.AssemblyAngularVelocity = Vector3.new(5.5 * side, 8.5, -7 * side)
	pcall(function() root:SetNetworkOwner(nil) end)

	Debris:AddItem(hatch, 9)
	return hatch
end

function DropPodBuilder.emitImpact(model, worldSurfacePosition)
	if not model then return end
	local impactAnchor = model:FindFirstChild("ImpactAnchor")
	if impactAnchor then
		local emitter = impactAnchor:FindFirstChild("ImpactDust")
		if emitter and emitter:IsA("ParticleEmitter") then emitter:Emit(38) end
		local sound = impactAnchor:FindFirstChild("ImpactSound")
		if sound and sound:IsA("Sound") then sound:Play() end
	end

	local ring = Instance.new("Part")
	ring.Name = "DropPodImpactRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.12, 2.5, 2.5)
	ring.CFrame = CFrame.new(worldSurfacePosition + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(89, 91, 88)
	ring.Material = Enum.Material.SmoothPlastic
	ring.Transparency = 0.42
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Parent = workspace

	local ringTween = TweenService:Create(
		ring,
		TweenInfo.new(0.48, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.12, 18, 18), Transparency = 1}
	)
	ringTween:Play()
	Debris:AddItem(ring, 0.55)

	for index = 1, 8 do
		local angle = math.rad((index - 1) * 45 + math.random(-11, 11))
		local debris = Instance.new("Part")
		debris.Name = "DropPodImpactDebris"
		debris.Size = Vector3.new(0.22 + math.random() * 0.28, 0.22 + math.random() * 0.42, 0.22 + math.random() * 0.3)
		debris.Position = worldSurfacePosition + Vector3.new(math.cos(angle) * 1.8, 0.35, math.sin(angle) * 1.8)
		debris.Color = Color3.fromRGB(68, 68, 65)
		debris.Material = Enum.Material.Slate
		debris.Anchored = false
		debris.CanCollide = false
		debris.CanTouch = false
		debris.CanQuery = false
		debris.CastShadow = true
		debris.AssemblyLinearVelocity = Vector3.new(math.cos(angle) * math.random(10, 17), math.random(9, 15), math.sin(angle) * math.random(10, 17))
		debris.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
		debris.Parent = workspace
		Debris:AddItem(debris, 1.2)
	end
end

function DropPodBuilder.playHatchSound(model)
	local hatch = model and model:FindFirstChild("HatchAssembly")
	local hatchRoot = hatch and hatch:FindFirstChild("HatchRoot")
	local sound = hatchRoot and hatchRoot:FindFirstChild("HatchSound")
	if sound and sound:IsA("Sound") then sound:Play() end
end

return DropPodBuilder
