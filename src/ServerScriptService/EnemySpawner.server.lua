local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local elapsedTimeVal = ReplicatedStorage:WaitForChild("ElapsedTime")
local teleporterCompleteVal = ReplicatedStorage:WaitForChild("TeleporterComplete", 10)
local gameStartedVal = ReplicatedStorage:WaitForChild("GameStarted", 10)

local function getEnemyTemplates()
	local templates = {}
	for _, child in ipairs(ReplicatedStorage:GetChildren()) do
		if child:IsA("Model") and child:FindFirstChild("Humanoid") then
			table.insert(templates, child)
		end
	end
	return templates
end

local MIN_DIST = 30
local MAX_DIST = 55

local function getValidSpawnPosition(targetChar)
	local playerPos = targetChar.HumanoidRootPart.Position

	-- PROTECTION 1: NEVER SPAWN NEAR PLAYERS WHO ARE IN THE SKY LOBBY (Y > 1500)
	if playerPos.Y > 1500 then return nil end

	for attempt = 1, 5 do
		local angle = math.rad(math.random(0, 360))
		local dist = math.random(MIN_DIST, MAX_DIST)
		local rayStart = playerPos + Vector3.new(math.cos(angle)*dist, 100, math.sin(angle)*dist)

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {targetChar}

		local result = workspace:Raycast(rayStart, Vector3.new(0, -200, 0), raycastParams)
		if result and result.Position.Y < 1500 then 
			return result.Position + Vector3.new(0, 3, 0) 
		end
	end

	local fallbackAngle = math.rad(math.random(0, 360))
	local fallbackPos = playerPos + Vector3.new(math.cos(fallbackAngle) * 35, 5, math.sin(fallbackAngle) * 35)
	if fallbackPos.Y < 1500 then
		return fallbackPos
	end
	return nil
end

local function getLivingEnemyCount()
	local count = 0
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:FindFirstChild("EnemyAI") and obj:FindFirstChild("Humanoid") and obj.Humanoid.Health > 0 then
			count = count + 1
		end
	end
	return count
end

-- Main Spawning Loop
task.spawn(function()
	while task.wait() do
		-- PRE-WAIT GUARD: STOP IF IN LOBBY OR STAGE COMPLETE
		if not gameStartedVal or gameStartedVal.Value == false or (teleporterCompleteVal and teleporterCompleteVal.Value == true) then
			task.wait(1)
			continue
		end

		local seconds = elapsedTimeVal.Value
		local spawnCooldown = math.max(1.5, 5 - (seconds / 60))
		local maxEnemies = math.min(30, 8 + math.floor(seconds / 20))
		local burstSize = math.min(3, 1 + math.floor(seconds / 90))

		task.wait(spawnCooldown)

		-- PROTECTION 2: POST-WAIT GUARD (RE-CHECK IF GAME STOPPED WHILE WAITING!)
		if not gameStartedVal or gameStartedVal.Value == false or (teleporterCompleteVal and teleporterCompleteVal.Value == true) then
			continue
		end

		local enemyTemplates = getEnemyTemplates()
		if getLivingEnemyCount() < maxEnemies and #enemyTemplates > 0 then
			local activePlayers = {}
			for _, p in ipairs(Players:GetPlayers()) do
				if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
					-- Only target players who are actively playing on stage (Y < 1500)
					if p.Character.HumanoidRootPart.Position.Y < 1500 then
						local hum = p.Character:FindFirstChildOfClass("Humanoid")
						if hum and hum.Health > 0 then table.insert(activePlayers, p.Character) end
					end
				end
			end

			if #activePlayers > 0 then
				for i = 1, burstSize do
					if getLivingEnemyCount() >= maxEnemies then break end

					local targetChar = activePlayers[math.random(1, #activePlayers)]
					local spawnPos = getValidSpawnPosition(targetChar)

					-- DOUBLE CHECK AGAIN RIGHT BEFORE CLONING
					if spawnPos and gameStartedVal.Value == true then
						local chosenTemplate = enemyTemplates[math.random(1, #enemyTemplates)]
						local newEnemy = chosenTemplate:Clone()
						newEnemy:PivotTo(CFrame.new(spawnPos))
						newEnemy.Parent = workspace

						local spawnSound = Instance.new("Sound")
						spawnSound.SoundId = "rbxassetid://2375539277"; spawnSound.Volume = 0.6
						spawnSound.Parent = newEnemy.PrimaryPart or newEnemy:FindFirstChild("HumanoidRootPart")
						spawnSound:Play()
					end
				end
			end
		end
	end
end)