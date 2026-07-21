-- ==========================================
-- mini hub (Orion UI 最終版)
-- 功能：鎖頭 | ESP | 座標傳送
-- 快捷鍵：Q = 鎖頭 | E = ESP | K = 開關UI
-- Ctrl+S = 儲存座標 | Ctrl+T = 傳送
-- ==========================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

print("🔄 mini hub 載入中...")

-- ==========================================
-- 1. 載入 Orion UI
-- ==========================================
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Qanuir/orion-ui/refs/heads/main/source.lua"))()

if not OrionLib then
    print("❌ Orion UI 載入失敗")
    return
end

-- ==========================================
-- 2. 設定
-- ==========================================
local Settings = {
    ESP = {
        Enabled = false,
        MaxDistance = 300,
        BoxColor = Color3.fromRGB(255, 50, 50),
        NameColor = Color3.fromRGB(255, 255, 255),
        DistColor = Color3.fromRGB(200, 200, 50),
    },
    Aimbot = {
        Enabled = false,
        MaxDistance = 250,
        Smoothness = 0.25,
        FOV = 120,
        TeamCheck = true,
        TargetPart = "Head",
    }
}

-- ==========================================
-- 3. FOV 圓環
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
-- 4. 鎖頭模組
-- ==========================================
local AimbotConn = nil

local function GetClosestTarget()
    local Char = LocalPlayer.Character
    if not Char then return nil end
    local Root = Char:FindFirstChild("HumanoidRootPart")
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
            local PChar = P.Character
            if not PChar or not PChar:FindFirstChild("Humanoid") or PChar.Humanoid.Health <= 0 then
                continue
            end
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
                    local CF = Camera.CFrame
                    Camera.CFrame = CF:Lerp(CFrame.new(CF.Position, T.Position), Settings.Aimbot.Smoothness)
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
end

-- ==========================================
-- 5. ESP 模組 (BillboardGui)
-- ==========================================
local ESPObjects = {}
local ESPConn = nil

local function CreateESP(Player)
    local Char = Player.Character
    if not Char then return nil end
    local Head = Char:FindFirstChild("Head") or Char:FindFirstChild("UpperTorso") or Char:FindFirstChild("HumanoidRootPart")
    if not Head then return nil end

    local BG = Instance.new("BillboardGui")
    BG.Size = UDim2.new(0, 120, 0, 45)
    BG.Adornee = Head
    BG.AlwaysOnTop = true
    BG.StudsOffset = Vector3.new(0, 2.5, 0)
    BG.Parent = Head

    -- 名稱 (字體小)
    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(1, 0, 0.4, 0)
    NameLabel.Position = UDim2.new(0, 0, 0, 0)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = Player.Name
    NameLabel.TextColor3 = Settings.ESP.NameColor
    NameLabel.TextSize = 11
    NameLabel.Font = Enum.Font.GothamBold
    NameLabel.Parent = BG

    -- 距離 (字體小)
    local DistLabel = Instance.new("TextLabel")
    DistLabel.Size = UDim2.new(1, 0, 0.3, 0)
    DistLabel.Position = UDim2.new(0, 0, 0.4, 0)
    DistLabel.BackgroundTransparency = 1
    DistLabel.Text = "0 stud"
    DistLabel.TextColor3 = Settings.ESP.DistColor
    DistLabel.TextSize = 9
    DistLabel.Font = Enum.Font.Gotham
    DistLabel.Parent = BG

    -- 血量條
    local HealthBar = Instance.new("Frame")
    HealthBar.Size = UDim2.new(1, 0, 0.12, 0)
    HealthBar.Position = UDim2.new(0, 0, 0.72, 0)
    HealthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    HealthBar.BorderSizePixel = 1
    HealthBar.BorderColor3 = Color3.fromRGB(0, 0, 0)
    HealthBar.Parent = BG

    local HealthBG = Instance.new("Frame")
    HealthBG.Size = UDim2.new(1, 0, 1, 0)
    HealthBG.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    HealthBG.BorderSizePixel = 0
    HealthBG.Parent = HealthBar

    return {
        Billboard = BG,
        NameLabel = NameLabel,
        DistLabel = DistLabel,
        HealthBar = HealthBar,
        HealthBG = HealthBG,
        Player = Player,
    }
