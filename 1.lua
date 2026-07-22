-- ==========================================
-- mini hub (ESP 精簡版)
-- 功能：鎖頭 | ESP(名字+距離+血量) | 傳送玩家 | 座標傳送
-- 快捷鍵：Q = 鎖頭 | E = ESP | K = 縮小/展開
-- Ctrl+S = 儲存座標 | Ctrl+T = 傳送
-- ==========================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

print("🔄 mini hub 載入中...")

-- ==========================================
-- 1. 設定
-- ==========================================
local Settings = {
    ESP = {
        Enabled = false,
        MaxDistance = 300,
        NameColor = Color3.fromRGB(255, 255, 255),
        DistColor = Color3.fromRGB(200, 200, 50),
    },
    Aimbot = {
        Enabled = false,
        MaxDistance = 250,
        FOV = 120,
        TeamCheck = true,
        TargetPart = "Head",
    }
}

-- ==========================================
-- 2. FOV 圓環
-- ==========================================
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.Color = Color3.fromRGB(0, 200, 255)
FOVCircle.Filled = false
FOVCircle.NumSides = 64
FOVCircle.Visible = false
FOVCircle.Radius = 150
FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

local function UpdateFOVCircle()
    FOVCircle.Radius = 30 + (Settings.Aimbot.FOV / 360) * 300
end
UpdateFOVCircle()

Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end)

-- ==========================================
-- 3. 輔助函數
-- ==========================================
local function GetCharacter(Player)
    if not Player then return nil end
    local Char = Player.Character
    if Char and Char:FindFirstChild("Humanoid") and Char.Humanoid.Health > 0 then
        return Char
    end
    return nil
end

local function GetRoot(Char)
    if Char then
        return Char:FindFirstChild("HumanoidRootPart") or Char:FindFirstChild("Torso")
    end
    return nil
end

-- ==========================================
-- 4. 鎖頭模組
-- ==========================================
local AimbotConn = nil

local function GetClosestTarget()
    local Char = LocalPlayer.Character
    if not Char then return nil end
    local Root = GetRoot(Char)
    if not Root then return nil end

    local Best = nil
    local BestDist = Settings.Aimbot.MaxDistance
    local CameraLook = Camera.CFrame.LookVector
    local CameraPos = Camera.CFrame.Position

    for _, P in ipairs(Players:GetPlayers()) do
        if P ~= LocalPlayer then
            if Settings.Aimbot.TeamCheck and P.Team == LocalPlayer.Team then
                continue
            end
            local PChar = GetCharacter(P)
            if not PChar then continue end
            local Part = PChar:FindFirstChild(Settings.Aimbot.TargetPart) or
                         PChar:FindFirstChild("UpperTorso") or
                         PChar:FindFirstChild("HumanoidRootPart")
            if not Part then continue end
            local Pos = Part.Position
            local Dist = (Root.Position - Pos).Magnitude
            if Dist < BestDist then
                local Dir = (Pos - CameraPos).Unit
                local Angle = math.deg(math.acos(CameraLook:Dot(Dir)))
                if Angle <= Settings.Aimbot.FOV / 2 then
                    BestDist = Dist
                    Best = Part
                end
            end
        end
    end
    return Best
end

local function ToggleAimbot()
    Settings.Aimbot.Enabled = not Settings.Aimbot.Enabled
    FOVCircle.Visible = Settings.Aimbot.Enabled
    if Settings.Aimbot.Enabled then
        print("🔒 鎖頭 開")
        if not AimbotConn then
            AimbotConn = RunService.RenderStepped:Connect(function()
                if not Settings.Aimbot.Enabled then return end
                local T = GetClosestTarget()
                if T then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, T.Position)
                end
            end)
        end
    else
        print("🔓 鎖頭 關")
        if AimbotConn then
            AimbotConn:Disconnect()
            AimbotConn = nil
        end
    end
    UpdateUI()
end

-- ==========================================
-- 5. ESP 模組 (只有名字 + 距離 + 血量)
-- ==========================================
local ESPObjects = {}
local ESPConn = nil
local ESPFolder = nil

local function CreateESPFolder()
    if ESPFolder then return end
    ESPFolder = Instance.new("Folder")
    ESPFolder.Name = "ESP_Objects"
    ESPFolder.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- 建立單一玩家的 ESP
