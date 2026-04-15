local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Mouse = Players.LocalPlayer:GetMouse()
local player = Players.LocalPlayer

local settingsFile = "nyx_lpiscript.json"
local minimizeKey = Enum.KeyCode.P
local hideKey = Enum.KeyCode.H
local recenterKey = Enum.KeyCode.R
local recenterEnabled = true

if isfile(settingsFile) then
	local ok2, loaded = pcall(function()
		return game:GetService("HttpService"):JSONDecode(readfile(settingsFile))
	end)
	if ok2 then
		minimizeKey = Enum.KeyCode[loaded.minimizeKey] or minimizeKey
		hideKey = Enum.KeyCode[loaded.hideKey] or hideKey
		recenterKey = Enum.KeyCode[loaded.recenterKey] or recenterKey
		recenterEnabled = loaded.recenterEnabled ~= nil and loaded.recenterEnabled
	end
end

local function saveSettings()
	local d = {
		minimizeKey = tostring(minimizeKey):gsub("Enum.KeyCode.", ""),
		hideKey = tostring(hideKey):gsub("Enum.KeyCode.", ""),
		recenterKey = tostring(recenterKey):gsub("Enum.KeyCode.", ""),
		recenterEnabled = recenterEnabled,
	}
	writefile(settingsFile, game:GetService("HttpService"):JSONEncode(d))
end



local activeTab = nil
local minimized = false
local hidden = false
local dragging = false
local dragOffset = Vector2.new(0, 0)
local currentPos = Vector2.new(0, 0)
local targetPos = Vector2.new(0, 0)
local listenKey = false
local ignoreNext = {}
local originalTransparencies = {}
local strokes = {}
local accent = Color3.fromRGB(65, 105, 195)
local openDropdown = nil

local function tween(obj, props, t, style, dir)
	TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props):Play()
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

local function pad(parent, top, right, bottom, left)
	local p = Instance.new("UIPadding")
	p.PaddingTop    = UDim.new(0, top    or 0)
	p.PaddingRight  = UDim.new(0, right  or top or 0)
	p.PaddingBottom = UDim.new(0, bottom or top or 0)
	p.PaddingLeft   = UDim.new(0, left   or right or top or 0)
	p.Parent = parent
	return p
end

local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 500, 0, 400)
main.Position = UDim2.new(0.5, -250, 0.5, -200)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
corner(main, 8)

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 35)
top.BackgroundColor3 = Color3.fromRGB(9, 9, 14)
top.BorderSizePixel = 0
top.ZIndex = 2
top.Parent = main
corner(top, 8)

local topCornerOverride = Instance.new("Frame")
topCornerOverride.Size = UDim2.new(1, 0, 0, 8)
topCornerOverride.Position = UDim2.new(0, 0, 1, -8)
topCornerOverride.BackgroundColor3 = Color3.fromRGB(9, 9, 14)
topCornerOverride.BorderSizePixel = 0
topCornerOverride.ZIndex = 2
topCornerOverride.Parent = top
topCornerOverride.Visible = not minimized

local topFill = Instance.new("Frame")
topFill.Size = UDim2.new(1, 0, 0, 8)
topFill.Position = UDim2.new(0, 0, 1, -8)
topFill.BackgroundColor3 = Color3.fromRGB(9, 9, 14)
topFill.BorderSizePixel = 0
topFill.ZIndex = 2
topFill.Parent = top

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 200, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.RichText = true
titleLabel.Text = string.format("<font color='#666666'>v%d</font> <font color='#ffffff'>nyx lpi ui</font>", ver)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.Arial
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextStrokeTransparency = 1
titleLabel.ZIndex = 3
titleLabel.Parent = top

local minBtn = Instance.new("TextButton")
minBtn.Text = "−"
minBtn.Size = UDim2.new(0, 40, 1, 0)
minBtn.Position = UDim2.new(1, -80, 0, 0)
minBtn.BackgroundTransparency = 1
minBtn.TextColor3 = Color3.fromRGB(170, 170, 180)
minBtn.TextSize = 18
minBtn.Font = Enum.Font.Arial
minBtn.ZIndex = 3
minBtn.TextStrokeTransparency = 1
minBtn.AutoButtonColor = false
minBtn.Parent = top

local closeBtn = Instance.new("TextButton")
closeBtn.Text = "×"
closeBtn.Size = UDim2.new(0, 40, 1, 0)
closeBtn.Position = UDim2.new(1, -40, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.TextColor3 = Color3.fromRGB(170, 170, 180)
closeBtn.TextSize = 20
closeBtn.Font = Enum.Font.Arial
closeBtn.ZIndex = 3
closeBtn.TextStrokeTransparency = 1
closeBtn.AutoButtonColor = false
closeBtn.Parent = top

local container = Instance.new("Frame")
container.Size = UDim2.new(1, 0, 1, -35)
container.Position = UDim2.new(0, 0, 0, 35)
container.BackgroundTransparency = 1
container.Parent = main

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 120, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(12, 12, 19)
sidebar.BorderSizePixel = 0
sidebar.Parent = container
corner(sidebar, 8)

local sideFillTopStrip = Instance.new("Frame")
sideFillTopStrip.Size = UDim2.new(1, 0, 0, 8)
sideFillTopStrip.BackgroundColor3 = Color3.fromRGB(12, 12, 19)
sideFillTopStrip.BorderSizePixel = 0
sideFillTopStrip.Parent = sidebar

local sideFillRightStrip = Instance.new("Frame")
sideFillRightStrip.Size = UDim2.new(0, 8, 1, 0)
sideFillRightStrip.Position = UDim2.new(1, -8, 0, 0)
sideFillRightStrip.BackgroundColor3 = Color3.fromRGB(12, 12, 19)
sideFillRightStrip.BorderSizePixel = 0
sideFillRightStrip.Parent = sidebar

local sideScroll = Instance.new("ScrollingFrame")
sideScroll.Size = UDim2.new(1, 0, 1, 0)
sideScroll.BackgroundTransparency = 1
sideScroll.BorderSizePixel = 0
sideScroll.ScrollBarThickness = 0
sideScroll.ScrollBarImageTransparency = 1
sideScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
sideScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
sideScroll.Parent = sidebar

local sideList = Instance.new("UIListLayout")
sideList.SortOrder = Enum.SortOrder.LayoutOrder
sideList.FillDirection = Enum.FillDirection.Vertical
sideList.HorizontalAlignment = Enum.HorizontalAlignment.Left
sideList.VerticalAlignment = Enum.VerticalAlignment.Top
sideList.Padding = UDim.new(0, 0)
sideList.Parent = sideScroll

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -120, 1, 0)
content.Position = UDim2.new(0, 120, 0, 0)
content.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
content.BorderSizePixel = 0
content.Parent = container
corner(content, 8)

local contentFillTop = Instance.new("Frame")
contentFillTop.Size = UDim2.new(1, 0, 0, 8)
contentFillTop.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
contentFillTop.BorderSizePixel = 0
contentFillTop.Parent = content

