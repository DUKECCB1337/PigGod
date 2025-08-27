-- 服务和变量初始化
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- 玩家相关变量，在 CharacterAdded 事件中更新
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local camera = Workspace.CurrentCamera

-- 视图控制状态
local isViewUnlocked = false
local currentView = "FirstPerson"
local thirdPersonConn = nil
local switchViewCooldown = false

-- 全局变量和功能状态
local mainGUI, tpMainFrame, featureButtonRefs = nil, nil, {}
local moduleStates = {
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
	Gravity = false
}

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
	notif.Parent = playerGui
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

-- 功能按钮刷新
local function refreshButtonVisual(featureName)
	local ref = featureButtonRefs[featureName]
	if not ref then return end
	local btn = ref.button
	btn.BackgroundColor3 = moduleStates[featureName] and Color3.fromRGB(10, 100, 200) or Color3.fromRGB(60, 60, 60)
end

-- 视图控制工具
local function createAndEquipViewControlTool()
	if player.Backpack:FindFirstChild("ViewController") or player.Character and player.Character:FindFirstChild("ViewController") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "ViewController"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.Parent = player.Backpack
	notify("视图控制工具已自动创建。", 1.5)
end

-- 夜视功能
local nightVisionActive = false
local nvPrev = {
	Brightness = nil,
	Ambient = nil,
	OutdoorAmbient = nil
}

local function enableNightVision()
	if nightVisionActive then return end
	nvPrev.Brightness = Lighting.Brightness
	nvPrev.Ambient = Lighting.Ambient
	nvPrev.OutdoorAmbient = Lighting.OutdoorAmbient
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(255, 255, 255)
	Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
	Lighting.FogEnd = 0
	nightVisionActive = true
end

local function disableNightVision()
	if not nightVisionActive then return end
	if nvPrev.Brightness then Lighting.Brightness = nvPrev.Brightness end
	if nvPrev.Ambient then Lighting.Ambient = nvPrev.Ambient end
	if nvPrev.OutdoorAmbient then Lighting.OutdoorAmbient = nvPrev.OutdoorAmbient end
	Lighting.FogEnd = 100000
	nightVisionActive = false
end

-- 其他功能参数
local antiWalkFlingConn = nil
local maxSafeVelocity = 80
local currentSpeed = 16
local currentJumpPower = 50
local currentFlySpeed = 50
local sprintSpeed = 40
local currentGravity = 196.2 -- 默认重力值

-- 角色重生时重新加载
player.CharacterAdded:Connect(function(newChar)
	character = newChar
	local ok, hum = pcall(function() return newChar:WaitForChild("Humanoid", 10) end)
	if ok and hum then
		humanoid = hum
	else
		notify("Humanoid 加载失败，部分功能可能无法使用。", 3)
		return
	end
	if not isViewUnlocked then
		createAndEquipViewControlTool()
	end
end)

-- 视图切换功能
local function switchView()
	if not isViewUnlocked then return end
	if not character then return end

	if currentView == "FirstPerson" then
		currentView = "ThirdPerson"
		camera.CameraType = Enum.CameraType.Scriptable
		thirdPersonConn = RunService.RenderStepped:Connect(function()
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			local targetCFrame = hrp.CFrame * CFrame.new(0, 0, 5)
			camera.CFrame = camera.CFrame:Lerp(targetCFrame, 0.2)
		end)
	else
		currentView = "FirstPerson"
		camera.CameraType = Enum.CameraType.Custom
		if thirdPersonConn then
			thirdPersonConn:Disconnect()
			thirdPersonConn = nil
		end
	end
end

-- 鼠标滚轮视图控制
UIS.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel and isViewUnlocked then
		if not switchViewCooldown then
			switchView()
			switchViewCooldown = true
			task.delay(0.2, function()
				switchViewCooldown = false
			end)
		end
	end
end)

-- 功能实现：无碰撞
local noclipConn = nil
local function enableNoClip()
	if noclipConn then noclipConn:Disconnect() end
	noclipConn = RunService.Stepped:Connect(function()
		local char = player.Character
		if not char then return end
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end)
end

local function disableNoClip()
	if noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
	end
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = true
		end
	end
end