local function CreatePlayerESP(Player)
    local Char = GetCharacter(Player)
    if not Char then return nil end
    
    local Head = Char:FindFirstChild("Head") or Char:FindFirstChild("UpperTorso") or Char:FindFirstChild("HumanoidRootPart")
    if not Head then return nil end

    -- BillboardGui (名稱 + 距離 + 血量)
    local BG = Instance.new("BillboardGui")
    BG.Size = UDim2.new(0, 120, 0, 55)
    BG.Adornee = Head
    BG.AlwaysOnTop = true
    BG.StudsOffset = Vector3.new(0, 2.5, 0)
    BG.Parent = Head

    -- 名稱 (第一行)
    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(1, 0, 0.3, 0)
    NameLabel.Position = UDim2.new(0, 0, 0, 0)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = Player.Name
    NameLabel.TextColor3 = Settings.ESP.NameColor
    NameLabel.TextSize = 11
    NameLabel.Font = Enum.Font.GothamBold
    NameLabel.Parent = BG

    -- 距離 (第二行)
    local DistLabel = Instance.new("TextLabel")
    DistLabel.Size = UDim2.new(1, 0, 0.25, 0)
    DistLabel.Position = UDim2.new(0, 0, 0.3, 0)
    DistLabel.BackgroundTransparency = 1
    DistLabel.Text = "0 stud"
    DistLabel.TextColor3 = Settings.ESP.DistColor
    DistLabel.TextSize = 9
    DistLabel.Font = Enum.Font.Gotham
    DistLabel.Parent = BG

    -- 血量條 (第三行)
    local HealthBG = Instance.new("Frame")
    HealthBG.Size = UDim2.new(0.8, 0, 0.12, 0)
    HealthBG.Position = UDim2.new(0.1, 0, 0.58, 0)
    HealthBG.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    HealthBG.BorderSizePixel = 1
    HealthBG.BorderColor3 = Color3.fromRGB(0, 0, 0)
    HealthBG.Parent = BG

    local HealthBar = Instance.new("Frame")
    HealthBar.Size = UDim2.new(1, 0, 1, 0)
    HealthBar.Position = UDim2.new(0, 0, 0, 0)
    HealthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    HealthBar.BorderSizePixel = 0
    HealthBar.Parent = HealthBG

    return {
        Player = Player,
        Billboard = BG,
        NameLabel = NameLabel,
        DistLabel = DistLabel,
        HealthBG = HealthBG,
        HealthBar = HealthBar,
        Head = Head,
    }
end

-- 清除所有 ESP
local function ClearAllESP()
    for _, Obj in ipairs(ESPObjects) do
        pcall(function()
            if Obj.Billboard then Obj.Billboard:Destroy() end
        end)
    end
    ESPObjects = {}
    if ESPFolder then
        pcall(function() ESPFolder:ClearAllChildren() end)
    end
end

