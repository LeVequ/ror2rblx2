local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local screenGui = script.Parent
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = math.max(screenGui.DisplayOrder, 50)

local toggleReadyRemote = ReplicatedStorage:WaitForChild("ToggleReadyRemote", 10)
local completeTutorialRemote = ReplicatedStorage:WaitForChild("CompleteTutorialRemote", 10)
local disbandLobbyRemote = ReplicatedStorage:WaitForChild("DisbandLobbyRemote", 10)
local lobbyPhaseVal = ReplicatedStorage:WaitForChild("LobbyPhase", 10)
local gameStartedVal = ReplicatedStorage:WaitForChild("GameStarted", 10)

local C = {
	Ink = Color3.fromRGB(7, 12, 18),
	Panel = Color3.fromRGB(24, 34, 43),
	PanelSelected = Color3.fromRGB(188, 211, 220),
	Text = Color3.fromRGB(224, 236, 239),
	Muted = Color3.fromRGB(132, 151, 160),
	DarkText = Color3.fromRGB(19, 31, 38),
	Accent = Color3.fromRGB(132, 207, 226),
	AccentSoft = Color3.fromRGB(85, 143, 158),
}

-- These values intentionally mirror MainMenu.client.lua / LobbyManager.server.lua.
-- The title camera faces +Z. The four-player staging bay is directly behind it.
local FRONTEND_ORIGIN = Vector3.new(24000, 9200, -24000)
local LOBBY_CENTER = FRONTEND_ORIGIN + Vector3.new(0, 4, -230)
local LOBBY_SLOT_OFFSETS = {-12, -4, 4, 12}
local LOBBY_CAMERA_POSITION = FRONTEND_ORIGIN + Vector3.new(0, 8.2, -200)
local LOBBY_CAMERA_FOCUS = LOBBY_CENTER + Vector3.new(0, 0.6, 0)

local function make(className, name, parent, props)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local obj = Instance.new(className)
	obj.Name = name
	for key, value in pairs(props or {}) do obj[key] = value end
	obj.Parent = parent
	return obj
end

local function stroke(parent, color, transparency)
	return make("UIStroke", "Stroke", parent, {
		Color = color,
		Thickness = 1,
		Transparency = transparency or 0,
	})
end

local root = make("CanvasGroup", "LobbyRoot", screenGui, {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
	GroupTransparency = 1,
	ZIndex = 2,
})

local topShade = make("Frame", "TopShade", root, {
	Size = UDim2.fromScale(1, .22),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = .48,
	BorderSizePixel = 0,
	ZIndex = 2,
})
make("UIGradient", "Gradient", topShade, {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, .18),
		NumberSequenceKeypoint.new(1, 1),
	}),
})

local bottomShade = make("Frame", "BottomShade", root, {
	Size = UDim2.fromScale(1, .30),
	Position = UDim2.fromScale(0, .70),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = .42,
	BorderSizePixel = 0,
	ZIndex = 2,
})
make("UIGradient", "Gradient", bottomShade, {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, .12),
	}),
})

local eyebrow = make("TextLabel", "Eyebrow", root, {
	Size = UDim2.new(0, 430, 0, 18),
	Position = UDim2.fromScale(.045, .09),
	BackgroundTransparency = 1,
	Text = "BYTEFORCE // SQUAD SESSION",
	TextColor3 = C.Accent,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
})

local title = make("TextLabel", "LobbyTitle", root, {
	Size = UDim2.new(0, 520, 0, 44),
	Position = UDim2.fromScale(.045, .112),
	BackgroundTransparency = 1,
	Text = "SQUAD STAGING",
	TextColor3 = C.Text,
	TextSize = 30,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
})

local squadCount = make("TextLabel", "SquadCount", root, {
	Size = UDim2.new(0, 300, 0, 24),
	Position = UDim2.fromScale(.045, .17),
	BackgroundTransparency = 1,
	Text = "1 / 4 OPERATIVES",
	TextColor3 = C.Muted,
	TextSize = 11,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
})

local slotLayer = make("Frame", "SlotLayer", root, {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 6,
})

