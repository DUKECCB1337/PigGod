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

-- 玩家和角色信息，通过CharacterAdded事件动态更新
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Camera = Workspace.CurrentCamera

-- 全局UI和功能状态
local MainGUI, TP_GUI = nil, nil
local IsGUIVisible = false
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
	ClickGUI = Enum.KeyCode.RightShift,
}
local BindingInProgress = false
local CurrentBindingFeature = nil

-- UI组件引用
local FeatureButtonRefs = {}
local MouseLockState = nil

-- 检查是否为移动设备
local IsMobile = UserInputService.TouchEnabled

-- 刷新角色信息
LocalPlayer.CharacterAdded:Connect(function(newChar)
	Character = newChar
	Humanoid = newChar:WaitForChild("Humanoid")
	HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
end)

-- 通知系统
local function notify(text, time)
	time = time or 2
	local notif = Instance.new("TextLabel")
	notif.Size = UDim2.new(0, 320, 0, 40)
	notif.Position = UDim2.new(0.5, -160, 0.08, 0)
	notif.AnchorPoint = Vector2.new(0.5, 0)
	notif.BackgroundTransparency = 0.15
	notif.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	notif.TextColor3 = Color3.fromRGB(255, 255, 255)
	notif.Text = text
	notif.TextScaled = true
	notif.Font = Enum.Font.GothamSemibold
	notif.ZIndex = 12000
	notif.Parent = PlayerGui
	Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 6)

	local tween = TweenService:Create(
		notif,
		TweenInfo.new(time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{BackgroundTransparency = 1, TextTransparency = 1}
	)
	tween:Play()
	tween.Completed:Wait()
	notif:Destroy()
end

-- 刷新按钮视觉状态
local function refreshButtonVisual(featureName)
	local ref = FeatureButtonRefs[featureName]
	if not ref or not ref.button then return end
	local btn = ref.button
	btn.BackgroundColor3 = FeatureStates[featureName] and Color3.fromRGB(10, 100, 200) or Color3.fromRGB(60, 60, 60)
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
							part.CanCollide = false
						end
					end
				end
			end)
		end,
		disable = function()
			if Connections.NoClip then Connections.NoClip:Disconnect() end
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
			Lighting.Brightness = 1.5
			Lighting.Ambient = Color3.fromRGB(255, 255, 255)
			Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
			Lighting.FogEnd = 0
		end,
		disable = function()
			if FeatureHandlers.NightVision.originalLighting.Brightness then Lighting.Brightness = FeatureHandlers.NightVision.originalLighting.Brightness end
			if FeatureHandlers.NightVision.originalLighting.Ambient then Lighting.Ambient = FeatureHandlers.NightVision.originalLighting.Ambient end
			if FeatureHandlers.NightVision.originalLighting.OutdoorAmbient then Lighting.OutdoorAmbient = FeatureHandlers.NightVision.originalLighting.OutdoorAmbient end
			Lighting.FogEnd = 100000
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
			if Connections.ESP then Connections.ESP:Disconnect() end
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
					task.delay(0.1, function() bodyForce:Destroy() end)
				end
			end)
		end,
		disable = function()
			if Connections.WalkFling then Connections.WalkFling:Disconnect() end
		end,
	},
	WallClimb = {
		enable = function()
			Connections.WallClimb = RunService.Stepped:Connect(function()
				if Humanoid and HumanoidRootPart then
					local raycastParams = RaycastParams.new()
					raycastParams.FilterDescendantsInstances = {Character}
					raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
					local raycastResult = Workspace:Raycast(HumanoidRootPart.Position, HumanoidRootPart.CFrame.LookVector * 2, raycastParams)
					if raycastResult and Humanoid.MoveDirection.Magnitude > 0 then
						Humanoid.Jump = true
					end
				end
			end)
		end,
		disable = function()
			if Connections.WallClimb then Connections.WallClimb:Disconnect() end
		end,
	},
	Speed = {
		enable = function() Humanoid.WalkSpeed = FeatureSettings.Speed end,
		disable = function() Humanoid.WalkSpeed = FeatureStates.Sprint and FeatureSettings.SprintSpeed or 16 end,
	},
	HighJump = {
		enable = function() Humanoid.JumpPower = FeatureSettings.JumpPower end,
		disable = function() Humanoid.JumpPower = 50 end,
	},
	KeepY = {
		originalY = 0,
		enable = function()
			if HumanoidRootPart then FeatureHandlers.KeepY.originalY = HumanoidRootPart.Position.Y end
			Connections.KeepY = RunService.Stepped:Connect(function()
				if HumanoidRootPart then
					local pos = HumanoidRootPart.Position
					HumanoidRootPart.Position = Vector3.new(pos.X, FeatureHandlers.KeepY.originalY, pos.Z)
				end
			end)
		end,
		disable = function()
			if Connections.KeepY then Connections.KeepY:Disconnect() end
		end,
	},
	TP = {
		enable = function()
			if TP_GUI then TP_GUI.Visible = true end
		end,
		disable = function()
			if TP_GUI then TP_GUI.Visible = false end
		end,
	},
	ClickTP = {
		enable = function()
			Connections.ClickTP = UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 or not Camera or not HumanoidRootPart then return end
				local rayParams = RaycastParams.new()
				rayParams.FilterDescendantsInstances = {Character}
				rayParams.FilterType = Enum.RaycastFilterType.Blacklist
				local raycastResult = Camera:ViewportPointToRay(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
				local result = Workspace:Raycast(raycastResult.Origin, raycastResult.Direction * 1000, rayParams)
				if result then
					HumanoidRootPart.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
				end
			end)
		end,
		disable = function()
			if Connections.ClickTP then Connections.ClickTP:Disconnect() end
		end,
	},
	Fly = {
		enable = function()
			Humanoid.PlatformStand = true
			Humanoid:ChangeState(Enum.HumanoidStateType.Flying)
			Connections.Fly = RunService.Stepped:Connect(function()
				if HumanoidRootPart and Humanoid then
					local moveDirection = Humanoid.MoveDirection
					local flyVelocity = Vector3.new()
					if moveDirection.Magnitude > 0 then
						flyVelocity = HumanoidRootPart.CFrame.LookVector * moveDirection.Z * FeatureSettings.FlySpeed + HumanoidRootPart.CFrame.RightVector * moveDirection.X * FeatureSettings.FlySpeed
					end
					if UserInputService:IsKeyDown(Enum.KeyCode.Space) then flyVelocity += Vector3.new(0, FeatureSettings.FlySpeed, 0) end
					if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then flyVelocity -= Vector3.new(0, FeatureSettings.FlySpeed, 0) end
					HumanoidRootPart.CFrame = HumanoidRootPart.CFrame + flyVelocity * 0.05
				end
			end)
		end,
		disable = function()
			if Connections.Fly then Connections.Fly:Disconnect() end
			Humanoid.PlatformStand = false
			Humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end,
	},
	AirJump = {
		enable = function()
			Connections.AirJump = UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode ~= Enum.KeyCode.Space then return end
				if Humanoid and Humanoid.FloorMaterial == Enum.Material.Air then
					Humanoid.Jump = true
				end
			end)
		end,
		disable = function()
			if Connections.AirJump then Connections.AirJump:Disconnect() end
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
			if Connections.AntiWalkFling then Connections.AntiWalkFling:Disconnect() end
		end,
	},
	Sprint = {
		enable = function() Humanoid.WalkSpeed = FeatureSettings.SprintSpeed end,
		disable = function() Humanoid.WalkSpeed = FeatureStates.Speed and FeatureSettings.Speed or 16 end,
	},
	Lowhop = {
		enable = function()
			Connections.Lowhop = RunService.Heartbeat:Connect(function()
				if Humanoid then
					if Humanoid.FloorMaterial ~= Enum.Material.Air then
						Humanoid.Jump = true
						HumanoidRootPart.Velocity = HumanoidRootPart.CFrame.LookVector * (Humanoid.WalkSpeed * 1.025) + Vector3.new(0, HumanoidRootPart.Velocity.Y, 0)
					end
				end
			end)
		end,
		disable = function()
			if Connections.Lowhop then Connections.Lowhop:Disconnect() end
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
			if Connections.NoKnockBack then Connections.NoKnockBack:Disconnect() end
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
			if Connections.NoSlow then Connections.NoSlow:Disconnect() end
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
			if Connections.Bhop then Connections.Bhop:Disconnect() end
		end,
	},
	Hitbox = {
		originalSizes = {},
		enable = function()
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer and plr.Character then
					for _, part in ipairs(plr.Character:GetDescendants()) do
						if part:IsA("BasePart") then
							FeatureHandlers.Hitbox.originalSizes[part] = part.Size
							part.Size *= FeatureSettings.HitboxScale
						end
					end
				end
			end
		end,
		disable = function()
			for part, size in pairs(FeatureHandlers.Hitbox.originalSizes) do
				if part and part.Parent then
					part.Size = size
				end
			end
			FeatureHandlers.Hitbox.originalSizes = {}
		end,
	},
}

