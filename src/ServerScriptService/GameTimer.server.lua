local ReplicatedStorage = game:GetService("ReplicatedStorage")

local elapsedTimeVal = ReplicatedStorage:FindFirstChild("ElapsedTime") or Instance.new("IntValue")
elapsedTimeVal.Name = "ElapsedTime"; elapsedTimeVal.Value = 0; elapsedTimeVal.Parent = ReplicatedStorage

local threatTextVal = ReplicatedStorage:FindFirstChild("ThreatText") or Instance.new("StringValue")
threatTextVal.Name = "ThreatText"; threatTextVal.Value = "EASY"; threatTextVal.Parent = ReplicatedStorage

local gameStartedVal = ReplicatedStorage:WaitForChild("GameStarted", 10)

-- Timer Loop
task.spawn(function()
	while task.wait(1) do
		-- ONLY COUNT TIME WHILE GAME IS ACTIVE!
		if gameStartedVal and gameStartedVal.Value == true then
			elapsedTimeVal.Value = elapsedTimeVal.Value + 1
			local seconds = elapsedTimeVal.Value

			if seconds < 60 then threatTextVal.Value = "EASY"
			elseif seconds < 120 then threatTextVal.Value = "MEDIUM"
			elseif seconds < 180 then threatTextVal.Value = "HARD"
			elseif seconds < 240 then threatTextVal.Value = "VERY HARD"
			else threatTextVal.Value = "CRITICAL / IMPOSSIBLE" end
		else
			-- RESET TIMER AND THREAT WHEN IN LOBBY MODE
			elapsedTimeVal.Value = 0
			threatTextVal.Value = "EASY"
		end
	end
end)