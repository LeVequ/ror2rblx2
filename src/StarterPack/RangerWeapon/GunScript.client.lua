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
		sound.SoundId = soundId; sound.Volume = vol or 0.3; sound.Parent = handle; sound:Play()
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

local function createArrowTracer(startPos, endPos, colorName)
	local dist = (endPos - startPos).Magnitude
	if dist <= 0 then return end
	local tracer = Instance.new("Part")
	tracer.Size = Vector3.new(0.2, 0.2, dist)
	tracer.CFrame = CFrame.new(startPos, endPos) * CFrame.new(0, 0, -dist/2)
	tracer.BrickColor = BrickColor.new(colorName); tracer.Material = Enum.Material.Neon
	tracer.Anchored = true; tracer.CanCollide = false; tracer.Parent = workspace
	task.spawn(function()
		for i = 1, 5 do tracer.Transparency = i / 5; task.wait(0.02) end
		tracer:Destroy()
	end)
end

-- RANGER M1: SEEKING ENERGY ARROW
local function fireRangerArrow()
	local m1Cooldown = 0.18 -- Fast Firing!
	local now = tick()
	if now - lastM1 < m1Cooldown then return m1Cooldown - (now - lastM1) end
	lastM1 = now

	playSound("rbxassetid://12222170", 0.3)

	local handle = tool:FindFirstChild("Handle")
	local startPos = handle and handle.Position or (player.Character.HumanoidRootPart.Position + Vector3.new(0, 1.5, 0))
	local mouse = player:GetMouse()
	local targetPos = mouse.Hit and mouse.Hit.Position or (startPos + player.Character.HumanoidRootPart.CFrame.LookVector * 120)

	createArrowTracer(startPos, targetPos, "Bright cyan")

	local target = mouse.Target
	if target then
		local model = target:FindFirstAncestorOfClass("Model")
		if model and model ~= player.Character then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid:TakeDamage(15) end
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
			local cooldown = fireRangerArrow()
			task.wait(cooldown)
		end
		isFiringLoopActive = false
	end)
end)

tool.Deactivated:Connect(function() isHoldingM1 = false end)
tool.Unequipped:Connect(function() isHoldingM1 = false; isFiringLoopActive = false end)

-- RANGER M2, SHIFT, R
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or tool.Parent ~= player.Character then return end
	local now = tick()
	local mouse = player:GetMouse()
	local char = player.Character
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")

	-- M2: Piercing Heavy Arrow
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		if now - lastM2 >= m2Cooldown then
			lastM2 = now; triggerHUDCooldown("M2", m2Cooldown); playSound("rbxassetid://130113322", 0.5)
			local startPos = rootPart.Position + Vector3.new(0, 1.5, 0)
			local targetPos = mouse.Hit and mouse.Hit.Position or (startPos + rootPart.CFrame.LookVector * 150)
			createArrowTracer(startPos, targetPos, "Bright yellow")

			local target = mouse.Target
			if target then
				local model = target:FindFirstAncestorOfClass("Model")
				if model and model ~= char then
					local hum = model:FindFirstChildOfClass("Humanoid")
					if hum then hum:TakeDamage(45) end
				end
			end
		end

		-- SHIFT: INSTANT BLINK STEP
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		if now - lastShift >= shiftCooldown then
			lastShift = now; triggerHUDCooldown("SHIFT", shiftCooldown); playSound("rbxassetid://12222170", 0.5)
			if rootPart then
				-- Teleport 35 studs forward instantly
				rootPart.CFrame = rootPart.CFrame * CFrame.new(0, 0, -35)
				print("Ranger Blink Step!")
			end
		end

		-- R: ARROW RAIN AOE
	elseif input.KeyCode == Enum.KeyCode.R then
		if now - lastR >= rCooldown then
			lastR = now; triggerHUDCooldown("R", rCooldown); playSound("rbxassetid://12221984", 0.6)
			local hitPos = mouse.Hit and mouse.Hit.Position
			if hitPos then
				task.delay(0.2, function()
					local explosion = Instance.new("Explosion")
					explosion.Position = hitPos; explosion.BlastRadius = 16; explosion.BlastPressure = 0; explosion.Parent = workspace
					for _, obj in ipairs(workspace:GetChildren()) do
						if obj:FindFirstChild("EnemyAI") and obj:FindFirstChild("HumanoidRootPart") then
							if (obj.HumanoidRootPart.Position - hitPos).Magnitude <= 16 and obj:FindFirstChildOfClass("Humanoid") then
								obj:FindFirstChildOfClass("Humanoid"):TakeDamage(120)
							end
						end
					end
				end)
			end
		end
	end
end)