-- 功能实现：ESP
local espEnabled = false
local espConn = nil
local function applyESPToPlayer(model)
	if not model or not model:IsA("Model") or not model:FindFirstChild("HumanoidRootPart") then return end
	if model:FindFirstChild("ESP_Highlight") then return end

	local highlight = Instance.new("Highlight")
	highlight.Name = "ESP_Highlight"
	highlight.FillColor = Color3.fromRGB(200, 20, 20)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0
	highlight.FillTransparency = 0.5
	highlight.Enabled = true
	highlight.Parent = model
end

local function removeAllESP()
	for _, obj in pairs(Workspace:GetDescendants()) do
		if obj:IsA("Highlight") and obj.Name == "ESP_Highlight" then
			obj:Destroy()
		end
	end
end

local function enableESP()
    if espConn then return end
    espConn = RunService.RenderStepped:Connect(function()
        if not espEnabled then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                applyESPToPlayer(plr.Character)
            end
        end
    end)
    espEnabled = true
end

local function disableESP()
    if espConn then
        espConn:Disconnect()
        espConn = nil
    end
    espEnabled = false
    removeAllESP()
end

-- 功能实现：WalkFling
local walkFlingPower = 1000000
local walkFlingYBoost = 1000000
local walkFlingMoveToggle = 0.1
local walkFlingConn = nil

local function enableWalkFling()
	if walkFlingConn then walkFlingConn:Disconnect() end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	walkFlingConn = RunService.Stepped:Connect(function()
		local moveDir = humanoid.MoveDirection
		if moveDir.Magnitude > 0 and walkFlingMoveToggle > 0 then
			local force = moveDir * walkFlingPower + Vector3.new(0, walkFlingYBoost, 0)
			local bodyForce = Instance.new("BodyForce")
			bodyForce.Force = force
			bodyForce.Parent = hrp
			task.delay(walkFlingMoveToggle, function() bodyForce:Destroy() end)
		end
	end)
end

local function disableWalkFling()
	if walkFlingConn then
		walkFlingConn:Disconnect()
		walkFlingConn = nil
	end
	walkFlingMoveToggle = 0.1
end

-- 功能实现：墙壁攀爬
local wallClimbOn = false
local climbConn = nil

local function enableWallClimb()
	if climbConn then climbConn:Disconnect() end
	wallClimbOn = true
	climbConn = RunService.Stepped:Connect(function()
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {player.Character}
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		local raycastResult = Workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 2, raycastParams)
		if raycastResult and raycastResult.Instance and raycastResult.Instance.CanCollide and humanoid.MoveDirection.Magnitude > 0 then
			local climbForce = Instance.new("BodyVelocity")
			climbForce.MaxForce = Vector3.new(0, 100000, 0)
			climbForce.Velocity = Vector3.new(0, 50, 0)
			climbForce.P = 1000
			climbForce.Parent = hrp
			task.delay(0.2, function()
				if climbForce.Parent then climbForce:Destroy() end
			end)
		end
	end)
end

local function disableWallClimb()
	if climbConn then
		climbConn:Disconnect()
		climbConn = nil
	end
	wallClimbOn = false
end

-- 功能实现：速度提升
local function applyWalkSpeedToCharacter()
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		notify("Speed apply failed: Humanoid not found", 1.5)
		return
	end
	humanoid.WalkSpeed = moduleStates.Speed and currentSpeed or 16
end

local function setSpeed(value)
	local newSpeed = tonumber(value)
	if not newSpeed or newSpeed <= 0 or newSpeed > 500 then
		notify("Invalid speed value (1-500)", 1.5)
		return
	end
	currentSpeed = newSpeed
	applyWalkSpeedToCharacter()
	if moduleStates.Speed then notify("Walk Speed set to: " .. tostring(currentSpeed), 1.5) end
end

-- 功能实现：高跳
local function applyJumpPower()
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		notify("HighJump apply failed: Humanoid not found", 1.5)
		return
	end
	humanoid.UseJumpPower = true
	humanoid.JumpPower = moduleStates.HighJump and currentJumpPower or 50
end

local function setJumpPower(value)
	local newJump = tonumber(value)
	if not newJump or newJump <= 0 or newJump > 200 then
		notify("Invalid jump power (1-200)", 1.5)
		return
	end
	currentJumpPower = newJump
	applyJumpPower()
	if moduleStates.HighJump then notify("Jump Power set to: " .. tostring(currentJumpPower), 1.5) end
end

-- 功能实现：保持Y高度
local KeepYConn = nil
local keepYTarget = nil

