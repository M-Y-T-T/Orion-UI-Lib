local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local HttpService = game:GetService("HttpService")

local OrionLib = {
	Elements = {},
	ThemeObjects = {},
	Connections = {},
	Flags = {},
	Themes = {
		Default = {
			Main = Color3.fromRGB(25, 25, 25),
			Second = Color3.fromRGB(32, 32, 32),
			Stroke = Color3.fromRGB(60, 60, 60),
			Divider = Color3.fromRGB(60, 60, 60),
			Text = Color3.fromRGB(240, 240, 240),
			TextDark = Color3.fromRGB(150, 150, 150)
		}
	},
	SelectedTheme = "Default",
	Folder = nil,
	SaveCfg = false
}

--Feather Icons https://github.com/evoincorp/lucideblox/tree/master/src/modules/util - Created by 7kayoh
local Icons = {}

local Success, Response = pcall(function()
	Icons = HttpService:JSONDecode(game:HttpGetAsync("https://raw.githubusercontent.com/evoincorp/lucideblox/master/src/modules/util/icons.json")).icons
end)

if not Success then
	warn("\nOrion Library - Failed to load Feather Icons. Error code: " .. Response .. "\n")
end

local function GetIcon(IconName)
	if Icons[IconName] ~= nil then
		return Icons[IconName]
	else
		return nil
	end
end

local Orion = Instance.new("ScreenGui")
Orion.Name = "Orion"
if syn then
	syn.protect_gui(Orion)
	Orion.Parent = game:GetService("CoreGui") -- Prefer CoreGui if syn is available
else
	Orion.Parent = gethui and gethui() or game:GetService("CoreGui")
end

if gethui then
	for _, Interface in ipairs(gethui():GetChildren()) do
		if Interface:IsA("ScreenGui") and Interface.Name == Orion.Name and Interface ~= Orion then
			Interface:Destroy()
		end
	end
elseif game:GetService("CoreGui") then
	for _, Interface in ipairs(game:GetService("CoreGui"):GetChildren()) do
		if Interface:IsA("ScreenGui") and Interface.Name == Orion.Name and Interface ~= Orion then
			Interface:Destroy()
		end
	end
end

function OrionLib:IsRunning()
	return Orion.Parent ~= nil and (Orion.Parent == (gethui and gethui() or game:GetService("CoreGui")))
end

local function AddConnection(Signal, Function)
	if (not OrionLib:IsRunning()) then
		return { Disconnect = function() end } -- Return dummy connection if not running
	end
	local SignalConnect = Signal:Connect(Function)
	table.insert(OrionLib.Connections, SignalConnect)
	return SignalConnect
end

task.spawn(function()
	while OrionLib:IsRunning() do
		task.wait() -- Use task.wait()
	end

	for _, Connection in pairs(OrionLib.Connections) do -- Use pairs for potentially sparse table
		if typeof(Connection.Disconnect) == "function" then
			Connection:Disconnect()
		end
	end
	OrionLib.Connections = {} -- Clear connections
end)

--[[ Enhanced MakeDraggable with TweenService ]]
local function MakeDraggable(DragPoint, Main)
	pcall(function()
		local Dragging, DragInput, MousePos, FramePos = false
		local dragTween = nil

		AddConnection(DragPoint.InputBegan, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				Dragging = true
				MousePos = Input.Position
				FramePos = Main.Position

				if dragTween and dragTween.PlaybackState == Enum.PlaybackState.Playing then
					dragTween:Cancel() -- Cancel any ongoing drag tween
				end

				local ChangedConnection
				ChangedConnection = Input.Changed:Connect(function()
					if Input.UserInputState == Enum.UserInputState.End then
						Dragging = false
						if ChangedConnection then
							ChangedConnection:Disconnect()
							ChangedConnection = nil
						end
					end
				end)
			end
		end)

		AddConnection(DragPoint.InputChanged, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
				DragInput = Input
			end
		end)

		-- Use RunService for smoother updates
		AddConnection(RunService.Heartbeat, function()
			if Dragging and DragInput then
				local Delta = DragInput.Position - MousePos
				local TargetPosition = UDim2.new(FramePos.X.Scale, FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)

				-- Cancel previous tween if still playing and target is different
				if dragTween and dragTween.PlaybackState == Enum.PlaybackState.Playing then
					local currentGoal = dragTween.Goal.Position
                    if currentGoal.X.Scale ~= TargetPosition.X.Scale or currentGoal.X.Offset ~= TargetPosition.X.Offset or currentGoal.Y.Scale ~= TargetPosition.Y.Scale or currentGoal.Y.Offset ~= TargetPosition.Y.Offset then
                        dragTween:Cancel()
						dragTween = nil
                    else
						return -- Already tweening to the same position
					end
				end

				-- Create and play new tween if not already tweening or cancelled
				if not dragTween or dragTween.PlaybackState ~= Enum.PlaybackState.Playing then
					dragTween = TweenService:Create(Main, TweenInfo.new(0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = TargetPosition })
					dragTween:Play()
				end
				-- Direct assignment removed for tweening: Main.Position = TargetPosition
			elseif not Dragging and dragTween and dragTween.PlaybackState == Enum.PlaybackState.Playing then
				-- Optional: Allow tween to finish naturally or cancel it immediately when dragging stops
				-- dragTween:Cancel()
			end
		end)
	end)
end

local function Create(Name, Properties, Children)
	local Object = Instance.new(Name)
	for i, v in next, Properties or {} do
		Object[i] = v
	end
	for i, v in next, Children or {} do
		v.Parent = Object
	end
	return Object
end

local function CreateElement(ElementName, ElementFunction)
	OrionLib.Elements[ElementName] = function(...)
		return ElementFunction(...)
	end
end

local function MakeElement(ElementName, ...)
	local NewElement = OrionLib.Elements[ElementName](...)
	return NewElement
end

local function SetProps(Element, Props)
	for Property, Value in pairs(Props) do -- Use pairs for dictionaries
		Element[Property] = Value
	end
	return Element
end

local function SetChildren(Element, Children)
	for _, Child in ipairs(Children) do -- Use ipairs for arrays
		Child.Parent = Element
	end
	return Element
end

local function Round(Number, Factor)
    if Factor == 0 then return Number end
	local Result = math.floor(Number/Factor + (math.sign(Number) * 0.5)) * Factor
	-- No need for the < 0 check if Factor is positive
	return Result
end

local function ReturnProperty(Object)
	if Object:IsA("Frame") or Object:IsA("TextButton") or Object:IsA("ImageButton") then -- Added ImageButton
		return "BackgroundColor3"
	end
	if Object:IsA("ScrollingFrame") then
		return "ScrollBarImageColor3"
	end
	if Object:IsA("UIStroke") then
		return "Color"
	end
	if Object:IsA("TextLabel") or Object:IsA("TextBox") then
		return "TextColor3"
	end
	if Object:IsA("ImageLabel") then -- Removed ImageButton here
		return "ImageColor3"
	end
	return nil -- Return nil if no property found
end

local function AddThemeObject(Object, Type)
	if not OrionLib.ThemeObjects[Type] then
		OrionLib.ThemeObjects[Type] = {}
	end
	table.insert(OrionLib.ThemeObjects[Type], Object)
    local prop = ReturnProperty(Object)
    if prop then
	    Object[prop] = OrionLib.Themes[OrionLib.SelectedTheme][Type]
    end
	return Object
end

local function SetTheme()
	local selectedThemeData = OrionLib.Themes[OrionLib.SelectedTheme]
	for Name, Type in pairs(OrionLib.ThemeObjects) do
		local themeColor = selectedThemeData[Name]
		if themeColor then
			for _, Object in pairs(Type) do
                local prop = ReturnProperty(Object)
                if prop and Object then -- Check if object still exists
				    Object[prop] = themeColor
                end
			end
		end
	end
end

local function PackColor(Color)
	return {R = math.floor(Color.R * 255 + 0.5), G = math.floor(Color.G * 255 + 0.5), B = math.floor(Color.B * 255 + 0.5)}
end

local function UnpackColor(Color)
	return Color3.fromRGB(Color.R, Color.G, Color.B)
end

local function LoadCfg(Config)
    pcall(function() -- Wrap in pcall for safety
	    local Data = HttpService:JSONDecode(Config)
	    for a, b in pairs(Data) do
		    if OrionLib.Flags[a] then
			    task.spawn(function() -- Use task.spawn for concurrency
				    if OrionLib.Flags[a].Type == "Colorpicker" then
					    OrionLib.Flags[a]:Set(UnpackColor(b))
				    else
					    OrionLib.Flags[a]:Set(b)
				    end
			    end)
		    else
			    warn("Orion Library Config Loader - Could not find flag: ", a)
		    end
	    end
    end)
end

local function SaveCfg(Name)
    if not OrionLib.SaveCfg then return end -- Check if saving is enabled
    pcall(function() -- Wrap in pcall for safety
	    local Data = {}
	    for i, v in pairs(OrionLib.Flags) do
		    if v.Save then
			    if v.Type == "Colorpicker" then
				    Data[i] = PackColor(v.Value)
			    else
				    Data[i] = v.Value
			    end
		    end
	    end
	    writefile(OrionLib.Folder .. "/" .. Name .. ".txt", HttpService:JSONEncode(Data))
    end)
end

-- Standard hover/click colors
local function GetHoverColor(baseColor)
	return Color3.fromRGB(
		math.min(255, math.floor(baseColor.R * 255 + 0.5) + 5),
		math.min(255, math.floor(baseColor.G * 255 + 0.5) + 5),
		math.min(255, math.floor(baseColor.B * 255 + 0.5) + 5)
	)
end

local function GetClickColor(baseColor)
	return Color3.fromRGB(
		math.min(255, math.floor(baseColor.R * 255 + 0.5) + 10),
		math.min(255, math.floor(baseColor.G * 255 + 0.5) + 10),
		math.min(255, math.floor(baseColor.B * 255 + 0.5) + 10)
	)
end

-- Standard tween info
local TWEEN_INFO_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_INFO_NORMAL = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_INFO_SLOW = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local WhitelistedMouse = {Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2,Enum.UserInputType.MouseButton3}
local BlacklistedKeys = {Enum.KeyCode.Unknown,Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,Enum.KeyCode.Up,Enum.KeyCode.Left,Enum.KeyCode.Down,Enum.KeyCode.Right,Enum.KeyCode.Slash,Enum.KeyCode.Tab,Enum.KeyCode.Backspace,Enum.KeyCode.Escape}

local function CheckKey(Table, Key)
	for _, v in ipairs(Table) do -- Use ipairs for arrays
		if v == Key then
			return true
		end
	end
	return false -- Explicitly return false
end

CreateElement("Corner", function(Scale, Offset)
	local Corner = Create("UICorner", {
		CornerRadius = UDim.new(Scale or 0, Offset or 10)
	})
	return Corner
end)

CreateElement("Stroke", function(Color, Thickness)
	local Stroke = Create("UIStroke", {
		Color = Color or Color3.fromRGB(255, 255, 255),
		Thickness = Thickness or 1
	})
	return Stroke
end)

CreateElement("List", function(Scale, Offset)
	local List = Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(Scale or 0, Offset or 0)
	})
	return List
end)

CreateElement("Padding", function(Bottom, Left, Right, Top)
	local Padding = Create("UIPadding", {
		PaddingBottom = UDim.new(0, Bottom or 4),
		PaddingLeft = UDim.new(0, Left or 4),
		PaddingRight = UDim.new(0, Right or 4),
		PaddingTop = UDim.new(0, Top or 4)
	})
	return Padding
end)

CreateElement("TFrame", function()
	local TFrame = Create("Frame", {
		BackgroundTransparency = 1,
        BorderSizePixel = 0 -- Ensure consistency
	})
	return TFrame
end)

CreateElement("Frame", function(Color)
	local Frame = Create("Frame", {
		BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0
	})
	return Frame
end)

CreateElement("RoundFrame", function(Color, Scale, Offset)
	local Frame = Create("Frame", {
		BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0
	}, {
		Create("UICorner", {
			CornerRadius = UDim.new(Scale or 0, Offset or 5) -- Default to 5 offset for consistency
		})
	})
	return Frame
end)

