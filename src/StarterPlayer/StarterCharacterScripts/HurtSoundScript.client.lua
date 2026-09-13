local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gameStartedVal = ReplicatedStorage:WaitForChild("GameStarted", 10)
local lobbyPhaseVal = ReplicatedStorage:WaitForChild("LobbyPhase", 10)

local hurtSound = Instance.new("Sound")
hurtSound.SoundId = "rbxassetid://12222225" -- Roblox Oof / Hurt sound
hurtSound.Parent = character

local lastHealth = humanoid.Health
local lastMaxHealth = humanoid.MaxHealth
humanoid.HealthChanged:Connect(function(newHealth)
	-- Loadout/stat setup can change MaxHealth/Health without real damage. Those
	-- changes must not trigger the hurt/unsheath audio. Only allow the
	-- sound during an active run when MaxHealth itself did not just change.
	local gameplayActive = gameStartedVal and gameStartedVal.Value
		and lobbyPhaseVal and lobbyPhaseVal.Value == "RUN"
	local maxHealthUnchanged = humanoid.MaxHealth == lastMaxHealth
	if gameplayActive and maxHealthUnchanged and newHealth < lastHealth then
		hurtSound:Play() -- Play sound when taking damage!
	end
	lastHealth = newHealth
	lastMaxHealth = humanoid.MaxHealth
end)
