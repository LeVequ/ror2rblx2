local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local showcaseRemote = ReplicatedStorage:WaitForChild("PlayShowcaseRemote", 10)
local confirmDeployRemote = ReplicatedStorage:WaitForChild("ConfirmDeployRemote", 10)
local selectClassRemote = ReplicatedStorage:WaitForChild("SelectClassRemote", 10)
local deploymentRemote = ReplicatedStorage:WaitForChild("DeploymentRemote", 10)
local returnLobbyRemote = ReplicatedStorage:WaitForChild("ReturnLobbyRemote", 10)
local gameStartedVal = ReplicatedStorage:WaitForChild("GameStarted", 10)
local lobbyPhaseVal = ReplicatedStorage:WaitForChild("LobbyPhase", 10)
local screenGui = player:WaitForChild("PlayerGui"):WaitForChild("LobbyUI")

screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = math.max(screenGui.DisplayOrder, 70)

local C = {
	Ink = Color3.fromRGB(7, 11, 16), Panel = Color3.fromRGB(22, 31, 39),
	Selected = Color3.fromRGB(190, 214, 221), Text = Color3.fromRGB(229, 239, 242),
	Muted = Color3.fromRGB(126, 148, 157), Dark = Color3.fromRGB(18, 30, 36),
	Accent = Color3.fromRGB(128, 202, 219), AccentSoft = Color3.fromRGB(69, 116, 128),
}

local CLASSES = {
	Gunner = {role="RANGED PRESSURE // MOBILE ASSAULT", summary="Sustained ranged pressure with a heavy secondary and straightforward repositioning.", stats={"100 HP","STANDARD MOBILITY","LOW COMPLEXITY"}, skills={
		{"M1","PRIMARY","AUTO LASER CANNON","Rapid sustained energy fire."},
		{"M2","SECONDARY","HEAVY PIERCING SHOT","Heavy shot that punches through targets."},
		{"SHIFT","UTILITY","TACTICAL DASH","Quick burst of forward movement."},
		{"R","SPECIAL","ORBITAL STRIKE","Targeted high-yield area burst."},
	}},
	Ranger = {role="PRECISION // HIGH MOBILITY", summary="Fast precision pressure built around instant repositioning and area denial.", stats={"90 HP","HIGH MOBILITY","MEDIUM COMPLEXITY"}, skills={
		{"M1","PRIMARY","SEEKING ENERGY ARROWS","Rapid long-range seeking arrows."},
		{"M2","SECONDARY","PIERCING ARROW","Focused heavy precision shot."},
		{"SHIFT","UTILITY","BLINK STEP","Instant forward displacement."},
		{"R","SPECIAL","ARROW RAIN","High-damage barrage over an area."},
	}},
	Brawler = {role="MELEE BURST // DURABLE", summary="Durable close-range pressure that turns movement into explosive melee bursts.", stats={"150 HP","HIGH MOBILITY","MEDIUM COMPLEXITY"}, skills={
		{"M1","PRIMARY","IRON FIST COMBO","Fast strikes with forward momentum."},
		{"M2","SECONDARY","MOUNTAIN SPLITTER","Charging palm shockwave."},
		{"SHIFT","UTILITY","GALE FLASH STEP","High-speed aggressive dash."},
		{"R","SPECIAL","EIGHT-POLE SPIRIT SLAM","Leap into a devastating shockwave."},
	}},
	Weaver = {role="CONTROL // GRAPPLE MOBILITY", summary="Control targets with web pressure, then dictate distance with grapple movement.", stats={"100 HP","VERY HIGH MOBILITY","HIGH COMPLEXITY"}, skills={
		{"M1","PRIMARY","WEB SHOOTERS","Rapid web projectiles."},
		{"M2","SECONDARY","WEB SNARE","Briefly pin and burst a target."},
		{"SHIFT","UTILITY","GRAPPLE ZIP","Grapple terrain and pull forward."},
		{"R","SPECIAL","WEB SLAM","Pull enemies inward and detonate."},
	}},
}
local CLASS_ORDER = {"Gunner", "Ranger", "Brawler", "Weaver"}

local function make(className, name, parent, props)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local obj = Instance.new(className); obj.Name = name
	for k, v in pairs(props or {}) do obj[k] = v end
	obj.Parent = parent
	return obj
end

local function getOrCreate(className, name, parent, props)
	local obj = parent:FindFirstChild(name)
	if not obj then obj = Instance.new(className); obj.Name = name; obj.Parent = parent end
	for k, v in pairs(props or {}) do obj[k] = v end
	return obj
end

local function stroke(parent, color, transparency)
	return make("UIStroke", "Stroke", parent, {Color=color, Thickness=1, Transparency=transparency or 0})
end

local function tw(obj, duration, props)
	local t = TweenService:Create(obj, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play(); return t
end

local oldCard = screenGui:FindFirstChild("ShowcaseCard")
if oldCard then oldCard:Destroy() end

-- Survivor select uses a darker grade than the title / squad staging screens.
-- This keeps the industrial bay low-key and lets the local character lights do
-- the visual work instead of globally lifting the entire scene.
local oldSelectGrade = Lighting:FindFirstChild("SurvivorSelectGrade")
if oldSelectGrade then oldSelectGrade:Destroy() end
local selectGrade = Instance.new("ColorCorrectionEffect")
selectGrade.Name = "SurvivorSelectGrade"
selectGrade.Brightness = -0.08
selectGrade.Contrast = 0.16
selectGrade.Saturation = -0.16
selectGrade.TintColor = Color3.fromRGB(198, 217, 224)
selectGrade.Enabled = false
selectGrade.Parent = Lighting

local flow = getOrCreate("Frame", "FlowTransition", screenGui, {
	Size=UDim2.fromScale(1,1), Position=UDim2.fromScale(0,0), BackgroundColor3=Color3.new(0,0,0),
	BackgroundTransparency=1, BorderSizePixel=0, ZIndex=100, Visible=true,
})

local rootGui = make("Frame", "ShowcaseRoot", screenGui, {Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Visible=false, ZIndex=20})

-- RoR2-style composition: the UI owns the left side while the 3D survivor gets
-- clean negative space on the right.  The gradient is intentionally much darker
-- at the far-left edge and fades before reaching the presentation character.
local shade = make("Frame", "LeftShade", rootGui, {Size=UDim2.fromScale(.60,1), BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=.08, BorderSizePixel=0, ZIndex=20})
make("UIGradient", "Gradient", shade, {Transparency=NumberSequence.new({
	NumberSequenceKeypoint.new(0,.02),
	NumberSequenceKeypoint.new(.58,.23),
	NumberSequenceKeypoint.new(.84,.64),
	NumberSequenceKeypoint.new(1,1),
})})
local bottomShade = make("Frame", "BottomShade", rootGui, {Size=UDim2.fromScale(1,.22), Position=UDim2.fromScale(0,.78), BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=.46, BorderSizePixel=0, ZIndex=20})
make("UIGradient", "Gradient", bottomShade, {Rotation=90, Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,.18)})})