-- 更新 ESP
local function UpdateESP()
    if not Settings.ESP.Enabled then
        ClearAllESP()
        return
    end

    local LocalRoot = LocalPlayer.Character and GetRoot(LocalPlayer.Character)
    if not LocalRoot then return end

    local players = Players:GetPlayers()
    
    -- 1. 移除已離開的玩家
    local toRemove = {}
    for i, Obj in ipairs(ESPObjects) do
        local stillExists = false
        for _, P in ipairs(players) do
            if Obj.Player == P then
                stillExists = true
                break
            end
        end
        if not stillExists then
            table.insert(toRemove, i)
        end
    end
    for _, idx in ipairs(toRemove) do
        local Obj = ESPObjects[idx]
        pcall(function()
            if Obj.Billboard then Obj.Billboard:Destroy() end
        end)
        table.remove(ESPObjects, idx)
    end

    -- 2. 處理每個玩家
    for _, P in ipairs(players) do
        if P == LocalPlayer then continue end
        
        local Char = GetCharacter(P)
        if not Char then
            -- 移除該玩家的 ESP
            for i, Obj in ipairs(ESPObjects) do
                if Obj.Player == P then
                    pcall(function()
                        if Obj.Billboard then Obj.Billboard:Destroy() end
                    end)
                    table.remove(ESPObjects, i)
                    break
                end
            end
            continue
        end

        local Root = GetRoot(Char)
        if not Root then continue end
        
        local Dist = (LocalRoot.Position - Root.Position).Magnitude

        -- 距離過濾
        if Dist > Settings.ESP.MaxDistance then
            for i, Obj in ipairs(ESPObjects) do
                if Obj.Player == P then
                    if Obj.Billboard then Obj.Billboard.Enabled = false end
                end
            end
            continue
        end

        -- 尋找現有的 ESP 物件
        local Existing = nil
        for i, Obj in ipairs(ESPObjects) do
            if Obj.Player == P then
                Existing = Obj
                break
            end
        end

        if Existing then
            -- 更新現有的 ESP
            pcall(function()
                if Existing.Billboard then
                    Existing.Billboard.Enabled = true
                    -- 確保 Adornee 仍然有效
                    local Head = Char:FindFirstChild("Head") or Char:FindFirstChild("UpperTorso")
                    if Head and Existing.Billboard.Adornee ~= Head then
                        Existing.Billboard.Adornee = Head
                    end
                end
                
                if Existing.DistLabel then
                    Existing.DistLabel.Text = string.format("%.0f stud", Dist)
                end

                -- 更新血量
                if Existing.HealthBar then
                    local Humanoid = Char:FindFirstChild("Humanoid")
                    if Humanoid then
                        local Percent = Humanoid.Health / Humanoid.MaxHealth
                        Existing.HealthBar.Size = UDim2.new(Percent, 0, 1, 0)
                        if Percent > 0.5 then
                            Existing.HealthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                        elseif Percent > 0.25 then
                            Existing.HealthBar.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
                        else
                            Existing.HealthBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
                        end
                    end
                end
            end)
        else
            -- 建立新的 ESP
            local Obj = CreatePlayerESP(P)
            if Obj then
                table.insert(ESPObjects, Obj)
            end
        end
    end
end

-- 切換 ESP
local function ToggleESP()
    Settings.ESP.Enabled = not Settings.ESP.Enabled

    if Settings.ESP.Enabled then
        CreateESPFolder()
        ClearAllESP()
        print("👁️ ESP 開")
        if not ESPConn then
            ESPConn = RunService.RenderStepped:Connect(UpdateESP)
        end
    else
        ClearAllESP()
        if ESPConn then
            ESPConn:Disconnect()
            ESPConn = nil
        end
        print("👁️ ESP 關")
    end
    UpdateUI()
end

-- ==========================================
-- 6. 傳送玩家模組
-- ==========================================
local CurrentTargetPlayer = nil
local PlayerList = {}

local function GetClosestPlayer()
    local Char = LocalPlayer.Character
    if not Char then return nil end
    local Root = GetRoot(Char)
    if not Root then return nil end

    local Best = nil
    local BestDist = math.huge

    for _, P in ipairs(Players:GetPlayers()) do
        if P ~= LocalPlayer then
            local PChar = GetCharacter(P)
            if PChar then
                local PRoot = GetRoot(PChar)
                if PRoot then
                    local Dist = (Root.Position - PRoot.Position).Magnitude
                    if Dist < BestDist then
                        BestDist = Dist
                        Best = P
                    end
                end
            end
        end
    end
    return Best
end

local function TeleportToPlayer(TargetPlayer)
    if not TargetPlayer then return false end

    local Found = nil
    for _, P in ipairs(Players:GetPlayers()) do
        if string.lower(P.Name):find(string.lower(TargetPlayer)) then
            Found = P
            break
        end
    end

    if not Found then
        print("❌ 找不到玩家: " .. TargetPlayer)
        return false
    end

    local Char = LocalPlayer.Character
    if not Char then return false end

    local TargetChar = GetCharacter(Found)
    if not TargetChar then return false end

    local TargetRoot = GetRoot(TargetChar)
    local MyRoot = GetRoot(Char)
    if not TargetRoot or not MyRoot then return false end

    pcall(function()
        MyRoot.CFrame = TargetRoot.CFrame + Vector3.new(0, 2, 0)
    end)
    print("✅ 已傳送到 " .. Found.Name)
    return true
end

local function UpdatePlayerList()
    PlayerList = {}
    for _, P in ipairs(Players:GetPlayers()) do
        if P ~= LocalPlayer then
            table.insert(PlayerList, P.Name)
        end
    end
    if #PlayerList == 0 then
        table.insert(PlayerList, "⚠️ 無玩家")
    end
    if not CurrentTargetPlayer or not table.find(PlayerList, CurrentTargetPlayer) then
        CurrentTargetPlayer = PlayerList[1]
    end
    if TargetLabel then
        TargetLabel.Text = "🎯 " .. CurrentTargetPlayer
    end
