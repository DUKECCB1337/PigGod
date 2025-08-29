-- 加载WindUI库
local success, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Guo61/Cat-/refs/heads/main/main.lua"))()
end)
if not success then
    warn("WindUI库加载失败：" .. tostring(WindUI))
    game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
    error("请检查WindUI链接是否有效，程序已终止")
end

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
    -- 重置LowHop相关变量
    if FeatureHandlers.LowHop then
        FeatureHandlers.LowHop.airTicks = 0
        FeatureHandlers.LowHop.shouldStrafe = false
    end
    -- 重置WalkFling相关变量
    if FeatureHandlers.WalkFling then
        FeatureHandlers.WalkFling.walkflinging = false
    end
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
    LowHopGlide = false -- LowHop滑翔开关（对应原Java的glide变量）
}

-- 使用WindUI的通知函数
local function notify(title, desc, duration)
    WindUI:Notify({
        Title = title,
        Desc = desc,
        Duration = duration or 3
    })
end

-- 辅助函数：模拟原Java的withStrafe（根据移动方向调整水平速度）
local function withStrafe(velocity, speed)
    if not Humanoid or not HumanoidRootPart then return velocity end
    local moveDir = Humanoid.MoveDirection
    if moveDir.Magnitude <= 0 then return velocity end -- 无移动时不调整
    
    -- 计算水平方向（忽略Y轴）
    local horizontalDir = CFrame.lookAt(Vector3.new(), Vector3.new(moveDir.X, 0, moveDir.Z)).LookVector
    local targetSpeed = speed or Humanoid.WalkSpeed * 1.2 -- 默认速度（可自定义）
    
    -- 应用水平速度
    return Vector3.new(
        horizontalDir.X * targetSpeed,
        velocity.Y,
        horizontalDir.Z * targetSpeed
    )
end

-- 辅助函数：模拟原Java的isGroundExempt（检测角色下方0.66单位是否有方块）
local function isGroundExempt()
    if not Character or not HumanoidRootPart then return false end
    if Humanoid.FloorMaterial ~= Enum.Material.Air then return false end -- 落地时不检测
    
    -- 射线检测：从角色中心向下0.66单位
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.IgnoreWater = true
    
    local origin = HumanoidRootPart.Position
    local direction = Vector3.new(0, -0.66, 0) -- 向下检测0.66单位
    local result = Workspace:Raycast(origin, direction, raycastParams)
    
    -- 有碰撞且Y速度<0时返回true
    return result ~= nil and HumanoidRootPart.Velocity.Y < 0
end