local phase = make("TextLabel", "Phase", rootGui, {
		Size=UDim2.new(.44,0,0,24), Position=UDim2.fromScale(.045,.085), BackgroundTransparency=1,
		Text="CHARACTER SELECT", TextColor3=C.Text, TextSize=18, Font=Enum.Font.GothamBold,
		TextXAlignment=Enum.TextXAlignment.Left, ZIndex=23,
})
local phaseRule = make("Frame", "PhaseRule", rootGui, {
		Size=UDim2.new(0,360,0,2), Position=UDim2.fromScale(.045,.123), BackgroundColor3=C.AccentSoft,
		BackgroundTransparency=.35, BorderSizePixel=0, ZIndex=23,
})

local classRail = make("Frame", "ClassRail", rootGui, {Size=UDim2.new(0,300,0,64), Position=UDim2.fromScale(.045,.145), BackgroundTransparency=1, ZIndex=24})
local classButtons = {}
local classGlyphs = {}
for i, className in ipairs(CLASS_ORDER) do
	local button = make("TextButton", className.."Button", classRail, {
		Size=UDim2.fromOffset(62,62), Position=UDim2.new(0,(i-1)*70,0,0),
		BackgroundColor3=C.Panel, BackgroundTransparency=.08, BorderSizePixel=0,
		AutoButtonColor=false, Text="", Selectable=true, ZIndex=25,
	})
	stroke(button,C.AccentSoft,.7)
	local glyph = make("TextLabel", "Glyph", button, {
		Size=UDim2.new(1,0,1,-17), BackgroundTransparency=1,
		Text=string.sub(string.upper(className),1,1), TextColor3=C.Text,
		TextSize=26, Font=Enum.Font.GothamBlack, ZIndex=26,
	})
	make("TextLabel", "Name", button, {
		Size=UDim2.new(1,-4,0,15), Position=UDim2.new(0,2,1,-16), BackgroundTransparency=1,
		Text=string.upper(className), TextColor3=C.Muted, TextSize=7,
		Font=Enum.Font.GothamBold, TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=26,
	})
	classButtons[className]=button
	classGlyphs[className]=glyph
end

local title = make("TextLabel", "ClassTitle", rootGui, {
		Size=UDim2.new(.44,0,0,42), Position=UDim2.fromScale(.045,.245), BackgroundTransparency=1,
		Text="GUNNER", TextColor3=C.Text, TextSize=32, Font=Enum.Font.GothamBlack,
		TextXAlignment=Enum.TextXAlignment.Left, ZIndex=23,
})
local role = make("TextLabel", "Role", rootGui, {
		Size=UDim2.new(.44,0,0,20), Position=UDim2.fromScale(.045,.298), BackgroundTransparency=1,
		Text="", TextColor3=C.Accent, TextSize=10, Font=Enum.Font.GothamBold,
		TextXAlignment=Enum.TextXAlignment.Left, ZIndex=23,
})

local panel = make("Frame", "LoadoutPanel", rootGui, {
		Size=UDim2.new(.36,0,0,348), Position=UDim2.fromScale(.045,.342),
		BackgroundColor3=C.Ink, BackgroundTransparency=.18, BorderSizePixel=0, ZIndex=22,
})
make("UISizeConstraint", "Size", panel, {MinSize=Vector2.new(390,330), MaxSize=Vector2.new(520,370)}); stroke(panel,C.AccentSoft,.5)

local overviewTab = make("TextLabel", "OverviewTab", panel, {
	Size=UDim2.new(.5,-1,0,28), BackgroundColor3=C.Panel, BackgroundTransparency=.3,
	BorderSizePixel=0, Text="OVERVIEW", TextColor3=C.Muted, TextSize=9,
	Font=Enum.Font.GothamBold, ZIndex=23,
})
local skillsTab = make("TextLabel", "SkillsTab", panel, {
	Size=UDim2.new(.5,-1,0,28), Position=UDim2.new(.5,1,0,0), BackgroundColor3=C.Selected,
	BorderSizePixel=0, Text="SKILLS", TextColor3=C.Dark, TextSize=9,
	Font=Enum.Font.GothamBold, ZIndex=23,
})
local stats = make("TextLabel", "Stats", panel, {
	Size=UDim2.new(1,-24,0,26), Position=UDim2.new(0,12,0,37), BackgroundTransparency=1,
	Text="", TextColor3=C.Text, TextSize=9, Font=Enum.Font.GothamBold,
	TextXAlignment=Enum.TextXAlignment.Left, ZIndex=23,
})
local summary = make("TextLabel", "Summary", panel, {
	Size=UDim2.new(1,-24,0,39), Position=UDim2.new(0,12,0,62), BackgroundTransparency=1,
	Text="", TextColor3=C.Muted, TextSize=10, Font=Enum.Font.GothamMedium, TextWrapped=true,
	TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, ZIndex=23,
})

