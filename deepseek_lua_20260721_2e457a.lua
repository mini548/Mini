-- ==========================================
-- 三合一 Hub (繁體中文版)
-- 功能：飛行 | ESP | 鎖頭
-- 快捷鍵：F = 飛行 | E = ESP | Q = 鎖頭
-- ==========================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

-- ==========================================
-- 1. 飛行模組 (Fly) - 保留你原本的邏輯
-- ==========================================
local Fly = {}
Fly.Enabled = false
Fly.Speed = 50
Fly.ToggleKey = Enum.KeyCode.F

local function StartFly(Character)
    local Root = Character:FindFirstChild("HumanoidRootPart")
    if not Root then return end

    local BV = Instance.new("BodyVelocity")
    BV.MaxForce = Vector3.new(1, 1, 1) * 4000
    BV.Velocity = Vector3.new(0, 0, 0)
    BV.Parent = Root

    local BG = Instance.new("BodyGyro")
    BG.MaxTorque = Vector3.new(1, 1, 1) * 4000
    BG.CFrame = Root.CFrame
    BG.Parent = Root

    return {BV = BV, BG = BG}
end

local function StopFly(Character, Parts)
    if Parts then
        Parts.BV:Destroy()
        Parts.BG:Destroy()
    end
    local Humanoid = Character:FindFirstChild("Humanoid")
    if Humanoid then
        Humanoid.PlatformStand = false
    end
end

function Fly.Toggle()
    local Character = LocalPlayer.Character
    if not Character then return end

    if Fly.Enabled then
        if Fly._Parts then
            StopFly(Character, Fly._Parts)
            Fly._Parts = nil
        end
        Fly.Enabled = false
        print("✈️ 飛行已關閉")
    else
        Fly._Parts = StartFly(Character)
        local Humanoid = Character:FindFirstChild("Humanoid")
        if Humanoid then
            Humanoid.PlatformStand = true
        end
        Fly.Enabled = true
        print("✈️ 飛行已開啟")
    end
    UpdateUI()
end

local function UpdateFlight()
    if not Fly.Enabled or not Fly._Parts then return end

    local Character = LocalPlayer.Character
    if not Character then return end

    local Root = Character:FindFirstChild("HumanoidRootPart")
    if not Root then return end

    local Speed = Fly.Speed
    local MoveVec = Vector3.new(0, 0, 0)
    local Forward = Root.CFrame.LookVector
    local Right = Root.CFrame.RightVector

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then MoveVec = MoveVec + Forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then MoveVec = MoveVec - Forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then MoveVec = MoveVec - Right end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then MoveVec = MoveVec + Right end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then MoveVec = MoveVec + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then MoveVec = MoveVec - Vector3.new(0, 1, 0) end

    if MoveVec.Magnitude > 0 then
        Fly._Parts.BV.Velocity = MoveVec.Unit * Speed
    else
        Fly._Parts.BV.Velocity = Vector3.new(0, 0, 0)
    end
    Fly._Parts.BG.CFrame = Root.CFrame
end

RunService.RenderStepped:Connect(UpdateFlight)

-- ==========================================
-- 2. ESP 透視模組
-- ==========================================
local ESP = {}
ESP.Enabled = false
ESP.ToggleKey = Enum.KeyCode.E
ESP._Objects = {}

-- 檢查執行器是否支援 Drawing 庫
local Drawing = Drawing or nil

local function CreateESPBox(PlayerToESP)
    if not Drawing then return nil end
    
    local Box = Drawing.new("Square")
    Box.Thickness = 1
    Box.Color = Color3.fromRGB(255, 50, 50)
    Box.Filled = false
    Box.Visible = false

    local NameTag = Drawing.new("Text")
    NameTag.Color = Color3.fromRGB(255, 255, 255)
    NameTag.Size = 14
    NameTag.Center = true
    NameTag.Visible = false

    return {Box = Box, NameTag = NameTag, Player = PlayerToESP}
end

function ESP.Toggle()
    if not Drawing then
        print("⚠️ 你的執行器不支援 Drawing 庫，ESP 無法使用")
        return
    end
    
    ESP.Enabled = not ESP.Enabled

    if ESP.Enabled then
        for _, P in ipairs(Players:GetPlayers()) do
            if P ~= LocalPlayer then
                local obj = CreateESPBox(P)
                if obj then
                    table.insert(ESP._Objects, obj)
                end
            end
        end
        print("👁️ ESP 已開啟")
    else
        for _, Obj in ipairs(ESP._Objects) do
            if Obj.Box then Obj.Box:Remove() end
            if Obj.NameTag then Obj.NameTag:Remove() end
        end
        ESP._Objects = {}
        print("👁️ ESP 已關閉")
    end
    UpdateUI()
end