local function enableKeepY()
	if KeepYConn then KeepYConn:Disconnect() end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		keepYTarget = hrp.Position.Y
	else
		keepYTarget = 5
	end

	KeepYConn = RunService.Stepped:Connect(function()
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local currentPos = hrp.Position
			hrp.Position = Vector3.new(currentPos.X, keepYTarget, currentPos.Z)
		end
	end)
end

local function disableKeepY()
	if KeepYConn then
		KeepYConn:Disconnect()
		KeepYConn = nil
	end
	keepYTarget = nil
end

-- 功能实现：飞行
local flyConn = nil
local flyActive = false

local function enableFly()
	if flyConn then flyConn:Disconnect() end
	local char = player.Character
	if not char then
		notify("Fly enable failed: Character not found", 1.5)
		moduleStates.Fly = false
		return
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
		humanoid:ChangeState(Enum.HumanoidStateType.Flying)
	end

	flyActive = true
	flyConn = RunService.Stepped:Connect(function()
		local char = player.Character
		if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local moveDirection = humanoid.MoveDirection
		local flyVelocity = Vector3.new(0, 0, 0)
		if moveDirection.Magnitude > 0 then
			flyVelocity = root.CFrame.LookVector * moveDirection.Z * currentFlySpeed + root.CFrame.RightVector * moveDirection.X * currentFlySpeed
		end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then flyVelocity = flyVelocity + Vector3.new(0, currentFlySpeed, 0) end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then flyVelocity = flyVelocity - Vector3.new(0, currentFlySpeed, 0) end
		root.CFrame = root.CFrame + flyVelocity * 0.05
	end)
end

local function disableFly()
	if flyConn then
		flyConn:Disconnect()
		flyConn = nil
	end
	flyActive = false
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end
end

local function setFlySpeed(value)
	local newFlySpeed = tonumber(value)
	if not newFlySpeed or newFlySpeed <= 0 or newFlySpeed > 300 then
		notify("Invalid fly speed (1-300)", 1.5)
		return
	end
	currentFlySpeed = newFlySpeed
	if flyActive then
		disableFly()
		enableFly()
	end
end

-- 功能实现：空中跳跃
local airJumpConn = nil
local airJumpCooldown = false

local function enableAirJump()
	if airJumpConn then airJumpConn:Disconnect() end
	airJumpConn = UIS.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space and not airJumpCooldown then
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if not hrp or not humanoid then return end
			if humanoid.FloorMaterial == Enum.Material.Air then
				humanoid.Jump = true
				airJumpCooldown = true
				task.delay(0.5, function() airJumpCooldown = false end)
			end
		end
	end)
end

local function disableAirJump()
	if airJumpConn then
		airJumpConn:Disconnect()
		airJumpConn = nil
	end
end

-- 功能实现：防甩飞
local function enableAntiWalkFling()
	if antiWalkFlingConn then antiWalkFlingConn:Disconnect() end
	local lastVelocity = Vector3.new()
	antiWalkFlingConn = RunService.Stepped:Connect(function()
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local currentVelocity = hrp.Velocity
		if (currentVelocity - lastVelocity).Magnitude > maxSafeVelocity then
			hrp.Velocity = lastVelocity
			notify("Anti-WalkFling activated!", 1)
		end
		lastVelocity = currentVelocity
	end)
end

local function disableAntiWalkFling()
	if antiWalkFlingConn then
		antiWalkFlingConn:Disconnect()
		antiWalkFlingConn = nil
	end
end

-- 功能实现：疾跑
local function enableSprint()
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	humanoid.WalkSpeed = sprintSpeed
end

local function disableSprint()
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	-- 检查 Speed 功能是否开启，如果开启则恢复到自定义速度，否则恢复默认
	if moduleStates.Speed then
		humanoid.WalkSpeed = currentSpeed
	else
		humanoid.WalkSpeed = 16
	end
end

-- 功能实现：点击瞬移
local clickTPConn = nil
local function enableClickTP()
    if clickTPConn then clickTPConn:Disconnect() end
    clickTPConn = UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {player.Character}
        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
        
        local raycastResult = camera:ViewportPointToRay(UIS:GetMouseLocation().X, UIS:GetMouseLocation().Y)
        local result = Workspace:Raycast(raycastResult.Origin, raycastResult.Direction * 1000, rayParams)
        
        if result then
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local newPos = result.Position + Vector3.new(0, 3, 0)
                hrp.CFrame = CFrame.new(newPos)
            end
        end
    end)