local list = make("Frame", "Skills", panel, {Size=UDim2.new(1,-24,1,-108), Position=UDim2.new(0,12,0,104), BackgroundTransparency=1, ZIndex=23})
make("UIListLayout", "Layout", list, {FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,5)})
local rows = {}
for i=1,4 do
	local row = make("Frame", "Skill"..i, list, {Size=UDim2.new(1,0,0,54), LayoutOrder=i, BackgroundColor3=C.Panel, BackgroundTransparency=.16, BorderSizePixel=0, ZIndex=24}); stroke(row,C.AccentSoft,.76)
	local key = make("TextLabel", "Key", row, {Size=UDim2.new(0,50,1,0), BackgroundColor3=C.Selected, BackgroundTransparency=.03, BorderSizePixel=0, Text="", TextColor3=C.Dark, TextSize=10, Font=Enum.Font.GothamBold, ZIndex=25})
	local slot = make("TextLabel", "Slot", row, {Size=UDim2.new(1,-64,0,12), Position=UDim2.new(0,61,0,4), BackgroundTransparency=1, Text="", TextColor3=C.Accent, TextSize=7, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=25})
	local name = make("TextLabel", "Name", row, {Size=UDim2.new(1,-64,0,17), Position=UDim2.new(0,61,0,15), BackgroundTransparency=1, Text="", TextColor3=C.Text, TextSize=11, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=25})
	local desc = make("TextLabel", "Description", row, {Size=UDim2.new(1,-64,0,18), Position=UDim2.new(0,61,0,32), BackgroundTransparency=1, Text="", TextColor3=C.Muted, TextSize=8, Font=Enum.Font.Gotham, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, ZIndex=25})
	rows[i]={key,slot,name,desc}
end

local navHint = make("TextLabel", "NavigationHint", rootGui, {
		Size=UDim2.new(.40,0,0,18), Position=UDim2.fromScale(.045,.875), BackgroundTransparency=1,
		Text="A / D   OR   ← / →   CHANGE SURVIVOR", TextColor3=C.Muted, TextSize=8,
		Font=Enum.Font.GothamMedium, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=23,
})

local squad = make("TextLabel", "Squad", rootGui, {
	Size=UDim2.new(0,300,0,20), Position=UDim2.new(1,-328,1,-126), BackgroundTransparency=1,
	Text="", TextColor3=C.Muted, TextSize=9, Font=Enum.Font.GothamMedium,
	TextXAlignment=Enum.TextXAlignment.Right, ZIndex=23,
})
local deploy = make("TextButton", "DeployBtn", rootGui, {
	Size=UDim2.new(0,300,0,52), Position=UDim2.new(1,-328,1,-98),
	BackgroundColor3=C.Selected, BorderSizePixel=0, AutoButtonColor=false,
	Text="CONFIRM SURVIVOR", TextColor3=C.Dark, TextSize=15, Font=Enum.Font.GothamBold,
	Selectable=true, ZIndex=24,
}); stroke(deploy,C.Accent,.18)
local hint = make("TextLabel", "DeployHint", rootGui, {
	Size=UDim2.new(0,300,0,18), Position=UDim2.new(1,-328,1,-38), BackgroundTransparency=1,
	Text="ENTER / A   CONFIRM SURVIVOR", TextColor3=C.Muted, TextSize=8,
	Font=Enum.Font.GothamMedium, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=24,
})

local active = false
local confirmed = false
local generation = 0
local cameraBind = "ByteforceShowcaseCamera"
local movementLockBind = "ByteforceShowcaseMovementLock"
local deploymentCameraBind = "ByteforceDeploymentCamera"
local controls
local presentationFillAttachment
local deploymentActive = false
local deploymentPrimed = false
local deploymentBlackoutReady = false
local deploymentPod = nil
local deploymentGroundPosition = nil
local deploymentGroundForward = nil
local deploymentGroundRight = nil
local deploymentLandingPosition = nil
local deploymentGeneration = 0
local deploymentStartTime = 0
local deploymentDuration = 1
local impactImpulse = 0
local impactStarted = nil
local hatchReframeStarted = nil
local returningToLobby = false
local activeReturnToken = nil
local returnRevealInProgress = false

local hiddenPresentationState = {}

local function hidePresentationFolder(folderName)
	local folder = workspace:FindFirstChild(folderName)
	if not folder then return end

	for _, descendant in ipairs(folder:GetDescendants()) do
		if hiddenPresentationState[descendant] == nil then
			if descendant:IsA("BasePart") then
				hiddenPresentationState[descendant] = {
					Kind = "BasePart",
					LocalTransparencyModifier = descendant.LocalTransparencyModifier,
				}
				descendant.LocalTransparencyModifier = 1
			elseif descendant:IsA("Light") then
				hiddenPresentationState[descendant] = {
					Kind = "Light",
					Enabled = descendant.Enabled,
				}
				descendant.Enabled = false
			elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
				hiddenPresentationState[descendant] = {
					Kind = "Effect",
					Enabled = descendant.Enabled,
				}
				descendant.Enabled = false
			end
		end
	end
end

local function hideFrontendPresentation()
	hidePresentationFolder("ByteforceFrontendLobby")
	hidePresentationFolder("ByteforceShowcaseScene")
end

local function restoreFrontendPresentation()
	for descendant, state in pairs(hiddenPresentationState) do
		if descendant and descendant.Parent then
			if state.Kind == "BasePart" then
				descendant.LocalTransparencyModifier = state.LocalTransparencyModifier
			elseif state.Kind == "Light" or state.Kind == "Effect" then
				descendant.Enabled = state.Enabled
			end
		end
		hiddenPresentationState[descendant] = nil
	end
end

local function destroyPresentationFill()
	if presentationFillAttachment and presentationFillAttachment.Parent then
		presentationFillAttachment:Destroy()
	end
	presentationFillAttachment=nil
end

local function createPresentationFill(rootPart)
	destroyPresentationFill()
	if not rootPart or not rootPart.Parent then return end

	-- Keep the hero readable independently of Roblox's delayed world-light/shadow
	-- refresh after the large teleport into the showcase bay. This attachment is
	-- client-only, unshadowed, and exists only during survivor select.
	local attachment=Instance.new("Attachment")
	attachment.Name="SurvivorSelectFillAttachment"
	attachment.CFrame=CFrame.new(-2.5,4.4,5)
	attachment.Parent=rootPart

	local fill=Instance.new("PointLight")
	fill.Name="SurvivorSelectFill"
	fill.Color=Color3.fromRGB(181,210,219)
	fill.Brightness=1.05
	fill.Range=18
	fill.Shadows=false
	fill.Enabled=true
	fill.Parent=attachment

	presentationFillAttachment=attachment
end

local function tweenFlow(alpha, duration)
	local t = TweenService:Create(flow, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency=alpha})
	t:Play(); return t
end

local function getControls()
	if controls then return controls end
	local ok, result = pcall(function()
		local ps = player:WaitForChild("PlayerScripts",3)
		local pm = ps and ps:WaitForChild("PlayerModule",3)
		return pm and require(pm):GetControls()
	end)
	if ok then controls=result end
	return controls