local contentFillLeft = Instance.new("Frame")
contentFillLeft.Size = UDim2.new(0, 8, 1, 0)
contentFillLeft.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
contentFillLeft.BorderSizePixel = 0
contentFillLeft.Parent = content

local tabs = {}

local function animateTabIn(scroll)
	local items = {}
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("GuiObject") and child.ClassName ~= "UIListLayout" and child.ClassName ~= "UIPadding" then
			table.insert(items, child)
		end
	end
	table.sort(items, function(a, b) return (a.LayoutOrder or 0) < (b.LayoutOrder or 0) end)

	for i, item in ipairs(items) do
		local orig = originalTransparencies[item] or { bg = item.BackgroundTransparency }
		local origPos = item.Position

		item.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset, origPos.Y.Scale, origPos.Y.Offset + 14)
		item.BackgroundTransparency = 1

		if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
			item.TextTransparency = 1
		end
		if item:IsA("ImageLabel") or item:IsA("ImageButton") then
			item.ImageTransparency = 1
		end
		if strokes[item] then
			strokes[item].Transparency = 1
		end

		for _, desc in ipairs(item:GetDescendants()) do
			if desc:IsA("GuiObject") then
				local dOrig = originalTransparencies[desc] or { bg = desc.BackgroundTransparency }

				desc.BackgroundTransparency = 1

				if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
					desc.TextTransparency = 1
				end
				if desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
					desc.ImageTransparency = 1
				end
				if strokes[desc] then
					strokes[desc].Transparency = 1
				end
			end
		end

		task.delay(i * 0.035, function()
			if not item or not item.Parent then return end

			tween(item, {
				Position = origPos,
				BackgroundTransparency = orig.bg or 0
			}, 0.28, Enum.EasingStyle.Quint)

			if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
				tween(item, { TextTransparency = orig.text or 0 }, 0.28)
			end
			if item:IsA("ImageLabel") or item:IsA("ImageButton") then
				tween(item, { ImageTransparency = 0 }, 0.28)
			end
			if strokes[item] then
				tween(strokes[item], { Transparency = 0 }, 0.28)
			end

			for _, desc in ipairs(item:GetDescendants()) do
				if desc:IsA("GuiObject") then
					local dOrig = originalTransparencies[desc] or { bg = desc.BackgroundTransparency }

					tween(desc, { BackgroundTransparency = dOrig.bg or 0 }, 0.28)

					if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
						tween(desc, { TextTransparency = dOrig.text or 0 }, 0.28)
					end
					if desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
						tween(desc, { ImageTransparency = 0 }, 0.28)
					end
					if strokes[desc] then
						tween(strokes[desc], { Transparency = 0 }, 0.28)
					end
				end
			end
		end)
	end
end

local function addTab(name, iconId)
	local btn = Instance.new("ImageButton")
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.BackgroundColor3 = Color3.fromRGB(12, 12, 19)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.LayoutOrder = #tabs + 1
	btn.Parent = sideScroll

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 18, 0, 18)
	icon.Position = UDim2.new(0, 12, 0.5, -9)
	icon.BackgroundTransparency = 1
	icon.Image = "rbxassetid://" .. tostring(iconId or 0)
	icon.ImageColor3 = Color3.fromRGB(160, 160, 175)
	icon.Parent = btn

	local lbl = Instance.new("TextLabel")
	lbl.Text = name
	lbl.Size = UDim2.new(1, -42, 1, 0)
	lbl.Position = UDim2.new(0, 42, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(160, 160, 175)
	lbl.TextSize = 12
	lbl.Font = Enum.Font.Arial
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextStrokeTransparency = 1
	lbl.Parent = btn

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 0
	scroll.ScrollBarImageTransparency = 1
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Visible = false
	scroll.Parent = content

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.Padding = UDim.new(0, 6)
	list.Parent = scroll

	local innerPad = Instance.new("UIPadding")
	innerPad.PaddingTop = UDim.new(0, 12)
	innerPad.PaddingLeft = UDim.new(0, 12)
	innerPad.PaddingRight = UDim.new(0, 12)
	innerPad.PaddingBottom = UDim.new(0, 12)
	innerPad.Parent = scroll

	local tab = { name = name, scroll = scroll, btn = btn, icon = icon, lbl = lbl }
	table.insert(tabs, tab)

	btn.MouseButton1Click:Connect(function()
		if activeTab == tab then return end
		activeTab = tab

		for _, t in ipairs(tabs) do
			t.scroll.Visible = false
			t.btn.BackgroundColor3 = Color3.fromRGB(12, 12, 19)
			t.lbl.TextColor3 = Color3.fromRGB(160, 160, 175)
			t.icon.ImageColor3 = Color3.fromRGB(160, 160, 175)
		end

		scroll.Visible = true
		btn.BackgroundColor3 = accent
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		icon.ImageColor3 = Color3.fromRGB(255, 255, 255)

		task.defer(function()
			animateTabIn(scroll)
		end)
	end)

	return scroll, list
end

local function setActiveTab(name)
	for _, t in ipairs(tabs) do
		if t.name == name then
			activeTab = t
		end
		local active = t.name == name
		t.scroll.Visible = active
		t.btn.BackgroundColor3 = active and accent or Color3.fromRGB(12, 12, 19)
		t.lbl.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 175)
		t.icon.ImageColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 175)
	end
end

local function setActiveTab(name)
	for _, t in ipairs(tabs) do
		local active = t.name == name
		t.scroll.Visible = active
		t.btn.BackgroundColor3 = active and accent or Color3.fromRGB(12, 12, 19)
		t.lbl.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 175)
		t.icon.ImageColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 175)
	end
end

local function addDivider(parent, layoutOrder)
	local wrap = Instance.new("Frame")
	wrap.Size = UDim2.new(1, 0, 0, 14)
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder = layoutOrder or 0
	wrap.Parent = parent
	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, -8, 0, 1)
	line.Position = UDim2.new(0, 4, 0.5, 0)
	line.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	line.BorderSizePixel = 0
	line.Parent = wrap
	return wrap
end

local function addSubnote(parent, layoutOrder, text)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 0)
	lbl.AutomaticSize = Enum.AutomaticSize.Y
	lbl.BackgroundTransparency = 1
	lbl.Text = text or ""
	lbl.RichText = true
	lbl.TextSize = 11
	lbl.Font = Enum.Font.Arial
	lbl.TextColor3 = Color3.fromRGB(88, 88, 105)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextWrapped = true
	lbl.TextStrokeTransparency = 1
	lbl.LayoutOrder = layoutOrder or 0
	lbl.Parent = parent
	return lbl
end

local function addSectionTitle(parent, layoutOrder, text)
	local wrap = Instance.new("Frame")
	wrap.Size = UDim2.new(1, 0, 0, 28)
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder = layoutOrder or 0
	wrap.Parent = parent
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text or ""
	lbl.TextSize = 13
	lbl.Font = Enum.Font.Arial
	lbl.TextColor3 = Color3.fromRGB(240, 240, 255)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextStrokeTransparency = 1
	lbl.Parent = wrap
	return wrap
end