end

local function disableClickTP()
    if clickTPConn then
        clickTPConn:Disconnect()
        clickTPConn = nil
    end
end

-- 功能实现：Lowhop (更新版本)
local lowhopConn = nil
local function enableLowhop()
    if lowhopConn then lowhopConn:Disconnect() end
    lowhopConn = RunService.RenderStepped:Connect(function()
        local char = player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if not humanoid or not hrp then return end

        if humanoid.MoveDirection.Magnitude > 0 and humanoid.FloorMaterial ~= Enum.Material.Air then
            humanoid.Jump = true
        end
		
		-- 在跳跃后立即降低垂直速度，实现低跳
		local jumpPower = humanoid.JumpPower
		if hrp.Velocity.Y > jumpPower * 0.5 then
			hrp.Velocity = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z)
		end
    end)
end

local function disableLowhop()
    if lowhopConn then
        lowhopConn:Disconnect()
        lowhopConn = nil
    end
end

-- 功能实现：重力设置
local function enableGravity()
    Workspace.Gravity = currentGravity
end

local function disableGravity()
    Workspace.Gravity = 196.2 -- 恢复默认重力
end

local function setGravity(value)
    local newGravity = tonumber(value)
    if not newGravity or newGravity < 0 then
        notify("重力值无效（必须为非负数）。", 1.5)
        return
    end
    currentGravity = newGravity
    Workspace.Gravity = newGravity
    notify("重力已设置为: " .. tostring(currentGravity), 1.5)
end

-- 功能映射表：将功能名称与启用/禁用函数关联起来
local featureHandlers = {
    NoClip = {enable = enableNoClip, disable = disableNoClip},
    NightVision = {enable = enableNightVision, disable = disableNightVision},
    ESP = {enable = enableESP, disable = disableESP},
    WalkFling = {enable = enableWalkFling, disable = disableWalkFling},
    WallClimb = {enable = enableWallClimb, disable = disableWallClimb},
    Speed = {enable = applyWalkSpeedToCharacter, disable = applyWalkSpeedToCharacter},
    HighJump = {enable = applyJumpPower, disable = applyJumpPower},
    KeepY = {enable = enableKeepY, disable = disableKeepY},
    TP = {
        enable = function() tpMainFrame.Visible = true end,
        disable = function() tpMainFrame.Visible = false end
    },
    ClickTP = {enable = enableClickTP, disable = disableClickTP},
    Fly = {enable = enableFly, disable = disableFly},
    AirJump = {enable = enableAirJump, disable = disableAirJump},
    AntiWalkFling = {enable = enableAntiWalkFling, disable = disableAntiWalkFling},
    Sprint = {enable = enableSprint, disable = disableSprint},
    Lowhop = {enable = enableLowhop, disable = disableLowhop},
	Gravity = {enable = enableGravity, disable = disableGravity}
}

-- 键位绑定系统
local keybinds = {
	ClickGUI = Enum.KeyCode.Rightshift,
	Speed = nil,
	HighJump = nil,
	KeepY = nil,
	WalkFling = nil,
	NoClip = nil,
	NightVision = nil,
	ESP = nil,
	WallClimb = nil,
	TP = nil,
	ClickTP = nil,
	Fly = nil,
	AirJump = nil,
	AntiWalkFling = nil,
	Sprint = nil,
	Lowhop = nil,
	Gravity = nil
}

local bindingInProgress = false
local currentBindingFeature = nil
local bindingConnection = nil

-- 开始绑定过程
local function startBinding(featureName)
	if bindingInProgress then
		notify("已有绑定任务进行中", 1.5)
		return
	end

	bindingInProgress = true
	currentBindingFeature = featureName
	notify("按下新的按键来绑定 "..featureName.."...", 2)

	bindingConnection = UIS.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end

		keybinds[currentBindingFeature] = input.KeyCode
		notify("'"..currentBindingFeature.."' 已绑定到: "..input.KeyCode.Name, 2)
		
		bindingInProgress = false
		currentBindingFeature = nil
		bindingConnection:Disconnect()
		bindingConnection = nil
	end)
end