end

local function setControls(enabled)
	local c = getControls(); if not c then return end
	pcall(function() if enabled then c:Enable() else c:Disable() end end)
end

local function refreshSquad()
	local n=#Players:GetPlayers(); squad.Text=string.format("SQUAD // %d OPERATIVE%s   ",n,n==1 and "" or "S")
end
Players.PlayerAdded:Connect(refreshSquad); Players.PlayerRemoving:Connect(refreshSquad); refreshSquad()

local function refreshLoadout()
	local cls=player:GetAttribute("SelectedClass") or "Gunner"; local data=CLASSES[cls] or CLASSES.Gunner
	title.Text=string.upper(cls); role.Text=data.role; summary.Text=data.summary; stats.Text="   "..table.concat(data.stats,"     //     ")
	for i, skill in ipairs(data.skills) do
		rows[i][1].Text=skill[1]; rows[i][2].Text=skill[2]; rows[i][3].Text=skill[3]; rows[i][4].Text=skill[4]
	end
	for name, button in pairs(classButtons) do
		local selected = name == cls
		button.BackgroundColor3 = selected and C.Selected or C.Panel
		button.BackgroundTransparency = selected and 0 or .08
		local glyph = classGlyphs[name]
		if glyph then glyph.TextColor3 = selected and C.Dark or C.Text end
		local nameLabel = button:FindFirstChild("Name")
		if nameLabel then nameLabel.TextColor3 = selected and C.Dark or C.Muted end
		local border = button:FindFirstChild("Stroke")
		if border then
			border.Color = selected and C.Accent or C.AccentSoft
			border.Transparency = selected and .08 or .7
		end
		button.Active = active and not confirmed
	end
end

local function setShowcaseGrade(enabled)
	selectGrade.Enabled = enabled
	local sharedBloom = Lighting:FindFirstChild("MainMenuBloom")
	if sharedBloom and sharedBloom:IsA("BloomEffect") then
		-- The title screen can afford a broad glow; survivor select should reserve
		-- bloom for the small practical lights and podium edge.
		sharedBloom.Intensity = enabled and 0.2 or 0.45
		sharedBloom.Size = enabled and 24 or 34
		sharedBloom.Threshold = enabled and 1.35 or 1.1
	end
end
player:GetAttributeChangedSignal("SelectedClass"):Connect(refreshLoadout); refreshLoadout()

local function stopCamera() RunService:UnbindFromRenderStep(cameraBind) end
local function stopDeploymentCamera() RunService:UnbindFromRenderStep(deploymentCameraBind) end
local function restoreCamera()
	stopCamera(); stopDeploymentCamera(); camera.CameraType=Enum.CameraType.Custom; camera.FieldOfView=70
	local char=player.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if hum then camera.CameraSubject=hum end
end

local function showcaseCameraFrame(rootPart, t)
	local right=rootPart.CFrame.RightVector
	local forward=rootPart.CFrame.LookVector
	-- Aim off the presentation character so the survivor reads on the right third
	-- of the screen instead of sitting under the UI. The tiny time-based offsets are
	-- ambient drift only; the transition into this framing is handled by the black
	-- screen, so there should never be a visible camera travel into survivor select.
	local focus=rootPart.Position+Vector3.new(0,1.45,0)+right*4.4
	local pos=rootPart.Position
		+forward*(14.8+math.sin(t*.16)*.12)
		+right*(2.4+math.sin(t*.11)*.16)
		+Vector3.new(0,3.05+math.sin(t*.14)*.05,0)
	return CFrame.lookAt(pos,focus)
end

local function startCamera(rootPart)
	stopCamera()
	camera.CameraType=Enum.CameraType.Scriptable
	camera.CFrame=showcaseCameraFrame(rootPart,0)
	camera.FieldOfView=48

	local started=os.clock()
	RunService:BindToRenderStep(cameraBind,Enum.RenderPriority.Camera.Value+1,function()
		if not active or not rootPart.Parent then return end
		local t=os.clock()-started
		camera.CFrame=showcaseCameraFrame(rootPart,t)
		camera.FieldOfView=48
	end)
end

local function deployVisual(done)
	confirmed=done; deploy.Active=not done
	deploy.Text=done and "SURVIVOR LOCKED" or "CONFIRM SURVIVOR"
	deploy.BackgroundColor3=done and C.Panel or C.Selected; deploy.TextColor3=done and C.Muted or C.Dark
	hint.Text=done and "WAITING FOR SQUAD..." or "ENTER / A  CONFIRM SURVIVOR"
	refreshLoadout()
end

local function selectClass(className)
	if not active or confirmed or lobbyPhaseVal.Value ~= "SURVIVOR_SELECT" then return end
	if selectClassRemote then selectClassRemote:FireServer(className) end
end

for className, button in pairs(classButtons) do
	button.Activated:Connect(function() selectClass(className) end)
end

