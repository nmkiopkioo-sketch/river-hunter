-- ==============================================================================
-- Project Name: เรื่องโปร Hub | ProScript [River Hunter - นักล่าแห่งสายน้ำ]
-- Platform: PC & Mobile (Universal Executor Support)
-- Features:
--   1. Custom External UI (gethui / CoreGui / PlayerGui) with Topmost DisplayOrder
--   2. Fixed Auto-Hookset & Strike Tap (แก้ปัญหาปลาติดแล้วไม่กดให้ ทั้งคอมและมือถือ)
--   3. Smart Anti-Snap Fight, Auto Steer (Left/Right), Auto Jerk, Auto Reel & Auto Sell
--   4. Smooth Noclip Tween Travel + Boat & Elephant Spawner
--   5. Boss River Alerts, Fish School Highlights, Player ESP, Movement & FPS Boost
-- ==============================================================================

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

-- Safe Executor Fallbacks (PC & Mobile: Delta, Arceus X, Codex, Hydrogen, Fluxus, Synapse, Wave, Solara)
local _gethui = (type(gethui) == "function" and gethui) or nil
local _setclipboard = (type(setclipboard) == "function" and setclipboard) or (type(toclipboard) == "function" and toclipboard) or nil
local _firesignal = (type(firesignal) == "function" and firesignal) or nil
local _hookmetamethod = (type(hookmetamethod) == "function" and hookmetamethod) or nil
local _getnamecallmethod = (type(getnamecallmethod) == "function" and getnamecallmethod) or nil
local _checkcaller = (type(checkcaller) == "function" and checkcaller) or function() return false end
local _newcclosure = (type(newcclosure) == "function" and newcclosure) or function(f) return f end
local _getcustomasset = (type(getcustomasset) == "function" and getcustomasset) or (type(getsynasset) == "function" and getsynasset) or nil

local VirtualInputManager = nil
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)

-- River Hunter Remotes (Verified from PlaceId 92700843475315)
local FishingRemotes = ReplicatedStorage:WaitForChild("FishingRemotes", 10)
local CastRemote = FishingRemotes and FishingRemotes:FindFirstChild("Cast")
local InputRemote = FishingRemotes and FishingRemotes:FindFirstChild("Input")
local StateRemote = FishingRemotes and FishingRemotes:FindFirstChild("State")
local TickRemote = FishingRemotes and FishingRemotes:FindFirstChild("Tick")
local GarageRemote = FishingRemotes and FishingRemotes:FindFirstChild("Garage")

-- Resolve External/Topmost GUI Container (gethui -> CoreGui -> PlayerGui)
local function GetExternalGuiParent()
    if _gethui then
        local ok, hui = pcall(_gethui)
        if ok and hui then return hui end
    end

    local successCore, coreRef = pcall(function()
        local test = Instance.new("Folder")
        test.Parent = CoreGui
        test:Destroy()
        return CoreGui
    end)
    if successCore and coreRef then
        return coreRef
    end

    return PlayerGui
end

-- Remove previous UI, Connections, and Blur instances across all containers
local function CleanupExistingUI()
    if _G.ProScriptRHConnections then
        for _, conn in ipairs(_G.ProScriptRHConnections) do
            pcall(function() conn:Disconnect() end)
        end
    end
    _G.ProScriptRHConnections = {}

    local containers = {PlayerGui}
    if _gethui then
        pcall(function() table.insert(containers, _gethui()) end)
    end
    pcall(function()
        table.insert(containers, CoreGui)
    end)

    for _, parentObj in ipairs(containers) do
        pcall(function()
            if parentObj and parentObj:FindFirstChild("ProScriptHub") then
                parentObj.ProScriptHub:Destroy()
            end
        end)
    end

    if Lighting:FindFirstChild("ProScriptBlur") then
        Lighting.ProScriptBlur:Destroy()
    end
end

CleanupExistingUI()

local Connections = _G.ProScriptRHConnections
local function TrackConn(conn)
    table.insert(Connections, conn)
    return conn
end

local TargetGuiParent = GetExternalGuiParent()

-- Runtime Configuration State
local Config = {
    -- Auto Fish & Fight
    AutoFish = false,
    AutoHookTap = true,
    HooksetDelay = 0.05,
    CastDistance = "ไกล (Far)", -- "ไกล (Far)" or "กลาง (Medium)"
    CastHold = 0.55,
    AutoReelLure = true,
    ReelSpeed = 0.70,
    AutoJerk = true,
    JerkDelay = 1.5,

    -- Fight & Sell
    SmartFight = true,
    MaxTension = 0.85,
    AutoSteer = true,
    FastTug = true,
    NoReelTug = true,
    ReelBelowTension = 0.50,
    AutoSell = false,
    SellThreshold = 15,

    -- Tween Travel
    TweenSpeed = 65,

    -- Visuals & ESP
    BossAlert = true,
    RadarMode = false,
    ESPMaster = false,
    FishSchoolESP = false,
    ESPNameDist = true,
    ESPColor = Color3.fromRGB(62, 235, 130),
    ESPRainbow = false,
    ESPMaxDist = 2000,

    -- Movement & Performance
    SpeedBoost = false,
    WalkSpeed = 36,
    HighJump = false,
    JumpPower = 80,
    InfiniteJump = false,
    Noclip = false,
    FlyMode = false,
    FlySpeed = 50,
    ReduceEffects = false,
    LowGraphics = false,
    FPSBoost = false,

    -- Settings & Protection
    AntiBan = true,
    AntiAFK = true,
    UIBlur = false,
    UITransparency = 0.04,
    LightSoftTheme = false,
    UIFontScale = 100
}

-- Eye-Friendly Modern Dark-Emerald Theme Palette
local Theme = {
    Background = Color3.fromRGB(13, 18, 15),
    Sidebar = Color3.fromRGB(17, 24, 20),
    ColumnBg = Color3.fromRGB(20, 29, 24),
    CardBg = Color3.fromRGB(26, 38, 31),
    CardHover = Color3.fromRGB(32, 47, 38),
    CardStroke = Color3.fromRGB(40, 64, 49),
    AccentLight = Color3.fromRGB(72, 232, 134),
    AccentDark = Color3.fromRGB(38, 194, 98),
    Stroke = Color3.fromRGB(48, 86, 62),
    TextPrimary = Color3.fromRGB(242, 252, 245),
    TextSecondary = Color3.fromRGB(168, 202, 178),
    DangerBg = Color3.fromRGB(64, 22, 28),
    DangerHover = Color3.fromRGB(220, 48, 60),
    DangerStroke = Color3.fromRGB(235, 75, 85),
    DangerIcon = Color3.fromRGB(255, 105, 115)
}

-- Preset Color Swatches for ESP
local ESPColorPresets = {
    {Name = "เขียว", Color = Color3.fromRGB(62, 235, 130)},
    {Name = "เหลือง", Color = Color3.fromRGB(255, 215, 65)},
    {Name = "แดง", Color = Color3.fromRGB(255, 70, 80)},
    {Name = "ฟ้า", Color = Color3.fromRGB(55, 195, 255)},
    {Name = "ม่วง", Color = Color3.fromRGB(185, 105, 255)},
    {Name = "ชมพู", Color = Color3.fromRGB(255, 105, 195)},
    {Name = "ส้ม", Color = Color3.fromRGB(255, 145, 50)},
    {Name = "ขาว", Color = Color3.fromRGB(255, 255, 255)}
}

-- Typography Configuration
local Typography = {
    FontHeading = Enum.Font.GothamBlack,
    FontBold = Enum.Font.GothamBold,
    FontMedium = Enum.Font.GothamMedium,
    TitleSize = 17,
    SubTitleSize = 12,
    SectionHeader = 15,
    TabText = 14,
    ItemTitle = 14,
    ItemDesc = 12,
    ControlText = 12,
    ProfileTitle = 13,
    ProfileSub = 11
}

-- Tween Helpers
local SmoothInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local FastInfo = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function Tween(instance, info, properties)
    if not instance or not instance.Parent then return nil end
    local tween = TweenService:Create(instance, info, properties)
    tween:Play()
    return tween
end

-- Optional Background Blur Effect
local BlurEffect = Instance.new("BlurEffect")
BlurEffect.Name = "ProScriptBlur"
BlurEffect.Size = 12
BlurEffect.Enabled = Config.UIBlur
BlurEffect.Parent = Lighting

-- External Topmost ScreenGui (Renders above all in-game UIs)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ProScriptHub"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999999999
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

pcall(function()
    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
    end
end)

ScreenGui.Parent = TargetGuiParent

-- Logo Configuration
local DefaultLogo = "rbxassetid://10723414902"
local LogoUrl = "https://i.postimg.cc/BQHJQMyH/loko-kemm-ng-P-re-xng-por-Hub-(1).png"

-- Universal Smooth Dragging Utility for PC and Mobile
local function MakeDraggable(handle, targetFrame, onTapCallback)
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil
    local movedDistance = 0

    TrackConn(handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position
            movedDistance = 0

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    if dragging then
                        dragging = false
                        if onTapCallback and movedDistance < 10 then
                            onTapCallback()
                        end
                    end
                end
            end)
        end
    end))

    TrackConn(handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    TrackConn(UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            movedDistance = delta.Magnitude
            Tween(targetFrame, TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            })
        end
    end))
end

-- Dynamic Transparency & Font Scaling Registries
local TransparentFrames = {
    Main = {},
    Sub = {},
    Cards = {}
}

local RegisteredTexts = {}
local function RegisterText(label, baseSize)
    label.TextSize = baseSize
    table.insert(RegisteredTexts, {Instance = label, BaseSize = baseSize})
end

local function ApplyFontScale(scalePercent)
    Config.UIFontScale = scalePercent
    local multiplier = scalePercent / 100
    for _, item in ipairs(RegisteredTexts) do
        if item.Instance and item.Instance.Parent then
            item.Instance.TextSize = math.clamp(math.floor(item.BaseSize * multiplier + 0.5), 10, 26)
        end
    end
end

local function ApplyTransparency(val)
    Config.UITransparency = val
    local subTrans = math.clamp(val * 0.85, 0, 0.88)
    local cardTrans = math.clamp(val * 0.65, 0, 0.82)
    for _, frame in ipairs(TransparentFrames.Main) do
        Tween(frame, FastInfo, {BackgroundTransparency = val})
    end
    for _, frame in ipairs(TransparentFrames.Sub) do
        Tween(frame, FastInfo, {BackgroundTransparency = subTrans})
    end
    for _, frame in ipairs(TransparentFrames.Cards) do
        Tween(frame, FastInfo, {BackgroundTransparency = cardTrans})
    end
end

-- Floating Toggle Button (Upper-Left-Center, Topmost ZIndex = 200)
local DefaultOpenBtnPos = UDim2.new(0.28, 0, 0.08, 0)

local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Parent = ScreenGui
OpenButton.AnchorPoint = Vector2.new(0.5, 0.5)
OpenButton.BackgroundColor3 = Theme.Background
OpenButton.BackgroundTransparency = 0.04
OpenButton.Position = DefaultOpenBtnPos
OpenButton.Size = UDim2.new(0, 56, 0, 56)
OpenButton.AutoButtonColor = false
OpenButton.Text = ""
OpenButton.ZIndex = 200

local OpenCorner = Instance.new("UICorner")
OpenCorner.CornerRadius = UDim.new(1, 0)
OpenCorner.Parent = OpenButton

local OpenStroke = Instance.new("UIStroke")
OpenStroke.Color = Theme.AccentLight
OpenStroke.Thickness = 2.2
OpenStroke.Transparency = 0.08
OpenStroke.Parent = OpenButton

local OpenLogo = Instance.new("ImageLabel")
OpenLogo.Parent = OpenButton
OpenLogo.BackgroundTransparency = 1
OpenLogo.Position = UDim2.new(0, 3, 0, 3)
OpenLogo.Size = UDim2.new(1, -6, 1, -6)
OpenLogo.Image = DefaultLogo
OpenLogo.ScaleType = Enum.ScaleType.Fit
OpenLogo.ZIndex = 201

local OpenLogoCorner = Instance.new("UICorner")
OpenLogoCorner.CornerRadius = UDim.new(1, 0)
OpenLogoCorner.Parent = OpenLogo

local OpenStatusDot = Instance.new("Frame")
OpenStatusDot.Parent = OpenButton
OpenStatusDot.BackgroundColor3 = Theme.AccentLight
OpenStatusDot.Position = UDim2.new(1, -14, 1, -14)
OpenStatusDot.Size = UDim2.new(0, 12, 0, 12)
OpenStatusDot.ZIndex = 202