end

-- ==========================================
-- 7. 座標傳送模組
-- ==========================================
local SavedPoints = {}
local SelectedIndex = nil

-- ==========================================
-- 8. 建立主 UI
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MiniHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 280, 0, 470)
MainFrame.Position = UDim2.new(0.02, 0, 0.03, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
MainFrame.BackgroundTransparency = 0.08
MainFrame.BorderColor3 = Color3.fromRGB(0, 200, 255)
MainFrame.BorderSizePixel = 2
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
TitleBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.5, 0, 1, 0)
Title.Position = UDim2.new(0.05, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "📌 mini hub"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 28, 0, 24)
MinimizeBtn.Position = UDim2.new(1, -65, 0, 5)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 180)
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Text = "−"
MinimizeBtn.TextColor3 = Color3.new(1, 1, 1)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 18
MinimizeBtn.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 24)
CloseBtn.Position = UDim2.new(1, -33, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = TitleBar
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local isMinimized = false

local function MinimizeUI()
    isMinimized = true
    MainFrame.Size = UDim2.new(0, 50, 0, 35)
    MainFrame.Position = UDim2.new(0.9, -25, 0.02, 0)
    MainFrame.BackgroundTransparency = 0.3
    for _, child in ipairs(MainFrame:GetChildren()) do
        if child ~= TitleBar then
            child.Visible = false
        end
    end
    TitleBar.Size = UDim2.new(1, 0, 1, 0)
    Title.Text = "📌"
    Title.TextSize = 18
    MinimizeBtn.Text = "+"
    CloseBtn.Visible = false
end

local function ExpandUI()
    isMinimized = false
    MainFrame.Size = UDim2.new(0, 280, 0, 470)
    MainFrame.Position = UDim2.new(0.02, 0, 0.03, 0)
    MainFrame.BackgroundTransparency = 0.08
    for _, child in ipairs(MainFrame:GetChildren()) do
        if child ~= TitleBar then
            child.Visible = true
        end
    end
    TitleBar.Size = UDim2.new(1, 0, 0, 35)
    Title.Text = "📌 mini hub"
    Title.TextSize = 16
    MinimizeBtn.Text = "−"
    CloseBtn.Visible = true
end

MinimizeBtn.MouseButton1Click:Connect(function()
    if isMinimized then ExpandUI() else MinimizeUI() end
end)

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, 0, 1, -35)
ScrollFrame.Position = UDim2.new(0, 0, 0, 35)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 750)
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.Parent = MainFrame

local Y = 5

-- ==========================================
-- 輔助函數
-- ==========================================
local function AddDivider(Text)
    Y = Y + 5
    local Div = Instance.new("Frame")
    Div.Size = UDim2.new(0.9, 0, 0, 1)
    Div.Position = UDim2.new(0.05, 0, 0, Y)
    Div.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
    Div.Parent = ScrollFrame
    Y = Y + 5
    if Text then
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.9, 0, 0, 20)
        Label.Position = UDim2.new(0.05, 0, 0, Y)
        Label.BackgroundTransparency = 1
        Label.Text = Text
        Label.TextColor3 = Color3.fromRGB(180, 180, 210)
        Label.Font = Enum.Font.GothamBold
        Label.TextSize = 12
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = ScrollFrame
        Y = Y + 22
    end
end

local function AddButton(Text, Color, Callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0.85, 0, 0, 30)
    Btn.Position = UDim2.new(0.075, 0, 0, Y)
    Btn.BackgroundColor3 = Color
    Btn.Text = Text
    Btn.TextColor3 = Color3.new(1, 1, 1)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 13
    Btn.Parent = ScrollFrame
    Btn.MouseButton1Click:Connect(Callback)
    Y = Y + 36
    return Btn
end

