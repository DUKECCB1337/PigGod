-- 加载WindUI库
local success, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Xingyan777/roblox/refs/heads/main/main.lua"))()
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 获取本地玩家与相机
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

-- 角色加载/重生时更新引用
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid")
    HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    -- 重置功能变量
    if FeatureHandlers and FeatureHandlers.LowHop then
        FeatureHandlers.LowHop.airTicks = 0
        FeatureHandlers.LowHop.shouldStrafe = false
    end
    if FeatureHandlers and FeatureHandlers.WalkFling then
        FeatureHandlers.WalkFling.hiddenfling = false
    end
end)
setupCharacter()

-- 全局状态与配置
local FeatureStates = {} -- 功能启用状态表
local Connections = {} -- 事件连接跟踪表
local FeatureSettings = { -- 功能参数配置
    Speed = 30,
    JumpPower = 100,
    FlySpeed = 50,
    SprintSpeed = 40,
    Gravity = 196.2,
    HitboxScale = 1.5,
    LowHopGlide = false
}

-- 通用通知函数
local function notify(title, desc, duration)
    WindUI:Notify({
        Title = title,
        Desc = desc,
        Duration = duration or 3
    })
end

-- 辅助函数：根据移动方向调整水平速度
local function withStrafe(velocity, speed)
    if not Humanoid or not HumanoidRootPart then return velocity end
    local moveDir = Humanoid.MoveDirection
    if moveDir.Magnitude <= 0 then return velocity end
    
    local horizontalDir = CFrame.lookAt(Vector3.new(), Vector3.new(moveDir.X, 0, moveDir.Z)).LookVector
    local targetSpeed = speed or Humanoid.WalkSpeed * 1.2
    return Vector3.new(
        horizontalDir.X * targetSpeed,
        velocity.Y,
        horizontalDir.Z * targetSpeed
    )
end

-- 辅助函数：检测角色下方是否有方块（用于LowHop）
local function isGroundExempt()
    if not Character or not HumanoidRootPart then return false end
    if Humanoid.FloorMaterial ~= Enum.Material.Air then return false end
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.IgnoreWater = true
    
    local origin = HumanoidRootPart.Position
    local direction = Vector3.new(0, -0.66, 0)
    local result = Workspace:Raycast(origin, direction, raycastParams)
    return result ~= nil and HumanoidRootPart.Velocity.Y < 0
end

-- 辅助函数：简化速度加成检测（可扩展）
local function getSpeedAmplifier()
    return 0
end

