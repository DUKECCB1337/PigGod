local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Guo61/Cat-/refs/heads/main/main.lua"))()

-- 获取必要的服务
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

-- 初始化变量
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- 监听角色变化
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid")
    HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
end)

-- 用于存储连接和状态的表
local Connections = {}
local FeatureStates = {}
local FeatureSettings = {
    Speed = 50,
    JumpPower = 100,
    FlySpeed = 50,
    SprintSpeed = 30,
    Gravity = 50,
}

-- 通知函数
local function notify(msg, duration)
    -- 这里可以替换为WindUI的提示或者使用自己的提示方式
    print(msg)
end

-- 功能处理器
local FeatureHandlers = {
    NoClip = {
        enable = function()
            Connections.NoClip = RunService.Stepped:Connect(function()
                if Character then
                    for _, part in ipairs(Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        end,
        disable = function()
            if Connections.NoClip then
                Connections.NoClip:Disconnect()
                Connections.NoClip = nil
            end
            if Character then
                for _, part in ipairs(Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end,
    },

    NightVision = {
        originalLighting = {},
        enable = function()
            local handler = FeatureHandlers.NightVision
            handler.originalLighting = {
                Brightness = Lighting.Brightness,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                FogEnd = Lighting.FogEnd,
            }
            Lighting.Brightness = 1.5
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            Lighting.FogEnd = 0
        end,
        disable = function()
            local handler = FeatureHandlers.NightVision
            if handler.originalLighting.Brightness then
                Lighting.Brightness = handler.originalLighting.Brightness
            end
            if handler.originalLighting.Ambient then
                Lighting.Ambient = handler.originalLighting.Ambient
            end
            if handler.originalLighting.OutdoorAmbient then
                Lighting.OutdoorAmbient = handler.originalLighting.OutdoorAmbient
            end
            Lighting.FogEnd = handler.originalLighting.FogEnd or 100000
        end,
    },

    ESP = {
        enable = function()
            Connections.ESP = RunService.RenderStepped:Connect(function()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.Character and not plr.Character:FindFirstChild("ESP_Highlight") then
                        local highlight = Instance.new("Highlight")
                        highlight.Name = "ESP_Highlight"
                        highlight.FillColor = Color3.fromRGB(200, 20, 20)
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.OutlineTransparency = 0
                        highlight.FillTransparency = 0.5
                        highlight.Enabled = true
                        highlight.Parent = plr.Character
                    end
                end
            end)
        end,
        disable = function()
            if Connections.ESP then
                Connections.ESP:Disconnect()
                Connections.ESP = nil
            end
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("Highlight") and obj.Name == "ESP_Highlight" then
                    obj:Destroy()
                end
            end
        end,
    },

    WalkFling = {
        enable = function()
            Connections.WalkFling = RunService.Stepped:Connect(function()
                if Humanoid and HumanoidRootPart and Humanoid.MoveDirection.Magnitude > 0 then
                    local force = Humanoid.MoveDirection * 1000000 + Vector3.new(0, 1000000, 0)
                    local bodyForce = Instance.new("BodyForce")
                    bodyForce.Force = force
                    bodyForce.Parent = HumanoidRootPart
                    task.delay(0.1, function()
                        if bodyForce and bodyForce.Parent then
                            bodyForce:Destroy()
                        end
                    end)
                end
            end)
        end,
        disable = function()
            if Connections.WalkFling then
                Connections.WalkFling:Disconnect()
                Connections.WalkFling = nil
            end
        end,
    },

    WallClimb = {
        enable = function()
            Connections.WallClimb = RunService.Stepped:Connect(function()
                if Humanoid and HumanoidRootPart then
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterDescendantsInstances = {Character}
                    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                    local origin = HumanoidRootPart.Position
                    local direction = HumanoidRootPart.CFrame.LookVector * 2
                    local raycastResult = Workspace:Raycast(origin, direction, raycastParams)
                    if raycastResult and Humanoid.MoveDirection.Magnitude > 0 then
                        Humanoid.Jump = true
                    end
                end
            end)
        end,
        disable = function()
            if Connections.WallClimb then
                Connections.WallClimb:Disconnect()
                Connections.WallClimb = nil
            end
        end,
    },

    Speed = {
        enable = function()
            if Humanoid then
                Humanoid.WalkSpeed = FeatureSettings.Speed
            end
        end,
        disable = function()
            if Humanoid then
                Humanoid.WalkSpeed = (FeatureStates.Sprint and FeatureSettings.SprintSpeed) or 16
            end
        end,
    },

    HighJump = {
        enable = function()
            if Humanoid then
                Humanoid.JumpPower = FeatureSettings.JumpPower
            end
        end,
        disable = function()
            if Humanoid then
                Humanoid.JumpPower = 50
            end
        end,
    },

    KeepY = {
        originalY = 0,
        enable = function()
            if HumanoidRootPart then
                FeatureHandlers.KeepY.originalY = HumanoidRootPart.Position.Y
            end
            Connections.KeepY = RunService.Stepped:Connect(function()
                if HumanoidRootPart then
                    local pos = HumanoidRootPart.Position
                    HumanoidRootPart.CFrame = CFrame.new(pos.X, FeatureHandlers.KeepY.originalY, pos.Z)
                end
            end)
        end,
        disable = function()
            if Connections.KeepY then
                Connections.KeepY:Disconnect()
                Connections.KeepY = nil
            end
        end,
    },

    TP = {
        enable = function()
            -- 这里可以添加TP GUI的创建代码
            notify("TP功能已启用，但需要GUI实现", 2)
        end,
        disable = function()
            -- 这里可以添加TP GUI的销毁代码
            notify("TP功能已禁用", 2)
        end,
    },

    ClickTP = {
        enable = function()
            Connections.ClickTP = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 or not Camera or not HumanoidRootPart then
                    return
                end
                local mouseX, mouseY = UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y
                local ray = Camera:ViewportPointToRay(mouseX, mouseY)
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = {Character}
                rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, rayParams)
                if result and result.Position then
                    HumanoidRootPart.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
                end
            end)
        end,
        disable = function()
            if Connections.ClickTP then
                Connections.ClickTP:Disconnect()
                Connections.ClickTP = nil
            end
        end,
    },

    Fly = {
        enable = function()
            if not Humanoid or not HumanoidRootPart then return end
            Humanoid.PlatformStand = true
            Connections.Fly = RunService.Stepped:Connect(function()
                if HumanoidRootPart and Humanoid then
                    local moveDirection = Humanoid.MoveDirection
                    local flyVelocity = Vector3.new(0, 0, 0)
                    if moveDirection.Magnitude > 0 then
                        flyVelocity = HumanoidRootPart.CFrame.LookVector * moveDirection.Z * FeatureSettings.FlySpeed +
                            HumanoidRootPart.CFrame.RightVector * moveDirection.X * FeatureSettings.FlySpeed
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                        flyVelocity = flyVelocity + Vector3.new(0, FeatureSettings.FlySpeed, 0)
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                        flyVelocity = flyVelocity - Vector3.new(0, FeatureSettings.FlySpeed, 0)
                    end
                    HumanoidRootPart.CFrame = HumanoidRootPart.CFrame + flyVelocity * (1/60)
                end
            end)
        end,
        disable = function()
            if Connections.Fly then
                Connections.Fly:Disconnect()
                Connections.Fly = nil
            end
            if Humanoid then
                Humanoid.PlatformStand = false
                pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
            end
        end,
    },

    AirJump = {
        enable = function()
            Connections.AirJump = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then return end
                if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
                    if Humanoid and Humanoid.FloorMaterial == Enum.Material.Air then
                        Humanoid.Jump = true
                    end
                end
            end)
        end,
        disable = function()
            if Connections.AirJump then
                Connections.AirJump:Disconnect()
                Connections.AirJump = nil
            end
        end,
    },

    AntiWalkFling = {
        lastVelocity = Vector3.new(),
        maxSafeVelocity = 80,
        enable = function()
            Connections.AntiWalkFling = RunService.Stepped:Connect(function()
                if HumanoidRootPart then
                    local currentVelocity = HumanoidRootPart.Velocity
                    if (currentVelocity - FeatureHandlers.AntiWalkFling.lastVelocity).Magnitude > FeatureHandlers.AntiWalkFling.maxSafeVelocity then
                        HumanoidRootPart.Velocity = FeatureHandlers.AntiWalkFling.lastVelocity
                        notify("防甩飞已启动！", 1)
                    end
                    FeatureHandlers.AntiWalkFling.lastVelocity = currentVelocity
                end
            end)
        end,
        disable = function()
            if Connections.AntiWalkFling then
                Connections.AntiWalkFling:Disconnect()
                Connections.AntiWalkFling = nil
            end
        end,
    },

    Sprint = {
        enable = function()
            if Humanoid then
                Humanoid.WalkSpeed = FeatureSettings.SprintSpeed
            end
        end,
        disable = function()
            if Humanoid then
                Humanoid.WalkSpeed = (FeatureStates.Speed and FeatureSettings.Speed) or 16
            end
        end,
    },

    Lowhop = {
        enable = function()
            Connections.Lowhop = RunService.Heartbeat:Connect(function()
                if Humanoid and HumanoidRootPart then
                    if Humanoid.FloorMaterial ~= Enum.Material.Air then
                        Humanoid.Jump = true
                        HumanoidRootPart.Velocity = HumanoidRootPart.CFrame.LookVector * (Humanoid.WalkSpeed * 1.025) + Vector3.new(0, HumanoidRootPart.Velocity.Y, 0)
                    end
                end
            end)
        end,
        disable = function()
            if Connections.Lowhop then
                Connections.Lowhop:Disconnect()
                Connections.Lowhop = nil
            end
        end,
    },

    Gravity = {
        enable = function()
            Workspace.Gravity = FeatureSettings.Gravity
        end,
        disable = function()
            Workspace.Gravity = 196.2
        end,
    },

    NoKnockBack = {
        enable = function()
            Connections.NoKnockBack = RunService.Heartbeat:Connect(function()
                if Character then
                    for _, child in ipairs(Character:GetChildren()) do
                        if child:IsA("BodyVelocity") or child:IsA("BodyForce") or child:IsA("BodyGyro") then
                            child:Destroy()
                        end
                    end
                end
            end)
        end,
        disable = function()
            if Connections.NoKnockBack then
                Connections.NoKnockBack:Disconnect()
                Connections.NoKnockBack = nil
            end
        end,
    },

    NoSlow = {
        enable = function()
            Connections.NoSlow = RunService.Heartbeat:Connect(function()
                if Humanoid and Humanoid.WalkSpeed < 16 and Humanoid.WalkSpeed > 0 then
                    Humanoid.WalkSpeed = 16
                end
            end)
        end,
        disable = function()
            if Connections.NoSlow then
                Connections.NoSlow:Disconnect()
                Connections.NoSlow = nil
            end
        end,
    },

    Bhop = {
        enable = function()
            Connections.Bhop = RunService.Heartbeat:Connect(function()
                if Humanoid and HumanoidRootPart and Humanoid.FloorMaterial ~= Enum.Material.Air then
                    Humanoid.Jump = true
                    local moveVec = Humanoid.MoveDirection * 1.05
                    HumanoidRootPart.Velocity = HumanoidRootPart.Velocity + HumanoidRootPart.CFrame.LookVector * moveVec.Z * 0.05
                end
            end)
        end,
        disable = function()
            if Connections.Bhop then
                Connections.Bhop:Disconnect()
                Connections.Bhop = nil
            end
        end,
    },
}

