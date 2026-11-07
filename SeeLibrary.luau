local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")


local SeeLib = {}
SeeLib.__index = SeeLib
SeeLib.Version = "0.1"

local DEFAULT_ICON = "rbxassetid://122126277187781"
local DEFAULT_BG = "rbxassetid://119467109407855"

local Themes = {
	Blue = Color3.fromRGB(60, 140, 255),
	Red = Color3.fromRGB(235, 70, 70),
	Green = Color3.fromRGB(60, 200, 120),
	Purple = Color3.fromRGB(150, 90, 255),
	Pink = Color3.fromRGB(255, 100, 170),
	Yellow = Color3.fromRGB(245, 195, 50),
	White = Color3.fromRGB(230, 230, 240),
}

local C = {
	Panel = Color3.fromRGB(22, 22, 30),
	Bg = Color3.fromRGB(14, 14, 20),
	Element = Color3.fromRGB(32, 32, 44),
	ElementHover = Color3.fromRGB(44, 44, 60),
	Stroke = Color3.fromRGB(58, 58, 76),
	Text = Color3.fromRGB(242, 242, 248),
	SubText = Color3.fromRGB(150, 150, 168),
	Off = Color3.fromRGB(62, 62, 80),
}

local ET = 0.15

local FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local MEDIUM = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local OPEN = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local INSTANT = TweenInfo.new(0)

local DEFAULT_SOUNDS = {
	Click = "rbxassetid://124993589864467",
	Toggle = "rbxassetid://101404943278256",
	Open = "rbxassetid://89842591486388",
	Close = "rbxassetid://71159461717880",
	Notify = "rbxassetid://18512046618",
	Hover = "rbxassetid://90698049598280",
}

-- Shared helpers

local function getGuiParent()
	if gethui then
		local ok, result = pcall(gethui)
		if ok and result then
			return result
		end
	end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function addCorner(inst, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) }, inst)
end

local function tween(inst, info, props)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

local function round(n, inc)
	inc = inc or 1
	local r = math.floor(n / inc + 0.5) * inc
	return tonumber(string.format("%.4f", r))
end

local function toHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function resolveTheme(t)
	if typeof(t) == "Color3" then
		return t
	end
	return Themes[t] or Themes.Blue
end

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function borderSeq(c)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, c),
		ColorSequenceKeypoint.new(0.5, c:Lerp(BLACK, 0.65)),
		ColorSequenceKeypoint.new(1, c),
	})
end

local function shineSeq(c)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, c:Lerp(BLACK, 0.25)),
		ColorSequenceKeypoint.new(0.5, c:Lerp(WHITE, 0.55)),
		ColorSequenceKeypoint.new(1, c:Lerp(BLACK, 0.25)),
	})
end

-- ColoredWords accepts a list of { Text, Color } entries.
local function applyColored(label, text, words)
	if not words or #words == 0 then
		label.RichText = false
		label.Text = text
		return
	end
	local safe = text:gsub("&", "&amp;")
	safe = safe:gsub("<", "&lt;")
	safe = safe:gsub(">", "&gt;")
	for _, w in ipairs(words) do
		local color = w.Color or (w.Colors and w.Colors[1]) or WHITE
		local pattern = tostring(w.Text):gsub("%p", "%%%0")
		local tag = '<font color="' .. toHex(color) .. '">' .. tostring(w.Text) .. "</font>"
		tag = tag:gsub("%%", "%%%%")
		safe = safe:gsub(pattern, tag)
	end
	label.RichText = true
	label.Text = safe
end


local function resolveImage(str)
	if type(str) ~= "string" then
		return nil
	end
	str = (string.gsub(str, "^%s*(.-)%s*$", "%1"))
	if str == "" then
		return nil
	end
	if string.match(str, "^%d+$") then
		return "rbxassetid://" .. str
	end
	if string.match(str, "^rbxassetid://%d+$") or string.match(str, "^rbxasset://") then
		return str
	end
	if isfile and getcustomasset then
		local ok, result = pcall(function()
			if isfile(str) then
				return getcustomasset(str)
			end
			return nil
		end)
		if ok and result then
			return result
		end
	end
	local digits = string.match(str, "(%d%d%d%d%d+)")
	if digits then
		return "rbxassetid://" .. digits
	end
	return nil
end


local function textureFromDecal(id)
	local ok, result = pcall(function()
		local objs = game:GetObjects("rbxassetid://" .. id)
		local tex = nil
		for _, o in ipairs(objs) do
			if not tex then
				if o:IsA("Decal") or o:IsA("Texture") then
					tex = o.Texture
				elseif o:IsA("ImageLabel") or o:IsA("ImageButton") then
					tex = o.Image
				else
					local d = o:FindFirstChildWhichIsA("Decal", true) or o:FindFirstChildWhichIsA("Texture", true)
					if d then
						tex = d.Texture
					end
				end
			end
			o:Destroy()
		end
		return tex
	end)
	if ok and type(result) == "string" and result ~= "" then
		return result
	end
	return nil
end

-- Resolve decal IDs to image IDs through Asset Delivery when supported.
local function textureFromDelivery(id)
	local ok, body = pcall(function()
		return game:HttpGet("https://assetdelivery.roblox.com/v1/asset/?id=" .. id)
	end)
	if ok and type(body) == "string" then
		local imgId = string.match(body, "asset/%?id=(%d+)")
		if imgId and imgId ~= id then
			return "rbxassetid://" .. imgId
		end
	end
	return nil
end

local function describeAsset(id)
	local ok, info = pcall(function()
		return game:GetService("MarketplaceService"):GetProductInfo(tonumber(id))
	end)
	if not ok or type(info) ~= "table" then
		return "ID " .. id .. " tidak ditemukan atau tidak bisa diakses (mungkin private atau sudah dihapus moderasi)."
	end
	local t = info.AssetTypeId
	if t == 1 then
		return "ID " .. id .. " sudah berupa Image tapi gagal dimuat (mungkin belum lolos moderasi)."
	elseif t == 13 then
		return "ID " .. id .. " adalah Decal, bukan Image, dan gagal diubah otomatis."
	end
	return "ID " .. id .. " bukan gambar (tipe asset: " .. tostring(t) .. ")."
end

local function isImageLoaded(img)
	local ok, loaded = pcall(function()
		return img.IsLoaded
	end)
	return ok and loaded == true
end

local function smartLoad(img, spec, onFail)
	img.Image = spec
	local id = string.match(spec, "^rbxassetid://(%d+)$")
	task.spawn(function()
		for _ = 1, 6 do
			task.wait(0.5)
			if not img.Parent or img.Image ~= spec then
				return
			end
			if isImageLoaded(img) then
				return
			end
		end
		if id then
			local tex = textureFromDecal(id) or textureFromDelivery(id)
			if tex and img.Parent and img.Image == spec then
				img.Image = tex
				for _ = 1, 8 do
					task.wait(0.5)
					if not img.Parent then
						return
					end
					if isImageLoaded(img) then
						return
					end
				end
			end
		end
		if img.Parent and onFail then
			onFail(id and describeAsset(id) or nil)
		end
	end)
end

-- Lucide icons

local LucideModule = nil
local lucideTried = false

local function getLucide()
	if lucideTried then
		return LucideModule
	end
	lucideTried = true

	pcall(function()
		local m = game:GetService("ReplicatedStorage"):FindFirstChild("Lucide")
		if m and m:IsA("ModuleScript") then
			local r = require(m)
			if type(r) == "table" and r.GetAsset then
				LucideModule = r
			end
		end
	end)
	if LucideModule then
		return LucideModule
	end

	local ok, mod = pcall(function()
		return loadstring(game:HttpGet("https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau"))()
	end)
	if ok and type(mod) == "table" and mod.GetAsset then
		LucideModule = mod
	end
	return LucideModule
end

function SeeLib.SetIconModule(mod)
	LucideModule = mod
	lucideTried = true
end

local ICON_ALIASES = { home = "house", house = "home" }

local function applyIcon(img, spec)
	if type(spec) ~= "string" or spec == "" then
		return false
	end
	if string.match(spec, "^%d+$") or string.match(spec, "^rbxasset") then
		img.Image = resolveImage(spec) or spec
		return true
	end
	local name = string.lower((string.gsub(spec, "^lucide:", "")))
	local mod = getLucide()
	if not mod then
		return false
	end
	local function try(n)
		local ok, asset = pcall(mod.GetAsset, n, 48)
		if ok and type(asset) == "table" and asset.Url then
			return asset
		end
		return nil
	end
	local asset = try(name)
	if not asset and ICON_ALIASES[name] then
		asset = try(ICON_ALIASES[name])
	end
	if not asset then
		return false
	end
	img.Image = asset.Url
	img.ImageRectSize = asset.ImageRectSize
	img.ImageRectOffset = asset.ImageRectOffset
	return true
end

function SeeLib.new()
	local self = setmetatable({}, SeeLib)
	self._windows = {}
	return self
end

-- Window

