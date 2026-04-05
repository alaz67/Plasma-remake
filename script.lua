local function setCollide(v) local c=player.Character; if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=v end end end end
local Players = game:GetService("Players"); local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService"); local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage"); local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService") local player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Config = {
    StealSpeed = 30,
    FOV = 70,
    InfJumpPower = 60,
    WalkSpeed = 59,
    GrabRadius = 20,
    Gravity = 120,
    GalaxyGravityPercent = 70,
    HopPower = 35,
    HopCooldown = 0.08,
    AimbotRadius = 100,
    BatAimbotSpeed = 55,
    SpeedBoost = 29,
}
local Keybinds = {
    AutoLeft = Enum.KeyCode.Q,
    AutoRight = Enum.KeyCode.E,
    SpeedBoost = Enum.KeyCode.R,
    AutoSteal = Enum.KeyCode.V,
    BatAimbot = Enum.KeyCode.Z,
    AntiRagdoll = Enum.KeyCode.X,
    NoAnimations = Enum.KeyCode.N,
}
local ACCENT = Color3.fromRGB(255, 255, 255)  -- White accent
local BG_DARK = Color3.fromRGB(10, 10, 10)    -- Near black
local BG_MID = Color3.fromRGB(20, 20, 20)     -- Dark grey
local BG_CARD = Color3.fromRGB(30, 30, 30)    -- Card color
local TEXT_DIM = Color3.fromRGB(150, 150, 150) -- Dim text
local function saveConfig()
    local data={Config=Config,Keybinds={},Features={}}
    for k,v in pairs(Keybinds) do if v then data.Keybinds[k]=v.Name end end
    pcall(function()
        local F=data.Features;local function st(b) return b and b.BackgroundColor3==ACCENT or false end
        F.SpeedBoost=st(SpeedBoostBtn);F.AutoSteal=st(AutoStealBtn);F.BatAimbot=st(BatAimbotBtn)
        F.Galaxy=st(GalaxyBtn);F.Optimizer=st(OptimizerBtn);F.AntiRagdoll=st(AntiRagdollBtn)
        F.NoAnimations=st(NoAnimBtn);F.Spinbot=st(SpinbotBtn);F.InfJump=st(InfJumpBtn)
        F.Noclip=st(NoclipBtn);F.Fullbright=st(FullbrightBtn);F.AutoLeft=st(AutoLeftBtn)
        F.AutoRight=st(AutoRightBtn);F.TeleportOn=st(TeleportBtn);F.FlyOn=st(FlyBtn);F.AutoSell=st(AutoSellBtn)
    end)
    pcall(function() writefile("SecretDuel_Config.json",HttpService:JSONEncode(data)) end)
end
local function loadConfig()
    pcall(function() if isfile("SecretDuel_Config.json") then
            local data = HttpService:JSONDecode(readfile("SecretDuel_Config.json"))
            if data.Config then for k, v in pairs(data.Config) do Config[k] = v end end
            if data.Keybinds then for k, v in pairs(data.Keybinds) do Keybinds[k] = Enum.KeyCode[v] end end
            return data.Features
        end
    end)
    return nil
end
local savedFeatures = loadConfig()
local leftActive = false
local rightActive = false
local speedBoostConn = nil
local autoStealGui = nil
local circleParts = {}
local CIRCLE_COLOR = Color3.fromRGB(255, 255, 255) local noAnimConn = nil
local batAimbotConn = nil
local galaxyVectorForce = nil
local galaxyAttachment = nil
local galaxyEnabled = false
local hopsEnabled = false
local lastHopTime = 0
local spaceHeld = false
local originalJumpPower = 50
local DEFAULT_GRAVITY = 196.2
local infJumpEnabled = true
local jumpForce = 54
local clampFallSpeed = 80
local infJumpConn = nil
local function startInfJump()
    if infJumpConn then return end
    infJumpConn = UserInputService.JumpRequest:Connect(function() if not infJumpEnabled then return end
        local c = player.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, jumpForce, hrp.AssemblyLinearVelocity.Z)
    end)
end
RunService.Heartbeat:Connect(function() if not infJumpEnabled then return end
    local c = player.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    if hrp.AssemblyLinearVelocity.Y < -clampFallSpeed then
        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, -clampFallSpeed, hrp.AssemblyLinearVelocity.Z)
    end
end)
startInfJump()
local arMode=nil
local arConns={}
local arChar={}
local arBoosting=false
local function arCache()
    local c=player.Character; if not c then return false end
    local h=c:FindFirstChildOfClass("Humanoid"); local r=c:FindFirstChild("HumanoidRootPart")
    if not h or not r then return false end
    arChar={character=c,humanoid=h,root=r}; return true
end
local function arDisconnect()
    for _,c in ipairs(arConns) do pcall(function() c:Disconnect() end) end
    arConns={}
end
local function arIsRagdolled()
    if not arChar.humanoid then return false end
    local s=arChar.humanoid:GetState()
    if s==Enum.HumanoidStateType.Physics or s==Enum.HumanoidStateType.Ragdoll or s==Enum.HumanoidStateType.FallingDown then return true end
    local e=player:GetAttribute("RagdollEndTime")
    if e and (e-workspace:GetServerTimeNow())>0 then return true end
    return false
end
local function arForceExit()
    if not arChar.humanoid or not arChar.root then return end
    pcall(function() player:SetAttribute("RagdollEndTime",workspace:GetServerTimeNow()) end)
    for _,d in ipairs(arChar.character:GetDescendants()) do
        if d:IsA("BallSocketConstraint") or (d:IsA("Attachment") and d.Name:find("RagdollAttachment")) then d:Destroy() end
    end
    if not arBoosting then arBoosting=true; arChar.humanoid.WalkSpeed=400 end
    if arChar.humanoid.Health>0 then arChar.humanoid:ChangeState(Enum.HumanoidStateType.Running) end
    arChar.root.Anchored=false
end
local function startAntiRagdoll()
    if antiRagdollConn then antiRagdollConn:Disconnect(); antiRagdollConn=nil end
    if arMode=="v1" then return end
    if not arCache() then return end
    arMode="v1"
    table.insert(arConns,RunService.RenderStepped:Connect(function()
        if workspace.CurrentCamera and arChar.humanoid then workspace.CurrentCamera.CameraSubject=arChar.humanoid end
    end))
    table.insert(arConns,player.CharacterAdded:Connect(function()
        arBoosting=false; task.wait(0.5); arCache()
    end))
    task.spawn(function()
        while arMode=="v1" do
            task.wait()
            if arIsRagdolled() then arForceExit()
            elseif arBoosting then arBoosting=false; if arChar.humanoid then arChar.humanoid.WalkSpeed=16 end end
        end
    end)
end
local function stopAntiRagdoll()
    arMode=nil
    if arBoosting and arChar.humanoid then arChar.humanoid.WalkSpeed=16 end
    arBoosting=false; arDisconnect(); arChar={}
    if antiRagdollConn then antiRagdollConn:Disconnect(); antiRagdollConn=nil end
end
local EnableAntiRagdoll = startAntiRagdoll
local DisableAntiRagdoll = stopAntiRagdoll
local spinBAV2 = nil
local function startSpinbot()
    local hrp = getHRP(); if not hrp then return end
    if spinBAV2 then spinBAV2:Destroy() end
    spinBAV2 = Instance.new("BodyAngularVelocity"); spinBAV2.MaxTorque = Vector3.new(0, math.huge, 0)
    spinBAV2.AngularVelocity = Vector3.new(0, 50, 0) spinBAV2.Parent = hrp
end
local function stopSpinbot()
    if spinBAV2 then spinBAV2:Destroy(); spinBAV2 = nil end
local flyBV = nil
local flyConn = nil
local function startFly()
    local hrp = getHRP(); if not hrp then return end
    if flyBV then flyBV:Destroy() end
    flyBV = Instance.new("BodyVelocity"); flyBV.Velocity = Vector3.zero
    flyBV.MaxForce = Vector3.new(1e9,1e9,1e9) flyBV.Parent = hrp
    if flyConn then flyConn:Disconnect() end
    local UIS = game:GetService("UserInputService") flyConn = RunService.RenderStepped:Connect(function()
        if not T.FlyOn then stopFly(); return end
        local h = getHRP(); if not h then return end
        local cam = workspace.CurrentCamera
        local d = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then d=d+cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then d=d-cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then d=d-cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then d=d+cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then d=d+Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then d=d-Vector3.new(0,1,0) end
        if flyBV then flyBV.Velocity = d*50 end
    end)
