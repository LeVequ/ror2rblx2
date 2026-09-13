local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")

local hurtSound = Instance.new("Sound")
hurtSound.SoundId = "rbxassetid://12222225" -- Roblox Oof / Hurt sound
hurtSound.Parent = character

local lastHealth = humanoid.Health
humanoid.HealthChanged:Connect(function(newHealth)
	if newHealth < lastHealth then
		hurtSound:Play() -- Play sound when taking damage!
	end
	lastHealth = newHealth
end)