local function addToggle(parent, layoutOrder, labelText, default, callback)
	local state = default == true
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 38)
	row.BackgroundColor3 = Color3.fromRGB(11, 11, 17)
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder or 0
	row.Parent = parent
	corner(row, 6)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(30, 30, 40)
	stroke.Parent = row
	strokes[row] = stroke
	local lbl = Instance.new("TextLabel")
	lbl.Text = labelText or ""
	lbl.Size = UDim2.new(1, -62, 1, 0)
	lbl.Position = UDim2.new(0, 12, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
	lbl.TextSize = 12
	lbl.Font = Enum.Font.Arial
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextStrokeTransparency = 1
	lbl.Parent = row
	local track = Instance.new("Frame")
	track.Size = UDim2.new(0, 46, 0, 24)
	track.Position = UDim2.new(1, -52, 0.5, -12)
	track.BackgroundColor3 = state and Color3.fromRGB(45, 120, 65) or Color3.fromRGB(45, 45, 58)
	track.BorderSizePixel = 0
	track.Parent = row
	corner(track, 12)
	local thumb = Instance.new("Frame")
	thumb.Size = UDim2.new(0, 18, 0, 18)
	thumb.Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.BorderSizePixel = 0
	thumb.ZIndex = 2
	thumb.Parent = track
	corner(thumb, 9)
	local hitBtn = Instance.new("TextButton")
	hitBtn.Text = ""
	hitBtn.Size = UDim2.new(1, 0, 1, 0)
	hitBtn.BackgroundTransparency = 1
	hitBtn.ZIndex = 3
	hitBtn.AutoButtonColor = false
	hitBtn.Parent = track
	local function setValue(s)
		state = s
		tween(track, { BackgroundColor3 = s and Color3.fromRGB(45, 120, 65) or Color3.fromRGB(45, 45, 58) }, 0.2)
		tween(thumb, { Position = s and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9) }, 0.2)
		if callback then callback(state) end
	end
	hitBtn.MouseButton1Click:Connect(function() setValue(not state) end)
	return row, function() return state end, setValue
end