-- 功能切换函数（按名称）
local function performToggleByName(fname)
	if fname == "ClickGUI" then
		notify("ClickGUI无需切换，通过Rightshift打开", 1.5)
		return
	end
	
	if not featureHandlers[fname] then
        notify("无效的功能: "..fname, 1.5)
        return
    end
    
	local newState = not moduleStates[fname]
	moduleStates[fname] = newState
	
	-- 确保 Speed 和 Sprint 功能不会互相冲突
    if fname == "Speed" and newState and moduleStates.Sprint then
        notify("已关闭 Sprint 功能以启用 Speed。", 1.5)
        moduleStates.Sprint = false
        featureHandlers.Sprint.disable()
        refreshButtonVisual("Sprint")
    elseif fname == "Sprint" and newState and moduleStates.Speed then
        notify("已关闭 Speed 功能以启用 Sprint。", 1.5)
        moduleStates.Speed = false
        featureHandlers.Speed.disable()
        refreshButtonVisual("Speed")
    end
    
	local handler = featureHandlers[fname]
	if newState then
		handler.enable()
	else
		handler.disable()
	end

	refreshButtonVisual(fname)
	notify(fname .. (newState and " 已启用" or " 已禁用"), 1.5)
end

-- 详情面板创建函数
local function createDetailPanel(titleText, content, inputHandler)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 300, 0, 180)
	frame.Position = UDim2.new(0.5, -150, 0.5, -90)
	frame.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Parent = playerGui
	frame.ZIndex = 10000
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(30, 30, 30)
	stroke.Transparency = 0.25

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
	title.Text = titleText
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamSemibold
	title.Parent = frame
	local dragConn = nil
	title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local initialPos = frame.Position
			local initialMousePos = UIS:GetMouseLocation()
			dragConn = UIS.InputChanged:Connect(function(input2)
				if input2.UserInputType == Enum.UserInputType.MouseMovement then
					local delta = UIS:GetMouseLocation() - initialMousePos
					frame.Position = initialPos + UDim2.new(0, delta.X, 0, delta.Y)
				end
			end)
		end
	end)
	title.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and dragConn then
			dragConn:Disconnect()
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

	local mainContent = Instance.new("Frame")
	mainContent.Size = UDim2.new(1, -10, 1, -40)
	mainContent.Position = UDim2.new(0, 5, 0, 35)
	mainContent.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
	mainContent.BorderSizePixel = 0
	mainContent.Parent = frame

	local textContent = Instance.new("TextLabel")
	textContent.Size = UDim2.new(1, 0, 1, 0)
	textContent.Text = content
	textContent.TextWrapped = true
	textContent.TextScaled = true
	textContent.TextColor3 = Color3.fromRGB(255, 255, 255)
	textContent.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
	textContent.Parent = mainContent
	
	if inputHandler then
		local inputField = Instance.new("TextBox")
		inputField.Size = UDim2.new(1, 0, 0, 30)
		inputField.Position = UDim2.new(0, 0, 0.7, 0)
		inputField.AnchorPoint = Vector2.new(0, 0.5)
		inputField.PlaceholderText = "输入新值..."
		inputField.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		inputField.TextColor3 = Color3.fromRGB(255, 255, 255)
		inputField.Font = Enum.Font.GothamSemibold
		inputField.Parent = mainContent
		inputField.FocusLost:Connect(function()
			inputHandler(inputField.Text)
		end)
	end
	
	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, 0, 0.6, 0)
	desc.Position = UDim2.new(0, 0, 0, 0)
	desc.Text = content
	desc.TextWrapped = true
	desc.TextScaled = true
	desc.TextColor3 = Color3.fromRGB(255, 255, 255)
	desc.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
	desc.Parent = mainContent
	
	return frame
end


-- 创建TP GUI函数
local function createTPGUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TP_GUI"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.DisplayOrder = 9999

	local frame = Instance.new("Frame")
	frame.Name = "Main"
	frame.Size = UDim2.new(0, 250, 0, 400)
	frame.Position = UDim2.new(1, -260, 0.5, -200)
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
	frame.BorderSizePixel = 0
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
		gui.Visible = false
		moduleStates.TP = false
		refreshButtonVisual("TP")
	end)

	local playerList = Instance.new("ScrollingFrame")
	playerList.Name = "PlayerList"
	playerList.Size = UDim2.new(1, -10, 1, -40)
	playerList.Position = UDim2.new(0, 5, 0, 35)
	playerList.BackgroundTransparency = 1
	playerList.BorderSizePixel = 0
	playerList.Parent = frame

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Padding = UDim.new(0, 5)
	listLayout.Parent = playerList

	local function refreshPlayerList()
		for _, child in ipairs(playerList:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
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
					local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if hrp then
						hrp.CFrame = targetChar.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
						notify("已传送到 "..p.Name, 2)
					end
				end)
			end
		end
	end

	refreshPlayerList()
	Players.PlayerAdded:Connect(refreshPlayerList)
	Players.PlayerRemoving:Connect(refreshPlayerList)

	return gui