-- 功能切换函数
local function toggleFeature(featureName, state)
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
	local handler = FeatureHandlers[featureName]
	if handler then
		if newState then
			if handler.enable then handler.enable() end
		else
			if handler.disable then handler.disable() end
		end
	end
	
	refreshButtonVisual(featureName)
	if featureName ~= "ClickGUI" then
		notify(featureName .. (newState and " 已启用" or " 已禁用"), 1.5)
	end
end

-- 键位绑定系统
local function startBinding(featureName)
	if BindingInProgress then
		notify("已有绑定任务进行中", 1.5)
		return
	end
	BindingInProgress = true
	CurrentBindingFeature = featureName
	notify("按下新的按键来绑定 '"..featureName.."'...", 2)

	local bindingConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		Keybinds[CurrentBindingFeature] = input.KeyCode
		notify("'"..CurrentBindingFeature.."' 已绑定到: "..input.KeyCode.Name, 2)
		BindingInProgress = false
		CurrentBindingFeature = nil
		bindingConnection:Disconnect()
	end)
end

-- 创建详情面板
local function createDetailPanel(titleText, content, settingName, inputHandler)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 300, 0, 180)
	frame.Position = UDim2.new(0.5, -150, 0.5, -90)
	frame.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
	frame.Parent = PlayerGui
	frame.ZIndex = 10000
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(30, 30, 30)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
	title.Text = titleText
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamSemibold
	title.Parent = frame
	-- 拖动功能（双端支持）
	local dragConn = nil
	local dragInput, dragStart, startPos
	
	title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
			dragStart = input.Position
			startPos = frame.Position
			dragConn = UserInputService.InputChanged:Connect(function(input2)
				if input2 == dragInput then
					local delta = input2.Position - dragStart
					frame.Position = startPos + UDim2.new(0, delta.X, 0, delta.Y)
				end
			end)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragConn then
				dragConn:Disconnect()
				dragConn = nil
			end
			dragInput, dragStart, startPos = nil, nil, nil
		end
	end)

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
		frame:Destroy()
	end)

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -10, 0.6, 0)
	desc.Position = UDim2.new(0, 5, 0, 35)
	desc.Text = content
	desc.TextWrapped = true
	desc.TextScaled = true
	desc.TextColor3 = Color3.fromRGB(255, 255, 255)
	desc.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.Parent = frame

	if inputHandler then
		local inputField = Instance.new("TextBox")
		inputField.Size = UDim2.new(1, -10, 0, 30)
		inputField.Position = UDim2.new(0, 5, 0.7, 0)
		inputField.AnchorPoint = Vector2.new(0, 0.5)
		inputField.PlaceholderText = "输入新值..."
		inputField.Text = tostring(FeatureSettings[settingName])
		inputField.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		inputField.TextColor3 = Color3.fromRGB(255, 255, 255)
		inputField.Font = Enum.Font.GothamSemibold
		inputField.Parent = frame
		inputField.FocusLost:Connect(function()
			inputHandler(inputField.Text, settingName)
		end)
	end
	
	return frame
