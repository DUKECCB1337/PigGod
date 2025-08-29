-- 安全加载WindUI库
local WindUI = nil
local function LoadWindUI()
    local sources = {
        "https://raw.githubusercontent.com/Guo61/Cat-/refs/heads/main/main.lua",
        "https://raw.githubusercontent.com/AlexR32/Roblox/main/WindUI.lua" -- 备用源
    }
    
    for _, url in ipairs(sources) do
        local success, result = pcall(function()
            return loadstring(game:HttpGet(url, true))()
        end)
        if success and type(result) == "table" then
            return result
        end
    end
    return nil
end

WindUI = LoadWindUI()

if not WindUI then
    warn("WindUI库加载失败，请检查网络连接或链接有效性")
    return
end

-- 服务和变量初始化
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

-- 安全等待函数 - 解决 "CoreGui:WaitForChild" 错误
local function SafeWaitForChild(parent, childName, timeout)
    timeout = timeout or 5
    local start = tick()
    local child = parent:FindFirstChild(childName)
    
    while not child and (tick() - start) < timeout do
        task.wait(0.1)
        child = parent:FindFirstChild(childName)
    end
    
    return child
end

-- 玩家和角色信息
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Camera = Workspace.CurrentCamera

-- 功能分类映射
local CategoryFeatureMap = {
    Movement = {"NoClip","Speed","HighJump","KeepY","Fly","AirJump","WallClimb","Sprint","Lowhop","Bhop"},
    Visual = {"NightVision","ESP"},
    Combat = {"Hitbox"},
    Exploit = {"WalkFling","TP","ClickTP"},
    Misc = {"Gravity"},
    Player = {"AntiWalkFling","NoKnockBack","NoSlow"}
}

-- 全局功能状态 - 所有功能默认关闭
local FeatureStates = {}
for _, features in pairs(CategoryFeatureMap) do
    for _, feature in ipairs(features) do
        FeatureStates[feature] = false
    end
end

-- 功能参数
local FeatureSettings = {
    Speed = 30,
    JumpPower = 100,
    FlySpeed = 50,
    SprintSpeed = 40,
    Gravity = 196.2,
    HitboxScale = 1.5,
}

-- 键位绑定
local Keybinds = {
    OpenGUI = Enum.KeyCode.RightShift,
}

-- 连接管理
local Connections = {}

-- 安全等待核心GUI元素 - 解决 "TopBarApp" 错误
local topBarApp = SafeWaitForChild(CoreGui, "TopBarApp")
if not topBarApp then
    warn("TopBarApp not found in CoreGui")
end

-- 刷新角色信息
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = SafeWaitForChild(newChar, "Humanoid") or newChar:WaitForChild("Humanoid")
    HumanoidRootPart = SafeWaitForChild(newChar, "HumanoidRootPart") or newChar:WaitForChild("HumanoidRootPart")
    
    -- 仅重新应用已启用的功能设置
    if FeatureStates.Speed then
        Humanoid.WalkSpeed = FeatureSettings.Speed
    elseif FeatureStates.Sprint then
        Humanoid.WalkSpeed = FeatureSettings.SprintSpeed
    else
        Humanoid.WalkSpeed = 16
    end
    
    if FeatureStates.HighJump then
        Humanoid.JumpPower = FeatureSettings.JumpPower
    else
        Humanoid.JumpPower = 50
    end
end)

-- 通知系统
local function notify(text, time)
    if WindUI and WindUI.Notify then
        WindUI:Notify({
            Title = "通知",
            Content = text,
            Duration = time or 2
        })
    else
        -- 备用通知系统
        warn(text)
    end
end