end
local function stopFly()
    T.FlyOn = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then flyBV:Destroy(); flyBV = nil end
end
local tpLoopConn = nil
local function startTeleportLoop()
    if tpLoopConn then return end
    tpLoopConn = RunService.Heartbeat:Connect(function()
        if not T.TeleportOn then tpLoopConn:Disconnect(); tpLoopConn = nil; return end
        local hrp = getHRP(); if not hrp then return end
        local p = findPrompt(false); if p and p.Parent then
            pcall(function() hrp.CFrame = CFrame.new(p.Parent.Parent.Parent:GetPivot().Position+Vector3.new(0,3,0)) end)
        end
    end)
end
end
local infJumpConn2 = nil
local function startInfJump()
    if infJumpConn2 then return end
    infJumpConn2 = game:GetService("UserInputService").JumpRequest:Connect(function() if not T.InfJump then return end
        local hrp = getHRP(); if not hrp then return end
        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, Config.InfJumpPower, hrp.AssemblyLinearVelocity.Z)
    end)
end
local function stopInfJump()
    if infJumpConn2 then infJumpConn2:Disconnect(); infJumpConn2 = nil end
end
local noclipConn = nil
local function startNoclip()
    if noclipConn then return end
    noclipConn = game:GetService("RunService").Stepped:Connect(function() if not T.Noclip then return end
        local char = player.Character; if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
end
local function stopNoclip()
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    local char = player.Character; if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = true end
    end
end
local origBrightness = nil
local function enableFullbright()
    local L = game:GetService("Lighting") origBrightness = {L.Brightness, L.Ambient, L.OutdoorAmbient}
    L.Brightness = 10
    L.Ambient = Color3.fromRGB(255,255,255) L.OutdoorAmbient = Color3.fromRGB(255,255,255)
end
local function disableFullbright()
    if origBrightness then
        local L = game:GetService("Lighting") L.Brightness = origBrightness[1]
        L.Ambient = origBrightness[2]
        L.OutdoorAmbient = origBrightness[3]
    end
end
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "SecretDuelGUI"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false
local MainFrame = Instance.new("Frame"); MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 340, 0, 480); MainFrame.Position = UDim2.new(0.5, -170, 0.5, -240)
MainFrame.BackgroundColor3 = BG_DARK
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
local UICorner = Instance.new("UICorner"); UICorner.CornerRadius = UDim.new(0, 16)
UICorner.Parent = MainFrame
local MainStroke = Instance.new("UIStroke"); MainStroke.Thickness = 2.5
MainStroke.Color = ACCENT
MainStroke.Parent = MainFrame
local TitleBar = Instance.new("Frame"); TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 50); TitleBar.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
local TitleCorner = Instance.new("UICorner"); TitleCorner.CornerRadius = UDim.new(0, 16)
TitleCorner.Parent = TitleBar
local Title = Instance.new("TextLabel"); Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 1, 0); Title.BackgroundTransparency = 1
Title.Text = "SECRET DUEL"
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 20
Title.TextColor3 = ACCENT
Title.Parent = TitleBar
local DiscordLabel = Instance.new("TextLabel"); DiscordLabel.Name = "Discord"
DiscordLabel.Size = UDim2.new(1, 0, 0, 20); DiscordLabel.Position = UDim2.new(0, 0, 1, -25)
DiscordLabel.BackgroundTransparency = 1
DiscordLabel.Text = "discord.gg/JaFSsH8RrU"
DiscordLabel.Font = Enum.Font.GothamBold
DiscordLabel.TextSize = 12
DiscordLabel.TextColor3 = TEXT_DIM
DiscordLabel.Parent = MainFrame
local TabContainer = Instance.new("Frame"); TabContainer.Name = "TabContainer"
TabContainer.Size = UDim2.new(1, -20, 0, 35); TabContainer.Position = UDim2.new(0, 10, 0, 60)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = MainFrame
local function makeTab(name, text, xPos, active)
    local tab = Instance.new("TextButton"); tab.Name = name
    tab.Size = UDim2.new(0.22, 0, 1, 0) tab.Position = UDim2.new(xPos, 0, 0, 0)
    tab.BackgroundColor3 = active and ACCENT or BG_CARD
    tab.Text = text
    tab.Font = Enum.Font.GothamBold
    tab.TextSize = 11
    tab.TextColor3 = active and BG_DARK or TEXT_DIM
    tab.BorderSizePixel = 0
    tab.Parent = TabContainer
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = tab
    return tab
end
local FeaturesTab = makeTab("FeaturesTab", "FEATURES", 0, true)
local SettingsTab  = makeTab("SettingsTab",  "SETTINGS",  0.52, false)
local MobileTab    = makeTab("MobileTab",    "MOBILE",    0.78, false)
local function makeScrollFrame(visible)
    local f = Instance.new("ScrollingFrame"); f.Size = UDim2.new(1, -20, 1, -145)
    f.Position = UDim2.new(0, 10, 0, 105) f.BackgroundTransparency = 1
    f.ScrollBarThickness = 4
    f.ScrollBarImageColor3 = ACCENT
    f.CanvasSize = UDim2.new(0, 0, 0, 450) f.Visible = visible
    f.Parent = MainFrame
    return f
end
local FeaturesFrame = makeScrollFrame(true); local KeybindsFrame = makeScrollFrame(false)
local SettingsFrame = makeScrollFrame(false); local MobileFrame   = makeScrollFrame(false)
local function switchTabs(active)
    local tabs = {FeaturesTab, SettingsTab, MobileTab}
    local frames = {FeaturesFrame, SettingsFrame, MobileFrame}
    for i, t in ipairs(tabs) do
        local on = (t == active) t.BackgroundColor3 = on and ACCENT or BG_CARD
        t.TextColor3 = on and BG_DARK or TEXT_DIM
        frames[i].Visible = on
    end
end
FeaturesTab.MouseButton1Click:Connect(function() switchTabs(FeaturesTab) end)
KeybindsTab.MouseButton1Click:Connect(function() switchTabs(KeybindsTab) end)
SettingsTab.MouseButton1Click:Connect(function()  switchTabs(SettingsTab)  end)
MobileTab.MouseButton1Click:Connect(function()    switchTabs(MobileTab)    end) local toggleCount = 0
local function createToggle(parent, name, text, yPos)
    local col = toggleCount % 2
    local row = math.floor(toggleCount / 2) toggleCount = toggleCount + 1
    local button = Instance.new("TextButton"); button.Name = name.."Toggle"
    button.Size = UDim2.new(0.48, 0, 0, 34) button.Position = UDim2.new(col * 0.51, 0, 0, row * 38)
    button.BackgroundColor3 = BG_CARD
    button.Text = text
    button.Font = Enum.Font.GothamBold
    button.TextSize = 11
    button.TextColor3 = Color3.fromRGB(255,255,255) button.BorderSizePixel = 0
    button.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = button
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(60,60,60); s.Thickness = 1; s.Parent = button
    return button
end
local function updateToggle(button, active)
    local targetColor = active and ACCENT or BG_CARD
    local textColor = active and BG_DARK or Color3.fromRGB(255,255,255)
    TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play() button.TextColor3 = textColor
end
local function     local container = Instance.new("Frame"); container.Size = UDim2.new(1, -10, 0, 50)
    container.Position = UDim2.new(0, 5, 0, yPos) container.BackgroundColor3 = BG_CARD
    container.BorderSizePixel = 0
    container.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = container
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(60,60,60); s.Thickness = 1; s.Parent = container
    local keyButton = Instance.new("TextButton"); keyButton.Size = UDim2.new(0, 35, 0, 35)
    keyButton.Position = UDim2.new(0, 8, 0.5, -17.5) keyButton.BackgroundColor3 = ACCENT
    keyButton.Text = currentKey and currentKey.Name:sub(1,1) or "NONE"
    keyButton.Font = Enum.Font.GothamBlack
    keyButton.TextSize = currentKey and 16 or 10
    keyButton.TextColor3 = BG_DARK
    keyButton.BorderSizePixel = 0
    keyButton.Parent = container
    local kc = Instance.new("UICorner"); kc.CornerRadius = UDim.new(0,8); kc.Parent = keyButton
    local label = Instance.new("TextLabel"); label.Size = UDim2.new(1, -55, 1, 0)
    label.Position = UDim2.new(0, 50, 0, 0) label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(255,255,255) label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    return keyButton