local function UpdateESP()
    if not ESP.Enabled or not Drawing then return end

    for _, Obj in ipairs(ESP._Objects) do
        local TargetChar = Obj.Player.Character
        if TargetChar and TargetChar:FindFirstChild("HumanoidRootPart") then
            local Root = TargetChar.HumanoidRootPart
            local Pos, OnScreen = Camera:WorldToScreenPoint(Root.Position + Vector3.new(0, 2, 0))
            local FootPos = Camera:WorldToScreenPoint(Root.Position - Vector3.new(0, 2, 0))

            if OnScreen then
                local Height = FootPos.Y - Pos.Y
                local Width = Height * 0.5
                local Box = Obj.Box
                if Box then
                    Box.Size = Vector2.new(Width, Height)
                    Box.Position = Vector2.new(Pos.X - Width/2, Pos.Y)
                    Box.Visible = true
                end

                local NameTag = Obj.NameTag
                if NameTag then
                    NameTag.Text = Obj.Player.Name
                    NameTag.Position = Vector2.new(Pos.X, Pos.Y - 20)
                    NameTag.Visible = true
                end
            else
                if Obj.Box then Obj.Box.Visible = false end
                if Obj.NameTag then Obj.NameTag.Visible = false end
            end
        else
            if Obj.Box then Obj.Box.Visible = false end
            if Obj.NameTag then Obj.NameTag.Visible = false end
        end
    end
end

RunService.RenderStepped:Connect(UpdateESP)

Players.PlayerAdded:Connect(function(NewPlayer)
    if ESP.Enabled and NewPlayer ~= LocalPlayer then
        local obj = CreateESPBox(NewPlayer)
        if obj then
            table.insert(ESP._Objects, obj)
        end
    end
end)

-- ==========================================
-- 3. 鎖頭模組 (Aimbot)
-- ==========================================
local Aimbot = {}
Aimbot.Enabled = false
Aimbot.ToggleKey = Enum.KeyCode.Q

local SETTINGS = {
    MaxDistance = 250,
    TargetPart = "Head",
    Smoothness = 0.3,
    FOV = 120,
    TeamCheck = true,
    VisibleCheck = false,
}

local Target = nil
local TargetPos = nil

local function GetClosestEnemy()
    local Character = LocalPlayer.Character
    if not Character then return nil, nil end

    local RootPart = Character:FindFirstChild("HumanoidRootPart")
    if not RootPart then return nil, nil end

    local CameraPos = Camera.CFrame.Position
    local CameraLook = Camera.CFrame.LookVector

    local BestTarget = nil
    local BestDistance = SETTINGS.MaxDistance
    local BestPos = nil

    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            if SETTINGS.TeamCheck and Player.Team == LocalPlayer.Team then
                continue
            end

            local TargetChar = Player.Character
            if not TargetChar then continue end

            local Humanoid = TargetChar:FindFirstChild("Humanoid")
            if not Humanoid or Humanoid.Health <= 0 then continue end

            local TargetPart = TargetChar:FindFirstChild(SETTINGS.TargetPart) or
                               TargetChar:FindFirstChild("UpperTorso") or
                               TargetChar:FindFirstChild("HumanoidRootPart")
            if not TargetPart then continue end

            local Pos = TargetPart.Position
            local Distance = (RootPart.Position - Pos).Magnitude

            if Distance > SETTINGS.MaxDistance then continue end

            if SETTINGS.VisibleCheck then
                local Ray = Ray.new(CameraPos, (Pos - CameraPos).Unit * Distance)
                local Hit = workspace:FindPartOnRay(Ray, Character)
                if Hit and not Hit:IsDescendantOf(TargetChar) then
                    continue
                end
            end

            local Direction = (Pos - CameraPos).Unit
            local Angle = math.deg(math.acos(CameraLook:Dot(Direction)))
            if Angle > SETTINGS.FOV / 2 then
                continue
            end

            if Distance < BestDistance then
                BestDistance = Distance
                BestTarget = TargetChar
                BestPos = Pos
            end
        end
    end

    return BestTarget, BestPos
end

local function SmoothAim(TargetPos)
    if not TargetPos then return end

    local CurrentCF = Camera.CFrame
    local TargetCF = CFrame.new(CurrentCF.Position, TargetPos)
    Camera.CFrame = CurrentCF:Lerp(TargetCF, SETTINGS.Smoothness)
end

function Aimbot.Toggle()
    Aimbot.Enabled = not Aimbot.Enabled
    if Aimbot.Enabled then
        print("🔒 鎖頭已開啟")
    else
        print("🔓 鎖頭已關閉")
        Target = nil
        TargetPos = nil
    end
    UpdateUI()
end

RunService.RenderStepped:Connect(function()
    if not Aimbot.Enabled then
        Target = nil
        TargetPos = nil
        return
    end

    local TargetChar, Pos = GetClosestEnemy()
    if TargetChar and Pos then
        Target = TargetChar
        TargetPos = Pos
    else
        Target = nil
        TargetPos = nil
        return
    end

    SmoothAim(TargetPos)
end)