local function AddSlider(LabelText, GetValue, SetValue, Min, Max, Step, Color)
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.5, 0, 0, 20)
    Label.Position = UDim2.new(0.02, 0, 0, Y)
    Label.BackgroundTransparency = 1
    Label.Text = LabelText .. GetValue()
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = ScrollFrame

    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(0.46, 0, 0, 20)
    Container.Position = UDim2.new(0.52, 0, 0, Y)
    Container.BackgroundTransparency = 1
    Container.Parent = ScrollFrame

    local MinusBtn = Instance.new("TextButton")
    MinusBtn.Size = UDim2.new(0.15, 0, 1, 0)
    MinusBtn.Position = UDim2.new(0, 0, 0, 0)
    MinusBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
    MinusBtn.Text = "−"
    MinusBtn.TextColor3 = Color3.new(1, 1, 1)
    MinusBtn.Font = Enum.Font.GothamBold
    MinusBtn.TextSize = 16
    MinusBtn.Parent = Container
    MinusBtn.MouseButton1Click:Connect(function()
        local v = math.clamp(GetValue() - Step, Min, Max)
        SetValue(v)
        Label.Text = LabelText .. GetValue()
    end)

    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0.6, 0, 1, 0)
    Btn.Position = UDim2.new(0.2, 0, 0, 0)
    Btn.BackgroundColor3 = Color3.fromRGB(50, 50, 75)
    Btn.Text = "────────●────────"
    Btn.TextColor3 = Color
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 10
    Btn.Parent = Container
    Btn.MouseButton1Click:Connect(function()
        local v = math.clamp(GetValue() + Step, Min, Max)
        SetValue(v)
        Label.Text = LabelText .. GetValue()
    end)

    local PlusBtn = Instance.new("TextButton")
    PlusBtn.Size = UDim2.new(0.15, 0, 1, 0)
    PlusBtn.Position = UDim2.new(0.85, 0, 0, 0)
    PlusBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
    PlusBtn.Text = "+"
    PlusBtn.TextColor3 = Color3.new(1, 1, 1)
    PlusBtn.Font = Enum.Font.GothamBold
    PlusBtn.TextSize = 16
    PlusBtn.Parent = Container
    PlusBtn.MouseButton1Click:Connect(function()
        local v = math.clamp(GetValue() + Step, Min, Max)
        SetValue(v)
        Label.Text = LabelText .. GetValue()
    end)

    Y = Y + 26
    return Label
end

local function AddColorPicker(LabelText, ColorRef, Callback)
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.4, 0, 0, 20)
    Label.Position = UDim2.new(0.05, 0, 0, Y)
    Label.BackgroundTransparency = 1
    Label.Text = LabelText
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = ScrollFrame

    local Preview = Instance.new("Frame")
    Preview.Size = UDim2.new(0.12, 0, 0, 16)
    Preview.Position = UDim2.new(0.5, 0, 0, Y+2)
    Preview.BackgroundColor3 = ColorRef
    Preview.BorderSizePixel = 1
    Preview.BorderColor3 = Color3.fromRGB(255, 255, 255)
    Preview.Parent = ScrollFrame

    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0.2, 0, 0, 20)
    Btn.Position = UDim2.new(0.7, 0, 0, Y)
    Btn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
    Btn.Text = "換色"
    Btn.TextColor3 = Color3.new(1, 1, 1)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 11
    Btn.Parent = ScrollFrame
    Btn.MouseButton1Click:Connect(function()
        local Colors = {
            Color3.fromRGB(255, 255, 255),
            Color3.fromRGB(255, 200, 0),
            Color3.fromRGB(0, 200, 255),
            Color3.fromRGB(255, 100, 255),
        }
        local idx = 1
        for i, c in ipairs(Colors) do
            if c == ColorRef then
                idx = i % #Colors + 1
                break
            end
        end
        Preview.BackgroundColor3 = Colors[idx]
        Callback(Colors[idx])
    end)
    Y = Y + 28
end

local function AddSmallBtn(Text, X, Color, Callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0.28, 0, 0, 26)
    Btn.Position = UDim2.new(X, 0, 0, Y)
    Btn.BackgroundColor3 = Color
    Btn.Text = Text
    Btn.TextColor3 = Color3.new(1, 1, 1)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 11
    Btn.Parent = ScrollFrame
    Btn.MouseButton1Click:Connect(Callback)
    return Btn
end