end
local function createNumberInput(parent, name, text, currentValue, yPos)
    local container = Instance.new("Frame"); container.Size = UDim2.new(1, -10, 0, 45)
    container.Position = UDim2.new(0, 5, 0, yPos) container.BackgroundColor3 = BG_CARD
    container.BorderSizePixel = 0
    container.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = container
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(60,60,60); s.Thickness = 1; s.Parent = container
    local label = Instance.new("TextLabel"); label.Size = UDim2.new(1, -100, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0) label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(255,255,255) label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    local numButton = Instance.new("TextButton"); numButton.Size = UDim2.new(0, 80, 0, 30)
    numButton.Position = UDim2.new(1, -85, 0.5, -15) numButton.BackgroundColor3 = ACCENT
    numButton.Text = tostring(currentValue) numButton.Font = Enum.Font.GothamBold
    numButton.TextSize = 12
    numButton.TextColor3 = BG_DARK
    numButton.BorderSizePixel = 0
    numButton.Parent = container
    local nc = Instance.new("UICorner"); nc.CornerRadius = UDim.new(0,8); nc.Parent = numButton
    return numButton
end
toggleCount = 0
local AutoLeftBtn    = createToggle(FeaturesFrame, "AutoLeft",     "Auto Left",      0)
local AutoRightBtn   = createToggle(FeaturesFrame, "AutoRight",    "Auto Right",     45)
local SpeedBoostBtn  = createToggle(FeaturesFrame, "SpeedBoost",   "Steal Speed",    90)
local AutoStealBtn   = createToggle(FeaturesFrame, "AutoSteal",    "Auto Steal",     135)
local BatAimbotBtn   = createToggle(FeaturesFrame, "BatAimbot",    "Bat Aimbot",     180)
local GalaxyBtn      = createToggle(FeaturesFrame, "Galaxy",       "Jump Power",     225)
local OptimizerBtn   = createToggle(FeaturesFrame, "Optimizer",    "Performance",    270)
local AntiRagdollBtn = createToggle(FeaturesFrame, "AntiRagdoll",  "Anti Ragdoll",   315)
local NoAnimBtn      = createToggle(FeaturesFrame, "NoAnimations", "No Animations",  360)
local SpinbotBtn     = createToggle(FeaturesFrame, "Spinbot",      "Spinbot",        405)
local TeleportBtn    = createToggle(FeaturesFrame, "TeleportOn",   "TP to Animal",   450)
local AutoSellBtn    = createToggle(FeaturesFrame, "AutoSell",     "Auto Sell",      495)
local FlyBtn         = createToggle(FeaturesFrame, "FlyOn",        "Fly",            540)
local InfJumpBtn     = createToggle(FeaturesFrame, "InfJump",      "Inf Jump",       450)
local NoclipBtn      = createToggle(FeaturesFrame, "Noclip",       "Noclip",         495)
local FullbrightBtn  = createToggle(FeaturesFrame, "Fullbright",   "Fullbright",     540)
local SpeedBoostInput        = createNumberInput(SettingsFrame, "SpeedBoost",           "Speed While Stealing", Config.SpeedBoost,          0)
local GrabRadiusInput        = createNumberInput(SettingsFrame, "GrabRadius",           "Grab Radius",          Config.GrabRadius,           50)
local GalaxyGravityInput     = createNumberInput(SettingsFrame, "GalaxyGravityPercent", "Gravity",              Config.GalaxyGravityPercent, 100)
local HopPowerInput          = createNumberInput(SettingsFrame, "HopPower",             "Hop Power",            Config.HopPower,             150)
local AimbotRadiusInput      = createNumberInput(SettingsFrame, "AimbotRadius",         "Aimbot Radius",        Config.AimbotRadius,         200)
local AimbotSpeedInput       = createNumberInput(SettingsFrame, "BatAimbotSpeed",       "Aimbot Speed",         Config.BatAimbotSpeed,       250)
local WalkSpeedInput         = createNumberInput(SettingsFrame, "WalkSpeed",            "Walk Speed",           Config.WalkSpeed,            300)
local FOVInput                = createNumberInput(SettingsFrame, "FOV",                 "Field of View",        Config.FOV,                  350)
local SaveButton = Instance.new("TextButton"); SaveButton.Size = UDim2.new(1, -10, 0, 40)
SaveButton.Position = UDim2.new(0, 5, 0, 305); SaveButton.BackgroundColor3 = ACCENT
SaveButton.Text = "SAVE CONFIG"
SaveButton.Font = Enum.Font.GothamBlack
SaveButton.TextSize = 14
SaveButton.TextColor3 = BG_DARK
SaveButton.BorderSizePixel = 0
SaveButton.Parent = SettingsFrame
local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0,10); sc.Parent = SaveButton
SaveButton.MouseButton1Click:Connect(function() saveConfig()
    SaveButton.Text = "SAVED!"
    task.wait(1); SaveButton.Text = "SAVE CONFIG"
end)
local _ml = Instance.new("TextLabel") _ml.Size = UDim2.new(1,-10,0,30); _ml.Position = UDim2.new(0,5,0,0)
_ml.BackgroundTransparency = 1; _ml.Text = "MOBILE BUTTONS"
_ml.Font = Enum.Font.GothamBlack; _ml.TextSize = 13
_ml.TextColor3 = ACCENT; _ml.TextXAlignment = Enum.TextXAlignment.Left
_ml.Parent = MobileFrame
local MobileSupportBtn = createToggle(MobileFrame, "MobileSupport", "Show Mobile Buttons", 35)
local _mi = Instance.new("TextLabel") _mi.Size = UDim2.new(1,-10,0,60); _mi.Position = UDim2.new(0,5,0,82)
_mi.BackgroundTransparency = 1
_mi.Text = "4 buttons: AUTO STEAL | BAT AIMBOT | AUTO LEFT | AUTO RIGHT"
_mi.Font = Enum.Font.Gotham; _mi.TextSize = 11
_mi.TextColor3 = TEXT_DIM; _mi.TextWrapped = true
_mi.TextXAlignment = Enum.TextXAlignment.Left; _mi.Parent = MobileFrame
local changingKeybind = nil
local keybindButtons = {
    {button=AutoLeftKey,    name="AutoLeft"},
    {button=AutoRightKey,   name="AutoRight"},
    {button=SpeedBoostKey,  name="SpeedBoost"},
    {button=AutoStealKey,   name="AutoSteal"},
    {button=BatAimbotKey,   name="BatAimbot"},
    {button=AntiRagdollKey, name="AntiRagdoll"},
    {button=NoAnimKey,      name="NoAnimations"},
}
for _, data in ipairs(keybindButtons) do
    data.button.MouseButton1Click:Connect(function() if changingKeybind then return end
        changingKeybind = data.name
        data.button.Text = "..."
        data.button.TextSize = 9
        local conn
        conn = UserInputService.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
                    Keybinds[data.name] = nil
                    data.button.Text = "NONE"; data.button.TextSize = 10
                else
                    Keybinds[data.name] = input.KeyCode
                    data.button.Text = input.KeyCode.Name:sub(1,1); data.button.TextSize = 16
                end
                saveConfig(); changingKeybind = nil; conn:Disconnect()
            end
        end)
    end)