-- 功能处理函数
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
            FeatureHandlers.NightVision.originalLighting.Brightness = Lighting.Brightness
            FeatureHandlers.NightVision.originalLighting.Ambient = Lighting.Ambient
            FeatureHandlers.NightVision.originalLighting.OutdoorAmbient = Lighting.OutdoorAmbient
            FeatureHandlers.NightVision.originalLighting.FogEnd = Lighting.FogEnd
            Lighting.Brightness = 1.5
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            Lighting.FogEnd = 0
        end,
        disable = function()
            if FeatureHandlers.NightVision.originalLighting.Brightness then
                Lighting.Brightness = FeatureHandlers.NightVision.originalLighting.Brightness
            end
            if FeatureHandlers.NightVision.originalLighting.Ambient then
                Lighting.Ambient = FeatureHandlers.NightVision.originalLighting.Ambient
            end
            if FeatureHandlers.NightVision.originalLighting.OutdoorAmbient then
                Lighting.OutdoorAmbient = FeatureHandlers.NightVision.originalLighting.OutdoorAmbient
            end
            if FeatureHandlers.NightVision.originalLighting.FogEnd then
                Lighting.FogEnd = FeatureHandlers.NightVision.originalLighting.FogEnd
            else
                Lighting.FogEnd = 100000
            end
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
                Humanoid.WalkSpeed = 16
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
                Humanoid.WalkSpeed = 16
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
    
    Hitbox = {
        enable = function()
            Connections.Hitbox = RunService.Heartbeat:Connect(function()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.Character then
                        for _, part in ipairs(plr.Character:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.Size = part.Size * FeatureSettings.HitboxScale
                            end
                        end
                    end
                end
            end)
        end,
        disable = function()
            if Connections.Hitbox then
                Connections.Hitbox:Disconnect()
                Connections.Hitbox = nil
            end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    for _, part in ipairs(plr.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.Size = part.Size / FeatureSettings.HitboxScale
                        end
                    end
                end
            end
        end,
    },
}

-- 功能切换函数
local function toggleFeature(featureName, state)
    if not FeatureHandlers[featureName] then
        notify("无效功能: "..featureName, 2)
        return
    end
    
    local newState = state ~= nil and state or not FeatureStates[featureName]
    
    -- 处理功能冲突
    if newState then
        if featureName == "Speed" and FeatureStates.Sprint then
            toggleFeature("Sprint", false)
        elseif featureName == "Sprint" and FeatureStates.Speed then
            toggleFeature("Speed", false)
        end
        if featureName == "Lowhop" and FeatureStates.Bhop then
            toggleFeature("Bhop", false)
        elseif featureName == "Bhop" and FeatureStates.Lowhop then
            toggleFeature("Lowhop", false)
        end
    end
    
    FeatureStates[featureName] = newState
    
    pcall(function()
        local handler = FeatureHandlers[featureName]
        if handler then
            if newState then
                if handler.enable then handler.enable() end
            else
                if handler.disable then handler.disable() end
            end
        end
    end)
    
    notify(featureName .. (newState and " 已启用" or " 已禁用"), 1.5)
end

-- 创建玩家列表用于传送
local function createPlayerList()
    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(players, {
                Title = player.Name,
                Callback = function()
                    local targetChar = player.Character
                    if not targetChar or not targetChar:FindFirstChild("HumanoidRootPart") then
                        notify("无法找到该玩家角色", 2)
                        return
                    end
                    if HumanoidRootPart then
                        HumanoidRootPart.CFrame = targetChar.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
                        notify("已传送到 "..player.Name, 2)
                    end
                end
            })
        end
    end
    return players
end

-- 创建TP GUI
local TP_GUI = nil
local function createTPGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "TP_GUI"
    gui.Parent = PlayerGui
    gui.Enabled = false
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 250, 0, 400)
    frame.Position = UDim2.new(1, -260, 0.5, -200)
    frame.AnchorPoint = Vector2.new(1, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
    title.Text = "传送玩家"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamSemibold
    title.Parent = frame
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -28, 0, 3)
    closeBtn.AnchorPoint = Vector2.new(1, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 20, 20)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamSemibold
    closeBtn.Text = "X"
    closeBtn.Parent = title
    closeBtn.Activated:Connect(function()
        toggleFeature("TP", false)
    end)
    
    local playerList = Instance.new("ScrollingFrame")
    playerList.Size = UDim2.new(1, -10, 1, -40)
    playerList.Position = UDim2.new(0, 5, 0, 35)
    playerList.BackgroundTransparency = 1
    playerList.Parent = frame
    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = playerList
    
    local function refreshPlayerList()
        for _, child in ipairs(playerList:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local tpBtn = Instance.new("TextButton")
                tpBtn.Size = UDim2.new(1, 0, 0, 30)
                tpBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                tpBtn.Text = p.Name
                tpBtn.TextScaled = true
                tpBtn.Font = Enum.Font.GothamSemibold
                tpBtn.Parent = playerList
                tpBtn.Activated:Connect(function()
                    local targetChar = p.Character
                    if not targetChar or not targetChar:FindFirstChild("HumanoidRootPart") then
                        notify("无法找到该玩家角色", 2)
                        return
                    end
                    if HumanoidRootPart then
                        HumanoidRootPart.CFrame = targetChar.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
                        notify("已传送到 "..p.Name, 2)
                    end
                end)
            end
        end
    end
    
    Players.PlayerAdded:Connect(refreshPlayerList)
    Players.PlayerRemoving:Connect(refreshPlayerList)
    refreshPlayerList()
    
    return gui
end

-- 主程序入口
local function main()
    -- 创建TP GUI
    TP_GUI = createTPGUI()
    
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
        Visual = Window:Tab({ Title = "Visual", Icon = "eye" }),
        Combat = Window:Tab({ Title = "Combat", Icon = "swords" }),
        Player = Window:Tab({ Title = "Player", Icon = "user" }),
        Misc = Window:Tab({ Title = "Misc", Icon = "settings" }),
        Exploit = Window:Tab({ Title = "Exploit", Icon = "code" }),
    }

    Window:SelectTab(1)

    -- Main 标签页
    Tabs.Main:Paragraph({
        Title = "欢迎",
        Desc = "皮革尬的脚盆v1.0",
    })

    -- 根据功能分类映射动态创建UI元素
    for category, features in pairs(CategoryFeatureMap) do
        local tab = Tabs[category]
        if tab then
            for _, feature in ipairs(features) do
                -- 添加开关控制
                tab:Toggle({
                    Title = feature,
                    Description = feature .. " 功能开关",
                    Callback = function(state)
                        toggleFeature(feature, state)
                    end
                })
                
                -- 为特定功能添加滑块
                if feature == "Speed" then
                    tab:Slider({
                        Title = "移动速度",
                        Min = 16,
                        Max = 200,
                        Default = FeatureSettings.Speed,
                        Callback = function(value)
                            FeatureSettings.Speed = value
                            if FeatureStates.Speed then
                                Humanoid.WalkSpeed = value
                            end
                        end
                    })
                elseif feature == "HighJump" then
                    tab:Slider({
                        Title = "跳跃高度",
                        Min = 50,
                        Max = 500,
                        Default = FeatureSettings.JumpPower,
                        Callback = function(value)
                            FeatureSettings.JumpPower = value
                            if FeatureStates.HighJump then
                                Humanoid.JumpPower = value
                            end
                        end
                    })
                elseif feature == "Fly" then
                    tab:Slider({
                        Title = "飞行速度",
                        Min = 10,
                        Max = 300,
                        Default = FeatureSettings.FlySpeed,
                        Callback = function(value)
                            FeatureSettings.FlySpeed = value
                        end
                    })
                elseif feature == "Sprint" then
                    tab:Slider({
                        Title = "疾跑速度",
                        Min = 16,
                        Max = 200,
                        Default = FeatureSettings.SprintSpeed,
                        Callback = function(value)
                            FeatureSettings.SprintSpeed = value
                            if FeatureStates.Sprint then
                                Humanoid.WalkSpeed = value
                            end
                        end
                    })
                elseif feature == "Gravity" then
                    tab:Slider({
                        Title = "重力设置",
                        Min = 0,
                        Max = 300,
                        Default = FeatureSettings.Gravity,
                        Callback = function(value)
                            FeatureSettings.Gravity = value
                            if FeatureStates.Gravity then
                                Workspace.Gravity = value
                            end
                        end
                    })
                elseif feature == "Hitbox" then
                    tab:Slider({
                        Title = "碰撞箱大小",
                        Min = 0.5,
                        Max = 5,
                        Default = FeatureSettings.HitboxScale,
                        Callback = function(value)
                            FeatureSettings.HitboxScale = value
                        end
                    })
                end
            end
        end
    end

    -- 添加额外按钮
    Tabs.Exploit:Button({
        Title = "传送玩家",
        Description = "打开玩家列表",
        Callback = function()
            toggleFeature("TP", true)
        end
    })

    -- 窗口关闭事件
    Window:OnClose(function()
        notify("UI已关闭", 2)
    end)

    -- 键位绑定事件
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Keybinds.OpenGUI then
            Window:Toggle()
        end
    end)

    notify("客户端初始化完成！按RightShift打开菜单", 3)
end

-- 运行主程序并捕获错误
local success, err = pcall(main)
if not success then
    warn("脚本运行错误: "..tostring(err))
    if WindUI and WindUI.Notify then
        WindUI:Notify({
            Title = "脚本错误",
            Content = tostring(err),
            Duration = 10
        })
    end
end