local OpenDotCorner = Instance.new("UICorner")
OpenDotCorner.CornerRadius = UDim.new(1, 0)
OpenDotCorner.Parent = OpenStatusDot

local OpenDotStroke = Instance.new("UIStroke")
OpenDotStroke.Color = Theme.Background
OpenDotStroke.Thickness = 2
OpenDotStroke.Parent = OpenStatusDot

-- Main Window Frame
local DefaultW, DefaultH = 730, 450
local MinW, MinH = 540, 330
local MaxW, MaxH = 960, 600

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BackgroundTransparency = Config.UITransparency
MainFrame.BorderSizePixel = 0
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.Size = UDim2.new(0, DefaultW, 0, DefaultH)
MainFrame.ClipsDescendants = true
MainFrame.Visible = true
MainFrame.Active = true
MainFrame.ZIndex = 100
table.insert(TransparentFrames.Main, MainFrame)

-- Responsive Cross-Platform UIScale (Auto-fits Mobile Portrait/Landscape, Tablet, and PC)
local MainScale = Instance.new("UIScale")
MainScale.Parent = MainFrame

local function GetResponsiveBaseScale()
    local vp = Camera and Camera.ViewportSize or Vector2.new(1280, 720)
    local scaleX = (vp.X - 24) / DefaultW
    local scaleY = (vp.Y - 24) / DefaultH
    local minFit = math.min(scaleX, scaleY)
    if minFit < 1 then
        return math.clamp(minFit, 0.48, 1)
    end
    return 1
end

local BaseScale = GetResponsiveBaseScale()
MainScale.Scale = BaseScale

TrackConn(Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    BaseScale = GetResponsiveBaseScale()
    if MainFrame.Visible then
        MainScale.Scale = BaseScale
    end
end))

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.Stroke
MainStroke.Thickness = 1.8
MainStroke.Transparency = 0.15
MainStroke.Parent = MainFrame

-- Window Visibility Controller
local isWindowOpen = true
local isMinimized = false

local function SetWindowVisible(state)
    isWindowOpen = state
    BaseScale = GetResponsiveBaseScale()
    if state then
        MainFrame.Visible = true
        MainScale.Scale = BaseScale * 0.92
        Tween(MainScale, SmoothInfo, {Scale = BaseScale})
        Tween(OpenButton, FastInfo, {Size = UDim2.new(0, 56, 0, 56)})
        Tween(OpenStatusDot, FastInfo, {BackgroundColor3 = Theme.AccentLight})
        if Config.UIBlur and not isMinimized then
            BlurEffect.Enabled = true
            Tween(BlurEffect, SmoothInfo, {Size = 12})
        end
    else
        Tween(MainScale, FastInfo, {Scale = BaseScale * 0.92})
        Tween(OpenButton, FastInfo, {Size = UDim2.new(0, 50, 0, 50)})
        Tween(OpenStatusDot, FastInfo, {BackgroundColor3 = Theme.DangerHover})
        if Config.UIBlur then
            Tween(BlurEffect, FastInfo, {Size = 0})
            task.delay(0.16, function()
                if not isWindowOpen then
                    BlurEffect.Enabled = false
                end
            end)
        end
        task.delay(0.15, function()
            if not isWindowOpen then
                MainFrame.Visible = false
            end
        end)
    end
end

MakeDraggable(OpenButton, OpenButton, function()
    SetWindowVisible(not isWindowOpen)
end)

-- Top Header Bar
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Parent = MainFrame
TopBar.BackgroundColor3 = Theme.Sidebar
TopBar.BackgroundTransparency = Config.UITransparency * 0.85
TopBar.BorderSizePixel = 0
TopBar.Size = UDim2.new(1, 0, 0, 56)
TopBar.Active = true
table.insert(TransparentFrames.Sub, TopBar)

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 14)
TopCorner.Parent = TopBar

local TopFix = Instance.new("Frame")
TopFix.Parent = TopBar
TopFix.BackgroundColor3 = Theme.Sidebar
TopFix.BackgroundTransparency = Config.UITransparency * 0.85
TopFix.BorderSizePixel = 0
TopFix.Position = UDim2.new(0, 0, 1, -14)
TopFix.Size = UDim2.new(1, 0, 0, 14)
table.insert(TransparentFrames.Sub, TopFix)

local TopDivider = Instance.new("Frame")
TopDivider.Parent = TopBar
TopDivider.BackgroundColor3 = Theme.Stroke
TopDivider.BackgroundTransparency = 0.55
TopDivider.BorderSizePixel = 0
TopDivider.Position = UDim2.new(0, 0, 1, -1)
TopDivider.Size = UDim2.new(1, 0, 0, 1)

MakeDraggable(TopBar, MainFrame)

-- Header Logo
local HeaderLogo = Instance.new("ImageLabel")
HeaderLogo.Parent = TopBar
HeaderLogo.BackgroundColor3 = Theme.CardBg
HeaderLogo.Position = UDim2.new(0, 14, 0.5, -19)
HeaderLogo.Size = UDim2.new(0, 38, 0, 38)
HeaderLogo.Image = DefaultLogo

local HeaderLogoCorner = Instance.new("UICorner")
HeaderLogoCorner.CornerRadius = UDim.new(1, 0)
HeaderLogoCorner.Parent = HeaderLogo

local HeaderLogoStroke = Instance.new("UIStroke")
HeaderLogoStroke.Color = Theme.AccentLight
HeaderLogoStroke.Thickness = 1.5
HeaderLogoStroke.Parent = HeaderLogo

-- Asynchronous Custom Logo Loader
task.spawn(function()
    pcall(function()
        if _getcustomasset and writefile and isfile then
            local fileName = "ProScript_Logo_V3.png"
            if not isfile(fileName) then
                writefile(fileName, game:HttpGet(LogoUrl))
            end
            local customId = _getcustomasset(fileName)
            if customId then
                OpenLogo.Image = customId
                HeaderLogo.Image = customId
            end
        end
    end)
end)

-- Header Title & Clickable Credit Subtitle
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Parent = TopBar
TitleLabel.BackgroundTransparency = 1
TitleLabel.Position = UDim2.new(0, 62, 0, 8)
TitleLabel.Size = UDim2.new(1, -165, 0, 22)
TitleLabel.Font = Typography.FontHeading
TitleLabel.Text = "เรื่องโปร Hub | River Hunter"
TitleLabel.TextColor3 = Theme.TextPrimary
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
RegisterText(TitleLabel, Typography.TitleSize)

local CreditButton = Instance.new("TextButton")
CreditButton.Parent = TopBar
CreditButton.BackgroundTransparency = 1
CreditButton.Position = UDim2.new(0, 62, 0, 30)
CreditButton.Size = UDim2.new(1, -165, 0, 18)
CreditButton.Font = Typography.FontMedium
CreditButton.Text = "ช่องนี้เรื่องโปร | ดิสคอร์ด: https://discord.gg/gZpkSgmR8"
CreditButton.TextColor3 = Theme.AccentLight
CreditButton.TextXAlignment = Enum.TextXAlignment.Left
RegisterText(CreditButton, Typography.SubTitleSize)

CreditButton.MouseButton1Click:Connect(function()
    pcall(function()
        if _setclipboard then
            _setclipboard("https://discord.gg/gZpkSgmR8")
            CreditButton.Text = "คัดลอกลิงก์ดิสคอร์ดเรียบร้อยแล้ว!"
            task.wait(1.5)
            CreditButton.Text = "ช่องนี้เรื่องโปร | ดิสคอร์ด: https://discord.gg/gZpkSgmR8"
        end
    end)
end)

-- Vector Collapse/Minimize Tab Button
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Parent = TopBar
MinimizeButton.BackgroundColor3 = Theme.CardBg
MinimizeButton.BackgroundTransparency = 0.1
MinimizeButton.Position = UDim2.new(1, -92, 0.5, -17)
MinimizeButton.Size = UDim2.new(0, 34, 0, 34)
MinimizeButton.AutoButtonColor = false
MinimizeButton.Text = ""

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 9)
MinCorner.Parent = MinimizeButton

local MinStroke = Instance.new("UIStroke")
MinStroke.Color = Theme.Stroke
MinStroke.Thickness = 1.2
MinStroke.Transparency = 0.25
MinStroke.Parent = MinimizeButton

local MinBarH = Instance.new("Frame")
MinBarH.Name = "MinBarH"
MinBarH.Parent = MinimizeButton
MinBarH.AnchorPoint = Vector2.new(0.5, 0.5)
MinBarH.BackgroundColor3 = Theme.TextPrimary
MinBarH.BorderSizePixel = 0
MinBarH.Position = UDim2.new(0.5, 0, 0.5, 0)
MinBarH.Size = UDim2.new(0, 14, 0, 2.5)

local MinBarHCorner = Instance.new("UICorner")
MinBarHCorner.CornerRadius = UDim.new(1, 0)
MinBarHCorner.Parent = MinBarH

local MinBarV = Instance.new("Frame")
MinBarV.Name = "MinBarV"
MinBarV.Parent = MinimizeButton
MinBarV.AnchorPoint = Vector2.new(0.5, 0.5)
MinBarV.BackgroundColor3 = Theme.TextPrimary
MinBarV.BorderSizePixel = 0
MinBarV.Position = UDim2.new(0.5, 0, 0.5, 0)
MinBarV.Size = UDim2.new(0, 2.5, 0, 0)
MinBarV.Visible = false

local MinBarVCorner = Instance.new("UICorner")
MinBarVCorner.CornerRadius = UDim.new(1, 0)
MinBarVCorner.Parent = MinBarV

MinimizeButton.MouseEnter:Connect(function()
    Tween(MinimizeButton, FastInfo, {BackgroundColor3 = Theme.AccentDark})
    Tween(MinBarH, FastInfo, {BackgroundColor3 = Theme.Background})
    Tween(MinBarV, FastInfo, {BackgroundColor3 = Theme.Background})
end)
MinimizeButton.MouseLeave:Connect(function()
    Tween(MinimizeButton, FastInfo, {BackgroundColor3 = Theme.CardBg})
    Tween(MinBarH, FastInfo, {BackgroundColor3 = Theme.TextPrimary})
    Tween(MinBarV, FastInfo, {BackgroundColor3 = Theme.TextPrimary})
end)

-- Vector Close Button (Crisp Dual-Line Cross "X" Icon)
local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Parent = TopBar
CloseButton.BackgroundColor3 = Theme.DangerBg
CloseButton.BackgroundTransparency = 0.08
CloseButton.Position = UDim2.new(1, -48, 0.5, -17)
CloseButton.Size = UDim2.new(0, 34, 0, 34)
CloseButton.AutoButtonColor = false
CloseButton.Text = ""

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 9)
CloseCorner.Parent = CloseButton

local CloseStroke = Instance.new("UIStroke")
CloseStroke.Color = Theme.DangerStroke
CloseStroke.Thickness = 1.3
CloseStroke.Transparency = 0.15
CloseStroke.Parent = CloseButton

local XLine1 = Instance.new("Frame")
XLine1.Name = "XLine1"
XLine1.Parent = CloseButton
XLine1.AnchorPoint = Vector2.new(0.5, 0.5)
XLine1.BackgroundColor3 = Theme.DangerIcon
XLine1.BorderSizePixel = 0
XLine1.Position = UDim2.new(0.5, 0, 0.5, 0)
XLine1.Size = UDim2.new(0, 16, 0, 2.5)
XLine1.Rotation = 45

local XLine1Corner = Instance.new("UICorner")
XLine1Corner.CornerRadius = UDim.new(1, 0)
XLine1Corner.Parent = XLine1

local XLine2 = Instance.new("Frame")
XLine2.Name = "XLine2"
XLine2.Parent = CloseButton
XLine2.AnchorPoint = Vector2.new(0.5, 0.5)
XLine2.BackgroundColor3 = Theme.DangerIcon
XLine2.BorderSizePixel = 0
XLine2.Position = UDim2.new(0.5, 0, 0.5, 0)
XLine2.Size = UDim2.new(0, 16, 0, 2.5)
XLine2.Rotation = -45

local XLine2Corner = Instance.new("UICorner")
XLine2Corner.CornerRadius = UDim.new(1, 0)
XLine2Corner.Parent = XLine2

CloseButton.MouseEnter:Connect(function()
    Tween(CloseButton, FastInfo, {BackgroundColor3 = Theme.DangerHover})
    Tween(XLine1, FastInfo, {BackgroundColor3 = Color3.fromRGB(255, 255, 255)})
    Tween(XLine2, FastInfo, {BackgroundColor3 = Color3.fromRGB(255, 255, 255)})
end)
CloseButton.MouseLeave:Connect(function()
    Tween(CloseButton, FastInfo, {BackgroundColor3 = Theme.DangerBg})
    Tween(XLine1, FastInfo, {BackgroundColor3 = Theme.DangerIcon})
    Tween(XLine2, FastInfo, {BackgroundColor3 = Theme.DangerIcon})
end)