end
local numberInputs = {
    {button=SpeedBoostInput,    name="SpeedBoost",           min=1, max=100},
    {button=GrabRadiusInput,    name="GrabRadius",           min=1, max=999999},
    {button=GalaxyGravityInput, name="GalaxyGravityPercent", min=1, max=130},
    {button=HopPowerInput,      name="HopPower",             min=1, max=80},
    {button=AimbotRadiusInput,  name="AimbotRadius",         min=1, max=999},
    {button=AimbotSpeedInput,   name="BatAimbotSpeed",       min=1, max=200},
}
for _, data in ipairs(numberInputs) do
    data.button.MouseButton1Click:Connect(function() local typing = false
        if typing then return end
        typing = true
        local textBox = Instance.new("TextBox"); textBox.Size = data.button.Size; textBox.Position = data.button.Position
        textBox.BackgroundColor3 = data.button.BackgroundColor3
        textBox.Text = tostring(Config[data.name]) textBox.Font = data.button.Font; textBox.TextSize = data.button.TextSize
        textBox.TextColor3 = BG_DARK; textBox.ClearTextOnFocus = false; textBox.BorderSizePixel = 0
        textBox.Parent = data.button.Parent
        local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0,8); tc.Parent = textBox
        textBox:CaptureFocus() textBox.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local num = tonumber(textBox.Text); if num and num >= data.min and num <= data.max then
                    Config[data.name] = num; data.button.Text = tostring(Config[data.name])
                end
            end
            textBox:Destroy(); typing = false
        end)
    end)
end
local leftTargets = {
    Vector3.new(-474.92510986328125, -6.398684978485107, 95.64352416992188),
    Vector3.new(-482.6980285644531, -4.433956623077393, 98.34976196289062) }
local rightTargets = {
    Vector3.new(-473.9881286621094, -6.398684024810791, 25.45433807373047),
    Vector3.new(-482.8011474609375, -4.433956623077393, 24.77419090270996) }
local speed = Config.WalkSpeed or 59
local AUTO_STEAL_PROX_RADIUS = Config.GrabRadius
local allAnimalsCache = {}
local PromptMemoryCache = {}
local InternalStealCache = {}
local IsStealing = false
local StealProgress = 0
local PartsCount = 64
local function getHRP()
    local c = player.Character
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso"))
end
local function toggleNoAnimations(state)
    if noAnimConn then noAnimConn:Disconnect(); noAnimConn = nil end
    if state then
        local char = player.Character; if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid"); if not humanoid then return end
        local animator = humanoid:FindFirstChildOfClass("Animator"); if not animator then return end
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do track:Stop(); track:AdjustSpeed(0) end
        noAnimConn = humanoid.AnimationPlayed:Connect(function(track) track:Stop(); track:AdjustSpeed(0) end)
    end
end
local function captureJumpPower()
    local c = player.Character; if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid"); if hum and hum.JumpPower > 0 then originalJumpPower = hum.JumpPower end
end
task.spawn(function() task.wait(1); captureJumpPower() end)
player.CharacterAdded:Connect(function() task.wait(1); captureJumpPower() end)
local function setupGalaxyForce()
    pcall(function() local c = player.Character; if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart"); if not h then return end
        if galaxyVectorForce then galaxyVectorForce:Destroy() end
        if galaxyAttachment then galaxyAttachment:Destroy() end
        galaxyAttachment = Instance.new("Attachment"); galaxyAttachment.Parent = h
        galaxyVectorForce = Instance.new("VectorForce"); galaxyVectorForce.Attachment0 = galaxyAttachment
        galaxyVectorForce.ApplyAtCenterOfMass = true
        galaxyVectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
        galaxyVectorForce.Force = Vector3.new(0, 0, 0) galaxyVectorForce.Parent = h
    end)
end
local function updateGalaxyForce()
    if not galaxyEnabled or not galaxyVectorForce then return end
    local c = player.Character; if not c then return end
    local mass = 0
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then mass = mass + p:GetMass() end
    end
    local tg = DEFAULT_GRAVITY * (Config.GalaxyGravityPercent / 100)
    galaxyVectorForce.Force = Vector3.new(0, mass * (DEFAULT_GRAVITY - tg) * 0.95, 0)
end
local function adjustGalaxyJump()
    pcall(function() local c = player.Character; if not c then return end
        local hum = c:FindFirstChildOfClass("Humanoid"); if not hum then return end
        if not galaxyEnabled then hum.JumpPower = originalJumpPower; return end
        local ratio = math.sqrt((DEFAULT_GRAVITY * (Config.GalaxyGravityPercent / 100)) / DEFAULT_GRAVITY)
        hum.JumpPower = originalJumpPower * ratio
    end)
end
local function doMiniHop()
    if not hopsEnabled then return end
    pcall(function() local c = player.Character; if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid"); if not h or not hum then return end
        if tick() - lastHopTime < Config.HopCooldown then return end
        lastHopTime = tick(); if hum.FloorMaterial == Enum.Material.Air then
            h.AssemblyLinearVelocity = Vector3.new(h.AssemblyLinearVelocity.X, Config.HopPower, h.AssemblyLinearVelocity.Z)
        end
    end)
end
local function startGalaxy()
    galaxyEnabled = true; hopsEnabled = true; setupGalaxyForce(); adjustGalaxyJump()
end
local function stopGalaxy()
    galaxyEnabled = false; hopsEnabled = false
    if galaxyVectorForce then galaxyVectorForce:Destroy(); galaxyVectorForce = nil end
    if galaxyAttachment then galaxyAttachment:Destroy(); galaxyAttachment = nil end
    adjustGalaxyJump()
