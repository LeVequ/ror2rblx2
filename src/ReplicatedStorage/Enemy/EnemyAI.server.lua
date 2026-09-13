local enemy = script.Parent
local humanoid = enemy:WaitForChild("Humanoid")
local rootPart = enemy:WaitForChild("HumanoidRootPart")
local animator = humanoid:WaitForChild("Animator")

local attackDamage = 10
local attackCooldown = 1.5
local lastAttackTime = 0

local gameStartedVal = game:GetService("ReplicatedStorage"):WaitForChild("GameStarted", 10)

-- R15 ANIMATIONS
local walkAnim = Instance.new("Animation")
walkAnim.AnimationId = "rbxassetid://507777826"
local walkTrack = animator:LoadAnimation(walkAnim)
walkTrack.Looped = true

local attackAnim = Instance.new("Animation")
attackAnim.AnimationId = "rbxassetid://522635514"
local attackTrack = animator:LoadAnimation(attackAnim)
attackTrack.Priority = Enum.AnimationPriority.Action

local function getNearestPlayer()
	local nearestCharacter = nil
	local shortestDistance = math.huge

	for _, player in ipairs(game.Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local char = player.Character
			local playerHumanoid = char:FindFirstChildOfClass("Humanoid")
			if playerHumanoid and playerHumanoid.Health > 0 then
				local distance = (rootPart.Position - char.HumanoidRootPart.Position).Magnitude
				if distance < shortestDistance then
					shortestDistance = distance
					nearestCharacter = char
				end
			end
		end
	end
	return nearestCharacter, shortestDistance
end

-- ENEMY DEATH EVENT
humanoid.Died:Connect(function()
	if walkTrack then walkTrack:Stop() end
	local killerChar, dist = getNearestPlayer()
	if killerChar then
		local killerPlayer = game.Players:GetPlayerFromCharacter(killerChar)
		if killerPlayer and killerPlayer:FindFirstChild("leaderstats") then
			local goldVal = killerPlayer.leaderstats:FindFirstChild("Gold")
			if goldVal then
				local buffs = killerPlayer:FindFirstChild("Buffs")
				local goblinCount = (buffs and buffs:FindFirstChild("Goblin")) and buffs.Goblin.Value or 0
				local totalGold = 15 + (goblinCount * 4)
				goldVal.Value = goldVal.Value + totalGold

				local kills = killerPlayer:GetAttribute("Kills") or 0
				local totalEarned = killerPlayer:GetAttribute("TotalGoldEarned") or 0
				killerPlayer:SetAttribute("Kills", kills + 1)
				killerPlayer:SetAttribute("TotalGoldEarned", totalEarned + totalGold)
			end
		end
	end
	task.wait(2)
	enemy:Destroy()
end)

-- MAIN AI MOVEMENT & ANIMATION LOOP
while task.wait(0.2) do
	-- PROTECTION 3: SELF-DESTRUCT IF GAME STOPPED OR IF IN LOBBY ALTITUDE!
	if (gameStartedVal and gameStartedVal.Value == false) or rootPart.Position.Y > 1500 or humanoid.Health <= 0 then
		if walkTrack then walkTrack:Stop() end
		enemy:Destroy()
		break
	end

	local targetChar, distance = getNearestPlayer()
	if targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
		humanoid:MoveTo(targetChar.HumanoidRootPart.Position)

		if not walkTrack.IsPlaying then
			walkTrack:Play()
		end

		if distance <= 6 and (tick() - lastAttackTime) >= attackCooldown then
			lastAttackTime = tick()
			attackTrack:Play()

			local playerHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
			if playerHumanoid then
				playerHumanoid:TakeDamage(attackDamage)
			end
		end
	else
		if walkTrack.IsPlaying then walkTrack:Stop() end
	end
end