local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local showcaseRemote = ReplicatedStorage:WaitForChild("PlayShowcaseRemote", 10)
local confirmDeployRemote = ReplicatedStorage:WaitForChild("ConfirmDeployRemote", 10)
local selectClassRemote = ReplicatedStorage:WaitForChild("SelectClassRemote", 10)
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
	Gunner = {role="RANGED PRESSURE // MOBILE ASSAULT", summary="Reliable sustained fire, a heavy piercing secondary, and simple repositioning tools.", stats={"100 HP","STANDARD MOBILITY","LOW COMPLEXITY"}, skills={
		{"M1","PRIMARY","AUTO LASER CANNON","Rapid energy fire for consistent single-target pressure."},
		{"M2","SECONDARY","HEAVY PIERCING SHOT","High-damage blast built to punch through priority targets."},
		{"SHIFT","UTILITY","TACTICAL DASH","Burst forward to disengage, dodge, or close distance."},
		{"R","SPECIAL","ORBITAL STRIKE","Call a high-yield blast onto the aimed position."},
	}},
	Ranger = {role="PRECISION // HIGH MOBILITY", summary="Fast ranged pressure with an instant blink and strong area denial.", stats={"90 HP","HIGH MOBILITY","MEDIUM COMPLEXITY"}, skills={
		{"M1","PRIMARY","SEEKING ENERGY ARROWS","Rapid arrows for long-range pressure."},
		{"M2","SECONDARY","PIERCING ARROW","Focused heavy arrow that hits hard at range."},
		{"SHIFT","UTILITY","BLINK STEP","Instantly displace forward and break away from danger."},
		{"R","SPECIAL","ARROW RAIN","Saturate an area with a high-damage energy barrage."},
	}},
	Brawler = {role="MELEE BURST // DURABLE", summary="A close-range bruiser that converts momentum into explosive strikes and shockwaves.", stats={"150 HP","HIGH MOBILITY","MEDIUM COMPLEXITY"}, skills={
		{"M1","PRIMARY","IRON FIST COMBO","Fast close-range strikes with forward momentum."},
		{"M2","SECONDARY","MOUNTAIN SPLITTER","Charge through enemies with an explosive palm shockwave."},
		{"SHIFT","UTILITY","GALE FLASH STEP","High-speed martial dash for aggressive repositioning."},
		{"R","SPECIAL","EIGHT-POLE SPIRIT SLAM","Leap and crash down in a devastating area shockwave."},
	}},
	Weaver = {role="CONTROL // GRAPPLE MOBILITY", summary="Control targets with web pressure, then use grapple movement to dictate the engagement.", stats={"100 HP","VERY HIGH MOBILITY","HIGH COMPLEXITY"}, skills={
		{"M1","PRIMARY","WEB SHOOTERS","Rapid web projectiles for dependable ranged damage."},
		{"M2","SECONDARY","WEB SNARE","Pin a target briefly while dealing a heavy burst of damage."},
		{"SHIFT","UTILITY","GRAPPLE ZIP","Latch onto terrain and rapidly pull yourself toward it."},
		{"R","SPECIAL","WEB SLAM","Pull nearby enemies inward and detonate a powerful web burst."},
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

local flow = getOrCreate("Frame", "FlowTransition", screenGui, {
	Size=UDim2.fromScale(1,1), Position=UDim2.fromScale(0,0), BackgroundColor3=Color3.new(0,0,0),
	BackgroundTransparency=1, BorderSizePixel=0, ZIndex=100, Visible=true,
})

local rootGui = make("Frame", "ShowcaseRoot", screenGui, {Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Visible=false, ZIndex=20})
local shade = make("Frame", "LeftShade", rootGui, {Size=UDim2.fromScale(.61,1), BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=.2, BorderSizePixel=0, ZIndex=20})
make("UIGradient", "Gradient", shade, {Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.06),NumberSequenceKeypoint.new(.72,.48),NumberSequenceKeypoint.new(1,1)})})
local bottomShade = make("Frame", "BottomShade", rootGui, {Size=UDim2.fromScale(1,.25), Position=UDim2.fromScale(0,.75), BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=.34, BorderSizePixel=0, ZIndex=20})
make("UIGradient", "Gradient", bottomShade, {Rotation=90, Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,.08)})})