local slotCards = {}
for slot = 1, 4 do
	local card = make("Frame", "Slot" .. slot, slotLayer, {
		Size = UDim2.fromOffset(146, 60),
		AnchorPoint = Vector2.new(.5, 0),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = .16,
		BorderSizePixel = 0,
		ZIndex = 7,
	})
	stroke(card, C.AccentSoft, .48)

	local avatar = make("ImageLabel", "Avatar", card, {
		Size = UDim2.fromOffset(38, 38),
		Position = UDim2.fromOffset(9, 15),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = .1,
		BorderSizePixel = 0,
		Image = "",
		Visible = false,
		ZIndex = 8,
	})
	make("UICorner", "Corner", avatar, {CornerRadius = UDim.new(1, 0)})

	local slotLabel = make("TextLabel", "SlotLabel", card, {
		Size = UDim2.new(1, -16, 0, 14),
		Position = UDim2.fromOffset(8, 2),
		BackgroundTransparency = 1,
		Text = string.format("SLOT %02d", slot),
		TextColor3 = C.AccentSoft,
		TextSize = 8,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
	})

	local name = make("TextLabel", "PlayerName", card, {
		Size = UDim2.new(1, -60, 0, 22),
		Position = UDim2.fromOffset(55, 15),
		BackgroundTransparency = 1,
		Text = "OPEN SLOT",
		TextColor3 = C.Text,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
	})

	local state = make("TextLabel", "State", card, {
		Size = UDim2.new(1, -60, 0, 16),
		Position = UDim2.fromOffset(55, 37),
		BackgroundTransparency = 1,
		Text = "AWAITING OPERATIVE",
		TextColor3 = C.Muted,
		TextSize = 8,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
	})

	slotCards[slot] = {
		Frame = card,
		Avatar = avatar,
		Name = name,
		State = state,
		SlotLabel = slotLabel,
		Stroke = card:FindFirstChild("Stroke"),
	}
end

local readyBtn = make("TextButton", "ReadyBtn", root, {
	Size = UDim2.fromOffset(330, 58),
	Position = UDim2.new(.5, 0, 1, -50),
	AnchorPoint = Vector2.new(.5, 1),
	BackgroundColor3 = C.PanelSelected,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "READY UP",
	TextColor3 = C.DarkText,
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	Selectable = true,
	ZIndex = 9,
})
stroke(readyBtn, C.Accent, .22)

local statusText = make("TextLabel", "StatusText", root, {
	Size = UDim2.fromOffset(440, 20),
	Position = UDim2.new(.5, 0, 1, -18),
	AnchorPoint = Vector2.new(.5, 1),
	BackgroundTransparency = 1,
	Text = "0 / 1 READY",
	TextColor3 = C.Muted,
	TextSize = 9,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 9,
})

local disbandBtn = make("TextButton", "DisbandBtn", root, {
	Size = UDim2.fromOffset(190, 38),
	Position = UDim2.new(0, 24, 1, -56),
	AnchorPoint = Vector2.new(0, 1),
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = .34,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "←  DISBAND SQUAD",
	TextColor3 = C.Muted,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
	Selectable = true,
	Visible = false,
	ZIndex = 9,
})
stroke(disbandBtn, C.AccentSoft, .68)

local disbandHint = make("TextLabel", "DisbandHint", root, {
	Size = UDim2.fromOffset(190, 16),
	Position = UDim2.new(0, 24, 1, -18),
	AnchorPoint = Vector2.new(0, 1),
	BackgroundTransparency = 1,
	Text = "ESC   RETURN TO TITLE",
	TextColor3 = C.Muted,
	TextSize = 8,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	Visible = false,
	ZIndex = 9,
})

local helpBtn = make("TextButton", "HelpBtn", root, {
	Size = UDim2.fromOffset(112, 34),
	Position = UDim2.new(1, -138, 0, 28),
	BackgroundColor3 = C.Panel,
	BorderSizePixel = 0,
	Text = "CONTROLS",
	TextColor3 = C.Text,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
	ZIndex = 9,
})
stroke(helpBtn, C.AccentSoft, .62)