-- Body Container
local BodyFrame = Instance.new("Frame")
BodyFrame.Name = "BodyFrame"
BodyFrame.Parent = MainFrame
BodyFrame.BackgroundTransparency = 1
BodyFrame.Position = UDim2.new(0, 0, 0, 56)
BodyFrame.Size = UDim2.new(1, 0, 1, -56)

-- Bottom-Right Corner Vector Resize Handle
local ResizeHandle = Instance.new("TextButton")
ResizeHandle.Name = "ResizeHandle"
ResizeHandle.Parent = MainFrame
ResizeHandle.BackgroundTransparency = 1
ResizeHandle.Position = UDim2.new(1, -24, 1, -24)
ResizeHandle.Size = UDim2.new(0, 24, 0, 24)
ResizeHandle.AutoButtonColor = false
ResizeHandle.Text = ""
ResizeHandle.ZIndex = 115

local ResizeGrip1 = Instance.new("Frame")
ResizeGrip1.Parent = ResizeHandle
ResizeGrip1.AnchorPoint = Vector2.new(0.5, 0.5)
ResizeGrip1.BackgroundColor3 = Theme.AccentLight
ResizeGrip1.BorderSizePixel = 0
ResizeGrip1.Position = UDim2.new(0.6, 0, 0.6, 0)
ResizeGrip1.Rotation = -45
ResizeGrip1.Size = UDim2.new(0, 12, 0, 2)

local ResizeGrip2 = Instance.new("Frame")
ResizeGrip2.Parent = ResizeHandle
ResizeGrip2.AnchorPoint = Vector2.new(0.5, 0.5)
ResizeGrip2.BackgroundColor3 = Theme.AccentLight
ResizeGrip2.BorderSizePixel = 0
ResizeGrip2.Position = UDim2.new(0.75, 0, 0.75, 0)
ResizeGrip2.Rotation = -45
ResizeGrip2.Size = UDim2.new(0, 6, 0, 2)

-- Minimize & Close Logic
local savedSize = UDim2.new(0, DefaultW, 0, DefaultH)

MinimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        savedSize = MainFrame.Size
        BodyFrame.Visible = false
        ResizeHandle.Visible = false
        TopDivider.Visible = false
        TopFix.Visible = false
        MinBarV.Visible = true
        Tween(MinBarV, FastInfo, {Size = UDim2.new(0, 2.5, 0, 14)})
        Tween(MainFrame, SmoothInfo, {Size = UDim2.new(0, savedSize.X.Offset, 0, 56)})
        if Config.UIBlur then
            Tween(BlurEffect, FastInfo, {Size = 0})
        end
    else
        Tween(MinBarV, FastInfo, {Size = UDim2.new(0, 2.5, 0, 0)})
        task.delay(0.12, function()
            if not isMinimized then MinBarV.Visible = false end
        end)
        TopDivider.Visible = true
        TopFix.Visible = true
        Tween(MainFrame, SmoothInfo, {Size = savedSize})
        if Config.UIBlur then
            BlurEffect.Enabled = true
            Tween(BlurEffect, SmoothInfo, {Size = 12})
        end
        task.delay(0.12, function()
            if not isMinimized then
                BodyFrame.Visible = true
                ResizeHandle.Visible = true
            end
        end)
    end
end)

CloseButton.MouseButton1Click:Connect(function()
    Tween(CloseButton, FastInfo, {BackgroundColor3 = Theme.DangerHover})
    task.delay(0.15, function()
        Tween(CloseButton, FastInfo, {BackgroundColor3 = Theme.DangerBg})
    end)
    SetWindowVisible(false)
end)

-- Sidebar Navigation
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Parent = BodyFrame
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BackgroundTransparency = Config.UITransparency * 0.85
Sidebar.BorderSizePixel = 0
Sidebar.Position = UDim2.new(0, 10, 0, 10)
Sidebar.Size = UDim2.new(0, 176, 1, -20)
table.insert(TransparentFrames.Sub, Sidebar)

local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 11)
SidebarCorner.Parent = Sidebar

local SidebarStroke = Instance.new("UIStroke")
SidebarStroke.Color = Theme.Stroke
SidebarStroke.Thickness = 1.1
SidebarStroke.Transparency = 0.3
SidebarStroke.Parent = Sidebar

local SidebarScroll = Instance.new("ScrollingFrame")
SidebarScroll.Parent = Sidebar
SidebarScroll.Active = true
SidebarScroll.BackgroundTransparency = 1
SidebarScroll.BorderSizePixel = 0
SidebarScroll.Position = UDim2.new(0, 8, 0, 8)
SidebarScroll.Size = UDim2.new(1, -16, 1, -68)
SidebarScroll.CanvasSize = UDim2.new(0, 0, 0, 280)
SidebarScroll.ScrollBarThickness = 2
SidebarScroll.ScrollBarImageColor3 = Theme.AccentLight

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Parent = SidebarScroll
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
SidebarLayout.Padding = UDim.new(0, 6)

TrackConn(SidebarLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    SidebarScroll.CanvasSize = UDim2.new(0, 0, 0, SidebarLayout.AbsoluteContentSize.Y + 12)
end))

-- Bottom Player Profile Card (Live Fishing Phase Indicator)
local ProfileFrame = Instance.new("Frame")
ProfileFrame.Parent = Sidebar
ProfileFrame.BackgroundColor3 = Theme.CardBg
ProfileFrame.BackgroundTransparency = Config.UITransparency * 0.65
ProfileFrame.Position = UDim2.new(0, 8, 1, -54)
ProfileFrame.Size = UDim2.new(1, -16, 0, 46)
table.insert(TransparentFrames.Cards, ProfileFrame)

local ProfileCorner = Instance.new("UICorner")
ProfileCorner.CornerRadius = UDim.new(0, 9)
ProfileCorner.Parent = ProfileFrame

local ProfileStroke = Instance.new("UIStroke")
ProfileStroke.Color = Theme.CardStroke
ProfileStroke.Thickness = 1
ProfileStroke.Transparency = 0.35
ProfileStroke.Parent = ProfileFrame

local AvatarIcon = Instance.new("ImageLabel")
AvatarIcon.Parent = ProfileFrame
AvatarIcon.BackgroundColor3 = Theme.Background
AvatarIcon.Position = UDim2.new(0, 7, 0.5, -16)
AvatarIcon.Size = UDim2.new(0, 32, 0, 32)
AvatarIcon.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=150&h=150"

local AvatarCorner = Instance.new("UICorner")
AvatarCorner.CornerRadius = UDim.new(1, 0)
AvatarCorner.Parent = AvatarIcon

local ProfileName = Instance.new("TextLabel")
ProfileName.Parent = ProfileFrame
ProfileName.BackgroundTransparency = 1
ProfileName.Position = UDim2.new(0, 46, 0, 6)
ProfileName.Size = UDim2.new(1, -52, 0, 17)
ProfileName.Font = Typography.FontBold
ProfileName.Text = string.sub(LocalPlayer.Name, 1, 5) .. "***"
ProfileName.TextColor3 = Theme.TextPrimary
ProfileName.TextXAlignment = Enum.TextXAlignment.Left
RegisterText(ProfileName, Typography.ProfileTitle)

local ProfileStatus = Instance.new("TextLabel")
ProfileStatus.Parent = ProfileFrame
ProfileStatus.BackgroundTransparency = 1
ProfileStatus.Position = UDim2.new(0, 46, 0, 23)
ProfileStatus.Size = UDim2.new(1, -52, 0, 16)
ProfileStatus.Font = Typography.FontMedium
ProfileStatus.Text = "สถานะ: พร้อมตกปลา"
ProfileStatus.TextColor3 = Theme.AccentLight
ProfileStatus.TextXAlignment = Enum.TextXAlignment.Left
RegisterText(ProfileStatus, Typography.ProfileSub)

-- Pages Holder (Dual-Column Layout)
local PagesHolder = Instance.new("Frame")
PagesHolder.Name = "PagesHolder"
PagesHolder.Parent = BodyFrame
PagesHolder.BackgroundTransparency = 1
PagesHolder.Position = UDim2.new(0, 196, 0, 10)
PagesHolder.Size = UDim2.new(1, -206, 1, -20)

local AllTabs = {}

local function CreateCategoryTab(tabName, orderIndex, leftHeaderTitle, rightHeaderTitle)
    local TabButton = Instance.new("TextButton")
    TabButton.Name = tabName .. "Tab"
    TabButton.Parent = SidebarScroll
    TabButton.BackgroundColor3 = Theme.CardBg
    TabButton.BackgroundTransparency = Config.UITransparency * 0.65
    TabButton.BorderSizePixel = 0
    TabButton.Size = UDim2.new(1, 0, 0, 40)
    TabButton.AutoButtonColor = false
    TabButton.Text = ""
    TabButton.LayoutOrder = orderIndex
    table.insert(TransparentFrames.Cards, TabButton)

    local TabCorner = Instance.new("UICorner")
    TabCorner.CornerRadius = UDim.new(0, 8)
    TabCorner.Parent = TabButton

    local IndicatorPill = Instance.new("Frame")
    IndicatorPill.Parent = TabButton
    IndicatorPill.AnchorPoint = Vector2.new(0, 0.5)
    IndicatorPill.BackgroundColor3 = Theme.TextSecondary
    IndicatorPill.Position = UDim2.new(0, 10, 0.5, 0)
    IndicatorPill.Size = UDim2.new(0, 4, 0, 14)

    local PillCorner = Instance.new("UICorner")
    PillCorner.CornerRadius = UDim.new(1, 0)
    PillCorner.Parent = IndicatorPill

    local TabLabel = Instance.new("TextLabel")
    TabLabel.Parent = TabButton
    TabLabel.BackgroundTransparency = 1
    TabLabel.Position = UDim2.new(0, 22, 0, 0)
    TabLabel.Size = UDim2.new(1, -28, 1, 0)
    TabLabel.Font = Typography.FontBold
    TabLabel.Text = tabName
    TabLabel.TextColor3 = Theme.TextSecondary
    TabLabel.TextXAlignment = Enum.TextXAlignment.Left
    RegisterText(TabLabel, Typography.TabText)

    local PageFrame = Instance.new("Frame")
    PageFrame.Name = tabName .. "Page"
    PageFrame.Parent = PagesHolder
    PageFrame.BackgroundTransparency = 1
    PageFrame.Size = UDim2.new(1, 0, 1, 0)
    PageFrame.Visible = false

    local function BuildColumn(headerText, posScale, sizeScale)
        local ColBox = Instance.new("Frame")
        ColBox.Parent = PageFrame
        ColBox.BackgroundColor3 = Theme.ColumnBg
        ColBox.BackgroundTransparency = Config.UITransparency * 0.85
        ColBox.Position = posScale
        ColBox.Size = sizeScale
        table.insert(TransparentFrames.Sub, ColBox)

        local ColCorner = Instance.new("UICorner")
        ColCorner.CornerRadius = UDim.new(0, 11)
        ColCorner.Parent = ColBox

        local ColStroke = Instance.new("UIStroke")
        ColStroke.Color = Theme.Stroke
        ColStroke.Thickness = 1.1
        ColStroke.Transparency = 0.3
        ColStroke.Parent = ColBox

        local HeaderLbl = Instance.new("TextLabel")
        HeaderLbl.Parent = ColBox
        HeaderLbl.BackgroundTransparency = 1
        HeaderLbl.Position = UDim2.new(0, 14, 0, 9)
        HeaderLbl.Size = UDim2.new(1, -28, 0, 22)
        HeaderLbl.Font = Typography.FontHeading
        HeaderLbl.Text = headerText
        HeaderLbl.TextColor3 = Theme.AccentLight
        HeaderLbl.TextXAlignment = Enum.TextXAlignment.Left
        RegisterText(HeaderLbl, Typography.SectionHeader)

        local HeaderLine = Instance.new("Frame")
        HeaderLine.Parent = ColBox
        HeaderLine.BackgroundColor3 = Theme.Stroke
        HeaderLine.BackgroundTransparency = 0.55
        HeaderLine.BorderSizePixel = 0
        HeaderLine.Position = UDim2.new(0, 12, 0, 34)
        HeaderLine.Size = UDim2.new(1, -24, 0, 1)

        local Scroll = Instance.new("ScrollingFrame")
        Scroll.Parent = ColBox
        Scroll.Active = true
        Scroll.BackgroundTransparency = 1
        Scroll.BorderSizePixel = 0
        Scroll.Position = UDim2.new(0, 8, 0, 40)
        Scroll.Size = UDim2.new(1, -16, 1, -48)
        Scroll.CanvasSize = UDim2.new(0, 0, 0, 340)
        Scroll.ScrollBarThickness = 2
        Scroll.ScrollBarImageColor3 = Theme.AccentLight

        local List = Instance.new("UIListLayout")
        List.Parent = Scroll
        List.SortOrder = Enum.SortOrder.LayoutOrder
        List.Padding = UDim.new(0, 7)

        TrackConn(List:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Scroll.CanvasSize = UDim2.new(0, 0, 0, List.AbsoluteContentSize.Y + 14)
        end))

        return Scroll
    end

    local LeftColumn = BuildColumn(leftHeaderTitle, UDim2.new(0, 0, 0, 0), UDim2.new(0.5, -5, 1, 0))
    local RightColumn = BuildColumn(rightHeaderTitle, UDim2.new(0.5, 5, 0, 0), UDim2.new(0.5, -5, 1, 0))

    local tabEntry = {
        Button = TabButton,
        Label = TabLabel,
        Pill = IndicatorPill,
        Page = PageFrame,
        Left = LeftColumn,
        Right = RightColumn
    }
    table.insert(AllTabs, tabEntry)

    TabButton.MouseButton1Click:Connect(function()
        for _, item in ipairs(AllTabs) do
            item.Page.Visible = false
            Tween(item.Button, FastInfo, {BackgroundColor3 = Theme.CardBg})
            Tween(item.Label, FastInfo, {TextColor3 = Theme.TextSecondary})
            Tween(item.Pill, FastInfo, {
                BackgroundColor3 = Theme.TextSecondary,
                Size = UDim2.new(0, 4, 0, 14)
            })
        end
        PageFrame.Visible = true
        PageFrame.Position = UDim2.new(0, 0, 0, 5)
        Tween(PageFrame, SmoothInfo, {Position = UDim2.new(0, 0, 0, 0)})
        Tween(TabButton, FastInfo, {BackgroundColor3 = Theme.AccentDark})
        Tween(TabLabel, FastInfo, {TextColor3 = Theme.Background})
        Tween(IndicatorPill, FastInfo, {
            BackgroundColor3 = Theme.Background,
            Size = UDim2.new(0, 4, 0, 22)
        })
    end)

    return tabEntry
