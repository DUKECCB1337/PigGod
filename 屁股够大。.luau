-- 服务和变量初始化
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

-- 玩家和角色信息，通过CharacterAdded事件动态更新
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Camera = Workspace.CurrentCamera

-- 刷新角色信息
LocalPlayer.CharacterAdded:Connect(function(newChar)
	Character = newChar
	Humanoid = newChar:WaitForChild("Humanoid")
	HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
end)

-- 全局UI和功能状态
local FeatureStates = {
	NoClip = false,
	NightVision = false,
	ESP = false,
	WalkFling = false,
	WallClimb = false,
	Speed = false,
	HighJump = false,
	KeepY = false,
	TP = false,
	ClickTP = false,
	Fly = false,
	AirJump = false,
	AntiWalkFling = false,
	Sprint = false,
	Lowhop = false,
	Gravity = false,
	NoKnockBack = false,
	NoSlow = false,
	Bhop = false,
	Hitbox = false,
}

-- 功能参数
local FeatureSettings = {
	Speed = 30,
	JumpPower = 100,
	FlySpeed = 50,
	SprintSpeed = 40,
	Gravity = 196.2, -- 默认重力值
	HitboxScale = 1.5,
}

-- 键位绑定系统
local Keybinds = {
	OpenGUI = Enum.KeyCode.RightShift, -- 用于打开/关闭 GUI
}
local BindingInProgress = false
local CurrentBindingFeature = nil

-- 通知系统 (使用WindUI的内置通知功能，如果需要)
local function notify(text)
    -- 可以使用 WindUI:Notification() 或 WindUI:Hint()
    -- 这里我们使用一个简单的print代替，以保持代码简洁
    print("[通知] " .. text)
end

-- 功能控制和连接管理
local Connections = {}