end

-- 创建主GUI函数
local function createMainGUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PigGod_LiquidGui"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.DisplayOrder = 9999

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "Main"
	mainFrame.Size = UDim2.new(0, 350, 0, 400)
	mainFrame.Position = UDim2.new(0.5, -175, 0.5, -200)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
	mainFrame.BorderSizePixel = 0
	mainFrame.Active = true
	mainFrame.Parent = gui
	Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
	title.Text = "PigGod's Liquid"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Font = Enum.Font.GothamSemibold
	title.Parent = mainFrame
	local dragConn = nil
	title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local initialPos = mainFrame.Position
			local initialMousePos = UIS:GetMouseLocation()
			dragConn = UIS.InputChanged:Connect(function(input2)
				if input2.UserInputType == Enum.UserInputType.MouseMovement then
					local delta = UIS:GetMouseLocation() - initialMousePos
					mainFrame.Position = initialPos + UDim2.new(0, delta.X, 0, delta.Y)
				end
			end)
		end
	end)
	title.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and dragConn then
			dragConn:Disconnect()
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
		gui.Visible = false
	end)

	local tabList = Instance.new("ScrollingFrame")
	tabList.Name = "TabList"
	tabList.Size = UDim2.new(0, 100, 1, -30)
	tabList.Position = UDim2.new(0, 0, 0, 30)
	tabList.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	tabList.BorderSizePixel = 0
	tabList.Parent = mainFrame
	local tabListLayout = Instance.new("UIListLayout")
	tabListLayout.Padding = UDim.new(0, 5)
	tabListLayout.Parent = tabList

	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, -100, 1, -30)
	contentFrame.Position = UDim2.new(0, 100, 0, 30)
	contentFrame.BackgroundTransparency = 1
	contentFrame.BorderSizePixel = 0
	contentFrame.Parent = mainFrame

	local CategoryFeatureMap = {
		Movement = {"NoClip", "Speed", "HighJump", "KeepY", "Fly", "AirJump", "WallClimb", "Sprint", "Lowhop", "Gravity"},
		Visual = {"NightVision", "ESP"},
		Exploits = {"WalkFling", "TP", "ClickTP"},
		Player = {"AntiWalkFling"},
		Misc = {"ClickGUI"}
	}
	
	local lastActiveTab = nil

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
			featureBtn.BackgroundColor3 = moduleStates[featureName] and Color3.fromRGB(10, 100, 200) or Color3.fromRGB(60, 60, 60)
			featureBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			featureBtn.Font = Enum.Font.GothamSemibold
			featureBtn.Text = featureName
			featureBtn.TextScaled = true
			featureBtn.Parent = buttonFrame
			featureBtn.Activated:Connect(function()
				performToggleByName(featureName)
			end)
			
			featureBtn.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton2 then
					startBinding(featureName)
				end
			end)

			featureButtonRefs[featureName] = { button = featureBtn, frame = buttonFrame }
			
			if featureName == "Speed" or featureName == "HighJump" or featureName == "Fly" or featureName == "Gravity" then
				local inputField = Instance.new("TextBox")
				inputField.Size = UDim2.new(0, 60, 1, 0)
				inputField.Position = UDim2.new(0, 160, 0, 0)
				inputField.PlaceholderText = "Value"
				inputField.Text = tostring(featureName == "Speed" and currentSpeed or featureName == "HighJump" and currentJumpPower or featureName == "Fly" and currentFlySpeed or currentGravity)
				inputField.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
				inputField.TextColor3 = Color3.fromRGB(255, 255, 255)
				inputField.TextScaled = true
				inputField.Font = Enum.Font.GothamSemibold
				inputField.Parent = buttonFrame
				inputField.FocusLost:Connect(function()
					local value = tonumber(inputField.Text)
					if featureName == "Speed" then setSpeed(value)
					elseif featureName == "HighJump" then setJumpPower(value)
					elseif featureName == "Fly" then setFlySpeed(value)
					elseif featureName == "Gravity" then setGravity(value)
					end
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
				local inputHandler = nil
				if featureName == "NoClip" then contentText = "启用后可以穿过墙壁和障碍物。中键点击按钮进行键位绑定。"
				elseif featureName == "Speed" then contentText = "调整行走速度。输入框可以设置新的速度值 (1-500)。"
				elseif featureName == "HighJump" then contentText = "调整跳跃高度。输入框可以设置新的跳跃力 (1-200)。"
				elseif featureName == "KeepY" then contentText = "启用后将锁定角色的Y轴高度，防止掉落。"
				elseif featureName == "Fly" then contentText = "启用后可自由飞行，WASD移动，空格上升，shift下降。输入框可设置飞行速度 (1-300)。"
				elseif featureName == "AirJump" then contentText = "启用后可以在空中无限次跳跃。"
				elseif featureName == "WallClimb" then contentText = "启用后靠近墙壁时会自动攀爬。"
				elseif featureName == "Sprint" then contentText = "启用后角色的行走速度会提升到疾跑速度。"
				elseif featureName == "Lowhop" then contentText = "启用后将自动进行超低跳跃，通过节省下落时间来获得Hop速度加成。"
				elseif featureName == "NightVision" then contentText = "启用后游戏亮度将最大化，可以清晰看到黑暗区域。"
				elseif featureName == "ESP" then contentText = "启用后将高亮显示其他玩家，即使隔着障碍物也能看到。"
				elseif featureName == "WalkFling" then contentText = "利用移动时的物理惯性将周围玩家甩飞。"
				elseif featureName == "TP" then contentText = "打开一个列表，可以选择其他玩家进行传送。"
				elseif featureName == "ClickTP" then contentText = "启用后，鼠标左键点击任意地方即可瞬移到该位置。"
				elseif featureName == "AntiWalkFling" then contentText = "防止被其他玩家的甩飞功能影响。"
				elseif featureName == "ClickGUI" then contentText = "默认按键 'Rightshift' 用于打开/关闭GUI面板。"
				elseif featureName == "Gravity" then
					contentText = "调整游戏世界的重力。默认重力值为 196.2。"
					inputHandler = setGravity
				end
				createDetailPanel(titleText, contentText, inputHandler)
			end)
		end
	end
	
	for categoryName, features in pairs(CategoryFeatureMap) do
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