LocalPlayer.CharacterAdded:Connect(function()
    Target = nil
    TargetPos = nil
end)

-- ==========================================
-- 4. UI 介面 (繁體中文)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "三合一Hub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 240, 0, 200)
Frame.Position = UDim2.new(0.5, -120, 0.3, 0)
Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
Frame.BackgroundTransparency = 0.1
Frame.BorderColor3 = Color3.fromRGB(100, 200, 255)
Frame.BorderSizePixel = 2
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
Title.Text = "🎯 三合一 Hub"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.Parent = Frame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0.9, 0, 0, 22)
StatusLabel.Position = UDim2.new(0.05, 0, 0.22, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "F:飛行 | E:ESP | Q:鎖頭"
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 13
StatusLabel.Parent = Frame

-- 更新 UI 按鈕狀態
local function UpdateUI()
    FlyBtn.Text = Fly.Enabled and "🟢 飛行: 開" or "⚫ 飛行: 關"
    FlyBtn.BackgroundColor3 = Fly.Enabled and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(60, 60, 90)
    
    ESPBtn.Text = ESP.Enabled and "🟢 ESP: 開" or "⚫ ESP: 關"
    ESPBtn.BackgroundColor3 = ESP.Enabled and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(60, 60, 90)
    
    AimbotBtn.Text = Aimbot.Enabled and "🟢 鎖頭: 開" or "⚫ 鎖頭: 關"
    AimbotBtn.BackgroundColor3 = Aimbot.Enabled and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(60, 60, 90)
end

-- 飛行按鈕
local FlyBtn = Instance.new("TextButton")
FlyBtn.Size = UDim2.new(0.28, 0, 0.22, 0)
FlyBtn.Position = UDim2.new(0.05, 0, 0.40, 0)
FlyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
FlyBtn.Text = "⚫ 飛行: 關"
FlyBtn.TextColor3 = Color3.new(1, 1, 1)
FlyBtn.Font = Enum.Font.GothamBold
FlyBtn.TextSize = 13
FlyBtn.Parent = Frame

FlyBtn.MouseButton1Click:Connect(function()
    Fly.Toggle()
end)

-- ESP 按鈕
local ESPBtn = Instance.new("TextButton")
ESPBtn.Size = UDim2.new(0.28, 0, 0.22, 0)
ESPBtn.Position = UDim2.new(0.36, 0, 0.40, 0)
ESPBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
ESPBtn.Text = "⚫ ESP: 關"
ESPBtn.TextColor3 = Color3.new(1, 1, 1)
ESPBtn.Font = Enum.Font.GothamBold
ESPBtn.TextSize = 13
ESPBtn.Parent = Frame

ESPBtn.MouseButton1Click:Connect(function()
    ESP.Toggle()
end)

-- 鎖頭按鈕
local AimbotBtn = Instance.new("TextButton")
AimbotBtn.Size = UDim2.new(0.28, 0, 0.22, 0)
AimbotBtn.Position = UDim2.new(0.67, 0, 0.40, 0)
AimbotBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
AimbotBtn.Text = "⚫ 鎖頭: 關"
AimbotBtn.TextColor3 = Color3.new(1, 1, 1)
AimbotBtn.Font = Enum.Font.GothamBold
AimbotBtn.TextSize = 13
AimbotBtn.Parent = Frame

AimbotBtn.MouseButton1Click:Connect(function()
    Aimbot.Toggle()
end)

-- 快捷鍵提示
local HintLabel = Instance.new("TextLabel")
HintLabel.Size = UDim2.new(0.9, 0, 0, 20)
HintLabel.Position = UDim2.new(0.05, 0, 0.68, 0)
HintLabel.BackgroundTransparency = 1
HintLabel.Text = "快捷鍵: F | E | Q"
HintLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
HintLabel.Font = Enum.Font.Gotham
HintLabel.TextSize = 12
HintLabel.Parent = Frame

-- 關閉按鈕
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 25)
CloseBtn.Position = UDim2.new(1, -35, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.Parent = Frame

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    print("🔚 三合一 Hub 已關閉")
end)

-- 初始化 UI 狀態
UpdateUI()

-- ==========================================
-- 5. 快捷鍵綁定 (統一管理)
-- ==========================================
UserInputService.InputBegan:Connect(function(Input, GameProcessed)
    if GameProcessed then return end
    
    if Input.KeyCode == Fly.ToggleKey then
        Fly.Toggle()
    elseif Input.KeyCode == ESP.ToggleKey then
        ESP.Toggle()
    elseif Input.KeyCode == Aimbot.ToggleKey then
        Aimbot.Toggle()
    end
end)

-- ==========================================
-- 6. 載入完成訊息
-- ==========================================
print("✅ 三合一 Hub 已載入！")
print("   F: 開關飛行")
print("   E: 開關 ESP")
print("   Q: 開關鎖頭")