local phase = make("TextLabel", "Phase", rootGui, {Size=UDim2.new(.45,0,0,20), Position=UDim2.fromScale(.045,.055), BackgroundTransparency=1, Text="SURVIVOR LOADOUT // DEPLOYMENT", TextColor3=C.Accent, TextSize=12, Font=Enum.Font.GothamMedium, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=23})
local title = make("TextLabel", "ClassTitle", rootGui, {Size=UDim2.new(.45,0,0,50), Position=UDim2.fromScale(.045,.078), BackgroundTransparency=1, Text="GUNNER", TextColor3=C.Text, TextSize=38, Font=Enum.Font.GothamBlack, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=23})
local role = make("TextLabel", "Role", rootGui, {Size=UDim2.new(.45,0,0,22), Position=UDim2.fromScale(.045,.137), BackgroundTransparency=1, Text="", TextColor3=C.Muted, TextSize=13, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=23})

local classRail = make("Frame", "ClassRail", rootGui, {Size=UDim2.new(0,472,0,38), Position=UDim2.fromScale(.045,.17), BackgroundTransparency=1, ZIndex=24})
local classButtons = {}
for i, className in ipairs(CLASS_ORDER) do
	local button = make("TextButton", className.."Button", classRail, {
		Size=UDim2.new(0,112,0,34), Position=UDim2.new(0,(i-1)*120,0,0),
		BackgroundColor3=C.Panel, BorderSizePixel=0, AutoButtonColor=false,
		Text=string.upper(className), TextColor3=C.Muted, TextSize=10,
		Font=Enum.Font.GothamBold, Selectable=true, ZIndex=25,
	})
	stroke(button,C.AccentSoft,.7)
	classButtons[className]=button
end

local panel = make("Frame", "LoadoutPanel", rootGui, {Size=UDim2.new(.42,0,0,410), Position=UDim2.fromScale(.045,.225), BackgroundColor3=C.Ink, BackgroundTransparency=.14, BorderSizePixel=0, ZIndex=22})
make("UISizeConstraint", "Size", panel, {MinSize=Vector2.new(440,410), MaxSize=Vector2.new(610,465)}); stroke(panel,C.AccentSoft,.46)
local summary = make("TextLabel", "Summary", panel, {Size=UDim2.new(1,-28,0,52), Position=UDim2.new(0,14,0,12), BackgroundTransparency=1, Text="", TextColor3=C.Muted, TextSize=13, Font=Enum.Font.GothamMedium, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, ZIndex=23})
local stats = make("TextLabel", "Stats", panel, {Size=UDim2.new(1,-28,0,32), Position=UDim2.new(0,14,0,67), BackgroundColor3=C.Panel, BackgroundTransparency=.12, BorderSizePixel=0, Text="", TextColor3=C.Text, TextSize=10, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=23})

local list = make("Frame", "Skills", panel, {Size=UDim2.new(1,-28,1,-112), Position=UDim2.new(0,14,0,106), BackgroundTransparency=1, ZIndex=23})
make("UIListLayout", "Layout", list, {FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6)})
local rows = {}
for i=1,4 do
	local row = make("Frame", "Skill"..i, list, {Size=UDim2.new(1,0,0,70), LayoutOrder=i, BackgroundColor3=C.Panel, BackgroundTransparency=.1, BorderSizePixel=0, ZIndex=24}); stroke(row,C.AccentSoft,.72)
	local key = make("TextLabel", "Key", row, {Size=UDim2.new(0,58,1,0), BackgroundColor3=C.Selected, BorderSizePixel=0, Text="", TextColor3=C.Dark, TextSize=11, Font=Enum.Font.GothamBold, ZIndex=25})
	local slot = make("TextLabel", "Slot", row, {Size=UDim2.new(1,-76,0,15), Position=UDim2.new(0,70,0,6), BackgroundTransparency=1, Text="", TextColor3=C.Accent, TextSize=9, Font=Enum.Font.GothamMedium, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=25})
	local name = make("TextLabel", "Name", row, {Size=UDim2.new(1,-76,0,20), Position=UDim2.new(0,70,0,21), BackgroundTransparency=1, Text="", TextColor3=C.Text, TextSize=13, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=25})
	local desc = make("TextLabel", "Description", row, {Size=UDim2.new(1,-76,0,24), Position=UDim2.new(0,70,0,42), BackgroundTransparency=1, Text="", TextColor3=C.Muted, TextSize=10, Font=Enum.Font.Gotham, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, ZIndex=25})
	rows[i]={key,slot,name,desc}
end

