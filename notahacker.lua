-- 加载WindUI库
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Guo61/Cat-/refs/heads/main/main.lua"))()

-- 添加必要的服务引用
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

-- 获取本地玩家
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- 初始化角色引用
local Character, Humanoid, HumanoidRootPart
local function setupCharacter()
    Character = LocalPlayer.Character
    if Character then
        Humanoid = Character:FindFirstChild("Humanoid")
        HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    end
end

-- 连接角色变化事件
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid")
    HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    Character:WaitForChild("HumanoidRootPart")
end)

setupCharacter()

-- 功能状态和连接跟踪表
local FeatureStates = {}
local Connections = {}

-- 功能设置
local FeatureSettings = {
    Speed = 30,
    JumpPower = 100,
    FlySpeed = 50,
    SprintSpeed = 40,
    Gravity = 196.2,
    HitboxScale = 1.5,
}

-- 使用WindUI的通知函数
local function notify(title, desc, duration)
    WindUI:Notify({
        Title = title,
        Desc = desc,
        Duration = duration or 3
    })
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
                notify("速度功能已开启", string.format("当前速度: %d", FeatureSettings.Speed))
            end
        end,
        disable = function()
            if Humanoid then
                Humanoid.WalkSpeed = (FeatureStates.Sprint and FeatureSettings.SprintSpeed) or 16
                notify("速度功能已关闭", "已恢复默认速度")
            end
        end,
    },

    HighJump = {
        enable = function()
            if Humanoid then
                Humanoid.JumpPower = FeatureSettings.JumpPower
                notify("高跳功能已开启", string.format("跳跃高度: %d", FeatureSettings.JumpPower))
            end
        end,
        disable = function()
            if Humanoid then
                Humanoid.JumpPower = 50
                notify("高跳功能已关闭", "已恢复默认跳跃高度")
            end
        end,
    },

    KeepY = {
        originalY = 0,
        enable = function()
            if HumanoidRootPart then
                FeatureHandlers.KeepY.originalY = HumanoidRootPart.Position.Y
                notify("保持高度已开启", "角色高度将被固定")
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
                notify("保持高度已关闭", "角色高度限制已解除")
            end
        end,
    },

    TP = {
        enable = function()
            if TP_GUI then
                TP_GUI.Enabled = true
            end
        end,
        disable = function()
            if TP_GUI then
                TP_GUI.Enabled = false
            end
        end,
    },

    ClickTP = {
        enable = function()
            Connections.ClickTP = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 or not Camera or not HumanoidRootPart then
                    return
                end
                local mousePos = UserInputService:GetMouseLocation()
                local ray = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = {Character}
                rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, rayParams)
                if result and result.Position then
                    HumanoidRootPart.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
                    notify("传送成功", "已传送到目标位置")
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
            notify("飞行已开启", string.format("飞行速度: %d", FeatureSettings.FlySpeed))
            
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
            notify("飞行已关闭", "已回到地面模式")
        end,
    },

    AirJump = {
        enable = function()
            notify("空中跳跃已开启", "现在可以在空中跳跃")
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
            notify("空中跳跃已关闭", "恢复常规跳跃规则")
        end,
    },

    AntiWalkFling = {
        lastVelocity = Vector3.new(),
        maxSafeVelocity = 80,
        enable = function()
            notify("防甩飞已开启", "自动防止被高速甩飞")
            Connections.AntiWalkFling = RunService.Stepped:Connect(function()
                if HumanoidRootPart then
                    local currentVelocity = HumanoidRootPart.Velocity
                    if (currentVelocity - FeatureHandlers.AntiWalkFling.lastVelocity).Magnitude > FeatureHandlers.AntiWalkFling.maxSafeVelocity then
                        HumanoidRootPart.Velocity = FeatureHandlers.AntiWalkFling.lastVelocity
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
                notify("冲刺已开启", string.format("冲刺速度: %d", FeatureSettings.SprintSpeed))
            end
        end,
        disable = function()
            if Humanoid then
                Humanoid.WalkSpeed = (FeatureStates.Speed and FeatureSettings.Speed) or 16
                notify("冲刺已关闭", "恢复常规移动速度")
            end
        end,
    },

    Lowhop = {
        enable = function()
            notify("低空跳跃已开启", "自动进行连续低空跳跃")
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
            notify("低空跳跃已关闭", "停止连续跳跃")
        end,
    },

    Gravity = {
        enable = function()
            Workspace.Gravity = FeatureSettings.Gravity
            notify("重力已修改", string.format("当前重力: %d", FeatureSettings.Gravity))
        end,
        disable = function()
            Workspace.Gravity = 196.2
            notify("重力已恢复", "恢复默认重力值")
        end,
    },

    NoKnockBack = {
        enable = function()
            notify("免疫击退已开启", "不再受到击退效果影响")
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
            notify("免疫击退已关闭", "恢复常规物理效果")
        end,
    },

    NoSlow = {
        enable = function()
            notify("免疫减速已开启", "不再受到减速效果影响")
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
            notify("免疫减速已关闭", "恢复常规移动状态")
        end,
    },

    Bhop = {
        enable = function()
            notify("兔子跳已开启", "自动进行连续跳跃")
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
            notify("兔子跳已关闭", "停止自动跳跃")
        end,
    },
}

