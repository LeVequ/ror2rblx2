local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local SHOULDER_OFFSET = Vector3.new(2.2, 1.2, 0)
local gameStartedVal = ReplicatedStorage:WaitForChild("GameStarted", 10)
local deathConnection = nil

local function unlockMouse()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

-- Single authoritative cleanup path for leaving gameplay/aim mode.
-- This is intentionally safe to call repeatedly during death, round cleanup,
-- unequip/respawn transitions, or while the character is being removed.
local function resetAimState(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.CameraOffset = Vector3.new(0, 0, 0)
	end

	unlockMouse()
end

local function applyAimState(character)
	if not character then
		resetAimState(nil)
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local shouldAim = gameStartedVal and gameStartedVal.Value and humanoid.Health > 0
	if shouldAim then
		humanoid.AutoRotate = false
		humanoid.CameraOffset = SHOULDER_OFFSET
	else
		resetAimState(character)
	end
end

local function setupCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")

	if deathConnection then
		deathConnection:Disconnect()
		deathConnection = nil
	end

	-- New characters always derive their camera state from the current round.
	-- Never inherit assumptions from the previous life.
	applyAimState(character)

	deathConnection = humanoid.Died:Connect(function()
		resetAimState(character)
	end)
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)
player.CharacterRemoving:Connect(function(character)
	resetAimState(character)
	if deathConnection then
		deathConnection:Disconnect()
		deathConnection = nil
	end
end)

if gameStartedVal then
	gameStartedVal.Changed:Connect(function()
		-- Handle both round start and round end. Previously the false transition
		-- left AutoRotate disabled and the shoulder offset active.
		applyAimState(player.Character)
	end)
end

-- Render Loop
RunService.RenderStepped:Connect(function()
	local isGameplayActive = gameStartedVal and gameStartedVal.Value
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local isAlive = humanoid and humanoid.Health > 0

	-- UNLOCK MOUSE IF DEAD OR IN LOBBY!
	if isGameplayActive and isAlive then
		-- === ALIVE IN GAMEPLAY: LOCK MOUSE & CROSSHAIR ===
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local cameraCFrame = camera.CFrame
			local lookVector = Vector3.new(cameraCFrame.LookVector.X, 0, cameraCFrame.LookVector.Z).Unit
			if lookVector.Magnitude > 0 then
				rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + lookVector)
			end
		end
	else
		-- === DEAD OR IN LOBBY: FORCE NORMAL CHARACTER/CAMERA STATE ===
		-- This per-frame fallback makes cleanup self-healing even if a lifecycle
		-- event fires while Roblox is tearing down the old character.
		resetAimState(character)
	end
end)
