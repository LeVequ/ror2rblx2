local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local tool = script.Parent
local player = Players.LocalPlayer

local isHoldingM1 = false
local isFiringLoopActive = false

local m2Cooldown = 5; local shiftCooldown = 4; local rCooldown = 10
local lastM1 = 0; local lastM2 = 0; local lastShift = 0; local lastR = 0

local function playSound(soundId, vol)
	local handle = tool:FindFirstChild("Handle")
	if handle then
		local sound = Instance.new("Sound"); sound.SoundId = soundId; sound.Volume = vol or 0.3; sound.Parent = handle; sound:Play()
		game:GetService("Debris"):AddItem(sound, 2)
	end
end

-- HELPER: ENSURES TARGET IS A VALID ENEMY (NO FRIENDLY FIRE!)
local function isValidEnemy(model)
	if not model then return false end
	-- DO NOT DAMAGE OTHER PLAYERS!
	if Players:GetPlayerFromCharacter(model) then return false end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

local function createLaserTracer(startPos, endPos, colorName, thickness)
	local dist = (endPos - startPos).Magnitude
	if dist <= 0 then return end
	local tracer = Instance.new("Part")
	tracer.Name = "LaserTracer"; tracer.Size = Vector3.new(thickness, thickness, dist)
	tracer.CFrame = CFrame.new(startPos, endPos) * CFrame.new(0, 0, -dist/2)
	tracer.BrickColor = BrickColor.new(colorName); tracer.Material = Enum.Material.Neon; tracer.Anchored = true; tracer.CanCollide = false; tracer.Parent = workspace
	task.spawn(function()
		for i = 1, 5 do tracer.Transparency = i / 5; task.wait(0.02) end
		tracer:Destroy()
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

local function handleSplitshotRicochet(primaryEnemyModel, baseDamage)
	local buffs = player:FindFirstChild("Buffs")
	local splitshotCount = (buffs and buffs:FindFirstChild("Splitshot")) and buffs.Splitshot.Value or 0

	if splitshotCount > 0 then
		local chance = math.min(100, splitshotCount * 12)
		if math.random(1, 100) <= chance then
			local originPos = primaryEnemyModel.PrimaryPart and primaryEnemyModel.PrimaryPart.Position or player.Character.HumanoidRootPart.Position
			for _, obj in ipairs(workspace:GetChildren()) do
				if isValidEnemy(obj) and obj ~= primaryEnemyModel then
					local dist = (obj.HumanoidRootPart.Position - originPos).Magnitude
					if dist <= 25 then
						local ricochetDmg = math.floor(baseDamage * 0.5)
						obj:FindFirstChildOfClass("Humanoid"):TakeDamage(ricochetDmg)
						createLaserTracer(originPos, obj.HumanoidRootPart.Position, "Bright yellow", 0.4)
						break
					end
				end
			end
		end
	end
end

local function fireSingleM1Shot()
	local buffs = player:FindFirstChild("Buffs")
	local daggerCount = (buffs and buffs:FindFirstChild("Dagger")) and buffs.Dagger.Value or 0
	local farsightCount = (buffs and buffs:FindFirstChild("CharliesFarsight")) and buffs.CharliesFarsight.Value or 0

	local m1Cooldown = math.max(0.08, 0.28 / (1 + 0.12 * daggerCount))
	local now = tick()
	if now - lastM1 < m1Cooldown then return m1Cooldown - (now - lastM1) end
	lastM1 = now

	playSound("rbxassetid://260430079", 0.2)

	local handle = tool:FindFirstChild("Handle")
	local startPos = handle and handle.Position or (player.Character.HumanoidRootPart.Position + Vector3.new(0, 1.5, 0))
	local mouse = player:GetMouse()
	local targetPos = mouse.Hit and mouse.Hit.Position or (startPos + player.Character.HumanoidRootPart.CFrame.LookVector * 100)

	createLaserTracer(startPos, targetPos, "Bright green", 0.3)

	local target = mouse.Target
	if target then
		local model = target:FindFirstAncestorOfClass("Model")
		if isValidEnemy(model) then -- NO FRIENDLY FIRE!
			local dist = (target.Position - player.Character.HumanoidRootPart.Position).Magnitude
			local maxRange = 150 * (1 + 0.25 * farsightCount)
			if dist <= maxRange then
				model:FindFirstChildOfClass("Humanoid"):TakeDamage(12)
				handleSplitshotRicochet(model, 12)
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
			local cooldown = fireSingleM1Shot()
			task.wait(cooldown)
		end
		isFiringLoopActive = false
	end)
end)

-- FORCE RESET M1 FLAGS ON RELEASE, UNEQUIP, OR DEATH
tool.Deactivated:Connect(function() isHoldingM1 = false end)
tool.Unequipped:Connect(function() isHoldingM1 = false; isFiringLoopActive = false end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or tool.Parent ~= player.Character then return end
	local now = tick()
	local mouse = player:GetMouse()
	local char = player.Character
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		if now - lastM2 >= m2Cooldown then
			lastM2 = now; triggerHUDCooldown("M2", m2Cooldown); playSound("rbxassetid://130113322", 0.5)
			local handle = tool:FindFirstChild("Handle")
			local startPos = handle and handle.Position or (rootPart.Position + Vector3.new(0, 1.5, 0))
			local targetPos = mouse.Hit and mouse.Hit.Position or (startPos + rootPart.CFrame.LookVector * 100)
			createLaserTracer(startPos, targetPos, "Bright red", 0.8)

			local target = mouse.Target
			if target then
				local model = target:FindFirstAncestorOfClass("Model")
				if isValidEnemy(model) then
					model:FindFirstChildOfClass("Humanoid"):TakeDamage(40)
					handleSplitshotRicochet(model, 40)
				end
			end
		end

	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		if now - lastShift >= shiftCooldown then
			lastShift = now; triggerHUDCooldown("SHIFT", shiftCooldown); playSound("rbxassetid://12222170", 0.4)
			if rootPart then
				task.spawn(function()
					local dashDir = rootPart.CFrame.LookVector * 120 + Vector3.new(0, 10, 0)
					for i = 1, 8 do rootPart.AssemblyLinearVelocity = dashDir; task.wait(0.03) end
				end)
			end
		end

	elseif input.KeyCode == Enum.KeyCode.R then
		if now - lastR >= rCooldown then
			lastR = now; triggerHUDCooldown("R", rCooldown); playSound("rbxassetid://12221984", 0.6)
			local hitPos = mouse.Hit and mouse.Hit.Position
			if hitPos then
				task.delay(0.4, function()
					local explosion = Instance.new("Explosion"); explosion.Position = hitPos; explosion.BlastRadius = 18; explosion.BlastPressure = 0; explosion.Parent = workspace
					for _, obj in ipairs(workspace:GetChildren()) do
						if isValidEnemy(obj) and obj:FindFirstChild("HumanoidRootPart") then
							if (obj.HumanoidRootPart.Position - hitPos).Magnitude <= 18 then
								obj:FindFirstChildOfClass("Humanoid"):TakeDamage(85)
							end
						end
					end
				end)
			end
		end
	end
end)