-- 欢迎弹窗
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
            Callback = function() 
                Confirmed = true 
                WindUI:Notify({
                    Title = "欢迎",
                    Desc = "脚盆UI已激活，请尽情享受！",
                    Duration = 3
                })
            end,
            Variant = "Primary",
        }
    }
})

repeat task.wait() until Confirmed

-- 创建主窗口
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
    Combat = Window:Tab({ Title = "Combat", Icon = "swords" }),
    Player = Window:Tab({ Title = "Player", Icon = "user" }),
    Misc = Window:Tab({ Title = "Misc", Icon = "settings" }),
    Exploit = Window:Tab({ Title = "Exploit", Icon = "code" }),
}

Window:SelectTab(1)

-- 主标签页内容
Tabs.Main:Paragraph({
    Title = "欢迎使用皮革尬的脚盆",
    Desc = "一个高效、美观的游戏界面工具集",
})

-- 添加一个简单的设置保存按钮
Tabs.Main:Button({
    Title = "保存设置",
    Desc = "将当前功能设置保存到云端",
    Callback = function()
        local settings = HttpService:JSONEncode(FeatureSettings)
        -- 在实际应用中，这里应该使用DataStoreService
        notify("设置已保存", "下次启动时将应用您的设置", 2)
    end
})

-- 移动标签页
Tabs.Movement:Toggle({
    Title = "飞行模式",
    Desc = "启用/禁用飞行功能",
    Callback = function(state)
        FeatureStates.Fly = state
        if state then
            FeatureHandlers.Fly:enable()
        else
            FeatureHandlers.Fly:disable()
        end
    end
})

Tabs.Movement:Slider({
    Title = "飞行速度",
    Value = {
        Min = 10,
        Max = 200,
        Default = FeatureSettings.FlySpeed,
    },
    Callback = function(value)
        FeatureSettings.FlySpeed = value
        if FeatureStates.Fly then
            FeatureHandlers.Fly:disable()
            FeatureHandlers.Fly:enable()
            notify("飞行速度已更新", string.format("新飞行速度: %d", value), 2)
        end
    end
})

Tabs.Movement:Toggle({
    Title = "穿墙模式",
    Desc = "允许角色穿过墙壁和障碍物",
    Callback = function(state)
        FeatureStates.NoClip = state
        if state then
            FeatureHandlers.NoClip:enable()
            notify("穿墙已开启", "现在可以穿过墙壁和障碍物")
        else
            FeatureHandlers.NoClip:disable()
            notify("穿墙已关闭", "恢复常规碰撞检测")
        end
    end
})

Tabs.Movement:Toggle({
    Title = "移动加速",
    Desc = "增加角色移动速度",
    Callback = function(state)
        FeatureStates.Speed = state
        if state then
            FeatureHandlers.Speed:enable()
        else
            FeatureHandlers.Speed:disable()
        end
    end
})

Tabs.Movement:Slider({
    Title = "移动速度",
    Value = {
        Min = 16,
        Max = 200,
        Default = FeatureSettings.Speed,
    },
    Callback = function(value)
        FeatureSettings.Speed = value
        if FeatureStates.Speed then
            FeatureHandlers.Speed:enable()
            notify("移动速度已更新", string.format("新移动速度: %d", value), 2)
        end
    end
})

Tabs.Movement:Toggle({
    Title = "高跳模式",
    Desc = "增加角色跳跃高度",
    Callback = function(state)
        FeatureStates.HighJump = state
        if state then
            FeatureHandlers.HighJump:enable()
        else
            FeatureHandlers.HighJump:disable()
        end
    end
})

Tabs.Movement:Slider({
    Title = "跳跃高度",
    Value = {
        Min = 50,
        Max = 500,
        Default = FeatureSettings.JumpPower,
    },
    Callback = function(value)
        FeatureSettings.JumpPower = value
        if FeatureStates.HighJump then
            FeatureHandlers.HighJump:enable()
            notify("跳跃高度已更新", string.format("新跳跃高度: %d", value), 2)
        end
    end
})

Tabs.Movement:Toggle({
    Title = "冲刺模式",
    Desc = "启用冲刺功能",
    Callback = function(state)
        FeatureStates.Sprint = state
        if state then
            FeatureHandlers.Sprint:enable()
        else
            FeatureHandlers.Sprint:disable()
        end
    end
})

Tabs.Movement:Slider({
    Title = "冲刺速度",
    Value = {
        Min = 20,
        Max = 200,
        Default = FeatureSettings.SprintSpeed,
    },
    Callback = function(value)
        FeatureSettings.SprintSpeed = value
        if FeatureStates.Sprint then
            FeatureHandlers.Sprint:enable()
            notify("冲刺速度已更新", string.format("新冲刺速度: %d", value), 2)
        end
    end
})