-- 功能类别映射
local CategoryFeatureMap = {
    Movement = {"NoClip","Speed","HighJump","KeepY","Fly","AirJump","WallClimb","Sprint","Lowhop","Bhop"},
    Visual = {"NightVision","ESP"},
    Combat = {"Hitbox"},
    Exploits = {"WalkFling","TP","ClickTP"},
    Misc = {"Gravity"},
    Player = {"AntiWalkFling","NoKnockBack","NoSlow"}
}

-- Test
local Confirmed = false

WindUI:Popup({
    Title = "皮革尬的脚盆v1.0",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Content = "欢迎使用皮革尬的脚盆。",
    Buttons = {
        {
            Title = "进入脚盆。",
            Icon = "arrow-right",
            Callback = function() Confirmed = true end,
            Variant = "Primary",
        }
    }
})

repeat task.wait() until Confirmed

--
local Window = WindUI:CreateWindow({
    Title = "PigGod UI",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Author = "PigGod",
    Folder = "MyGUI",
    Size = UDim2.fromOffset(580, 340),
    Transparent = true,
    Theme = "Dark",
    User = { Enabled = true },
    SideBarWidth = 200,
    ScrollBarEnabled = true,
})

-- 创建标签页
local Tabs = {
    Main = Window:Tab({ Title = "Main", Icon = "rbxassetid://6026568198" }),
    Movement = Window:Tab({ Title = "Movement", Icon = "rbxassetid://94462465090724" }),
    Visual = Window:Tab({ Title = "Visual", Icon = "eye" }),
    Combat = Window:Tab({ Title = "Combat", Icon = "swords" }),
    Exploits = Window:Tab({ Title = "Exploits", Icon = "code" }),
    Player = Window:Tab({ Title = "Player", Icon = "user" }),
    Misc = Window:Tab({ Title = "Misc", Icon = "settings" }),
}

