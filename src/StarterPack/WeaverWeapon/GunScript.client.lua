local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local tool = script.Parent
local player = Players.LocalPlayer

local isHoldingM1 = false
local isFiringLoopActive = false
local isGrappling = false
local grappleLine = nil

local m2Cooldown = 4; local shiftCooldown = 3; local rCooldown = 9
local lastM1 = 0; local lastM2 = 0; local lastShift = 0; local lastR = 0

local function playSound(soundId, vol)
	local handle = tool:FindFirstChild("Handle")
	if handle then
		local sound = Instance.new("Sound"); sound.SoundId = soundId; sound.Volume = vol or 0.4; sound.Parent = handle; sound:Play()
		game:GetService("Debris"):AddItem(sound, 2)
	end
end

local function isValidEnemy(model)
	if not model then return false end
	if Players:GetPlayerFromCharacter(model) then return false end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

local function createWebLine(startPos, endPos, thickness, colorName)
	local dist = (endPos - startPos).Magnitude
	if dist <= 0 then return end
	local line = Instance.new("Part")
	line.Size = Vector3.new(thickness, thickness, dist); line.CFrame = CFrame.new(startPos, endPos) * CFrame.new(0, 0, -dist/2)
	line.BrickColor = BrickColor.new(colorName or "White"); line.Material = Enum.Material.Neon; line.Anchored = true; line.CanCollide = false; line.Parent = workspace
	task.spawn(function()
		for i = 1, 5 do line.Transparency = i / 5; task.wait(0.03) end
		line:Destroy()
	end)
end

local function triggerHUDCooldown(keyName, cooldownTime)
	local hud = player.PlayerGui:FindFirstChild("HUD")
	if hud and hud:FindFirstChild("AbilityBar") then
		local skillBox = hud.AbilityBar:FindFirstChild("Skill_" .. keyName)
		if skillBox and skillBox:FindFirstChild("CooldownLabel") then
			local label = skillBox.CooldownLabel; label.Visible = true
			task.spawn(function()
				for i = cooldownTime, 1, -1 do label.Text = tostring(i) .. "s"; task.wait(1) end
				label.Visible = false
			end)
		end
	end
end

local function fireWebShooter()
	local m1Cooldown = 0.20
	local now = tick()
	if now - lastM1 < m1Cooldown then return m1Cooldown - (now - lastM1) end
	lastM1 = now

	playSound("rbxassetid://12222170", 0.3)
	local handle = tool:FindFirstChild("Handle")
	local startPos = handle and handle.Position or (player.Character.HumanoidRootPart.Position + Vector3.new(0, 1.5, 0))
	local mouse = player:GetMouse()
	local targetPos = mouse.Hit and mouse.Hit.Position or (startPos + player.Character.HumanoidRootPart.CFrame.LookVector * 100)

	createWebLine(startPos, targetPos, 0.3, "White")

	local target = mouse.Target
	if target then
		local model = target:FindFirstAncestorOfClass("Model")
		if isValidEnemy(model) then
			model:FindFirstChildOfClass("Humanoid"):TakeDamage(14)
		end
	end
	return m1Cooldown
end

tool.Activated:Connect(function()
	isHoldingM1 = true
	if isFiringLoopActive then return end
	isFiringLoopActive = true
	task.spawn(function()
		while isHoldingM1 and tool.Parent == player.Character do
			local cooldown = fireWebShooter()
			task.wait(cooldown)
		end
		isFiringLoopActive = false
	end)
end)

tool.Deactivated:Connect(function() isHoldingM1 = false end)
tool.Unequipped:Connect(function()
	isHoldingM1 = false; isFiringLoopActive = false; isGrappling = false
	if grappleLine then grappleLine:Destroy(); grappleLine = nil end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or tool.Parent ~= player.Character then return end
	local now = tick()
	local mouse = player:GetMouse()
	local char = player.Character
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")

	-- M2: WEB SNARE
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		if now - lastM2 >= m2Cooldown then
			lastM2 = now; triggerHUDCooldown("M2", m2Cooldown); playSound("rbxassetid://130113322", 0.5)
			local startPos = rootPart.Position + Vector3.new(0, 1.5, 0)
			local targetPos = mouse.Hit and mouse.Hit.Position or (startPos + rootPart.CFrame.LookVector * 120)
			createWebLine(startPos, targetPos, 1.2, "Institutional white")

			local target = mouse.Target
			if target then
				local model = target:FindFirstAncestorOfClass("Model")
				if isValidEnemy(model) then
					local hum = model:FindFirstChildOfClass("Humanoid")
					hum:TakeDamage(45)
					local origSpeed = hum.WalkSpeed
					hum.WalkSpeed = 0
					task.delay(1.5, function() pcall(function() if hum then hum.WalkSpeed = origSpeed end end) end)
				end
			end
		end

		-- SHIFT: LOADER STYLE SWINGING GRAPPLE
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		if now - lastShift >= shiftCooldown and not isGrappling then
			local hitPos = mouse.Hit and mouse.Hit.Position
			if hitPos and rootPart then
				local dist = (hitPos - rootPart.Position).Magnitude
				if dist <= 180 then
					lastShift = now; triggerHUDCooldown("SHIFT", shiftCooldown); playSound("rbxassetid://12222170", 0.6)

					isGrappling = true
					local latchPos = hitPos

					grappleLine = Instance.new("Part")
					grappleLine.Name = "WebGrappleLine"; grappleLine.BrickColor = BrickColor.new("White"); grappleLine.Material = Enum.Material.Neon; grappleLine.Anchored = true; grappleLine.CanCollide = false; grappleLine.Parent = workspace

					task.spawn(function()
						while isGrappling and tool.Parent == char and rootPart do
							local currentDist = (latchPos - rootPart.Position).Magnitude
							if currentDist <= 6 or currentDist > 220 then break end

							grappleLine.Size = Vector3.new(0.3, 0.3, currentDist)
							grappleLine.CFrame = CFrame.new(rootPart.Position, latchPos) * CFrame.new(0, 0, -currentDist/2)

							local pullDir = (latchPos - rootPart.Position).Unit
							local targetVel = pullDir * 125 + Vector3.new(0, 10, 0)
							rootPart.AssemblyLinearVelocity = rootPart.AssemblyLinearVelocity:Lerp(targetVel, 0.25)

							task.wait(0.03)
						end
						isGrappling = false
						if grappleLine then grappleLine:Destroy(); grappleLine = nil end
					end)
				end
			end
		end

		-- R: WEB SLAM
	elseif input.KeyCode == Enum.KeyCode.R then
		if now - lastR >= rCooldown then
			lastR = now; triggerHUDCooldown("R", rCooldown); playSound("rbxassetid://130113322", 0.8)
			if rootPart then
				local explosion = Instance.new("Explosion")
				explosion.Position = rootPart.Position; explosion.BlastRadius = 20; explosion.BlastPressure = 0; explosion.Parent = workspace
				for _, obj in ipairs(workspace:GetChildren()) do
					if isValidEnemy(obj) and obj:FindFirstChild("HumanoidRootPart") then
						local eRoot = obj.HumanoidRootPart
						if (eRoot.Position - rootPart.Position).Magnitude <= 22 then
							eRoot.AssemblyLinearVelocity = (rootPart.Position - eRoot.Position).Unit * 60 + Vector3.new(0, 15, 0)
							obj:FindFirstChildOfClass("Humanoid"):TakeDamage(130)
						end
					end
				end
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		isGrappling = false
		if grappleLine then grappleLine:Destroy(); grappleLine = nil end
	end
end)