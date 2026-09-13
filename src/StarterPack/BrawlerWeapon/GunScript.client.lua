local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local tool = script.Parent
local player = Players.LocalPlayer

local isHoldingM1 = false
local isFiringLoopActive = false

local m2Cooldown = 4
local shiftCooldown = 3
local rCooldown = 9

local lastM1 = 0; local lastM2 = 0; lastShift = 0; lastR = 0

local function playSound(soundId, vol)
	local handle = tool:FindFirstChild("Handle")
	if handle then
		local sound = Instance.new("Sound")
		sound.SoundId = soundId; sound.Volume = vol or 0.4; sound.Parent = handle; sound:Play()
		game:GetService("Debris"):AddItem(sound, 2)
	end
end

local function triggerHUDCooldown(keyName, cooldownTime)
	local hud = player.PlayerGui:FindFirstChild("HUD")
	if hud and hud:FindFirstChild("AbilityBar") then
		local skillBox = hud.AbilityBar:FindFirstChild("Skill_" .. keyName)
		if skillBox and skillBox:FindFirstChild("CooldownLabel") then
			local label = skillBox.CooldownLabel
			label.Visible = true
			task.spawn(function()
				for i = cooldownTime, 1, -1 do label.Text = tostring(i) .. "s"; task.wait(1) end
				label.Visible = false
			end)
		end
	end
end

-- BRAWLER VISUAL PARTICLE HELPERS
local function createPunchFlash(pos, colorName)
	local flash = Instance.new("Part")
	flash.Size = Vector3.new(2.5, 2.5, 2.5)
	flash.CFrame = CFrame.new(pos)
	flash.Shape = Enum.PartType.Ball
	flash.BrickColor = BrickColor.new(colorName or "Deep orange")
	flash.Material = Enum.Material.Neon
	flash.Anchored = true; flash.CanCollide = false; flash.Parent = workspace

	task.spawn(function()
		for i = 1, 6 do
			flash.Size = flash.Size + Vector3.new(0.5, 0.5, 0.5)
			flash.Transparency = i / 6
			task.wait(0.02)
		end
		flash:Destroy()
	end)
end

-- BRAWLER M1: IRON FIST COMBO
local function executeIronFistCombo()
	local m1Cooldown = 0.25
	local now = tick()
	if now - lastM1 < m1Cooldown then return m1Cooldown - (now - lastM1) end
	lastM1 = now

	playSound("rbxassetid://130113322", 0.4)

	local char = player.Character
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")

	if rootPart then
		rootPart.AssemblyLinearVelocity = rootPart.CFrame.LookVector * 25 + Vector3.new(0, 2, 0)
		local strikePos = rootPart.CFrame * CFrame.new(0, 0, -4)
		createPunchFlash(strikePos.Position, "Deep orange")

		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:FindFirstChild("EnemyAI") and obj ~= char and obj:FindFirstChild("HumanoidRootPart") then
				local dist = (obj.HumanoidRootPart.Position - rootPart.Position).Magnitude
				local dot = rootPart.CFrame.LookVector:Dot((obj.HumanoidRootPart.Position - rootPart.Position).Unit)

				if dist <= 9 and dot > 0.2 then
					local hum = obj:FindFirstChildOfClass("Humanoid")
					if hum then
						hum:TakeDamage(18)
						createPunchFlash(obj.HumanoidRootPart.Position, "Bright red")
					end
				end
			end
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
			local cooldown = executeIronFistCombo()
			task.wait(cooldown)
		end
		isFiringLoopActive = false
	end)
end)

tool.Deactivated:Connect(function() isHoldingM1 = false end)
tool.Unequipped:Connect(function() isHoldingM1 = false; isFiringLoopActive = false end)

-- BRAWLER M2, SHIFT, R
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or tool.Parent ~= player.Character then return end
	local now = tick()
	local char = player.Character
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")

	-- M2: MOUNTAIN SPLITTER
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		if now - lastM2 >= m2Cooldown then
			lastM2 = now; triggerHUDCooldown("M2", m2Cooldown); playSound("rbxassetid://130113322", 0.7)
			if rootPart then
				rootPart.AssemblyLinearVelocity = rootPart.CFrame.LookVector * 110 + Vector3.new(0, 10, 0)

				-- Expanding Shockwave Cone
				for step = 1, 3 do
					task.delay(step * 0.05, function()
						local shock = Instance.new("Part")
						shock.Size = Vector3.new(step * 4, 1, step * 4)
						shock.CFrame = rootPart.CFrame * CFrame.new(0, -1, -step * 5)
						shock.BrickColor = BrickColor.new("Bright orange")
						shock.Material = Enum.Material.Neon
						shock.Anchored = true; shock.CanCollide = false; shock.Parent = workspace
						game:GetService("Debris"):AddItem(shock, 0.2)
					end)
				end

				task.wait(0.1)
				for _, obj in ipairs(workspace:GetChildren()) do
					if obj:FindFirstChild("EnemyAI") and obj ~= char and obj:FindFirstChild("HumanoidRootPart") then
						local dist = (obj.HumanoidRootPart.Position - rootPart.Position).Magnitude
						if dist <= 12 and obj:FindFirstChildOfClass("Humanoid") then
							obj:FindFirstChildOfClass("Humanoid"):TakeDamage(60)
							obj.HumanoidRootPart.AssemblyLinearVelocity = rootPart.CFrame.LookVector * 80 + Vector3.new(0, 20, 0)
						end
					end
				end
			end
		end

		-- SHIFT: GALE FLASH STEP
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		if now - lastShift >= shiftCooldown then
			lastShift = now; triggerHUDCooldown("SHIFT", shiftCooldown); playSound("rbxassetid://12222170", 0.6)
			if rootPart then
				-- Motion Trail Part
				local trail = Instance.new("Part")
				trail.Size = Vector3.new(3, 5, 20)
				trail.CFrame = rootPart.CFrame
				trail.BrickColor = BrickColor.new("Cyan")
				trail.Material = Enum.Material.Neon
				trail.Transparency = 0.4
				trail.Anchored = true; trail.CanCollide = false; trail.Parent = workspace
				game:GetService("Debris"):AddItem(trail, 0.25)

				task.spawn(function()
					local dashDir = rootPart.CFrame.LookVector * 150 + Vector3.new(0, 8, 0)
					for i = 1, 8 do rootPart.AssemblyLinearVelocity = dashDir; task.wait(0.03) end
				end)
			end
		end

		-- R: EIGHT-POLE SPIRIT SLAM
	elseif input.KeyCode == Enum.KeyCode.R then
		if now - lastR >= rCooldown then
			lastR = now; triggerHUDCooldown("R", rCooldown); playSound("rbxassetid://130113322", 0.9)
			if rootPart then
				rootPart.AssemblyLinearVelocity = Vector3.new(0, 70, 0)
				task.wait(0.3)
				rootPart.AssemblyLinearVelocity = Vector3.new(0, -120, 0)
				task.wait(0.2)

				local slamPos = rootPart.Position
				local explosion = Instance.new("Explosion")
				explosion.Position = slamPos; explosion.BlastRadius = 18; explosion.BlastPressure = 0; explosion.Parent = workspace

				for _, obj in ipairs(workspace:GetChildren()) do
					if obj:FindFirstChild("EnemyAI") and obj:FindFirstChild("HumanoidRootPart") then
						if (obj.HumanoidRootPart.Position - slamPos).Magnitude <= 18 and obj:FindFirstChildOfClass("Humanoid") then
							obj:FindFirstChildOfClass("Humanoid"):TakeDamage(140)
						end
					end
				end
			end
		end
	end
end)