-- 辅助函数：模拟原Java的getStatusEffect（简化为检测是否有速度加成，可扩展）
local function getSpeedAmplifier()
    -- 此处简化：默认0，可根据Roblox游戏内Buff扩展（如检测角色是否有Speed效果）
    return 0
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

    -- 替换后的WalkFling逻辑
    WalkFling = {
        walkflinging = false,
        enable = function()
            if not Humanoid or not HumanoidRootPart or not Character then return end
            FeatureHandlers.WalkFling.walkflinging = true
            -- 添加跳跃能力
            FeatureHandlers.WalkFling.jumpConnection = UserInputService.JumpRequest:Connect(function()
                if Humanoid then
                    Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
            -- 设置碰撞和状态
            if HumanoidRootPart then
                HumanoidRootPart.CanCollide = false
            end
            if Humanoid then
                Humanoid:ChangeState(11)
            end
            -- 循环施加速度
            FeatureHandlers.WalkFling.walkFlingConnection = RunService.Heartbeat:Connect(function()
                if not FeatureHandlers.WalkFling.walkflinging or not HumanoidRootPart then return end
                local vel = HumanoidRootPart.Velocity
                HumanoidRootPart.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
                RunService.RenderStepped:Wait()
                HumanoidRootPart.Velocity = vel
                RunService.Stepped:Wait()
                HumanoidRootPart.Velocity = vel + Vector3.new(0, 0.1, 0)
            end)
            -- 角色死亡时停止
            if Humanoid then
                FeatureHandlers.WalkFling.diedConnection = Humanoid.Died:Connect(function()
                    FeatureHandlers.WalkFling.walkflinging = false
                end)
            end
            notify("行走甩飞", "已启用", 2)
        end,
        disable = function()
            FeatureHandlers.WalkFling.walkflinging = false
            if FeatureHandlers.WalkFling.jumpConnection then
                FeatureHandlers.WalkFling.jumpConnection:Disconnect()
                FeatureHandlers.WalkFling.jumpConnection = nil
            end
            if FeatureHandlers.WalkFling.walkFlingConnection then
                FeatureHandlers.WalkFling.walkFlingConnection:Disconnect()
                FeatureHandlers.WalkFling.walkFlingConnection = nil
            end
            if FeatureHandlers.WalkFling.diedConnection then
                FeatureHandlers.WalkFling.diedConnection:Disconnect()
                FeatureHandlers.WalkFling.diedConnection = nil
            end
            if HumanoidRootPart then
                HumanoidRootPart.CanCollide = true
            end
            notify("行走甩飞", "已关闭", 2)
        end,
    },

    WallClimb = {
        enable = function()
            if not Humanoid or not HumanoidRootPart then return end
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
            if not Humanoid then return end
            Humanoid.WalkSpeed = FeatureSettings.Speed
        end,
        disable = function()
            if not Humanoid then return end
            Humanoid.WalkSpeed = (FeatureStates.Sprint and FeatureSettings.SprintSpeed) or 16
        end,
    },

    HighJump = {
        enable = function()
            if not Humanoid then return end
            Humanoid.JumpPower = FeatureSettings.JumpPower
        end,
        disable = function()
            if not Humanoid then return end
            Humanoid.JumpPower = 50
        end,
    },

    KeepY = {
        originalY = 0,
        enable = function()
            if not HumanoidRootPart then return end
            FeatureHandlers.KeepY.originalY = HumanoidRootPart.Position.Y
            Connections.KeepY = RunService.Stepped:Connect(function()
                if not HumanoidRootPart then return end
                local pos = HumanoidRootPart.Position
                HumanoidRootPart.CFrame = CFrame.new(pos.X, FeatureHandlers.KeepY.originalY, pos.Z)
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
            if not Camera or not HumanoidRootPart then return end
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
                if not HumanoidRootPart or not Humanoid then return end
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
                if not HumanoidRootPart then return end
                local currentVelocity = HumanoidRootPart.Velocity
                if (currentVelocity - FeatureHandlers.AntiWalkFling.lastVelocity).Magnitude > FeatureHandlers.AntiWalkFling.maxSafeVelocity then
                    HumanoidRootPart.Velocity = FeatureHandlers.AntiWalkFling.lastVelocity
                    notify("防甩飞已启动！", 1)
                end
                FeatureHandlers.AntiWalkFling.lastVelocity = currentVelocity
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
            if not Humanoid then return end
            Humanoid.WalkSpeed = FeatureSettings.SprintSpeed
        end,
        disable = function()
            if not Humanoid then return end
            Humanoid.WalkSpeed = (FeatureStates.Speed and FeatureSettings.Speed) or 16
        end,
    },

    -- 新增：Hypixel LowHop（还原原Java逻辑）
    LowHop = {
        airTicks = 0,       -- 空中帧数（离开地面后递增，落地重置）
        shouldStrafe = false,-- 是否需要调整方向
        enable = function()
            if not Humanoid or not HumanoidRootPart then 
                notify("LowHop", "角色未加载，无法启用", 2)
                return 
            end
            
            -- 连接Heartbeat事件（每帧更新）
            Connections.LowHop = RunService.Heartbeat:Connect(function()
                if not Humanoid or not HumanoidRootPart or not Character then return end
                local velocity = HumanoidRootPart.Velocity
                local speedAmplifier = getSpeedAmplifier() -- 速度加成等级
                local glide = FeatureSettings.LowHopGlide -- 滑翔开关

                -- 重置shouldStrafe
                FeatureHandlers.LowHop.shouldStrafe = false

                -- 1. 地面状态（落地时）
                if Humanoid.FloorMaterial ~= Enum.Material.Air then
                    FeatureHandlers.LowHop.airTicks = 0 -- 重置空中帧数
                    -- 应用方向调整
                    velocity = withStrafe(velocity)
                    FeatureHandlers.LowHop.shouldStrafe = true
                else
                    -- 2. 空中状态（按airTicks分阶段处理）
                    FeatureHandlers.LowHop.airTicks += 1 -- 空中帧数递增
                    local airTicks = FeatureHandlers.LowHop.airTicks

                    -- 阶段1：空中第1帧
                    if airTicks == 1 then
                        velocity = withStrafe(velocity)
                        FeatureHandlers.LowHop.shouldStrafe = true
                        velocity = velocity + Vector3.new(0, 0.0568, 0) -- 向上加速（原Java的+0.0568）
                    end

                    -- 阶段2：空中第3帧
                    elseif airTicks == 3 then
                        velocity = Vector3.new(
                            velocity.X * 0.95,  -- X轴减速95%
                            velocity.Y - 0.13,   -- Y轴向下加速0.13
                            velocity.Z * 0.95    -- Z轴减速95%
                        )

                    -- 阶段3：空中第4帧
                    elseif airTicks == 4 then
                        velocity = velocity - Vector3.new(0, 0.2, 0) -- Y轴向下加速0.2

                    -- 阶段4：空中第7帧（滑翔逻辑）
                    elseif airTicks == 7 and glide and isGroundExempt() then
                        velocity = Vector3.new(velocity.X, 0, velocity.Z) -- Y轴速度置0（滑翔）
                    end

                    -- 3. 地面豁免检测（下方有方块时调整方向）
                    if isGroundExempt() then
                        velocity = withStrafe(velocity)
                    end

                    -- 4. 受伤时速度调整（原Java的hurtTime == 9）
                    if Humanoid.Health < Humanoid.MaxHealth then -- 简化：检测是否受伤
                        local minSpeed = 0.281 -- 最小速度（原Java的coerceAtLeast(0.281)）
                        velocity = withStrafe(velocity, math.max(velocity.Magnitude, minSpeed))
                    end

                    -- 5. 速度加成（amplifier == 2时）
                    if speedAmplifier == 2 then
                        if airTicks == 1 or airTicks == 2 or airTicks == 5 or airTicks == 6 or airTicks == 8 then
                            velocity = Vector3.new(
                                velocity.X * 1.2, -- X轴加速20%
                                velocity.Y,       -- Y轴不变
                                velocity.Z * 1.2  -- Z轴加速20%
                            )
                        end
                    end
                end

                -- 应用最终速度
                HumanoidRootPart.Velocity = velocity
            end)

            -- 6. 跳跃事件处理（原Java的jumpHandler）
            Connections.LowHopJump = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then return end
                if input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode ~= Enum.KeyCode.Space then return end
                if not Humanoid or not HumanoidRootPart then return end

                -- 跳跃时设置最小速度
                local speedAmplifier = getSpeedAmplifier()
                local minSpeed = 0.247 + 0.15 * speedAmplifier -- 原Java的0.247 + 0.15*amplifier
                local currentSpeed = HumanoidRootPart.Velocity.Magnitude
                local targetSpeed = math.max(currentSpeed, minSpeed)

                -- 应用方向和速度
                local velocity = withStrafe(HumanoidRootPart.Velocity, targetSpeed)
                HumanoidRootPart.Velocity = velocity
                FeatureHandlers.LowHop.shouldStrafe = true
            end)

            notify("LowHop", "Hypixel风格低跳已启用", 2)
        end,
        disable = function()
            -- 断开事件连接
            if Connections.LowHop then
                Connections.LowHop:Disconnect()
                Connections.LowHop = nil
            end
            if Connections.LowHopJump then
                Connections.LowHopJump:Disconnect()
                Connections.LowHopJump = nil
            end
            -- 重置变量
            FeatureHandlers.LowHop.airTicks = 0
            FeatureHandlers.LowHop.shouldStrafe = false
            notify("LowHop", "低跳已关闭", 2)
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
                if not Character then return end
                for _, child in ipairs(Character:GetChildren()) do
                    if child:IsA("BodyVelocity") or child:IsA("BodyForce") or child:IsA("BodyGyro") then
                        child:Destroy()
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
                if not Humanoid then return end
                if Humanoid.WalkSpeed < 16 and Humanoid.WalkSpeed > 0 then
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
                if not Humanoid or not HumanoidRootPart then return end
                if Humanoid.FloorMaterial ~= Enum.Material.Air then
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


-- 脚本加载时等待2秒并关闭所有功能
task.wait(2)
for feature, handler in pairs(FeatureHandlers) do
    if handler.disable then
        pcall(handler.disable)
    end
end
notify("初始化完成", "所有功能已重置", 2)

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

-- 创建主窗口（宽度140）
local Window = WindUI:CreateWindow({
    Title = "PigGod UI",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Author = "PigGod",
    Folder = "MyGUI",
    Size = UDim2.fromOffset(140, 340),
    Transparent = true,
    Theme = "Dark",
    User = { Enabled = true },
    SideBarWidth = 140,
    ScrollBarEnabled = true,
    UISizeConstraint = {
        MinSize = Vector2.new(140, 250),
        MaxSize = Vector2.new(140, 500)
    }
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

-- 主标签页内容（无图片）
Tabs.Main:Paragraph({
    Title = "欢迎使用",
    Desc = "皮革尬的脚盆",
})

-- 主标签页按钮
Tabs.Main:Button({
    Title = "保存设置",
    Desc = "将当前功能设置保存到云端",
    Callback = function()
        local settings = HttpService:JSONEncode(FeatureSettings)
        notify("设置已保存", "下次启动时将应用您的设置", 2)
    end
})

Tabs.Main:Button({
    Title = "快速开始",
    Desc = "一键启用推荐配置",
    Callback = function()
        FeatureStates.Fly = true
        FeatureHandlers.Fly:enable()
        FeatureStates.Speed = true
        FeatureHandlers.Speed:enable()
        FeatureStates.ESP = true
        FeatureHandlers.ESP:enable()
        notify("快速开始已启用", "飞行、加速和ESP功能已开启", 3)
    end
})

Tabs.Main:Button({
    Title = "重置设置",
    Desc = "恢复所有默认设置",
    Callback = function()
        for feature, state in pairs(FeatureStates) do
            if state and FeatureHandlers[feature] and FeatureHandlers[feature].disable then
                FeatureHandlers[feature]:disable()
            end
            FeatureStates[feature] = false
        end
        FeatureSettings = {
            Speed = 30,
            JumpPower = 100,
            FlySpeed = 50,
            SprintSpeed = 40,
            Gravity = 196.2,
            HitboxScale = 1.5,
            LowHopGlide = false
        }
        notify("设置已重置", "所有功能已恢复默认状态", 3)
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
    Value = { Min = 10, Max = 200, Default = FeatureSettings.FlySpeed },
    Callback = function(value)
        FeatureSettings.FlySpeed = value
        if FeatureStates.Fly then
            FeatureHandlers.Fly:disable()
            FeatureHandlers.Fly:enable()
            notify("飞行速度已更新", string.format("新速度: %d", value), 2)
        end
    end
})

Tabs.Movement:Toggle({
    Title = "穿墙模式",
    Desc = "允许穿过墙壁",
    Callback = function(state)
        FeatureStates.NoClip = state
        if state then
            FeatureHandlers.NoClip:enable()
            notify("穿墙已开启", "可穿过墙壁和障碍物")
        else
            FeatureHandlers.NoClip:disable()
            notify("穿墙已关闭", "恢复碰撞检测")
        end
    end
})

Tabs.Movement:Toggle({
    Title = "移动加速",
    Desc = "增加移动速度",
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
    Value = { Min = 16, Max = 200, Default = FeatureSettings.Speed },
    Callback = function(value)
        FeatureSettings.Speed = value
        if FeatureStates.Speed then
            FeatureHandlers.Speed:enable()
            notify("移动速度已更新", string.format("新速度: %d", value), 2)
        end
    end
})

Tabs.Movement:Toggle({
    Title = "高跳模式",
    Desc = "增加跳跃高度",
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
    Value = { Min = 50, Max = 500, Default = FeatureSettings.JumpPower },
    Callback = function(value)
        FeatureSettings.JumpPower = value
        if FeatureStates.HighJump then
            FeatureHandlers.HighJump:enable()
            notify("跳跃高度已更新", string.format("新高度: %d", value), 2)
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
    Value = { Min = 20, Max = 200, Default = FeatureSettings.SprintSpeed },
    Callback = function(value)
        FeatureSettings.SprintSpeed = value
        if FeatureStates.Sprint then
            FeatureHandlers.Sprint:enable()
            notify("冲刺速度已更新", string.format("新速度: %d", value), 2)
        end
    end
})

-- 新增：LowHop开关（Movement标签页）
Tabs.Movement:Toggle({
    Title = "LowHop（Hypixel）",
    Desc = "Hypixel风格低跳，优化移动",
    Callback = function(state)
        FeatureStates.LowHop = state
        if state then
            FeatureHandlers.LowHop:enable()
        else
            FeatureHandlers.LowHop:disable()
        end
    end
})

-- 新增：LowHop滑翔开关（对应原Java的glide变量）
Tabs.Movement:Toggle({
    Title = "LowHop滑翔",
    Desc = "开启后空中第7帧滑翔（需LowHop启用）",
    Callback = function(state)
        FeatureSettings.LowHopGlide = state
        notify("LowHop滑翔", state and "已开启" or "已关闭", 2)
    end
})

-- 新增：行走甩飞开关（替换后逻辑）
Tabs.Movement:Toggle({
    Title = "行走甩飞",
    Desc = "移动时产生甩飞效果",
    Callback = function(state)
        FeatureStates.WalkFling = state
        if state then
            FeatureHandlers.WalkFling:enable()
        else
            FeatureHandlers.WalkFling:disable()
        end
    end
})

-- 战斗标签页
Tabs.Combat:Toggle({
    Title = "自动攻击",
    Desc = "自动攻击附近敌人",
    Callback = function(state)
        notify("自动攻击已"..(state and "开启" or "关闭"), state and "开始自动攻击附近敌人" or "停止自动攻击", 2)
    end
})

Tabs.Combat:Toggle({
    Title = "无限连",
    Desc = "持续攻击目标（需手动锁定）",
    Callback = function(state)
        FeatureStates.InfiniteCombo = state
        if state then
            Connections.InfiniteCombo = RunService.Heartbeat:Connect(function()
                if not Character or not HumanoidRootPart then return end
                -- 简化逻辑：检测鼠标是否按下，按下则模拟攻击（可根据游戏攻击逻辑扩展）
                if UserInputService:IsMouseButtonDown(Enum.UserInputType.MouseButton1) then
                    -- 此处需替换为对应游戏的攻击触发代码（如激活工具、发送攻击事件等）
                    local tool = Character:FindFirstChildOfClass("Tool")
                    if tool and tool:FindFirstChild("Activate") then
                        pcall(tool.Activate, tool)
                    end
                end
            end)
            notify("无限连已开启", "按住鼠标左键持续攻击", 2)
        else
            if Connections.InfiniteCombo then
                Connections.InfiniteCombo:Disconnect()
                Connections.InfiniteCombo = nil
            end
            notify("无限连已关闭", "停止持续攻击", 2)
        end
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
    Desc = "不受攻击击退效果影响",
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
    Desc = "不受减速效果（如药水、陷阱）影响",
    Callback = function(state)
        FeatureStates.NoSlow = state
        if state then
            FeatureHandlers.NoSlow:enable()
        else
            FeatureHandlers.NoSlow:disable()
        end
    end
})

Tabs.Player:Slider({
    Title = " hitbox 缩放",
    Desc = "调整角色碰撞箱大小（1.0为默认）",
    Value = { Min = 1.0, Max = 5.0, Default = FeatureSettings.HitboxScale },
    Callback = function(value)
        FeatureSettings.HitboxScale = value
        if Character then
            for _, part in ipairs(Character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name == "HumanoidRootPart" then
                    part.Size = Vector3.new(4, 5, 4) * value -- 基于默认碰撞箱缩放
                end
            end
        end
        notify("Hitbox已更新", string.format("缩放比例: %.1f", value), 2)
    end
})

-- 杂项标签页
Tabs.Misc:Toggle({
    Title = "夜视模式",
    Desc = "提升黑暗环境亮度",
    Callback = function(state)
        FeatureStates.NightVision = state
        if state then
            FeatureHandlers.NightVision:enable()
        else
            FeatureHandlers.NightVision:disable()
        end
    end
})

Tabs.Misc:Toggle({
    Title = "玩家透视",
    Desc = "显示所有玩家轮廓（穿墙可见）",
    Callback = function(state)
        FeatureStates.ESP = state
        if state then
            FeatureHandlers.ESP:enable()
        else
            FeatureHandlers.ESP:disable()
        end
    end
})

Tabs.Misc:Toggle({
    Title = "重力修改",
    Desc = "自定义游戏世界重力",
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
    Desc = "默认重力为196.2（值越小重力越弱）",
    Value = { Min = 0, Max = 500, Default = FeatureSettings.Gravity },
    Callback = function(value)
        FeatureSettings.Gravity = value
        if FeatureStates.Gravity then
            FeatureHandlers.Gravity:enable()
            notify("重力已更新", string.format("当前重力: %d", value), 2)
        end
    end
})

Tabs.Misc:Toggle({
    Title = "空中跳跃",
    Desc = "允许在空中无限跳跃（按空格触发）",
    Callback = function(state)
        FeatureStates.AirJump = state
        if state then
            FeatureHandlers.AirJump:enable()
        else
            FeatureHandlers.AirJump:disable()
        end
    end
})

-- 利用标签页
Tabs.Exploit:Toggle({
    Title = "点击传送",
    Desc = "鼠标点击位置瞬间移动",
    Callback = function(state)
        FeatureStates.ClickTP = state
        if state then
            FeatureHandlers.ClickTP:enable()
        else
            FeatureHandlers.ClickTP:disable()
        end
    end
})

Tabs.Exploit:Toggle({
    Title = "墙壁攀爬",
    Desc = "贴近墙壁时自动向上攀爬",
    Callback = function(state)
        FeatureStates.WallClimb = state
        if state then
            FeatureHandlers.WallClimb:enable()
        else
            FeatureHandlers.WallClimb:disable()
        end
    end
})

Tabs.Exploit:Toggle({
    Title = "Y轴锁定",
    Desc = "锁定角色当前Y坐标（防止坠落/上升）",
    Callback = function(state)
        FeatureStates.KeepY = state
        if state then
            FeatureHandlers.KeepY:enable()
        else
            FeatureHandlers.KeepY:disable()
        end
    end
})

Tabs.Exploit:Code({
    Title = "代码控制台",
    Code = [[-- 在此输入并执行Lua代码
-- 示例：打印玩家位置
if LocalPlayer and LocalPlayer.Character then
    local pos = LocalPlayer.Character.HumanoidRootPart.Position
    print("当前位置: X="..pos.X..", Y="..pos.Y..", Z="..pos.Z)
    WindUI:Notify({
        Title = "位置打印",
        Desc = "已在控制台输出玩家位置",
        Duration = 2
    })
end
]],
    Callback = function(code)
        -- 安全执行用户代码（隔离环境，避免污染全局）
        local env = setmetatable({
            LocalPlayer = LocalPlayer,
            Character = Character,
            Humanoid = Humanoid,
            HumanoidRootPart = HumanoidRootPart,
            WindUI = WindUI,
            notify = notify
        }, { __index = _G })
        
        local success, err = pcall(function()
            loadstring(code, "ConsoleCode")(env)
        end)
        
        if success then
            WindUI:Notify({
                Title = "执行成功",
                Desc = "代码已正常运行",
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

-- 选择默认标签页（Main）
Window:SelectTab(1)

-- 窗口关闭事件：保留功能状态，仅关闭界面
Window:OnClose(function()
    WindUI:Notify({
        Title = "界面已关闭",
        Desc = "已启用的功能会继续运行",
        Duration = 3
    })
end)

-- 游戏关闭时清理所有功能和连接
game:BindToClose(function()
    Window:Close()
    -- 断开所有功能连接
    for _, conn in pairs(Connections) do
        if conn and typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    -- 关闭所有功能
    for _, handler in pairs(FeatureHandlers) do
        if handler.disable then
            pcall(handler.disable)
        end
    end
end)