end

local function UpdateESP()
    local LocalRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    for _, Obj in ipairs(ESPObjects) do
        local Char = Obj.Player.Character
        if not Char or not Char:FindFirstChild("Humanoid") or Char.Humanoid.Health <= 0 then
            if Obj.Billboard then Obj.Billboard.Enabled = false end
            continue
        end
        local Root = Char:FindFirstChild("HumanoidRootPart")
        if LocalRoot and Root then
            local Dist = (LocalRoot.Position - Root.Position).Magnitude
            if Dist > Settings.ESP.MaxDistance then
                Obj.Billboard.Enabled = false
            else
                Obj.Billboard.Enabled = true
                Obj.DistLabel.Text = string.format("%.0f stud", Dist)
                local Health = Char.Humanoid.Health
                local MaxHealth = Char.Humanoid.MaxHealth
                local Percent = Health / MaxHealth
                Obj.HealthBar.Size = UDim2.new(Percent, 0, 0.12, 0)
                if Percent > 0.5 then
                    Obj.HealthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                elseif Percent > 0.25 then
                    Obj.HealthBar.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
                else
                    Obj.HealthBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
                end
            end
        end
    end
end

local function ToggleESP()
    Settings.ESP.Enabled = not Settings.ESP.Enabled
    if Settings.ESP.Enabled then
        for _, Obj in ipairs(ESPObjects) do pcall(function() Obj.Billboard:Destroy() end) end
        ESPObjects = {}
        for _, P in ipairs(Players:GetPlayers()) do
            if P ~= LocalPlayer then
                local Obj = CreateESP(P)
                if Obj then table.insert(ESPObjects, Obj) end
            end
        end
        if not ESPConn then ESPConn = RunService.Heartbeat:Connect(UpdateESP) end
        print("👁️ ESP 開 (" .. #ESPObjects .. ")")
    else
        for _, Obj in ipairs(ESPObjects) do pcall(function() Obj.Billboard:Destroy() end) end
        ESPObjects = {}
        if ESPConn then ESPConn:Disconnect() ESPConn = nil end
        print("👁️ ESP 關")
    end
end

Players.PlayerAdded:Connect(function(P)
    if Settings.ESP.Enabled and P ~= LocalPlayer then
        task.wait(0.5)
        local Obj = CreateESP(P)
        if Obj then table.insert(ESPObjects, Obj) end
    end
end)

-- ==========================================
-- 6. 座標傳送模組
-- ==========================================
local SavedPoints = {}
local SelectedIndex = nil

-- ==========================================
-- 7. Orion UI
-- ==========================================
local Window = OrionLib:MakeWindow({
    Name = "mini hub",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "MiniHub",
    IntroEnabled = true,
    IntroText = "mini hub",
    IntroIcon = "rbxassetid://4483345998",
})

-- ==========================================
-- 分頁1：功能
-- ==========================================
local MainTab = Window:MakeTab({ Name = "功能", Icon = "rbxassetid://4483345998" })
local MainSection = MainTab:AddSection({ Name = "快速開關" })

MainSection:AddButton({
    Name = "🎯 鎖頭 (Q)",
    Callback = ToggleAimbot
})

MainSection:AddButton({
    Name = "👁️ ESP (E)",
    Callback = ToggleESP
})

-- ==========================================
-- 分頁2：鎖頭設定
-- ==========================================
local AimTab = Window:MakeTab({ Name = "鎖頭設定", Icon = "rbxassetid://4483345998" })
local AimSection = AimTab:AddSection({ Name = "鎖頭參數" })

AimSection:AddSlider({
    Name = "🔵 FOV 範圍",
    Min = 30,
    Max = 360,
    Default = 120,
    Color = Color3.fromRGB(0, 200, 255),
    Increment = 5,
    ValueName = "度",
    Callback = function(v)
        Settings.Aimbot.FOV = v
        UpdateFOVCircle()
    end
})

AimSection:AddSlider({
    Name = "🎯 鎖頭平滑度",
    Min = 5,
    Max = 50,
    Default = 25,
    Color = Color3.fromRGB(255, 200, 100),
    Increment = 5,
    ValueName = "%",
    Callback = function(v)
        Settings.Aimbot.Smoothness = v / 100
    end
})

AimSection:AddSlider({
    Name = "📏 鎖頭距離",
    Min = 50,
    Max = 400,
    Default = 250,
    Color = Color3.fromRGB(255, 200, 50),
    Increment = 10,
    ValueName = "stud",
    Callback = function(v)
        Settings.Aimbot.MaxDistance = v
    end
})

AimSection:AddDropdown({
    Name = "🎯 瞄準部位",
    Default = "Head",
    Options = {"Head", "UpperTorso", "HumanoidRootPart"},
    Callback = function(v)
        Settings.Aimbot.TargetPart = v
    end
})

AimSection:AddToggle({
    Name = "👥 略過隊友",
    Default = true,
    Callback = function(v)
        Settings.Aimbot.TeamCheck = v
    end
})

-- ==========================================
-- 分頁3：ESP設定
-- ==========================================
local ESPTab = Window:MakeTab({ Name = "ESP設定", Icon = "rbxassetid://4483345998" })
local ESPSection = ESPTab:AddSection({ Name = "ESP 參數" })

ESPSection:AddSlider({
    Name = "📏 ESP 最大距離",
    Min = 50,
    Max = 500,
    Default = 300,
    Color = Color3.fromRGB(255, 200, 50),
    Increment = 10,
    ValueName = "stud",
    Callback = function(v)
        Settings.ESP.MaxDistance = v
    end
})

ESPSection:AddColorPicker({
    Name = "🎨 方框顏色",
    Default = Color3.fromRGB(255, 50, 50),
    Callback = function(v)
        Settings.ESP.BoxColor = v
        for _, Obj in ipairs(ESPObjects) do
            if Obj.HealthBar then
                Obj.HealthBar.BackgroundColor3 = v
            end
        end
    end
})

ESPSection:AddColorPicker({
    Name = "📝 名稱顏色",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(v)
        Settings.ESP.NameColor = v
        for _, Obj in ipairs(ESPObjects) do
            if Obj.NameLabel then
                Obj.NameLabel.TextColor3 = v
            end
        end
    end
})

ESPSection:AddColorPicker({
    Name = "📏 距離顏色",
    Default = Color3.fromRGB(200, 200, 50),
    Callback = function(v)
        Settings.ESP.DistColor = v
        for _, Obj in ipairs(ESPObjects) do
            if Obj.DistLabel then
                Obj.DistLabel.TextColor3 = v
            end
        end
    end
})

-- ==========================================
-- 分頁4：座標傳送
-- ==========================================
local TPTab = Window:MakeTab({ Name = "座標", Icon = "rbxassetid://4483345998" })
local TPSection = TPTab:AddSection({ Name = "座標傳送" })

TPSection:AddButton({
    Name = "💾 儲存當前位置 (Ctrl+S)",
    Callback = function()
        local Char = LocalPlayer.Character
        if Char and Char:FindFirstChild("HumanoidRootPart") then
            table.insert(SavedPoints, Char.HumanoidRootPart.Position)
            RefreshList()
            print("✅ 儲存 #" .. #SavedPoints)
        end
    end
})

TPSection:AddButton({
    Name = "🚀 傳送 (Ctrl+T)",
    Callback = function()
        if not SelectedIndex then
            print("⚠️ 請先點擊列表選取座標")
            return
        end
        local Pos = SavedPoints[SelectedIndex]
        if Pos then
            local Char = LocalPlayer.Character
            if Char and Char:FindFirstChild("HumanoidRootPart") then
                Char.HumanoidRootPart.CFrame = CFrame.new(Pos)
                print("✅ 傳送 #" .. SelectedIndex)
            end
        end
    end
})

TPSection:AddButton({
    Name = "🗑️ 清空全部",
    Callback = function()
        if #SavedPoints > 0 then
            SavedPoints = {}
            SelectedIndex = nil
            RefreshList()
            print("🗑️ 已清空")
        end
    end
})

-- 座標列表
local ListFrame = Instance.new("ScrollingFrame")
ListFrame.Size = UDim2.new(0, 200, 0, 120)
ListFrame.Position = UDim2.new(0.05, 0, 0.65, 0)
ListFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
ListFrame.BorderSizePixel = 1
ListFrame.BorderColor3 = Color3.fromRGB(80, 80, 120)
ListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ListFrame.ScrollBarThickness = 6
ListFrame.Parent = Window._Tabs[TPTab._Index]._Container

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 4)
ListLayout.Parent = ListFrame

function RefreshList()
    for _, c in ipairs(ListFrame:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    if #SavedPoints == 0 then
        local E = Instance.new("TextLabel")
        E.Size = UDim2.new(1, 0, 0, 30)
        E.BackgroundTransparency = 1
        E.Text = "⚠️ 無座標 (點擊儲存)"
        E.TextColor3 = Color3.fromRGB(150, 150, 150)
        E.Font = Enum.Font.Gotham
        E.TextSize = 12
        E.Parent = ListFrame
        return
    end
    ListFrame.CanvasSize = UDim2.new(0, 0, 0, #SavedPoints * 30 + 4)
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
        B.Parent = ListFrame

        B.MouseButton1Click:Connect(function()
            if SelectedIndex == i then
                SelectedIndex = nil
                print("🔓 取消選取 #" .. i)
            else
                SelectedIndex = i
                print("✅ 已選取 #" .. i)
            end
            RefreshList()
        end)

        B.MouseButton2Click:Connect(function()
            table.remove(SavedPoints, i)
            if SelectedIndex == i then SelectedIndex = nil end
            RefreshList()
            print("🗑️ 刪除 #" .. i)
        end)
    end
end
RefreshList()

-- ==========================================
-- 分頁5：關於
-- ==========================================
local AboutTab = Window:MakeTab({ Name = "關於", Icon = "rbxassetid://4483345998" })
local AboutSection = AboutTab:AddSection({ Name = "mini hub" })

AboutSection:AddParagraph({
    Name = "📌 版本資訊",
    Content = "mini hub v2\nOrion UI 最終版\n\n快捷鍵：\nQ = 鎖頭\nE = ESP\nK = 開關UI\nCtrl+S = 儲存座標\nCtrl+T = 傳送"
})

-- ==========================================
-- 8. 快捷鍵
-- ==========================================
UserInputService.InputBegan:Connect(function(I, G)
    if G then return end

    if I.KeyCode == Enum.KeyCode.Q then
        ToggleAimbot()
    elseif I.KeyCode == Enum.KeyCode.E then
        ToggleESP()
    elseif I.KeyCode == Enum.KeyCode.K then
        Window:Toggle()
    elseif I.KeyCode == Enum.KeyCode.S and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local Char = LocalPlayer.Character
        if Char and Char:FindFirstChild("HumanoidRootPart") then
            table.insert(SavedPoints, Char.HumanoidRootPart.Position)
            RefreshList()
            print("✅ 儲存 #" .. #SavedPoints)
        end
    elseif I.KeyCode == Enum.KeyCode.T and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        if SelectedIndex and SavedPoints[SelectedIndex] then
            local Char = LocalPlayer.Character
            if Char and Char:FindFirstChild("HumanoidRootPart") then
                Char.HumanoidRootPart.CFrame = CFrame.new(SavedPoints[SelectedIndex])
                print("✅ 傳送 #" .. SelectedIndex)
            end
        else
            print("⚠️ 請先點擊列表選取座標")
        end
    end
end)

-- ==========================================
-- 9. 載入完成
-- ==========================================
print("✅ mini hub (Orion UI 最終版) 已載入")
print("   📌 分頁：功能 | 鎖頭設定 | ESP設定 | 座標 | 關於")
print("   Q: 鎖頭 | E: ESP | K: 開關UI")
print("   Ctrl+S: 儲存座標 | Ctrl+T: 傳送")
print("   💡 點擊座標列表中的項目即可選取")