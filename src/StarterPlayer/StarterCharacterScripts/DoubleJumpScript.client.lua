local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local hasDoubleJumped = false

humanoid.StateChanged:Connect(function(oldState, newState)
	if newState == Enum.HumanoidStateType.Landed then
		hasDoubleJumped = false
	end
end)

UserInputService.JumpRequest:Connect(function()
	local buffs = player:FindFirstChild("Buffs")
	local doubleJumpCount = (buffs and buffs:FindFirstChild("PaulsDoubleJumpers")) and buffs.PaulsDoubleJumpers.Value or 0

	if doubleJumpCount > 0 then
		local state = humanoid:GetState()
		if (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping) and not hasDoubleJumped then
			hasDoubleJumped = true
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, 60, rootPart.AssemblyLinearVelocity.Z)

			local sound = Instance.new("Sound")
			sound.SoundId = "rbxassetid://12222170"
			sound.Volume = 0.6
			sound.Parent = rootPart
			sound:Play()
			game:GetService("Debris"):AddItem(sound, 2)
		end
	end
end)