end
RunService.Heartbeat:Connect(function() if hopsEnabled and spaceHeld then doMiniHop() end
    if galaxyEnabled then updateGalaxyForce() end
end)
UserInputService.InputEnded:Connect(function(input) if input.KeyCode == Enum.KeyCode.Space then spaceHeld = false end
end)
local SlapList = {
    {1,"Bat"},{2,"Slap"},{3,"Iron Slap"},{4,"Gold Slap"},{5,"Diamond Slap"},
    {6,"Emerald Slap"},{7,"Ruby Slap"},{8,"Dark Matter Slap"},{9,"Flame Slap"},
    {10,"Nuclear Slap"},{11,"Galaxy Slap"},{12,"Glitched Slap"}
}
local function findBat()
    local c = player.Character; if not c then return nil end
    local bp = player:FindFirstChildOfClass("Backpack")
    for _, ch in ipairs(c:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end
    if bp then for _, ch in ipairs(bp:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end end
    for _, i in ipairs(SlapList) do
        local t = c:FindFirstChild(i[2]) or (bp and bp:FindFirstChild(i[2])); if t then return t end
    end
    return nil
end
local function findNearestEnemy(myHRP)
    local nearest, nearestDist, nearestTorso = nil, math.huge, nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local eh = p.Character:FindFirstChild("HumanoidRootPart")
            local torso = p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso")
            local hum = p.Character:FindFirstChildOfClass("Humanoid"); if eh and hum and hum.Health > 0 then
                local d = (eh.Position - myHRP.Position).Magnitude
                if d < nearestDist and d <= Config.AimbotRadius then
                    nearestDist = d; nearest = eh; nearestTorso = torso or eh
                end
            end
        end
    end
    return nearest, nearestDist, nearestTorso
end
local function startBatAimbot()
    if batAimbotConn then return end
    batAimbotConn = RunService.Heartbeat:Connect(function() local c = player.Character; if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid"); if not h or not hum then return end
        local bat = findBat(); if bat and bat.Parent ~= c then hum:EquipTool(bat) end
        local target, dist, torso = findNearestEnemy(h); if target and torso then
            local Prediction = 0.13
            local PredictedPos = torso.Position + (torso.AssemblyLinearVelocity * Prediction)
            local dir = (PredictedPos - h.Position); if dir.Magnitude > 1.5 then
                local moveDir = dir.Unit
                h.AssemblyLinearVelocity = moveDir * Config.BatAimbotSpeed
            else
                h.AssemblyLinearVelocity = target.AssemblyLinearVelocity
            end
        end
    end)
end
local function stopBatAimbot()
    if batAimbotConn then batAimbotConn:Disconnect(); batAimbotConn = nil end
end
local originalTransparency = {}
local xrayEnabled = false
local function enableOptimizer()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        game:GetService("Lighting").GlobalShadows = false
        game:GetService("Lighting").Brightness = 3
    end)
    pcall(function() for _, obj in ipairs(Workspace:GetDescendants()) do
            pcall(function() if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then obj:Destroy()
                elseif obj:IsA("BasePart") then obj.CastShadow = false; obj.Material = Enum.Material.Plastic end
            end)
        end
    end)
end
local function disableOptimizer()
    for part, value in pairs(originalTransparency) do
        if part then part.LocalTransparencyModifier = value end
    end
    originalTransparency = {}
    xrayEnabled = false
end
local function startSpeedBoost()
    if speedBoostConn then return end
    speedBoostConn = RunService.Heartbeat:Connect(function() local char = player.Character; if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart"); if not humanoid or not hrp then return end
        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0.1 then
            hrp.AssemblyLinearVelocity = Vector3.new(moveDir.X * Config.SpeedBoost, hrp.AssemblyLinearVelocity.Y, moveDir.Z * Config.SpeedBoost)
        end
    end)
end
local function stopSpeedBoost()
    if speedBoostConn then speedBoostConn:Disconnect(); speedBoostConn = nil end
end
task.spawn(function() task.wait(2)
    while task.wait(5) do
        if AutoStealBtn.BackgroundColor3 == ACCENT then
            table.clear(allAnimalsCache) for _, plot in ipairs(workspace.Plots:GetChildren()) do
                if plot:IsA("Model") then
                    local sign = plot:FindFirstChild("PlotSign") local yourBase = sign and sign:FindFirstChild("YourBase")
                    if not (yourBase and yourBase.Enabled) then
                        local podiums = plot:FindFirstChild("AnimalPodiums"); if podiums then
                            for _, podium in ipairs(podiums:GetChildren()) do
                                if podium:IsA("Model") and podium:FindFirstChild("Base") then
                                    table.insert(allAnimalsCache, {
                                        plot = plot.Name, slot = podium.Name,
                                        worldPosition = podium:GetPivot().Position,
                                        uid = plot.Name.."_"..podium.Name
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)
local function findPrompt(a)
    local c = PromptMemoryCache[a.uid]
    if c and c.Parent then return c end
    local plot = workspace.Plots:FindFirstChild(a.plot)
    local podium = plot and plot.AnimalPodiums:FindFirstChild(a.slot); if not podium then return end
    local base = podium:FindFirstChild("Base"); if not base then return end
    local spawn = base:FindFirstChild("Spawn"); if not spawn then return end
    local attach = spawn:FindFirstChild("PromptAttachment"); if not attach then return end
    for _, p in ipairs(attach:GetChildren()) do
        if p:IsA("ProximityPrompt") then PromptMemoryCache[a.uid] = p; return p end
    end
end
local function build(prompt)
    if InternalStealCache[prompt] then return end
    local d = {h = {}, t = {}, r = true}
    local s1, c1 = pcall(function() return getconnections(prompt.PromptButtonHoldBegan) end)
    if s1 and c1 then for _, c in ipairs(c1) do if c and type(c.Function) == "function" then table.insert(d.h, c.Function) end end end
    local s2, c2 = pcall(function() return getconnections(prompt.Triggered) end)
    if s2 and c2 then for _, c in ipairs(c2) do if c and type(c.Function) == "function" then table.insert(d.t, c.Function) end end end
    InternalStealCache[prompt] = d
end
local function steal(prompt)
    local d = InternalStealCache[prompt]
    if not d or not d.r then return end
    d.r = false; IsStealing = true; StealProgress = 0
    task.spawn(function() if #d.h > 0 or #d.t > 0 then
            for _, f in ipairs(d.h) do task.spawn(function() pcall(f) end) end
            local s = tick() while tick() - s < 0.05 do StealProgress = (tick()-s)/0.05; task.wait() end
            StealProgress = 1
            for _, f in ipairs(d.t) do task.spawn(function() pcall(f) end) end
        else
            if fireproximityprompt then fireproximityprompt(prompt) end
            local s = tick() while tick() - s < 0.05 do StealProgress = (tick()-s)/0.05; task.wait() end
            StealProgress = 1
        end
        task.wait(0.2); IsStealing = false; StealProgress = 0; d.r = true
    end)
end
local function createCircle()
    for _, p in ipairs(circleParts) do if p then pcall(function() p:Destroy() end) end end
    table.clear(circleParts) for i = 1, PartsCount do
        local part = Instance.new("Part"); part.Anchored = true; part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Color = CIRCLE_COLOR; part.Transparency = 0.35
        part.Size = Vector3.new(1, 0.2, 0.3) part.Parent = workspace
        table.insert(circleParts, part)
    end
end
local function initAutoStealGUI()
    if autoStealGui then pcall(function() autoStealGui:Destroy() end); autoStealGui = nil end
    autoStealGui = Instance.new("ScreenGui"); autoStealGui.Name = "SecretAutoSteal"; autoStealGui.ResetOnSpawn = false
    autoStealGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    autoStealGui.Parent = player:WaitForChild("PlayerGui") local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 260, 0, 26); frame.Position = UDim2.new(0.5, -130, 1, -120)
    frame.BackgroundColor3 = BG_DARK; frame.BackgroundTransparency = 0.2; frame.BorderSizePixel = 0
    frame.Parent = autoStealGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    local fStroke = Instance.new("UIStroke"); fStroke.Thickness = 1.2; fStroke.Color = ACCENT; fStroke.Parent = frame
    local bg = Instance.new("Frame"); bg.Size = UDim2.new(0.72, 0, 0, 8); bg.Position = UDim2.new(0.05, 0, 0.5, -4)
    bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40); bg.BorderSizePixel = 0; bg.Parent = frame
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0) local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0); fill.BackgroundColor3 = ACCENT; fill.BorderSizePixel = 0; fill.Parent = bg
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0) local radiusText = Instance.new("TextLabel")
    radiusText.Size = UDim2.new(0, 50, 1, 0); radiusText.Position = UDim2.new(0.8, 0, 0, 0)
    radiusText.BackgroundTransparency = 1; radiusText.Text = tostring(Config.GrabRadius)
    radiusText.Font = Enum.Font.GothamBold; radiusText.TextSize = 13; radiusText.TextColor3 = ACCENT
    radiusText.Parent = frame
    task.spawn(function()
        local prev=false
        while autoStealGui and autoStealGui.Parent do
            task.wait(0.03)
            if AutoStealBtn.BackgroundColor3==ACCENT then
                AUTO_STEAL_PROX_RADIUS=Config.GrabRadius; radiusText.Text=tostring(Config.GrabRadius)
                local h=getHRP(); local inR=false
                if h then
                    for _,v in ipairs(workspace:GetDescendants()) do
                        if v:IsA("ProximityPrompt") then
                            local ok,p=pcall(function() return v.Parent.Position end)
                            if ok and (p-h.Position).Magnitude<=AUTO_STEAL_PROX_RADIUS then inR=true; break end
                        end
                    end
                end
                if fill and fill.Parent then
                    if inR and not prev then for i=1,20 do fill.Size=UDim2.new(i/20,0,1,0); task.wait(0.008) end; fill.Size=UDim2.new(0,0,1,0)
                    elseif not inR then fill.Size=UDim2.new(0,0,1,0) end
                end
                prev=inR
            else if fill and fill.Parent then fill.Size=UDim2.new(0,0,1,0) end; prev=false end
        end
    end)
end
local function moveToTargets(targetList)
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart") local hum = character:FindFirstChildOfClass("Humanoid")
    for i, target in ipairs(targetList) do
        while true do
            hrp = getHRP(); if not hrp then break end
            if not leftActive and not rightActive then
                if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
                if hum then hum:Move(Vector3.zero, false) end
                return
            end
            local diff = target - hrp.Position
            local flat = Vector3.new(diff.X, 0, diff.Z); if flat.Magnitude <= 1.5 then
                hrp.AssemblyLinearVelocity = Vector3.zero
                break
            end
            local dir = flat.Unit
            hum = character:FindFirstChildOfClass("Humanoid"); if hum then hum:Move(dir, false) end
            hrp.AssemblyLinearVelocity = Vector3.new(dir.X * speed, hrp.AssemblyLinearVelocity.Y, dir.Z * speed)
            RunService.RenderStepped:Wait()
        end
    end
    if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
    local hum2 = (player.Character or player.CharacterAdded:Wait()):FindFirstChildOfClass("Humanoid")
    if hum2 then hum2:Move(Vector3.zero, false) end