CreateElement("Button", function()
	local Button = Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0
	})
	return Button
end)

CreateElement("ScrollFrame", function(Color, Width)
	local ScrollFrame = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		MidImage = "rbxassetid://7445543667",
		BottomImage = "rbxassetid://7445543667",
		TopImage = "rbxassetid://7445543667",
		ScrollBarImageColor3 = Color or Color3.fromRGB(60, 60, 60), -- Use theme divider color as default
		BorderSizePixel = 0,
		ScrollBarThickness = Width or 5, -- Slightly thicker default
		CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y, -- Explicitly set Y
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        HorizontalScrollBarInset = Enum.ScrollBarInset.None -- Usually only vertical needed
	})
	return ScrollFrame
end)

CreateElement("Image", function(ImageID)
	local ImageNew = Create("ImageLabel", {
		Image = ImageID or "",
		BackgroundTransparency = 1
	})

	if ImageID and GetIcon(ImageID) then
		ImageNew.Image = GetIcon(ImageID)
	end

	return ImageNew
end)

CreateElement("ImageButton", function(ImageID)
	local Image = Create("ImageButton", {
		Image = ImageID or "",
		BackgroundTransparency = 1,
        AutoButtonColor = false -- Disable default behavior
	})
	return Image
end)

CreateElement("Label", function(Text, TextSize, Transparency)
	local Label = Create("TextLabel", {
		Text = Text or "",
		TextColor3 = Color3.fromRGB(240, 240, 240),
		TextTransparency = Transparency or 0,
		TextSize = TextSize or 14, -- Slightly smaller default
		Font = Enum.Font.GothamSemibold, -- Change default font
		RichText = true,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	return Label
end)

local NotificationHolder = SetProps(SetChildren(MakeElement("TFrame"), {
	SetProps(MakeElement("List"), {
		HorizontalAlignment = Enum.HorizontalAlignment.Right, -- Align right
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 8) -- Slightly more padding
	})
}), {
	Position = UDim2.new(1, -10, 0, 0), -- Position from top right
	Size = UDim2.new(0, 300, 1, -10), -- Relative to top right
	AnchorPoint = Vector2.new(1, 0), -- Anchor top right
	Parent = Orion
})

function OrionLib:MakeNotification(NotificationConfig)
	spawn(function()
		NotificationConfig.Name = NotificationConfig.Name or "Notification"
		NotificationConfig.Content = NotificationConfig.Content or "Test"
		NotificationConfig.Image = NotificationConfig.Image or "rbxassetid://4384403532"
		NotificationConfig.Time = NotificationConfig.Time or 5 -- Shorter default time

		local notificationTheme = OrionLib.Themes[OrionLib.SelectedTheme]

		local NotificationParent = SetProps(MakeElement("TFrame"), {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = NotificationHolder,
            ClipsDescendants = true, -- Clip descendants for animations
            LayoutOrder = tick() -- Ensure newest are on top
		})

		local NotificationFrame = SetChildren(SetProps(MakeElement("RoundFrame", notificationTheme.Main, 0, 8), { -- Smaller corner radius
			Parent = NotificationParent,
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.new(1, 10, 0, 0), -- Start off-screen right
			BackgroundTransparency = 0.1, -- Slightly transparent
			AutomaticSize = Enum.AutomaticSize.Y
		}), {
			MakeElement("Stroke", notificationTheme.Stroke, 1), -- Thinner stroke
			MakeElement("Padding", 10, 10, 10, 10), -- Slightly less padding
			SetProps(MakeElement("Image", NotificationConfig.Image), {
				Size = UDim2.new(0, 20, 0, 20),
				ImageColor3 = notificationTheme.Text,
				Name = "Icon",
                LayoutOrder = 1
			}),
			SetProps(MakeElement("Label", "<b>" .. NotificationConfig.Name .. "</b>", 15), { -- Use bold tag
				Size = UDim2.new(1, -30, 0, 20),
				Position = UDim2.new(0, 30, 0, 0),
				Font = Enum.Font.GothamBold,
				Name = "Title",
                TextColor3 = notificationTheme.Text,
                LayoutOrder = 2
			}),
			SetProps(MakeElement("Label", NotificationConfig.Content, 14), {
				Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.new(0, 0, 0, 25),
				Font = Enum.Font.GothamSemibold,
				Name = "Content",
				AutomaticSize = Enum.AutomaticSize.Y,
				TextColor3 = notificationTheme.TextDark,
				TextWrapped = true,
                LayoutOrder = 3
			})
		})

        -- Intro Animation
		TweenService:Create(NotificationFrame, TWEEN_INFO_NORMAL, {Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.1}):Play()

		task.wait(NotificationConfig.Time) -- Wait for the specified time

        -- Outro Animation
        local fadeOutTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(NotificationFrame, fadeOutTweenInfo, {Position = UDim2.new(-1, -10, 0, 0), BackgroundTransparency = 1}):Play() -- Slide out left and fade

        -- Fade out children slightly faster
        local childrenFadeTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(NotificationFrame.Icon, childrenFadeTweenInfo, {ImageTransparency = 1}):Play()
		TweenService:Create(NotificationFrame.Title, childrenFadeTweenInfo, {TextTransparency = 1}):Play()
		TweenService:Create(NotificationFrame.Content, childrenFadeTweenInfo, {TextTransparency = 1}):Play()
        TweenService:Create(NotificationFrame:FindFirstChildOfClass("UIStroke"), childrenFadeTweenInfo, {Transparency = 1}):Play()

		task.wait(0.5) -- Wait for animation to mostly finish before destroying
		NotificationParent:Destroy() -- Destroy the parent holder
	end)
end

function OrionLib:Init()
	if OrionLib.SaveCfg then
		pcall(function()
            local configFileName = OrionLib.Folder .. "/" .. game.GameId .. ".txt"
			if isfile(configFileName) then
				LoadCfg(readfile(configFileName))
				OrionLib:MakeNotification({
					Name = "Configuration Loaded",
					Content = "Loaded configuration for game " .. game.GameId .. ".",
					Time = 4 -- Shorter time
				})
			end
		end)
	end
end

function OrionLib:MakeWindow(WindowConfig)
	local FirstTab = true
	local Minimized = false
	local Loaded = false
	local UIHidden = false
    local CurrentTab = nil -- Keep track of the selected tab

	WindowConfig = WindowConfig or {}
	WindowConfig.Name = WindowConfig.Name or "Orion Library"
	WindowConfig.ConfigFolder = WindowConfig.ConfigFolder or WindowConfig.Name
	WindowConfig.SaveConfig = WindowConfig.SaveConfig or false
	WindowConfig.HidePremium = WindowConfig.HidePremium or false
	if WindowConfig.IntroEnabled == nil then WindowConfig.IntroEnabled = true end
	WindowConfig.IntroText = WindowConfig.IntroText or "Orion Library"
	WindowConfig.CloseCallback = WindowConfig.CloseCallback or function() end
	WindowConfig.ShowIcon = WindowConfig.ShowIcon or false
	WindowConfig.Icon = WindowConfig.Icon or "rbxassetid://8834748103" -- Default Orion Icon
	WindowConfig.IntroIcon = WindowConfig.IntroIcon or "rbxassetid://8834748103" -- Default Orion Icon
	OrionLib.Folder = WindowConfig.ConfigFolder
	OrionLib.SaveCfg = WindowConfig.SaveConfig

	if WindowConfig.SaveConfig then
		if not isfolder(WindowConfig.ConfigFolder) then
			makefolder(WindowConfig.ConfigFolder)
		end
	end

    local windowTheme = OrionLib.Themes[OrionLib.SelectedTheme]

	local TabHolder = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", windowTheme.Divider, 4), {
		Size = UDim2.new(1, 0, 1, -50),
        Position = UDim2.new(0, 0, 0, 0), -- Position at top
        BackgroundTransparency = 1 -- Ensure transparent background
	}), {
		MakeElement("List", 0, 4), -- Add some padding between tabs
		MakeElement("Padding", 8, 8, 8, 8) -- Padding inside the holder
	}), "Divider") -- Using Divider color for scrollbar

	AddConnection(TabHolder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		TabHolder.CanvasSize = UDim2.new(0, 0, 0, TabHolder.UIListLayout.AbsoluteContentSize.Y + TabHolder.UIPadding.PaddingTop.Offset + TabHolder.UIPadding.PaddingBottom.Offset) -- Adjust for padding
	end)

    -- Button Control Frame (for Close/Minimize)
	local ButtonControlFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", windowTheme.Second, 0, 7), {
		Size = UDim2.new(0, 70, 0, 30),
		Position = UDim2.new(1, -80, 0, 10), -- Adjusted position slightly
        Name = "ButtonControls"
	}), {
		AddThemeObject(MakeElement("Stroke"), "Stroke"),
		AddThemeObject(SetProps(MakeElement("Frame"), { -- Divider line
			Size = UDim2.new(0, 1, 1, -10), -- Slightly smaller divider
            Position = UDim2.new(0.5, 0, 0, 5),
            AnchorPoint = Vector2.new(0.5, 0)
		}), "Stroke"),
        -- Minimize Button (Left Side)
        SetChildren(SetProps(MakeElement("Button"), {
            Size = UDim2.new(0.5, -1, 1, 0), -- Adjusted size for divider
            Position = UDim2.new(0, 0, 0, 0),
            Name = "MinimizeButton"
        }), {
            AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072719338"), { -- Minimize icon
                Position = UDim2.new(0.5, 0, 0.5, 0), -- Center icon
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.new(0, 16, 0, 16), -- Slightly smaller icon
                Name = "Ico"
            }), "Text")
        }),
		-- Close Button (Right Side)
		SetChildren(SetProps(MakeElement("Button"), {
			Size = UDim2.new(0.5, -1, 1, 0), -- Adjusted size for divider
			Position = UDim2.new(0.5, 1, 0, 0), -- Position right of divider
            Name = "CloseButton"
		}), {
			AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072725342"), { -- Close icon
				Position = UDim2.new(0.5, 0, 0.5, 0), -- Center icon
                AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(0, 16, 0, 16) -- Slightly smaller icon
			}), "Text")
		})
	}), "Second")

    local CloseBtn = ButtonControlFrame.CloseButton
    local MinimizeBtn = ButtonControlFrame.MinimizeButton

	local DragPoint = SetProps(MakeElement("TFrame"), {
		Size = UDim2.new(1, 0, 0, 50),
        ZIndex = 2 -- Ensure drag point is above other top bar elements if needed
	})

	local WindowStuff = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", windowTheme.Second, 0, 8), { -- Left panel slightly rounded
		Size = UDim2.new(0, 150, 1, -50),
		Position = UDim2.new(0, 0, 0, 50)
	}), {
        --[[ Removed extra theme frames, rely on parent RoundFrame
		AddThemeObject(SetProps(MakeElement("Frame"), {
			Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 0, 0)
		}), "Second"),
		AddThemeObject(SetProps(MakeElement("Frame"), {
			Size = UDim2.new(0, 10, 1, 0), Position = UDim2.new(1, -10, 0, 0)
		}), "Second"),
		AddThemeObject(SetProps(MakeElement("Frame"), {
			Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0)
		}), "Stroke"),
        ]]
        AddThemeObject(SetProps(MakeElement("Frame"), { -- Divider line on the right
			Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0)
		}), "Stroke"),
		TabHolder,
		SetChildren(SetProps(MakeElement("TFrame"), { -- Bottom User Info Area
			Size = UDim2.new(1, 0, 0, 50),
			Position = UDim2.new(0, 0, 1, -50)
		}), {
			AddThemeObject(SetProps(MakeElement("Frame"), { -- Top Divider Line
				Size = UDim2.new(1, 0, 0, 1)
			}), "Stroke"),
			AddThemeObject(SetChildren(SetProps(MakeElement("Frame"), { -- User Headshot Frame
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0, 32, 0, 32),
				Position = UDim2.new(0, 10, 0.5, 0),
                BackgroundTransparency = 1 -- Make frame transparent
			}), {
				SetProps(MakeElement("Image", "https://www.roblox.com/headshot-thumbnail/image?userId=".. LocalPlayer.UserId .."&width=420&height=420&format=png"), {
					Size = UDim2.new(1, 0, 1, 0),
                    ZIndex = 2
				}),
				AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://4031889928"), { -- Background circle?
					Size = UDim2.new(1, 0, 1, 0),
                    ImageTransparency = 0.5, -- Make it slightly transparent
                    ZIndex = 1
				}), "Second"),
				MakeElement("Corner", 1, 0) -- Make it a circle
			}), "Divider"),
			--[[ Removed extra stroke frame around headshot
			SetChildren(SetProps(MakeElement("TFrame"), {
				AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(0, 10, 0.5, 0)
			}), {
				AddThemeObject(MakeElement("Stroke"), "Stroke"), MakeElement("Corner", 1)
			}),
            ]]
			AddThemeObject(SetProps(MakeElement("Label", "<b>" .. LocalPlayer.DisplayName .. "</b>", WindowConfig.HidePremium and 14 or 13), { -- Bold username
				Size = UDim2.new(1, -55, 0, 13), -- Adjusted size
				Position = WindowConfig.HidePremium and UDim2.new(0, 50, 0.5, -7) or UDim2.new(0, 50, 0, 12), -- Centered Y slightly if premium hidden
				AnchorPoint = WindowConfig.HidePremium and Vector2.new(0, 0.5) or Vector2.new(0, 0),
                Font = Enum.Font.GothamBold,
				ClipsDescendants = true
			}), "Text"),
			AddThemeObject(SetProps(MakeElement("Label", "@" .. LocalPlayer.Name, 12), { -- Show @Name if not premium hidden
				Size = UDim2.new(1, -60, 0, 12),
				Position = UDim2.new(0, 50, 1, -18), -- Position below display name
                AnchorPoint = Vector2.new(0, 1),
				Visible = not WindowConfig.HidePremium,
                Font = Enum.Font.Gotham, -- Regular font
                TextXAlignment = Enum.TextXAlignment.Left
			}), "TextDark")
		}),
	}), "Second")

	local WindowName = AddThemeObject(SetProps(MakeElement("Label", WindowConfig.Name, 20), { -- Larger default size
		Size = UDim2.new(1, -30, 1, 0), -- Full height of top bar
		Position = UDim2.new(0, WindowConfig.ShowIcon and 50 or 15, 0, 0), -- Adjust position based on icon
		Font = Enum.Font.GothamBlack,
        TextYAlignment = Enum.TextYAlignment.Center, -- Center vertically
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 1 -- Below DragPoint
	}), "Text")

	local WindowTopBarLine = AddThemeObject(SetProps(MakeElement("Frame"), {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
        ZIndex = 2 -- Above other elements
	}), "Stroke")

    local TopBarFrame = SetChildren(SetProps(MakeElement("TFrame"), {
        Size = UDim2.new(1, 0, 0, 50),
        Name = "TopBar"
    }), {
        WindowName,
        WindowTopBarLine,
        ButtonControlFrame, -- Add the button controls here
        DragPoint -- Add DragPoint last so it's visually behind but functionally on top due to ZIndex
    })

	local MainWindow = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", windowTheme.Main, 0, 10), { -- Main Background
		Parent = Orion,
		Position = UDim2.new(0.5, 0, 0.5, 0), -- Center screen default
        AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 615, 0, 344),
		ClipsDescendants = true
	}), {
		--[[ Removed background noise image
		SetProps(MakeElement("Image", "rbxassetid://3523728077"), {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 80, 1, 320), ImageColor3 = Color3.fromRGB(33, 33, 33), ImageTransparency = 0.7
		}),
        ]]
        TopBarFrame,
		WindowStuff -- Left panel containing tabs and user info
	}), "Main")

	if WindowConfig.ShowIcon then
		local WindowIcon = SetProps(MakeElement("Image", WindowConfig.Icon), {
			Size = UDim2.new(0, 24, 0, 24), -- Slightly larger icon
			Position = UDim2.new(0, 15, 0.5, 0), -- Position near left edge, centered vertically
            AnchorPoint = Vector2.new(0, 0.5),
            ZIndex = 2 -- Ensure icon is visible
		})
		WindowIcon.Parent = TopBarFrame
	end

	MakeDraggable(DragPoint, MainWindow)

    -- Hover/Click effects for Close/Minimize buttons
	local function setupTopButtonEffects(button, parentFrame)
		local baseColor = windowTheme.Second
		local hoverColor = GetHoverColor(baseColor)
		local clickColor = GetClickColor(baseColor)

		AddConnection(button.MouseEnter, function() TweenService:Create(parentFrame, TWEEN_INFO_FAST, { BackgroundColor3 = hoverColor }):Play() end)
		AddConnection(button.MouseLeave, function() TweenService:Create(parentFrame, TWEEN_INFO_FAST, { BackgroundColor3 = baseColor }):Play() end)
		AddConnection(button.MouseButton1Down, function() TweenService:Create(parentFrame, TWEEN_INFO_FAST, { BackgroundColor3 = clickColor }):Play() end)
		AddConnection(button.MouseButton1Up, function()
            local mousePos = UserInputService:GetMouseLocation()
            local absPos, absSize = parentFrame.AbsolutePosition, parentFrame.AbsoluteSize
            if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X and mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then
                TweenService:Create(parentFrame, TWEEN_INFO_FAST, { BackgroundColor3 = hoverColor }):Play() -- Return to hover if mouse still over
            else
                TweenService:Create(parentFrame, TWEEN_INFO_FAST, { BackgroundColor3 = baseColor }):Play() -- Return to base if mouse left
            end
        end)
	end

	setupTopButtonEffects(CloseBtn, ButtonControlFrame)
	setupTopButtonEffects(MinimizeBtn, ButtonControlFrame)


	AddConnection(CloseBtn.MouseButton1Click, function() -- Use Click instead of Up
        TweenService:Create(MainWindow, TWEEN_INFO_NORMAL, { Size = MainWindow.Size * 0.9, Transparency = 1 }):Play() -- Shrink and fade out effect
        task.wait(0.25)
		MainWindow.Visible = false
        MainWindow.Size = UDim2.new(0, 615, 0, 344) -- Reset size and transparency for next show
        MainWindow.Transparency = 0
		UIHidden = true
		OrionLib:MakeNotification({
			Name = "Interface Hidden",
			Content = "Press RightShift to reopen.",
			Time = 4
		})
		pcall(WindowConfig.CloseCallback) -- Safely call callback
	end)

	AddConnection(UserInputService.InputBegan, function(Input)
		if Input.KeyCode == Enum.KeyCode.RightShift and UIHidden then
			UIHidden = false
            MainWindow.Visible = true
            MainWindow.Size = UDim2.new(0, 615, 0, 344) * 0.9 -- Start small and transparent
            MainWindow.Transparency = 1
            TweenService:Create(MainWindow, TWEEN_INFO_NORMAL, { Size = UDim2.new(0, 615, 0, 344), Transparency = 0 }):Play() -- Scale up and fade in
		end
	end)

	AddConnection(MinimizeBtn.MouseButton1Click, function() -- Use Click instead of Up
        local targetSize
        local targetClipsDescendants
        local targetTopBarLineVisible
        local targetWindowStuffVisible
        local targetIcon

		if Minimized then
			targetSize = UDim2.new(0, 615, 0, 344)
			targetIcon = "rbxassetid://7072719338" -- Minimize icon
            targetClipsDescendants = false
            targetTopBarLineVisible = true
            targetWindowStuffVisible = true
		else
            local minWidth = WindowName.TextBounds.X + (WindowConfig.ShowIcon and 50 or 15) + 90 -- Name pos + Name width + Button Controls width + padding
			targetSize = UDim2.new(0, math.max(200, minWidth), 0, 50) -- Ensure minimum width
			targetIcon = "rbxassetid://7072720870" -- Maximize icon (up arrow)
            targetClipsDescendants = true
            targetTopBarLineVisible = false
            targetWindowStuffVisible = false
		end

		Minimized = not Minimized -- Toggle state first

        -- Perform animations
        if not Minimized then -- If maximizing
            MainWindow.ClipsDescendants = targetClipsDescendants -- Allow content to show immediately
            WindowStuff.Visible = targetWindowStuffVisible
			WindowTopBarLine.Visible = targetTopBarLineVisible
        end

        TweenService:Create(MainWindow, TWEEN_INFO_SLOW, { Size = targetSize }):Play()
		MinimizeBtn.Ico.Image = targetIcon

        task.delay(Minimized and 0 or 0.1, function() -- Delay hiding if minimizing, show immediately if maximizing
            if Minimized then -- If minimizing (state is now true)
                 MainWindow.ClipsDescendants = targetClipsDescendants -- Clip after starting shrink
            end
            WindowStuff.Visible = targetWindowStuffVisible
			WindowTopBarLine.Visible = targetTopBarLineVisible
        end)
	end)

	local function LoadSequence()
        if not WindowConfig.IntroEnabled then
            MainWindow.Visible = true
            OrionLib:Init() -- Init config after potentially showing window
            return
        end

		MainWindow.Visible = false
        local introTheme = OrionLib.Themes[OrionLib.SelectedTheme]

		local LoadSequenceLogo = SetProps(MakeElement("Image", WindowConfig.IntroIcon), {
			Parent = Orion,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.45, 0), -- Start slightly higher
			Size = UDim2.new(0, 48, 0, 48), -- Larger logo
			ImageColor3 = introTheme.Text,
			ImageTransparency = 1,
            Rotation = -15 -- Start slightly rotated
		})

		local LoadSequenceText = SetProps(MakeElement("Label", WindowConfig.IntroText, 16), { -- Larger text
			Parent = Orion,
			Size = UDim2.new(1, 0, 0, 30), -- Fixed height
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.55, 20), -- Start below and off-center
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Enum.Font.GothamBold,
			TextTransparency = 1,
            TextColor3 = introTheme.TextDark
		})

        -- Logo fade in and drop/rotate
		TweenService:Create(LoadSequenceLogo, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            ImageTransparency = 0,
            Position = UDim2.new(0.5, 0, 0.5, -10), -- Settle above center
            Rotation = 0
        }):Play()

		task.wait(0.4) -- Wait slightly before text appears

        -- Text fade in and slide up
		TweenService:Create(LoadSequenceText, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            TextTransparency = 0,
            Position = UDim2.new(0.5, 0, 0.5, 20) -- Settle below logo
        }):Play()

		task.wait(1.5) -- Hold time

        -- Fade out logo and text
        local fadeOutTween = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		TweenService:Create(LoadSequenceLogo, fadeOutTween, { ImageTransparency = 1, Position = UDim2.new(0.5, 0, 0.45, 0) }):Play() -- Fade out upwards
		TweenService:Create(LoadSequenceText, fadeOutTween, { TextTransparency = 1, Position = UDim2.new(0.5, 0, 0.55, 40)}):Play() -- Fade out downwards

		task.wait(0.4) -- Wait for fade out

		MainWindow.Visible = true
        MainWindow.Size = UDim2.new(0, 615, 0, 344) * 0.9 -- Start slightly smaller
        MainWindow.Transparency = 1 -- Start transparent
        TweenService:Create(MainWindow, TWEEN_INFO_NORMAL, { Size = UDim2.new(0, 615, 0, 344), Transparency = 0 }):Play() -- Fade/Scale in window

        OrionLib:Init() -- Init config after intro

		LoadSequenceLogo:Destroy()
		LoadSequenceText:Destroy()
	end

    LoadSequence() -- Run the sequence

	local TabFunction = {}
	function TabFunction:MakeTab(TabConfig)
		TabConfig = TabConfig or {}
		TabConfig.Name = TabConfig.Name or "Tab"
		TabConfig.Icon = TabConfig.Icon or "rbxassetid://5107100128" -- Default icon (e.g., list)
		TabConfig.PremiumOnly = TabConfig.PremiumOnly or false

        local tabTheme = OrionLib.Themes[OrionLib.SelectedTheme]
        local isSelected = false

        -- Container for tab elements allowing background tween
        local TabContainer = AddThemeObject(SetProps(MakeElement("RoundFrame", tabTheme.Second, 0, 6), {
            Size = UDim2.new(1, 0, 0, 35), -- Slightly taller tabs
            Parent = TabHolder,
            BackgroundTransparency = 1 -- Start transparent
        }), "Second") -- Base color is Second, but transparent initially

		local TabFrame = SetChildren(SetProps(MakeElement("Button"), {
			Size = UDim2.new(1, 0, 1, 0),
            Parent = TabContainer,
            BackgroundTransparency = 1 -- Button itself is transparent
		}), {
			AddThemeObject(SetProps(MakeElement("Image", TabConfig.Icon), {
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0, 18, 0, 18),
				Position = UDim2.new(0, 12, 0.5, 0), -- Indent icon slightly more
				ImageTransparency = 0.6, -- Start more transparent
				Name = "Ico"
			}), "Text"),
			AddThemeObject(SetProps(MakeElement("Label", TabConfig.Name, 14), {
				Size = UDim2.new(1, -35, 1, 0),
				Position = UDim2.new(0, 40, 0, 0), -- Position text next to icon
				Font = Enum.Font.GothamSemibold,
				TextTransparency = 0.6, -- Start more transparent
				Name = "Title",
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center
			}), "Text")
		})

		if GetIcon(TabConfig.Icon) then
			TabFrame.Ico.Image = GetIcon(TabConfig.Icon)
		end

		local Container = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", windowTheme.Divider, 5), {
			Size = UDim2.new(1, -150, 1, -50), -- Size relative to main window parts
			Position = UDim2.new(0, 150, 0, 50),
			Parent = MainWindow,
			Visible = false,
            BackgroundTransparency = 1, -- Content area is transparent
			Name = "ItemContainer"
		}), {
			MakeElement("List", 0, 8), -- Increased spacing between elements
			MakeElement("Padding", 15, 15, 15, 15) -- Uniform padding
		}), "Divider") -- Scrollbar color

		AddConnection(Container.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
            local listLayout = Container.UIListLayout
            local padding = Container.UIPadding
			Container.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + padding.PaddingTop.Offset + padding.PaddingBottom.Offset) -- Include padding in canvas size calculation
		end)

        local function SetSelected(selected)
            isSelected = selected
            local targetIconTransparency = selected and 0 or 0.6
            local targetTitleTransparency = selected and 0 or 0.6
            local targetFont = selected and Enum.Font.GothamBlack or Enum.Font.GothamSemibold
            local targetBgTransparency = selected and 0 or 1 -- Show background only when selected

            TabFrame.Title.Font = targetFont -- Immediate font change
            TweenService:Create(TabFrame.Ico, TWEEN_INFO_NORMAL, { ImageTransparency = targetIconTransparency }):Play()
			TweenService:Create(TabFrame.Title, TWEEN_INFO_NORMAL, { TextTransparency = targetTitleTransparency }):Play()
            TweenService:Create(TabContainer, TWEEN_INFO_NORMAL, { BackgroundTransparency = targetBgTransparency }):Play()

            Container.Visible = selected -- Show/hide content immediately
        end

		if FirstTab then
			FirstTab = false
            SetSelected(true)
            CurrentTab = {Frame = TabFrame, Container = TabContainer, SetSelected = SetSelected} -- Store initially selected tab
		end

        -- Tab Hover/Click Logic
        local baseTabColor = tabTheme.Second
        local hoverTabColor = GetHoverColor(baseTabColor)
        local clickTabColor = GetClickColor(baseTabColor)

        AddConnection(TabFrame.MouseEnter, function()
            if not isSelected then
                TweenService:Create(TabContainer, TWEEN_INFO_FAST, { BackgroundTransparency = 0.8 }):Play() -- Subtle background fade in
                TweenService:Create(TabFrame.Ico, TWEEN_INFO_FAST, { ImageTransparency = 0.4 }):Play()
                TweenService:Create(TabFrame.Title, TWEEN_INFO_FAST, { TextTransparency = 0.4 }):Play()
            end
        end)

        AddConnection(TabFrame.MouseLeave, function()
             if not isSelected then
                TweenService:Create(TabContainer, TWEEN_INFO_FAST, { BackgroundTransparency = 1 }):Play() -- Fade out background
                TweenService:Create(TabFrame.Ico, TWEEN_INFO_FAST, { ImageTransparency = 0.6 }):Play()
                TweenService:Create(TabFrame.Title, TWEEN_INFO_FAST, { TextTransparency = 0.6 }):Play()
            end
        end)

        AddConnection(TabFrame.MouseButton1Down, function()
            if not isSelected then
                TweenService:Create(TabContainer, TWEEN_INFO_FAST, { BackgroundColor3 = clickTabColor, BackgroundTransparency = 0.7 }):Play()
            end
        end)

		AddConnection(TabFrame.MouseButton1Click, function() -- Use Click
            if isSelected then return end -- Do nothing if already selected

            -- Deselect previous tab
            if CurrentTab and CurrentTab.SetSelected then
                CurrentTab.SetSelected(false)
            end

            -- Select this tab
            SetSelected(true)
            CurrentTab = {Frame = TabFrame, Container = TabContainer, SetSelected = SetSelected} -- Update current tab tracker
		end)

		local function GetElements(ItemParent)
            local elementTheme = OrionLib.Themes[OrionLib.SelectedTheme] -- Theme for elements inside container

			local ElementFunction = {}
            -- Helper for standard element hover/click
            local function setupElementEffects(elementFrame, clickObject)
                local baseColor = elementTheme.Second
		        local hoverColor = GetHoverColor(baseColor)
		        local clickColor = GetClickColor(baseColor)

                AddConnection(clickObject.MouseEnter, function() TweenService:Create(elementFrame, TWEEN_INFO_FAST, { BackgroundColor3 = hoverColor }):Play() end)
                AddConnection(clickObject.MouseLeave, function() TweenService:Create(elementFrame, TWEEN_INFO_FAST, { BackgroundColor3 = baseColor }):Play() end)
                AddConnection(clickObject.MouseButton1Down, function() TweenService:Create(elementFrame, TWEEN_INFO_FAST, { BackgroundColor3 = clickColor }):Play() end)
                AddConnection(clickObject.MouseButton1Up, function()
                    local mousePos = UserInputService:GetMouseLocation()
                    local absPos, absSize = elementFrame.AbsolutePosition, elementFrame.AbsoluteSize
                    if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X and mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then
                        TweenService:Create(elementFrame, TWEEN_INFO_FAST, { BackgroundColor3 = hoverColor }):Play()
                    else
                        TweenService:Create(elementFrame, TWEEN_INFO_FAST, { BackgroundColor3 = baseColor }):Play()
                    end
                end)
            end

			function ElementFunction:AddLabel(Text)
				local LabelFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", elementTheme.Second, 0, 5), {
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 0.7, -- Keep label distinct
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", Text, 14), { -- Slightly smaller label text
						Size = UDim2.new(1, -24, 1, 0), -- Adjust for padding
						Position = UDim2.new(0, 12, 0, 0),
						Font = Enum.Font.GothamBold,
						Name = "Content",
                        TextYAlignment = Enum.TextYAlignment.Center
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Second")

				local LabelFunction = {}
				function LabelFunction:Set(ToChange)
					LabelFrame.Content.Text = ToChange
				end
				return LabelFunction
			end

			function ElementFunction:AddParagraph(Text, Content)
				Text = Text or "Paragraph Title" -- More descriptive default
				Content = Content or "Paragraph content goes here."

				local ParagraphFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", elementTheme.Second, 0, 5), {
					Size = UDim2.new(1, 0, 0, 0), -- Start with zero height
                    AutomaticSize = Enum.AutomaticSize.Y, -- Let it auto-size
					BackgroundTransparency = 0.7,
					Parent = ItemParent
				}), {
                    MakeElement("Padding", 8, 12, 12, 10), -- Add internal padding
					AddThemeObject(SetProps(MakeElement("Label", "<b>" .. Text .. "</b>", 14), { -- Bold title
						Size = UDim2.new(1, 0, 0, 18), -- Fixed height for title
						--Position = UDim2.new(0, 12, 0, 10),
						Font = Enum.Font.GothamBold,
						Name = "Title",
                        LayoutOrder = 1
					}), "Text"),
					AddThemeObject(SetProps(MakeElement("Label", Content, 13), { -- Slightly smaller content text
						Size = UDim2.new(1, 0, 0, 0), -- Auto height
						--Position = UDim2.new(0, 12, 0, 26),
                        AutomaticSize = Enum.AutomaticSize.Y,
						Font = Enum.Font.Gotham, -- Regular font for content
						Name = "Content",
						TextWrapped = true,
                        LayoutOrder = 2
					}), "TextDark"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
                    MakeElement("List", 0, 4) -- Add list layout for spacing title/content
				}), "Second")

                -- No need for connection, AutomaticSize handles it

				local ParagraphFunction = {}
				function ParagraphFunction:Set(ToChange)
					ParagraphFrame.Content.Text = ToChange
				end
				return ParagraphFunction
			end

			function ElementFunction:AddButton(ButtonConfig)
				ButtonConfig = ButtonConfig or {}
				ButtonConfig.Name = ButtonConfig.Name or "Button"
				ButtonConfig.Callback = ButtonConfig.Callback or function() print("Button Clicked:", ButtonConfig.Name) end
				ButtonConfig.Icon = ButtonConfig.Icon -- Keep nil default, don't force an icon

				local Button = {}

				local Click = SetProps(MakeElement("Button"), {
					Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1 -- Make button transparent
				})

                local hasIcon = ButtonConfig.Icon ~= nil and ButtonConfig.Icon ~= ""

				local ButtonFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", elementTheme.Second, 0, 5), {
					Size = UDim2.new(1, 0, 0, 35), -- Slightly taller buttons
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", ButtonConfig.Name, 14), {
						Size = UDim2.new(1, hasIcon and -42 or -24, 1, 0), -- Adjust size based on icon presence
						Position = UDim2.new(0, 12, 0, 0),
						Font = Enum.Font.GothamBold,
						Name = "Content",
                        TextYAlignment = Enum.TextYAlignment.Center
					}), "Text"),
                    (hasIcon and AddThemeObject(SetProps(MakeElement("Image", ButtonConfig.Icon), {
						Size = UDim2.new(0, 18, 0, 18), -- Smaller icon
						Position = UDim2.new(1, -30, 0.5, 0), -- Position right, centered Y
                        AnchorPoint = Vector2.new(1, 0.5),
                        Name = "Ico"
					}), "TextDark") or nil), -- Conditionally add icon
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					Click
				}), "Second")

                setupElementEffects(ButtonFrame, Click) -- Apply standard effects

				AddConnection(Click.MouseButton1Click, function() -- Use Click instead of Up
                    -- Optional: Add a quick visual press effect
                    local originalSize = ButtonFrame.Size
                    TweenService:Create(ButtonFrame, TweenInfo.new(0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = originalSize * 0.98 }):Play()
                    task.wait(0.1)
                    TweenService:Create(ButtonFrame, TWEEN_INFO_FAST, { Size = originalSize }):Play()

					task.spawn(ButtonConfig.Callback) -- Use task.spawn for safety
                    SaveCfg(game.GameId) -- Save config on button press if applicable
				end)

				function Button:Set(ButtonText)
					ButtonFrame.Content.Text = ButtonText
				end

				return Button
			end

			function ElementFunction:AddToggle(ToggleConfig)
				ToggleConfig = ToggleConfig or {}
				ToggleConfig.Name = ToggleConfig.Name or "Toggle"
				ToggleConfig.Default = ToggleConfig.Default or false
				ToggleConfig.Callback = ToggleConfig.Callback or function(val) print("Toggle:", ToggleConfig.Name, val) end
				ToggleConfig.Color = ToggleConfig.Color or Color3.fromRGB(40, 167, 69) -- Green default
				ToggleConfig.Flag = ToggleConfig.Flag or nil
				ToggleConfig.Save = ToggleConfig.Save or true -- Save by default

				local Toggle = {Value = ToggleConfig.Default, Save = ToggleConfig.Save, Type = "Toggle"} -- Add Type

				local Click = SetProps(MakeElement("Button"), {
					Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1
				})

                local toggleOnColor = ToggleConfig.Color
                local toggleOffColor = elementTheme.Divider

				local ToggleBox = SetChildren(SetProps(MakeElement("RoundFrame", toggleOffColor, 0.5, 0), { -- Make it a circle
					Size = UDim2.new(0, 20, 0, 20), -- Smaller toggle box
					Position = UDim2.new(1, -30, 0.5, 0), -- Positioned right, centered Y
					AnchorPoint = Vector2.new(0.5, 0.5),
                    Name = "ToggleIndicator",
                    BorderSizePixel = 0
				}), {
					SetProps(MakeElement("Stroke"), {
						Color = toggleOffColor,
						Name = "Stroke",
						Transparency = 0 -- Start opaque
					}),
					SetProps(MakeElement("Image", "rbxassetid://3944680095"), { -- Checkmark icon
						Size = UDim2.new(0.7, 0, 0.7, 0), -- Relative size
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0.5, 0, 0.5, 0),
						ImageColor3 = Color3.fromRGB(255, 255, 255),
						Name = "Ico",
                        ImageTransparency = 1 -- Start hidden
					}),
                    MakeElement("UIAspectRatioConstraint", { AspectRatio = 1 }) -- Ensure it stays circle/square
				})

				local ToggleFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", elementTheme.Second, 0, 5), {
					Size = UDim2.new(1, 0, 0, 38), -- Taller toggle row
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", ToggleConfig.Name, 14), {
						Size = UDim2.new(1, -50, 1, 0), -- Adjust size for toggle box
						Position = UDim2.new(0, 12, 0, 0),
						Font = Enum.Font.GothamBold,
						Name = "Content",
                        TextYAlignment = Enum.TextYAlignment.Center
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					ToggleBox,
					Click
				}), "Second")

                setupElementEffects(ToggleFrame, Click) -- Standard hover/click

				function Toggle:Set(Value, skipCallback)
					Toggle.Value = Value
                    local targetBgColor = Toggle.Value and toggleOnColor or toggleOffColor
                    local targetStrokeColor = Toggle.Value and toggleOnColor or elementTheme.Stroke
                    local targetIconTransparency = Toggle.Value and 0 or 1
                    local targetIconSize = Toggle.Value and UDim2.fromScale(0.7, 0.7) or UDim2.fromScale(0.4, 0.4) -- Shrink icon when off

					TweenService:Create(ToggleBox, TWEEN_INFO_NORMAL, { BackgroundColor3 = targetBgColor }):Play()
					TweenService:Create(ToggleBox.Stroke, TWEEN_INFO_NORMAL, { Color = targetStrokeColor }):Play()
					TweenService:Create(ToggleBox.Ico, TWEEN_INFO_NORMAL, { ImageTransparency = targetIconTransparency, Size = targetIconSize }):Play()

					if not skipCallback then
                        task.spawn(ToggleConfig.Callback, Toggle.Value)
                    end
				end

				Toggle:Set(Toggle.Value, true) -- Set initial state without callback

				AddConnection(Click.MouseButton1Click, function()
					Toggle:Set(not Toggle.Value)
                    if Toggle.Save then SaveCfg(game.GameId) end -- Save only if flag is set
				end)

				if ToggleConfig.Flag then
					OrionLib.Flags[ToggleConfig.Flag] = Toggle
				end
				return Toggle
			end

			function ElementFunction:AddSlider(SliderConfig)
				SliderConfig = SliderConfig or {}
				SliderConfig.Name = SliderConfig.Name or "Slider"
				SliderConfig.Min = SliderConfig.Min or 0
				SliderConfig.Max = SliderConfig.Max or 100
				SliderConfig.Increment = SliderConfig.Increment or 1
				SliderConfig.Default = SliderConfig.Default or SliderConfig.Min -- Default to Min
				SliderConfig.Callback = SliderConfig.Callback or function(val) print("Slider:", SliderConfig.Name, val) end
				SliderConfig.ValueName = SliderConfig.ValueName or ""
				SliderConfig.Color = SliderConfig.Color or Color3.fromRGB(0, 123, 255) -- Blue default
				SliderConfig.Flag = SliderConfig.Flag or nil
				SliderConfig.Save = SliderConfig.Save or true -- Save by default

				local Slider = {Value = SliderConfig.Default, Save = SliderConfig.Save, Type = "Slider"} -- Add Type
				local Dragging = false
                local sliderColor = SliderConfig.Color
                local sliderBgColor = elementTheme.Divider

                local ValueLabel = AddThemeObject(SetProps(MakeElement("Label", "", 12), { -- Value indicator label
                    Size = UDim2.new(0, 50, 0, 14), -- Size for text
                    Position = UDim2.new(1, -12, 0, 10), -- Position top right
                    AnchorPoint = Vector2.new(1, 0),
                    Font = Enum.Font.GothamBold,
                    Name = "ValueLabel",
                    TextXAlignment = Enum.TextXAlignment.Right,
                    BackgroundTransparency = 1
                }), "TextDark")

				local SliderDrag = SetChildren(SetProps(MakeElement("RoundFrame", sliderColor, 0, 4), { -- Filled part
					Size = UDim2.new(0, 0, 1, 0), -- Start at 0 width scale
					BackgroundTransparency = 0, -- Opaque fill
					ClipsDescendants = true,
                    BorderSizePixel = 0
				}), {
                    -- Optional: Add subtle gradient or highlight to fill bar
				})

                -- Clickable background bar
				local SliderBar = SetChildren(SetProps(MakeElement("RoundFrame", sliderBgColor, 0, 4), {
					Size = UDim2.new(1, -24, 0, 10), -- Thinner bar
					Position = UDim2.new(0, 12, 1, -18), -- Positioned at bottom
                    AnchorPoint = Vector2.new(0, 1),
					BackgroundTransparency = 0, -- Opaque background
                    ClipsDescendants = true,
                    BorderSizePixel = 0
				}), {
					--[[ Stroke removed for cleaner look
					SetProps(MakeElement("Stroke"), {
						Color = sliderColor, Transparency = 0.5
					}),
                    ]]
					SliderDrag -- Fill bar is child of background bar
				})

				local SliderFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", elementTheme.Second, 0, 5), {
					Size = UDim2.new(1, 0, 0, 55), -- Shorter height for slider
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", SliderConfig.Name, 14), {
						Size = UDim2.new(1, -70, 0, 14), -- Adjust size for value label
						Position = UDim2.new(0, 12, 0, 10), -- Position top left
						Font = Enum.Font.GothamBold,
						Name = "Content"
					}), "Text"),
                    ValueLabel,
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					SliderBar
				}), "Second")

                local function UpdateSlider(value, skipCallback)
                    local clampedValue = math.clamp(Round(value, SliderConfig.Increment), SliderConfig.Min, SliderConfig.Max)
                    Slider.Value = clampedValue
                    local percentage = (clampedValue - SliderConfig.Min) / (SliderConfig.Max - SliderConfig.Min)
                    if SliderConfig.Max == SliderConfig.Min then percentage = 1 end -- Handle divide by zero

					TweenService:Create(SliderDrag, TWEEN_INFO_FAST, { Size = UDim2.fromScale(percentage, 1) }):Play()
					ValueLabel.Text = tostring(clampedValue) .. (SliderConfig.ValueName ~= "" and (" " .. SliderConfig.ValueName) or "")

                    if not skipCallback then
					    task.spawn(SliderConfig.Callback, Slider.Value)
                    end
				end

                local inputConn = nil
				AddConnection(SliderBar.InputBegan, function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
						Dragging = true
                        local pos = Input.Position
                        local relativeX = math.clamp(pos.X - SliderBar.AbsolutePosition.X, 0, SliderBar.AbsoluteSize.X)
                        local percentage = relativeX / SliderBar.AbsoluteSize.X
                        local newValue = SliderConfig.Min + (SliderConfig.Max - SliderConfig.Min) * percentage
                        UpdateSlider(newValue) -- Update immediately on click

                        if inputConn then inputConn:Disconnect() end
                        inputConn = AddConnection(UserInputService.InputChanged, function(changeInput)
                            if Dragging and (changeInput.UserInputType == Enum.UserInputType.MouseMovement or changeInput.UserInputType == Enum.UserInputType.Touch) then
                                local currentPos = changeInput.Position
                                local currentRelativeX = math.clamp(currentPos.X - SliderBar.AbsolutePosition.X, 0, SliderBar.AbsoluteSize.X)
                                local currentPercentage = currentRelativeX / SliderBar.AbsoluteSize.X
                                local currentNewValue = SliderConfig.Min + (SliderConfig.Max - SliderConfig.Min) * currentPercentage
						        UpdateSlider(currentNewValue)
                            end
                        end)
					end
				end)

				AddConnection(SliderBar.InputEnded, function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        if Dragging then
						    Dragging = false
                            if inputConn then inputConn:Disconnect(); inputConn = nil end
                            if Slider.Save then SaveCfg(game.GameId) end -- Save on release
                        end
					end
				end)

                -- Also handle mouse leaving the slider bar area while dragging
                AddConnection(SliderBar.MouseLeave, function()
                    -- Check if dragging was active, could potentially stop drag here or let it continue based on InputEnded
                end)


				function Slider:Set(Value, skipCallback)
					UpdateSlider(Value, skipCallback)
				end

				Slider:Set(Slider.Value, true) -- Set initial value without callback

				if SliderConfig.Flag then
					OrionLib.Flags[SliderConfig.Flag] = Slider
				end
				return Slider
			end

			function ElementFunction:AddDropdown(DropdownConfig)
				DropdownConfig = DropdownConfig or {}
				DropdownConfig.Name = DropdownConfig.Name or "Dropdown"
				DropdownConfig.Options = DropdownConfig.Options or {}
				DropdownConfig.Default = DropdownConfig.Default or ""
				DropdownConfig.Callback = DropdownConfig.Callback or function(val) print("Dropdown:", DropdownConfig.Name, val) end
				DropdownConfig.Flag = DropdownConfig.Flag or nil
				DropdownConfig.Save = DropdownConfig.Save or true -- Save by default
                DropdownConfig.MaxHeight = DropdownConfig.MaxHeight or 150 -- Max dropdown height in pixels

				local Dropdown = {Value = DropdownConfig.Default, Options = DropdownConfig.Options, Buttons = {}, Toggled = false, Type = "Dropdown", Save = DropdownConfig.Save}
				local MaxElements = DropdownConfig.MaxHeight / 30 -- Estimate max elements visible based on height and option height

				if #Dropdown.Options > 0 and not table.find(Dropdown.Options, Dropdown.Value) then
					Dropdown.Value = DropdownConfig.Options[1] -- Default to first option if current default invalid
                elseif #Dropdown.Options == 0 then
                    Dropdown.Value = "No Options" -- Handle empty options
				end

				local DropdownList = MakeElement("List", 0, 2) -- Spacing between options

                -- Scroll container for options
				local DropdownContainer = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", elementTheme.Divider, 4), {
					DropdownList
				}), {
					Parent = nil, -- Set parent later
					Position = UDim2.new(0, 0, 1, 1), -- Position below the main frame + divider offset
					Size = UDim2.new(1, 0, 0, 0), -- Start hidden (zero height)
					ClipsDescendants = true,
                    BackgroundTransparency = 0, -- Has background
                    BorderSizePixel = 0,
                    Visible = false, -- Start invisible
                    ZIndex = 3 -- Ensure dropdown appears above other elements
				}), "Second") -- Use Second theme color for dropdown background

                -- Main frame for dropdown (visible part)
				local DropdownFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", elementTheme.Second, 0, 5), {
					Size = UDim2.new(1, 0, 0, 38), -- Fixed height for main part
					Parent = ItemParent,
					ClipsDescendants = true, -- Clip only the main part initially
                    ZIndex = 2 -- Above normal elements
				}), {
					-- Top clickable part
					SetProps(SetChildren(MakeElement("TFrame"), {
						AddThemeObject(SetProps(MakeElement("Label", DropdownConfig.Name, 14), {
							Size = UDim2.new(1, -100, 1, 0), -- Size adjusted for selected text and icon
							Position = UDim2.new(0, 12, 0, 0),
							Font = Enum.Font.GothamBold,
							Name = "Content",
                            TextYAlignment = Enum.TextYAlignment.Center
						}), "Text"),
						AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072706796"), { -- Down arrow icon
							Size = UDim2.new(0, 16, 0, 16), -- Smaller icon
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -12, 0.5, 0), -- Position right, centered Y
                            ImageColor3 = elementTheme.TextDark,
							Name = "Ico",
                            Rotation = 0 -- Start pointing down
						}), "TextDark"),
						AddThemeObject(SetProps(MakeElement("Label", Dropdown.Value, 13), {
							Size = UDim2.new(1, -50, 1, 0), -- Size adjusted for icon
                            AnchorPoint = Vector2.new(1, 0.5),
                            Position = UDim2.new(1, -35, 0.5, 0), -- Position left of icon
							Font = Enum.Font.Gotham,
							Name = "Selected",
							TextXAlignment = Enum.TextXAlignment.Right,
                            TextYAlignment = Enum.TextYAlignment.Center
						}), "TextDark"),
						AddThemeObject(SetProps(MakeElement("Frame"), { -- Divider line (for open state)
							Size = UDim2.new(1, 0, 0, 1),
							Position = UDim2.new(0, 0, 1, 0), -- At the bottom
							Name = "Line",
							Visible = false -- Hidden initially
						}), "Stroke"),
                        SetProps(MakeElement("Button"), { -- The actual click detector
                            Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Name = "Click"
                        })
					}), {
						Size = UDim2.new(1, 0, 1, 0), -- Cover the whole frame
						ClipsDescendants = true,
						Name = "F"
					}),
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Second")

                local Click = DropdownFrame.F.Click
                DropdownContainer.Parent = DropdownFrame -- Set parent now

				AddConnection(DropdownList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
                    local totalHeight = DropdownList.AbsoluteContentSize.Y
					DropdownContainer.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
				end)

                local optionBaseColor = elementTheme.Second
                local optionHoverColor = GetHoverColor(optionBaseColor)
                local optionClickColor = GetClickColor(optionBaseColor)
                local optionSelectedColor = GetClickColor(optionClickColor) -- Slightly darker for selected

				local function AddOptions(Options)
                    -- Clear existing buttons first
                    for _, btn in pairs(Dropdown.Buttons) do btn:Destroy() end
                    Dropdown.Buttons = {}

					for _, Option in ipairs(Options) do
						local OptionBtn = AddThemeObject(SetProps(SetChildren(MakeElement("Button"), {
							AddThemeObject(SetProps(MakeElement("Label", Option, 13), {
								Position = UDim2.new(0, 8, 0, 0),
								Size = UDim2.new(1, -16, 1, 0),
								Name = "Title",
                                TextXAlignment = Enum.TextXAlignment.Left,
                                TextYAlignment = Enum.TextYAlignment.Center,
                                TextTransparency = 0 -- Default text color
							}), "Text")
						}), {
							Parent = DropdownContainer,
							Size = UDim2.new(1, 0, 0, 30), -- Fixed height for options
							BackgroundTransparency = 1, -- Options transparent by default
							ClipsDescendants = true,
                            AutoButtonColor = false,
                            LayoutOrder = #Dropdown.Buttons + 1 -- Ensure order
						}), "Divider") -- Not really divider, just themed object

                        local isOptionSelected = (Option == Dropdown.Value)
                        OptionBtn.BackgroundTransparency = isOptionSelected and 0 or 1
                        OptionBtn.BackgroundColor3 = isOptionSelected and optionSelectedColor or optionBaseColor
                        OptionBtn.Title.TextColor3 = isOptionSelected and elementTheme.Text or elementTheme.TextDark
                        OptionBtn.Title.Font = isOptionSelected and Enum.Font.GothamBold or Enum.Font.Gotham

                        AddConnection(OptionBtn.MouseEnter, function() if not (Option == Dropdown.Value) then TweenService:Create(OptionBtn, TWEEN_INFO_FAST, { BackgroundColor3 = optionHoverColor, BackgroundTransparency = 0 }):Play() end end)
                        AddConnection(OptionBtn.MouseLeave, function() if not (Option == Dropdown.Value) then TweenService:Create(OptionBtn, TWEEN_INFO_FAST, { BackgroundTransparency = 1 }):Play() end end)
                        AddConnection(OptionBtn.MouseButton1Down, function() if not (Option == Dropdown.Value) then TweenService:Create(OptionBtn, TWEEN_INFO_FAST, { BackgroundColor3 = optionClickColor, BackgroundTransparency = 0 }):Play() end end)
						AddConnection(OptionBtn.MouseButton1Click, function()
                            if Option ~= Dropdown.Value then
							    Dropdown:Set(Option)
							    if Dropdown.Save then SaveCfg(game.GameId) end
                            end
                            -- Close dropdown after selection
                            if Dropdown.Toggled then
                                Click:Activated() -- Simulate a click on the main button to toggle off
                            end
						end)

						Dropdown.Buttons[Option] = OptionBtn
					end
                    -- Recalculate canvas size after adding options
                    task.wait() -- Wait a frame for layout to update
                    local totalHeight = DropdownList.AbsoluteContentSize.Y
					DropdownContainer.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
				end

				function Dropdown:Refresh(Options, Delete) -- Delete parameter seems redundant now
                    Dropdown.Options = Options or {}
					AddOptions(Dropdown.Options)
                    -- Reselect current value to update visuals if options changed
                    Dropdown:Set(Dropdown.Value, true)
				end

				function Dropdown:Set(Value, skipCallback)
                    local found = false
                    for _, opt in ipairs(Dropdown.Options) do
                        if opt == Value then
                            found = true
                            break
                        end
                    end

					if not found then
                        if #Dropdown.Options > 0 then
                            Dropdown.Value = Dropdown.Options[1] -- Default to first if value not found
                        else
                            Dropdown.Value = "No Options"
                        end
                    else
                        Dropdown.Value = Value
					end

					DropdownFrame.F.Selected.Text = Dropdown.Value

                    -- Update visuals for all buttons
                    for opt, btn in pairs(Dropdown.Buttons) do
                        local isOptionSelected = (opt == Dropdown.Value)
                        local targetBgTransparency = isOptionSelected and 0 or 1
                        local targetBgColor = isOptionSelected and optionSelectedColor or optionBaseColor
                        local targetTextColor = isOptionSelected and elementTheme.Text or elementTheme.TextDark
                        local targetFont = isOptionSelected and Enum.Font.GothamBold or Enum.Font.Gotham

                        TweenService:Create(btn, TWEEN_INFO_FAST, { BackgroundTransparency = targetBgTransparency, BackgroundColor3 = targetBgColor }):Play()
                        TweenService:Create(btn.Title, TWEEN_INFO_FAST, { TextColor3 = targetTextColor }):Play()
                        btn.Title.Font = targetFont
                    end

					if not skipCallback then
                        return task.spawn(DropdownConfig.Callback, Dropdown.Value)
                    end
				end

                setupElementEffects(DropdownFrame, Click) -- Apply hover/click to the main frame part

				AddConnection(Click.MouseButton1Click, function()
					Dropdown.Toggled = not Dropdown.Toggled
					DropdownFrame.F.Line.Visible = Dropdown.Toggled
					DropdownContainer.Visible = Dropdown.Toggled
                    DropdownFrame.ClipsDescendants = not Dropdown.Toggled -- Stop clipping main frame when open

					TweenService:Create(DropdownFrame.F.Ico, TWEEN_INFO_FAST, { Rotation = Dropdown.Toggled and -180 or 0 }):Play() -- Point up when open

                    local targetHeight = 0
                    if Dropdown.Toggled then
                        targetHeight = math.min(DropdownContainer.CanvasSize.Y.Offset, DropdownConfig.MaxHeight)
                    end

					TweenService:Create(DropdownContainer, TWEEN_INFO_NORMAL, { Size = UDim2.new(1, 0, 0, targetHeight) }):Play()
				end)

				Dropdown:Refresh(Dropdown.Options) -- Initial population
				Dropdown:Set(Dropdown.Value, true) -- Set initial state without callback

				if DropdownConfig.Flag then
					OrionLib.Flags[DropdownConfig.Flag] = Dropdown
				end
				return Dropdown
			end

			function ElementFunction:AddBind(BindConfig)
                BindConfig = BindConfig or {}
				BindConfig.Name = BindConfig.Name or "Bind"
				BindConfig.Default = BindConfig.Default or Enum.KeyCode.None -- Use None instead of Unknown
				BindConfig.Hold = BindConfig.Hold or false
				BindConfig.Callback = BindConfig.Callback or function(val) print("Bind:", BindConfig.Name, val) end
				BindConfig.Flag = BindConfig.Flag or nil
				BindConfig.Save = BindConfig.Save or true -- Save by default

				local Bind = {Value = BindConfig.Default, Binding = false, Type = "Bind", Save = BindConfig.Save}
				local Holding = false

				local Click = SetProps(MakeElement("Button"), {
					Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1
				})

                local BindValueLabel = AddThemeObject(SetProps(MakeElement("Label", "...", 13), { -- Start with ...
                    Size = UDim2.new(1, -16, 1, -8), -- Padding inside the box
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextYAlignment = Enum.TextYAlignment.Center,
                    Name = "Value",
                    BackgroundTransparency = 1
                }), "Text")

				local BindBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", elementTheme.Main, 0, 4), {
					Size = UDim2.new(0, 60, 0, 24), -- Fixed initial size, will resize
					Position = UDim2.new(1, -12, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
                    ClipsDescendants = true
				}), {
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
                    BindValueLabel
				}), "Main")

				local BindFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", elementTheme.Second, 0, 5), {
					Size = UDim2.new(1, 0, 0, 38),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", BindConfig.Name, 14), {
						Size = UDim2.new(1, -80, 1, 0), -- Adjusted for bind box size
						Position = UDim2.new(0, 12, 0, 0),
						Font = Enum.Font.GothamBold,
						Name = "Content",
                        TextYAlignment = Enum.TextYAlignment.Center
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					BindBox,
					Click
				}), "Second")

                local currentInput = nil -- Track the current input connection

				AddConnection(BindValueLabel:GetPropertyChangedSignal("Text"), function()
                    local text = BindValueLabel.Text
                    local width = BindValueLabel.TextBounds.X + 20 -- Add padding
                    width = math.max(40, width) -- Minimum width
					TweenService:Create(BindBox, TWEEN_INFO_FAST, { Size = UDim2.new(0, width, 0, 24) }):Play()
				end)

                local function StopBinding(newKey)
                    if not Bind.Binding then return end -- Only stop if currently binding

                    Bind.Binding = false
                    BindValueLabel.TextColor3 = elementTheme.Text -- Restore color
                    if inputConn then inputConn:Disconnect(); inputConn = nil end -- Disconnect listener

                    local keyToSet = newKey or Bind.Value -- Use newKey if provided, else keep old value
                    if keyToSet ~= Enum.KeyCode.Escape then -- Don't set if Escape was pressed to cancel
                        Bind:Set(keyToSet)
                        if Bind.Save then SaveCfg(game.GameId) end -- Save if not cancelled
                    else
                        Bind:Set(Bind.Value) -- Revert to original value display if cancelled
                    end
                end

				AddConnection(Click.MouseButton1Click, function() -- Use Click
					if Bind.Binding then return end -- Don't restart binding if already active

					Bind.Binding = true
					BindValueLabel.Text = "..."
                    BindValueLabel.TextColor3 = Color3.fromRGB(255, 255, 0) -- Yellow while binding

                    -- Disconnect previous input connection if it exists
                    if inputConn then inputConn:Disconnect(); inputConn = nil end

                    -- Start listening for the next key/mouse press
                    inputConn = AddConnection(UserInputService.InputBegan, function(Input, gameProcessed)
                        if gameProcessed then return end -- Ignore if game engine handled it (e.g., textbox focus)
                        if not Bind.Binding then return end -- Ensure still binding

                        local key = nil
                        if Input.UserInputType.Name:find("Mouse") and table.find(WhitelistedMouse, Input.UserInputType) then
                            key = Input.UserInputType
                        elseif Input.KeyCode ~= Enum.KeyCode.Unknown and not table.find(BlacklistedKeys, Input.KeyCode) then
                            key = Input.KeyCode
                        end

                        if key then
                            StopBinding(key) -- Stop binding and set the new key
                        elseif Input.KeyCode == Enum.KeyCode.Escape then
                            StopBinding(Enum.KeyCode.Escape) -- Stop binding and cancel (revert value)
                        end
                    end)
				end)

                -- Handle clicking outside while binding to cancel
                AddConnection(UserInputService.InputBegan, function(Input)
                    if Bind.Binding and Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        -- Check if the click was outside the BindBox
                        local mousePos = Input.Position
                        local boxPos, boxSize = BindBox.AbsolutePosition, BindBox.AbsoluteSize
                        if not (mousePos.X >= boxPos.X and mousePos.X <= boxPos.X + boxSize.X and
                                mousePos.Y >= boxPos.Y and mousePos.Y <= boxPos.Y + boxSize.Y) then
                            StopBinding(Enum.KeyCode.Escape) -- Cancel binding if clicked outside
                        end
                    end
                end)


                -- Handle actual keybind activation
                AddConnection(UserInputService.InputBegan, function(Input, gameProcessed)
                    if gameProcessed then return end
                    if UserInputService:GetFocusedTextBox() then return end
					if Bind.Binding then return end -- Don't trigger callback while binding

                    local bindValue = Bind.Value
                    local inputMatch = (Input.KeyCode == bindValue or Input.UserInputType == bindValue)

					if inputMatch then
						if BindConfig.Hold then
							Holding = true
							task.spawn(BindConfig.Callback, Holding)
						else
							task.spawn(BindConfig.Callback)
						end
					end
				end)

				AddConnection(UserInputService.InputEnded, function(Input)
                    local bindValue = Bind.Value
                    local inputMatch = (Input.KeyCode == bindValue or Input.UserInputType == bindValue)

					if inputMatch and BindConfig.Hold and Holding then
						Holding = false
						task.spawn(BindConfig.Callback, Holding)
					end
				end)

                setupElementEffects(BindFrame, Click) -- Standard hover/click

				function Bind:Set(Key)
					Bind.Value = Key or Bind.Value -- Keep old value if Key is nil
                    local name = ""
                    if type(Bind.Value) == "EnumItem" then
                        name = Bind.Value.Name
                        if name == "None" then name = "None"
                        elseif name:find("MouseButton") then name = name:sub(12) -- Shorten MouseButton1 to M1 etc.
                        end
                    else
                        name = tostring(Bind.Value) -- Fallback for safety
                    end
					BindValueLabel.Text = name
                    Bind.Binding = false -- Ensure binding state is false after Set is called externally
                    if inputConn then inputConn:Disconnect(); inputConn = nil end -- Disconnect listener if Set is called
				end

				Bind:Set(BindConfig.Default) -- Set initial value

				if BindConfig.Flag then
					OrionLib.Flags[BindConfig.Flag] = Bind
				end
				return Bind
			end

			function ElementFunction:AddTextbox(TextboxConfig)
				TextboxConfig = TextboxConfig or {}
				TextboxConfig.Name = TextboxConfig.Name or "Textbox"
				TextboxConfig.Default = TextboxConfig.Default or ""
                TextboxConfig.Placeholder = TextboxConfig.Placeholder or "Input..." -- Add placeholder option
				TextboxConfig.TextDisappear = TextboxConfig.TextDisappear or false -- Clear on focus lost
                TextboxConfig.NumbersOnly = TextboxConfig.NumbersOnly or false -- Numbers only option
				TextboxConfig.Callback = TextboxConfig.Callback or function(val) print("Textbox:", TextboxConfig.Name, val) end
                TextboxConfig.Flag = TextboxConfig.Flag or nil
				TextboxConfig.Save = TextboxConfig.Save or true -- Save by default

                local Textbox = { Value = TextboxConfig.Default, Type = "Textbox", Save = TextboxConfig.Save }

				local Click = SetProps(MakeElement("Button"), { -- Click area to focus textbox
					Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1
				})

				local TextboxActual = AddThemeObject(Create("TextBox", {
					Size = UDim2.new(1, -10, 1, -6), -- Padding inside container
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					TextColor3 = elementTheme.Text,
                    TextSize = 14,
					PlaceholderColor3 = elementTheme.TextDark,
					PlaceholderText = TextboxConfig.Placeholder,
					Font = Enum.Font.GothamSemibold,
					TextXAlignment = Enum.TextXAlignment.Left, -- Left align text
                    TextYAlignment = Enum.TextYAlignment.Center,
					ClearTextOnFocus = false, -- We handle clearing manually if needed
                    MultiLine = false,
                    Text = TextboxConfig.Default,
                    Name = "InputBox"
				}), "Text")

                -- Filter input if NumbersOnly
                if TextboxConfig.NumbersOnly then
                    AddConnection(TextboxActual:GetPropertyChangedSignal("Text"), function()
                        TextboxActual.Text = TextboxActual.Text:match("[\-%.%d]*") or "" -- Allow numbers, decimal, negative
                    end)
                end

				local TextContainer = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", elementTheme.Main, 0, 4), {
					Size = UDim2.new(1, -50, 0, 24), -- Initial size adjusted for label
					Position = UDim2.new(1, -12, 0.5, 0), -- Position right, centered Y
					AnchorPoint = Vector2.new(1, 0.5),
                    ClipsDescendants = true
				}), {
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					TextboxActual
				}), "Main")


				local TextboxFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", elementTheme.Second, 0, 5), {
					Size = UDim2.new(1, 0, 0, 38),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", TextboxConfig.Name, 14), {
						Size = UDim2.new(1, -12, 1, 0), -- Full height label
						Position = UDim2.new(0, 12, 0, 0),
						Font = Enum.Font.GothamBold,
						Name = "Content",
                        TextYAlignment = Enum.TextYAlignment.Center
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					TextContainer,
					Click
				}), "Second")

                -- Resize container based on text content (optional, can be fixed width too)
                --[[
				AddConnection(TextboxActual:GetPropertyChangedSignal("TextBounds"), function()
                    local width = TextboxActual.TextBounds.X + 20 -- Text width + padding
                    width = math.max(60, width) -- Minimum width
                    width = math.min(TextboxFrame.AbsoluteSize.X - 60, width) -- Max width (frame width - label area - padding)
					TweenService:Create(TextContainer, TWEEN_INFO_FAST, {Size = UDim2.new(0, width, 0, 24)}):Play()
				end)
                ]]
                -- Fixed width approach (simpler): Adjust TextContainer's initial size calculation if needed

				AddConnection(TextboxActual.FocusLost, function(enterPressed)
                    local newValue = TextboxActual.Text
                    if Textbox.Value ~= newValue then -- Check if value changed
                        Textbox.Value = newValue
					    task.spawn(TextboxConfig.Callback, newValue)
                        if Textbox.Save then SaveCfg(game.GameId) end
                    end
					if enterPressed and TextboxConfig.TextDisappear then -- Clear only if enter pressed and configured
						TextboxActual.Text = ""
                        Textbox.Value = ""
					end
				end)

                setupElementEffects(TextboxFrame, Click) -- Apply standard effects

				AddConnection(Click.MouseButton1Click, function() -- Use Click
					TextboxActual:CaptureFocus()
				end)

                function Textbox:Set(value, skipCallback)
                    TextboxActual.Text = tostring(value)
                    local newValue = TextboxActual.Text -- Read back after potential filtering
                    if Textbox.Value ~= newValue then
                        Textbox.Value = newValue
                        if not skipCallback then
                            task.spawn(TextboxConfig.Callback, newValue)
                        end
                    end
                end

                Textbox:Set(TextboxConfig.Default, true) -- Set initial value

                if TextboxConfig.Flag then
                    OrionLib.Flags[TextboxConfig.Flag] = Textbox
                end
                return Textbox
			end

			function ElementFunction:AddColorpicker(ColorpickerConfig)
				ColorpickerConfig = ColorpickerConfig or {}
				ColorpickerConfig.Name = ColorpickerConfig.Name or "Colorpicker"
				ColorpickerConfig.Default = ColorpickerConfig.Default or Color3.fromRGB(255,255,255)
				ColorpickerConfig.Callback = ColorpickerConfig.Callback or function(val) print("Colorpicker:", ColorpickerConfig.Name, val) end
				ColorpickerConfig.Flag = ColorpickerConfig.Flag or nil
				ColorpickerConfig.Save = ColorpickerConfig.Save or true -- Save by default

				local ColorH, ColorS, ColorV = Color3.toHSV(ColorpickerConfig.Default)
				local Colorpicker = {Value = ColorpickerConfig.Default, Toggled = false, Type = "Colorpicker", Save = ColorpickerConfig.Save}
                local pickerDragging = nil -- "Color" or "Hue" or nil

				local ColorSelection = Create("ImageLabel", {
					Size = UDim2.new(0, 18, 0, 18),
					Position = UDim2.fromScale(ColorS, 1 - ColorV), -- S maps to X, V maps to Y (inverted)
					ScaleType = Enum.ScaleType.Fit,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "http://www.roblox.com/asset/?id=4805639000", -- Circle selector image
                    ZIndex = 4 -- Above color/hue gradients
				})

				local HueSelection = Create("ImageLabel", {
					Size = UDim2.new(0, 18, 0, 18),
					Position = UDim2.fromScale(0.5, ColorH), -- H maps to Y
					ScaleType = Enum.ScaleType.Fit,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "http://www.roblox.com/asset/?id=4805639000",
                    ZIndex = 4
				})

                -- Saturation/Value Picker Frame
				local Color = Create("Frame", { -- Use Frame instead of ImageLabel
					Size = UDim2.new(1, -35, 1, 0), -- Size adjusted for hue slider and padding
                    Position = UDim2.new(0,0,0,0),
					Visible = false, -- Start hidden
                    ClipsDescendants = false, -- Allow selector to go slightly outside
                    BackgroundColor3 = Color3.fromHSV(ColorH, 1, 1), -- Background shows Hue
                    ZIndex = 2 -- Behind selectors
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 5)}),
                    -- Saturation Gradient (White to Color)
                    Create("UIGradient", {
                        Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)), ColorSequenceKeypoint.new(1, Color3.fromHSV(ColorH, 1, 1))},
                        Rotation = 0 -- Left to Right
                    }),
                    -- Value Gradient (Transparent to Black)
                    Create("UIGradient", {
                        Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.new(0,0,0)), ColorSequenceKeypoint.new(1, Color3.new(0,0,0))},
                        Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0)}, -- Top (Transparent) to Bottom (Black)
                        Rotation = 90 -- Top to Bottom
                    }),
					ColorSelection -- Selector is child of this frame
				})

                -- Hue Picker Frame
				local Hue = Create("Frame", {
					Size = UDim2.new(0, 20, 1, 0), -- Width of hue slider
					Position = UDim2.new(1, -20, 0, 0), -- Positioned right
					Visible = false, -- Start hidden
                    ClipsDescendants = false,
                    ZIndex = 2
				}, {
					Create("UIGradient", { -- Hue Gradient
                        Rotation = 90, -- Top to Bottom
                        Color = ColorSequence.new{
                            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),   -- Red
                            ColorSequenceKeypoint.new(1/6, Color3.fromRGB(255, 255, 0)), -- Yellow
                            ColorSequenceKeypoint.new(2/6, Color3.fromRGB(0, 255, 0)),   -- Lime
                            ColorSequenceKeypoint.new(3/6, Color3.fromRGB(0, 255, 255)), -- Cyan
                            ColorSequenceKeypoint.new(4/6, Color3.fromRGB(0, 0, 255)),   -- Blue
                            ColorSequenceKeypoint.new(5/6, Color3.fromRGB(255, 0, 255)), -- Magenta
                            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0))    -- Red (wrap)
                        },
                    }),
					Create("UICorner", {CornerRadius = UDim.new(0, 5)}),
					HueSelection -- Selector is child of this frame
				})

                -- Container for the picker elements
				local ColorpickerContainer = Create("Frame", {
					Position = UDim2.new(0, 0, 1, 1), -- Position below main part + divider
					Size = UDim2.new(1, 0, 0, 110), -- Fixed height for picker area
					BackgroundTransparency = 1, -- Container itself is transparent
					ClipsDescendants = true, -- Clip the contents (Color and Hue frames)
                    Visible = false -- Start hidden
				}, {
					Hue,
					Color,
					Create("UIPadding", { -- Padding around Color and Hue pickers
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
						PaddingBottom = UDim.new(0, 10),
						PaddingTop = UDim.new(0, 10)
					})
				})

				local Click = SetProps(MakeElement("Button"), { -- Click detector for main part
					Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1
				})

				local ColorpickerBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Colorpicker.Value, 0, 4), { -- Shows selected color
					Size = UDim2.new(0, 24, 0, 24),
					Position = UDim2.new(1, -12, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
                    Name = "ColorDisplay"
				}), {
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Main")

				local ColorpickerFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", elementTheme.Second, 0, 5), {
					Size = UDim2.new(1, 0, 0, 38), -- Fixed height for collapsed state
					Parent = ItemParent,
                    ClipsDescendants = true, -- Clip contents initially
                    ZIndex = 2 -- Above normal elements
				}), {
                    ColorpickerContainer, -- Add container first (drawn below F)
					SetProps(SetChildren(MakeElement("TFrame"), { -- Frame for top elements + click detector
						AddThemeObject(SetProps(MakeElement("Label", ColorpickerConfig.Name, 14), {
							Size = UDim2.new(1, -50, 1, 0), -- Adjusted for color box
							Position = UDim2.new(0, 12, 0, 0),
							Font = Enum.Font.GothamBold,
							Name = "Content",
                            TextYAlignment = Enum.TextYAlignment.Center
						}), "Text"),
						ColorpickerBox,
						Click,
						AddThemeObject(SetProps(MakeElement("Frame"), { -- Divider line
							Size = UDim2.new(1, 0, 0, 1),
							Position = UDim2.new(0, 0, 1, 0), -- Bottom of this frame
							Name = "Line",
							Visible = false -- Hidden initially
						}), "Stroke"),
					}), {
						Size = UDim2.new(1, 0, 1, 0), -- Cover the parent frame
						ClipsDescendants = true,
						Name = "F"
					}),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
				}), "Second")

                local colorpickerOpenTween = nil
                local containerOpenTween = nil
				AddConnection(Click.MouseButton1Click, function()
					Colorpicker.Toggled = not Colorpicker.Toggled

                    if colorpickerOpenTween and colorpickerOpenTween.PlaybackState == Enum.PlaybackState.Playing then colorpickerOpenTween:Cancel() end
                    if containerOpenTween and containerOpenTween.PlaybackState == Enum.PlaybackState.Playing then containerOpenTween:Cancel() end

                    local targetFrameSizeY = Colorpicker.Toggled and (38 + 1 + 110) or 38 -- Frame height + divider + container height
                    local targetContainerVisible = Colorpicker.Toggled

                    -- Animate overall frame size
                    colorpickerOpenTween = TweenService:Create(ColorpickerFrame, TWEEN_INFO_NORMAL, { Size = UDim2.new(1, 0, 0, targetFrameSizeY) })
                    colorpickerOpenTween:Play()

                    -- Handle container visibility and internal element visibility
                    if Colorpicker.Toggled then
                        ColorpickerFrame.ClipsDescendants = false -- Unclip main frame
                        ColorpickerContainer.Visible = true -- Make container visible first
                        ColorpickerContainer.ClipsDescendants = false -- Unclip container
                        Color.Visible = true
                        Hue.Visible = true
                        ColorpickerFrame.F.Line.Visible = true
                        -- Optional: Fade in container content?
                    else
                        ColorpickerFrame.F.Line.Visible = false
                        -- Optional: Fade out container content before hiding?
                        task.delay(TWEEN_INFO_NORMAL.Time, function() -- Hide after main frame shrinks
                            if not Colorpicker.Toggled then -- Check state again in case it was clicked quickly
                                Color.Visible = false
                                Hue.Visible = false
                                ColorpickerContainer.Visible = false
                                ColorpickerFrame.ClipsDescendants = true -- Re-clip main frame
                                ColorpickerContainer.ClipsDescendants = true -- Re-clip container
                            end
                        end)
                    end
				end)

                setupElementEffects(ColorpickerFrame, Click) -- Add hover/click to main part

				local function UpdateColorPicker(skipCallback)
                    local newColor = Color3.fromHSV(ColorH, ColorS, ColorV)
                    if Colorpicker.Value == newColor then return end -- No change

                    Colorpicker.Value = newColor
					ColorpickerBox.BackgroundColor3 = Colorpicker.Value

                    -- Update Saturation/Value picker background based on Hue
                    local hueColor = Color3.fromHSV(ColorH, 1, 1)
                    Color.BackgroundColor3 = hueColor
                    local grad = Color:FindFirstChildOfClass("UIGradient")
                    if grad then grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)), ColorSequenceKeypoint.new(1, hueColor)} end

                    if not skipCallback then
					    task.spawn(ColorpickerConfig.Callback, Colorpicker.Value)
                    end
				end

                local inputConnection = nil
                local function StartDrag(inputType) -- "Color" or "Hue"
                    pickerDragging = inputType
                    if inputConnection then inputConnection:Disconnect() end
                    inputConnection = AddConnection(UserInputService.InputChanged, function(input)
                        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                            if pickerDragging == "Color" then
                                local mousePos = input.Position
                                local relativeX = math.clamp(mousePos.X - Color.AbsolutePosition.X, 0, Color.AbsoluteSize.X)
                                local relativeY = math.clamp(mousePos.Y - Color.AbsolutePosition.Y, 0, Color.AbsoluteSize.Y)
                                ColorS = relativeX / Color.AbsoluteSize.X
                                ColorV = 1 - (relativeY / Color.AbsoluteSize.Y)
                                ColorSelection.Position = UDim2.fromScale(ColorS, 1 - ColorV)
                                UpdateColorPicker()
                            elseif pickerDragging == "Hue" then
                                local mousePos = input.Position
                                local relativeY = math.clamp(mousePos.Y - Hue.AbsolutePosition.Y, 0, Hue.AbsoluteSize.Y)
                                ColorH = relativeY / Hue.AbsoluteSize.Y
                                HueSelection.Position = UDim2.fromScale(0.5, ColorH)
                                UpdateColorPicker()
                            end
                        end
                    end)
                end

                local function StopDrag()
                    if pickerDragging and Colorpicker.Save then
                        SaveCfg(game.GameId) -- Save on drag end if enabled
                    end
                    pickerDragging = nil
                    if inputConnection then inputConnection:Disconnect(); inputConnection = nil end
                end

				AddConnection(Color.InputBegan, function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then StartDrag("Color"); UpdateColorPicker() end end)
				AddConnection(Hue.InputBegan, function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then StartDrag("Hue"); UpdateColorPicker() end end)

				AddConnection(UserInputService.InputEnded, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						if pickerDragging then StopDrag() end
					end
				end)


				function Colorpicker:Set(Value, skipCallback)
                    if type(Value) ~= "Color3" then return end
					ColorH, ColorS, ColorV = Color3.toHSV(Value)
					Colorpicker.Value = Value
					ColorpickerBox.BackgroundColor3 = Colorpicker.Value

                    -- Update selector positions
                    ColorSelection.Position = UDim2.fromScale(ColorS, 1 - ColorV)
                    HueSelection.Position = UDim2.fromScale(0.5, ColorH)

                    -- Update picker background gradients/colors
                    local hueColor = Color3.fromHSV(ColorH, 1, 1)
                    Color.BackgroundColor3 = hueColor
                    local grad = Color:FindFirstChildOfClass("UIGradient")
                    if grad then grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)), ColorSequenceKeypoint.new(1, hueColor)} end


					if not skipCallback then
                        task.spawn(ColorpickerConfig.Callback, Colorpicker.Value)
                    end
				end

				Colorpicker:Set(Colorpicker.Value, true) -- Set initial state

				if ColorpickerConfig.Flag then
					OrionLib.Flags[ColorpickerConfig.Flag] = Colorpicker
				end
				return Colorpicker
			end
			return ElementFunction
		end

		local ElementFunction = {}

		function ElementFunction:AddSection(SectionConfig)
			SectionConfig = SectionConfig or {}
            SectionConfig.Name = SectionConfig.Name or "Section"

			local SectionFrame = SetChildren(SetProps(MakeElement("TFrame"), {
				Size = UDim2.new(1, 0, 0, 0), -- Start at zero height
                AutomaticSize = Enum.AutomaticSize.Y, -- Auto-adjust height
				Parent = Container,
                LayoutOrder = #Container:GetChildren() + 1 -- Ensure order
			}), {
                AddThemeObject(SetProps(MakeElement("Label", "<b>" .. SectionConfig.Name .. "</b>", 14), { -- Bold section title
					Size = UDim2.new(1, 0, 0, 20), -- Fixed height for title
					Position = UDim2.new(0, 0, 0, 0),
					Font = Enum.Font.GothamBold, -- Bold font
                    TextYAlignment = Enum.TextYAlignment.Bottom,
                    Name = "SectionTitle",
                    LayoutOrder = 1
				}), "TextDark"), -- Use TextDark for section titles
				SetChildren(SetProps(MakeElement("TFrame"), {
					AnchorPoint = Vector2.new(0, 0),
					Size = UDim2.new(1, 0, 0, 0), -- Auto height for holder
                    AutomaticSize = Enum.AutomaticSize.Y,
					Position = UDim2.new(0, 0, 0, 23), -- Position below title
					Name = "Holder",
                    LayoutOrder = 2
				}), {
					MakeElement("List", 0, 6) -- Spacing for elements within section
				}),
                MakeElement("List", 0, 5) -- Vertical layout for Title + Holder
			})

            -- No need for connection, AutomaticSize handles height

			local SectionFunction = {}
			for i, v in pairs(GetElements(SectionFrame.Holder)) do -- Use pairs for dictionaries
				SectionFunction[i] = v
			end
			return SectionFunction
		end

		for i, v in pairs(GetElements(Container)) do -- Use pairs for dictionaries
			ElementFunction[i] = v
		end

		if TabConfig.PremiumOnly and WindowConfig.HidePremium then -- Check HidePremium flag too
			-- Optionally hide the tab itself, or just disable content
            TabContainer.Visible = false -- Hide the tab button container
            Container:Destroy() -- Destroy the content container

            -- Return dummy functions
            local dummyFunc = function() return {Set = function() end, Refresh = function() end} end
            for i, _ in pairs(ElementFunction) do ElementFunction[i] = dummyFunc end
            return ElementFunction
		end

		return ElementFunction
	end

	return TabFunction
end

function OrionLib:Destroy()
    -- Disconnect all connections first
    for _, Connection in pairs(OrionLib.Connections) do
		if typeof(Connection.Disconnect) == "function" then
			pcall(Connection.Disconnect)
		end
	end
	OrionLib.Connections = {} -- Clear connections table

    -- Destroy the main ScreenGui
	if Orion and Orion.Parent then
	    Orion:Destroy()
    end

    -- Clear flags and theme objects to prevent memory leaks if library object persists
    OrionLib.Flags = {}
    OrionLib.ThemeObjects = {}
end

return OrionLib