end

-- UI Component: Clean Toggle Card
local function CreateToggle(parentScroll, titleText, descText, defaultState, callback)
    local Card = Instance.new("Frame")
    Card.Parent = parentScroll
    Card.BackgroundColor3 = Theme.CardBg
    Card.BackgroundTransparency = Config.UITransparency * 0.65
    Card.Size = UDim2.new(1, 0, 0, 62)
    table.insert(TransparentFrames.Cards, Card)

    local CardCorner = Instance.new("UICorner")
    CardCorner.CornerRadius = UDim.new(0, 8)
    CardCorner.Parent = Card

    local CardStroke = Instance.new("UIStroke")
    CardStroke.Color = Theme.CardStroke
    CardStroke.Thickness = 1
    CardStroke.Transparency = 0.4
    CardStroke.Parent = Card

    local Title = Instance.new("TextLabel")
    Title.Parent = Card
    Title.BackgroundTransparency = 1
    Title.Position = UDim2.new(0, 12, 0, 7)
    Title.Size = UDim2.new(1, -66, 0, 20)
    Title.Font = Typography.FontBold
    Title.Text = titleText
    Title.TextColor3 = Theme.TextPrimary
    Title.TextXAlignment = Enum.TextXAlignment.Left
    RegisterText(Title, Typography.ItemTitle)

    local Desc = Instance.new("TextLabel")
    Desc.Parent = Card
    Desc.BackgroundTransparency = 1
    Desc.Position = UDim2.new(0, 12, 0, 28)
    Desc.Size = UDim2.new(1, -66, 0, 28)
    Desc.Font = Typography.FontMedium
    Desc.Text = descText
    Desc.TextColor3 = Theme.TextSecondary
    Desc.TextWrapped = true
    Desc.TextXAlignment = Enum.TextXAlignment.Left
    Desc.TextYAlignment = Enum.TextYAlignment.Top
    RegisterText(Desc, Typography.ItemDesc)

    local SwitchBtn = Instance.new("TextButton")
    SwitchBtn.Parent = Card
    SwitchBtn.BackgroundColor3 = defaultState and Theme.AccentDark or Theme.Sidebar
    SwitchBtn.Position = UDim2.new(1, -50, 0.5, -11)
    SwitchBtn.Size = UDim2.new(0, 40, 0, 22)
    SwitchBtn.AutoButtonColor = false
    SwitchBtn.Text = ""

    local SwitchCorner = Instance.new("UICorner")
    SwitchCorner.CornerRadius = UDim.new(1, 0)
    SwitchCorner.Parent = SwitchBtn

    local SwitchStroke = Instance.new("UIStroke")
    SwitchStroke.Color = defaultState and Theme.AccentLight or Theme.Stroke
    SwitchStroke.Thickness = 1
    SwitchStroke.Transparency = 0.35
    SwitchStroke.Parent = SwitchBtn

    local Circle = Instance.new("Frame")
    Circle.Parent = SwitchBtn
    Circle.BackgroundColor3 = defaultState and Theme.Background or Theme.TextSecondary
    Circle.Position = defaultState and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    Circle.Size = UDim2.new(0, 18, 0, 18)

    local CircleCorner = Instance.new("UICorner")
    CircleCorner.CornerRadius = UDim.new(1, 0)
    CircleCorner.Parent = Circle

    local toggled = defaultState or false
    SwitchBtn.MouseButton1Click:Connect(function()
        toggled = not toggled
        local targetPos = toggled and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        local targetBg = toggled and Theme.AccentDark or Theme.Sidebar
        local targetCircle = toggled and Theme.Background or Theme.TextSecondary
        local targetStroke = toggled and Theme.AccentLight or Theme.Stroke

        Tween(SwitchBtn, SmoothInfo, {BackgroundColor3 = targetBg})
        Tween(SwitchStroke, SmoothInfo, {Color = targetStroke})
        Tween(Circle, SmoothInfo, {Position = targetPos, BackgroundColor3 = targetCircle})

        if callback then
            callback(toggled)
        end
    end)
end

-- UI Component: Smooth Slider Card
local function CreateSlider(parentScroll, titleText, minVal, maxVal, defaultVal, isFloat, callback)
    local Card = Instance.new("Frame")
    Card.Parent = parentScroll
    Card.BackgroundColor3 = Theme.CardBg
    Card.BackgroundTransparency = Config.UITransparency * 0.65
    Card.Size = UDim2.new(1, 0, 0, 58)
    table.insert(TransparentFrames.Cards, Card)

    local CardCorner = Instance.new("UICorner")
    CardCorner.CornerRadius = UDim.new(0, 8)
    CardCorner.Parent = Card

    local CardStroke = Instance.new("UIStroke")
    CardStroke.Color = Theme.CardStroke
    CardStroke.Thickness = 1
    CardStroke.Transparency = 0.4
    CardStroke.Parent = Card

    local Title = Instance.new("TextLabel")
    Title.Parent = Card
    Title.BackgroundTransparency = 1
    Title.Position = UDim2.new(0, 12, 0, 7)
    Title.Size = UDim2.new(0.68, 0, 0, 20)
    Title.Font = Typography.FontBold
    Title.Text = titleText
    Title.TextColor3 = Theme.TextPrimary
    Title.TextXAlignment = Enum.TextXAlignment.Left
    RegisterText(Title, Typography.ItemTitle)

    local ValueLbl = Instance.new("TextLabel")
    ValueLbl.Parent = Card
    ValueLbl.BackgroundTransparency = 1
    ValueLbl.Position = UDim2.new(0.68, 0, 0, 7)
    ValueLbl.Size = UDim2.new(0.32, -12, 0, 20)
    ValueLbl.Font = Typography.FontHeading
    ValueLbl.Text = isFloat and string.format("%.2f", defaultVal) or tostring(defaultVal)
    ValueLbl.TextColor3 = Theme.AccentLight
    ValueLbl.TextXAlignment = Enum.TextXAlignment.Right
    RegisterText(ValueLbl, Typography.ItemTitle)

    local SliderBtn = Instance.new("TextButton")
    SliderBtn.Parent = Card
    SliderBtn.BackgroundColor3 = Theme.Sidebar
    SliderBtn.Position = UDim2.new(0, 12, 0, 36)
    SliderBtn.Size = UDim2.new(1, -24, 0, 8)
    SliderBtn.AutoButtonColor = false
    SliderBtn.Text = ""

    local BarCorner = Instance.new("UICorner")
    BarCorner.CornerRadius = UDim.new(1, 0)
    BarCorner.Parent = SliderBtn

    local startPercent = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)

    local Fill = Instance.new("Frame")
    Fill.Parent = SliderBtn
    Fill.BackgroundColor3 = Theme.AccentDark
    Fill.Size = UDim2.new(startPercent, 0, 1, 0)

    local FillCorner = Instance.new("UICorner")
    FillCorner.CornerRadius = UDim.new(1, 0)
    FillCorner.Parent = Fill

    local Knob = Instance.new("Frame")
    Knob.Parent = SliderBtn
    Knob.BackgroundColor3 = Theme.AccentLight
    Knob.Position = UDim2.new(startPercent, -7, 0.5, -7)
    Knob.Size = UDim2.new(0, 14, 0, 14)

    local KnobCorner = Instance.new("UICorner")
    KnobCorner.CornerRadius = UDim.new(1, 0)
    KnobCorner.Parent = Knob

    local isSliding = false
    local function UpdateFromInput(input)
        local barPos = SliderBtn.AbsolutePosition.X
        local barSize = SliderBtn.AbsoluteSize.X
        if barSize <= 0 then return end
        local ratio = math.clamp((input.Position.X - barPos) / barSize, 0, 1)
        local currentVal
        if isFloat then
            currentVal = math.floor((minVal + (maxVal - minVal) * ratio) * 100 + 0.5) / 100
            ValueLbl.Text = string.format("%.2f", currentVal)
        else
            currentVal = math.floor(minVal + (maxVal - minVal) * ratio + 0.5)
            ValueLbl.Text = tostring(currentVal)
        end
        Tween(Fill, TweenInfo.new(0.06, Enum.EasingStyle.Sine), {Size = UDim2.new(ratio, 0, 1, 0)})
        Tween(Knob, TweenInfo.new(0.06, Enum.EasingStyle.Sine), {Position = UDim2.new(ratio, -7, 0.5, -7)})
        if callback then
            callback(currentVal)
        end
    end

    TrackConn(SliderBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isSliding = true
            parentScroll.ScrollingEnabled = false
            UpdateFromInput(input)
        end
    end))

    TrackConn(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if isSliding then
                isSliding = false
                parentScroll.ScrollingEnabled = true
            end
        end
    end))

    TrackConn(UserInputService.InputChanged:Connect(function(input)
        if isSliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            UpdateFromInput(input)
        end
    end))
end

