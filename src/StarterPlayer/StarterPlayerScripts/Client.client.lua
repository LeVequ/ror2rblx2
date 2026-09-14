local StarterGui = game:GetService("StarterGui")

-- The game uses its own UI, so keep Roblox's built-in player list/leaderboard
-- from overlapping it. This also prevents the default Tab player list from
-- being shown during menus or gameplay.
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