end
AutoLeftBtn.MouseButton1Click:Connect(function() local newState = AutoLeftBtn.BackgroundColor3 ~= ACCENT
    updateToggle(AutoLeftBtn, newState); if newState then
        updateToggle(AutoRightBtn, false); leftActive = true
        task.spawn(function() moveToTargets(leftTargets); leftActive = false; updateToggle(AutoLeftBtn, false) end)
    else leftActive = false end
end)
AutoRightBtn.MouseButton1Click:Connect(function() local newState = AutoRightBtn.BackgroundColor3 ~= ACCENT
    updateToggle(AutoRightBtn, newState); if newState then
        updateToggle(AutoLeftBtn, false); rightActive = true
        task.spawn(function() moveToTargets(rightTargets); rightActive = false; updateToggle(AutoRightBtn, false) end)
    else rightActive = false end
end)
SpeedBoostBtn.MouseButton1Click:Connect(function() local newState = SpeedBoostBtn.BackgroundColor3 ~= ACCENT
    updateToggle(SpeedBoostBtn, newState); if newState then startSpeedBoost() else stopSpeedBoost() end
end)
AutoStealBtn.MouseButton1Click:Connect(function() local newState = AutoStealBtn.BackgroundColor3 ~= ACCENT
    updateToggle(AutoStealBtn, newState); if newState then
        task.spawn(function() initAutoStealGUI(); createCircle() end)
    else
        if autoStealGui then pcall(function() autoStealGui:Destroy() end); autoStealGui = nil end
        for _, p in ipairs(circleParts) do if p then pcall(function() p:Destroy() end) end end
        table.clear(circleParts)
    end
end)
BatAimbotBtn.MouseButton1Click:Connect(function() local newState = BatAimbotBtn.BackgroundColor3 ~= ACCENT
    updateToggle(BatAimbotBtn, newState); if newState then startBatAimbot() else stopBatAimbot() end
end)
GalaxyBtn.MouseButton1Click:Connect(function() local newState = GalaxyBtn.BackgroundColor3 ~= ACCENT
    updateToggle(GalaxyBtn, newState); if newState then startGalaxy() else stopGalaxy() end
end)
OptimizerBtn.MouseButton1Click:Connect(function() local newState = OptimizerBtn.BackgroundColor3 ~= ACCENT
    updateToggle(OptimizerBtn, newState); if newState then enableOptimizer() else disableOptimizer() end
end)
AntiRagdollBtn.MouseButton1Click:Connect(function() local newState = AntiRagdollBtn.BackgroundColor3 ~= ACCENT
    updateToggle(AntiRagdollBtn, newState); if newState then EnableAntiRagdoll() else DisableAntiRagdoll() end
end)
NoAnimBtn.MouseButton1Click:Connect(function() local newState = NoAnimBtn.BackgroundColor3 ~= ACCENT
    updateToggle(NoAnimBtn, newState) toggleNoAnimations(newState)
end)
SpinbotBtn.MouseButton1Click:Connect(function() local newState = SpinbotBtn.BackgroundColor3 ~= ACCENT
    updateToggle(SpinbotBtn, newState); if newState then startSpinbot() else stopSpinbot() end
end)
TeleportBtn.MouseButton1Click:Connect(function() local newState = TeleportBtn.BackgroundColor3 ~= ACCENT
    updateToggle(TeleportBtn, newState) T.TeleportOn = newState
    if newState then startTeleportLoop() end
end)
FlyBtn.MouseButton1Click:Connect(function() local newState = FlyBtn.BackgroundColor3 ~= ACCENT
    updateToggle(FlyBtn, newState) T.FlyOn = newState
    if newState then startFly() else stopFly() end
end)
AutoSellBtn.MouseButton1Click:Connect(function() local newState = AutoSellBtn.BackgroundColor3 ~= ACCENT
    updateToggle(AutoSellBtn, newState)
end)
InfJumpBtn.MouseButton1Click:Connect(function() local newState = InfJumpBtn.BackgroundColor3 ~= ACCENT
    updateToggle(InfJumpBtn, newState) T.InfJump = newState
    if newState then startInfJump() else stopInfJump() end
end)
NoclipBtn.MouseButton1Click:Connect(function() local newState = NoclipBtn.BackgroundColor3 ~= ACCENT
    updateToggle(NoclipBtn, newState); if newState then startNoclip() else stopNoclip() end
end)
FullbrightBtn.MouseButton1Click:Connect(function() local newState = FullbrightBtn.BackgroundColor3 ~= ACCENT
    updateToggle(FullbrightBtn, newState); if newState then enableFullbright() else disableFullbright() end
end)
UserInputService.InputBegan:Connect(function(input, processed) if processed then return end
    if changingKeybind then return end
    if input.KeyCode == Enum.KeyCode.Space then spaceHeld = true; return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local function tog(btn, onFn, offFn)
        local newState = btn.BackgroundColor3 ~= ACCENT
        updateToggle(btn, newState); if newState then if onFn then onFn() end else if offFn then offFn() end end
    end
    if Keybinds.AutoLeft     and input.KeyCode == Keybinds.AutoLeft     then
        local newState = AutoLeftBtn.BackgroundColor3 ~= ACCENT
        updateToggle(AutoLeftBtn, newState)
        if newState then updateToggle(AutoRightBtn, false)
        leftActive = true; task.spawn(function() moveToTargets(leftTargets); leftActive = false; updateToggle(AutoLeftBtn, false) end) else leftActive = false end
    elseif Keybinds.AutoRight  and input.KeyCode == Keybinds.AutoRight  then
        local newState = AutoRightBtn.BackgroundColor3 ~= ACCENT
        updateToggle(AutoRightBtn, newState)
        if newState then updateToggle(AutoLeftBtn, false)
        rightActive = true; task.spawn(function() moveToTargets(rightTargets); rightActive = false; updateToggle(AutoRightBtn, false) end) else rightActive = false end
    elseif Keybinds.SpeedBoost and input.KeyCode == Keybinds.SpeedBoost then tog(SpeedBoostBtn,  startSpeedBoost, stopSpeedBoost)
    elseif Keybinds.AutoSteal  and input.KeyCode == Keybinds.AutoSteal  then
        local newState = AutoStealBtn.BackgroundColor3 ~= ACCENT
        updateToggle(AutoStealBtn, newState); if newState then task.spawn(function() initAutoStealGUI(); createCircle() end)
        else if autoStealGui then pcall(function() autoStealGui:Destroy() end)
        autoStealGui = nil end; for _, p in ipairs(circleParts) do if p then pcall(function() p:Destroy() end) end end; table.clear(circleParts) end
    elseif Keybinds.BatAimbot  and input.KeyCode == Keybinds.BatAimbot  then tog(BatAimbotBtn,   startBatAimbot,  stopBatAimbot)
    elseif Keybinds.AntiRagdoll and input.KeyCode == Keybinds.AntiRagdoll then tog(AntiRagdollBtn, EnableAntiRagdoll, DisableAntiRagdoll)
    elseif Keybinds.NoAnimations and input.KeyCode == Keybinds.NoAnimations then
        local newState = NoAnimBtn.BackgroundColor3 ~= ACCENT
        updateToggle(NoAnimBtn, newState); toggleNoAnimations(newState)
    end
end)
RunService.Heartbeat:Connect(function()
    if AutoStealBtn.BackgroundColor3~=ACCENT then return end
    local hrp=getHRP(); if not hrp then return end
    for _,a in ipairs(allAnimalsCache) do
        if (hrp.Position-a.worldPosition).Magnitude<=AUTO_STEAL_PROX_RADIUS then
            local p=findPrompt(a); if not p then continue end
            build(p)
            local d=InternalStealCache[p]; if not d then continue end
            if #d.h>0 then for i=1,#d.h do pcall(d.h[i]) end end
            if #d.t>0 then for i=1,#d.t do pcall(d.t[i]) end end
            if #d.h==0 and #d.t==0 and fireproximityprompt then fireproximityprompt(p) end
        end
    end
end)
RunService.RenderStepped:Connect(function() if AutoStealBtn.BackgroundColor3 ~= ACCENT then return end
    local hrp = getHRP(); if not hrp then return end
    if #circleParts == 0 then createCircle() end
    AUTO_STEAL_PROX_RADIUS = Config.GrabRadius
    for i, p in ipairs(circleParts) do
        local a1 = math.rad((i-1)/PartsCount*360); local a2 = math.rad(i/PartsCount*360)
        local p1 = Vector3.new(math.cos(a1),0,math.sin(a1))*AUTO_STEAL_PROX_RADIUS
        local p2 = Vector3.new(math.cos(a2),0,math.sin(a2))*AUTO_STEAL_PROX_RADIUS
        local c = (p1+p2)/2+hrp.Position
        p.Size = Vector3.new((p2-p1).Magnitude,0.2,0.3)
        p.CFrame = CFrame.new(c,c+Vector3.new(p2.X-p1.X,0,p2.Z-p1.Z))*CFrame.Angles(0,math.pi/2,0)
    end
end)
player.CharacterAdded:Connect(function() task.wait(1)
    pcall(function() workspace.CurrentCamera.FieldOfView = Config.FOV end)
    if AutoStealBtn.BackgroundColor3 == ACCENT then createCircle() end
    if NoAnimBtn.BackgroundColor3 == ACCENT then toggleNoAnimations(true) end
end)
local floatConn = nil
local floatY = nil
local spinBAV2 = nil
local function startMobileFloat()
    local hrp = getHRP(); if not hrp then return end
    floatY = hrp.Position.Y
    if floatConn then floatConn:Disconnect(); floatConn = nil end
    floatConn = RunService.Heartbeat:Connect(function() local h = getHRP(); if not h then return end
        local vel = h.AssemblyLinearVelocity
        h.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z); if floatY then
            local diff = h.Position.Y - floatY
            if math.abs(diff) > 0.3 then
                h.CFrame = CFrame.new(h.Position.X, floatY, h.Position.Z)
            end
        end
    end)