local tutorial = make("Frame", "TutorialModal", screenGui, {
	Size = UDim2.fromOffset(540, 330),
	Position = UDim2.new(.5, -270, .5, -165),
	BackgroundColor3 = C.Ink,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 30,
})
stroke(tutorial, C.Accent, .32)
make("TextLabel", "Title", tutorial, {
	Size = UDim2.new(1, -32, 0, 44),
	Position = UDim2.fromOffset(16, 14),
	BackgroundTransparency = 1,
	Text = "COMBAT CONTROLS",
	TextColor3 = C.Text,
	TextSize = 20,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 31,
})
make("TextLabel", "Body", tutorial, {
	Size = UDim2.new(1, -32, 1, -116),
	Position = UDim2.fromOffset(16, 68),
	BackgroundTransparency = 1,
	Text = "M1  PRIMARY\nM2  SECONDARY\nSHIFT  UTILITY\nR  SPECIAL\n\nReady the squad, choose a survivor, then locate and charge the teleporter during the run.",
	TextColor3 = C.Muted,
	TextSize = 13,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 31,
})
local closeTutorial = make("TextButton", "CloseTutorial", tutorial, {
	Size = UDim2.fromOffset(180, 42),
	Position = UDim2.new(1, -196, 1, -58),
	BackgroundColor3 = C.PanelSelected,
	BorderSizePixel = 0,
	Text = "CLOSE",
	TextColor3 = C.DarkText,
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	ZIndex = 31,
})

local controls
local lobbyActive = false
local hudRevealed = false
local hudRevealTween = nil
local cameraBind = "ByteforceLobbyCamera"
local hudTrackingBind = "ByteforceLobbyHudTracking"
local inputBind = "ByteforceLobbyInput"
local cameraGeneration = 0
local playerConnections = {}
local returningFromRun = false
local returnSettleToken = nil
local returnSettleFrames = 0

local function getControls()
	if controls then return controls end
	local ok, result = pcall(function()
		local ps = player:WaitForChild("PlayerScripts", 3)
		local pm = ps and ps:WaitForChild("PlayerModule", 3)
		return pm and require(pm):GetControls()
	end)
	if ok then controls = result end
	return controls
end

local function setControlsEnabled(enabled)
	local c = getControls()
	if not c then return end
	pcall(function()
		if enabled then c:Enable() else c:Disable() end
	end)
end

local function stopLobbyCamera()
	RunService:UnbindFromRenderStep(cameraBind)
end

local function stopHudTracking()
	RunService:UnbindFromRenderStep(hudTrackingBind)
end

local function lobbyTarget(driftX, driftY)
	local position = LOBBY_CAMERA_POSITION + Vector3.new(driftX or 0, driftY or 0, 0)
	return CFrame.lookAt(position, LOBBY_CAMERA_FOCUS)
end

local function slotWorldPosition(slot)
	return LOBBY_CENTER + Vector3.new(LOBBY_SLOT_OFFSETS[slot], -2.7, 0)
end

local function updateSlotCardPositions()
	local viewport = camera.ViewportSize
	for slot, data in ipairs(slotCards) do
		local screenPoint, onScreen = camera:WorldToViewportPoint(slotWorldPosition(slot))
		data.Frame.Visible = hudRevealed and onScreen and screenPoint.Z > 0
		if data.Frame.Visible then
			local x = math.clamp(screenPoint.X, 92, math.max(92, viewport.X - 92))
			local y = math.clamp(screenPoint.Y + 18, 150, math.max(150, viewport.Y - 150))
			data.Frame.Position = UDim2.fromOffset(x, y)
		end
	end
end