-- 功能处理函数（集中管理）
local FeatureHandlers = {
	NoClip = {
		enable = function()
			Connections.NoClip = RunService.Stepped:Connect(function()
				if Character then
					for _, part in ipairs(Character:GetDescendants()) do
						if part:IsA("BasePart") then
							pcall(function() part.CanCollide = false end)
						end
					end
				end
			end)
		end,
		disable = function()
			if Connections.NoClip then Connections.NoClip:Disconnect() Connections.NoClip = nil end
			if Character then
				for _, part in ipairs(Character:GetDescendants()) do
					if part:IsA("BasePart") then
						pcall(function() part.CanCollide = true end)
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
			if FeatureHandlers.NightVision.originalLighting.Brightness then Lighting.Brightness = FeatureHandlers.NightVision.originalLighting.Brightness end
			if FeatureHandlers.NightVision.originalLighting.Ambient then Lighting.Ambient = FeatureHandlers.NightVision.originalLighting.Ambient end
			if FeatureHandlers.NightVision.originalLighting.OutdoorAmbient then Lighting.OutdoorAmbient = FeatureHandlers.NightVision.originalLighting.OutdoorAmbient end
			if FeatureHandlers.NightVision.originalLighting.FogEnd then Lighting.FogEnd = FeatureHandlers.NightVision.originalLighting.FogEnd end
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
			if Connections.ESP then Connections.ESP:Disconnect() Connections.ESP = nil end
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
					task.delay(0.1, function() if bodyForce and bodyForce.Parent then bodyForce:Destroy() end end)
				end
			end)
		end,
		disable = function()
			if Connections.WalkFling then Connections.WalkFling:Disconnect() Connections.WalkFling = nil end
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
			if Connections.WallClimb then Connections.WallClimb:Disconnect() Connections.WallClimb = nil end
		end,
	},
	Speed = {
		enable = function() if Humanoid then Humanoid.WalkSpeed = FeatureSettings.Speed end end,
		disable = function() if Humanoid then Humanoid.WalkSpeed = (FeatureStates.Sprint and FeatureSettings.SprintSpeed) or 16 end end,
	},
	HighJump = {
		enable = function() if Humanoid then Humanoid.JumpPower = FeatureSettings.JumpPower end end,
		disable = function() if Humanoid then Humanoid.JumpPower = 50 end end,
	},
	KeepY = {
		originalY = 0,
		enable = function()
			if HumanoidRootPart then FeatureHandlers.KeepY.originalY = HumanoidRootPart.Position.Y end
			Connections.KeepY = RunService.Stepped:Connect(function()
				if HumanoidRootPart then
					local pos = HumanoidRootPart.Position
					HumanoidRootPart.CFrame = CFrame.new(pos.X, FeatureHandlers.KeepY.originalY, pos.Z)
				end
			end)
		end,
		disable = function()
			if Connections.KeepY then Connections.KeepY:Disconnect() Connections.KeepY = nil end
		end,
	},
	TP = {
		enable = function()
            -- 我们将创建一个TP窗口，而不是一个独立的GUI
		end,
		disable = function()
            -- 在WindUI中，这个逻辑由窗口关闭按钮处理
		end,
	},
	ClickTP = {
		enable = function()
			Connections.ClickTP = UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 or not Camera or not HumanoidRootPart then return end
				local mousePos = UserInputService:GetMouseLocation()
				local ray = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
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
	Fly = {
		enable = function()
			if not Humanoid or not HumanoidRootPart then return end
			Humanoid.PlatformStand = true
			Connections.Fly = RunService.Stepped:Connect(function()
				if HumanoidRootPart and Humanoid then
					local moveDirection = Humanoid.MoveDirection
					local flyVelocity = Vector3.new(0, 0, 0)
					if moveDirection.Magnitude > 0 then
						flyVelocity = HumanoidRootPart.CFrame.LookVector * moveDirection.Z * FeatureSettings.FlySpeed + HumanoidRootPart.CFrame.RightVector * moveDirection.X * FeatureSettings.FlySpeed
					end
					if UserInputService:IsKeyDown(Enum.KeyCode.Space) then flyVelocity = flyVelocity + Vector3.new(0, FeatureSettings.FlySpeed, 0) end
					if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then flyVelocity = flyVelocity - Vector3.new(0, FeatureSettings.FlySpeed, 0) end
					HumanoidRootPart.CFrame = HumanoidRootPart.CFrame + flyVelocity * (1/60)
				end
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
	AntiWalkFling = {
		lastVelocity = Vector3.new(),
		maxSafeVelocity = 80,
		enable = function()
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
			if Connections.AntiWalkFling then Connections.AntiWalkFling:Disconnect() Connections.AntiWalkFling = nil end
		end,
	},
	Sprint = {
		enable = function() if Humanoid then Humanoid.WalkSpeed = FeatureSettings.SprintSpeed end end,
		disable = function() if Humanoid then Humanoid.WalkSpeed = (FeatureStates.Speed and FeatureSettings.Speed) or 16 end end,
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
			if Connections.Lowhop then Connections.Lowhop:Disconnect() Connections.Lowhop = nil end
		end,
	},
	Gravity = {
		enable = function() Workspace.Gravity = FeatureSettings.Gravity end,
		disable = function() Workspace.Gravity = 196.2 end,
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
			if Connections.NoKnockBack then Connections.NoKnockBack:Disconnect() Connections.NoKnockBack = nil end
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
			if Connections.NoSlow then Connections.NoSlow:Disconnect() Connections.NoSlow = nil end
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
			if Connections.Bhop then Connections.Bhop:Disconnect() Connections.Bhop = nil end
		end,
	},
	Hitbox = {
		originalSizes = {},
		enable = function()
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer and plr.Character then
					for _, part in ipairs(plr.Character:GetDescendants()) do
						if part:IsA("BasePart") then
							if not FeatureHandlers.Hitbox.originalSizes[part] then
								FeatureHandlers.Hitbox.originalSizes[part] = part.Size
								pcall(function() part.Size = part.Size * FeatureSettings.HitboxScale end)
							end
						end
					end
				end
			end
		end,
		disable = function()
			for part, size in pairs(FeatureHandlers.Hitbox.originalSizes) do
				if part and part.Parent then
					pcall(function() part.Size = size end)
				end
			end
			FeatureHandlers.Hitbox.originalSizes = {}
		end,
	},
}

-- 功能切换函数
local function toggleFeature(featureName, state)
	local newState = state ~= nil and state or not FeatureStates[featureName]
	
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
	local handler = FeatureHandlers[featureName]
	if handler then
		if newState then
			if handler.enable then handler.enable() end
		else
			if handler.disable then handler.disable() end
		end
	end
	
	-- 这里的notify可以替换为WindUI的通知
	notify(featureName .. (newState and " 已启用" or " 已禁用"))
end

-- 键位绑定系统
local function startBinding(featureName)
	if BindingInProgress then
		notify("已有绑定任务进行中")
		return
	end
	BindingInProgress = true
	CurrentBindingFeature = featureName
	notify("按下新的按键来绑定 '"..featureName.."'...")

	local bindingConnection
	bindingConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		Keybinds[CurrentBindingFeature] = input.KeyCode
		notify("'"..CurrentBindingFeature.."' 已绑定到: "..tostring(input.KeyCode.Name))
		BindingInProgress = false
		CurrentBindingFeature = nil
		if bindingConnection then bindingConnection:Disconnect() bindingConnection = nil end
	end)
end

-- WindUI 客户端脚本开始
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Guo61/Cat-/refs/heads/main/main.lua"))()

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

repeat wait() until Confirmed

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
    Keybind = Enum.KeyCode.RightControl, -- 使用RightControl键
})