local function AddDropdown(LabelText, Options, GetCurrent, SetCurrent)
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.4, 0, 0, 20)
    Label.Position = UDim2.new(0.05, 0, 0, Y)
    Label.BackgroundTransparency = 1
    Label.Text = LabelText
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = ScrollFrame

    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0.4, 0, 0, 20)
    Btn.Position = UDim2.new(0.55, 0, 0, Y)
    Btn.BackgroundColor3 = Color3.fromRGB(50, 50, 75)
    Btn.Text = GetCurrent()
    Btn.TextColor3 = Color3.new(1, 1, 1)
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 11
    Btn.Parent = ScrollFrame
    Btn.MouseButton1Click:Connect(function()
        local current = GetCurrent()
        local idx = 1
        for i, v in ipairs(Options) do
            if v == current then
                idx = i % #Options + 1
                break
            end
        end
        local new = Options[idx]
        SetCurrent(new)
        Btn.Text = new
    end)
    Y = Y + 28
    return Btn
end

local function UpdateUI()
    if AimBtn then
        AimBtn.Text = Settings.Aimbot.Enabled and "🟢 鎖頭: 開" or "🔴 鎖頭: 關"
        AimBtn.BackgroundColor3 = Settings.Aimbot.Enabled and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 50, 50)
    end
    if ESPBtn then
        ESPBtn.Text = Settings.ESP.Enabled and "🟢 ESP: 開" or "🔴 ESP: 關"
        ESPBtn.BackgroundColor3 = Settings.ESP.Enabled and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 50, 50)
    end
end

-- ==========================================
-- 9. 建立 UI 內容
-- ==========================================

AddDivider("⚡ 快速開關")
local AimBtn = AddButton("🔴 鎖頭: 關", Color3.fromRGB(200, 50, 50), ToggleAimbot)
local ESPBtn = AddButton("🔴 ESP: 關", Color3.fromRGB(200, 50, 50), ToggleESP)

AddDivider("🎯 鎖頭設定")
AddSlider("FOV: ", function() return Settings.Aimbot.FOV end, function(v) Settings.Aimbot.FOV = v; UpdateFOVCircle() end, 30, 360, 5, Color3.fromRGB(0, 200, 255))
AddSlider("距離: ", function() return Settings.Aimbot.MaxDistance end, function(v) Settings.Aimbot.MaxDistance = v end, 50, 400, 10, Color3.fromRGB(255, 200, 50))

local aimParts = {"Head", "UpperTorso", "HumanoidRootPart"}
local function GetAimPart() return Settings.Aimbot.TargetPart end
local function SetAimPart(v) Settings.Aimbot.TargetPart = v end
AddDropdown("瞄準部位:", aimParts, GetAimPart, SetAimPart)

local TeamBtn = Instance.new("TextButton")
TeamBtn.Size = UDim2.new(0.4, 0, 0, 24)
TeamBtn.Position = UDim2.new(0.05, 0, 0, Y)
TeamBtn.BackgroundColor3 = Settings.Aimbot.TeamCheck and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(60, 60, 70)
TeamBtn.Text = Settings.Aimbot.TeamCheck and "👥 略過隊友: 開" or "👥 略過隊友: 關"
TeamBtn.TextColor3 = Color3.new(1, 1, 1)
TeamBtn.Font = Enum.Font.GothamBold
TeamBtn.TextSize = 12
TeamBtn.Parent = ScrollFrame
TeamBtn.MouseButton1Click:Connect(function()
    Settings.Aimbot.TeamCheck = not Settings.Aimbot.TeamCheck
    TeamBtn.Text = Settings.Aimbot.TeamCheck and "👥 略過隊友: 開" or "👥 略過隊友: 關"
    TeamBtn.BackgroundColor3 = Settings.Aimbot.TeamCheck and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(60, 60, 70)
end)
Y = Y + 32

AddDivider("👁️ ESP 設定")

AddSlider("最大距離: ", function() return Settings.ESP.MaxDistance end, function(v) Settings.ESP.MaxDistance = v end, 50, 500, 10, Color3.fromRGB(255, 200, 50))

AddColorPicker("名稱顏色", Settings.ESP.NameColor, function(v)
    Settings.ESP.NameColor = v
    for _, Obj in ipairs(ESPObjects) do
        if Obj.NameLabel then
            Obj.NameLabel.TextColor3 = v
        end
    end
end)

AddColorPicker("距離顏色", Settings.ESP.DistColor, function(v)
    Settings.ESP.DistColor = v
    for _, Obj in ipairs(ESPObjects) do
        if Obj.DistLabel then
            Obj.DistLabel.TextColor3 = v
        end
    end
end)