-- UI Component: Dual Option Selector
local function CreateSelector(parentScroll, titleText, optionA, optionB, callback)
    local Card = Instance.new("Frame")
    Card.Parent = parentScroll
    Card.BackgroundColor3 = Theme.CardBg
    Card.BackgroundTransparency = Config.UITransparency * 0.65
    Card.Size = UDim2.new(1, 0, 0, 64)
    table.insert(TransparentFrames.Cards, Card)

    local CardCorner = Instance.new("UICorner")
    CardCorner.CornerRadius = UDim.new(0, 8)
    CardCorner.Parent = Card

    local CardStroke = Instance.new("UIStroke")
    CardStroke.Color = Theme.CardStroke
    CardStroke.Thickness = 1
    CardStroke.Transparency = 0.4
    CardStroke.Parent = Card

    local Title = Instance.new("TextLabel")
    Title.Parent = Card
    Title.BackgroundTransparency = 1
    Title.Position = UDim2.new(0, 12, 0, 6)
    Title.Size = UDim2.new(1, -24, 0, 20)
    Title.Font = Typography.FontBold
    Title.Text = titleText
    Title.TextColor3 = Theme.TextPrimary
    Title.TextXAlignment = Enum.TextXAlignment.Left
    RegisterText(Title, Typography.ItemTitle)

    local Holder = Instance.new("Frame")
    Holder.Parent = Card
    Holder.BackgroundColor3 = Theme.Sidebar
    Holder.Position = UDim2.new(0, 12, 0, 30)
    Holder.Size = UDim2.new(1, -24, 0, 26)

    local HolderCorner = Instance.new("UICorner")
    HolderCorner.CornerRadius = UDim.new(0, 6)
    HolderCorner.Parent = Holder

    local BtnA = Instance.new("TextButton")
    BtnA.Parent = Holder
    BtnA.BackgroundColor3 = Theme.AccentDark
    BtnA.Size = UDim2.new(0.5, 0, 1, 0)
    BtnA.AutoButtonColor = false
    BtnA.Font = Typography.FontBold
    BtnA.Text = optionA
    BtnA.TextColor3 = Theme.Background
    RegisterText(BtnA, Typography.ControlText)

    local CornerA = Instance.new("UICorner")
    CornerA.CornerRadius = UDim.new(0, 6)
    CornerA.Parent = BtnA

    local BtnB = Instance.new("TextButton")
    BtnB.Parent = Holder
    BtnB.BackgroundColor3 = Theme.Sidebar
    BtnB.Position = UDim2.new(0.5, 0, 0, 0)
    BtnB.Size = UDim2.new(0.5, 0, 1, 0)
    BtnB.AutoButtonColor = false
    BtnB.Font = Typography.FontBold
    BtnB.Text = optionB
    BtnB.TextColor3 = Theme.TextSecondary
    RegisterText(BtnB, Typography.ControlText)

    local CornerB = Instance.new("UICorner")
    CornerB.CornerRadius = UDim.new(0, 6)
    CornerB.Parent = BtnB

    BtnA.MouseButton1Click:Connect(function()
        Tween(BtnA, FastInfo, {BackgroundColor3 = Theme.AccentDark, TextColor3 = Theme.Background})
        Tween(BtnB, FastInfo, {BackgroundColor3 = Theme.Sidebar, TextColor3 = Theme.TextSecondary})
        if callback then callback(optionA) end
    end)

    BtnB.MouseButton1Click:Connect(function()
        Tween(BtnB, FastInfo, {BackgroundColor3 = Theme.AccentDark, TextColor3 = Theme.Background})
        Tween(BtnA, FastInfo, {BackgroundColor3 = Theme.Sidebar, TextColor3 = Theme.TextSecondary})
        if callback then callback(optionB) end
    end)
end

-- UI Component: Color Swatch Palette Selector
local function CreateColorPalette(parentScroll, titleText, presets, callback)
    local Card = Instance.new("Frame")
    Card.Parent = parentScroll
    Card.BackgroundColor3 = Theme.CardBg
    Card.BackgroundTransparency = Config.UITransparency * 0.65
    Card.Size = UDim2.new(1, 0, 0, 68)
    table.insert(TransparentFrames.Cards, Card)

    local CardCorner = Instance.new("UICorner")
    CardCorner.CornerRadius = UDim.new(0, 8)
    CardCorner.Parent = Card

    local CardStroke = Instance.new("UIStroke")
    CardStroke.Color = Theme.CardStroke
    CardStroke.Thickness = 1
    CardStroke.Transparency = 0.4
    CardStroke.Parent = Card

    local Title = Instance.new("TextLabel")
    Title.Parent = Card
    Title.BackgroundTransparency = 1
    Title.Position = UDim2.new(0, 12, 0, 6)
    Title.Size = UDim2.new(0.65, 0, 0, 20)
    Title.Font = Typography.FontBold
    Title.Text = titleText
    Title.TextColor3 = Theme.TextPrimary
    Title.TextXAlignment = Enum.TextXAlignment.Left
    RegisterText(Title, Typography.ItemTitle)

    local SelectedLbl = Instance.new("TextLabel")
    SelectedLbl.Parent = Card
    SelectedLbl.BackgroundTransparency = 1
    SelectedLbl.Position = UDim2.new(0.65, 0, 0, 6)
    SelectedLbl.Size = UDim2.new(0.35, -12, 0, 20)
    SelectedLbl.Font = Typography.FontBold
    SelectedLbl.Text = presets[1].Name
    SelectedLbl.TextColor3 = presets[1].Color
    SelectedLbl.TextXAlignment = Enum.TextXAlignment.Right
    RegisterText(SelectedLbl, Typography.ControlText)

    local SwatchRow = Instance.new("Frame")
    SwatchRow.Parent = Card
    SwatchRow.BackgroundTransparency = 1
    SwatchRow.Position = UDim2.new(0, 12, 0, 32)
    SwatchRow.Size = UDim2.new(1, -24, 0, 26)

    local SwatchLayout = Instance.new("UIListLayout")
    SwatchLayout.Parent = SwatchRow
    SwatchLayout.FillDirection = Enum.FillDirection.Horizontal
    SwatchLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    SwatchLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    SwatchLayout.Padding = UDim.new(0, 6)

    local SwatchStrokes = {}

    for idx, preset in ipairs(presets) do
        local SwatchBtn = Instance.new("TextButton")
        SwatchBtn.Parent = SwatchRow
        SwatchBtn.BackgroundColor3 = preset.Color
        SwatchBtn.Size = UDim2.new(0, 22, 0, 22)
        SwatchBtn.AutoButtonColor = false
        SwatchBtn.Text = ""

        local SwatchCorner = Instance.new("UICorner")
        SwatchCorner.CornerRadius = UDim.new(1, 0)
        SwatchCorner.Parent = SwatchBtn

        local SwatchStroke = Instance.new("UIStroke")
        SwatchStroke.Color = Color3.fromRGB(255, 255, 255)
        SwatchStroke.Thickness = (idx == 1) and 2.2 or 0
        SwatchStroke.Parent = SwatchBtn
        table.insert(SwatchStrokes, SwatchStroke)

        SwatchBtn.MouseButton1Click:Connect(function()
            for _, st in ipairs(SwatchStrokes) do
                st.Thickness = 0
            end
            SwatchStroke.Thickness = 2.2
            SelectedLbl.Text = preset.Name
            SelectedLbl.TextColor3 = preset.Color
            if callback then
                callback(preset.Color)
            end
        end)
    end
end

-- UI Component: Action Button Card
local function CreateButton(parentScroll, titleText, btnLabel, callback)
    local Card = Instance.new("Frame")
    Card.Parent = parentScroll
    Card.BackgroundColor3 = Theme.CardBg
    Card.BackgroundTransparency = Config.UITransparency * 0.65
    Card.Size = UDim2.new(1, 0, 0, 48)
    table.insert(TransparentFrames.Cards, Card)

    local CardCorner = Instance.new("UICorner")
    CardCorner.CornerRadius = UDim.new(0, 8)
    CardCorner.Parent = Card

    local CardStroke = Instance.new("UIStroke")
    CardStroke.Color = Theme.CardStroke
    CardStroke.Thickness = 1
    CardStroke.Transparency = 0.4
    CardStroke.Parent = Card

    local Title = Instance.new("TextLabel")
    Title.Parent = Card
    Title.BackgroundTransparency = 1
    Title.Position = UDim2.new(0, 12, 0, 0)
    Title.Size = UDim2.new(0.56, 0, 1, 0)
    Title.Font = Typography.FontBold
    Title.Text = titleText
    Title.TextColor3 = Theme.TextPrimary
    Title.TextXAlignment = Enum.TextXAlignment.Left
    RegisterText(Title, Typography.ItemTitle)

    local ActBtn = Instance.new("TextButton")
    ActBtn.Parent = Card
    ActBtn.BackgroundColor3 = Theme.AccentDark
    ActBtn.Position = UDim2.new(0.58, 0, 0.5, -14)
    ActBtn.Size = UDim2.new(0.42, -12, 0, 28)
    ActBtn.AutoButtonColor = false
    ActBtn.Font = Typography.FontBold
    ActBtn.Text = btnLabel
    ActBtn.TextColor3 = Theme.Background
    RegisterText(ActBtn, Typography.ControlText)

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 6)
    BtnCorner.Parent = ActBtn

    ActBtn.MouseButton1Click:Connect(function()
        Tween(ActBtn, FastInfo, {BackgroundColor3 = Theme.AccentLight})
        task.delay(0.14, function()
            Tween(ActBtn, FastInfo, {BackgroundColor3 = Theme.AccentDark})
        end)
        if callback then callback(ActBtn) end
    end)
end

-- Forward Declarations for Tween & Fishing Systems
local tweenTo = function(_) end
local stopTween = function() end
local triggerHookset = function() end

-- Build All 5 Category Tabs for River Hunter
local TabFish = CreateCategoryTab("ออโต้ตกปลา", 1, "ระบบโยนเบ็ดและตวัดเบ็ด", "ระบบสู้ปลาและขายปลา")
local TabTween = CreateCategoryTab("ทวีนเดินทาง", 2, "จุดหมายในแผนที่ (Tween)", "แม่น้ำ บ้าน และยานพาหนะ")
local TabEsp = CreateCategoryTab("มองทะลุ & บอส", 3, "บอสแม่น้ำและฝูงปลา", "ปรับแต่ง ESP ผู้เล่น")
local TabMove = CreateCategoryTab("ตัวละคร & FPS", 4, "การเคลื่อนไหวและกระโดด", "รางวัลสมุดปลา & บูสต์ FPS")
local TabSetting = CreateCategoryTab("ตั้งค่าเมนู", 5, "ปรับแต่งธีมและกันแบน", "จัดการหน้าต่างและเครดิต")

-- ==========================================
-- TAB 1: ออโต้ตกปลา (AUTO FISH & SMART FIGHT)
-- ==========================================
CreateToggle(TabFish.Left, "เปิด/ปิด ออโต้ตกปลา (Auto Fish)", "โยนเบ็ด กรอสาย ตวัดเบ็ด สู้ปลา และดึงขึ้นฝั่งอัตโนมัติ", Config.AutoFish, function(state)
    Config.AutoFish = state
    ProfileStatus.Text = state and "สถานะ: กำลังออโต้ตกปลา" or "สถานะ: พร้อมตกปลา"
end)
CreateToggle(TabFish.Left, "กดตวัด & สู้ปลาอัตโนมัติ (PC & มือถือ)", "จำลองการแตะ/คลิกปุ่มตกปลาและส่งคำสั่งทันทีที่ปลาติดเบ็ด", Config.AutoHookTap, function(state)
    Config.AutoHookTap = state
end)
CreateSlider(TabFish.Left, "ดีเลย์ตวัดเบ็ด (วินาที)", 0.0, 1.5, Config.HooksetDelay, true, function(val)
    Config.HooksetDelay = val
end)
CreateSelector(TabFish.Left, "ระยะโยนเบ็ด (Cast Distance)", "ไกล (Far)", "กลาง (Medium)", function(opt)
    Config.CastDistance = opt
    Config.CastHold = (opt == "ไกล (Far)") and 0.55 or 0.36
end)
CreateSlider(TabFish.Left, "เวลาชาร์จโยนเบ็ด (วินาที)", 0.10, 1.00, Config.CastHold, true, function(val)
    Config.CastHold = val
end)
CreateToggle(TabFish.Left, "กรอสายขณะล่อปลา (Auto Reel)", "กรอสายเข้าช้าๆ เพื่อล่อปลามากินเหยื่อ", Config.AutoReelLure, function(state)
    Config.AutoReelLure = state
end)
CreateSlider(TabFish.Left, "ความเร็วกรอสายล่อปลา", 0.10, 1.00, Config.ReelSpeed, true, function(val)
    Config.ReelSpeed = val
end)
CreateToggle(TabFish.Left, "กระตุกเหยื่ออัตโนมัติ (Auto Jerk)", "กระตุกเหยื่อปลอมเป็นจังหวะระหว่างล่อปลา", Config.AutoJerk, function(state)
    Config.AutoJerk = state
end)
CreateSlider(TabFish.Left, "ดีเลย์กระตุกเหยื่อ (วินาที)", 0.3, 5.0, Config.JerkDelay, true, function(val)
    Config.JerkDelay = val
end)