-- 定义标签页
local Tabs = {
    Main = Window:Tab({ Title = "Main", Icon = "rbxassetid://6026568198" }),
    Movement = Window:Tab({ Title = "Movement", Icon = "rbxassetid://94462465090724" }),
    Combat = Window:Tab({ Title = "Combat", Icon = "swords" }),
    Player = Window:Tab({ Title = "Player", Icon = "user" }),
    Misc = Window:Tab({ Title = "Misc", Icon = "settings" }),
    Exploit = Window:Tab({ Title = "Exploit", Icon = "code" }),
}

-- 绑定功能到UI
local function createFeatureButtons(tab, features, title, desc, settingName)
    if title then
        tab:Paragraph({ Title = title, Desc = desc })
    end
    for _, feature in ipairs(features) do
        if feature == "Speed" or feature == "Sprint" or feature == "HighJump" or feature == "Fly" or feature == "Gravity" or feature == "Hitbox" then
            -- 滑块或输入框
            local settings = FeatureSettings[feature]
            tab:Slider({
                Title = feature,
                Desc = "调整 "..feature.." 值",
                Value = {
                    Min = 1,
                    Max = 200,
                    Default = settings,
                },
                OnRightClick = function()
                    startBinding(feature)
                end,
                Callback = function(value)
                    FeatureSettings[feature] = value
                    if FeatureStates[feature] then
                        toggleFeature(feature, true) -- 更新功能状态
                    end
                end
            })
        elseif feature == "TP" then
            tab:Button({
                Title = "Teleport List",
                Desc = "传送至玩家列表",
                Callback = function()
                    local tpWindow = WindUI:CreateWindow({
                        Title = "Teleport",
                        Size = UDim2.fromOffset(250, 400),
                        SideBarEnabled = false,
                    })

                    local tpTab = tpWindow:Tab({ Title = "Players" })
                    local function refreshPlayerList()
                        tpTab:Clear() -- 清空现有按钮
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= LocalPlayer then
                                tpTab:Button({
                                    Title = p.Name,
                                    Callback = function()
                                        local targetChar = p.Character
                                        if not targetChar or not targetChar:FindFirstChild("HumanoidRootPart") then
                                            notify("无法找到该玩家角色")
                                            return
                                        end
                                        if HumanoidRootPart then
                                            HumanoidRootPart.CFrame = targetChar.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
                                            notify("已传送到 "..p.Name)
                                        end
                                    end
                                })
                            end
                        end
                    end

                    Players.PlayerAdded:Connect(refreshPlayerList)
                    Players.PlayerRemoving:Connect(refreshPlayerList)
                    refreshPlayerList()
                end
            })
        else
            -- 开关
            tab:Toggle({
                Title = feature,
                Desc = "切换 "..feature.." 功能",
                State = FeatureStates[feature],
                OnRightClick = function()
                    startBinding(feature)
                end,
                Callback = function(state)
                    toggleFeature(feature, state)
                end,
            })
        end
    end
end

-- 添加功能到每个标签页
createFeatureButtons(Tabs.Main, {}, "欢迎", "这里是你的主页。")
createFeatureButtons(Tabs.Movement, {"NoClip", "Speed", "HighJump", "Fly", "AirJump", "WallClimb", "Sprint", "Lowhop", "Bhop"})
createFeatureButtons(Tabs.Combat, {"Hitbox", "NoKnockBack", "NoSlow"})
createFeatureButtons(Tabs.Player, {"ESP"})
createFeatureButtons(Tabs.Misc, {"AntiWalkFling", "Gravity"})
createFeatureButtons(Tabs.Exploit, {"WalkFling", "TP", "ClickTP"})

-- 窗口关闭时的处理
Window:OnClose(function()
    print("UI closed.")
end)

-- 键位事件处理
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or BindingInProgress then return end
	-- 遍历 Keybinds，如果有 feature 绑定到这个键，则切换该功能
	for fname, kcode in pairs(Keybinds) do
		if fname ~= "OpenGUI" and kcode == input.KeyCode and FeatureHandlers[fname] then
			toggleFeature(fname)
			return
		end
	end
end)