end

-- 创建TP GUI
local function createTPGUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TP_GUI"
	gui.ResetOnSpawn = false
	gui.Parent = PlayerGui
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.DisplayOrder = 9999

	local frame = Instance.new("Frame")
	frame.Name = "Main"
	frame.Size = UDim2.new(0, 250, 0, 400)
	frame.Position = UDim2.new(1, -260, 0.5, -200)
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
	title.Text = "Teleport"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Font = Enum.Font.GothamSemibold
	title.Parent = frame
	-- 拖动功能（双端支持）
	local dragConn = nil
	local dragInput, dragStart, startPos
	
	title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
			dragStart = input.Position
			startPos = frame.Position
			dragConn = UserInputService.InputChanged:Connect(function(input2)
				if input2 == dragInput then
					local delta = input2.Position - dragStart
					frame.Position = startPos + UDim2.new(0, delta.X, 0, delta.Y)
				end
			end)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragConn then
				dragConn:Disconnect()
				dragConn = nil
			end
			dragInput, dragStart, startPos = nil, nil, nil
		end
	end)

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
	playerList.Name = "PlayerList"
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

-- 创建主GUI
local function createMainGUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PigGod_LiquidGui"
	gui.ResetOnSpawn = false
	gui.Parent = PlayerGui
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.DisplayOrder = 9999

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "Main"
	mainFrame.Size = UDim2.new(0, 350, 0, 400)
	mainFrame.Position = UDim2.new(0.5, -175, 0.5, -200)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
	mainFrame.Active = true
	mainFrame.Parent = gui
	Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke", mainFrame)
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(30, 30, 30)
	stroke.Transparency = 0.25

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
	title.Text = "PigGod's Liquid"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Font = Enum.Font.GothamSemibold
	title.Parent = mainFrame
	-- 拖动功能（双端支持）
	local dragConn = nil
	local dragInput, dragStart, startPos
	
	title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
			dragStart = input.Position
			startPos = mainFrame.Position
			dragConn = UserInputService.InputChanged:Connect(function(input2)
				if input2 == dragInput then
					local delta = input2.Position - dragStart
					mainFrame.Position = startPos + UDim2.new(0, delta.X, 0, delta.Y)
				end
			end)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragConn then
				dragConn:Disconnect()
				dragConn = nil
			end
			dragInput, dragStart, startPos = nil, nil, nil
		end
	end)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 25, 0, 25)
	closeBtn.Position = UDim2.new(1, -28, 0, 3)
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 20, 20)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamSemibold
	closeBtn.Text = "X"
	closeBtn.Parent = title
	closeBtn.Activated:Connect(function()
		IsGUIVisible = false
		mainFrame.Visible = false
	end)

	local tabList = Instance.new("ScrollingFrame")
	tabList.Name = "TabList"
	tabList.Size = UDim2.new(0, 100, 1, -30)
	tabList.Position = UDim2.new(0, 0, 0, 30)
	tabList.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	tabList.Parent = mainFrame
	local tabListLayout = Instance.new("UIListLayout")
	tabListLayout.Padding = UDim.new(0, 5)
	tabListLayout.Parent = tabList

	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, -100, 1, -30)
	contentFrame.Position = UDim2.new(0, 100, 0, 30)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = mainFrame

	local CategoryFeatureMap = {
		Movement = {"NoClip","Speed","HighJump","KeepY","Fly","AirJump","WallClimb","Sprint","Lowhop","Bhop"},
		Visual = {"NightVision","ESP"},
		Combat = {"Hitbox","NoKnockBack","NoSlow"},
		Exploits = {"WalkFling","TP","ClickTP"},
		Misc = {"AntiWalkFling", "Gravity"},
	}
	local lastActiveTab = nil
	
	local function setSettingValue(value, settingName)
		local numVal = tonumber(value)
		if not numVal then
			notify("输入值无效，请输入数字。", 1.5)
			return
		end
		FeatureSettings[settingName] = numVal
		notify("'"..settingName.."' 已设置为: " .. tostring(numVal), 1.5)
		if FeatureStates[settingName] then
			FeatureHandlers[settingName].disable()
			FeatureHandlers[settingName].enable()
		end
	end

	local function showCategory(categoryName)
		for _, child in ipairs(contentFrame:GetChildren()) do
			child:Destroy()
		end

		local tabContent = Instance.new("ScrollingFrame")
		tabContent.Size = UDim2.new(1, -10, 1, -10)
		tabContent.Position = UDim2.new(0, 5, 0, 5)
		tabContent.BackgroundTransparency = 1
		tabContent.Parent = contentFrame
		local contentLayout = Instance.new("UIListLayout")
		contentLayout.Padding = UDim.new(0, 5)
		contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		contentLayout.Parent = tabContent

		for _, featureName in ipairs(CategoryFeatureMap[categoryName]) do
			local buttonFrame = Instance.new("Frame")
			buttonFrame.Size = UDim2.new(1, 0, 0, 40)
			buttonFrame.BackgroundTransparency = 1
			buttonFrame.Parent = tabContent
			
			local featureBtn = Instance.new("TextButton")
			featureBtn.Name = featureName
			featureBtn.Size = UDim2.new(0, 150, 1, 0)
			featureBtn.BackgroundColor3 = FeatureStates[featureName] and Color3.fromRGB(10, 100, 200) or Color3.fromRGB(60, 60, 60)
			featureBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			featureBtn.Font = Enum.Font.GothamSemibold
			featureBtn.Text = featureName
			featureBtn.TextScaled = true
			featureBtn.Parent = buttonFrame
			featureBtn.Activated:Connect(function()
				toggleFeature(featureName)
			end)
			featureBtn.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton2 then
					startBinding(featureName)
				end
			end)

			FeatureButtonRefs[featureName] = { button = featureBtn, frame = buttonFrame }
			
			-- 添加设置输入框
			local settingNames = {"Speed", "HighJump", "FlySpeed", "Gravity", "HitboxScale", "SprintSpeed"}
			local hasInput = false
			local settingName = ""
			if featureName == "Speed" then settingName = "Speed" end
			if featureName == "HighJump" then settingName = "JumpPower" end
			if featureName == "Fly" then settingName = "FlySpeed" end
			if featureName == "Gravity" then settingName = "Gravity" end
			if featureName == "Hitbox" then settingName = "HitboxScale" end
			
			if settingName ~= "" then
				local inputField = Instance.new("TextBox")
				inputField.Size = UDim2.new(0, 60, 1, 0)
				inputField.Position = UDim2.new(0, 160, 0, 0)
				inputField.PlaceholderText = "Value"
				inputField.Text = tostring(FeatureSettings[settingName])
				inputField.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
				inputField.TextColor3 = Color3.fromRGB(255, 255, 255)
				inputField.TextScaled = true
				inputField.Font = Enum.Font.GothamSemibold
				inputField.Parent = buttonFrame
				inputField.FocusLost:Connect(function()
					setSettingValue(inputField.Text, settingName)
				end)
			end

			local infoBtn = Instance.new("TextButton")
			infoBtn.Size = UDim2.new(0, 25, 1, 0)
			infoBtn.Position = UDim2.new(1, -25, 0, 0)
			infoBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			infoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			infoBtn.Font = Enum.Font.GothamSemibold
			infoBtn.Text = "?"
			infoBtn.Parent = buttonFrame
			infoBtn.Activated:Connect(function()
				local titleText = featureName .. " 详情"
				local contentText = "此功能暂无详细描述。"
				local settingName = nil
				if featureName == "NoClip" then contentText = "启用后可以穿过墙壁和障碍物。中键点击按钮进行键位绑定。"
				elseif featureName == "Speed" then contentText = "调整行走速度。输入框可以设置新的速度值 (1-500)。" settingName = "Speed"
				elseif featureName == "HighJump" then contentText = "调整跳跃高度。输入框可以设置新的跳跃力 (1-200)。" settingName = "JumpPower"
				elseif featureName == "KeepY" then contentText = "启用后将锁定角色的Y轴高度，防止掉落。"
				elseif featureName == "Fly" then contentText = "启用后可自由飞行，WASD移动，空格上升，Shift下降。输入框可设置飞行速度 (1-300)。" settingName = "FlySpeed"
				elseif featureName == "AirJump" then contentText = "启用后可以在空中无限次跳跃。"
				elseif featureName == "WallClimb" then contentText = "启用后靠近墙壁时会自动攀爬。"
				elseif featureName == "Sprint" then contentText = "启用后角色的行走速度会提升到疾跑速度。"
				elseif featureName == "Lowhop" then contentText = "自动进行超低跳跃，通常用于加速。"
				elseif featureName == "Bhop" then contentText = "基于跳跃的加速功能。通常用于在平地上快速移动。"
				elseif featureName == "NightVision" then contentText = "启用后游戏亮度将最大化，可以清晰看到黑暗区域。"
				elseif featureName == "NoKnockBack" then contentText = "防止玩家被外力击退，如物理攻击或爆炸。"
				elseif featureName == "NoSlow" then contentText = "防止玩家被减速效果影响，始终保持正常移动速度。"
				elseif featureName == "ESP" then contentText = "启用后将高亮显示其他玩家，即使隔着障碍物也能看到。"
				elseif featureName == "WalkFling" then contentText = "利用移动时的物理惯性将周围玩家甩飞。"
				elseif featureName == "TP" then contentText = "打开一个列表，可以选择其他玩家进行传送。"
				elseif featureName == "ClickTP" then contentText = "启用后，鼠标左键点击任意地方即可瞬移到该位置。"
				elseif featureName == "AntiWalkFling" then contentText = "防止被其他玩家的甩飞功能影响。"
				elseif featureName == "Gravity" then contentText = "调整游戏世界的重力。默认重力值为 196.2。" settingName = "Gravity"
				elseif featureName == "Hitbox" then contentText = "调整其他玩家的碰撞箱大小。输入框可设置新的比例（例如：2代表放大2倍）。" settingName = "HitboxScale"
				end
				createDetailPanel(titleText, contentText, settingName, setSettingValue)
			end)
		end
	end
	
	for categoryName, _ in pairs(CategoryFeatureMap) do
		local tabBtn = Instance.new("TextButton")
		tabBtn.Size = UDim2.new(1, 0, 0, 30)
		tabBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		tabBtn.Text = categoryName
		tabBtn.TextScaled = true
		tabBtn.Font = Enum.Font.GothamSemibold
		tabBtn.Parent = tabList
		tabBtn.Activated:Connect(function()
			if lastActiveTab then lastActiveTab.BackgroundColor3 = Color3.fromRGB(40, 40, 40) end
			tabBtn.BackgroundColor3 = Color3.fromRGB(10, 100, 200)
			lastActiveTab = tabBtn
			showCategory(categoryName)
		end)
	end
	
	mainFrame.Visible = false
	
	task.spawn(function()
		task.wait(0.1)
		if tabList:FindFirstChildOfClass("TextButton") then
			tabList:FindFirstChildOfClass("TextButton").Activated:Fire()
		end
	end)

	return gui