CreateToggle(TabFish.Right, "กันสายขาดอัจฉริยะ (Smart Fight)", "หยุดดึงและผ่อนรอกทันทีเมื่อแรงตึงสายสูงหรือปลาคลั่ง", Config.SmartFight, function(state)
    Config.SmartFight = state
end)
CreateSlider(TabFish.Right, "เกณฑ์แรงตึงสายสูงสุด", 0.50, 0.95, Config.MaxTension, true, function(val)
    Config.MaxTension = val
end)
CreateToggle(TabFish.Right, "เอียงคันเบ็ดอัตโนมัติ (Auto Steer)", "เอียงคันเบ็ดซ้าย-ขวาตามทิศทางปลาและปลดตออัตโนมัติ", Config.AutoSteer, function(state)
    Config.AutoSteer = state
end)
CreateToggle(TabFish.Right, "ดึงสู้ปลารัวความเร็วสูง (Fast Tug)", "เร่งจังหวะดึงสู้ปลาเมื่อแรงตึงสายอยู่ในระดับปลอดภัย", Config.FastTug, function(state)
    Config.FastTug = state
end)
CreateToggle(TabFish.Right, "ดึงสู้โดยไม่กรอสายพร้อมกัน", "สลับกรอเฉพาะตอนสายหย่อน ลดแรงตึงป้องกันสายขาด", Config.NoReelTug, function(state)
    Config.NoReelTug = state
end)
CreateToggle(TabFish.Right, "ขายปลาอัตโนมัติ (Auto Sell)", "ส่งคำสั่งขายปลาทั้งหมดเมื่อจำนวนปลาในถังถึงเป้า", Config.AutoSell, function(state)
    Config.AutoSell = state
end)
CreateSlider(TabFish.Right, "จำนวนปลาในถังก่อนขาย", 1, 30, Config.SellThreshold, false, function(val)
    Config.SellThreshold = val
end)
CreateButton(TabFish.Right, "ขายปลาในถังทั้งหมด", "ขายปลาทันที", function(btn)
    if InputRemote then
        InputRemote:FireServer("sell", {all = true})
        btn.Text = "ขายสำเร็จ!"
        task.wait(1.2)
        btn.Text = "ขายปลาทันที"
    end
end)

-- ==========================================
-- TAB 2: ทวีนเดินทาง (TWEEN & VEHICLES)
-- ==========================================
local TweenLocations = {
    Market = Vector3.new(-31.6, 7.4, 197.8),
    Pier = Vector3.new(-8.6, 4.5, 73.1),
    Noodle = Vector3.new(29.6, 3.5, 180.0),
    Coffee = Vector3.new(-366.7, 18.4, -161.0),
    Reservoir = Vector3.new(0, 10, -450),
    Dam = Vector3.new(0, 16, -160),
    MainRiver = Vector3.new(0, 5, 800),
    Downstream = Vector3.new(0, 5, 1200)
}

CreateSlider(TabTween.Left, "ความเร็วการทวีน (Studs/วิ)", 20, 150, Config.TweenSpeed, false, function(val)
    Config.TweenSpeed = val
end)
CreateButton(TabTween.Left, "ตลาดปลา (Fish Market)", "ทวีนไป", function()
    tweenTo(CFrame.new(TweenLocations.Market))
end)
CreateButton(TabTween.Left, "ท่าเรือแพตกปลา (Bait Pier)", "ทวีนไป", function()
    tweenTo(CFrame.new(TweenLocations.Pier))
end)
CreateButton(TabTween.Left, "ร้านก๋วยเตี๋ยวริมน้ำ", "ทวีนไป", function()
    tweenTo(CFrame.new(TweenLocations.Noodle))
end)
CreateButton(TabTween.Left, "ร้านกาแฟริมทาง (Coffee Shop)", "ทวีนไป", function()
    tweenTo(CFrame.new(TweenLocations.Coffee))
end)
CreateButton(TabTween.Left, "อ่างเก็บน้ำ (Reservoir)", "ทวีนไป", function()
    tweenTo(CFrame.new(TweenLocations.Reservoir))
end)
CreateButton(TabTween.Left, "สันเขื่อน (Dam Crest)", "ทวีนไป", function()
    tweenTo(CFrame.new(TweenLocations.Dam))
end)

CreateButton(TabTween.Right, "แม่น้ำสายหลัก (Main River)", "ทวีนไป", function()
    tweenTo(CFrame.new(TweenLocations.MainRiver))
end)
CreateButton(TabTween.Right, "แม่น้ำตอนล่าง (Downstream)", "ทวีนไป", function()
    tweenTo(CFrame.new(TweenLocations.Downstream))
end)
CreateButton(TabTween.Right, "บ้านของฉัน (My Plot)", "ทวีนกลับบ้าน", function()
    local plotNum = LocalPlayer:GetAttribute("Plot")
    local town = Workspace:FindFirstChild("Town")
    local plots = town and town:FindFirstChild("Plots")
    local plot = plots and plots:FindFirstChild("Plot" .. tostring(plotNum))
    if plot then
        tweenTo(plot:GetPivot() + Vector3.new(0, 3, 0))
    end
end)
CreateButton(TabTween.Right, "ยกเลิกการทวีนกลางทาง", "หยุดทวีน", function()
    stopTween()
end)
CreateButton(TabTween.Right, "เรียกเรือหางยาว (Longtail)", "เสกเรือ", function()
    if GarageRemote then
        GarageRemote:FireServer("boat", "longtail")
    end
end)
CreateButton(TabTween.Right, "เก็บเรือเข้าโรงเก็บ", "เก็บเรือ", function()
    if GarageRemote then
        GarageRemote:FireServer("boatAway")
    end
end)
CreateButton(TabTween.Right, "เรียกช้างมารับ (Elephant)", "เรียกช้าง", function()
    if GarageRemote then
        GarageRemote:FireServer("elephantCome")
    end
end)

-- ==========================================
-- TAB 3: มองทะลุ & บอส (ESP & BOSS ALERTS)
-- ==========================================
CreateToggle(TabEsp.Left, "แจ้งเตือนบอสแม่น้ำเกิด", "แสดงแถบแจ้งเตือนเมื่อบอสเกิดหรือเข้าใกล้รัศมี", Config.BossAlert, function(state)
    Config.BossAlert = state
end)
CreateToggle(TabEsp.Left, "เปิดเรดาร์ตรวจคุณภาพน้ำ", "เปิดระบบเรดาร์ค้นหาฝูงปลาในน้ำ", Config.RadarMode, function(state)
    Config.RadarMode = state
    if InputRemote then
        InputRemote:FireServer("radarSwap", state)
    end
end)
CreateToggle(TabEsp.Left, "ไฮไลท์ฝูงปลา (Fish Schools)", "เรืองแสงตำแหน่งฝูงปลาและจุดปลาชุกชุมในแม่น้ำ", Config.FishSchoolESP, function(state)
    Config.FishSchoolESP = state
end)
CreateToggle(TabEsp.Left, "มองทะลุผู้เล่น (Player ESP)", "แสดงกรอบ ไฮไลท์ ชื่อ และระยะห่างผู้เล่นทุกคน", Config.ESPMaster, function(state)
    Config.ESPMaster = state
end)

CreateColorPalette(TabEsp.Right, "เลือกสี ESP และไฮไลท์", ESPColorPresets, function(selectedColor)
    Config.ESPColor = selectedColor
end)
CreateToggle(TabEsp.Right, "โหมดสีรุ้ง (Rainbow ESP)", "ไล่เฉดสี RGB อัตโนมัติทั้งกรอบและไฮไลท์", Config.ESPRainbow, function(state)
    Config.ESPRainbow = state
end)
CreateToggle(TabEsp.Right, "แสดงชื่อและระยะห่าง (เมตร)", "แสดงชื่อผู้เล่นและระยะห่างเหนือศีรษะ", Config.ESPNameDist, function(state)
    Config.ESPNameDist = state
end)
CreateSlider(TabEsp.Right, "ระยะมองทะลุสูงสุด (เมตร)", 100, 3000, Config.ESPMaxDist, false, function(val)
    Config.ESPMaxDist = val
end)

-- ==========================================
-- TAB 4: ตัวละคร & FPS (MOVEMENT & PERFORMANCE)
-- ==========================================
CreateToggle(TabMove.Left, "วิ่งไวพิเศษ (Speed Boost)", "เพิ่มความเร็วการเดินและวิ่งของตัวละคร", Config.SpeedBoost, function(state)
    Config.SpeedBoost = state
    if not state then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end
end)
CreateSlider(TabMove.Left, "ระดับความเร็ววิ่ง", 16, 150, Config.WalkSpeed, false, function(val)
    Config.WalkSpeed = val
end)
CreateToggle(TabMove.Left, "กระโดดสูงพิเศษ (High Jump)", "เพิ่มแรงกระโดดของตัวละคร", Config.HighJump, function(state)
    Config.HighJump = state
    if not state then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = 50 end
    end
end)
CreateSlider(TabMove.Left, "ระดับความสูงกระโดด", 50, 220, Config.JumpPower, false, function(val)
    Config.JumpPower = val
end)
CreateToggle(TabMove.Left, "กระโดดไม่จำกัด (Inf Jump)", "กระโดดกลางอากาศได้ต่อเนื่องทั้งมือถือและคอม", Config.InfiniteJump, function(state)
    Config.InfiniteJump = state
end)
CreateToggle(TabMove.Left, "เดินทะลุกำแพง (Noclip)", "เดินทะลุสิ่งกีดขวาง ต้นไม้ และรั้วได้ทั้งหมด", Config.Noclip, function(state)
    Config.Noclip = state
end)
CreateToggle(TabMove.Left, "โหมดบินอิสระ (Fly Mode)", "บินสำรวจตามทิศทางกล้องได้ทั้งมือถือและคอม", Config.FlyMode, function(state)
    Config.FlyMode = state
end)
CreateSlider(TabMove.Left, "ความเร็วการบิน", 15, 150, Config.FlySpeed, false, function(val)
    Config.FlySpeed = val
end)

CreateButton(TabMove.Right, "รับรางวัลสมุดปลาทั้งหมด", "กดรับทั้งหมด", function(btn)
    if InputRemote then
        local fishList = {"chado", "barb", "catfish", "channa", "kasong", "plajad", "redtilapia", "tilapia", "featherback", "pacu", "peacockbass", "carp", "gourami"}
        for _, f in ipairs(fishList) do
            InputRemote:FireServer("bookClaim", f)
            task.wait(0.04)
        end
        btn.Text = "รับสำเร็จ!"
        task.wait(1.3)
        btn.Text = "กดรับทั้งหมด"
    end
end)
CreateToggle(TabMove.Right, "ลดเอฟเฟกต์ (ลดแลค)", "ปิดอนุภาค ควัน และเอฟเฟกต์ฟุ้งกระจายในแมพ", Config.ReduceEffects, function(state)
    Config.ReduceEffects = state
    if state then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                obj.Enabled = false
            end
        end
    end
end)
CreateToggle(TabMove.Right, "ลดกราฟิกพื้นผิว (Low Graphics)", "ปรับวัสดุแมพให้เรียบเนียนและปิดเงาเพิ่มความลื่น", Config.LowGraphics, function(state)
    Config.LowGraphics = state
    if state then
        Lighting.GlobalShadows = false
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not (LocalPlayer.Character and obj:IsDescendantOf(LocalPlayer.Character)) then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            end
        end
    else
        Lighting.GlobalShadows = true
    end
end)
CreateToggle(TabMove.Right, "บูสต์ FPS สูงสุด (FPS Boost)", "ปิดหมอกและเอฟเฟกต์แสงโพสต์เพื่อเพิ่มเฟรมเรตสูงสุด", Config.FPSBoost, function(state)
    Config.FPSBoost = state
    if state then
        Lighting.FogEnd = 9e9
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") and effect.Name ~= "ProScriptBlur" then
                effect.Enabled = false
            end
        end
    end
end)

-- ==========================================
-- TAB 5: ตั้งค่าเมนู (SETTINGS & PROTECTION)
-- ==========================================
CreateSlider(TabSetting.Left, "ขนาดตัวอักษร (%)", 90, 125, Config.UIFontScale, false, function(val)
    ApplyFontScale(val)
end)
CreateSlider(TabSetting.Left, "ความโปร่งใสพื้นหลัง (%)", 0, 80, 4, false, function(val)
    ApplyTransparency(val / 100)
end)
CreateToggle(TabSetting.Left, "เบลอฉากหลังขณะเปิดเมนู", "เปิดเอฟเฟกต์เบลอภาพพื้นหลังเพื่อความสมูทสบายตา", Config.UIBlur, function(state)
    Config.UIBlur = state
    BlurEffect.Enabled = state and isWindowOpen and not isMinimized
    if BlurEffect.Enabled then
        Tween(BlurEffect, SmoothInfo, {Size = 12})
    end
end)
CreateToggle(TabSetting.Left, "โหมดธีมสีซอฟต์สบายตา", "ปรับสีพื้นหลังเมนูให้สว่างและนุ่มนวลขึ้น", Config.LightSoftTheme, function(state)
    Config.LightSoftTheme = state
    if state then
        Theme.Background = Color3.fromRGB(22, 32, 26)
        Theme.Sidebar = Color3.fromRGB(27, 40, 33)
        Theme.ColumnBg = Color3.fromRGB(31, 46, 37)
        Theme.CardBg = Color3.fromRGB(38, 56, 46)
    else
        Theme.Background = Color3.fromRGB(13, 18, 15)
        Theme.Sidebar = Color3.fromRGB(17, 24, 20)
        Theme.ColumnBg = Color3.fromRGB(20, 29, 24)
        Theme.CardBg = Color3.fromRGB(26, 38, 31)
    end
    Tween(MainFrame, SmoothInfo, {BackgroundColor3 = Theme.Background})
    Tween(OpenButton, SmoothInfo, {BackgroundColor3 = Theme.Background})
    for _, f in ipairs(TransparentFrames.Sub) do
        Tween(f, SmoothInfo, {BackgroundColor3 = Theme.Sidebar})
    end
    for _, c in ipairs(TransparentFrames.Cards) do
        if c ~= AllTabs[1].Button then
            Tween(c, SmoothInfo, {BackgroundColor3 = Theme.CardBg})
        end
    end
end)
CreateToggle(TabSetting.Left, "กันแบนและกันโหวตเตะ (Anti-Ban)", "บล็อกคำสั่ง VoteKick, AdminPoll และ Kick อัตโนมัติ", Config.AntiBan, function(state)
    Config.AntiBan = state
end)
CreateToggle(TabSetting.Left, "ป้องกันหลุดเมื่ออยู่นิ่ง (Anti-AFK)", "ขยับสถานะจำลองอัตโนมัติไม่ให้โดนเตะออกจากเซิร์ฟ", Config.AntiAFK, function(state)
    Config.AntiAFK = state
end)