-- 初始化函数
local function init()
	tpMainFrame = createTPGUI()
	tpMainFrame.Visible = false
	mainGUI = createMainGUI()
	mainGUI.Visible = false
	
	local endKeyIsDown = false
	local unlockNotified = false
	local lastMouseLockState = nil

	UIS.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.End then
			endKeyIsDown = true
			if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then
				-- 只有在鼠标未解锁时才保存状态并解锁
				if lastMouseLockState == nil then
					lastMouseLockState = UIS.MouseBehavior
				end
				UIS.MouseBehavior = Enum.MouseBehavior.Default
				if not unlockNotified then
					notify("已长按'End'键解锁鼠标，点击空白区域重新锁定", 2)
					unlockNotified = true
				end
			end
		end
		
		if gameProcessed then return end
		if input.KeyCode == keybinds.ClickGUI then
			mainGUI.Visible = not mainGUI.Visible
			if mainGUI.Visible then
				isViewUnlocked = true
				createAndEquipViewControlTool()
			else
				isViewUnlocked = false
			end
		end
		
		-- 新增：点击空白区域重新锁定鼠标
		if input.UserInputType == Enum.UserInputType.MouseButton1 and UIS.MouseBehavior == Enum.MouseBehavior.Default and not gameProcessed then
			if lastMouseLockState then
				UIS.MouseBehavior = lastMouseLockState
				lastMouseLockState = nil
				unlockNotified = false
				notify("鼠标已恢复锁定", 1.5)
			end
		end
	end)
	
	UIS.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.End then
			endKeyIsDown = false
		end
	end)

	UIS.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or bindingInProgress then return end
		for fname, kcode in pairs(keybinds) do
			if kcode == input.KeyCode and fname ~= "ClickGUI" and fname ~= "End" then
				performToggleByName(fname)
				return
			end
		end
	end)
	
	-- 首次加载时创建工具
    createAndEquipViewControlTool()
	
	notify("客户端初始化完成！默认快捷键: Rightshift", 3)
end

-- 启动初始化
local success, err = pcall(init)
if not success then
	warn("Initialization failed: " .. err)
	notify("客户端初始化失败。请检查控制台。", 5)
end
