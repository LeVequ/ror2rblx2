local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")

local function equipClass(player, className)
	local char = player.Character
	if not char or not char:FindFirstChild("Humanoid") then return end

	local hum = char.Humanoid

	-- Clear current weapons from Backpack and Character
	player.Backpack:ClearAllChildren()
	for _, item in ipairs(char:GetChildren()) do
		if item:IsA("Tool") then item:Destroy() end
	end

	if className == "gunner" then
		hum.MaxHealth = 100; hum.Health = 100
		hum.WalkSpeed = 16
		local gun = StarterPack:FindFirstChild("LaserGun")
		if gun then gun:Clone().Parent = player.Backpack end
		print(player.Name .. " switched to GUNNER!")

	elseif className == "ranger" then
		hum.MaxHealth = 90; hum.Health = 90
		hum.WalkSpeed = 20 -- High Speed!
		local bow = StarterPack:FindFirstChild("RangerWeapon")
		if bow then bow:Clone().Parent = player.Backpack end
		print(player.Name .. " switched to RANGER!")

	elseif className == "brawler" then
		hum.MaxHealth = 150; hum.Health = 150 -- Tanky Melee HP!
		hum.WalkSpeed = 18
		local fists = StarterPack:FindFirstChild("BrawlerWeapon")
		if fists then fists:Clone().Parent = player.Backpack end
		print(player.Name .. " switched to BRAWLER (Yaeno Muteki Style)!")
	end

	-- Auto equip new tool
	task.delay(0.2, function()
		local tool = player.Backpack:FindFirstChildOfClass("Tool")
		if tool and hum then hum:EquipTool(tool) end
	end)
end

-- Chat Commands: /gunner, /ranger, /brawler
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		local lower = string.lower(msg)
		if lower == "/gunner" or lower == "/ranger" or lower == "/brawler" then
			equipClass(player, string.sub(lower, 2))
		end
	end)
end)