local squad = make("TextLabel", "Squad", rootGui, {Size=UDim2.new(0,360,0,42), Position=UDim2.new(1,-390,0,26), BackgroundColor3=C.Ink, BackgroundTransparency=.38, BorderSizePixel=0, Text="", TextColor3=C.Muted, TextSize=11, Font=Enum.Font.GothamMedium, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=23}); stroke(squad,C.AccentSoft,.68)
local deploy = make("TextButton", "DeployBtn", rootGui, {Size=UDim2.new(0,330,0,58), Position=UDim2.new(1,-370,1,-92), BackgroundColor3=C.Selected, BorderSizePixel=0, AutoButtonColor=false, Text="READY TO DEPLOY", TextColor3=C.Dark, TextSize=17, Font=Enum.Font.GothamBold, Selectable=true, ZIndex=24}); stroke(deploy,C.Accent,.18)
local hint = make("TextLabel", "DeployHint", rootGui, {Size=UDim2.new(0,330,0,20), Position=UDim2.new(1,-370,1,-30), BackgroundTransparency=1, Text="ENTER / A  CONFIRM DEPLOYMENT", TextColor3=C.Muted, TextSize=9, Font=Enum.Font.GothamMedium, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=24})

local active = false
local confirmed = false
local generation = 0
local cameraBind = "ByteforceShowcaseCamera"
local movementLockBind = "ByteforceShowcaseMovementLock"
local controls

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
		button.TextColor3 = selected and C.Dark or C.Muted
		button.Active = active and not confirmed
	end
end
player:GetAttributeChangedSignal("SelectedClass"):Connect(refreshLoadout); refreshLoadout()

local function stopCamera() RunService:UnbindFromRenderStep(cameraBind) end
local function restoreCamera()
	stopCamera(); camera.CameraType=Enum.CameraType.Custom; camera.FieldOfView=70
	local char=player.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if hum then camera.CameraSubject=hum end
end

local function startCamera(rootPart)
	stopCamera(); camera.CameraType=Enum.CameraType.Scriptable; camera.FieldOfView=52; local started=os.clock()
	RunService:BindToRenderStep(cameraBind,Enum.RenderPriority.Camera.Value+1,function()
		if not active or not rootPart.Parent then return end
		local t=os.clock()-started; local focus=rootPart.Position+Vector3.new(0,1.6,0)
		local pos=rootPart.Position+rootPart.CFrame.LookVector*(10.8+math.sin(t*.2)*.25)+rootPart.CFrame.RightVector*(4.8+math.sin(t*.13)*.4)+Vector3.new(0,2.7+math.sin(t*.17)*.1,0)
		camera.CFrame=CFrame.lookAt(pos,focus)
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
	generation+=1; local mine=generation; deployVisual(false); refreshLoadout(); flow.BackgroundTransparency=1
	local cover=tweenFlow(0,.18); cover.Completed:Wait(); if mine~=generation then return end
	local char=player.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then flow.BackgroundTransparency=1; return end
	hideLobby(); active=true; rootGui.Visible=true; refreshLoadout(); setControls(false); bindInput(); startCamera(hrp)
	title.TextTransparency=1; role.TextTransparency=1; panel.Position=UDim2.fromScale(.025,.225); panel.BackgroundTransparency=1; deploy.Position=UDim2.new(1,-345,1,-92); deploy.BackgroundTransparency=1
	RunService.RenderStepped:Wait(); tweenFlow(1,.34); tw(title,.25,{TextTransparency=0}); tw(role,.3,{TextTransparency=0}); tw(panel,.3,{Position=UDim2.fromScale(.045,.225),BackgroundTransparency=.14}); tw(deploy,.3,{Position=UDim2.new(1,-370,1,-92),BackgroundTransparency=0})
end

local function enterRun()
	if not active then restoreCamera(); setControls(true); return end
	generation+=1; local mine=generation; local cover=tweenFlow(0,.2); cover.Completed:Wait(); if mine~=generation then return end
	active=false; rootGui.Visible=false; unbindInput(); stopCamera()
	local char=player.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); local started=os.clock()
	while hrp and hrp.Parent and os.clock()-started<1.4 do
		if (hrp.Position-Vector3.new(0,2005,50)).Magnitude>100 then break end
		RunService.Heartbeat:Wait()
	end
	restoreCamera(); setControls(true); RunService.RenderStepped:Wait(); tweenFlow(1,.45)
end

if showcaseRemote then showcaseRemote.OnClientEvent:Connect(function() task.spawn(showShowcase) end) end
if lobbyPhaseVal then lobbyPhaseVal.Changed:Connect(function(phase)
	if phase=="SURVIVOR_SELECT" and not active then task.spawn(showShowcase) end
end) end
if gameStartedVal then gameStartedVal.Changed:Connect(function(started)
	if started then
		task.spawn(enterRun)
	elseif active then
		active=false
		rootGui.Visible=false
		unbindInput()
		stopCamera()
		setControls(false)
	end
end) end

if lobbyPhaseVal.Value=="SURVIVOR_SELECT" and not gameStartedVal.Value then
	task.spawn(showShowcase)
end

script.Destroying:Connect(function() generation+=1; active=false; unbindInput(); stopCamera(); setControls(true) end)