local function startLobbyCamera(snapImmediately, returnReadyToken)
	cameraGeneration += 1
	local mine = cameraGeneration
	stopLobbyCamera()
	lobbyActive = true
	camera.CameraType = Enum.CameraType.Scriptable

	local startCF = camera.CFrame
	local targetCF = lobbyTarget(0, 0)
	local startFov = camera.FieldOfView
	local started = os.clock()
	local returnCameraFrames = 0
	if snapImmediately then
		camera.CFrame = targetCF
		camera.FieldOfView = 50
		startCF = targetCF
		startFov = 50
		-- Skip the initial camera blend while the return blackout is still covering it.
		started -= .24
	end

	RunService:BindToRenderStep(cameraBind, Enum.RenderPriority.Camera.Value + 1, function()
		if not lobbyActive or mine ~= cameraGeneration then return end
		-- Reassert Scriptable ownership every rendered frame. Character respawn/default
		-- camera setup can run during a return, so a one-time assignment is not enough
		-- to prove the staging camera has actually won before the blackout is removed.
			camera.CameraType = Enum.CameraType.Scriptable
			local elapsed = os.clock() - started
			local appliedCF
			if elapsed < .24 then
				local alpha = TweenService:GetValue(math.clamp(elapsed / .24, 0, 1), Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				appliedCF = startCF:Lerp(targetCF, alpha)
				camera.CFrame = appliedCF
				camera.FieldOfView = startFov + (50 - startFov) * alpha
			else
				local driftX = math.sin(elapsed * .22) * .28
				local driftY = math.sin(elapsed * .16) * .07
				appliedCF = lobbyTarget(driftX, driftY)
				camera.CFrame = appliedCF
				camera.FieldOfView = 50
			end
		updateSlotCardPositions()

		if returnReadyToken
			and player:GetAttribute("LobbyReturnToken") == returnReadyToken
			and player:GetAttribute("LobbyReturnCameraPrelock") == returnReadyToken then
			returnCameraFrames += 1
			-- Return camera readiness is intentionally allowed before RETURNING/LOBBY.
			-- The staging camera must win while the old run is still hidden under black,
			-- so character respawn/default-camera setup can never become visible later.
			if returnCameraFrames >= 3
				and player:GetAttribute("LobbyReturnCameraReady") ~= returnReadyToken then
					player:SetAttribute("LobbyReturnCameraReady", returnReadyToken)
				end
			end

			local settleToken = player:GetAttribute("LobbyReturnToken")
			if lobbyPhaseVal.Value == "LOBBY"
				and typeof(settleToken) == "number"
				and player:GetAttribute("LobbyReturnCameraPrelock") == settleToken
				and player:GetAttribute("LobbyReturnCameraReady") == settleToken
				and appliedCF then
				-- Self-arm on the first rendered LOBBY frame. This avoids relying on event
				-- ordering between the replicated phase change and the local UI handoff.
				if returnSettleToken ~= settleToken then
					returnSettleToken = settleToken
					returnSettleFrames = 0
				end
				local positionError = (camera.CFrame.Position - appliedCF.Position).Magnitude
				local lookAgreement = camera.CFrame.LookVector:Dot(appliedCF.LookVector)
				local fovError = math.abs(camera.FieldOfView - 50)
				if camera.CameraType == Enum.CameraType.Scriptable
					and positionError <= 0.05
					and lookAgreement >= 0.9999
					and fovError <= 0.05 then
					returnSettleFrames += 1
				else
					returnSettleFrames = 0
				end

				-- This is intentionally a fresh post-respawn proof. The prelock token may
				-- already be satisfied before LoadCharacter runs, so only consecutive frames
				-- from this live lobby render bind are allowed to release the blackout.
				if returnSettleFrames >= 3
					and player:GetAttribute("LobbyReturnCameraSettled") ~= settleToken then
					player:SetAttribute("LobbyReturnCameraSettled", settleToken)
				end
			end
		end)

	-- Control resolution can yield while PlayerModule initializes. Camera ownership
	-- must never wait on that during a return, so disable movement off the critical
	-- render path after the bind is already live.
	task.spawn(setControlsEnabled, false)
end

local function refreshReady()
	local ready = player:GetAttribute("IsReady") == true
	readyBtn.Text = ready and "READY // CLICK TO UNREADY" or "READY UP"
	readyBtn.BackgroundColor3 = ready and C.Panel or C.PanelSelected
	readyBtn.TextColor3 = ready and C.Accent or C.DarkText

	local total, readyCount = 0, 0
	for _, p in ipairs(Players:GetPlayers()) do
		local slot = p:GetAttribute("LobbySlot")
		if typeof(slot) == "number" and slot >= 1 and slot <= 4 then
			total += 1
			if p:GetAttribute("IsReady") == true then readyCount += 1 end
		end
	end
	statusText.Text = string.format("%d / %d READY   //   ENTER / A", readyCount, math.max(total, 1))
end

local function refreshDisbandVisibility()
	local isHost = player:GetAttribute("LobbySlot") == 1
	disbandBtn.Visible = isHost and hudRevealed and lobbyPhaseVal.Value == "LOBBY"
	disbandBtn.Active = disbandBtn.Visible and lobbyActive
	disbandHint.Visible = disbandBtn.Visible
end

local function refreshRoster()
	local playersBySlot = {}
	local occupied = 0
	for _, p in ipairs(Players:GetPlayers()) do
		local slot = p:GetAttribute("LobbySlot")
		if typeof(slot) == "number" and slot >= 1 and slot <= 4 and not playersBySlot[slot] then
			playersBySlot[slot] = p
			occupied += 1
		end
	end

	squadCount.Text = string.format("%d / 4 OPERATIVES", occupied)
	for slot, data in ipairs(slotCards) do
		local occupant = playersBySlot[slot]
		if occupant then
			local ready = occupant:GetAttribute("IsReady") == true
			data.Avatar.Visible = true
			data.Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. occupant.UserId .. "&w=150&h=150"
			data.Name.Text = string.upper(occupant.DisplayName) .. (occupant == player and "  //  YOU" or "")
			data.Name.TextColor3 = C.Text
			data.State.Text = ready and "READY" or "WAITING"
			data.State.TextColor3 = ready and C.Accent or C.Muted
			data.Frame.BackgroundTransparency = ready and .08 or .16
			if data.Stroke then data.Stroke.Transparency = ready and .18 or .48 end
		else
			data.Avatar.Visible = false
			data.Avatar.Image = ""
			data.Name.Text = "OPEN SLOT"
			data.Name.TextColor3 = C.Muted
			data.State.Text = "AWAITING OPERATIVE"
			data.State.TextColor3 = C.AccentSoft
			data.Frame.BackgroundTransparency = .42
			if data.Stroke then data.Stroke.Transparency = .72 end
		end
	end
	refreshReady()
	refreshDisbandVisibility()
end

local function connectPlayer(p)
	if playerConnections[p] then return end
	local connections = {}
	connections[#connections + 1] = p:GetAttributeChangedSignal("IsReady"):Connect(refreshRoster)
	connections[#connections + 1] = p:GetAttributeChangedSignal("LobbySlot"):Connect(refreshRoster)
	playerConnections[p] = connections
end

local function disconnectPlayer(p)
	local connections = playerConnections[p]
	if not connections then return end
	for _, connection in ipairs(connections) do connection:Disconnect() end
	playerConnections[p] = nil
end

local function stopLobbyPresentation()
	lobbyActive = false
	hudRevealed = false
	returnSettleToken = nil
	returnSettleFrames = 0
	readyBtn.Active = false
	helpBtn.Active = false
	cameraGeneration += 1
	stopLobbyCamera()
	stopHudTracking()
	ContextActionService:UnbindAction(inputBind)
	if hudRevealTween then
		hudRevealTween:Cancel()
		hudRevealTween = nil
	end
	pcall(function()
		if GuiService.SelectedObject == readyBtn then GuiService.SelectedObject = nil end
	end)
	root.GroupTransparency = 1
	root.Position = UDim2.fromOffset(0, 10)
	root.Visible = false
	tutorial.Visible = false
	disbandBtn.Visible = false
	disbandHint.Visible = false
end

local function hideLobbyHudForReturn()
	-- Return transitions keep the lobby camera bind alive continuously. Only hide
	-- staging UI/input here; tearing down the camera would let Roblox's respawn
	-- camera briefly reclaim the viewport before the fade finishes.
	hudRevealed = false
	readyBtn.Active = false
	helpBtn.Active = false
	stopHudTracking()
	ContextActionService:UnbindAction(inputBind)
	if hudRevealTween then
		hudRevealTween:Cancel()
		hudRevealTween = nil
	end
	pcall(function()
		if GuiService.SelectedObject == readyBtn then GuiService.SelectedObject = nil end
	end)
	root.GroupTransparency = 1
	root.Position = UDim2.fromOffset(0, 10)
	root.Visible = false
	tutorial.Visible = false
	disbandBtn.Visible = false
	disbandHint.Visible = false
	-- PlayerModule can still be initializing after a respawn. Never let that yield
	-- delay the camera prelock; movement disabling is independent of camera ownership.
	task.spawn(setControlsEnabled, false)
end

local function revealLobbyHud()
	if lobbyPhaseVal.Value ~= "LOBBY" or gameStartedVal.Value then return end
	root.Visible = true
	readyBtn.Active = false
	helpBtn.Active = false
	refreshRoster()
	if hudRevealed then return end

	hudRevealed = true
	-- During the main-menu camera turn the lobby does not own the camera yet, but the
	-- player cards still need to follow that moving camera. This render step is
	-- presentation-only: it never writes camera CFrame/FOV.
	stopHudTracking()
	RunService:BindToRenderStep(hudTrackingBind, Enum.RenderPriority.Camera.Value + 2, function()
		if not hudRevealed or lobbyActive then return end
		updateSlotCardPositions()
	end)
	if hudRevealTween then hudRevealTween:Cancel() end
	root.GroupTransparency = 1
	root.Position = UDim2.fromOffset(0, 10)
	hudRevealTween = TweenService:Create(
		root,
		TweenInfo.new(.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{
			GroupTransparency = 0,
			Position = UDim2.fromOffset(0, 0),
		}
	)
	hudRevealTween:Play()
	hudRevealTween.Completed:Once(function()
		hudRevealTween = nil
	end)
	refreshDisbandVisibility()
end

local function enableLobbyInteraction()
	readyBtn.Active = true
	helpBtn.Active = true
	ContextActionService:UnbindAction(inputBind)
	ContextActionService:BindActionAtPriority(inputBind, function(_, state, input)
		if not lobbyActive then return Enum.ContextActionResult.Pass end
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			if toggleReadyRemote then toggleReadyRemote:FireServer() end
			return Enum.ContextActionResult.Sink
		elseif input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if tutorial.Visible then
				tutorial.Visible = false
			elseif disbandBtn.Visible and disbandLobbyRemote then
				disbandLobbyRemote:FireServer()
			end
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, 10000,
		Enum.KeyCode.Return, Enum.KeyCode.Space, Enum.KeyCode.ButtonA,
		Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)

	if UserInputService.GamepadEnabled then
		pcall(function() GuiService.SelectedObject = readyBtn end)
	end
	refreshDisbandVisibility()
end

local function showLobby(snapCamera)
	if player:GetAttribute("MainMenuDismissed") ~= true then return end
	if lobbyPhaseVal.Value ~= "LOBBY" or gameStartedVal.Value then return end
	revealLobbyHud()
	stopHudTracking()
	startLobbyCamera(snapCamera == true)
	enableLobbyInteraction()
end

local function prepareReturnedLobby()
	if player:GetAttribute("MainMenuDismissed") ~= true then return end
	if lobbyPhaseVal.Value ~= "LOBBY" or gameStartedVal.Value then return end

	-- Build the final staging view under black, but deliberately keep every lobby
	-- HUD element hidden and non-interactive until the transition controller reveals it.
	hudRevealed = false
	root.Visible = false
	root.GroupTransparency = 1
	readyBtn.Active = false
	helpBtn.Active = false
	ContextActionService:UnbindAction(inputBind)
	stopHudTracking()
	refreshRoster()

	local token = player:GetAttribute("LobbyReturnToken")
	if typeof(token) ~= "number" then return end
	-- Normal return path already prelocked the camera before the server started the
	-- respawn. Only start it here as a late-join/fallback path; never restart a bind
	-- that has been holding the staging view throughout RETURNING.
	if not lobbyActive then
		startLobbyCamera(true, token)
	end
end

local function revealReturnedLobby(token)
	if not returningFromRun then return end
	if typeof(token) ~= "number" or player:GetAttribute("LobbyReturnToken") ~= token then return end
	if lobbyPhaseVal.Value ~= "LOBBY" or gameStartedVal.Value then return end
	revealLobbyHud()
	stopHudTracking()
	enableLobbyInteraction()
	returningFromRun = false
	returnSettleToken = nil
	returnSettleFrames = 0
end

readyBtn.Activated:Connect(function()
	if lobbyPhaseVal.Value == "LOBBY" and toggleReadyRemote then
		toggleReadyRemote:FireServer()
	end
end)

disbandBtn.MouseEnter:Connect(function()
	disbandBtn.TextColor3 = C.Text
	disbandBtn.BackgroundTransparency = .18
end)

disbandBtn.MouseLeave:Connect(function()
	disbandBtn.TextColor3 = C.Muted
	disbandBtn.BackgroundTransparency = .34
end)

disbandBtn.Activated:Connect(function()
	if lobbyActive and disbandBtn.Visible and lobbyPhaseVal.Value == "LOBBY" and disbandLobbyRemote then
		disbandLobbyRemote:FireServer()
	end
end)

helpBtn.Activated:Connect(function()
	tutorial.Visible = true
end)

closeTutorial.Activated:Connect(function()
	tutorial.Visible = false
	if completeTutorialRemote then completeTutorialRemote:FireServer() end
end)

if disbandLobbyRemote then
	disbandLobbyRemote.OnClientEvent:Connect(function()
		if gameStartedVal.Value or lobbyPhaseVal.Value ~= "LOBBY" then return end
		player:SetAttribute("SquadHudVisible", false)
		stopLobbyPresentation()
		player:SetAttribute("MainMenuDismissed", false)
	end)
end

player:GetAttributeChangedSignal("SquadHudVisible"):Connect(function()
	if player:GetAttribute("SquadHudVisible") == true then
		-- Mid-turn pre-reveal only. MainMenu still owns the camera and input here.
		revealLobbyHud()
	elseif player:GetAttribute("MainMenuDismissed") ~= true then
		stopLobbyPresentation()
	end
end)

player:GetAttributeChangedSignal("MainMenuDismissed"):Connect(function()
	if player:GetAttribute("MainMenuDismissed") == true then
		showLobby()
	else
		stopLobbyPresentation()
	end
end)

player:GetAttributeChangedSignal("LobbyReturnCameraPrelock"):Connect(function()
	local token = player:GetAttribute("LobbyReturnCameraPrelock")
	if typeof(token) ~= "number" then return end
	if player:GetAttribute("LobbyReturnToken") ~= token then return end

	returningFromRun = true
	returnSettleToken = nil
	returnSettleFrames = 0
	hideLobbyHudForReturn()
	startLobbyCamera(true, token)
end)

lobbyPhaseVal.Changed:Connect(function(phase)
	if phase == "LOBBY" then
		local token = player:GetAttribute("LobbyReturnToken")
		local returningByToken = typeof(token) == "number"
			and player:GetAttribute("LobbyReturnCameraPrelock") == token
			and player:GetAttribute("LobbyReturnCameraReady") == token
		if returningFromRun or returningByToken then
			returningFromRun = true
			prepareReturnedLobby()
		else
			showLobby(false)
		end
	elseif phase == "RETURNING" then
		returningFromRun = true
		returnSettleToken = nil
		returnSettleFrames = 0
		-- The camera was prelocked under the blackout before the server entered this
		-- phase. Preserve that exact bind through LoadCharacter/teleport/reset.
		hideLobbyHudForReturn()
	elseif phase == "SURVIVOR_SELECT" or phase == "RUN" then
		stopLobbyPresentation()
	end
end)

player:GetAttributeChangedSignal("LobbyReturnRevealHud"):Connect(function()
	revealReturnedLobby(player:GetAttribute("LobbyReturnRevealHud"))
end)

Players.PlayerAdded:Connect(function(p)
	connectPlayer(p)
	refreshRoster()
end)

Players.PlayerRemoving:Connect(function(p)
	disconnectPlayer(p)
	task.defer(refreshRoster)
end)

for _, p in ipairs(Players:GetPlayers()) do connectPlayer(p) end
refreshRoster()

gameStartedVal.Changed:Connect(function(started)
	if started then stopLobbyPresentation() end
end)

if player:GetAttribute("MainMenuDismissed") == true and lobbyPhaseVal.Value == "LOBBY" then
	showLobby()
elseif player:GetAttribute("SquadHudVisible") == true and lobbyPhaseVal.Value == "LOBBY" then
	revealLobbyHud()
end

script.Destroying:Connect(function()
	stopLobbyPresentation()
	for p in pairs(playerConnections) do disconnectPlayer(p) end
	if lobbyPhaseVal.Value == "RUN" then setControlsEnabled(true) end
end)