local function addButton(parent, layoutOrder, labelText, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 38)
	row.BackgroundColor3 = Color3.fromRGB(11, 11, 17)
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder or 0
	row.Parent = parent
	corner(row, 6)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(30, 30, 40)
	stroke.Parent = row
	strokes[row] = stroke
	local lbl = Instance.new("TextLabel")
	lbl.Text = labelText or "Button"
	lbl.Size = UDim2.new(1, -70, 1, 0)
	lbl.Position = UDim2.new(0, 12, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
	lbl.TextSize = 12
	lbl.Font = Enum.Font.Arial
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextStrokeTransparency = 1
	lbl.Parent = row
	local tag = Instance.new("TextLabel")
	tag.Text = "Button"
	tag.Size = UDim2.new(0, 52, 1, 0)
	tag.Position = UDim2.new(1, -58, 0, 0)
	tag.BackgroundTransparency = 1
	tag.TextColor3 = Color3.fromRGB(85, 85, 102)
	tag.TextSize = 11
	tag.Font = Enum.Font.Arial
	tag.TextXAlignment = Enum.TextXAlignment.Right
	tag.TextStrokeTransparency = 1
	tag.Parent = row
	local hitBtn = Instance.new("TextButton")
	hitBtn.Text = ""
	hitBtn.Size = UDim2.new(1, 0, 1, 0)
	hitBtn.BackgroundTransparency = 1
	hitBtn.ZIndex = 3
	hitBtn.AutoButtonColor = false
	hitBtn.Parent = row
	hitBtn.MouseButton1Click:Connect(function()
		if callback then callback() end
	end)
	return row
end

local function addInput(parent, layoutOrder, labelText, placeholder, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 38)
	row.BackgroundColor3 = Color3.fromRGB(11, 11, 17)
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder or 0
	row.Parent = parent
	corner(row, 6)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(30, 30, 40)
	stroke.Parent = row
	strokes[row] = stroke

	local lbl = Instance.new("TextLabel")
	lbl.Text = labelText or ""
	lbl.Size = UDim2.new(0.45, -12, 1, 0)
	lbl.Position = UDim2.new(0, 12, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
	lbl.TextSize = 12
	lbl.Font = Enum.Font.Arial
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextStrokeTransparency = 1
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.Parent = row

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.55, -12, 0, 24)
	box.Position = UDim2.new(0.45, 0, 0.5, -12)
	box.BackgroundColor3 = Color3.fromRGB(19, 19, 28)
	box.BorderSizePixel = 0
	box.TextColor3 = Color3.fromRGB(218, 218, 232)
	box.PlaceholderText = placeholder or ""
	box.PlaceholderColor3 = Color3.fromRGB(65, 65, 82)
	box.TextSize = 12
	box.Font = Enum.Font.Arial
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClearTextOnFocus = false
	box.TextStrokeTransparency = 1
	box.Parent = row
	corner(box, 5)
	pad(box, 0, 8, 0, 8)

	local boxStroke = Instance.new("UIStroke")
	boxStroke.Thickness = 1
	boxStroke.Color = Color3.fromRGB(35, 35, 48)
	boxStroke.Parent = box

	box.Focused:Connect(function()
		
		tween(box, { Size = UDim2.new(0.65, -12, 0, 24) }, 0.15)
		tween(box, { Position = UDim2.new(0.35, 0, 0.5, -12) }, 0.15)
		tween(lbl, { Size = UDim2.new(0.33, -12, 1, 0) }, 0.15)
	end)
	box.FocusLost:Connect(function(enter)
		
		tween(box, { Size = UDim2.new(0.55, -12, 0, 24) }, 0.15)
		tween(box, { Position = UDim2.new(0.45, 0, 0.5, -12) }, 0.15)
		tween(lbl, { Size = UDim2.new(0.45, -12, 1, 0) }, 0.15)
		if callback then callback(box.Text, enter) end
	end)

	return row, box
end

local function addSlider(parent, layoutOrder, labelText, minVal, maxVal, default, callback)
	minVal  = minVal  or 0
	maxVal  = maxVal  or 100
	default = math.clamp(default or minVal, minVal, maxVal)
	local value = default
	local draggingSlider = false
	local visualT = (value - minVal) / (maxVal - minVal)
	local targetT  = visualT

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 38)
	row.BackgroundColor3 = Color3.fromRGB(11, 11, 17)
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder or 0
	row.Parent = parent
	corner(row, 6)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(30, 30, 40)
	stroke.Parent = row
	strokes[row] = stroke

	local lbl = Instance.new("TextLabel")
	lbl.Text = labelText or ""
	lbl.Size = UDim2.new(0.38, -12, 1, 0)
	lbl.Position = UDim2.new(0, 12, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
	lbl.TextSize = 12
	lbl.Font = Enum.Font.Arial
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextStrokeTransparency = 1
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.Parent = row

	local valLbl = Instance.new("TextLabel")
	valLbl.Text = tostring(math.round(value))
	valLbl.Size = UDim2.new(0, 32, 1, 0)
	valLbl.Position = UDim2.new(1, -52, 0, 0)
	valLbl.BackgroundTransparency = 1
	valLbl.TextColor3 = Color3.fromRGB(110, 110, 125)
	valLbl.TextSize = 11
	valLbl.Font = Enum.Font.Arial
	valLbl.TextXAlignment = Enum.TextXAlignment.Right
	valLbl.TextStrokeTransparency = 1
	valLbl.Parent = row

	local track = Instance.new("Frame")
	track.Size = UDim2.new(0.58, -44, 0, 12)
	track.Position = UDim2.new(0.38, 0, 0.5, -6)
	track.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
	track.BorderSizePixel = 0
	track.Parent = row
	corner(track, 6)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(visualT, 0, 1, 0)
	fill.BackgroundColor3 = accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 6)

	local hitbox = Instance.new("TextButton")
	hitbox.Text = ""
	hitbox.Size = UDim2.new(1, 0, 0, 28)
	hitbox.Position = UDim2.new(0, 0, 0.5, -14)
	hitbox.BackgroundTransparency = 1
	hitbox.ZIndex = 4
	hitbox.AutoButtonColor = false
	hitbox.Parent = track

	local function applyValue(absX)
		local abs = track.AbsolutePosition
		local sz  = track.AbsoluteSize
		local t   = math.clamp((absX - abs.X) / sz.X, 0, 1)
		targetT = t
		value = math.round(minVal + t * (maxVal - minVal))
		valLbl.Text = tostring(value)
		if callback then callback(value) end
	end

	hitbox.MouseButton1Down:Connect(function()
		draggingSlider = true
		tween(track, { Size = UDim2.new(0.58, -44, 0, 16) }, 0.12)
		tween(track, { Position = UDim2.new(0.38, 0, 0.5, -8) }, 0.12)
		applyValue(Mouse.X)
	end)

	UserInputService.InputChanged:Connect(function(input)
		if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
			applyValue(Mouse.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and draggingSlider then
			draggingSlider = false
			tween(track, { Size = UDim2.new(0.58, -44, 0, 12) }, 0.15)
			tween(track, { Position = UDim2.new(0.38, 0, 0.5, -6) }, 0.15)
		end
	end)

	RunService.RenderStepped:Connect(function()
		visualT = visualT + (targetT - visualT) * 0.18
		fill.Size = UDim2.new(visualT, 0, 1, 0)
	end)

	return row, function() return value end
end

local function addMultiDropdown(parent, layoutOrder, labelText, options, callback)
	options = options or {}
	local selected = {}
	local open = false
	local hoveringList = false
	local hoveringBtn = false
	local ITEM_H = 28
	local MAX_VIS = 6
	local LIST_H = math.min(#options + 3, MAX_VIS) * ITEM_H

	local function count(t)
		local n = 0
		for _ in pairs(t) do n += 1 end
		return n
	end

	local function trimText(str)
		if #str > 23 then
			return string.sub(str, 1, 23) .. "..."
		end
		return str
	end

	local function updateText(btn)
		local t = {}
		for k in pairs(selected) do table.insert(t, k) end
		local txt = #t == 0 and "None" or table.concat(t, ", ")
		btn.Text = trimText(txt)
	end

	local wrap = Instance.new("Frame")
	wrap.Size = UDim2.new(1, 0, 0, 38)
	wrap.BackgroundColor3 = Color3.fromRGB(11, 11, 17)
	wrap.BorderSizePixel = 0
	wrap.LayoutOrder = layoutOrder or 0
	wrap.Parent = parent
	corner(wrap, 6)

	local rowLbl = Instance.new("TextLabel")
	rowLbl.Text = labelText or ""
	rowLbl.Size = UDim2.new(0.38, -12, 1, 0)
	rowLbl.Position = UDim2.new(0, 12, 0, 0)
	rowLbl.BackgroundTransparency = 1
	rowLbl.TextColor3 = Color3.fromRGB(180, 180, 200)
	rowLbl.TextSize = 12
	rowLbl.Font = Enum.Font.Arial
	rowLbl.TextXAlignment = Enum.TextXAlignment.Left
	rowLbl.Parent = wrap

	local dropBtn = Instance.new("TextButton")
	dropBtn.Size = UDim2.new(0.58, 0, 0, 26)
	dropBtn.Position = UDim2.new(0.42, 0, 0.5, -13)
	dropBtn.BackgroundTransparency = 1
	dropBtn.BorderSizePixel = 0
	dropBtn.TextColor3 = Color3.fromRGB(218, 218, 232)
	dropBtn.TextSize = 12
	dropBtn.Font = Enum.Font.Arial
	dropBtn.TextXAlignment = Enum.TextXAlignment.Left
	dropBtn.Text = "None"
	dropBtn.ClipsDescendants = true
	dropBtn.ZIndex = 10
	dropBtn.Parent = wrap
	corner(dropBtn, 5)
	pad(dropBtn, 0, 24, 0, 10)

	local arrow = Instance.new("ImageLabel")
	arrow.Image = "rbxassetid://13184099706"
	arrow.Size = UDim2.new(0, 10, 0, 10)
	arrow.Position = UDim2.new(1, 0, 0.5, -7)
	arrow.BackgroundTransparency = 1
	arrow.ImageColor3 = Color3.fromRGB(105, 105, 125)
	arrow.ZIndex = 11
	arrow.Parent = dropBtn

	local listFrame = Instance.new("Frame")
	listFrame.BackgroundColor3 = Color3.fromRGB(17, 17, 25)
	listFrame.BorderSizePixel = 0
	listFrame.ZIndex = 60
	listFrame.Visible = false
	listFrame.ClipsDescendants = true
	listFrame.Size = UDim2.new(0, 0, 0, 0)
	listFrame.Parent = gui
	corner(listFrame, 5)

	local listScroll = Instance.new("ScrollingFrame")
	listScroll.Size = UDim2.new(1, 0, 1, 0)
	listScroll.BackgroundTransparency = 1
	listScroll.BorderSizePixel = 0
	listScroll.ScrollBarThickness = 4
	listScroll.CanvasSize = UDim2.new(0, 0, 0, (#options + 3) * ITEM_H)
	listScroll.ZIndex = 62
	listScroll.Parent = listFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = listScroll

	local function refreshButtons(btns)
		for _, b in ipairs(btns) do
			b.BackgroundColor3 = selected[b.Text] and Color3.fromRGB(28, 28, 52) or Color3.fromRGB(17, 17, 25)
		end
	end

	local function makeAction(text, fn, order)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, 0, 0, ITEM_H)
		b.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
		b.BorderSizePixel = 0
		b.TextColor3 = Color3.fromRGB(160, 160, 200)
		b.TextSize = 12
		b.Font = Enum.Font.Arial
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Text = text
		b.LayoutOrder = order
		b.ZIndex = 63
		b.Parent = listScroll
		pad(b, 0, 0, 0, 10)
		b.MouseButton1Click:Connect(function()
			fn()
			updateText(dropBtn)
			refreshButtons(optBtns)
			if callback then callback(selected) end
		end)
	end

	makeAction("Select All", function()
		if count(selected) == #options then
			selected = {}
		else
			selected = {}
			for _, v in ipairs(options) do selected[v] = true end
		end
	end, 0)

	makeAction("Others", function()
		local me = player.Name
		if count(selected) == (#options - 1) then
			selected = {}
		else
			selected = {}
			for _, v in ipairs(options) do
				if v ~= me then selected[v] = true end
			end
		end
	end, 1)

	makeAction("Clear", function()
		selected = {}
	end, 2)

	local optBtns = {}
	for i, opt in ipairs(options) do
		local ob = Instance.new("TextButton")
		ob.Size = UDim2.new(1, 0, 0, ITEM_H)
		ob.BackgroundColor3 = Color3.fromRGB(17, 17, 25)
		ob.BorderSizePixel = 0
		ob.TextColor3 = Color3.fromRGB(200, 200, 215)
		ob.TextSize = 12
		ob.Font = Enum.Font.Arial
		ob.TextXAlignment = Enum.TextXAlignment.Left
		ob.Text = opt
		ob.LayoutOrder = i + 3
		ob.ZIndex = 63
		ob.Parent = listScroll
		pad(ob, 0, 0, 0, 10)

		ob.MouseButton1Click:Connect(function()
			if selected[opt] then selected[opt] = nil else selected[opt] = true end
			refreshButtons(optBtns)
			updateText(dropBtn)
			if callback then callback(selected) end
		end)

		table.insert(optBtns, ob)
	end

	local function closeThis()
		open = false
		if openDropdown == listFrame then openDropdown = nil end
		tween(listFrame, { Size = UDim2.new(0, dropBtn.AbsoluteSize.X, 0, 0) }, 0.15)
		task.delay(0.15, function() listFrame.Visible = false end)
		tween(arrow, { Rotation = 0 }, 0.2)
	end

	dropBtn.MouseEnter:Connect(function() hoveringBtn = true end)
	dropBtn.MouseLeave:Connect(function() hoveringBtn = false end)
	listFrame.MouseEnter:Connect(function() hoveringList = true end)
	listFrame.MouseLeave:Connect(function() hoveringList = false end)

	dropBtn.MouseButton1Click:Connect(function()
		if open then closeThis() return end
		open = true
		openDropdown = listFrame
		task.defer(function()
			local as = dropBtn.AbsoluteSize
			local ap = dropBtn.AbsolutePosition
			listFrame.Position = UDim2.new(0, ap.X, 0, ap.Y + as.Y - 1)
			listFrame.Size = UDim2.new(0, as.X, 0, 0)
			listFrame.Visible = true
			tween(listFrame, { Size = UDim2.new(0, as.X, 0, LIST_H) }, 0.2)
		end)
		tween(arrow, { Rotation = 180 }, 0.2)
	end)

	RunService.RenderStepped:Connect(function()
		if open and not hoveringList and not hoveringBtn then
			closeThis()
		end
	end)

	return wrap, function() return selected end
end

local function getPlayerNames()
	local t = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(t, p.Name)
	end
	return t
end

local function addDropdown(parent, layoutOrder, labelText, options, default, callback)
	options = options or {}
	local selected = default or options[1] or ""
	local open = false
	local hoveringList = false
	local hoveringBtn = false
	local ITEM_H = 28
	local MAX_VIS = 5
	local LIST_H = math.min(#options, MAX_VIS) * ITEM_H

	local wrap = Instance.new("Frame")
	wrap.Size = UDim2.new(1, 0, 0, 38)
	wrap.BackgroundColor3 = Color3.fromRGB(11, 11, 17)
	wrap.BorderSizePixel = 0
	wrap.LayoutOrder = layoutOrder or 0
	wrap.ClipsDescendants = false
	wrap.Parent = parent
	corner(wrap, 6)

	local rowLbl = Instance.new("TextLabel")
	rowLbl.Text = labelText or ""
	rowLbl.Size = UDim2.new(0.38, -12, 1, 0)
	rowLbl.Position = UDim2.new(0, 12, 0, 0)
	rowLbl.BackgroundTransparency = 1
	rowLbl.TextColor3 = Color3.fromRGB(180, 180, 200)
	rowLbl.TextSize = 12
	rowLbl.Font = Enum.Font.Arial
	rowLbl.TextXAlignment = Enum.TextXAlignment.Left
	rowLbl.TextStrokeTransparency = 1
	rowLbl.TextTruncate = Enum.TextTruncate.AtEnd
	rowLbl.Parent = wrap

	local dropBtn = Instance.new("TextButton")
	dropBtn.Size = UDim2.new(0.58, 0, 0, 26)
	dropBtn.Position = UDim2.new(0.42, 0, 0.5, -13)
	dropBtn.BackgroundTransparency = 1
	dropBtn.BorderSizePixel = 0
	dropBtn.TextColor3 = Color3.fromRGB(218, 218, 232)
	dropBtn.TextSize = 12
	dropBtn.Font = Enum.Font.Arial
	dropBtn.TextXAlignment = Enum.TextXAlignment.Left
	dropBtn.Text = selected
	dropBtn.TextStrokeTransparency = 1
	dropBtn.AutoButtonColor = false
	dropBtn.ClipsDescendants = true
	dropBtn.ZIndex = 10
	dropBtn.Parent = wrap
	corner(dropBtn, 5)
	pad(dropBtn, 0, 24, 0, 10)

	local arrow = Instance.new("ImageLabel")
	arrow.Image = "rbxassetid://13184099706"
	arrow.Size = UDim2.new(0, 10, 0, 10)
	arrow.Position = UDim2.new(1, 0, 0.5, -7)
	arrow.BackgroundTransparency = 1
	arrow.ImageColor3 = Color3.fromRGB(105, 105, 125)
	arrow.ZIndex = 11
	arrow.Parent = dropBtn

	local listFrame = Instance.new("Frame")
	listFrame.BackgroundColor3 = Color3.fromRGB(17, 17, 25)
	listFrame.BorderSizePixel = 0
	listFrame.ZIndex = 60
	listFrame.Visible = false
	listFrame.ClipsDescendants = true
	listFrame.Size = UDim2.new(0, 0, 0, 0)
	listFrame.Parent = gui
	corner(listFrame, 5)

	local listScroll = Instance.new("ScrollingFrame")
	listScroll.Size = UDim2.new(1, 0, 1, 0)
	listScroll.BackgroundTransparency = 1
	listScroll.BorderSizePixel = 0
	listScroll.ScrollBarThickness = 0
	listScroll.ScrollBarImageTransparency = 1
	listScroll.CanvasSize = UDim2.new(0, 0, 0, #options * ITEM_H)
	listScroll.ZIndex = 62
	listScroll.Parent = listFrame

	local listLayout2 = Instance.new("UIListLayout")
	listLayout2.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout2.Parent = listScroll

	local optBtns = {}
	for i, opt in ipairs(options) do
		local ob = Instance.new("TextButton")
		ob.Size = UDim2.new(1, 0, 0, ITEM_H)
		ob.BackgroundColor3 = (opt == selected) and Color3.fromRGB(28, 28, 52) or Color3.fromRGB(17, 17, 25)
		ob.BorderSizePixel = 0
		ob.TextColor3 = Color3.fromRGB(200, 200, 215)
		ob.TextSize = 12
		ob.Font = Enum.Font.Arial
		ob.TextXAlignment = Enum.TextXAlignment.Left
		ob.Text = opt
		ob.TextStrokeTransparency = 1
		ob.AutoButtonColor = false
		ob.ZIndex = 63
		ob.LayoutOrder = i
		ob.Parent = listScroll
		pad(ob, 0, 0, 0, 10)

		ob.MouseEnter:Connect(function()
			tween(ob, { BackgroundColor3 = Color3.fromRGB(30, 30, 48) }, 0.08)
		end)
		ob.MouseLeave:Connect(function()
			tween(ob, { BackgroundColor3 = (opt == selected) and Color3.fromRGB(28, 28, 52) or Color3.fromRGB(17, 17, 25) }, 0.08)
		end)
		ob.MouseButton1Click:Connect(function()
			selected = opt
			dropBtn.Text = opt
			for _, b in ipairs(optBtns) do
				b.BackgroundColor3 = (b.Text == selected) and Color3.fromRGB(28, 28, 52) or Color3.fromRGB(17, 17, 25)
			end
			open = false
			openDropdown = nil
			tween(listFrame, { Size = UDim2.new(0, dropBtn.AbsoluteSize.X, 0, 0) }, 0.15)
			task.delay(0.15, function() listFrame.Visible = false end)
			tween(arrow, { Rotation = 0 }, 0.2)
			if callback then callback(selected) end
		end)
		table.insert(optBtns, ob)
	end

	local function closeThis()
		open = false
		if openDropdown == listFrame then openDropdown = nil end
		tween(listFrame, { Size = UDim2.new(0, dropBtn.AbsoluteSize.X, 0, 0) }, 0.15)
		task.delay(0.15, function() listFrame.Visible = false end)
		tween(arrow, { Rotation = 0 }, 0.2)
	end

	dropBtn.MouseEnter:Connect(function() hoveringBtn = true end)
	dropBtn.MouseLeave:Connect(function() hoveringBtn = false end)
	listFrame.MouseEnter:Connect(function() hoveringList = true end)
	listFrame.MouseLeave:Connect(function() hoveringList = false end)

	dropBtn.MouseButton1Click:Connect(function()
		if open then
			closeThis()
			return
		end
		if openDropdown and openDropdown ~= listFrame then
			local prev = openDropdown
			tween(prev, { Size = UDim2.new(0, prev.AbsoluteSize.X, 0, 0) }, 0.15)
			task.delay(0.15, function() prev.Visible = false end)
			openDropdown = nil
		end
		open = true
		openDropdown = listFrame

		task.defer(function()
			local as = dropBtn.AbsoluteSize
			local ap = dropBtn.AbsolutePosition
			listFrame.Position = UDim2.new(0, ap.X, 0, ap.Y + as.Y - 1)
			listFrame.Size = UDim2.new(0, as.X, 0, 0)
			listFrame.Visible = true
			tween(listFrame, { Size = UDim2.new(0, as.X, 0, LIST_H) }, 0.2)
		end)

		tween(arrow, { Rotation = 180 }, 0.2)
	end)

	RunService.RenderStepped:Connect(function()
		if not open then return end
		if not hoveringList and not hoveringBtn then
			closeThis()
		end
	end)

	return wrap, function() return selected end
end
local homeScroll, _ = addTab("Home", 6034798461)

local profileCard = Instance.new("Frame")
profileCard.Size = UDim2.new(1, 0, 0, 220)
profileCard.BackgroundColor3 = Color3.fromRGB(11, 11, 17)
profileCard.BorderSizePixel = 0
profileCard.LayoutOrder = 1
profileCard.Parent = homeScroll
corner(profileCard, 10)

local pfp = Instance.new("ImageLabel")
pfp.Size = UDim2.new(0, 68, 0, 68)
pfp.Position = UDim2.new(0, 18, 0, 18)
pfp.BackgroundTransparency = 1
pfp.Parent = profileCard
corner(pfp, 34)
local thumbImg = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
pfp.Image = thumbImg

local welcomeLbl = Instance.new("TextLabel")
welcomeLbl.Text = "Welcome, " .. player.DisplayName
welcomeLbl.Size = UDim2.new(1, -28, 0, 20)
welcomeLbl.Position = UDim2.new(0, 14, 0, -26)
welcomeLbl.AnchorPoint = Vector2.new(0, 1)
welcomeLbl.BackgroundTransparency = 1
welcomeLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
welcomeLbl.TextSize = 13
welcomeLbl.Font = Enum.Font.Arial
welcomeLbl.TextXAlignment = Enum.TextXAlignment.Left
welcomeLbl.TextStrokeTransparency = 1

local unLbl = Instance.new("TextLabel")
unLbl.Text = player.Name
unLbl.Size = UDim2.new(0, 200, 0, 24)
unLbl.Position = UDim2.new(0, 100, 0, 20)
unLbl.BackgroundTransparency = 1
unLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
unLbl.TextSize = 17
unLbl.Font = Enum.Font.Arial
unLbl.TextXAlignment = Enum.TextXAlignment.Left
unLbl.TextStrokeTransparency = 1
unLbl.Parent = profileCard

local dpLbl = Instance.new("TextLabel")
dpLbl.Text = "@" .. player.DisplayName
dpLbl.Size = UDim2.new(0, 200, 0, 17)
dpLbl.Position = UDim2.new(0, 100, 0, 44)
dpLbl.BackgroundTransparency = 1
dpLbl.TextColor3 = Color3.fromRGB(100, 100, 120)
dpLbl.TextSize = 12
dpLbl.Font = Enum.Font.Arial
dpLbl.TextXAlignment = Enum.TextXAlignment.Left
dpLbl.TextStrokeTransparency = 1
dpLbl.Parent = profileCard

local div1 = Instance.new("Frame")
div1.Size = UDim2.new(1, -28, 0, 1)
div1.Position = UDim2.new(0, 14, 0, 100)
div1.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
div1.BorderSizePixel = 0
div1.Parent = profileCard

local repoLbl = Instance.new("TextLabel")
repoLbl.RichText = true
repoLbl.Text = '<font color="#4d4d62">repo •</font> <font color="#6a9cff">github.com/Nyx494/nyx-lpi-ui</font>'
repoLbl.Size = UDim2.new(1, -28, 0, 17)
repoLbl.Position = UDim2.new(0, 14, 0, 112)
repoLbl.BackgroundTransparency = 1
repoLbl.TextSize = 12
repoLbl.Font = Enum.Font.Arial
repoLbl.TextXAlignment = Enum.TextXAlignment.Left
repoLbl.TextStrokeTransparency = 1
repoLbl.Parent = profileCard

local linksLbl = Instance.new("TextLabel")
linksLbl.RichText = true
linksLbl.Text = '<font color="#4d4d62">discord •</font> <font color="#6a9cff">Nyx494</font>  <font color="#4d4d62">github •</font> <font color="#6a9cff">Nyx494</font>'
linksLbl.Size = UDim2.new(1, -28, 0, 17)
linksLbl.Position = UDim2.new(0, 14, 0, 132)
linksLbl.BackgroundTransparency = 1
linksLbl.TextSize = 12
linksLbl.Font = Enum.Font.Arial
linksLbl.TextXAlignment = Enum.TextXAlignment.Left
linksLbl.TextStrokeTransparency = 1
linksLbl.Parent = profileCard

local sumLbl = Instance.new("TextLabel")
sumLbl.Text = "test ui for nyx lpi script — placeholder text, more features soon"
sumLbl.Size = UDim2.new(1, -28, 0, 36)
sumLbl.Position = UDim2.new(0, 14, 0, 162)
sumLbl.BackgroundTransparency = 1
sumLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
sumLbl.TextSize = 11
sumLbl.Font = Enum.Font.Arial
sumLbl.TextXAlignment = Enum.TextXAlignment.Left
sumLbl.TextWrapped = true
sumLbl.TextStrokeTransparency = 1
sumLbl.Parent = profileCard

local welcomeHeader = Instance.new("Frame")
welcomeHeader.Size = UDim2.new(1, 0, 0, 28)
welcomeHeader.BackgroundTransparency = 1
welcomeHeader.LayoutOrder = 0
welcomeHeader.Parent = homeScroll

local welcomeHeaderLbl = Instance.new("TextLabel")
welcomeHeaderLbl.Text = "Welcome, " .. player.DisplayName
welcomeHeaderLbl.Size = UDim2.new(1, 0, 1, 0)
welcomeHeaderLbl.BackgroundTransparency = 1
welcomeHeaderLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
welcomeHeaderLbl.TextSize = 15
welcomeHeaderLbl.Font = Enum.Font.Arial
welcomeHeaderLbl.TextXAlignment = Enum.TextXAlignment.Left
welcomeHeaderLbl.TextStrokeTransparency = 1
welcomeHeaderLbl.Parent = welcomeHeader


local settingsScroll, _ = addTab("Settings", 7059346373)

local function makeRow(parent, order)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 38)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(38, 38, 48)
	stroke.Parent = row
	corner(row, 6)
	strokes[row] = stroke
	return row
end

addSectionTitle(settingsScroll, 1, "Hotkeys")

local minRow = makeRow(settingsScroll, 2)
local minimizeLbl = Instance.new("TextLabel")
minimizeLbl.Text = "Minimize"
minimizeLbl.Size = UDim2.new(1, -62, 1, 0)
minimizeLbl.Position = UDim2.new(0, 12, 0, 0)
minimizeLbl.BackgroundTransparency = 1
minimizeLbl.TextColor3 = Color3.fromRGB(180, 180, 200)
minimizeLbl.TextSize = 12
minimizeLbl.Font = Enum.Font.Arial
minimizeLbl.TextXAlignment = Enum.TextXAlignment.Left
minimizeLbl.TextStrokeTransparency = 1
minimizeLbl.Parent = minRow

local minimizeKeyBtn = Instance.new("TextButton")
minimizeKeyBtn.Text = tostring(minimizeKey):gsub("Enum.KeyCode.", "")
minimizeKeyBtn.Size = UDim2.new(0, 46, 0, 28)
minimizeKeyBtn.Position = UDim2.new(1, -52, 0.5, -14)
minimizeKeyBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
minimizeKeyBtn.BorderSizePixel = 0
minimizeKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeKeyBtn.TextSize = 11
minimizeKeyBtn.Font = Enum.Font.Arial
minimizeKeyBtn.TextStrokeTransparency = 1
minimizeKeyBtn.AutoButtonColor = false
minimizeKeyBtn.Parent = minRow
corner(minimizeKeyBtn, 5)

local hideRow = makeRow(settingsScroll, 3)
local hideLbl = Instance.new("TextLabel")
hideLbl.Text = "Hide Window"
hideLbl.Size = UDim2.new(1, -62, 1, 0)
hideLbl.Position = UDim2.new(0, 12, 0, 0)
hideLbl.BackgroundTransparency = 1
hideLbl.TextColor3 = Color3.fromRGB(180, 180, 200)
hideLbl.TextSize = 12
hideLbl.Font = Enum.Font.Arial
hideLbl.TextXAlignment = Enum.TextXAlignment.Left
hideLbl.TextStrokeTransparency = 1
hideLbl.Parent = hideRow

local hideKeyBtn = Instance.new("TextButton")
hideKeyBtn.Text = tostring(hideKey):gsub("Enum.KeyCode.", "")
hideKeyBtn.Size = UDim2.new(0, 46, 0, 28)
hideKeyBtn.Position = UDim2.new(1, -52, 0.5, -14)
hideKeyBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
hideKeyBtn.BorderSizePixel = 0
hideKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hideKeyBtn.TextSize = 11
hideKeyBtn.Font = Enum.Font.Arial
hideKeyBtn.TextStrokeTransparency = 1
hideKeyBtn.AutoButtonColor = false
hideKeyBtn.Parent = hideRow
corner(hideKeyBtn, 5)

local recenterRow = makeRow(settingsScroll, 4)
local recenterLbl2 = Instance.new("TextLabel")
recenterLbl2.Text = "Recenter Window"
recenterLbl2.Size = UDim2.new(1, -62, 1, 0)
recenterLbl2.Position = UDim2.new(0, 12, 0, 0)
recenterLbl2.BackgroundTransparency = 1
recenterLbl2.TextColor3 = Color3.fromRGB(180, 180, 200)
recenterLbl2.TextSize = 12
recenterLbl2.Font = Enum.Font.Arial
recenterLbl2.TextXAlignment = Enum.TextXAlignment.Left
recenterLbl2.TextStrokeTransparency = 1
recenterLbl2.Parent = recenterRow

local recenterKeyBtn = Instance.new("TextButton")
recenterKeyBtn.Text = tostring(recenterKey):gsub("Enum.KeyCode.", "")
recenterKeyBtn.Size = UDim2.new(0, 46, 0, 28)
recenterKeyBtn.Position = UDim2.new(1, -52, 0.5, -14)
recenterKeyBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
recenterKeyBtn.BorderSizePixel = 0
recenterKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
recenterKeyBtn.TextSize = 11
recenterKeyBtn.Font = Enum.Font.Arial
recenterKeyBtn.TextStrokeTransparency = 1
recenterKeyBtn.AutoButtonColor = false
recenterKeyBtn.Parent = recenterRow
corner(recenterKeyBtn, 5)

local toggleRow = makeRow(settingsScroll, 5)
local recenterToggleLbl = Instance.new("TextLabel")
recenterToggleLbl.Text = "Enable Recenter Hotkey"
recenterToggleLbl.Size = UDim2.new(1, -62, 1, 0)
recenterToggleLbl.Position = UDim2.new(0, 12, 0, 0)
recenterToggleLbl.BackgroundTransparency = 1
recenterToggleLbl.TextColor3 = Color3.fromRGB(180, 180, 200)
recenterToggleLbl.TextSize = 12
recenterToggleLbl.Font = Enum.Font.Arial
recenterToggleLbl.TextXAlignment = Enum.TextXAlignment.Left
recenterToggleLbl.TextStrokeTransparency = 1
recenterToggleLbl.Parent = toggleRow

local toggleTrack = Instance.new("Frame")
toggleTrack.Size = UDim2.new(0, 46, 0, 24)
toggleTrack.Position = UDim2.new(1, -52, 0.5, -12)
toggleTrack.BackgroundColor3 = recenterEnabled and Color3.fromRGB(45, 120, 65) or Color3.fromRGB(48, 48, 58)
toggleTrack.BorderSizePixel = 0
toggleTrack.Parent = toggleRow
corner(toggleTrack, 12)

local toggleThumb = Instance.new("Frame")
toggleThumb.Size = UDim2.new(0, 18, 0, 18)
toggleThumb.Position = recenterEnabled and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
toggleThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
toggleThumb.BorderSizePixel = 0
toggleThumb.ZIndex = 2
toggleThumb.Parent = toggleTrack
corner(toggleThumb, 9)

local toggleBtn = Instance.new("TextButton")
toggleBtn.Text = ""
toggleBtn.Size = UDim2.new(1, 0, 1, 0)
toggleBtn.BackgroundTransparency = 1
toggleBtn.ZIndex = 3
toggleBtn.AutoButtonColor = false
toggleBtn.Parent = toggleTrack

addSubnote(settingsScroll, 6, "Click a key square to rebind. Changes are saved automatically.")

local function setRecenterRowEnabled(enabled)
	recenterEnabled = enabled
	saveSettings()
	tween(toggleTrack, { BackgroundColor3 = enabled and Color3.fromRGB(45, 120, 65) or Color3.fromRGB(48, 48, 58) }, 0.2)
	tween(toggleThumb, { Position = enabled and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9) }, 0.2)
	recenterLbl2.TextColor3 = enabled and Color3.fromRGB(180, 180, 200) or Color3.fromRGB(100, 100, 110)
	recenterKeyBtn.TextColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 110)
	tween(recenterKeyBtn, { BackgroundColor3 = enabled and Color3.fromRGB(28, 28, 38) or Color3.fromRGB(22, 22, 30) }, 0.2)
	recenterKeyBtn.Active = enabled
end

setRecenterRowEnabled(recenterEnabled)

local currentBindConn = nil
local currentBtn = nil

local function cancelListening()
	if currentBindConn then currentBindConn:Disconnect() currentBindConn = nil end
	if currentBtn then
		currentBtn.Text = tostring(
			currentBtn == minimizeKeyBtn and minimizeKey
			or currentBtn == hideKeyBtn and hideKey
			or recenterKey
		):gsub("Enum.KeyCode.", "")
		tween(currentBtn, { BackgroundColor3 = Color3.fromRGB(28, 28, 38) }, 0.15)
		currentBtn = nil
	end
	listenKey = false
end

local function bindRebind(btn, setKey)
	btn.MouseButton1Click:Connect(function()
		if listenKey and currentBtn == btn then cancelListening() return end
		if listenKey then cancelListening() end
		if not btn.Active then return end
		listenKey = true
		currentBtn = btn
		btn.Text = "..."
		tween(btn, { BackgroundColor3 = accent }, 0.15)
		if currentBindConn then currentBindConn:Disconnect() end
		local conn
		conn = UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Unknown then return end
			conn:Disconnect()
			currentBindConn = nil
			setKey(input.KeyCode)
			btn.Text = tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
			tween(btn, { BackgroundColor3 = Color3.fromRGB(28, 28, 38) }, 0.15)
			listenKey = false
			currentBtn = nil
			saveSettings()
			ignoreNext[input.KeyCode] = true
			task.delay(0.1, function() ignoreNext[input.KeyCode] = nil end)
		end)
		currentBindConn = conn
	end)
end

bindRebind(minimizeKeyBtn, function(k) minimizeKey = k end)
bindRebind(hideKeyBtn, function(k) hideKey = k end)
bindRebind(recenterKeyBtn, function(k) recenterKey = k end)

toggleBtn.MouseButton1Click:Connect(function()
	if listenKey then cancelListening() end
	setRecenterRowEnabled(not recenterEnabled)
end)

setActiveTab("Home")

task.defer(function()
	originalTransparencies[main] = { bg = main.BackgroundTransparency }
	for _, v in ipairs(main:GetDescendants()) do
		if v:IsA("GuiObject") then
			local entry = { bg = v.BackgroundTransparency }
			if v:IsA("TextLabel") or v:IsA("TextButton") then entry.text = v.TextTransparency end
			originalTransparencies[v] = entry
		end
	end
	task.delay(0.05, function() animateTabIn(homeScroll) end)
end)

currentPos = Vector2.new(main.AbsolutePosition.X, main.AbsolutePosition.Y)
targetPos = currentPos

RunService.RenderStepped:Connect(function()
	if dragging then
		targetPos = Vector2.new(Mouse.X - dragOffset.X, Mouse.Y - dragOffset.Y)
	end
	currentPos = currentPos:Lerp(targetPos, 0.1)
	main.Position = UDim2.new(0, currentPos.X, 0, currentPos.Y)
end)

local function recenterWindow()
	local vp = workspace.CurrentCamera.ViewportSize
	targetPos = Vector2.new(vp.X / 2 - 250, vp.Y / 2 - 200)
end

local function setGuiHidden(hide)
	hidden = hide
	tween(main, { BackgroundTransparency = hide and 1 or 0 }, 0.3)
	for _, v in ipairs(main:GetDescendants()) do
		if v:IsA("GuiObject") then
			local orig = originalTransparencies[v]
			if orig then
				tween(v, { BackgroundTransparency = hide and 1 or orig.bg }, 0.3)
				if v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then
					tween(v, { TextTransparency = hide and 1 or (orig.text or 0) }, 0.3)
				end
				if v:IsA("ImageLabel") or v:IsA("ImageButton") then
					tween(v, { ImageTransparency = hide and 1 or 0 }, 0.3)
				end
				if strokes[v] then tween(strokes[v], { Transparency = hide and 1 or 0 }, 0.3) end
			end
		end
	end
end

local function doMinimize()
	minimized = not minimized
	topCornerOverride.Visible = not minimized
	tween(main, { Size = minimized and UDim2.new(0, 500, 0, 35) or UDim2.new(0, 500, 0, 400) }, 0.4, Enum.EasingStyle.Quint)
end

minBtn.MouseButton1Click:Connect(doMinimize)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

top.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragOffset = Vector2.new(Mouse.X - currentPos.X, Mouse.Y - currentPos.Y)
	end
end)
top.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if listenKey then return end
	if gpe then return end
	if ignoreNext[input.KeyCode] then return end
	if input.KeyCode == minimizeKey then
		doMinimize()
	elseif input.KeyCode == hideKey then
		setGuiHidden(not hidden)
	elseif input.KeyCode == recenterKey and recenterEnabled and not hidden then
		recenterWindow()
	end
end) 

