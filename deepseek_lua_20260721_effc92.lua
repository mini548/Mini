-- ==========================================
-- 飛行模組 (Fly)
-- 功能：按下 F 鍵開關飛行，WASD 控制方向，空白鍵上升，Shift 下降
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
    local Player = game.Players.LocalPlayer
    local Character = Player.Character
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
end

local function UpdateFlight()
    if not Fly.Enabled or not Fly._Parts then return end

    local Player = game.Players.LocalPlayer
    local Character = Player.Character
    if not Character then return end

    local Root = Character:FindFirstChild("HumanoidRootPart")
    if not Root then return end

    local UIS = game:GetService("UserInputService")
    local Speed = Fly.Speed

    local MoveVec = Vector3.new(0, 0, 0)
    local Forward = Root.CFrame.LookVector
    local Right = Root.CFrame.RightVector

    if UIS:IsKeyDown(Enum.KeyCode.W) then MoveVec = MoveVec + Forward end
    if UIS:IsKeyDown(Enum.KeyCode.S) then MoveVec = MoveVec - Forward end
    if UIS:IsKeyDown(Enum.KeyCode.A) then MoveVec = MoveVec - Right end
    if UIS:IsKeyDown(Enum.KeyCode.D) then MoveVec = MoveVec + Right end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then MoveVec = MoveVec + Vector3.new(0, 1, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then MoveVec = MoveVec - Vector3.new(0, 1, 0) end

    if MoveVec.Magnitude > 0 then
        Fly._Parts.BV.Velocity = MoveVec.Unit * Speed
    else
        Fly._Parts.BV.Velocity = Vector3.new(0, 0, 0)
    end

    Fly._Parts.BG.CFrame = Root.CFrame
end

game:GetService("RunService").RenderStepped:Connect(UpdateFlight)

game:GetService("UserInputService").InputBegan:Connect(function(Input, GP)
    if GP then return end
    if Input.KeyCode == Fly.ToggleKey then
        Fly.Toggle()
    end
end)

return Fly