-- ==========================================
-- 傳送玩家
-- ==========================================
AddDivider("🚀 傳送玩家")

local TargetLabel = Instance.new("TextLabel")
TargetLabel.Size = UDim2.new(0.85, 0, 0, 22)
TargetLabel.Position = UDim2.new(0.075, 0, 0, Y)
TargetLabel.BackgroundTransparency = 1
TargetLabel.Text = "🎯 無玩家"
TargetLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
TargetLabel.Font = Enum.Font.GothamBold
TargetLabel.TextSize = 12
TargetLabel.TextXAlignment = Enum.TextXAlignment.Left
TargetLabel.Parent = ScrollFrame
Y = Y + 28

AddButton("🔄 切換目標", Color3.fromRGB(60, 60, 90), function()
    if #PlayerList == 0 then UpdatePlayerList() end
    if #PlayerList == 0 or (PlayerList[1] == "⚠️ 無玩家") then
        print("⚠️ 沒有其他玩家")
        return
    end
    local idx = 1
    for i, name in ipairs(PlayerList) do
        if name == CurrentTargetPlayer then
            idx = i % #PlayerList + 1
            break
        end
    end
    CurrentTargetPlayer = PlayerList[idx]
    TargetLabel.Text = "🎯 " .. CurrentTargetPlayer
    print("✅ 已切換到: " .. CurrentTargetPlayer)
end)

AddButton("🚀 傳送", Color3.fromRGB(50, 150, 220), function()
    if not CurrentTargetPlayer or CurrentTargetPlayer == "⚠️ 無玩家" then
        print("⚠️ 沒有玩家可傳送")
        return
    end
    TeleportToPlayer(CurrentTargetPlayer)
end)

AddButton("🚀 傳送到最近玩家", Color3.fromRGB(50, 200, 150), function()
    local Target = GetClosestPlayer()
    if Target then
        TeleportToPlayer(Target.Name)
        CurrentTargetPlayer = Target.Name
        TargetLabel.Text = "🎯 " .. CurrentTargetPlayer
    else
        print("⚠️ 附近沒有玩家")
    end
end)