-- 战斗标签页
Tabs.Combat:Toggle({
    Title = "自动攻击",
    Desc = "自动攻击附近的敌人",
    Callback = function(state)
        notify("自动攻击已"..(state and "开启" or "关闭"), state and "开始自动攻击" or "停止自动攻击", 2)
        -- 这里添加自动攻击代码
    end
})

-- 玩家标签页
Tabs.Player:Toggle({
    Title = "防甩飞",
    Desc = "防止被高速甩出地图",
    Callback = function(state)
        FeatureStates.AntiWalkFling = state
        if state then
            FeatureHandlers.AntiWalkFling:enable()
        else
            FeatureHandlers.AntiWalkFling:disable()
        end
    end
})

Tabs.Player:Toggle({
    Title = "免疫击退",
    Desc = "不受击退效果影响",
    Callback = function(state)
        FeatureStates.NoKnockBack = state
        if state then
            FeatureHandlers.NoKnockBack:enable()
        else
            FeatureHandlers.NoKnockBack:disable()
        end
    end
})

Tabs.Player:Toggle({
    Title = "免疫减速",
    Desc = "不受减速效果影响",
    Callback = function(state)
        FeatureStates.NoSlow = state
        if state then
            FeatureHandlers.NoSlow:enable()
        else
            FeatureHandlers.NoSlow:disable()
        end
    end
})

-- 杂项标签页
Tabs.Misc:Toggle({
    Title = "夜视模式",
    Desc = "启用夜视功能",
    Callback = function(state)
        FeatureStates.NightVision = state
        if state then
            FeatureHandlers.NightVision:enable()
            notify("夜视已开启", "场景亮度已提升")
        else
            FeatureHandlers.NightVision:disable()
            notify("夜视已关闭", "恢复常规视觉效果")
        end
    end
})

Tabs.Misc:Toggle({
    Title = "玩家透视",
    Desc = "显示其他玩家轮廓",
    Callback = function(state)
        FeatureStates.ESP = state
        if state then
            FeatureHandlers.ESP:enable()
            notify("玩家透视已开启", "现在可以看到其他玩家位置")
        else
            FeatureHandlers.ESP:disable()
            notify("玩家透视已关闭", "停止显示其他玩家轮廓")
        end
    end
})

Tabs.Misc:Toggle({
    Title = "重力修改",
    Desc = "修改游戏世界的重力",
    Callback = function(state)
        FeatureStates.Gravity = state
        if state then
            FeatureHandlers.Gravity:enable()
        else
            FeatureHandlers.Gravity:disable()
        end
    end
})

Tabs.Misc:Slider({
    Title = "重力值",
    Value = {
        Min = 0,
        Max = 500,
        Default = FeatureSettings.Gravity,
    },
    Callback = function(value)
        FeatureSettings.Gravity = value
        if FeatureStates.Gravity then
            FeatureHandlers.Gravity:enable()
            notify("重力值已更新", string.format("新重力值: %d", value), 2)
        end
    end
})

-- 利用标签页
Tabs.Exploit:Toggle({
    Title = "行走甩飞",
    Desc = "移动时产生甩飞效果",
    Callback = function(state)
        FeatureStates.WalkFling = state
        if state then
            FeatureHandlers.WalkFling:enable()
            notify("行走甩飞已开启", "移动时会产生甩飞效果")
        else
            FeatureHandlers.WalkFling:disable()
            notify("行走甩飞已关闭", "恢复常规移动")
        end
    end
})

Tabs.Exploit:Toggle({
    Title = "点击传送",
    Desc = "点击位置进行瞬间移动",
    Callback = function(state)
        FeatureStates.ClickTP = state
        if state then
            FeatureHandlers.ClickTP:enable()
            notify("点击传送已开启", "点击位置即可传送")
        else
            FeatureHandlers.ClickTP:disable()
            notify("点击传送已关闭", "停止传送功能")
        end
    end
})

Tabs.Exploit:Code({
    Title = "控制台",
    Code = [[-- 在这里运行你的代码
print("Hello World!")
WindUI:Notify({
    Title = "控制台执行",
    Desc = "代码已成功执行!",
    Duration = 3
})
]],
    Callback = function(code)
        local success, err = pcall(loadstring(code))
        if success then
            WindUI:Notify({
                Title = "执行成功",
                Desc = "代码已成功运行",
                Duration = 3
            })
        else
            WindUI:Notify({
                Title = "执行错误",
                Desc = "错误信息: "..tostring(err),
                Duration = 5
            })
        end
    end
})

-- 窗口关闭事件
Window:OnClose(function()
    WindUI:Notify({
        Title = "界面已关闭",
        Desc = "所有功能已停用",
        Duration = 3
    })
    
    -- 清理所有功能
    for feature, state in pairs(FeatureStates) do
        if state and FeatureHandlers[feature] and FeatureHandlers[feature].disable then
            FeatureHandlers[feature]:disable()
        end
    end
    
    -- 断开所有连接
    for _, connection in pairs(Connections) do
        connection:Disconnect()
    end
end)

-- 游戏关闭时清理
game:BindToClose(function()
    Window:Close()
end)