end
local function stopMobileFloat()
    if floatConn then floatConn:Disconnect(); floatConn = nil end
    floatY = nil
end
local function startMobileSpin()
    local hrp = getHRP(); if not hrp then return end
    if spinBAV2 then spinBAV2:Destroy() end
    spinBAV2 = Instance.new("BodyAngularVelocity"); spinBAV2.MaxTorque = Vector3.new(0, math.huge, 0)
    spinBAV2.AngularVelocity = Vector3.new(0, 50, 0) spinBAV2.Parent = hrp
end
local function stopMobileSpin()
    if spinBAV2 then spinBAV2:Destroy(); spinBAV2 = nil end
end
local MobileButtonsGui = Instance.new("ScreenGui")
MobileButtonsGui.Name = "SecretMobileButtons"; MobileButtonsGui.ResetOnSpawn = false
MobileButtonsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
MobileButtonsGui.Enabled = false; MobileButtonsGui.Parent = player:WaitForChild("PlayerGui")
local function createMobileButton(text, position)
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(0,65,0,65); btn.Position = position
    btn.BackgroundColor3 = BG_CARD; btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255,255,255); btn.Font = Enum.Font.GothamBold
    btn.TextSize = 9; btn.TextWrapped = true; btn.BorderSizePixel = 0
    btn.Parent = MobileButtonsGui
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1,0)
    local s = Instance.new("UIStroke"); s.Color = ACCENT; s.Thickness = 2.5; s.Transparency = 0.3; s.Parent = btn
    return btn
end
local MobileFloatBtn  = Instance.new("TextButton") -- removed
local MobileUngrabBtn = createMobileButton("UNGRAB",     UDim2.new(1,-80,0.10,0))
local MobileBatBtn    = createMobileButton("BAT AIMBOT", UDim2.new(1,-80,0.24,0))
local MobileTauntBtn  = createMobileButton("TAUNT",      UDim2.new(1,-80,0.38,0))
local MobileSpinBtn   = createMobileButton("SPINBOT",    UDim2.new(1,-80,0.52,0))
local MobileStealBtn  = Instance.new("TextButton") -- hidden
local MobileLeftBtn   = Instance.new("TextButton")  -- hidden
local MobileRightBtn  = Instance.new("TextButton")  -- hidden
local MobileLeftMobBtn  = createMobileButton("SECRET LEFT",  UDim2.new(0,10,0.3,-27))
local MobileRightMobBtn = createMobileButton("SECRET RIGHT", UDim2.new(0,10,0.3,46))
MobileSupportBtn.MouseButton1Click:Connect(function() local newState = MobileSupportBtn.BackgroundColor3 ~= ACCENT
    updateToggle(MobileSupportBtn, newState); MobileButtonsGui.Enabled = newState
end)
local function stealNearby()
    local h=getHRP(); if not h then return end
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local ok,p=pcall(function() return v.Parent.Position end)
            if ok and (p-h.Position).Magnitude<20 then
                if not InternalStealCache[v] then build(v) end
                local d=InternalStealCache[v]
                if d then
                    if #d.h>0 then for i=1,#d.h do pcall(d.h[i]) end end
                    if #d.t>0 then for i=1,#d.t do pcall(d.t[i]) end end
                    if #d.h==0 and #d.t==0 and fireproximityprompt then fireproximityprompt(v) end
                end; break
            end
        end
    end
end
MobileLeftMobBtn.MouseButton1Click:Connect(function()
    if leftActive then
        leftActive=false; MobileLeftMobBtn.BackgroundColor3=BG_CARD; MobileLeftMobBtn.TextColor3=Color3.fromRGB(255,255,255)
        local h=getHRP(); if h then h.AssemblyLinearVelocity=Vector3.zero end
        local hm=getHum(); if hm then hm:Move(Vector3.zero,false) end; return
    end
    leftActive=true; rightActive=false
    MobileLeftMobBtn.BackgroundColor3=ACCENT; MobileLeftMobBtn.TextColor3=BG_DARK
    MobileRightMobBtn.BackgroundColor3=BG_CARD; MobileRightMobBtn.TextColor3=Color3.fromRGB(255,255,255)
    task.spawn(function()
        while leftActive do
            moveToTargets(leftTargets)
            if not leftActive then break end
            task.wait(0.25)
            if not leftActive then break end
            stealNearby()
            if not leftActive then break end
            local os=speed; speed=Config.StealSpeed
            local safePoint=Vector3.new(-474.6,-7.01,94.19)
            moveToTargets({safePoint,rightTargets[1],rightTargets[2]})
            speed=os
            if not leftActive then break end
            task.wait(0.1)
        end
        leftActive=false; MobileLeftMobBtn.BackgroundColor3=BG_CARD; MobileLeftMobBtn.TextColor3=Color3.fromRGB(255,255,255)
        local h=getHRP(); if h then h.AssemblyLinearVelocity=Vector3.zero end
    end)
end)
MobileRightMobBtn.MouseButton1Click:Connect(function()
    if rightActive then
        rightActive=false; MobileRightMobBtn.BackgroundColor3=BG_CARD; MobileRightMobBtn.TextColor3=Color3.fromRGB(255,255,255)
        local h=getHRP(); if h then h.AssemblyLinearVelocity=Vector3.zero end
        local hm=getHum(); if hm then hm:Move(Vector3.zero,false) end; return
    end
    rightActive=true; leftActive=false
    MobileRightMobBtn.BackgroundColor3=ACCENT; MobileRightMobBtn.TextColor3=BG_DARK
    MobileLeftMobBtn.BackgroundColor3=BG_CARD; MobileLeftMobBtn.TextColor3=Color3.fromRGB(255,255,255)
    task.spawn(function()
        while rightActive do
            moveToTargets(rightTargets)
            if not rightActive then break end
            task.wait(0.25)
            if not rightActive then break end
            stealNearby()
            if not rightActive then break end
            local os=speed; speed=Config.StealSpeed
            local safeExit=Vector3.new(-473.22,-7.0,26.59)
            moveToTargets({safeExit,leftTargets[1],leftTargets[2]})
            speed=os
            if not rightActive then break end
            task.wait(0.1)
        end
        rightActive=false; MobileRightMobBtn.BackgroundColor3=BG_CARD; MobileRightMobBtn.TextColor3=Color3.fromRGB(255,255,255)
        local h=getHRP(); if h then h.AssemblyLinearVelocity=Vector3.zero end
    end)
end)
local dropBusy = false
local dropFloatConn = nil
local function doDrop()
    if dropBusy or not getHRP() then return end
    dropBusy = true
    if dropFloatConn then dropFloatConn:Disconnect(); dropFloatConn = nil end
    local hrp2 = getHRP() local origY = hrp2.Position.Y
    local targetY = origY + 20
    local goingUp = true
    dropFloatConn = RunService.Heartbeat:Connect(function()
        local h = getHRP(); if not h then dropBusy = false; if dropFloatConn then dropFloatConn:Disconnect(); dropFloatConn = nil end; return end
        local currentTarget = goingUp and targetY or origY
        local diff = currentTarget - h.Position.Y
        h.AssemblyLinearVelocity = Vector3.new(h.AssemblyLinearVelocity.X, math.clamp(diff*25,-300,300), h.AssemblyLinearVelocity.Z)
        if goingUp and h.Position.Y >= targetY - 1 then goingUp = false end
        if not goingUp and math.abs(diff) < 1.5 then
            h.AssemblyLinearVelocity = Vector3.new(h.AssemblyLinearVelocity.X, 0, h.AssemblyLinearVelocity.Z)
            dropFloatConn:Disconnect(); dropFloatConn = nil; dropBusy = false
        end
    end)