CreateButton(TabSetting.Right, "ช่องยูทูป: ช่องนี้เรื่องโปร", "เรื่องโปร Hub", function() end)
CreateButton(TabSetting.Right, "ดิสคอร์ดกลุ่มพูดคุย", "คัดลอกลิงก์", function(btn)
    pcall(function()
        if _setclipboard then
            _setclipboard("https://discord.gg/gZpkSgmR8")
            btn.Text = "คัดลอกแล้ว!"
            task.wait(1.5)
            btn.Text = "คัดลอกลิงก์"
        end
    end)
end)
CreateButton(TabSetting.Right, "รีเซ็ตตำแหน่งปุ่มเปิด/ปิด", "ซ้ายบนกลางๆ", function()
    Tween(OpenButton, SmoothInfo, {Position = DefaultOpenBtnPos})
end)
CreateButton(TabSetting.Right, "คืนค่าขนาดหน้าต่าง", "ขนาดมาตรฐาน", function()
    Tween(MainFrame, SmoothInfo, {Size = UDim2.new(0, DefaultW, 0, DefaultH)})
    savedSize = UDim2.new(0, DefaultW, 0, DefaultH)
end)
CreateButton(TabSetting.Right, "ปิดสคริปต์ถาวร", "ลบเมนู", function()
    Config.AutoFish = false
    stopTween()
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Connections)
    if BlurEffect then BlurEffect:Destroy() end
    ScreenGui:Destroy()
end)

-- Activate First Tab by Default
AllTabs[1].Page.Visible = true
AllTabs[1].Button.BackgroundColor3 = Theme.AccentDark
AllTabs[1].Label.TextColor3 = Theme.Background
AllTabs[1].Pill.BackgroundColor3 = Theme.Background
AllTabs[1].Pill.Size = UDim2.new(0, 4, 0, 22)

-- Resize Handle Interaction
local isResizing = false
local resizeInput = nil
local resizeStart = nil
local initialSize = nil

TrackConn(ResizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = true
        resizeStart = input.Position
        initialSize = MainFrame.Size

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                isResizing = false
            end
        end)
    end
end))

TrackConn(ResizeHandle.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        resizeInput = input
    end
end))

TrackConn(UserInputService.InputChanged:Connect(function(input)
    if input == resizeInput and isResizing and not isMinimized then
        local delta = input.Position - resizeStart
        local scaleDiv = MainScale.Scale > 0 and MainScale.Scale or 1
        local newW = math.clamp(initialSize.X.Offset + (delta.X / scaleDiv), MinW, MaxW)
        local newH = math.clamp(initialSize.Y.Offset + (delta.Y / scaleDiv), MinH, MaxH)
        MainFrame.Size = UDim2.new(0, newW, 0, newH)
        savedSize = MainFrame.Size
    end
end))

-- ==============================================================================
-- ANTI-BAN & ANTI-VOTEKICK PROTECTION
-- ==============================================================================
pcall(function()
    if _hookmetamethod and _getnamecallmethod then
        local oldNamecall
        oldNamecall = _hookmetamethod(game, "__namecall", _newcclosure(function(self, ...)
            if Config.AntiBan and not _checkcaller() then
                local method = _getnamecallmethod()
                if (method == "Kick" or method == "Ban") and self == LocalPlayer then
                    return nil
                end
                if (method == "FireServer" or method == "InvokeServer") and typeof(self) == "Instance" then
                    if self.Name == "VoteKick" or self.Name == "AdminPoll" then
                        return nil
                    end
                end
            end
            return oldNamecall(self, ...)
        end))
    end
end)

TrackConn(LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end))

-- ==============================================================================
-- CROSS-PLATFORM INPUT & FISHING UI TAP/CLICK ENGINE (PC & MOBILE FIX)
-- Fixes the issue where fish bites ("strike") or fights are not clicked on PC/Mobile
-- ==============================================================================
local function GetFishingButtons()
    local buttons = {}
    local fGui = PlayerGui:FindFirstChild("FishingUI")
    if fGui then
        local reel = fGui:FindFirstChild("Reel")
        local mainBtn = reel and reel:FindFirstChild("Main")
        if mainBtn and mainBtn:IsA("GuiButton") then
            table.insert(buttons, mainBtn)
        end
        for _, desc in ipairs(fGui:GetDescendants()) do
            if desc:IsA("GuiButton") and desc.Visible and desc ~= mainBtn then
                local n = string.lower(desc.Name)
                if string.find(n, "main") or string.find(n, "strike") or string.find(n, "hook") or string.find(n, "pull") or string.find(n, "tap") or string.find(n, "cast") or string.find(n, "reel") then
                    table.insert(buttons, desc)
                end
            end
        end
    end
    return buttons
end

local function SimulateTapOrClick(holdDuration)
    local hold = holdDuration or 0.02
    local btns = GetFishingButtons()
    local primaryBtn = btns[1]

    -- Layer 1: Fire GuiButton signals directly (Works on Delta, Arceus X, Codex, Fluxus, Synapse, Wave)
    if _firesignal and #btns > 0 then
        for _, b in ipairs(btns) do
            pcall(function() _firesignal(b.MouseButton1Down) end)
            pcall(function() _firesignal(b.InputBegan, {UserInputType = Enum.UserInputType.Touch}) end)
        end
    end

    -- Calculate exact screen position accounting for GuiInset (fixes mobile & topbar offset)
    local clickX, clickY
    if primaryBtn and primaryBtn.AbsoluteSize.X > 0 then
        local inset = Vector2.zero
        pcall(function() inset = GuiService:GetGuiInset() end)
        clickX = primaryBtn.AbsolutePosition.X + (primaryBtn.AbsoluteSize.X * 0.5) + inset.X
        clickY = primaryBtn.AbsolutePosition.Y + (primaryBtn.AbsoluteSize.Y * 0.5) + inset.Y
    else
        local vp = Camera and Camera.ViewportSize or Vector2.new(1280, 720)
        clickX = vp.X * 0.5
        clickY = vp.Y * 0.72
    end

    -- Layer 2: VirtualInputManager Mouse & Touch simulation (pcall-safe for Mobile)
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, true, game, 0)
        end)
        pcall(function()
            VirtualInputManager:SendTouchEvent(1, 0, clickX, clickY)
        end)
    end

    -- Layer 3: VirtualUser fallback
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:Button1Down(Vector2.new(clickX, clickY))
    end)

    if hold > 0 then
        task.wait(hold)
    end

    -- Release all inputs cleanly
    if _firesignal and #btns > 0 then
        for _, b in ipairs(btns) do
            pcall(function() _firesignal(b.MouseButton1Up) end)
            pcall(function() _firesignal(b.MouseButton1Click) end)
            pcall(function() _firesignal(b.Activated) end)
        end
    end

    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, false, game, 0)
        end)
        pcall(function()
            VirtualInputManager:SendTouchEvent(1, 2, clickX, clickY)
        end)
    end

    pcall(function()
        VirtualUser:Button1Up(Vector2.new(clickX, clickY))
    end)
end

local function PressKeySafe(keyCode)
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
        end)
    end
end

-- ==============================================================================
-- REAL-TIME FISHING & FIGHT STATE MONITORING
-- ==============================================================================
local fightState = {
    phase = "idle",
    tension = 0,
    fishStamina = 1,
    playerStamina = 1,
    isBurst = false,
    isSurge = false,
    isSnagged = false,
    gaveUp = false,
    lateralDir = 0,
    snagDir = 0,
    lastTick = 0
}

if TickRemote then
    TrackConn(TickRemote.OnClientEvent:Connect(function(data)
        if typeof(data) == "table" then
            if data.ph then fightState.phase = data.ph end
            if typeof(data.te) == "number" then fightState.tension = data.te end
            if typeof(data.fs) == "number" then fightState.fishStamina = data.fs end
            if typeof(data.ps) == "number" then fightState.playerStamina = data.ps end
            if data.bu ~= nil then fightState.isBurst = (data.bu == true) end
            if data.sw ~= nil then fightState.isSurge = (data.sw == true) end
            if data.sn ~= nil then fightState.isSnagged = (data.sn == true) end
            if data.gu ~= nil then fightState.gaveUp = (data.gu == true) end
            if typeof(data.ld) == "number" then fightState.lateralDir = data.ld end
            if typeof(data.sd) == "number" then fightState.snagDir = data.sd end
            fightState.lastTick = os.clock()

            if (data.ph == "strike" or data.ph == "bite") and Config.AutoFish then
                triggerHookset()
            end
        end
    end))
end

-- ==============================================================================
-- GUARANTEED HOOKSET (WHEN FISH BITES) & CASTING & STEERING
-- ==============================================================================
local lastHooksetTime = 0
local isHooksetting = false

triggerHookset = function()
    local now = os.clock()
    if isHooksetting or (now - lastHooksetTime < 0.22) then return end
    isHooksetting = true
    lastHooksetTime = now

    task.spawn(function()
        local delayVal = Config.HooksetDelay or 0
        if delayVal > 0 then
            task.wait(delayVal)
        end

        -- 1. Fire server remotes for hookset / strike
        if InputRemote then
            pcall(function() InputRemote:FireServer("hookset") end)
            pcall(function() InputRemote:FireServer("strike") end)
        end

        -- 2. Click/Tap the FishingUI button & screen (fixes mobile & PC non-click bug)
        if Config.AutoHookTap then
            SimulateTapOrClick(0.04)
            PressKeySafe(Enum.KeyCode.E)
        end

        task.wait(0.12)
        isHooksetting = false
    end)
end

if StateRemote then
    TrackConn(StateRemote.OnClientEvent:Connect(function(a1, a2)
        if (a1 == "strike" or a1 == "bite") and Config.AutoFish then
            triggerHookset()
        end
        if Config.BossAlert then
            if a1 == "announce" and typeof(a2) == "table" and a2.k == "announce.outBoss" then
                local p = a2.p
                local bossName = p and tostring(p.boss) or "บอส"
                local zoneName = p and tostring(p.zone) or "แม่น้ำ"
                ProfileStatus.Text = "พบ " .. bossName .. " @ " .. zoneName
            elseif a1 == "bossTrack" and typeof(a2) == "table" and a2.id then
                ProfileStatus.Text = "พบบอส: " .. tostring(a2.id)
            end
        end
    end))
end

TrackConn(LocalPlayer:GetAttributeChangedSignal("FishPhase"):Connect(function()
    local phase = LocalPlayer:GetAttribute("FishPhase")
    if (phase == "strike" or phase == "bite") and Config.AutoFish then
        triggerHookset()
    end
end))

local function performCast()
    local holdTime = math.clamp(tonumber(Config.CastHold) or 0.55, 0.08, 1.5)
    SimulateTapOrClick(holdTime)
end

local currentSteer = 0
local function updateSteer(targetSteer)
    if currentSteer == targetSteer then return end
    currentSteer = targetSteer

    if InputRemote then
        pcall(function() InputRemote:FireServer("steer", targetSteer) end)
    end

    if VirtualInputManager then
        pcall(function()
            if targetSteer > 0 then
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.A, false, game)
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.D, false, game)
            elseif targetSteer < 0 then
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.D, false, game)
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.A, false, game)
            else
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.A, false, game)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.D, false, game)
            end
        end)
    end
end

-- ==============================================================================
-- AUTO FISH & FIGHT BACKGROUND LOOP (PC & MOBILE)
-- ==============================================================================
local lastFightTapTime = 0