AddButton("🔄 刷新列表", Color3.fromRGB(200, 180, 50), function()
    UpdatePlayerList()
    TargetLabel.Text = "🎯 " .. CurrentTargetPlayer
    print("✅ 玩家列表已刷新 (" .. #PlayerList .. " 位)")
end)

UpdatePlayerList()
TargetLabel.Text = "🎯 " .. CurrentTargetPlayer

-- ==========================================
-- 座標傳送
-- ==========================================
AddDivider("📍 座標傳送")
AddSmallBtn("💾 儲存", 0.05, Color3.fromRGB(0, 180, 80), function()
    local Char = LocalPlayer.Character
    if Char and Char:FindFirstChild("HumanoidRootPart") then
        table.insert(SavedPoints, Char.HumanoidRootPart.Position)
        RefreshCoordList()
        print("✅ 儲存座標 #" .. #SavedPoints)
    end
end)
AddSmallBtn("🚀 傳送", 0.36, Color3.fromRGB(50, 150, 220), function()
    if not SelectedIndex then
        print("⚠️ 請先點擊列表選取座標")
        return
    end
    local Pos = SavedPoints[SelectedIndex]
    if Pos then
        local Char = LocalPlayer.Character
        if Char and Char:FindFirstChild("HumanoidRootPart") then
            Char.HumanoidRootPart.CFrame = CFrame.new(Pos)
            print("✅ 傳送座標 #" .. SelectedIndex)
        end
    end
end)
AddSmallBtn("🗑️ 清空", 0.67, Color3.fromRGB(200, 50, 50), function()
    if #SavedPoints > 0 then
        SavedPoints = {}
        SelectedIndex = nil
        RefreshCoordList()
        print("🗑️ 已清空全部座標")
    end
end)

Y = Y + 34

local CoordListFrame = Instance.new("ScrollingFrame")
CoordListFrame.Size = UDim2.new(0.85, 0, 0, 80)
CoordListFrame.Position = UDim2.new(0.075, 0, 0, Y)
CoordListFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
CoordListFrame.BorderSizePixel = 1
CoordListFrame.BorderColor3 = Color3.fromRGB(80, 80, 120)
CoordListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
CoordListFrame.ScrollBarThickness = 4
CoordListFrame.Parent = ScrollFrame
Y = Y + 90

function RefreshCoordList()
    for _, c in ipairs(CoordListFrame:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    if #SavedPoints == 0 then
        local E = Instance.new("TextLabel")
        E.Size = UDim2.new(1, 0, 0, 30)
        E.BackgroundTransparency = 1
        E.Text = "⚠️ 無座標 (按儲存)"
        E.TextColor3 = Color3.fromRGB(150, 150, 150)
        E.Font = Enum.Font.Gotham
        E.TextSize = 12
        E.Parent = CoordListFrame
        return
    end

    CoordListFrame.CanvasSize = UDim2.new(0, 0, 0, #SavedPoints * 30 + 4)

    for i, Pos in ipairs(SavedPoints) do
        local B = Instance.new("TextButton")
        B.Size = UDim2.new(1, -4, 0, 26)
        B.BackgroundColor3 = (SelectedIndex == i) and Color3.fromRGB(50, 120, 200) or Color3.fromRGB(50, 50, 75)
        B.BorderSizePixel = 1
        B.BorderColor3 = Color3.fromRGB(80, 80, 120)
        B.Text = "#" .. i .. " (" .. string.format("%.0f,%.0f,%.0f", Pos.X, Pos.Y, Pos.Z) .. ")"
        B.TextColor3 = Color3.new(1, 1, 1)
        B.Font = Enum.Font.Gotham
        B.TextSize = 10
        B.TextXAlignment = Enum.TextXAlignment.Left
        B.Parent = CoordListFrame

        B.MouseButton1Click:Connect(function()
            if SelectedIndex == i then
                SelectedIndex = nil
                print("🔓 取消選取 #" .. i)
            else
                SelectedIndex = i
                print("✅ 已選取 #" .. i)
            end
            RefreshCoordList()
        end)

        B.MouseButton2Click:Connect(function()
            table.remove(SavedPoints, i)
            if SelectedIndex == i then SelectedIndex = nil end
            RefreshCoordList()
            print("🗑️ 刪除 #" .. i)
        end)

        local holding = false
        local holdTime = 0
        B.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                holding = true
                holdTime = tick()
                task.wait(0.5)
                if holding and (tick() - holdTime) >= 0.5 then
                    if i <= #SavedPoints then
                        table.remove(SavedPoints, i)
                        if SelectedIndex == i then SelectedIndex = nil end
                        RefreshCoordList()
                        print("🗑️ 長按刪除 #" .. i)
                    end
                end
            end
        end)
        B.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                holding = false
            end
        end)
    end
end
RefreshCoordList()

ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, Y + 20)

UpdateUI()

-- ==========================================
-- 10. 快捷鍵
-- ==========================================
UserInputService.InputBegan:Connect(function(I, G)
    if G then return end

    if I.KeyCode == Enum.KeyCode.Q then
        ToggleAimbot()
    elseif I.KeyCode == Enum.KeyCode.E then
        ToggleESP()
    elseif I.KeyCode == Enum.KeyCode.K then
        if isMinimized then ExpandUI() else MinimizeUI() end
    elseif I.KeyCode == Enum.KeyCode.S and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local Char = LocalPlayer.Character
        if Char and Char:FindFirstChild("HumanoidRootPart") then
            table.insert(SavedPoints, Char.HumanoidRootPart.Position)
            RefreshCoordList()
            print("✅ 儲存座標 #" .. #SavedPoints)
        end
    elseif I.KeyCode == Enum.KeyCode.T and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        if SelectedIndex and SavedPoints[SelectedIndex] then
            local Char = LocalPlayer.Character
            if Char and Char:FindFirstChild("HumanoidRootPart") then
                Char.HumanoidRootPart.CFrame = CFrame.new(SavedPoints[SelectedIndex])
                print("✅ 傳送座標 #" .. SelectedIndex)
            end
        else
            print("⚠️ 請先點擊列表選取座標")
        end
    end
end)

print("✅ mini hub (ESP 精簡版) 已載入")
print("   📌 ESP: 名字 + 距離 + 血量")
print("   Q: 鎖頭 | E: ESP | K: 縮小/展開")
print("   Ctrl+S: 儲存座標 | Ctrl+T: 傳送")