function SeeLib:CreateWindow(config)
	config = config or {}

	local title = config.Title or "See Library"
	local subtitle = config.Subtitle or ""
	local size = config.Size or Vector2.new(620, 400)
	local minSize = config.MinSize or Vector2.new(460, 320)
	local maxSize = config.MaxSize or Vector2.new(940, 700)
	local sidebarWidth = 160

	local Window = {}
	local connections = {}
	local accentFns = {}
	local tabs = {}
	local destroyed = false
	local visibleState = true
	local selectedEntry = nil
	local settingsTab = nil
	local keyListening = false
	local toggleKey = config.ToggleKey
	if toggleKey == nil then
		toggleKey = Enum.KeyCode.RightShift
	end
	local hideNotify = true

	local function track(conn)
		table.insert(connections, conn)
		return conn
	end

	if config.Icons ~= false then
		getLucide()
	end

	-- Settings persistence requires writefile, readfile, and isfile.
	local safeName = title:gsub("[^%w]", "")
	local cfgName = "SeeLibrary_" .. safeName .. ".json"
	local autoSave = config.AutoSave ~= false
	local autoLoad = config.AutoLoad ~= false
	local canFile = (writefile ~= nil) and (readfile ~= nil) and (isfile ~= nil)
	local saved = {}

	if autoLoad and canFile then
		local ok, data = pcall(function()
			if isfile(cfgName) then
				return HttpService:JSONDecode(readfile(cfgName))
			end
			return nil
		end)
		if ok and type(data) == "table" then
			saved = data
		end
	end

	local savePending = false
	local function saveValue(id, value)
		saved[id] = value
		if not (autoSave and canFile) or savePending then
			return
		end
		savePending = true
		task.delay(0.5, function()
			savePending = false
			pcall(function()
				writefile(cfgName, HttpService:JSONEncode(saved))
			end)
		end)
	end

	local function loadValue(id)
		return saved[id]
	end

	-- A nil ID skips persistence for this component.
	local function store(id, value)
		if id then
			saveValue(id, value)
		end
	end
	local function recall(id)
		if id then
			return loadValue(id)
		end
		return nil
	end

	local accent
	do
		local themeSaved = loadValue("__theme")
		local cc = loadValue("__customcolor")
		if themeSaved == "Custom" and type(cc) == "table" then
			accent = Color3.new(cc.r or 0, cc.g or 0, cc.b or 0)
		else
			accent = resolveTheme(themeSaved or config.Theme or "Blue")
		end
	end

	local function bindAccent(fn)
		fn()
		table.insert(accentFns, fn)
	end

	do
		local s = loadValue("__size")
		if type(s) == "table" and s.w and s.h then
			size = Vector2.new(math.clamp(s.w, minSize.X, maxSize.X), math.clamp(s.h, minSize.Y, maxSize.Y))
		end
	end

	local screenGui = create("ScreenGui", {
		Name = "SeeLibrary",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
	}, getGuiParent())

	local main = create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
	}, screenGui)
	addCorner(main, 12)
	local scale = create("UIScale", { Scale = 0.01 }, main)

	local mainStroke = create("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.1 }, main)
	local strokeGrad = create("UIGradient", { Color = borderSeq(accent) }, mainStroke)
	bindAccent(function()
		strokeGrad.Color = borderSeq(accent)
	end)
	local strokeTween = TweenService:Create(
		strokeGrad,
		TweenInfo.new(7, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
		{ Rotation = 360 }
	)
	strokeTween:Play()

	local bgImage = create("ImageLabel", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
		ImageTransparency = 0.5,
		Visible = false,
	}, main)
	addCorner(bgImage, 12)
	local bgShade = create("Frame", {
		Name = "BackgroundShade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Visible = false,
	}, main)
	addCorner(bgShade, 12)

	local titleBar = create("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
	}, main)

	local accentLine = create("Frame", {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, main)
	local lineGrad = create("UIGradient", { Color = shineSeq(accent), Offset = Vector2.new(-1, 0) }, accentLine)
	bindAccent(function()
		lineGrad.Color = shineSeq(accent)
	end)
	local lineTween = TweenService:Create(
		lineGrad,
		TweenInfo.new(2.8, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
		{ Offset = Vector2.new(1, 0) }
	)
	lineTween:Play()

	local iconTargets = {}
	local titleIcon = create("ImageLabel", {
		Position = UDim2.fromOffset(12, 9),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
	}, titleBar)
	table.insert(iconTargets, titleIcon)

	local titleHolder = create("Frame", {
		Position = UDim2.fromOffset(46, 0),
		Size = UDim2.new(1, -96, 1, 0),
		BackgroundTransparency = 1,
	}, titleBar)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, titleHolder)

	local titleLabel = create("TextLabel", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		LayoutOrder = 1,
	}, titleHolder)
	local titleGrad = create("UIGradient", {}, titleLabel)
	bindAccent(function()
		titleGrad.Color = ColorSequence.new(accent:Lerp(WHITE, 0.3), WHITE)
	end)

	if subtitle ~= "" then
		create("TextLabel", {
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = subtitle,
			TextColor3 = C.SubText,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			LayoutOrder = 2,
		}, titleHolder)
	end

	local closeBtn = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = C.Element,
		BackgroundTransparency = 0.3,
		Text = "X",
		TextColor3 = C.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = false,
	}, titleBar)
	addCorner(closeBtn, 8)
	track(closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, FAST, { BackgroundColor3 = Color3.fromRGB(220, 60, 60), BackgroundTransparency = 0 })
	end))
	track(closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, FAST, { BackgroundColor3 = C.Element, BackgroundTransparency = 0.3 })
	end))

	do
		local dragging = false
		local dragStart, startPos
		track(titleBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = main.Position
				local endConn
				endConn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						endConn:Disconnect()
						dragging = false
					end
				end)
			end
		end))
		track(UserInputService.InputChanged:Connect(function(input)
			if dragging
				and (input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStart
				main.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
			end
		end))
	end

	local soundEnabled = true
	local soundVolume = 0.5
	local clickEnabled = true
	local hoverEnabled = true
	local lastHover = 0
	local sounds = {}
	do
		local ids = {}
		for k, v in pairs(DEFAULT_SOUNDS) do
			ids[k] = v
		end
		if type(config.Sounds) == "table" then
			for k, v in pairs(config.Sounds) do
				ids[k] = v
			end
		end
		for name, id in pairs(ids) do
			if id and id ~= "" then
				local s = Instance.new("Sound")
				s.Name = "See_" .. name
				s.SoundId = (type(id) == "number" or string.match(tostring(id), "^%d+$")) and ("rbxassetid://" .. tostring(id)) or tostring(id)
				s.Volume = soundVolume
				s.Parent = SoundService
				sounds[name] = s
			end
		end
	end

	local function playSound(name, pitch)
		if not soundEnabled or destroyed or (name == "Hover" and not hoverEnabled) or (name == "Click" and not clickEnabled) then
			return
		end
		local s = sounds[name]
		if not s then
			return
		end
		s.Volume = soundVolume
		if name == "Hover" then
			local now = os.clock()
			if now - lastHover < 0.06 then
				return
			end
			lastHover = now
			s.Volume = soundVolume * 0.4
		end
		s.PlaybackSpeed = (pitch or 1) * (0.96 + math.random() * 0.08)
		pcall(function()
			s.TimePosition = 0
			s:Play()
		end)
	end

	local sidebar = create("Frame", {
		Name = "Sidebar",
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(0, sidebarWidth, 1, -46),
		BackgroundTransparency = 1,
	}, main)

	local searchOffset = 0
	if config.Search ~= false then
		searchOffset = 46
		local sf = create("Frame", {
			Position = UDim2.fromOffset(8, 10),
			Size = UDim2.new(1, -16, 0, 30),
			BackgroundColor3 = C.Element,
			BackgroundTransparency = ET,
			BorderSizePixel = 0,
		}, sidebar)
		addCorner(sf, 8)
		create("UIStroke", { Color = C.Stroke, Transparency = 0.5, Thickness = 1 }, sf)
		local searchIcon = create("ImageLabel", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(14, 14),
			BackgroundTransparency = 1,
			ImageColor3 = C.SubText,
		}, sf)
		local hasSearchIcon = applyIcon(searchIcon, "search")
		if not hasSearchIcon then
			searchIcon:Destroy()
		end
		local sbox = create("TextBox", {
			Position = UDim2.fromOffset(hasSearchIcon and 28 or 10, 0),
			Size = UDim2.new(1, hasSearchIcon and -34 or -16, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			PlaceholderText = "Search...",
			PlaceholderColor3 = C.SubText,
			TextColor3 = C.Text,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
		}, sf)
		track(sbox:GetPropertyChangedSignal("Text"):Connect(function()
			local q = string.lower(sbox.Text)
			for _, entry in ipairs(tabs) do
				entry.filter(q)
			end
		end))
	end

	function Window:SetSound(name, spec)
		local resolved = resolveImage(spec)
		if not resolved then
			return false
		end
		local s = sounds[name]
		if not s then
			s = Instance.new("Sound")
			s.Name = "See_" .. name
			s.Volume = soundVolume
			s.Parent = SoundService
			sounds[name] = s
		end
		s.SoundId = resolved
		return true
	end

	function Window:ResetSound(name)
		local s = sounds[name]
		local id = (type(config.Sounds) == "table" and config.Sounds[name]) or DEFAULT_SOUNDS[name]
		if s and id then
			id = tostring(id)
			s.SoundId = string.match(id, "^%d+$") and ("rbxassetid://" .. id) or id
		end
	end

	local profileOn = false
	local tabList = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, searchOffset),
		Size = UDim2.new(1, 0, 1, -searchOffset),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, sidebar)
	create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, tabList)
	create("UIPadding", {
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
	}, tabList)
	bindAccent(function()
		tabList.ScrollBarImageColor3 = accent
	end)

	local profileCard = create("Frame", {
		Name = "Profile",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.new(1, -16, 0, 44),
		BackgroundColor3 = C.Element,
		BackgroundTransparency = ET,
		BorderSizePixel = 0,
		Visible = false,
	}, sidebar)
	addCorner(profileCard, 8)
	create("UIStroke", { Color = C.Stroke, Transparency = 0.5, Thickness = 1 }, profileCard)
	local avatar = create("ImageLabel", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = C.Panel,
		Image = "",
	}, profileCard)
	addCorner(avatar, 16)
	create("TextLabel", {
		Position = UDim2.fromOffset(46, 5),
		Size = UDim2.new(1, -52, 0, 17),
		BackgroundTransparency = 1,
		Text = Players.LocalPlayer.DisplayName,
		TextColor3 = C.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, profileCard)
	create("TextLabel", {
		Position = UDim2.fromOffset(46, 22),
		Size = UDim2.new(1, -52, 0, 16),
		BackgroundTransparency = 1,
		Text = "@" .. Players.LocalPlayer.Name,
		TextColor3 = C.SubText,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, profileCard)
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(
				Players.LocalPlayer.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)
		if ok and img and avatar.Parent then
			avatar.Image = img
		end
	end)

	local function setProfile(on)
		profileOn = on and true or false
		profileCard.Visible = profileOn
		tabList.Size = UDim2.new(1, 0, 1, -(searchOffset + (profileOn and 56 or 0)))
	end

	local contentArea = create("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(sidebarWidth, 52),
		Size = UDim2.new(1, -(sidebarWidth + 8), 1, -60),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, main)
	addCorner(contentArea, 10)
	create("UIStroke", { Color = C.Stroke, Transparency = 0.5, Thickness = 1 }, contentArea)

	local sideOrder = 0

	local bgEnabled = true
	local bgIntensity = 45

	local function applyBackground()
		local show = bgEnabled and bgImage.Image ~= ""
		bgImage.Visible = show
		bgShade.Visible = show
		bgImage.ImageTransparency = 1 - (bgIntensity / 100)
	end

	local function bgFail(reason)
		if bgImage.Visible and not destroyed then
			Window:Notify({
				Title = "Gagal memuat background",
				Description = (reason or "Gagal memuat.") .. " Coba ID lain, atau taruh file gambar di folder workspace executor lalu isi nama filenya.",
				Duration = 6,
			})
		end
	end

	local function iconFail(reason)
		if not destroyed then
			Window:Notify({
				Title = "Gagal memuat icon",
				Description = (reason or "Gagal memuat.") .. " Coba ID lain, atau taruh file gambar di folder workspace executor lalu isi nama filenya.",
				Duration = 6,
			})
		end
	end

	function Window:SetBackground(spec)
		local resolved = resolveImage(spec)
		if not resolved then
			return false
		end
		smartLoad(bgImage, resolved, bgFail)
		applyBackground()
		return true
	end

	function Window:ResetBackground()
		smartLoad(bgImage, resolveImage(config.Background or DEFAULT_BG) or DEFAULT_BG, bgFail)
		applyBackground()
	end

	function Window:SetIcon(spec)
		local resolved = resolveImage(spec)
		if not resolved then
			return false
		end
		for _, img in ipairs(iconTargets) do
			smartLoad(img, resolved, (img == titleIcon) and iconFail or nil)
		end
		return true
	end

	function Window:ResetIcon()
		local resolved = resolveImage(config.Icon or DEFAULT_ICON) or DEFAULT_ICON
		for _, img in ipairs(iconTargets) do
			smartLoad(img, resolved, (img == titleIcon) and iconFail or nil)
		end
	end

	Window:ResetIcon()
	Window:ResetBackground()

	-- Performance overlay
	local showFps, showPing = false, false
	local statsUnlocked = false
	local statsFrame = create("Frame", {
		Name = "Stats",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(160, 26),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Visible = false,
	}, screenGui)
	addCorner(statsFrame, 8)
	local statsStroke = create("UIStroke", { Color = accent, Transparency = 0.3, Thickness = 1 }, statsFrame)
	bindAccent(function()
		statsStroke.Color = accent
	end)
	local statsLabel = create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = C.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
	}, statsFrame)

	local refreshStatsVisible

	local statsPresets = {
		["Kanan Atas"] = { Vector2.new(1, 0), UDim2.new(1, -12, 0, 10) },
		["Kiri Atas"] = { Vector2.new(0, 0), UDim2.new(0, 12, 0, 10) },
		["Tengah Atas"] = { Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 10) },
		["Kiri Bawah"] = { Vector2.new(0, 1), UDim2.new(0, 12, 1, -12) },
		["Tengah Bawah"] = { Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -12) },
	}
	local STATS_FREE = "Bebas (geser sendiri)"

	local function setStatsPosition(name)
		if name == STATS_FREE then
			statsUnlocked = true
			statsFrame.Active = true
			statsStroke.Thickness = 2
			local p = loadValue("__statsfree")
			if type(p) == "table" then
				statsFrame.AnchorPoint = Vector2.new(p.ax or 1, p.ay or 0)
				statsFrame.Position = UDim2.new(p.xs or 1, p.xo or -12, p.ys or 0, p.yo or 10)
			end
		else
			statsUnlocked = false
			statsFrame.Active = false
			statsStroke.Thickness = 1
			local pr = statsPresets[name] or statsPresets["Kanan Atas"]
			statsFrame.AnchorPoint = pr[1]
			statsFrame.Position = pr[2]
		end
		refreshStatsVisible()
	end

	do
		local sdrag = false
		local sStart, sPos
		track(statsFrame.InputBegan:Connect(function(input)
			if statsUnlocked
				and (input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch) then
				sdrag = true
				sStart = input.Position
				sPos = statsFrame.Position
				local endConn
				endConn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						endConn:Disconnect()
						sdrag = false
						saveValue("__statsfree", {
							ax = statsFrame.AnchorPoint.X,
							ay = statsFrame.AnchorPoint.Y,
							xs = statsFrame.Position.X.Scale,
							xo = statsFrame.Position.X.Offset,
							ys = statsFrame.Position.Y.Scale,
							yo = statsFrame.Position.Y.Offset,
						})
					end
				end)
			end
		end))
		track(UserInputService.InputChanged:Connect(function(input)
			if sdrag
				and (input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch) then
				local d = input.Position - sStart
				statsFrame.Position = UDim2.new(sPos.X.Scale, sPos.X.Offset + d.X, sPos.Y.Scale, sPos.Y.Offset + d.Y)
			end
		end))
	end

	refreshStatsVisible = function()
		statsFrame.Visible = showFps or showPing or statsUnlocked
	end

	do
		local frames, acc = 0, 0
		track(RunService.Heartbeat:Connect(function(dt)
			frames = frames + 1
			acc = acc + dt
			if acc >= 0.5 then
				local fps = math.floor(frames / acc + 0.5)
				frames = 0
				acc = 0
				if statsFrame.Visible then
					local parts = {}
					if showFps then
						table.insert(parts, "FPS " .. fps)
					end
					if showPing then
						local ok, p = pcall(function()
							return Players.LocalPlayer:GetNetworkPing() * 1000
						end)
						table.insert(parts, "Ping " .. (ok and math.floor(p + 0.5) or 0) .. "ms")
					end
					statsLabel.Text = (#parts > 0) and table.concat(parts, "  |  ") or "Geser aku"
				end
			end
		end))
	end

	local function confirmDialog(text, onYes)
		local overlay = create("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 0.4,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 50,
		}, main)
		addCorner(overlay, 12)
		local box = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(280, 124),
			BackgroundColor3 = C.Panel,
			BorderSizePixel = 0,
		}, overlay)
		addCorner(box, 10)
		local boxStroke = create("UIStroke", { Color = accent, Thickness = 1.5, Transparency = 0.2 }, box)
		local bscale = create("UIScale", { Scale = 0.85 }, box)
		tween(bscale, OPEN, { Scale = 1 })
		create("TextLabel", {
			Position = UDim2.fromOffset(16, 14),
			Size = UDim2.new(1, -32, 0, 48),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = C.Text,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, box)

		local function dialogButton(label, xScale, color, textColor, callback)
			local b = create("TextButton", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(xScale, 0, 1, -14),
				Size = UDim2.new(0.5, -22, 0, 32),
				BackgroundColor3 = color,
				Text = label,
				TextColor3 = textColor,
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				AutoButtonColor = false,
			}, box)
			addCorner(b, 8)
			b.MouseButton1Click:Connect(function()
				playSound("Click")
				overlay:Destroy()
				if callback then
					task.spawn(callback)
				end
			end)
		end
		dialogButton("Batal", 0.25, C.Element, C.Text, nil)
		dialogButton("Ya", 0.75, accent, WHITE, onYes)
	end

	local function attachDrag(hit, bar, onFraction)
		local dragging = false
		local function update(input)
			local w = bar.AbsoluteSize.X
			if w <= 0 then
				return
			end
			onFraction(math.clamp((input.Position.X - bar.AbsolutePosition.X) / w, 0, 1))
		end
		track(hit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				update(input)
				local endConn
				endConn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						endConn:Disconnect()
						dragging = false
					end
				end)
			end
		end))
		track(UserInputService.InputChanged:Connect(function(input)
			if dragging
				and (input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch) then
				update(input)
			end
		end))
	end

	local function hoverable(frame, hit)
		track(hit.MouseEnter:Connect(function()
			playSound("Hover")
			tween(frame, FAST, { BackgroundColor3 = C.ElementHover })
			local st = frame:FindFirstChildOfClass("UIStroke")
			if st then
				tween(st, FAST, { Color = accent, Transparency = 0.15 })
			end
		end))
		track(hit.MouseLeave:Connect(function()
			tween(frame, FAST, { BackgroundColor3 = C.Element })
			local st = frame:FindFirstChildOfClass("UIStroke")
			if st then
				tween(st, FAST, { Color = C.Stroke, Transparency = 0.5 })
			end
		end))
	end

	local function labels(frame, titleText, desc, rightWidth, icon)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		local holderX = 12
		if icon then
			local img = create("ImageLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.fromOffset(18, 18),
				BackgroundTransparency = 1,
			}, frame)
			if applyIcon(img, icon) then
				holderX = 38
				bindAccent(function()
					img.ImageColor3 = accent
				end)
			else
				img:Destroy()
			end
		end
		local holder = create("Frame", {
			Position = UDim2.fromOffset(holderX, 0),
			Size = UDim2.new(1, -(rightWidth + holderX + 12), 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, frame)
		create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
		create("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }, holder)
		local t = create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = titleText,
			TextColor3 = C.Text,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 1,
		}, holder)
		local d = create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = desc or "",
			TextColor3 = C.SubText,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Visible = (desc ~= nil and desc ~= ""),
			LayoutOrder = 2,
		}, holder)
		return t, d
	end

	local function addCommon(obj, frame, t, d)
		obj.GetFrame = function()
			return frame
		end
		if t then
			obj.SetTitle = function(_, text)
				t.Text = text
			end
		end
		if d then
			obj.SetDescription = function(_, text)
				d.Text = text
				d.Visible = text ~= ""
			end
		end
	end

	-- Window visibility
	local animTween = nil

	local function setVisible(v)
		if destroyed or v == visibleState then
			return
		end
		visibleState = v
		if animTween then
			animTween:Cancel()
		end
		if v then
			main.Visible = true
			scale.Scale = 0.01
			animTween = tween(scale, OPEN, { Scale = 1 })
			playSound("Open")
		else
			local tw = tween(scale, CLOSE, { Scale = 0.01 })
			animTween = tw
			tw.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not visibleState and not destroyed then
					main.Visible = false
				end
			end)
			playSound("Close")
		end
	end

	function Window:Show()
		setVisible(true)
	end
	function Window:Hide()
		setVisible(false)
	end
	function Window:Toggle()
		setVisible(not visibleState)
	end
	function Window:IsVisible()
		return visibleState
	end
	function Window:GetMainFrame()
		return main
	end
	function Window:GetSettingsTab()
		return settingsTab
	end
	function Window:PlaySound(name)
		playSound(name)
	end

	function Window:SetTheme(t)
		accent = resolveTheme(t)
		if typeof(t) == "Color3" then
			saveValue("__theme", "Custom")
			saveValue("__customcolor", { r = t.R, g = t.G, b = t.B })
		else
			saveValue("__theme", t)
		end
		for _, fn in ipairs(accentFns) do
			pcall(fn)
		end
	end

	function Window:Destroy()
		if destroyed then
			return
		end
		destroyed = true
		for _, conn in ipairs(connections) do
			conn:Disconnect()
		end
		strokeTween:Cancel()
		lineTween:Cancel()
		for _, s in pairs(sounds) do
			s:Destroy()
		end
		if animTween then
			animTween:Cancel()
		end
		main.Visible = true
		local tw = tween(scale, CLOSE, { Scale = 0.01 })
		tw.Completed:Connect(function()
			screenGui:Destroy()
		end)
		task.delay(0.5, function()
			if screenGui.Parent then
				screenGui:Destroy()
			end
		end)
	end

	-- Notifications
	local notifHolder = create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 290, 1, -32),
		BackgroundTransparency = 1,
	}, screenGui)
	create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, notifHolder)

	local notifCount = 0
	function Window:Notify(cfg)
		cfg = cfg or {}
		local duration = math.max(cfg.Duration or 4, 0.5)
		notifCount = notifCount + 1
		playSound("Notify")

		local n = create("CanvasGroup", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = C.Panel,
			BorderSizePixel = 0,
			GroupTransparency = 1,
			LayoutOrder = notifCount,
		}, notifHolder)
		addCorner(n, 10)
		create("UIStroke", { Color = accent, Thickness = 1.2, Transparency = 0.2 }, n)

		local holder = create("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, n)
		create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
		create("UIPadding", {
			PaddingTop = UDim.new(0, 11), PaddingBottom = UDim.new(0, 11),
			PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
		}, holder)

		create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = cfg.Title or "Notification",
			TextColor3 = C.Text,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
		}, holder)

		local body = cfg.Description or cfg.Text or ""
		if body ~= "" then
			local d = create("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = body,
				TextColor3 = C.SubText,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
			}, holder)
			if cfg.RichText then
				d.RichText = true
			elseif cfg.ColoredWords then
				applyColored(d, body, cfg.ColoredWords)
			end
		end

		local bar = create("Frame", {
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			LayoutOrder = 3,
		}, holder)
		addCorner(bar, 2)

		tween(n, FAST, { GroupTransparency = 0 })
		tween(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 3) })

		task.delay(duration, function()
			if n.Parent then
				tween(n, FAST, { GroupTransparency = 1 })
				task.delay(0.2, function()
					if n.Parent then
						n:Destroy()
					end
				end)
			end
		end)
	end

	function Window:CreateSeparator(cfg)
		cfg = cfg or {}
		local order = cfg._order
		if not order then
			sideOrder = sideOrder + 1
			order = sideOrder
		end
		create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Text = string.upper(cfg.Text or ""),
			TextColor3 = C.SubText,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
		}, tabList)
	end

	function Window:CreateSidebarLine(cfg)
		cfg = cfg or {}
		local order = cfg._order
		if not order then
			sideOrder = sideOrder + 1
			order = sideOrder
		end
		create("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = C.Stroke,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			LayoutOrder = order,
		}, tabList)
	end

	-- Tabs
	function Window:CreateTab(cfg)
		cfg = cfg or {}
		local tabTitle = cfg.Title or "Tab"
		local double = cfg.Double == true
		local Tab = {}
		local entry = {}
		local elements = {}
		local orders = { 0, 0 }
		local pages = {}

		local order = cfg._order
		if not order then
			sideOrder = sideOrder + 1
			order = sideOrder
		end
		local btn = create("TextButton", {
			Name = "Tab_" .. tabTitle,
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = accent,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = order,
		}, tabList)
		addCorner(btn, 8)
		bindAccent(function()
			btn.BackgroundColor3 = accent
		end)

		local indicator = create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(3, 0),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
		}, btn)
		addCorner(indicator, 2)
		bindAccent(function()
			indicator.BackgroundColor3 = accent
		end)

		local textX = 14
		local tabIcon = nil
		if cfg.Icon and cfg.Icon ~= "" then
			local img = create("ImageLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.fromOffset(18, 18),
				BackgroundTransparency = 1,
				ImageColor3 = C.SubText,
			}, btn)
			if applyIcon(img, cfg.Icon) then
				tabIcon = img
				textX = 38
			else
				img:Destroy()
			end
		end

		local tabLabel = create("TextLabel", {
			Position = UDim2.fromOffset(textX, 0),
			Size = UDim2.new(1, -(textX + 6), 1, 0),
			BackgroundTransparency = 1,
			Text = tabTitle,
			TextColor3 = C.SubText,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, btn)

		local pageHolder = create("Frame", {
			Name = tabTitle,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
		}, contentArea)

		local function newPage(pos, sz)
			local p = create("ScrollingFrame", {
				Position = pos,
				Size = sz,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 3,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
			}, pageHolder)
			create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, p)
			create("UIPadding", {
				PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10),
			}, p)
			bindAccent(function()
				p.ScrollBarImageColor3 = accent
			end)
			return p
		end

		if double then
			pages[1] = newPage(UDim2.new(0, 0, 0, 0), UDim2.new(0.5, -1, 1, 0))
			pages[2] = newPage(UDim2.new(0.5, 1, 0, 0), UDim2.new(0.5, -1, 1, 0))
			create("Frame", {
				Position = UDim2.new(0.5, -1, 0, 8),
				Size = UDim2.new(0, 1, 1, -16),
				BackgroundColor3 = C.Stroke,
				BackgroundTransparency = 0.3,
				BorderSizePixel = 0,
			}, pageHolder)
		else
			pages[1] = newPage(UDim2.new(0, 0, 0, 0), UDim2.fromScale(1, 1))
		end

		entry.filter = function(q)
			local tabMatch = (q == "") or (string.find(string.lower(tabTitle), q, 1, true) ~= nil)
			local any = false
			for _, e in ipairs(elements) do
				local m = tabMatch or (e.text ~= "" and string.find(e.text, q, 1, true) ~= nil)
				e.frame.Visible = m
				if m then
					any = true
				end
			end
			btn.Visible = (q == "") or tabMatch or any
		end

		entry.setActive = function(on)
			if on and not pageHolder.Visible then
				pageHolder.Position = UDim2.fromOffset(0, 12)
				pageHolder.Visible = true
				tween(pageHolder, MEDIUM, { Position = UDim2.fromOffset(0, 0) })
			elseif not on then
				pageHolder.Visible = false
			end
			tabLabel.TextColor3 = on and C.Text or C.SubText
			if tabIcon then
				tabIcon.ImageColor3 = on and accent or C.SubText
			end
			tween(btn, FAST, { BackgroundTransparency = on and 0.82 or 1 })
			tween(indicator, FAST, { Size = UDim2.fromOffset(3, on and 18 or 0) })
		end
		if tabIcon then
			bindAccent(function()
				if selectedEntry == entry then
					tabIcon.ImageColor3 = accent
				end
			end)
		end

		local function select()
			selectedEntry = entry
			for _, t in ipairs(tabs) do
				t.setActive(t == entry)
			end
		end
		table.insert(tabs, entry)
		track(btn.MouseButton1Click:Connect(function()
			if selectedEntry ~= entry then
				playSound("Click")
			end
			select()
		end))
		track(btn.MouseEnter:Connect(function()
			playSound("Hover")
			if selectedEntry ~= entry then
				tween(btn, FAST, { BackgroundTransparency = 0.9 })
			end
		end))
		track(btn.MouseLeave:Connect(function()
			if selectedEntry ~= entry then
				tween(btn, FAST, { BackgroundTransparency = 1 })
			end
		end))
		if not selectedEntry and not cfg._settings then
			select()
		end

		function Tab:Select()
			select()
		end

		function Tab:GetPage()
			return pages[1]
		end

		local function newElement(side, minHeight, searchText, plain)
			side = (double and side == 2) and 2 or 1
			orders[side] = orders[side] + 1
			local f = create("Frame", {
				Size = UDim2.new(1, 0, 0, minHeight),
				BackgroundColor3 = C.Element,
				BackgroundTransparency = plain and 1 or ET,
				BorderSizePixel = 0,
				LayoutOrder = orders[side],
			}, pages[side])
			addCorner(f, 8)
			if not plain then
				create("UIStroke", { Color = C.Stroke, Transparency = 0.5, Thickness = 1 }, f)
			end
			table.insert(elements, { frame = f, text = string.lower(searchText or "") })
			return f
		end

		local function makeId(opt, ttl)
			if opt.NoSave then
				return nil
			end
			return opt.SaveId or (tabTitle .. "/" .. ttl)
		end

		function Tab:CreateSection(opt)
			opt = opt or {}
			local text = opt.Text or ""
			local f = newElement(opt.Side, 26, text, true)
			local bar = create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 2, 0.5, 0),
				Size = UDim2.fromOffset(3, 14),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
			}, f)
			addCorner(bar, 2)
			local x = 12
			local secIcon = nil
			if opt.Icon and opt.Icon ~= "" then
				local img = create("ImageLabel", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 12, 0.5, 0),
					Size = UDim2.fromOffset(14, 14),
					BackgroundTransparency = 1,
				}, f)
				if applyIcon(img, opt.Icon) then
					secIcon = img
					x = 32
				else
					img:Destroy()
				end
			end
			local l = create("TextLabel", {
				Position = UDim2.fromOffset(x, 0),
				Size = UDim2.new(1, -x, 1, 0),
				BackgroundTransparency = 1,
				Text = string.upper(text),
				TextColor3 = accent,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, f)
			bindAccent(function()
				bar.BackgroundColor3 = accent
				l.TextColor3 = accent
				if secIcon then
					secIcon.ImageColor3 = accent
				end
			end)
			local obj = {}
			addCommon(obj, f, nil, nil)
			return obj
		end

		function Tab:CreateSeparatorLine(opt)
			opt = opt or {}
			local f = newElement(opt.Side, 1, "", true)
			f.BackgroundTransparency = 0.3
			f.BackgroundColor3 = C.Stroke
			return { GetFrame = function() return f end }
		end

		function Tab:CreateParagraph(opt)
			opt = opt or {}
			local ttl = opt.Title or "Info"
			local desc = opt.Description or ""
			local f = newElement(opt.Side, 40, ttl .. " " .. desc)
			local t, d = labels(f, ttl, desc, 0, opt.Icon)
			applyColored(d, desc, opt.ColoredWords)
			local obj = {}
			addCommon(obj, f, t, nil)
			obj.SetDescription = function(_, text, words)
				d.Visible = text ~= ""
				applyColored(d, text, words)
			end
			return obj
		end

		function Tab:CreateToggle(opt)
			opt = opt or {}
			local ttl = opt.Title or "Toggle"
			local id = makeId(opt, ttl)
			local f = newElement(opt.Side, 42, ttl)
			local t, d = labels(f, ttl, opt.Description, 46, opt.Icon)

			local sw = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(42, 22),
				BackgroundColor3 = C.Off,
				BorderSizePixel = 0,
			}, f)
			addCorner(sw, 11)
			local swStroke = create("UIStroke", { Color = accent, Thickness = 1, Transparency = 1 }, sw)
			local knob = create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 3, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
			}, sw)
			addCorner(knob, 8)

			local value = opt.Default == true
			local savedV = recall(id)
			if type(savedV) == "boolean" then
				value = savedV
			end

			local function render(animate)
				local info = animate and FAST or INSTANT
				tween(sw, info, { BackgroundColor3 = value and accent or C.Off })
				tween(swStroke, info, { Color = accent, Transparency = value and 0.2 or 1 })
				tween(knob, info, { Position = value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
			end
			bindAccent(function()
				render(false)
			end)

			local function set(v, silent)
				value = v and true or false
				render(true)
				store(id, value)
				if not silent and opt.Callback then
					task.spawn(opt.Callback, value)
				end
			end

			local hit = create("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
			}, f)
			hoverable(f, hit)
			track(hit.MouseButton1Click:Connect(function()
				set(not value)
				playSound("Toggle", value and 1.15 or 0.9)
			end))

			if type(savedV) == "boolean" and opt.Callback then
				task.spawn(opt.Callback, value)
			end

			local obj = {}
			addCommon(obj, f, t, d)
			obj.Set = function(_, v)
				set(v)
			end
			obj.Get = function()
				return value
			end
			return obj
		end

		function Tab:CreateCheckBox(opt)
			opt = opt or {}
			local ttl = opt.Title or "CheckBox"
			local id = makeId(opt, ttl)
			local f = newElement(opt.Side, 42, ttl)
			local t, d = labels(f, ttl, opt.Description, 26, opt.Icon)

			local box = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(22, 22),
				BackgroundColor3 = C.Panel,
				BorderSizePixel = 0,
			}, f)
			addCorner(box, 6)
			local stroke = create("UIStroke", { Color = C.Stroke, Thickness = 1 }, box)
			local tick = create("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "✓",
				TextColor3 = WHITE,
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				TextTransparency = 1,
			}, box)

			local value = opt.Default == true
			local savedV = recall(id)
			if type(savedV) == "boolean" then
				value = savedV
			end

			local function render(animate)
				local info = animate and FAST or INSTANT
				tween(box, info, { BackgroundColor3 = value and accent or C.Panel })
				tween(stroke, info, { Color = value and accent or C.Stroke })
				tween(tick, info, { TextTransparency = value and 0 or 1 })
			end
			bindAccent(function()
				render(false)
			end)

			local function apply(v, silent)
				value = v and true or false
				render(true)
				store(id, value)
				if not silent and opt.Callback then
					task.spawn(opt.Callback, value)
				end
			end

			local hit = create("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
			}, f)
			hoverable(f, hit)
			track(hit.MouseButton1Click:Connect(function()
				local newValue = not value
				playSound("Toggle", newValue and 1.15 or 0.9)
				if opt.Confirmation and newValue then
					confirmDialog('Aktifkan "' .. ttl .. '"?', function()
						apply(true)
					end)
				else
					apply(newValue)
				end
			end))

			if type(savedV) == "boolean" and opt.Callback then
				task.spawn(opt.Callback, value)
			end

			local obj = {}
			addCommon(obj, f, t, d)
			obj.Set = function(_, v)
				apply(v)
			end
			obj.Get = function()
				return value
			end
			return obj
		end

		function Tab:CreateButton(opt)
			opt = opt or {}
			local ttl = opt.Title or "Button"
			local f = newElement(opt.Side, 42, ttl)
			local t, d = labels(f, ttl, opt.Description, 22, opt.Icon)

			local arrow = create("TextLabel", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(16, 20),
				BackgroundTransparency = 1,
				Text = ">",
				TextColor3 = accent,
				Font = Enum.Font.GothamBold,
				TextSize = 14,
			}, f)
			bindAccent(function()
				arrow.TextColor3 = accent
			end)

			local hit = create("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
			}, f)
			hoverable(f, hit)
			track(hit.MouseEnter:Connect(function()
				tween(arrow, FAST, { Position = UDim2.new(1, -8, 0.5, 0) })
			end))
			track(hit.MouseLeave:Connect(function()
				tween(arrow, FAST, { Position = UDim2.new(1, -12, 0.5, 0) })
			end))

			local function run()
				f.BackgroundColor3 = accent
				tween(f, MEDIUM, { BackgroundColor3 = C.ElementHover })
				if opt.Callback then
					task.spawn(opt.Callback)
				end
			end
			track(hit.MouseButton1Click:Connect(function()
				playSound("Click")
				if opt.Confirmation then
					confirmDialog('Jalankan "' .. ttl .. '"?', run)
				else
					run()
				end
			end))

			local obj = {}
			addCommon(obj, f, t, d)
			return obj
		end

		function Tab:CreateSlider(opt)
			opt = opt or {}
			local ttl = opt.Title or "Slider"
			local id = makeId(opt, ttl)
			local min = opt.Min or 0
			local max = opt.Max or 100
			local inc = opt.Increment or 1
			local f = newElement(opt.Side, 58, ttl)

			local t = create("TextLabel", {
				Position = UDim2.fromOffset(12, 8),
				Size = UDim2.new(1, -90, 0, 20),
				BackgroundTransparency = 1,
				Text = ttl,
				TextColor3 = C.Text,
				Font = Enum.Font.GothamMedium,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, f)

			local box = create("TextBox", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 8),
				Size = UDim2.fromOffset(54, 20),
				BackgroundColor3 = C.Panel,
				BorderSizePixel = 0,
				Text = "",
				TextColor3 = C.Text,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				ClearTextOnFocus = false,
			}, f)
			addCorner(box, 6)

			local bar = create("Frame", {
				Position = UDim2.fromOffset(12, 42),
				Size = UDim2.new(1, -24, 0, 6),
				BackgroundColor3 = C.Off,
				BorderSizePixel = 0,
			}, f)
			addCorner(bar, 3)
			local fill = create("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
			}, bar)
			addCorner(fill, 3)
			create("UIGradient", {
				Color = ColorSequence.new(WHITE:Lerp(BLACK, 0.25), WHITE),
			}, fill)
			local knob = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
			}, fill)
			addCorner(knob, 7)
			local knobStroke = create("UIStroke", { Color = accent, Thickness = 2 }, knob)
			bindAccent(function()
				fill.BackgroundColor3 = accent
				knobStroke.Color = accent
			end)

			local hit = create("TextButton", {
				Position = UDim2.fromOffset(12, 32),
				Size = UDim2.new(1, -24, 0, 26),
				BackgroundTransparency = 1,
				Text = "",
			}, f)

			local value = math.clamp(opt.Default or min, min, max)
			local savedV = recall(id)
			if type(savedV) == "number" then
				value = math.clamp(savedV, min, max)
			end

			local function render()
				local frac = (max == min) and 0 or (value - min) / (max - min)
				fill.Size = UDim2.new(frac, 0, 1, 0)
				box.Text = tostring(value)
			end
			render()

			local function set(v, silent)
				v = math.clamp(round(v, inc), min, max)
				local changed = v ~= value
				value = v
				render()
				if changed then
					store(id, value)
					if not silent and opt.Callback then
						task.spawn(opt.Callback, value)
					end
				end
			end

			attachDrag(hit, bar, function(frac)
				set(min + (max - min) * frac)
			end)
			track(box.FocusLost:Connect(function()
				local n = tonumber(box.Text)
				if n then
					set(n)
				else
					render()
				end
			end))

			if type(savedV) == "number" and opt.Callback then
				task.spawn(opt.Callback, value)
			end

			local obj = {}
			addCommon(obj, f, t, nil)
			obj.Set = function(_, v)
				set(v)
			end
			obj.Get = function()
				return value
			end
			return obj
		end

		function Tab:CreateDropdown(opt)
			opt = opt or {}
			local ttl = opt.Title or "Dropdown"
			local multiple = opt.Multiple == true
			local id = makeId(opt, ttl)
			local options = {}
			local selected = {}
			local buttons = {}
			local filterText = ""
			local isOpen = false

			for _, o in ipairs(opt.Options or {}) do
				table.insert(options, tostring(o))
			end

			local f = newElement(opt.Side, 42, ttl)
			f.ClipsDescendants = true

			local t = create("TextLabel", {
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(0.5, -12, 0, 42),
				BackgroundTransparency = 1,
				Text = ttl,
				TextColor3 = C.Text,
				Font = Enum.Font.GothamMedium,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, f)
			local selLabel = create("TextLabel", {
				Position = UDim2.new(0.5, 0, 0, 0),
				Size = UDim2.new(0.5, -34, 0, 42),
				BackgroundTransparency = 1,
				Text = "None",
				TextColor3 = C.SubText,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, f)
			local arrow = create("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -18, 0, 21),
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Text = "v",
				TextColor3 = accent,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
			}, f)

			local header = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundTransparency = 1,
				Text = "",
			}, f)
			hoverable(f, header)

			local panel = create("Frame", {
				Position = UDim2.fromOffset(0, 42),
				Size = UDim2.new(1, 0, 0, 220),
				BackgroundTransparency = 1,
			}, f)
			local searchFrame = create("Frame", {
				Position = UDim2.fromOffset(8, 2),
				Size = UDim2.new(1, -16, 0, 26),
				BackgroundColor3 = C.Panel,
				BorderSizePixel = 0,
			}, panel)
			addCorner(searchFrame, 6)
			local searchBox = create("TextBox", {
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(1, -16, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				PlaceholderText = "Search...",
				PlaceholderColor3 = C.SubText,
				TextColor3 = C.Text,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				ClearTextOnFocus = false,
			}, searchFrame)

			local list = create("ScrollingFrame", {
				Position = UDim2.fromOffset(8, 34),
				Size = UDim2.new(1, -16, 0, 30),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 3,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
			}, panel)
			create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)
			bindAccent(function()
				list.ScrollBarImageColor3 = accent
			end)

			local function visibleOptions()
				local out = {}
				for _, o in ipairs(options) do
					if filterText == "" or string.find(string.lower(o), filterText, 1, true) then
						table.insert(out, o)
					end
				end
				return out
			end

			local function getList()
				local out = {}
				for _, o in ipairs(options) do
					if selected[o] then
						table.insert(out, o)
					end
				end
				return out
			end

			local function getValue()
				local l = getList()
				if multiple then
					return l
				end
				return l[1]
			end

			local function renderSel()
				local l = getList()
				selLabel.Text = (#l == 0) and "None" or table.concat(l, ", ")
			end

			local function restyle()
				for o, b in pairs(buttons) do
					local on = selected[o] == true
					b.TextColor3 = on and accent or C.Text
					b.BackgroundColor3 = on and C.ElementHover or C.Panel
				end
				arrow.TextColor3 = accent
			end

			local function applyHeight(animate)
				local h = 42
				if isOpen then
					local listH = math.max(math.min(#visibleOptions() * 30, 150), 30)
					list.Size = UDim2.new(1, -16, 0, listH)
					h = 42 + 34 + listH + 8
				end
				tween(f, animate and FAST or INSTANT, { Size = UDim2.new(1, 0, 0, h) })
			end

			local function setOpen(b)
				isOpen = b
				tween(arrow, FAST, { Rotation = b and 180 or 0 })
				applyHeight(true)
			end

			local function fire()
				local v = getValue()
				store(id, v)
				if opt.Callback then
					task.spawn(opt.Callback, v)
				end
			end

			local function pick(o)
				playSound("Click")
				if multiple then
					selected[o] = (not selected[o]) or nil
				else
					selected = {}
					selected[o] = true
					setOpen(false)
				end
				restyle()
				renderSel()
				fire()
			end

			local function rebuild()
				for _, b in pairs(buttons) do
					b:Destroy()
				end
				buttons = {}
				for i, o in ipairs(visibleOptions()) do
					local b = create("TextButton", {
						Size = UDim2.new(1, 0, 0, 28),
						BackgroundColor3 = C.Panel,
						BorderSizePixel = 0,
						Text = o,
						TextColor3 = C.Text,
						Font = Enum.Font.Gotham,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Left,
						AutoButtonColor = false,
						LayoutOrder = i,
					}, list)
					addCorner(b, 6)
					create("UIPadding", { PaddingLeft = UDim.new(0, 10) }, b)
					buttons[o] = b
					b.MouseEnter:Connect(function()
						playSound("Hover")
					end)
					b.MouseButton1Click:Connect(function()
						pick(o)
					end)
				end
				restyle()
			end

			local function setSel(v)
				selected = {}
				if type(v) == "table" then
					for _, x in ipairs(v) do
						selected[tostring(x)] = true
						if not multiple then
							break
						end
					end
				elseif v ~= nil then
					selected[tostring(v)] = true
				end
			end

			local savedV = recall(id)
			if savedV ~= nil then
				setSel(savedV)
			else
				setSel(opt.Default)
			end

			rebuild()
			renderSel()
			bindAccent(restyle)

			track(header.MouseButton1Click:Connect(function()
				playSound("Click")
				if not isOpen and opt.AutoReload then
					local ok, newOpts = pcall(opt.AutoReload)
					if ok and type(newOpts) == "table" then
						options = {}
						for _, o in ipairs(newOpts) do
							table.insert(options, tostring(o))
						end
						rebuild()
						renderSel()
					end
				end
				setOpen(not isOpen)
			end))
			track(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
				filterText = string.lower(searchBox.Text)
				rebuild()
				applyHeight(true)
			end))

			if savedV ~= nil and opt.Callback then
				task.spawn(opt.Callback, getValue())
			end

			local obj = {}
			addCommon(obj, f, t, nil)
			obj.Set = function(_, v)
				setSel(v)
				restyle()
				renderSel()
				fire()
			end
			obj.Get = function()
				return getValue()
			end
			obj.Reload = function(_, newOpts)
				options = {}
				for _, o in ipairs(newOpts or {}) do
					table.insert(options, tostring(o))
				end
				rebuild()
				renderSel()
				applyHeight(false)
			end
			obj.Open = function()
				setOpen(true)
			end
			obj.Close = function()
				setOpen(false)
			end
			return obj
		end

		function Tab:CreateTextBox(opt)
			opt = opt or {}
			local ttl = opt.Title or "Text"
			local id = makeId(opt, ttl)
			local maxLen = opt.MaxLength or 100
			local boxW = opt.Width or 150
			local f = newElement(opt.Side, 42, ttl)
			local t, d = labels(f, ttl, opt.Description, boxW, opt.Icon)

			local inputFrame = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(boxW, 28),
				BackgroundColor3 = C.Panel,
				BorderSizePixel = 0,
			}, f)
			addCorner(inputFrame, 6)
			local stroke = create("UIStroke", { Color = C.Stroke, Thickness = 1 }, inputFrame)

			local box = create("TextBox", {
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(1, -16, 1, 0),
				BackgroundTransparency = 1,
				Text = opt.Default or "",
				PlaceholderText = opt.Placeholder or "Type here...",
				PlaceholderColor3 = C.SubText,
				TextColor3 = C.Text,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				ClearTextOnFocus = false,
			}, inputFrame)

			local savedV = recall(id)
			if type(savedV) == "string" then
				box.Text = savedV
			end

			track(box:GetPropertyChangedSignal("Text"):Connect(function()
				if #box.Text > maxLen then
					box.Text = string.sub(box.Text, 1, maxLen)
				end
			end))
			track(box.Focused:Connect(function()
				tween(stroke, FAST, { Color = accent })
			end))
			track(box.FocusLost:Connect(function()
				tween(stroke, FAST, { Color = C.Stroke })
				store(id, box.Text)
				if opt.Callback then
					task.spawn(opt.Callback, box.Text)
				end
			end))

			if type(savedV) == "string" and opt.Callback then
				task.spawn(opt.Callback, box.Text)
			end

			local obj = {}
			addCommon(obj, f, t, d)
			obj.Get = function()
				return box.Text
			end
			obj.Set = function(_, text)
				box.Text = tostring(text)
				store(id, box.Text)
			end
			obj.SetPlaceholder = function(_, text)
				box.PlaceholderText = text
			end
			return obj
		end

		function Tab:CreateKeyBind(opt)
			opt = opt or {}
			local ttl = opt.Title or "KeyBind"
			local id = makeId(opt, ttl)
			local key = opt.Default or Enum.KeyCode.F
			local listening = false
			local f = newElement(opt.Side, 42, ttl)
			local t, d = labels(f, ttl, opt.Description, 96, opt.Icon)

			local savedV = recall(id)
			if type(savedV) == "string" then
				local ok, kc = pcall(function()
					return Enum.KeyCode[savedV]
				end)
				if ok and kc and kc ~= Enum.KeyCode.Unknown then
					key = kc
				end
			end

			local kb = create("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(96, 28),
				BackgroundColor3 = C.Panel,
				Text = key.Name,
				TextColor3 = C.Text,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				AutoButtonColor = false,
			}, f)
			addCorner(kb, 6)
			local stroke = create("UIStroke", { Color = C.Stroke, Thickness = 1 }, kb)

			track(kb.MouseButton1Click:Connect(function()
				playSound("Click")
				listening = true
				keyListening = true
				kb.Text = "..."
				tween(stroke, FAST, { Color = accent })
			end))

			track(UserInputService.InputBegan:Connect(function(input, gpe)
				if listening then
					if input.UserInputType == Enum.UserInputType.Keyboard then
						listening = false
						tween(stroke, FAST, { Color = C.Stroke })
						if input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Enum.KeyCode.Unknown then
							key = input.KeyCode
							store(id, key.Name)
							if opt.Callback then
								task.spawn(opt.Callback, key)
							end
						end
						kb.Text = key.Name
						task.defer(function()
							keyListening = false
						end)
					end
					return
				end
				if not gpe and not keyListening and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == key and opt.OnPress then
					task.spawn(opt.OnPress)
				end
			end))

			if type(savedV) == "string" and opt.Callback then
				task.spawn(opt.Callback, key)
			end

			local obj = {}
			addCommon(obj, f, t, d)
			obj.Get = function()
				return key
			end
			obj.Set = function(_, kc)
				key = kc
				kb.Text = key.Name
				store(id, key.Name)
			end
			return obj
		end

		function Tab:CreateColorPicker(opt)
			opt = opt or {}
			local ttl = opt.Title or "Color"
			local id = makeId(opt, ttl)
			local stored = opt.Default or Color3.fromRGB(255, 65, 65)
			local hadSaved = false
			local savedC = recall(id)
			if type(savedC) == "table" and savedC.r and savedC.g and savedC.b then
				stored = Color3.new(savedC.r, savedC.g, savedC.b)
				hadSaved = true
			end
			local h, s, v = stored:ToHSV()
			local isOpen = false

			local f = newElement(opt.Side, 42, ttl)
			f.ClipsDescendants = true

			local t = create("TextLabel", {
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -70, 0, 42),
				BackgroundTransparency = 1,
				Text = ttl,
				TextColor3 = C.Text,
				Font = Enum.Font.GothamMedium,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, f)
			local preview = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0, 21),
				Size = UDim2.fromOffset(36, 20),
				BackgroundColor3 = stored,
				BorderSizePixel = 0,
			}, f)
			addCorner(preview, 5)
			create("UIStroke", { Color = C.Stroke, Thickness = 1 }, preview)

			local header = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundTransparency = 1,
				Text = "",
			}, f)
			hoverable(f, header)

			local panel = create("Frame", {
				Position = UDim2.fromOffset(0, 42),
				Size = UDim2.new(1, 0, 0, 130),
				BackgroundTransparency = 1,
			}, f)

			local function makeRow(index, letter, isHue)
				local y = (index - 1) * 28 + 6
				create("TextLabel", {
					Position = UDim2.fromOffset(12, y),
					Size = UDim2.fromOffset(16, 20),
					BackgroundTransparency = 1,
					Text = letter,
					TextColor3 = C.SubText,
					Font = Enum.Font.GothamBold,
					TextSize = 12,
				}, panel)
				local bar = create("Frame", {
					Position = UDim2.new(0, 34, 0, y + 7),
					Size = UDim2.new(1, -50, 0, 6),
					BackgroundColor3 = isHue and WHITE or C.Off,
					BorderSizePixel = 0,
				}, panel)
				addCorner(bar, 3)
				local fill = nil
				if isHue then
					local keypoints = {}
					for i = 0, 6 do
						table.insert(keypoints, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
					end
					create("UIGradient", { Color = ColorSequence.new(keypoints) }, bar)
				else
					fill = create("Frame", {
						Size = UDim2.fromScale(0, 1),
						BackgroundColor3 = accent,
						BorderSizePixel = 0,
					}, bar)
					addCorner(fill, 3)
					bindAccent(function()
						fill.BackgroundColor3 = accent
					end)
				end
				local knob = create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.fromOffset(12, 12),
					BackgroundColor3 = WHITE,
					BorderSizePixel = 0,
					ZIndex = 2,
				}, bar)
				addCorner(knob, 6)
				local hit = create("TextButton", {
					Position = UDim2.new(0, 34, 0, y),
					Size = UDim2.new(1, -50, 0, 20),
					BackgroundTransparency = 1,
					Text = "",
				}, panel)
				return bar, fill, knob, hit
			end

			local hBar, _, hKnob, hHit = makeRow(1, "H", true)
			local sBar, sFill, sKnob, sHit = makeRow(2, "S", false)
			local vBar, vFill, vKnob, vHit = makeRow(3, "V", false)

			local hexLabel = create("TextLabel", {
				Position = UDim2.fromOffset(12, 94),
				Size = UDim2.fromOffset(100, 24),
				BackgroundTransparency = 1,
				Text = "",
				TextColor3 = C.SubText,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, panel)

			local applyBtn = create("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 92),
				Size = UDim2.fromOffset(70, 26),
				BackgroundColor3 = accent,
				Text = "Apply",
				TextColor3 = WHITE,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				AutoButtonColor = false,
			}, panel)
			addCorner(applyBtn, 7)
			bindAccent(function()
				applyBtn.BackgroundColor3 = accent
			end)

			local function updateVisuals()
				local c = Color3.fromHSV(h, s, v)
				preview.BackgroundColor3 = c
				hexLabel.Text = toHex(c)
				hKnob.Position = UDim2.new(h, 0, 0.5, 0)
				sFill.Size = UDim2.new(s, 0, 1, 0)
				sKnob.Position = UDim2.new(s, 0, 0.5, 0)
				vFill.Size = UDim2.new(v, 0, 1, 0)
				vKnob.Position = UDim2.new(v, 0, 0.5, 0)
			end
			updateVisuals()

			attachDrag(hHit, hBar, function(frac)
				h = frac
				updateVisuals()
			end)
			attachDrag(sHit, sBar, function(frac)
				s = frac
				updateVisuals()
			end)
			attachDrag(vHit, vBar, function(frac)
				v = frac
				updateVisuals()
			end)

			local function setOpen(b)
				isOpen = b
				if not b then
					h, s, v = stored:ToHSV()
					updateVisuals()
				end
				tween(f, FAST, { Size = UDim2.new(1, 0, 0, b and 172 or 42) })
			end

			local function commit(c, silent)
				stored = c
				h, s, v = stored:ToHSV()
				updateVisuals()
				store(id, { r = c.R, g = c.G, b = c.B })
				if not silent and opt.Callback then
					task.spawn(opt.Callback, stored)
				end
			end

			track(header.MouseButton1Click:Connect(function()
				playSound("Click")
				setOpen(not isOpen)
			end))
			track(applyBtn.MouseButton1Click:Connect(function()
				playSound("Click")
				commit(Color3.fromHSV(h, s, v))
				setOpen(false)
			end))

			if hadSaved and opt.Callback then
				task.spawn(opt.Callback, stored)
			end

			local obj = {}
			addCommon(obj, f, t, nil)
			obj.Get = function()
				return stored
			end
			obj.Set = function(_, c)
				commit(c)
			end
			return obj
		end

		return Tab
	end

	local fb = (type(config.FloatButton) == "table") and config.FloatButton or {}
	local floatEnabled = config.FloatButton ~= false
	local fsize = math.max(fb.Size or 100, 50)
	local fcolors = {
		Black = Color3.fromRGB(16, 16, 22),
		White = Color3.fromRGB(240, 240, 245),
		Translucent = Color3.fromRGB(30, 30, 42),
	}
	local floatBtn = create("TextButton", {
		Name = "FloatButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 20 + fsize / 2, 0.5, 0),
		Size = UDim2.fromOffset(fsize, fsize),
		BackgroundColor3 = fcolors[fb.Color or "Black"] or fcolors.Black,
		BackgroundTransparency = (fb.Color == "Translucent") and 1 or 1,
		Text = "",
		AutoButtonColor = false,
		Visible = floatEnabled,
	}, screenGui)
	addCorner(floatBtn, (fb.Shape == "Square") and 12 or (fsize / 2))
	local fStroke = create("UIStroke", { Color = WHITE, Thickness = 2 }, floatBtn)
	local fGrad = create("UIGradient", { Color = borderSeq(accent) }, fStroke)
	bindAccent(function()
		fGrad.Color = borderSeq(accent)
	end)
	local fScale = create("UIScale", { Scale = 1 }, floatBtn)
	local floatIcon = create("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
	}, floatBtn)
	table.insert(iconTargets, floatIcon)
	smartLoad(floatIcon, (titleIcon.Image ~= "") and titleIcon.Image or DEFAULT_ICON, nil)

	do
		local fdrag = false
		local moved = false
		local fstart, fpos
		track(floatBtn.MouseEnter:Connect(function()
			playSound("Hover")
			tween(fScale, FAST, { Scale = 1.1 })
		end))
		track(floatBtn.MouseLeave:Connect(function()
			tween(fScale, FAST, { Scale = 1 })
		end))
		track(floatBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				fdrag = true
				moved = false
				fstart = input.Position
				fpos = floatBtn.Position
				local endConn
				endConn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						endConn:Disconnect()
						local wasDown = fdrag
						fdrag = false
						if wasDown and not moved then
							Window:Toggle()
						end
					end
				end)
			end
		end))
		track(UserInputService.InputChanged:Connect(function(input)
			if fdrag
				and (input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - fstart
				if delta.Magnitude > 6 then
					moved = true
				end
				if moved then
					floatBtn.Position = UDim2.new(
						fpos.X.Scale, fpos.X.Offset + delta.X,
						fpos.Y.Scale, fpos.Y.Offset + delta.Y
					)
				end
			end
		end))
	end

	track(closeBtn.MouseButton1Click:Connect(function()
		playSound("Click")
		local canReopen = floatBtn.Visible or (toggleKey ~= nil)
		if canReopen then
			Window:Hide()
			if hideNotify then
				local how = {}
				if floatBtn.Visible then
					table.insert(how, "tombol bulat")
				end
				if toggleKey then
					table.insert(how, toggleKey.Name)
				end
				Window:Notify({
					Title = "Window disembunyikan",
					Description = "Buka lagi lewat " .. table.concat(how, " atau ") .. ".",
					Duration = 3,
				})
			end
		else
			Window:Destroy()
		end
	end))

	track(UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe or keyListening or not toggleKey then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == toggleKey then
			Window:Toggle()
		end
	end))

	if config.Resizable ~= false then
		local handle = create("TextButton", {
			Name = "ResizeHandle",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -3, 1, -3),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 10,
		}, main)

		local dots = {}
		local dotPos = { { 16, 16 }, { 16, 10 }, { 10, 16 }, { 16, 4 }, { 10, 10 }, { 4, 16 } }
		for _, p in ipairs(dotPos) do
			local dot = create("Frame", {
				Position = UDim2.fromOffset(p[1], p[2]),
				Size = UDim2.fromOffset(3, 3),
				BackgroundColor3 = C.SubText,
				BorderSizePixel = 0,
				ZIndex = 10,
			}, handle)
			addCorner(dot, 2)
			table.insert(dots, dot)
		end

		local function dotsColor(color)
			for _, d in ipairs(dots) do
				tween(d, FAST, { BackgroundColor3 = color })
			end
		end
		track(handle.MouseEnter:Connect(function()
			dotsColor(accent)
		end))
		track(handle.MouseLeave:Connect(function()
			dotsColor(C.SubText)
		end))

		local resizing = false
		local rStart, rSize, rPos
		track(handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				resizing = true
				rStart = input.Position
				rSize = Vector2.new(main.Size.X.Offset, main.Size.Y.Offset)
				rPos = main.Position
				dotsColor(accent)
				local endConn
				endConn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						endConn:Disconnect()
						resizing = false
						dotsColor(C.SubText)
						saveValue("__size", { w = main.Size.X.Offset, h = main.Size.Y.Offset })
					end
				end)
			end
		end))
		track(UserInputService.InputChanged:Connect(function(input)
			if resizing
				and (input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - rStart
				local newW = math.clamp(rSize.X + delta.X, minSize.X, maxSize.X)
				local newH = math.clamp(rSize.Y + delta.Y, minSize.Y, maxSize.Y)
				main.Size = UDim2.fromOffset(newW, newH)
				main.Position = UDim2.new(
					rPos.X.Scale, rPos.X.Offset + (newW - rSize.X) / 2,
					rPos.Y.Scale, rPos.Y.Offset + (newH - rSize.Y) / 2
				)
			end
		end))
	end

	function Window:ResetWindow()
		main.Size = UDim2.fromOffset(config.Size and config.Size.X or 620, config.Size and config.Size.Y or 400)
		main.Position = UDim2.fromScale(0.5, 0.5)
		saveValue("__size", nil)
	end

	-- Built-in settings tab
	local function buildSettings()
		Window:CreateSidebarLine({ _order = 99999 })
		local S = Window:CreateTab({ Title = "Settings", Icon = "settings", _order = 100000, _settings = true })
		settingsTab = S

		S:CreateSection({ Text = "Tampilan", Icon = "palette" })

		local themeNow = loadValue("__theme")
		S:CreateDropdown({
			Title = "Tema",
			Options = { "Blue", "Red", "Green", "Purple", "Pink", "Yellow", "White" },
			Default = Themes[themeNow] and themeNow or nil,
			NoSave = true,
			Callback = function(name)
				Window:SetTheme(name)
			end,
		})
		S:CreateColorPicker({
			Title = "Warna Kustom",
			Default = accent,
			NoSave = true,
			Callback = function(c)
				Window:SetTheme(c)
			end,
		})
		S:CreateSlider({
			Title = "Transparansi Window",
			Min = 0,
			Max = 60,
			Default = 0,
			SaveId = "__s_trans",
			Callback = function(v)
				main.BackgroundTransparency = v / 100
			end,
		})

		S:CreateSection({ Text = "Background", Icon = "image" })
		S:CreateToggle({
			Title = "Tampilkan Background",
			Icon = "image",
			Default = true,
			SaveId = "__s_bgon",
			Callback = function(v)
				bgEnabled = v
				applyBackground()
			end,
		})
		S:CreateSlider({
			Title = "Intensitas Background",
			Min = 0,
			Max = 100,
			Default = 45,
			SaveId = "__s_bgint",
			Callback = function(v)
				bgIntensity = v
				applyBackground()
			end,
		})
		local bgBox
		bgBox = S:CreateTextBox({
			Title = "Ganti Background",
			Description = "Isi ID gambar (angka / rbxassetid://...) atau nama file gambar di folder workspace executor.",
			Placeholder = "contoh: 111062921618165",
			MaxLength = 200,
			Width = 170,
			SaveId = "__s_bgid",
			Callback = function(text)
				if text == "" then
					Window:ResetBackground()
				elseif not Window:SetBackground(text) then
					Window:Notify({ Title = "Background tidak valid", Description = "Isi angka ID atau nama file yang ada.", Duration = 4 })
				end
			end,
		})
		S:CreateButton({
			Title = "Reset Background",
			Description = "Kembali ke background See bawaan",
			Icon = "rotate-ccw",
			Callback = function()
				bgBox:Set("")
				Window:ResetBackground()
			end,
		})

		S:CreateSection({ Text = "Icon", Icon = "sparkles" })
		local iconBox
		iconBox = S:CreateTextBox({
			Title = "Ganti Icon",
			Description = "Dipakai di title bar dan tombol bulat. Isi ID gambar atau nama file.",
			Placeholder = "contoh: 79416101611283",
			MaxLength = 200,
			Width = 170,
			SaveId = "__s_iconid",
			Callback = function(text)
				if text == "" then
					Window:ResetIcon()
				elseif not Window:SetIcon(text) then
					Window:Notify({ Title = "Icon tidak valid", Description = "Isi angka ID atau nama file yang ada.", Duration = 4 })
				end
			end,
		})
		S:CreateButton({
			Title = "Reset Icon",
			Description = "Kembali ke icon See bawaan",
			Icon = "rotate-ccw",
			Callback = function()
				iconBox:Set("")
				Window:ResetIcon()
			end,
		})

		S:CreateSection({ Text = "Suara", Icon = "volume-2" })
		S:CreateToggle({
			Title = "Suara UI",
			Description = "Menyalakan atau mematikan semua suara",
			Icon = "volume-2",
			Default = true,
			SaveId = "__s_sound",
			Callback = function(v)
				soundEnabled = v
			end,
		})
		S:CreateToggle({
			Title = "Suara Klik",
			Icon = "mouse-pointer-click",
			Default = true,
			SaveId = "__s_clicksnd",
			Callback = function(v)
				clickEnabled = v
			end,
		})
		S:CreateToggle({
			Title = "Suara Hover",
			Description = "Bunyi halus saat kursor menyentuh tombol",
			Icon = "mouse-pointer",
			Default = true,
			SaveId = "__s_hoversnd",
			Callback = function(v)
				hoverEnabled = v
			end,
		})
		S:CreateSlider({
			Title = "Volume Suara",
			Min = 0,
			Max = 100,
			Default = 50,
			SaveId = "__s_vol",
			Callback = function(v)
				soundVolume = v / 100
			end,
		})
		local clickBox, hoverBox
		clickBox = S:CreateTextBox({
			Title = "Ganti Suara Klik",
			Description = "Isi ID suara (angka / rbxassetid://...) atau nama file .mp3 di folder workspace executor.",
			Placeholder = "ID suara / nama file",
			MaxLength = 200,
			Width = 170,
			SaveId = "__s_clickid",
			Callback = function(text)
				if text == "" then
					Window:ResetSound("Click")
				elseif not Window:SetSound("Click", text) then
					Window:Notify({ Title = "Suara tidak valid", Description = "Isi angka ID atau nama file yang ada.", Duration = 4 })
				end
			end,
		})
		hoverBox = S:CreateTextBox({
			Title = "Ganti Suara Hover",
			Description = "Sama seperti suara klik, tapi untuk bunyi saat kursor menyentuh tombol.",
			Placeholder = "ID suara / nama file",
			MaxLength = 200,
			Width = 170,
			SaveId = "__s_hoverid",
			Callback = function(text)
				if text == "" then
					Window:ResetSound("Hover")
				elseif not Window:SetSound("Hover", text) then
					Window:Notify({ Title = "Suara tidak valid", Description = "Isi angka ID atau nama file yang ada.", Duration = 4 })
				end
			end,
		})
		S:CreateButton({
			Title = "Tes Suara Notifikasi",
			Icon = "bell",
			Callback = function()
				playSound("Notify")
			end,
		})
		S:CreateButton({
			Title = "Reset Suara",
			Description = "Kembali ke suara klik dan hover bawaan",
			Icon = "rotate-ccw",
			Callback = function()
				clickBox:Set("")
				hoverBox:Set("")
				Window:ResetSound("Click")
				Window:ResetSound("Hover")
			end,
		})

		S:CreateSection({ Text = "Info Layar", Icon = "monitor" })
		S:CreateToggle({
			Title = "Tampilkan FPS",
			Icon = "gauge",
			Default = config.DefaultFps == true,
			SaveId = "__s_fps",
			Callback = function(v)
				showFps = v
				refreshStatsVisible()
			end,
		})
		S:CreateToggle({
			Title = "Tampilkan Ping",
			Icon = "wifi",
			Default = config.DefaultPing == true,
			SaveId = "__s_ping",
			Callback = function(v)
				showPing = v
				refreshStatsVisible()
			end,
		})
		local posDrop
		posDrop = S:CreateDropdown({
			Title = "Posisi FPS / Ping",
			Options = { "Kanan Atas", "Kiri Atas", "Tengah Atas", "Kiri Bawah", "Tengah Bawah", STATS_FREE },
			Default = "Kanan Atas",
			SaveId = "__s_statspos",
			Callback = function(name)
				setStatsPosition(name)
			end,
		})
		S:CreateParagraph({
			Title = "Geser sendiri",
			Description = 'Pilih "Bebas (geser sendiri)", lalu geser tulisan FPS/Ping di layar dengan mouse atau jari. Posisinya tersimpan.',
			Icon = "info",
		})
		S:CreateButton({
			Title = "Reset Posisi FPS / Ping",
			Icon = "rotate-ccw",
			Callback = function()
				posDrop:Set("Kanan Atas")
			end,
		})
		S:CreateToggle({
			Title = "Kartu Profil",
			Description = "Tampilkan nama dan foto di sidebar",
			Icon = "user",
			Default = config.DefaultProfile ~= false,
			SaveId = "__s_profile",
			Callback = function(v)
				setProfile(v)
			end,
		})

		S:CreateSection({ Text = "Kontrol", Icon = "keyboard" })
		S:CreateKeyBind({
			Title = "Tombol Buka/Tutup",
			Icon = "keyboard",
			Default = toggleKey or Enum.KeyCode.RightShift,
			SaveId = "__s_togglekey",
			Callback = function(kc)
				if kc and kc ~= Enum.KeyCode.Unknown then
					toggleKey = kc
				end
			end,
		})
		S:CreateToggle({
			Title = "Tombol Bulat",
			Description = "Tombol See yang bisa digeser untuk buka/tutup",
			Icon = "mouse-pointer-click",
			Default = floatEnabled,
			SaveId = "__s_float",
			Callback = function(v)
				floatBtn.Visible = v
			end,
		})
		S:CreateToggle({
			Title = "Notifikasi Saat Disembunyikan",
			Icon = "bell",
			Default = true,
			SaveId = "__s_hidenotify",
			Callback = function(v)
				hideNotify = v
			end,
		})

		-- Window
		S:CreateSection({ Text = "Window", Icon = "layout-dashboard" })
		S:CreateButton({
			Title = "Reset Posisi & Ukuran",
			Icon = "rotate-ccw",
			Callback = function()
				Window:ResetWindow()
			end,
		})
		S:CreateButton({
			Title = "Reset Semua Pengaturan",
			Description = "Menghapus semua pengaturan tersimpan. Jalankan ulang script setelahnya.",
			Icon = "trash-2",
			Confirmation = true,
			Callback = function()
				for k in pairs(saved) do
					saved[k] = nil
				end
				if canFile then
					pcall(function()
						writefile(cfgName, "{}")
					end)
				end
				Window:Notify({
					Title = "Pengaturan direset",
					Description = "Jalankan ulang script supaya semuanya kembali ke bawaan.",
					Duration = 5,
				})
			end,
		})
		S:CreateButton({
			Title = "Tutup See Library",
			Description = "Menutup UI sepenuhnya (unload)",
			Icon = "power",
			Confirmation = true,
			Callback = function()
				Window:Destroy()
			end,
		})

		S:CreateSection({ Text = "Tentang", Icon = "info" })
		S:CreateParagraph({
			Title = "See Library v" .. SeeLib.Version,
			Description = canFile and ("Pengaturan tersimpan otomatis di file " .. cfgName .. ".")
				or "Executor kamu tidak mendukung penyimpanan file, jadi pengaturan tidak tersimpan.",
			Icon = "info",
		})
	end

	showFps = config.DefaultFps == true
	showPing = config.DefaultPing == true
	refreshStatsVisible()
	setProfile(config.DefaultProfile ~= false)

	if config.Settings ~= false then
		buildSettings()
	end

	animTween = tween(scale, OPEN, { Scale = 1 })
	playSound("Open")

	table.insert(self._windows, Window)
	return Window
end

function SeeLib:Destroy()
	for _, window in ipairs(self._windows) do
		window:Destroy()
	end
	self._windows = {}
end

return SeeLib