local function fightInput(pullRate, exhausted)
    if InputRemote then
        if not Config.NoReelTug or exhausted then
            pcall(function()
                InputRemote:FireServer("pull", pullRate)
                InputRemote:FireServer("reel", 1)
            end)
        else
            local slack = fightState.tension <= Config.ReelBelowTension
                and not fightState.isBurst and not fightState.isSurge and not fightState.isSnagged
            if slack then
                pcall(function() InputRemote:FireServer("reel", 1) end)
            else
                pcall(function()
                    InputRemote:FireServer("pull", pullRate)
                    InputRemote:FireServer("reel", 0)
                end)
            end
        end
    end

    -- Also tap/click FishingUI button during fight phase for Mobile & PC compatibility
    if Config.AutoHookTap then
        local now = os.clock()
        local tapInterval = Config.FastTug and 0.08 or 0.14
        if now - lastFightTapTime >= tapInterval then
            lastFightTapTime = now
            task.spawn(function()
                SimulateTapOrClick(0.015)
            end)
        end
    end
end

local lastJerkTime = 0
local lastCastTime = 0

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(0.05)

        if not Config.AutoFish then
            if currentSteer ~= 0 then
                updateSteer(0)
            end
            continue
        end

        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp or hum.Health <= 0 then continue end

        -- Auto-Equip Fishing Rod ("คันเบ็ด")
        local rodInHand = char:FindFirstChild("คันเบ็ด") or char:FindFirstChildOfClass("Tool")
        if not rodInHand then
            local rodInBag = LocalPlayer.Backpack:FindFirstChild("คันเบ็ด")
            if not rodInBag then
                for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
                    if item:IsA("Tool") and (string.find(item.Name, "เบ็ด") or string.find(string.lower(item.Name), "rod")) then
                        rodInBag = item
                        break
                    end
                end
            end
            if rodInBag then
                pcall(function() hum:EquipTool(rodInBag) end)
                task.wait(0.35)
            end
        end

        local phase = LocalPlayer:GetAttribute("FishPhase") or fightState.phase or "idle"
        local now = os.clock()

        -- Auto Sell when idle and bucket reaches threshold
        if Config.AutoSell and phase == "idle" then
            local bucketN = tonumber(LocalPlayer:GetAttribute("BucketN")) or 0
            if bucketN >= Config.SellThreshold and InputRemote then
                pcall(function() InputRemote:FireServer("sell", {all = true}) end)
                task.wait(0.8)
            end
        end

        if phase == "idle" then
            if currentSteer ~= 0 then updateSteer(0) end
            if now - lastCastTime > 1.25 then
                lastCastTime = now
                performCast()
            end

        elseif phase == "flight" or phase == "pending" then
            lastJerkTime = now
            if currentSteer ~= 0 then updateSteer(0) end

        elseif phase == "lure" then
            if currentSteer ~= 0 then updateSteer(0) end

            if Config.AutoJerk and (now - lastJerkTime >= Config.JerkDelay) then
                lastJerkTime = now
                if InputRemote then
                    pcall(function() InputRemote:FireServer("jerk") end)
                end
                PressKeySafe(Enum.KeyCode.E)
            end

            if InputRemote then
                local rVal = Config.AutoReelLure and Config.ReelSpeed or 0
                pcall(function() InputRemote:FireServer("reel", rVal) end)
            end

        elseif phase == "strike" or phase == "bite" then
            triggerHookset()

        elseif phase == "fight" then
            if Config.AutoSteer then
                if fightState.isSnagged then
                    if fightState.snagDir < 0 then
                        updateSteer(-1)
                    elseif fightState.snagDir > 0 then
                        updateSteer(1)
                    end
                elseif fightState.gaveUp then
                    updateSteer(0)
                else
                    local ld = fightState.lateralDir
                    if ld < -0.06 then
                        updateSteer(1)
                    elseif ld > 0.06 then
                        updateSteer(-1)
                    else
                        updateSteer(0)
                    end
                end
            end

            if Config.SmartFight then
                local isDanger = (fightState.tension >= Config.MaxTension) or fightState.isBurst or fightState.isSurge or fightState.isSnagged
                local isExhausted = fightState.gaveUp or (fightState.fishStamina <= 0.2 and not fightState.isBurst)

                if isDanger and not isExhausted then
                    if InputRemote then
                        pcall(function() InputRemote:FireServer("reel", 0) end)
                    end
                    task.wait(0.04)
                else
                    local pullRate = Config.FastTug and 0.07 or 0.12
                    fightInput(pullRate, isExhausted)
                end
            else
                local pullRate = Config.FastTug and 0.07 or 0.12
                fightInput(pullRate, false)
            end

        elseif phase == "landing" then
            if currentSteer ~= 0 then updateSteer(0) end
            if InputRemote then
                pcall(function()
                    InputRemote:FireServer("land")
                    InputRemote:FireServer("reel", 0)
                end)
            end
        end
    end
end)

-- ==============================================================================
-- SMOOTH NOCLIP TWEEN TRAVEL SYSTEM
-- ==============================================================================
local currentTween = nil
local isTweening = false
local currentBV = nil
local tweenNoclipConn = nil

stopTween = function()
    if currentTween then
        pcall(function() currentTween:Cancel() end)
        currentTween = nil
    end
    isTweening = false
    if currentBV and currentBV.Parent then
        currentBV:Destroy()
        currentBV = nil
    end
    if tweenNoclipConn then
        tweenNoclipConn:Disconnect()
        tweenNoclipConn = nil
    end
    local char = LocalPlayer.Character
    if char and not Config.Noclip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

tweenTo = function(targetCFrame)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    stopTween()

    local speed = Config.TweenSpeed or 65
    local distance = (targetCFrame.Position - hrp.Position).Magnitude
    local duration = math.max(0.2, distance / speed)

    currentBV = Instance.new("BodyVelocity")
    currentBV.Velocity = Vector3.zero
    currentBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    currentBV.Parent = hrp

    isTweening = true

    tweenNoclipConn = RunService.Stepped:Connect(function()
        if not isTweening or not char then
            if tweenNoclipConn then tweenNoclipConn:Disconnect() tweenNoclipConn = nil end
            return
        end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    currentTween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    currentTween.Completed:Connect(function()
        stopTween()
    end)
    currentTween:Play()
end

-- ==============================================================================
-- MOVEMENT, INFINITE JUMP & UNIVERSAL ESP RENDERER
-- ==============================================================================
TrackConn(UserInputService.JumpRequest:Connect(function()
    if Config.InfiniteJump then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end))

local ESPContainer = Instance.new("Frame")
ESPContainer.Name = "ProScriptESPContainer"
ESPContainer.Parent = ScreenGui
ESPContainer.BackgroundTransparency = 1
ESPContainer.Size = UDim2.new(1, 0, 1, 0)
ESPContainer.ZIndex = 1

local PlayerESPCache = {}

local function CreatePlayerESPUI(plr)
    local holder = Instance.new("Frame")
    holder.Name = plr.Name .. "_ESP"
    holder.Parent = ESPContainer
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(1, 0, 1, 0)
    holder.Visible = false

    local box = Instance.new("Frame")
    box.Name = "Box"
    box.Parent = holder
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = Config.ESPColor
    boxStroke.Thickness = 1.6
    boxStroke.Parent = box

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "NameDist"
    nameLbl.Parent = box
    nameLbl.BackgroundTransparency = 1
    nameLbl.Position = UDim2.new(0.5, -110, 0, -19)
    nameLbl.Size = UDim2.new(0, 220, 0, 16)
    nameLbl.Font = Typography.FontBold
    nameLbl.TextColor3 = Theme.TextPrimary
    nameLbl.TextStrokeTransparency = 0.15
    nameLbl.TextSize = 12

    PlayerESPCache[plr] = {
        Holder = holder,
        Box = box,
        BoxStroke = boxStroke,
        NameLbl = nameLbl
    }
end

TrackConn(Players.PlayerRemoving:Connect(function(plr)
    if PlayerESPCache[plr] then
        if PlayerESPCache[plr].Holder then PlayerESPCache[plr].Holder:Destroy() end
        PlayerESPCache[plr] = nil
    end
end))

local function GetActiveESPColor()
    if Config.ESPRainbow then
        return Color3.fromHSV((tick() * 0.28) % 1, 0.85, 1)
    end
    return Config.ESPColor
end

local FlyBV, FlyBG = nil, nil

TrackConn(RunService.RenderStepped:Connect(function()
    if not ScreenGui.Parent then return end
    Camera = Workspace.CurrentCamera
    if not Camera then return end

    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

    if myChar and myHum and myHrp then
        if Config.Noclip then
            for _, part in ipairs(myChar:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end

        if Config.SpeedBoost and not myHum.SeatPart then
            myHum.WalkSpeed = Config.WalkSpeed
        end

        if Config.HighJump then
            myHum.UseJumpPower = true
            myHum.JumpPower = Config.JumpPower
        end

        if Config.FlyMode then
            if not FlyBV or FlyBV.Parent ~= myHrp then
                FlyBV = Instance.new("BodyVelocity")
                FlyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                FlyBV.Velocity = Vector3.zero
                FlyBV.Parent = myHrp
            end
            if not FlyBG or FlyBG.Parent ~= myHrp then
                FlyBG = Instance.new("BodyGyro")
                FlyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                FlyBG.P = 9e4
                FlyBG.Parent = myHrp
            end
            myHum.PlatformStand = true
            FlyBG.CFrame = Camera.CFrame

            local moveDir = myHum.MoveDirection
            if moveDir.Magnitude > 0 then
                FlyBV.Velocity = (Camera.CFrame.LookVector * (moveDir:Dot(Camera.CFrame.LookVector) >= 0 and 1 or -1) + moveDir).Unit * Config.FlySpeed
            else
                FlyBV.Velocity = Vector3.zero
            end
        else
            if FlyBV then FlyBV:Destroy() FlyBV = nil end
            if FlyBG then FlyBG:Destroy() FlyBG = nil end
            if myHum.PlatformStand then
                myHum.PlatformStand = false
            end
        end
    end

    -- Render Player 2D ESP
    local activeColor = GetActiveESPColor()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if not PlayerESPCache[plr] then
                CreatePlayerESPUI(plr)
            end
            local ui = PlayerESPCache[plr]
            local char = plr.Character
            local rootPart = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if Config.ESPMaster and rootPart and (not hum or hum.Health > 0) then
                local dist = myHrp and (rootPart.Position - myHrp.Position).Magnitude or (rootPart.Position - Camera.CFrame.Position).Magnitude
                local meters = math.floor(dist * 0.28)
                local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)

                if onScreen and screenPos.Z > 0.5 and meters <= Config.ESPMaxDist then
                    ui.Holder.Visible = true
                    local scaleFactor = 1 / (screenPos.Z * math.tan(math.rad(Camera.FieldOfView * 0.5)) * 2) * 1000
                    local boxH = math.clamp(scaleFactor * 4.8, 18, 360)
                    local boxW = math.clamp(boxH * 0.62, 12, 240)

                    ui.Box.Position = UDim2.new(0, screenPos.X - boxW / 2, 0, screenPos.Y - boxH / 2)
                    ui.Box.Size = UDim2.new(0, boxW, 0, boxH)
                    ui.BoxStroke.Color = activeColor

                    ui.NameLbl.Visible = Config.ESPNameDist
                    ui.NameLbl.TextColor3 = activeColor
                    ui.NameLbl.Text = string.format("%s (%d ม.)", plr.DisplayName or plr.Name, meters)
                else
                    ui.Holder.Visible = false
                end
            else
                ui.Holder.Visible = false
            end
        end
    end
end))

-- Periodic Highlight Scanner for Players & Fish Schools
local function SetHighlight(targetModel, color, enabled)
    if not targetModel or not targetModel.Parent then return end
    local hl = targetModel:FindFirstChild("ProScriptHL")
    if enabled then
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = "ProScriptHL"
            hl.FillTransparency = 0.6
            hl.OutlineTransparency = 0.1
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = targetModel
        end
        hl.FillColor = color
        hl.OutlineColor = color
        hl.Enabled = true
    else
        if hl then hl:Destroy() end
    end
end

task.spawn(function()
    while ScreenGui.Parent do
        local col = GetActiveESPColor()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                SetHighlight(plr.Character, col, Config.ESPMaster)
            end
        end

        local fishSchools = Workspace:FindFirstChild("WaterStyleFX") or Workspace:FindFirstChild("FishingFX")
        if fishSchools then
            for _, child in ipairs(fishSchools:GetChildren()) do
                if child:IsA("Model") or child:IsA("BasePart") then
                    SetHighlight(child, Color3.fromRGB(55, 215, 255), Config.FishSchoolESP)
                end
            end
        end

        task.wait(0.45)
    end
end)