end
MobileUngrabBtn.MouseButton1Click:Connect(function() doDrop()
    tw(MobileUngrabBtn, {BackgroundColor3 = ACCENT}); MobileUngrabBtn.TextColor3 = BG_DARK
    task.delay(0.35, function() tw(MobileUngrabBtn, {BackgroundColor3 = BG_CARD})
        MobileUngrabBtn.TextColor3 = Color3.fromRGB(255,255,255)
    end)
end)
local spinMobileOn = false
MobileSpinBtn.MouseButton1Click:Connect(function() spinMobileOn = not spinMobileOn
    MobileSpinBtn.BackgroundColor3 = spinMobileOn and ACCENT or BG_CARD
    MobileSpinBtn.TextColor3 = spinMobileOn and BG_DARK or Color3.fromRGB(255,255,255)
    if spinMobileOn then startMobileSpin() else stopMobileSpin() end
end)
local tauntMobileOn = false
local function sendChat(msg)
    pcall(function() local e=game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents",true)
        if e then local s=e:FindFirstChild("SayMessageRequest"); if s then s:FireServer(msg,"All") end end end)
    pcall(function() local c=game:GetService("TextChatService"):FindFirstChild("TextChannels")
        if c then local g=c:FindFirstChild("RBXGeneral"); if g then g:SendAsync(msg) end end end)
end
MobileTauntBtn.MouseButton1Click:Connect(function() sendChat("/lol Secret Hub 😂😂")
    task.wait(0.5) sendChat("/lol Secret Hub 😂😂")
    tw(MobileTauntBtn, {BackgroundColor3 = ACCENT}); MobileTauntBtn.TextColor3 = BG_DARK
    task.delay(0.6, function() tw(MobileTauntBtn, {BackgroundColor3 = BG_CARD})
        MobileTauntBtn.TextColor3 = Color3.fromRGB(255,255,255)
    end)
end)
MobileStealBtn.MouseButton1Click:Connect(function() local newState = AutoStealBtn.BackgroundColor3 ~= ACCENT
    updateToggle(AutoStealBtn, newState); MobileStealBtn.BackgroundColor3 = newState and ACCENT or BG_CARD
    MobileStealBtn.TextColor3 = newState and BG_DARK or Color3.fromRGB(255,255,255)
    if newState then task.spawn(function() initAutoStealGUI(); createCircle() end)
    else if autoStealGui then pcall(function() autoStealGui:Destroy() end)
    autoStealGui = nil end; for _, p in ipairs(circleParts) do if p then pcall(function() p:Destroy() end) end end; table.clear(circleParts) end
end)
MobileBatBtn.MouseButton1Click:Connect(function() local newState = BatAimbotBtn.BackgroundColor3 ~= ACCENT
    updateToggle(BatAimbotBtn, newState); MobileBatBtn.BackgroundColor3 = newState and ACCENT or BG_CARD
    MobileBatBtn.TextColor3 = newState and BG_DARK or Color3.fromRGB(255,255,255)
    if newState then startBatAimbot() else stopBatAimbot() end
end)
MobileLeftBtn.MouseButton1Click:Connect(function() MobileLeftMobBtn.MouseButton1Click:Fire()
end)
MobileRightBtn.MouseButton1Click:Connect(function() MobileRightMobBtn.MouseButton1Click:Fire()
end)
local OpenCloseBtnGui = Instance.new("ScreenGui")
OpenCloseBtnGui.Name = "SecretOpenClose"; OpenCloseBtnGui.ResetOnSpawn = false
OpenCloseBtnGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
OpenCloseBtnGui.Parent = player:WaitForChild("PlayerGui"); local OpenCloseBtn = Instance.new("TextButton")
OpenCloseBtn.Size = UDim2.new(0,52,0,52); OpenCloseBtn.Position = UDim2.new(0,10,0.5,-26)
OpenCloseBtn.BackgroundColor3 = BG_DARK; OpenCloseBtn.Text = "SD"
OpenCloseBtn.TextSize = 14; OpenCloseBtn.Font = Enum.Font.GothamBlack
OpenCloseBtn.TextColor3 = ACCENT; OpenCloseBtn.BorderSizePixel = 0; OpenCloseBtn.Active = true
OpenCloseBtn.Parent = OpenCloseBtnGui
Instance.new("UICorner", OpenCloseBtn).CornerRadius = UDim.new(0,14)
local OCStroke = Instance.new("UIStroke"); OCStroke.Thickness = 2.5; OCStroke.Color = ACCENT; OCStroke.Parent = OpenCloseBtn
task.spawn(function() while OpenCloseBtn and OpenCloseBtn.Parent do
        for i=0,20 do if not OpenCloseBtn.Parent then break end OCStroke.Thickness=2.5+(i*0.05); task.wait(0.04) end
        for i=0,20 do if not OpenCloseBtn.Parent then break end OCStroke.Thickness=3.5-(i*0.05); task.wait(0.04) end
    end
end)
do
    local dragging, dragStart, startPos = false, nil, nil
    OpenCloseBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = OpenCloseBtn.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local d = input.Position - dragStart
            OpenCloseBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
end
OpenCloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible
    TweenService:Create(OCStroke, TweenInfo.new(0.15), {Color = MainFrame.Visible and Color3.fromRGB(200,200,200) or ACCENT}):Play()
end)
ScreenGui.Parent = player:WaitForChild("PlayerGui") task.spawn(function()
    for i = 0, 1, 0.05 do MainFrame.BackgroundTransparency = 1 - i; task.wait(0.025) end
end)
task.spawn(function() initAutoStealGUI(); createCircle() end)
-- Restore saved features
task.wait(0.5)
if savedFeatures then
    local sf=savedFeatures
    local function ap(b,s,f) if s and b then updateToggle(b,true); if f then f() end end end
    ap(AutoStealBtn,sf.AutoSteal,nil) ap(SpeedBoostBtn,sf.SpeedBoost,nil)
    ap(BatAimbotBtn,sf.BatAimbot,startBatAimbot) ap(GalaxyBtn,sf.Galaxy,startGalaxy)
    ap(OptimizerBtn,sf.Optimizer,nil) ap(AntiRagdollBtn,sf.AntiRagdoll,startAntiRagdoll)
    ap(NoAnimBtn,sf.NoAnimations,toggleNoAnimations) ap(SpinbotBtn,sf.Spinbot,startSpinbot)
    ap(InfJumpBtn,sf.InfJump,startInfJump) ap(NoclipBtn,sf.Noclip,startNoclip)
    ap(FullbrightBtn,sf.Fullbright,enableFullbright)
else updateToggle(AutoStealBtn,true) end
pcall(function() workspace.CurrentCamera.FieldOfView = Config.FOV end)
print("SECRET DUEL Loaded! discord.gg/JaFSsH8RrU")
