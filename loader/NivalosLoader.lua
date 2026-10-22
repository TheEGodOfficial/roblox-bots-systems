--// Nivalos's Loader
--// Usage:
--//   local Loader = loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/loader/NivalosLoader.lua"))()
--//   Loader:AddButton("Hello", function() print("hi") end)

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local GUI_NAME = "NivalosLoader"
local WIDTH = 280
local TITLE_H = 46
local PAD = 10
local BTN_H = 38
local MAX_LIST_H = 300

local THEME = {
	Background = Color3.fromRGB(22, 22, 28),
	Stroke = Color3.fromRGB(60, 60, 78),
	Title = Color3.fromRGB(240, 240, 250),
	Button = Color3.fromRGB(38, 38, 50),
	ButtonHover = Color3.fromRGB(56, 56, 76),
	ButtonText = Color3.fromRGB(225, 225, 240),
}

local function tween(obj, info, props)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

local function protectedParent(gui)
	-- Try gethui, then CoreGui, then PlayerGui
	local ok = pcall(function()
		gui.Parent = if gethui then gethui() elseif cloneref then cloneref(game:GetService("CoreGui")) else game:GetService("CoreGui")
	end)
	if not ok or not gui.Parent then
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
end

local Loader = {}
local state -- holds the live UI refs, nil when closed

local function build()
	-- Remove any old copy
	for _, root in ipairs({ (gethui and gethui()) or nil, game:GetService("CoreGui"), Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui") }) do
		pcall(function()
			local old = root and root:FindFirstChild(GUI_NAME)
			if old then old:Destroy() end
		end)
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 999
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	protectedParent(gui)

	local main = Instance.new("CanvasGroup")
	main.Name = "Main"
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Position = UDim2.fromScale(0.5, 0.5)
	main.Size = UDim2.fromOffset(WIDTH, TITLE_H + PAD)
	main.BackgroundColor3 = THEME.Background
	main.BorderSizePixel = 0
	main.GroupTransparency = 1
	main.Parent = gui

	Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)

	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.Stroke
	stroke.Thickness = 1.2
	stroke.Parent = main

	local scale = Instance.new("UIScale")
	scale.Scale = 0.8
	scale.Parent = main

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, TITLE_H)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "Nivalos's Loader"
	title.TextColor3 = THEME.Title
	title.TextSize = 18
	title.Active = true
	title.Parent = main

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(PAD, TITLE_H)
	list.Size = UDim2.new(1, -PAD * 2, 0, 0)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 3
	list.ScrollBarImageColor3 = THEME.Stroke
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Parent = main

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	state = {
		gui = gui,
		main = main,
		scale = scale,
		list = list,
		layout = layout,
		title = title,
		conns = {},
		closing = false,
		count = 0,
	}

	-- Dynamic sizing
	local function resize()
		local contentH = layout.AbsoluteContentSize.Y
		local listH = math.min(contentH, MAX_LIST_H)
		list.Size = UDim2.new(1, -PAD * 2, 0, listH)
		tween(main, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(WIDTH, TITLE_H + listH + PAD),
		})
	end
	table.insert(state.conns, layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize))

	-- Dragging (mouse + touch)
	local dragging, dragStart, startPos
	table.insert(state.conns, title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end))
	table.insert(state.conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))

	-- Opening animation
	tween(main, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 })
	tween(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
end

function Loader:Close()
	local s = state
	if not s or s.closing then return end
	s.closing = true

	tween(s.scale, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.9 })
	local fade = tween(s.main, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })

	fade.Completed:Once(function()
		for _, c in ipairs(s.conns) do c:Disconnect() end
		s.gui:Destroy()
		if state == s then state = nil end
	end)
end

function Loader:AddButton(text, callback)
	if not state or state.closing then
		build()
	end
	local s = state
	s.count += 1

	local btn = Instance.new("TextButton")
	btn.Name = "Btn_" .. tostring(text)
	btn.LayoutOrder = s.count
	btn.Size = UDim2.new(1, -(s.list.ScrollBarThickness + 2), 0, BTN_H)
	btn.BackgroundColor3 = THEME.Button
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamMedium
	btn.Text = tostring(text)
	btn.TextColor3 = THEME.ButtonText
	btn.TextSize = 15
	btn.Parent = s.list

	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 9)

	local hoverInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	btn.MouseEnter:Connect(function()
		tween(btn, hoverInfo, { BackgroundColor3 = THEME.ButtonHover })
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, hoverInfo, { BackgroundColor3 = THEME.Button })
	end)

	btn.MouseButton1Click:Connect(function()
		if s.closing then return end
		Loader:Close()
		if typeof(callback) == "function" then
			task.spawn(function()
				local ok, err = pcall(callback)
				if not ok then
					warn("[Nivalos's Loader] Button '" .. tostring(text) .. "' errored: " .. tostring(err))
				end
			end)
		end
	end)

	return btn
end

return Loader