end

-- 创建移动设备浮动按钮
local function createMobileButton()
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 60, 0, 60)
	button.Position = UDim2.new(0.5, -30, 0.8, -30)
	button.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
	button.Text = "菜单"
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.ZIndex = 10000
	button.Parent = PlayerGui
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
	
	local dragToggle = false
	local dragInput, dragStart, startPos
	
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and not IsGUIVisible then
			dragToggle = true
			dragInput = input
			dragStart = input.Position
			startPos = button.Position
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragToggle then
			local delta = input.Position - dragStart
			button.Position = startPos + UDim2.new(0, delta.X, 0, delta.Y)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input)
		if input == dragInput and dragToggle then
			dragToggle = false
		end
	end)
	
	button.Activated:Connect(function()
		IsGUIVisible = not IsGUIVisible
		MainGUI.Visible = IsGUIVisible
	end)
end

-- 初始化函数
local function init()
	TP_GUI = createTPGUI()
	MainGUI = createMainGUI()
	
	if IsMobile then
		createMobileButton()
		StarterGui:SetCore("ControlModule", nil)
		notify("移动设备模式已启用。", 2)
	else
		StarterGui:SetCore("ControlModule", true)
	end
	
	-- 鼠标锁定/解锁逻辑
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.End then
			if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
				MouseLockState = Enum.MouseBehavior.LockCenter
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				notify("鼠标已解锁，点击恢复锁定。", 2)
			elseif UserInputService.MouseBehavior == Enum.MouseBehavior.Default and MouseLockState then
				UserInputService.MouseBehavior = MouseLockState
				MouseLockState = nil
				notify("鼠标已恢复锁定。", 2)
			end
		end
	end)

	-- 键位事件处理
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or BindingInProgress then return end
		if input.KeyCode == Keybinds.ClickGUI then
			IsGUIVisible = not IsGUIVisible
			MainGUI.Visible = IsGUIVisible
			if IsGUIVisible then
				if not IsMobile and UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
					MouseLockState = UserInputService.MouseBehavior
					UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				end
			else
				if not IsMobile and MouseLockState then
					UserInputService.MouseBehavior = MouseLockState
					MouseLockState = nil
				end
			end
			return
		end
		
		for fname, kcode in pairs(Keybinds) do
			if kcode == input.KeyCode then
				toggleFeature(fname)
				return
			end
		end
	end)

	notify("客户端初始化完成！默认快捷键: RightShift", 3)
end

-- 启动初始化
local success, err = pcall(init)
if not success then
	warn("Initialization failed: " .. err)
	notify("客户端初始化失败。请检查控制台。", 5)
end