Window:SelectTab(1)

-- 主页面内容
Tabs.Main:Paragraph({
    Title = "欢迎",
    Desc = "皮革尬的脚盆v1.0 - 多功能脚本",
})

-- 为每个类别添加功能
for category, features in pairs(CategoryFeatureMap) do
    for _, featureName in ipairs(features) do
        local handler = FeatureHandlers[featureName]
        if handler then
            Tabs[category]:Toggle({
                Title = featureName,
                Desc = "启用/禁用 " .. featureName,
                Callback = function(state)
                    FeatureStates[featureName] = state
                    if state then
                        handler.enable()
                    else
                        handler.disable()
                    end
                end
            })
            
            -- 为需要设置的功能添加滑块
            if featureName == "Speed" then
                Tabs[category]:Slider({
                    Title = "速度值",
                    Value = {
                        Min = 16,
                        Max = 200,
                        Default = FeatureSettings.Speed,
                    },
                    Callback = function(value)
                        FeatureSettings.Speed = value
                        if FeatureStates.Speed then
                            FeatureHandlers.Speed.disable()
                            FeatureHandlers.Speed.enable()
                        end
                    end
                })
            elseif featureName == "HighJump" then
                Tabs[category]:Slider({
                    Title = "跳跃高度",
                    Value = {
                        Min = 50,
                        Max = 500,
                        Default = FeatureSettings.JumpPower,
                    },
                    Callback = function(value)
                        FeatureSettings.JumpPower = value
                        if FeatureStates.HighJump then
                            FeatureHandlers.HighJump.disable()
                            FeatureHandlers.HighJump.enable()
                        end
                    end
                })
            elseif featureName == "Fly" then
                Tabs[category]:Slider({
                    Title = "飞行速度",
                    Value = {
                        Min = 10,
                        Max = 200,
                        Default = FeatureSettings.FlySpeed,
                    },
                    Callback = function(value)
                        FeatureSettings.FlySpeed = value
                        if FeatureStates.Fly then
                            FeatureHandlers.Fly.disable()
                            FeatureHandlers.Fly.enable()
                        end
                    end
                })
            elseif featureName == "Sprint" then
                Tabs[category]:Slider({
                    Title = "冲刺速度",
                    Value = {
                        Min = 20,
                        Max = 100,
                        Default = FeatureSettings.SprintSpeed,
                    },
                    Callback = function(value)
                        FeatureSettings.SprintSpeed = value
                        if FeatureStates.Sprint then
                            FeatureHandlers.Sprint.disable()
                            FeatureHandlers.Sprint.enable()
                        end
                    end
                })
            elseif featureName == "Gravity" then
                Tabs[category]:Slider({
                    Title = "重力值",
                    Value = {
                        Min = 0,
                        Max = 196.2,
                        Default = FeatureSettings.Gravity,
                    },
                    Callback = function(value)
                        FeatureSettings.Gravity = value
                        if FeatureStates.Gravity then
                            FeatureHandlers.Gravity.disable()
                            FeatureHandlers.Gravity.enable()
                        end
                    end
                })
            end
        else
            warn("未找到功能处理器: " .. featureName)
        end
    end
end

-- 添加其他UI元素
Tabs.Misc:Button({
    Title = "重置角色",
    Desc = "重置当前角色",
    Callback = function()
        LocalPlayer.Character:BreakJoints()
    end
})

Tabs.Misc:Input({
    Title = "消息发送",
    Placeholder = "输入要发送的消息",
    Callback = function(text)
        game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(text, "All")
    end
})

Window:OnClose(function()
    print("UI closed.")
    -- 禁用所有功能
    for featureName, state in pairs(FeatureStates) do
        if state then
            local handler = FeatureHandlers[featureName]
            if handler and handler.disable then
                handler.disable()
            end
        end
    end
end)