local function cycleClass(delta)
	if confirmed or not active then return end
	local current = player:GetAttribute("SelectedClass") or "Gunner"
	local index = table.find(CLASS_ORDER, current) or 1
	index = ((index - 1 + delta) % #CLASS_ORDER) + 1
	selectClass(CLASS_ORDER[index])
end

local function confirm()
	if not active or confirmed then return end
	deployVisual(true); if confirmDeployRemote then confirmDeployRemote:FireServer() end
end
deploy.Activated:Connect(confirm)

local function onInput(_, state, input)
	if not active then return Enum.ContextActionResult.Pass end
	if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	if input.KeyCode==Enum.KeyCode.Left or input.KeyCode==Enum.KeyCode.A or input.KeyCode==Enum.KeyCode.DPadLeft or input.KeyCode==Enum.KeyCode.ButtonL1 then cycleClass(-1); return Enum.ContextActionResult.Sink end
	if input.KeyCode==Enum.KeyCode.Right or input.KeyCode==Enum.KeyCode.D or input.KeyCode==Enum.KeyCode.DPadRight or input.KeyCode==Enum.KeyCode.ButtonR1 then cycleClass(1); return Enum.ContextActionResult.Sink end
	if input.KeyCode==Enum.KeyCode.Return or input.KeyCode==Enum.KeyCode.Space or input.KeyCode==Enum.KeyCode.ButtonA then confirm(); return Enum.ContextActionResult.Sink end
	return Enum.ContextActionResult.Pass
end
local function bindInput()
	ContextActionService:BindActionAtPriority(movementLockBind,function()
		if active then return Enum.ContextActionResult.Sink end
		return Enum.ContextActionResult.Pass
	end,false,10000,
		Enum.KeyCode.W,Enum.KeyCode.S,
		Enum.KeyCode.Up,Enum.KeyCode.Down,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.Thumbstick1,
		Enum.KeyCode.DPadUp,Enum.KeyCode.DPadDown)
	ContextActionService:BindActionAtPriority("ByteforceShowcaseInput",onInput,false,9000,
		Enum.KeyCode.Return,Enum.KeyCode.Space,Enum.KeyCode.ButtonA,
		Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.A,Enum.KeyCode.D,
		Enum.KeyCode.DPadLeft,Enum.KeyCode.DPadRight,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1)
	if UserInputService.GamepadEnabled then pcall(function() GuiService.SelectedObject=deploy end) end
end
local function unbindInput()
	ContextActionService:UnbindAction(movementLockBind)
	ContextActionService:UnbindAction("ByteforceShowcaseInput"); pcall(function() if GuiService.SelectedObject==deploy then GuiService.SelectedObject=nil end end)
end

local function hideLobby()
	for _,n in ipairs({"LobbyRoot","LobbyFrame","LobbyBackdrop","TutorialModal","StoryModal","RestoreBtn"}) do local o=screenGui:FindFirstChild(n); if o and o:IsA("GuiObject") then o.Visible=false end end
end

local function showShowcase()
	if lobbyPhaseVal.Value ~= "SURVIVOR_SELECT" then return end
	restoreFrontendPresentation()
	deploymentBlackoutReady=false
	player:SetAttribute("DeploymentBlackoutReady", false)
	generation+=1; local mine=generation; deployVisual(false); refreshLoadout(); flow.BackgroundTransparency=1
	local cover=tweenFlow(0,.18); cover.Completed:Wait(); if mine~=generation then return end
	local char=player.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then flow.BackgroundTransparency=1; return end

	-- Everything below this point happens while the screen is fully black. Do not
	-- reveal the overlay again until the showcase camera, local post effects and the
	-- first few rendered lighting frames are already settled.
	hideLobby()
	active=true
	setControls(false)
	setShowcaseGrade(true)
	createPresentationFill(hrp)
	startCamera(hrp)
	bindInput()
	refreshLoadout()
	phase.TextTransparency=1
	phaseRule.BackgroundTransparency=1
	title.TextTransparency=1
	role.TextTransparency=1
	classRail.Position=UDim2.fromScale(.025,.145)
	panel.Position=UDim2.fromScale(.025,.342)
	panel.BackgroundTransparency=1
	navHint.TextTransparency=1
	squad.TextTransparency=1
	deploy.Position=UDim2.new(1,-304,1,-98)
	deploy.BackgroundTransparency=1
	hint.TextTransparency=1
	rootGui.Visible=true

	-- A large spatial camera jump can take Roblox several frames to rebuild the
	-- nearby lighting/shadow state. In Studio this was visibly longer than a simple
	-- 2-4 frame wait: the survivor first appeared as a black silhouette and only then
	-- received the bay lighting. Keep the transition fully opaque for a short,
	-- deterministic warm-up window so that renderer work happens off-screen.
	local warmupStarted=os.clock()
	repeat
		RunService.RenderStepped:Wait()
		if mine~=generation or not active then return end
	until os.clock()-warmupStarted>=.5
	tweenFlow(1,.30)
	tw(phase,.22,{TextTransparency=0})
	tw(phaseRule,.28,{BackgroundTransparency=.35})
	tw(classRail,.28,{Position=UDim2.fromScale(.045,.145)})
	tw(title,.25,{TextTransparency=0})
	tw(role,.3,{TextTransparency=0})
	tw(panel,.3,{Position=UDim2.fromScale(.045,.342),BackgroundTransparency=.18})
	tw(navHint,.34,{TextTransparency=0})
	tw(squad,.3,{TextTransparency=0})
	tw(deploy,.3,{Position=UDim2.new(1,-328,1,-98),BackgroundTransparency=0})
	tw(hint,.34,{TextTransparency=0})
end

local function findLocalDeploymentPod(timeout)
	local deadline=os.clock()+(timeout or 3)
	repeat
		local folder=workspace:FindFirstChild("ByteforceDropPods")
		if folder then
			for _,candidate in ipairs(folder:GetChildren()) do
				if candidate:IsA("Model") and candidate:GetAttribute("OwnerUserId")==player.UserId then
					return candidate
				end
			end
		end
		RunService.Heartbeat:Wait()
	until os.clock()>=deadline
	return nil
end

local function deploymentFormationCenter(fallbackPod)
	local folder=workspace:FindFirstChild("ByteforceDropPods")
	if not folder then return fallbackPod:GetPivot().Position end
	local total=Vector3.zero
	local count=0
	for _,candidate in ipairs(folder:GetChildren()) do
		if candidate:IsA("Model") and candidate:GetAttribute("DeploymentPod") then
			total+=candidate:GetPivot().Position
			count+=1
		end
	end
	return count>0 and total/count or fallbackPod:GetPivot().Position
end

local function cacheDeploymentGroundAnchor(pod)
	local podCF=pod:GetPivot()
	local landing=pod:GetAttribute("LandingPosition")
	if typeof(landing)~="Vector3" then landing=podCF.Position-Vector3.new(0,420,0) end

	local forward=pod:GetAttribute("LandingForward")
	if typeof(forward)~="Vector3" then forward=Vector3.new(podCF.LookVector.X,0,podCF.LookVector.Z) end
	forward=Vector3.new(forward.X,0,forward.Z)
	forward=forward.Magnitude>.01 and forward.Unit or Vector3.new(0,0,-1)

	local right=pod:GetAttribute("LandingRight")
	if typeof(right)~="Vector3" then right=Vector3.new(podCF.RightVector.X,0,podCF.RightVector.Z) end
	right=Vector3.new(right.X,0,right.Z)
	right=right.Magnitude>.01 and right.Unit or Vector3.new(1,0,0)

	deploymentLandingPosition=landing
	deploymentGroundForward=forward
	deploymentGroundRight=right
	-- This world-space position is intentionally calculated exactly once. Nothing in
	-- the descent is allowed to replace it with a pod-relative/chase camera position.
	deploymentGroundPosition=landing+forward*20+right*7+Vector3.new(0,2.6,0)
end

local function deploymentCameraFrame(pod, serverNow)
	local podCF=pod:GetPivot()
	local raw=math.clamp((serverNow-deploymentStartTime)/math.max(deploymentDuration,.01),0,1)
	local braking=math.clamp((raw-.68)/.32,0,1)
	local hatchBlend=0
	if hatchReframeStarted then
		hatchBlend=TweenService:GetValue(math.clamp((os.clock()-hatchReframeStarted)/.55,0,1),Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	end
	local landing=deploymentLandingPosition or pod:GetAttribute("LandingPosition")
	if typeof(landing)~="Vector3" then landing=podCF.Position-Vector3.new(0,420,0) end
	local forward=deploymentGroundForward or Vector3.new(0,0,-1)
	local right=deploymentGroundRight or Vector3.new(1,0,0)
	local groundPosition=deploymentGroundPosition or (landing+forward*20+right*7+Vector3.new(0,2.6,0))

	-- The camera is physically pinned to one terrain position for the entire cinematic.
	-- Only its look target and FOV are allowed to change while the pod descends.
	local formationCenter=deploymentFormationCenter(pod)
	local formationTarget=formationCenter+Vector3.new(0,-3,0)
	local podTarget=podCF.Position+Vector3.new(0,-.15,0)
	local targetBlend=TweenService:GetValue(math.clamp((raw-.32)/.28,0,1),Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
	local target=formationTarget:Lerp(podTarget,targetBlend)

	-- Tighten the lens as the capsule grows instead of moving the camera toward it.
	local fovBlend=TweenService:GetValue(math.clamp((raw-.20)/.62,0,1),Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
	local fov=72+(53-72)*fovBlend-(braking*2)

	-- Once the hatch fires, keep the exact same camera position and simply lower the
	-- aim toward the landed pod/survivor. There is no post-impact hero-position slide.
	if hatchBlend>0 then
		local heroTarget=landing+Vector3.new(0,2.1,0)
		target=target:Lerp(heroTarget,hatchBlend)
		fov=fov+(50-fov)*hatchBlend
	end

	local frame=CFrame.lookAt(groundPosition,target)

	if impactImpulse>0 then
		local t=os.clock()*82
		local amp=impactImpulse
		-- Shake orientation/lens only. Translation would make the supposedly planted
		-- terrain camera hover around at the moment of impact.
		local pitch=math.rad(math.sin(t*1.27)*1.25*amp)
		local yaw=math.rad(math.sin(t*.83)*1.05*amp)
		local roll=math.rad(math.sin(t*1.61)*.7*amp)
		frame=frame*CFrame.Angles(pitch,yaw,roll)
		fov+=2.4*amp
	end

	return frame,fov
end

local function primeDeploymentTransition()
	if deploymentActive then return end
	if deploymentPrimed then
		while deploymentPrimed and not deploymentBlackoutReady and lobbyPhaseVal.Value=="DEPLOYING" do
			RunService.RenderStepped:Wait()
		end
		return
	end
	deploymentPrimed=true
	deploymentBlackoutReady=false
	player:SetAttribute("DeploymentBlackoutReady", false)

	-- This runs as soon as DEPLOYING begins (and is also triggered by PREPARE).
	-- The black overlay is the authority for this handoff. Nothing from the survivor
	-- select scene is dismantled until the screen is completely opaque; otherwise
	-- lighting/sky changes can leak through the tail end of the fade.
	local cover=tweenFlow(0,.12)
	cover.Completed:Wait()
	flow.BackgroundTransparency=0

	generation+=1
	active=false
	rootGui.Visible=false
	unbindInput()
	stopCamera()
	destroyPresentationFill()
	setShowcaseGrade(false)
	hideFrontendPresentation()
	setControls(false)
	camera.CameraType=Enum.CameraType.Scriptable
	deploymentBlackoutReady=true
	player:SetAttribute("DeploymentBlackoutReady", true)
end

local function beginDeployment(startTime,duration)
	deploymentGeneration+=1
	local mine=deploymentGeneration
	deploymentStartTime=startTime or workspace:GetServerTimeNow()
	deploymentDuration=duration or 6.0
	impactImpulse=0
	impactStarted=nil
	hatchReframeStarted=nil

	-- Usually PREPARE / the DEPLOYING phase has already claimed the camera. Keep an
	-- idempotent fallback here for late joins or unusual replication ordering, then
	-- wait for full black before snapping to the ground shot.
	primeDeploymentTransition()
	if not deploymentBlackoutReady then return end
	flow.BackgroundTransparency=0
	if mine~=deploymentGeneration then return end

	local pod=findLocalDeploymentPod(3)
	if mine~=deploymentGeneration then return end
	if not pod then
		warn("Deployment camera could not find the local drop pod.")
		flow.BackgroundTransparency=0
		return
	end

	deploymentPod=pod
	deploymentActive=true
	cacheDeploymentGroundAnchor(pod)
	stopDeploymentCamera()
	camera.CameraType=Enum.CameraType.Scriptable
	-- At raw=0 deploymentCameraFrame is the fixed ground/sky shot. This assignment
	-- happens while fully black, so there is no visible travel from the showcase or
	-- from the falling pod down to the landing zone.
	local initialCF,initialFov=deploymentCameraFrame(pod,workspace:GetServerTimeNow())
	camera.CFrame=initialCF
	camera.FieldOfView=initialFov

	local lastFrame=os.clock()
	RunService:BindToRenderStep(deploymentCameraBind,Enum.RenderPriority.Camera.Value+2,function()
		if not deploymentActive or mine~=deploymentGeneration or not pod.Parent then return end
		local nowClock=os.clock()
		local dt=math.clamp(nowClock-lastFrame,0,0.05)
		lastFrame=nowClock
		impactImpulse=math.max(0,impactImpulse-dt*2.65)
		local frame,fov=deploymentCameraFrame(pod,workspace:GetServerTimeNow())
		camera.CFrame=frame
		camera.FieldOfView=fov
	end)

	-- Hold black until the terrain/pod camera has rendered several frames and the
	-- synchronized descent is just beginning. This avoids exposing the huge spatial
	-- jump from the showcase bay to the live map.
	while deploymentActive and mine==deploymentGeneration and workspace:GetServerTimeNow()<deploymentStartTime-.06 do
		RunService.RenderStepped:Wait()
	end
	if not deploymentActive or mine~=deploymentGeneration then return end
	tweenFlow(1,.32)
end

local function finishDeployment()
	if not deploymentActive then return end
	deploymentGeneration+=1
	deploymentActive=false
	deploymentPrimed=false
	deploymentBlackoutReady=false
	player:SetAttribute("DeploymentBlackoutReady", false)
	deploymentGroundPosition=nil
	deploymentGroundForward=nil
	deploymentGroundRight=nil
	deploymentLandingPosition=nil
	impactImpulse=0
	impactStarted=nil
	hatchReframeStarted=nil
	stopDeploymentCamera()
	flow.BackgroundTransparency=1

	-- The deployment camera spends the hatch beat looking back toward the pod. If we
	-- hand that exact view to Roblox's shoulder camera, the landed capsule sits
	-- directly between the player and the camera. Recompose to a gameplay-ready
	-- three-quarter shoulder view first, then release camera ownership.
	local pod=deploymentPod
	local char=player.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	if pod and pod.Parent and root and root.Parent then
		local podCF=pod:GetPivot()
		local forward=Vector3.new(podCF.LookVector.X,0,podCF.LookVector.Z)
		local right=Vector3.new(podCF.RightVector.X,0,podCF.RightVector.Z)
		if forward.Magnitude>.01 and right.Magnitude>.01 then
			forward=forward.Unit
			right=right.Unit
			local target=root.Position+Vector3.new(0,1.45,0)+forward*4.5
			local targetPos=root.Position-forward*6.8+right*6.2+Vector3.new(0,4.3,0)
			local startCF=camera.CFrame
			local startFov=camera.FieldOfView
			local targetCF=CFrame.lookAt(targetPos,target)
			local started=os.clock()
			local duration=.34
			while true do
				local raw=math.clamp((os.clock()-started)/duration,0,1)
				local alpha=TweenService:GetValue(raw,Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
				camera.CFrame=startCF:Lerp(targetCF,alpha)
				camera.FieldOfView=startFov+(70-startFov)*alpha
				if raw>=1 then break end
				RunService.RenderStepped:Wait()
			end
		end
	end

	deploymentPod=nil
	restoreCamera()
	setControls(true)
end

local function enterRun()
	if deploymentActive then return end
	if not active then
		destroyPresentationFill()
		setShowcaseGrade(false)
		restoreCamera()
		setControls(true)
		tweenFlow(1,.35)
		return
	end
	generation+=1; local mine=generation; local cover=tweenFlow(0,.2); cover.Completed:Wait(); if mine~=generation then return end
	active=false; rootGui.Visible=false; unbindInput(); stopCamera(); destroyPresentationFill(); setShowcaseGrade(false)
	local char=player.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); local started=os.clock()
	while hrp and hrp.Parent and os.clock()-started<1.4 do
		if (hrp.Position-Vector3.new(0,2005,50)).Magnitude>100 then break end
		RunService.Heartbeat:Wait()
	end
	restoreCamera(); setControls(true); RunService.RenderStepped:Wait(); tweenFlow(1,.45)
end

local function prepareReturnToLobby(token)
	if typeof(token) ~= "number" then return end
	activeReturnToken = token
	returningToLobby = true
	returnRevealInProgress = false
	player:SetAttribute("LobbyReturnToken", token)
	player:SetAttribute("LobbyReturnFrontendPrepare", nil)
	player:SetAttribute("LobbyReturnFrontendReady", nil)
	player:SetAttribute("LobbyReturnCameraPrelock", nil)
	player:SetAttribute("LobbyReturnCameraReady", nil)
	player:SetAttribute("LobbyReturnCameraSettled", nil)
	player:SetAttribute("LobbyReturnRevealHud", nil)

	-- This is the only owner of the return blackout. Finish the visible fade before
	-- telling the server it may respawn/teleport/reset anything underneath it.
	flow.Visible = true
	local cover = tweenFlow(0, .18)
	cover.Completed:Wait()
	if activeReturnToken ~= token then return end
	flow.BackgroundTransparency = 0

	generation += 1
	active = false
	rootGui.Visible = false
	unbindInput()
	stopCamera()
	stopDeploymentCamera()
	destroyPresentationFill()
	setShowcaseGrade(false)
	-- Do not let PlayerModule/control resolution delay frontend restoration or the
	-- lobby camera handshake. Movement can be disabled independently while black.
	task.spawn(setControls, false)
	camera.CameraType = Enum.CameraType.Scriptable

	-- The frontend is built from normal Roblox parts/materials, so there is no
	-- external mesh/texture payload for ContentProvider to preload here. The real
	-- readiness issue is presentation state: deployment locally hid the server
	-- staging folder, while MainMenu detached its client diorama from Workspace.
	-- Restore both while fully black, then wait for MainMenu to confirm the local
	-- scene/lighting have rendered before moving the camera there.
	restoreFrontendPresentation()
	player:SetAttribute("LobbyReturnFrontendPrepare", token)
	while activeReturnToken == token
		and player:GetAttribute("LobbyReturnFrontendReady") ~= token do
		RunService.RenderStepped:Wait()
	end
	if activeReturnToken ~= token then return end

	-- Camera positioning is the next hidden operation after the frontend is ready.
	-- LobbyUI snaps/binds the final staging shot while the run is still active and
	-- reports readiness from that render bind itself. Only then may the server
	-- respawn/teleport the character.
	player:SetAttribute("LobbyReturnCameraPrelock", token)
	while activeReturnToken == token
		and player:GetAttribute("LobbyReturnCameraReady") ~= token do
		RunService.RenderStepped:Wait()
	end
	if activeReturnToken ~= token then return end

	returnLobbyRemote:FireServer("BLACKOUT_READY", token)
end

local function tryRevealReturnedLobby()
	if returnRevealInProgress then return end
	local token = player:GetAttribute("LobbyReturnToken")
	if typeof(token) ~= "number" then return end
	if lobbyPhaseVal.Value ~= "LOBBY" then return end
	if player:GetAttribute("LobbyReturnCameraPrelock") ~= token then return end
	if player:GetAttribute("LobbyReturnCameraReady") ~= token then return end
	if player:GetAttribute("LobbyReturnCameraSettled") ~= token then return end

	returnRevealInProgress = true
	task.spawn(function()
		if lobbyPhaseVal.Value ~= "LOBBY"
			or player:GetAttribute("LobbyReturnToken") ~= token
			or player:GetAttribute("LobbyReturnCameraPrelock") ~= token
			or player:GetAttribute("LobbyReturnCameraReady") ~= token
			or player:GetAttribute("LobbyReturnCameraSettled") ~= token then
			returnRevealInProgress = false
			return
		end

		-- Resolve the live overlay after respawn instead of trusting the cached
		-- reference captured before LoadCharacter. StarterGui/PlayerGui can replace
		-- GUI instances during the return, which would let a tween complete against
		-- an orphaned frame while the visible FlowTransition remains black.
		local liveLobbyGui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("LobbyUI")
		local liveFlow = liveLobbyGui and liveLobbyGui:FindFirstChild("FlowTransition")
		local revealTarget = (liveFlow and liveFlow:IsA("Frame")) and liveFlow or flow
		local reveal = TweenService:Create(
			revealTarget,
			TweenInfo.new(.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{BackgroundTransparency = 1}
		)
		reveal:Play()
		reveal.Completed:Wait()
		-- Snap the terminal value as well so a cancelled/interrupted tween cannot
		-- leave even a single opaque frame after the camera has settled.
		revealTarget.BackgroundTransparency = 1
		if lobbyPhaseVal.Value == "LOBBY" and player:GetAttribute("LobbyReturnToken") == token then
			player:SetAttribute("LobbyReturnRevealHud", token)
			player:SetAttribute("LobbyReturnFrontendPrepare", nil)
			player:SetAttribute("LobbyReturnFrontendReady", nil)
			player:SetAttribute("LobbyReturnCameraPrelock", nil)
			player:SetAttribute("LobbyReturnCameraSettled", nil)
			returningToLobby = false
			activeReturnToken = nil
		end
		returnRevealInProgress = false
	end)
end

if showcaseRemote then showcaseRemote.OnClientEvent:Connect(function() task.spawn(showShowcase) end) end
if returnLobbyRemote then returnLobbyRemote.OnClientEvent:Connect(function(action, token)
	if action == "PREPARE" then
		task.spawn(prepareReturnToLobby, token)
	end
end) end
if deploymentRemote then deploymentRemote.OnClientEvent:Connect(function(action,a,b)
			if action=="PREPARE" then
				primeDeploymentTransition()
			elseif action=="BEGIN" then
				task.spawn(beginDeployment,a,b)
		elseif action=="IMPACT" and deploymentActive then
			impactImpulse=1
			impactStarted=os.clock()
		elseif action=="HATCH" and deploymentActive then
			hatchReframeStarted=os.clock()
	elseif action=="COMPLETE" then
		finishDeployment()
	end
end) end
	if lobbyPhaseVal then lobbyPhaseVal.Changed:Connect(function(phase)
		if phase=="SURVIVOR_SELECT" and not active then
			restoreFrontendPresentation()
			deploymentPrimed=false
			deploymentBlackoutReady=false
			player:SetAttribute("DeploymentBlackoutReady", false)
			deploymentGroundPosition=nil
			deploymentGroundForward=nil
			deploymentGroundRight=nil
			deploymentLandingPosition=nil
			task.spawn(showShowcase)
			elseif phase=="DEPLOYING" then
				-- Claim the camera immediately. Waiting until BEGIN allowed the showcase
				-- camera to follow the teleported character into the high-altitude pod.
				primeDeploymentTransition()
			elseif phase=="LOBBY" then
				restoreFrontendPresentation()
						deploymentPrimed=false
						deploymentBlackoutReady=false
						player:SetAttribute("DeploymentBlackoutReady", false)
						tryRevealReturnedLobby()
						local token = player:GetAttribute("LobbyReturnToken")
						if typeof(token) == "number"
							and player:GetAttribute("LobbyReturnCameraPrelock") == token
							and player:GetAttribute("LobbyReturnCameraReady") == token then
							task.spawn(function()
								while lobbyPhaseVal.Value == "LOBBY"
									and player:GetAttribute("LobbyReturnToken") == token
									and player:GetAttribute("LobbyReturnCameraSettled") ~= token do
									RunService.RenderStepped:Wait()
								end
								tryRevealReturnedLobby()
							end)
						end
			elseif phase=="RETURNING" then
				returningToLobby=true
				generation+=1
				active=false
				rootGui.Visible=false
				unbindInput()
				stopCamera()
				stopDeploymentCamera()
				destroyPresentationFill()
				setShowcaseGrade(false)
				task.spawn(setControls, false)
				-- PREPARE normally completed the fade before RETURNING was published. If a
				-- client missed that event, keep this as a late safety cover.
				if flow.BackgroundTransparency>0 then
					tweenFlow(0,.1)
				end
				camera.CameraType=Enum.CameraType.Scriptable
			elseif phase~="SURVIVOR_SELECT" and active and phase~="RUN" then
			generation+=1
			active=false
			rootGui.Visible=false
			unbindInput()
			stopCamera()
			destroyPresentationFill()
			setShowcaseGrade(false)
			end
		end) end
	player:GetAttributeChangedSignal("LobbyReturnCameraSettled"):Connect(tryRevealReturnedLobby)
if gameStartedVal then gameStartedVal.Changed:Connect(function(started)
		if started then
			if not deploymentActive then task.spawn(enterRun) end
			elseif active then
			active=false
				rootGui.Visible=false
				unbindInput()
				stopCamera()
				destroyPresentationFill()
				setShowcaseGrade(false)
				setControls(false)
		end
end) end

if lobbyPhaseVal.Value=="SURVIVOR_SELECT" and not gameStartedVal.Value then
	task.spawn(showShowcase)
end

script.Destroying:Connect(function()
	generation+=1
	deploymentGeneration+=1
	active=false
	deploymentActive=false
	deploymentBlackoutReady=false
	player:SetAttribute("DeploymentBlackoutReady", false)
	deploymentGroundPosition=nil
	deploymentGroundForward=nil
	deploymentGroundRight=nil
	deploymentLandingPosition=nil
	unbindInput()
	stopCamera()
	stopDeploymentCamera()
	restoreFrontendPresentation()
	destroyPresentationFill()
	setShowcaseGrade(false)
	if selectGrade and selectGrade.Parent then selectGrade:Destroy() end
	setControls(true)
end)