-- 功能处理器定义（基础类功能）
local FeatureHandlers = {
    -- 穿墙功能
    NoClip = {
        enable = function()
            Connections.NoClip = RunService.Stepped:Connect(function()
                if Character then
                    for _, part in ipairs(Character:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end)
        end,
        disable = function()
            if Connections.NoClip then Connections.NoClip:Disconnect() Connections.NoClip = nil end
            if Character then
                for _, part in ipairs(Character:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end
        end,
    },

    -- 夜视功能
    NightVision = {
        originalLighting = {},
        enable = function()
            local handler = FeatureHandlers.NightVision
            handler.originalLighting = {
                Brightness = Lighting.Brightness,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                FogEnd = Lighting.FogEnd
            }
            Lighting.Brightness = 1.5
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            Lighting.FogEnd = 0
        end,
        disable = function()
            local handler = FeatureHandlers.NightVision
            if handler.originalLighting.Brightness then Lighting.Brightness = handler.originalLighting.Brightness end
            if handler.originalLighting.Ambient then Lighting.Ambient = handler.originalLighting.Ambient end
            if handler.originalLighting.OutdoorAmbient then Lighting.OutdoorAmbient = handler.originalLighting.OutdoorAmbient end
            Lighting.FogEnd = handler.originalLighting.FogEnd or 100000
        end,
    },

    -- 玩家透视（ESP）
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
            if Connections.ESP then Connections.ESP:Disconnect() Connections.ESP = nil end
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("Highlight") and obj.Name == "ESP_Highlight" then obj:Destroy() end
            end
        end,
    },

    -- 墙壁攀爬
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
            if Connections.WallClimb then Connections.WallClimb:Disconnect() Connections.WallClimb = nil end
        end,
    }
}
-- 继续添加功能处理器（移动与战斗类）
table.insert(FeatureHandlers, {
    -- 移动加速
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

    -- 高跳功能
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

    -- Y轴锁定（防止坠落/上升）
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
            if Connections.KeepY then Connections.KeepY:Disconnect() Connections.KeepY = nil end
        end,
    },

    -- 点击传送
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
            if Connections.ClickTP then Connections.ClickTP:Disconnect() Connections.ClickTP = nil end
        end,
    },

    -- 飞行功能
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
            if Connections.Fly then Connections.Fly:Disconnect() Connections.Fly = nil end
            if Humanoid then
                Humanoid.PlatformStand = false
                pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
            end
        end,
    },

    -- 空中跳跃
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
            if Connections.AirJump then Connections.AirJump:Disconnect() Connections.AirJump = nil end
        end,
    },

    -- 防甩飞
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
            if Connections.AntiWalkFling then Connections.AntiWalkFling:Disconnect() Connections.AntiWalkFling = nil end
        end,
    },

    -- 冲刺功能
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

    -- LowHop（Hypixel风格低跳）
    LowHop = {
        airTicks = 0,
        shouldStrafe = false,
        enable = function()
            if not Humanoid or not HumanoidRootPart then 
                notify("LowHop", "角色未加载，无法启用", 2)
                return 
            end
            
            Connections.LowHop = RunService.Heartbeat:Connect(function()
                if not Humanoid or not HumanoidRootPart or not Character then return end
                local velocity = HumanoidRootPart.Velocity
                local speedAmplifier = getSpeedAmplifier()
                local glide = FeatureSettings.LowHopGlide

                FeatureHandlers.LowHop.shouldStrafe = false

                if Humanoid.FloorMaterial ~= Enum.Material.Air then
                    FeatureHandlers.LowHop.airTicks = 0
                    velocity = withStrafe(velocity)
                    FeatureHandlers.LowHop.shouldStrafe = true
                else
                    FeatureHandlers.LowHop.airTicks += 1
                    local airTicks = FeatureHandlers.LowHop.airTicks

                    if airTicks == 1 then
                        velocity = withStrafe(velocity)
                        FeatureHandlers.LowHop.shouldStrafe = true
                        velocity = velocity + Vector3.new(0, 0.0568, 0)
                    elseif airTicks == 3 then
                        velocity = Vector3.new(velocity.X * 0.95, velocity.Y - 0.13, velocity.Z * 0.95)
                    elseif airTicks == 4 then
                        velocity = velocity - Vector3.new(0, 0.2, 0)
                    elseif airTicks == 7 and glide and isGroundExempt() then
                        velocity = Vector3.new(velocity.X, 0, velocity.Z)
                    end

                    if isGroundExempt() then velocity = withStrafe(velocity) end

                    if Humanoid.Health < Humanoid.MaxHealth then
                        local minSpeed = 0.281
                        velocity = withStrafe(velocity, math.max(velocity.Magnitude, minSpeed))
                    end

                    if speedAmplifier == 2 then
                        if airTicks == 1 or airTicks == 2 or airTicks == 5 or airTicks == 6 or airTicks == 8 then
                            velocity = Vector3.new(velocity.X * 1.2, velocity.Y, velocity.Z * 1.2)
                        end
                    end
                end

                HumanoidRootPart.Velocity = velocity
            end)

            Connections.LowHopJump = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then return end
                if input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode ~= Enum.KeyCode.Space then return end
                if not Humanoid or not HumanoidRootPart then return end

                local speedAmplifier = getSpeedAmplifier()
                local minSpeed = 0.247 + 0.15 * speedAmplifier
                local currentSpeed = HumanoidRootPart.Velocity.Magnitude
                local targetSpeed = math.max(currentSpeed, minSpeed)

                local velocity = withStrafe(HumanoidRootPart.Velocity, targetSpeed)
                HumanoidRootPart.Velocity = velocity
                FeatureHandlers.LowHop.shouldStrafe = true
            end)

            notify("LowHop", "Hypixel风格低跳已启用", 2)
        end,
        disable = function()
            if Connections.LowHop then
                Connections.LowHop:Disconnect()
                Connections.LowHop = nil
            end
            if Connections.LowHopJump then
                Connections.LowHopJump:Disconnect()
                Connections.LowHopJump = nil
            end
            FeatureHandlers.LowHop.airTicks = 0
            FeatureHandlers.LowHop.shouldStrafe = false
            notify("LowHop", "低跳已关闭", 2)
        end,
    },

    -- 重力修改
    Gravity = {
        enable = function()
            Workspace.Gravity = FeatureSettings.Gravity
        end,
        disable = function()
            Workspace.Gravity = 196.2
        end,
    },

    -- 免疫击退
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

    -- 免疫减速
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

    -- 连跳（Bhop）
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

    -- 行走甩飞（已修复，移动到Exploit类）
    WalkFling = {
        hiddenfling = false,
        flingConnection = nil,
        diedConnection = nil,
        movel = 0.1, -- 垂直速度波动系数
        
        enable = function()
            if not Humanoid or not HumanoidRootPart or not Character then 
                notify("行走甩飞", "角色未加载，无法启用", 2)
                return 
            end
            
            -- 初始化检测标识
            if not ReplicatedStorage:FindFirstChild("juisdfj0i32i0eidsuf0iok") then
                local detection = Instance.new("Decal")
                detection.Name = "juisdfj0i32i0eidsuf0iok"
                detection.Parent = ReplicatedStorage
            end
            
            -- 核心甩飞循环
            FeatureHandlers.WalkFling.flingConnection = RunService.Heartbeat:Connect(function()
                if not FeatureHandlers.WalkFling.hiddenfling then return end
                if not Character or not HumanoidRootPart then return end
                
                local hrp = HumanoidRootPart
                local vel = hrp.Velocity
                
                -- 执行甩飞速度逻辑
                hrp.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
                RunService.RenderStepped:Wait()
                if hrp and hrp.Parent then
                    hrp.Velocity = vel
                end
                RunService.Stepped:Wait()
                if hrp and hrp.Parent then
                    hrp.Velocity = vel + Vector3.new(0, FeatureHandlers.WalkFling.movel, 0)
                    FeatureHandlers.WalkFling.movel = FeatureHandlers.WalkFling.movel * -1 -- 反向波动垂直速度
                end
            end)
            
            -- 角色死亡时自动停止
            if Humanoid then
                FeatureHandlers.WalkFling.diedConnection = Humanoid.Died:Connect(function()
                    FeatureHandlers.WalkFling.hiddenfling = false
                end)
            end
            
            FeatureHandlers.WalkFling.hiddenfling = true
            notify("行走甩飞", "已启用", 2)
        end,
        
        disable = function()
            FeatureHandlers.WalkFling.hiddenfling = false
            -- 断开甩飞连接
            if FeatureHandlers.WalkFling.flingConnection then
                FeatureHandlers.WalkFling.flingConnection:Disconnect()
                FeatureHandlers.WalkFling.flingConnection = nil
            end
            -- 断开死亡监听
            if FeatureHandlers.WalkFling.diedConnection then
                FeatureHandlers.WalkFling.diedConnection:Disconnect()
                FeatureHandlers.WalkFling.diedConnection = nil
            end
            -- 移除检测标识
            local detection = ReplicatedStorage:FindFirstChild("juisdfj0i32i0eidsuf0iok")
            if detection then
                detection:Destroy()
            end
            notify("行走甩飞", "已关闭", 2)
        end,
    }
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
