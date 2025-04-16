--[[
    EDEN 12 Refactored UI Library
    Focus: Modularity, Performance (Lazy Creation), Readability, Theming
]]

-- // Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Debris = game:GetService("Debris")
local CoreGui = game:GetService("CoreGui") -- Use GetService consistently

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse() -- Keep mouse handy if needed by modules

--========================================================================
-- // Theme Module (Configuration)
--========================================================================
local Theme = {
    -- Colors
    Background = Color3.fromRGB(18, 18, 18),
    BackgroundSecondary = Color3.fromRGB(25, 25, 25),
    BackgroundTertiary = Color3.fromRGB(32, 32, 32),
    BackgroundOverlay = Color3.fromRGB(18, 18, 18),
    Accent = Color3.fromRGB(83, 87, 158),
    AccentDark = Color3.fromRGB(50, 50, 50), -- Example for inactive/hover states
    Text = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(150, 150, 150),
    TextTertiary = Color3.fromRGB(100, 100, 100),
    TextDisabled = Color3.fromRGB(90, 90, 90),
    Error = Color3.fromRGB(170, 89, 91),
    Success = Color3.fromRGB(60, 150, 107),
    Divider = Color3.fromRGB(74, 74, 74),
    Shadow = Color3.fromRGB(0, 0, 0),

    -- Fonts
    Font = Enum.Font.Gotham,
    FontSemibold = Enum.Font.GothamSemibold,
    FontBold = Enum.Font.GothamBold,

    -- Sizes
    TextSize = 14,
    SmallTextSize = 12,
    TitleSize = 18,
    CornerRadius = UDim.new(0.1, 0),
    SmallCornerRadius = UDim.new(0.05, 0),
    LargeCornerRadius = UDim.new(0.2, 0),
    RoundCornerRadius = UDim.new(1, 0),

    -- Assets (Using descriptive names)
    DropShadowImage = "rbxassetid://6014261993", -- Generic shadow
    DropShadowSliceCenter = Rect.new(49, 49, 450, 450),
    DropShadowTransparency = 0.5,

    NineSliceImage = "rbxassetid://7881709447", -- Generic 9-slice panel
    NineSliceSliceCenter = Rect.new(512, 512, 512, 512),
    NineSliceScale = 0.005,

    CheckmarkImage = "rbxassetid://7072706620",
    CrossImage = "rbxassetid://7072725342",
    DropdownArrowImage = "rbxassetid://7072706663",
    ColorWheelImage = "rbxassetid://6020299385",
    SliderBackgroundImage = "rbxassetid://3570695787", -- For saturation gradient
    PointerImage = "rbxassetid://7892266163", -- Color wheel pointer

    -- Animation
    DefaultTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), -- Slightly faster default
    FastTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
    SlowTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),

    -- Z-Indices (Define base levels)
    BaseZIndex = 100,
    OverlayZIndex = 200,
    PopupZIndex = 300,
    TooltipZIndex = 400,

    -- Other
    DefaultWatermark = "EDEN 12 UI | %s | %s", -- UserID, GameName
    TimeUpdateInterval = 1, -- Update time every 1 second (adjust 1 to 60 for minutes etc.)
    TimeFormat = "%I:%M %p", -- 12-hour format with AM/PM. Use "%H:%M" for 24-hour.
}

-- Function to adjust animation speed globally
function Theme:SetAnimSpeed(speedMultiplier)
    local baseDuration = 0.3 -- Base duration for DefaultTweenInfo
    speedMultiplier = math.max(0.1, speedMultiplier) -- Prevent zero or negative multiplier
    local newDuration = baseDuration / speedMultiplier
    Theme.DefaultTweenInfo = TweenInfo.new(newDuration, Theme.DefaultTweenInfo.EasingStyle, Theme.DefaultTweenInfo.EasingDirection)
    Theme.FastTweenInfo = TweenInfo.new(newDuration * 0.66, Theme.FastTweenInfo.EasingStyle, Theme.FastTweenInfo.EasingDirection)
    Theme.SlowTweenInfo = TweenInfo.new(newDuration * 1.66, Theme.SlowTweenInfo.EasingStyle, Theme.SlowTweenInfo.EasingDirection)
    -- Consider updating other TIs if necessary
end


--========================================================================
-- // Utils Module
--========================================================================
local Utils = {}

local camera = workspace.CurrentCamera -- Use CurrentCamera

-- Debounce function
function Utils.Debounce(func, delay)
	local lastCall = 0
	return function(...)
		local now = tick()
		if now - lastCall >= delay then
			lastCall = now
			func(...)
		end
	end
end

-- Get next layout order helper
function Utils.GetLayoutOrder(container)
    local maxOrder = 0
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("GuiObject") then
            maxOrder = math.max(maxOrder, child.LayoutOrder)
        end
    end
    return maxOrder + 1
end

-- Simple deep clone for tables (used for component template defaults)
function Utils.DeepCloneTable(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = Utils.DeepCloneTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- Convert Color3 to Hex string
function Utils.Color3ToHex(color)
	return string.format("#%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
end

-- Convert Hex string to Color3
function Utils.HexToColor3(hex)
	hex = hex:gsub("#", "")
	local r = tonumber("0x" .. hex:sub(1, 2)) / 255
	local g = tonumber("0x" .. hex:sub(3, 4)) / 255
	local b = tonumber("0x" .. hex:sub(5, 6)) / 255
	return Color3.new(r, g, b)
end

-- Update camera viewport size (call if needed, e.g., on resize)
function Utils.UpdateCameraViewport()
    camera = workspace.CurrentCamera
end
-- Potentially add OffsetToScale, ScaleToOffset, CheckBoundary etc. if Draggable needs them externally


--========================================================================
-- // Effects Module
--========================================================================
local Effects = {}

-- Standard Hover Effect (Transparency)
function Effects.AddHoverTransparency(guiObject, targetProperty, hoverTransparency, normalTransparency)
    hoverTransparency = hoverTransparency or 0.5
    normalTransparency = normalTransparency or 1.0
    local connections = {}
    local isHovering = false

    local tweenIn = TweenService:Create(guiObject, Theme.FastTweenInfo, { [targetProperty] = hoverTransparency })
    local tweenOut = TweenService:Create(guiObject, Theme.FastTweenInfo, { [targetProperty] = normalTransparency })

    connections.MouseEnter = guiObject.MouseEnter:Connect(function()
        isHovering = true
        tweenOut:Cancel()
        tweenIn:Play()
    end)

    connections.MouseLeave = guiObject.MouseLeave:Connect(function()
        isHovering = false
        tweenIn:Cancel()
        tweenOut:Play()
    end)

    -- Return a function to disconnect the effects
    return function()
        for _, conn in pairs(connections) do
            conn:Disconnect()
        end
        -- Reset to normal state on disconnect
        if guiObject and guiObject.Parent then
            guiObject[targetProperty] = normalTransparency
        end
    end
end

-- Standard Click Effect (Temporary visual change)
function Effects.AddClickFeedback(guiObject, property, clickedValue, normalValue, duration)
	local clickEvent = Instance.new("BindableEvent")
	duration = duration or 0.1

	local function playFeedback()
		local originalValue = guiObject[property]
		guiObject[property] = clickedValue
		task.wait(duration)
		-- Check if object still exists before resetting
		if guiObject and guiObject.Parent then
			guiObject[property] = originalValue
		end
	end

	local connection = guiObject.MouseButton1Click:Connect(function()
		playFeedback()
		clickEvent:Fire() -- Fire event after feedback (or during, depending on desired behavior)
	end)

	return clickEvent.Event, function()
		connection:Disconnect()
		clickEvent:Destroy() -- Clean up bindable event
	end
end


-- Circle Click Effect (similar to original but cleaned up)
function Effects.CircleClick(button)
    local circle = Instance.new("Frame")
    local corner = Instance.new("UICorner", circle)

    local mousePos = UserInputService:GetMouseLocation()
    local buttonPos = button.AbsolutePosition
    local relativePos = mousePos - buttonPos

    corner.CornerRadius = Theme.RoundCornerRadius
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.BackgroundColor3 = Theme.Shadow -- Or a specific effect color
    circle.Position = UDim2.fromOffset(relativePos.X, relativePos.Y)
    circle.Size = UDim2.fromOffset(1, 1) -- Start small
    circle.BackgroundTransparency = 0.8
    circle.ZIndex = (button.ZIndex or 1) + 10 -- Ensure it's on top
    circle.ClipsDescendants = true
    circle.Parent = button

    local targetSize = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 1.5 -- Expand beyond button bounds

    local tween = TweenService:Create(circle, Theme.DefaultTweenInfo, {
        Size = UDim2.fromOffset(targetSize, targetSize),
        BackgroundTransparency = 1
    })

    tween:Play()
    Debris:AddItem(circle, Theme.DefaultTweenInfo.Time) -- Remove after tween duration
end

-- Fade In/Out Effect
function Effects.Fade(guiObject, fadeIn, duration, callback)
    duration = duration or Theme.DefaultTweenInfo.Time
    local targetTransparency = fadeIn and 0 or 1
    local startTransparency = fadeIn and 1 or 0

    -- Ensure starting state if needed (e.g., start invisible before fading in)
    if fadeIn and guiObject.BackgroundTransparency ~= 1 and guiObject.TextTransparency ~= 1 then
         if guiObject:IsA("Frame") or guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton") then
             guiObject.BackgroundTransparency = 1
         end
         if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") or guiObject:IsA("TextBox") then
             guiObject.TextTransparency = 1
         end
         -- Handle children recursively? Could be complex. Maybe target specific properties.
    end

    local properties = {}
    if guiObject:IsA("Frame") or guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton") then
        properties.BackgroundTransparency = targetTransparency
    end
    if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") or guiObject:IsA("TextBox") then
        properties.TextTransparency = targetTransparency
    end
    -- Add ImageTransparency for ImageLabels/Buttons if applicable
    if guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton") then
         properties.ImageTransparency = targetTransparency
    end

    if next(properties) then -- Check if there are any properties to tween
        local tween = TweenService:Create(guiObject, TweenInfo.new(duration, Enum.EasingStyle.Linear), properties) -- Linear often looks best for fades
        tween:Play()
        if callback then
            tween.Completed:Connect(callback)
        end
        return tween -- Return tween instance if control is needed
    elseif callback then
        task.spawn(callback) -- Run callback immediately if nothing to tween
    end
    return nil
end

-- Slide Effect
function Effects.Slide(guiObject, targetPosition, duration, callback)
    duration = duration or Theme.DefaultTweenInfo.Time
    local tween = TweenService:Create(guiObject, TweenInfo.new(duration, Theme.DefaultTweenInfo.EasingStyle, Theme.DefaultTweenInfo.EasingDirection), { Position = targetPosition })
    tween:Play()
    if callback then
        tween.Completed:Connect(callback)
    end
    return tween
end


--========================================================================
-- // Draggable Module (Simplified version, adapt original if complex features are needed)
--========================================================================
local Draggable = {}

function Draggable.EnableDrag(guiObject, dragHandle, boundary)
    local dragging = false
    local dragInput = nil
    local lastMousePos = nil
    local connections = {}

    connections.InputBegan = dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            lastMousePos = UserInputService:GetMouseLocation()
            dragInput = input
            -- Optional: Change mouse cursor
        end
    end)

    connections.InputChanged = UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local currentMousePos = UserInputService:GetMouseLocation()
            local delta = currentMousePos - lastMousePos
            lastMousePos = currentMousePos

            local currentPosition = guiObject.Position
            local currentOffset = Vector2.new(currentPosition.X.Offset, currentPosition.Y.Offset)
            local targetOffset = currentOffset + delta

            -- Boundary Check (Simplified)
            if boundary then
                 local guiSize = guiObject.AbsoluteSize
                 local boundPos = boundary.AbsolutePosition
                 local boundSize = boundary.AbsoluteSize

                 targetOffset = Vector2.new(
                     math.clamp(targetOffset.X, boundPos.X, boundPos.X + boundSize.X - guiSize.X),
                     math.clamp(targetOffset.Y, boundPos.Y, boundPos.Y + boundSize.Y - guiSize.Y)
                 )
            end


            guiObject.Position = UDim2.new(
                currentPosition.X.Scale, targetOffset.X,
                currentPosition.Y.Scale, targetOffset.Y
            )
        end
    end)

    connections.InputEnded = UserInputService.InputEnded:Connect(function(input)
        if input == dragInput then
            dragging = false
            dragInput = nil
            lastMousePos = nil
            -- Optional: Reset mouse cursor
        end
    end)

    -- Return a disconnect function
    return function()
        for _, conn in pairs(connections) do
            conn:Disconnect()
        end
        -- Ensure state is reset if needed
        dragging = false
        dragInput = nil
        lastMousePos = nil
    end
end

--========================================================================
-- // Component Templates Module
--========================================================================
local ComponentTemplates = {}

-- Helper to create a standard drop shadow
local function CreateDropShadow(parentZIndex)
    local holder = Instance.new("Frame")
    holder.Name = "DropShadowHolder"
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.fromScale(1, 1)
    holder.ZIndex = (parentZIndex or 1) - 1 -- Behind parent

    local shadow = Instance.new("ImageLabel")
    shadow.Name = "DropShadow"
    shadow.Image = Theme.DropShadowImage
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Theme.DropShadowSliceCenter
    shadow.ImageColor3 = Theme.Shadow
    shadow.ImageTransparency = Theme.DropShadowTransparency
    shadow.BackgroundTransparency = 1
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.fromScale(0.5, 0.5)
    -- Start slightly larger than parent, adjust per component if needed
    shadow.Size = UDim2.new(1, 10, 1, 10)
    shadow.ZIndex = holder.ZIndex
    shadow.Parent = holder

    return holder
end

-- Template: Basic Frame with Corner and Shadow
ComponentTemplates.BaseFrame = function(props)
    local frame = Instance.new("Frame")
    frame.Name = props.Name or "BaseFrame"
    frame.BackgroundColor3 = props.BackgroundColor3 or Theme.BackgroundSecondary
    frame.BorderSizePixel = 0
    frame.Size = props.Size or UDim2.fromScale(1, 1)
    frame.ZIndex = props.ZIndex or Theme.BaseZIndex

    local corner = Instance.new("UICorner")
    corner.CornerRadius = props.CornerRadius or Theme.CornerRadius
    corner.Parent = frame

    if props.DropShadow then
        local shadow = CreateDropShadow(frame.ZIndex)
        shadow.Parent = frame
        -- Customize shadow size/offset per component if needed
        if props.ShadowSizeOffset then
             shadow.DropShadow.Size = UDim2.new(1, props.ShadowSizeOffset.X, 1, props.ShadowSizeOffset.Y)
        end
    end

    return frame
end

-- Template: Text Label
ComponentTemplates.BaseLabel = function(props)
    local label = Instance.new("TextLabel")
    label.Name = props.Name or "BaseLabel"
    label.BackgroundTransparency = 1
    label.Font = props.Font or Theme.Font
    label.Text = props.Text or ""
    label.TextColor3 = props.TextColor3 or Theme.TextSecondary
    label.TextSize = props.TextSize or Theme.TextSize
    label.TextWrapped = props.TextWrapped or true
    label.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    label.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
    label.Size = props.Size or UDim2.new(1, 0, 1, 0)
    label.ZIndex = props.ZIndex or Theme.BaseZIndex + 1
    return label
end

-- Template: Hover Frame (for effects)
ComponentTemplates.HoverFrame = function(props)
    local hover = Instance.new("Frame")
    hover.Name = "HoverFrame"
    hover.BackgroundColor3 = props.HoverColor or Theme.AccentDark
    hover.BackgroundTransparency = 1 -- Start transparent
    hover.BorderSizePixel = 0
    hover.Size = UDim2.fromScale(1, 1)
    hover.ZIndex = (props.ParentZIndex or 1) + 1 -- Above parent, below content usually

    local corner = Instance.new("UICorner")
    corner.CornerRadius = props.CornerRadius or Theme.CornerRadius -- Match parent corner
    corner.Parent = hover

    return hover
end


-- Specific Component Templates ---

-- Window Template
ComponentTemplates.Window = function(props)
    local window = Instance.new("Frame")
    window.Name = "WindowContainer"
    window.BackgroundTransparency = 1
    window.Size = UDim2.fromScale(1, 1) -- Fullscreen container

    local mainUI = ComponentTemplates.BaseFrame({
        Name = "MainUI",
        BackgroundColor3 = Theme.Background,
        Size = UDim2.new(0, 851, 0, 488), -- Original size, consider making dynamic/configurable
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        CornerRadius = Theme.SmallCornerRadius, -- Original was 0.0199, adjust Theme if needed
        DropShadow = true,
        ShadowSizeOffset = Vector2.new(45, 45),
        ZIndex = Theme.BaseZIndex
    })
    mainUI.Parent = window

    -- Sidebar Structure
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.BackgroundTransparency = 1 -- Container
    sidebar.Size = UDim2.new(0.18, 0, 1, 0) -- Increased default width slightly
    sidebar.ZIndex = Theme.BaseZIndex + 1
    sidebar.Parent = mainUI
    -- Sidebar fill/bg (using original assets/colors for now)
    local sidebarFill = Instance.new("ImageLabel")
    sidebarFill.Name = "Fill"
    sidebarFill.Image = "rbxassetid://7881302920" -- Keep original assets for now
    sidebarFill.ImageColor3 = Color3.fromRGB(27, 27, 27) -- Darker background
    sidebarFill.ScaleType = Enum.ScaleType.Slice
    sidebarFill.SliceCenter = Rect.new(512, 512, 512, 512)
    sidebarFill.SliceScale = 0.020
    sidebarFill.BackgroundTransparency = 1
    sidebarFill.Size = UDim2.fromScale(1, 1)
    sidebarFill.ZIndex = Theme.BaseZIndex -- Behind content
    sidebarFill.Parent = sidebar
    -- Divider line
	local divLine = Instance.new("Frame")
	divLine.Name = "DivLine"
	divLine.BackgroundColor3 = Theme.Divider
	divLine.BorderSizePixel = 0
	divLine.Position = UDim2.new(1, -1, 0, 0) -- Positioned at the right edge
    divLine.AnchorPoint = Vector2.new(1, 0)
	divLine.Size = UDim2.new(0, 1, 1, 0) -- 1 pixel wide
	divLine.ZIndex = Theme.BaseZIndex + 2 -- Above sidebar content
	divLine.Parent = sidebar


    -- Sidebar Content Holder (Padded area)
    local sidebarContentHolder = Instance.new("Frame")
    sidebarContentHolder.Name = "ContentHolder"
    sidebarContentHolder.BackgroundTransparency = 1
    sidebarContentHolder.Size = UDim2.fromScale(1, 1)
    sidebarContentHolder.ZIndex = Theme.BaseZIndex + 1
    sidebarContentHolder.Parent = sidebar
    local sidebarPadding = Instance.new("UIPadding")
    sidebarPadding.PaddingTop = UDim.new(0, 8)
    sidebarPadding.PaddingBottom = UDim.new(0, 8)
    sidebarPadding.PaddingLeft = UDim.new(0, 8)
    sidebarPadding.PaddingRight = UDim.new(0, 8)
    sidebarPadding.Parent = sidebarContentHolder

    -- Sidebar: User Info Section (Top)
    local userInfo = Instance.new("Frame")
    userInfo.Name = "UserInfo"
    userInfo.BackgroundTransparency = 1 -- Or a slightly different bg color
    userInfo.Size = UDim2.new(1, 0, 0.15, 0) -- Relative height
    userInfo.LayoutOrder = 1
    userInfo.Parent = sidebarContentHolder
    local userInfoLayout = Instance.new("UIListLayout")
    userInfoLayout.SortOrder = Enum.SortOrder.LayoutOrder
    userInfoLayout.Padding = UDim.new(0, 2)
    userInfoLayout.Parent = userInfo
    local userInfoPadding = Instance.new("UIPadding")
    userInfoPadding.PaddingTop = UDim.new(0, 4)
    userInfoPadding.PaddingBottom = UDim.new(0, 4)
    userInfoPadding.PaddingLeft = UDim.new(0, 4)
    userInfoPadding.PaddingRight = UDim.new(0, 4)
    userInfoPadding.Parent = userInfo

    local userNameLabel = ComponentTemplates.BaseLabel({ Name = "UserName", Text = "UserID", Font = Theme.FontSemibold, TextColor3 = Theme.Text, TextSize = Theme.TextSize, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1})
    userNameLabel.Parent = userInfo
    local userRankLabel = ComponentTemplates.BaseLabel({ Name = "UserRank", Text = "Rank", Font = Theme.Font, TextColor3 = Theme.TextSecondary, TextSize = Theme.SmallTextSize, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2})
    userRankLabel.Parent = userInfo


    -- Sidebar: Category List Holder (Below User Info)
    local categoryList = Instance.new("ScrollingFrame") -- Use ScrollingFrame for categories
    categoryList.Name = "CategoryList"
    categoryList.BackgroundTransparency = 1
    categoryList.Size = UDim2.new(1, 0, 0.85, 0) -- Remaining space
    categoryList.LayoutOrder = 2
    categoryList.BorderSizePixel = 0
    categoryList.ScrollBarThickness = 4
    categoryList.CanvasSize = UDim2.fromScale(0,0) -- Auto canvas size
    categoryList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    categoryList.Parent = sidebarContentHolder
    local categoryListLayout = Instance.new("UIListLayout")
    categoryListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    categoryListLayout.Padding = UDim.new(0, 5)
    categoryListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    categoryListLayout.Parent = categoryList


    -- Main Content Area (Right side)
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.BackgroundTransparency = 1
    contentArea.ClipsDescendants = true
    contentArea.Size = UDim2.new(1 - sidebar.Size.X.Scale, 0, 1, 0) -- Fill remaining space
    contentArea.Position = UDim2.new(sidebar.Size.X.Scale, 0, 0, 0)
    contentArea.ZIndex = Theme.BaseZIndex + 1
    contentArea.Parent = mainUI

    -- Notification Area (Top Right or elsewhere)
    local notificationArea = Instance.new("Frame")
    notificationArea.Name = "NotificationArea"
    notificationArea.BackgroundTransparency = 1
    notificationArea.Size = UDim2.new(0.25, 0, 1, 0) -- Example size
    notificationArea.Position = UDim2.new(1, 0, 0, 0)
    notificationArea.AnchorPoint = Vector2.new(1, 0) -- Anchor to top right
    notificationArea.ZIndex = Theme.PopupZIndex -- Above main content
    notificationArea.Parent = window -- Parent to ScreenGui to overlay MainUI
    local notificationLayout = Instance.new("UIListLayout")
    notificationLayout.SortOrder = Enum.SortOrder.LayoutOrder
    notificationLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    notificationLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom -- Or Top
    notificationLayout.Padding = UDim.new(0, 8)
    notificationLayout.Parent = notificationArea

    -- Watermark
    local watermark = ComponentTemplates.BaseLabel({
        Name = "Watermark",
        Text = "Watermark Text",
        TextColor3 = Theme.TextSecondary,
        TextSize = Theme.SmallTextSize,
        TextStrokeTransparency = 0.8,
        Size = UDim2.new(0.5, 0, 0.03, 0),
        Position = UDim2.new(0, 5, 1, -5), -- Bottom left-ish
        AnchorPoint = Vector2.new(0, 1),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = Theme.PopupZIndex + 1 -- Above everything
    })
    watermark.Parent = window

    -- Color Picker Overlay (Initially hidden)
    local colorPickerOverlay = Instance.new("ImageButton") -- Use ImageButton for background click to close?
    colorPickerOverlay.Name = "ColorPickerOverlay"
    colorPickerOverlay.BackgroundTransparency = 1 -- Start transparent
    colorPickerOverlay.BackgroundColor3 = Theme.BackgroundOverlay
    colorPickerOverlay.Size = UDim2.fromScale(1, 1)
    colorPickerOverlay.Visible = false
    colorPickerOverlay.ZIndex = Theme.OverlayZIndex
    colorPickerOverlay.AutoButtonColor = false
    colorPickerOverlay.Parent = window -- Parent to ScreenGui

    -- Color Picker Content Frame (slides in)
    local colorPickerContent = ComponentTemplates.BaseFrame({
        Name = "ColorPickerContent",
        BackgroundColor3 = Theme.Background, -- Slightly different bg?
        Size = UDim2.new(0.3, 0, 0.5, 0), -- Example size
        Position = UDim2.new(0.5, 0, 1.5, 0), -- Start off-screen
        AnchorPoint = Vector2.new(0.5, 0.5),
        CornerRadius = Theme.SmallCornerRadius,
        DropShadow = true,
        ShadowSizeOffset = Vector2.new(24, 24),
        ZIndex = Theme.OverlayZIndex + 1
    })
    colorPickerContent.Parent = colorPickerOverlay

    -- Add basic layout to ColorPickerContent
    local cpLayout = Instance.new("UIListLayout")
    cpLayout.Padding = UDim.new(0, 10)
    cpLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    cpLayout.Parent = colorPickerContent
    local cpPadding = Instance.new("UIPadding")
    cpPadding.PaddingTop = UDim.new(0, 10)
    cpPadding.PaddingBottom = UDim.new(0, 10)
    cpPadding.PaddingLeft = UDim.new(0, 10)
    cpPadding.PaddingRight = UDim.new(0, 10)
    cpPadding.Parent = colorPickerContent


    -- Return main window frame and references to key areas
    return window, {
        MainUI = mainUI,
        Sidebar = sidebar,
        SidebarContent = sidebarContentHolder,
        UserInfo = userInfo,
        UserNameLabel = userNameLabel,
        UserRankLabel = userRankLabel,
        CategoryList = categoryList,
        ContentArea = contentArea,
        NotificationArea = notificationArea,
        Watermark = watermark,
        ColorPickerOverlay = colorPickerOverlay,
        ColorPickerContent = colorPickerContent
    }
end

-- Category Button Template (for sidebar)
ComponentTemplates.CategoryButton = function(props)
    local button = Instance.new("ImageButton") -- Use ImageButton for click handling
    button.Name = props.Name or "CategoryButton"
    button.BackgroundColor3 = Theme.Background -- Match sidebar bg or slight difference?
    button.BackgroundTransparency = 1 -- Let Fill handle visual background
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 40) -- Fixed height, adjust as needed
    button.ZIndex = Theme.BaseZIndex + 2
    button.AutoButtonColor = false

    local hoverFrame = ComponentTemplates.HoverFrame({ ParentZIndex = button.ZIndex, CornerRadius = Theme.SmallCornerRadius, HoverColor = Theme.BackgroundTertiary })
    hoverFrame.Parent = button

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.BackgroundTransparency = 1
    content.Size = UDim2.fromScale(1, 1)
    content.ZIndex = button.ZIndex + 1 -- Above hover
    content.Parent = button
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.FillDirection = Enum.FillDirection.Horizontal
    contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    contentLayout.Padding = UDim.new(0, 8)
    contentLayout.Parent = content
    local contentPadding = Instance.new("UIPadding")
    contentPadding.PaddingTop = UDim.new(0, 8)
    contentPadding.PaddingBottom = UDim.new(0, 8)
    contentPadding.PaddingLeft = UDim.new(0, 8)
    contentPadding.PaddingRight = UDim.new(0, 8)
    contentPadding.Parent = contentFrame

    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(0, 20, 0, 20) -- Fixed size icon
    icon.Image = props.Icon or ""
    icon.ImageColor3 = Theme.TextDisabled
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = content

    local title = ComponentTemplates.BaseLabel({
        Name = "Title",
        Text = props.Title or "Category",
        TextColor3 = Theme.TextDisabled,
        Font = Theme.Font,
        TextSize = Theme.TextSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -30, 1, 0) -- Fill remaining space minus icon/padding
    })
    title.Parent = content

    -- Selection indicator (e.g., a small bar or background change) - initially hidden/inactive
    local selectionIndicator = Instance.new("Frame")
    selectionIndicator.Name = "SelectionIndicator"
    selectionIndicator.BackgroundColor3 = Theme.Accent
    selectionIndicator.BorderSizePixel = 0
    selectionIndicator.Size = UDim2.new(0.05, 0, 1, 0) -- Small bar on the left
    selectionIndicator.Position = UDim2.fromScale(0, 0)
    selectionIndicator.Visible = false -- Toggle visibility on select
    selectionIndicator.ZIndex = button.ZIndex + 2
    selectionIndicator.Parent = button

    return button, { Icon = icon, Title = title, HoverFrame = hoverFrame, SelectionIndicator = selectionIndicator }
end


-- Section Template (Container for elements)
ComponentTemplates.Section = function(props)
    local section = Instance.new("Frame")
    section.Name = props.Name or "Section"
    section.BackgroundTransparency = 1
    section.Size = UDim2.new(1, 0, 0, 0) -- Auto Y size
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.ZIndex = Theme.BaseZIndex + 1

    local border = ComponentTemplates.BaseFrame({
        Name = "Border",
        BackgroundColor3 = Theme.BackgroundSecondary,
        CornerRadius = Theme.SmallCornerRadius,
        DropShadow = true,
        ShadowSizeOffset = Vector2.new(25, 25), -- Smaller shadow for sections
        ZIndex = section.ZIndex
    })
    border.Parent = section

    local sectionTitle = ComponentTemplates.BaseLabel({
        Name = "SectionTitle",
        Text = props.Title or "Section",
        Font = Theme.FontBold,
        TextColor3 = Theme.TextTertiary,
        TextSize = Theme.SmallTextSize, -- Smaller title for sections
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 20), -- Fixed height title area
        Position = UDim2.new(0, 0, 0, -10), -- Position above content area
        ZIndex = border.ZIndex + 1
    })
    sectionTitle.Parent = border -- Parent to border, position adjusted

    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "Content"
    contentFrame.BackgroundTransparency = 1
    contentFrame.Size = UDim2.new(1, 0, 1, -20) -- Fill space below title (adjust Y offset if title size changes)
    contentFrame.Position = UDim2.new(0, 0, 0, 20) -- Position below title
    contentFrame.AutomaticSize = Enum.AutomaticSize.Y
    contentFrame.ClipsDescendants = true -- Clip content within section
    contentFrame.Parent = border
    local contentPadding = Instance.new("UIPadding")
    contentPadding.Padding = UDim.new(0, 8) -- Padding for elements inside
    contentPadding.Parent = contentFrame
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Padding = UDim.new(0, 10) -- Spacing between elements
    contentLayout.Parent = contentFrame

    -- Connect layout size changes to update section size (might need debounce)
    local function updateSectionHeight()
        -- This might fire too rapidly, consider debouncing if performance issues arise
         section.Parent = section.Parent -- Force redraw if needed? Or just rely on AutomaticSize Y.
         -- AutomaticSize should handle this, but manual update might be needed in some cases.
    end
    --contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateSectionHeight) -- Connect AFTER initial parenting

    return section, { TitleLabel = sectionTitle, ContentFrame = contentFrame, Layout = contentLayout }
end

-- Element Base Template (Container for label + control)
ComponentTemplates.ElementBase = function(props)
    local base = Instance.new("Frame")
    base.Name = props.Name or "ElementBase"
    base.BackgroundTransparency = 1
    base.Size = UDim2.new(1, 0, 0, 30) -- Default height for elements
    base.ZIndex = Theme.BaseZIndex + 2

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = base

    local labelFrame = Instance.new("Frame")
    labelFrame.Name = "LabelFrame"
    labelFrame.BackgroundTransparency = 1
    labelFrame.Size = UDim2.fromScale(0.4, 1) -- Default 40% width for label
    labelFrame.Parent = base

    local titleLabel = ComponentTemplates.BaseLabel({
        Name = "Title", Text = props.Title or "Element",
        TextColor3 = Theme.TextSecondary, TextSize = Theme.TextSize,
        Size = UDim2.new(1, -5, 0.5, 0), -- Allow space for desc
        Position = UDim2.fromScale(0, 0.25),
        TextXAlignment = Enum.TextXAlignment.Left,
        AnchorPoint = Vector2.new(0, 0.5)
    })
    titleLabel.Parent = labelFrame

    local descLabel = ComponentTemplates.BaseLabel({
        Name = "Description", Text = props.Description or "",
        TextColor3 = Theme.TextTertiary, TextSize = Theme.SmallTextSize,
        Size = UDim2.new(1, -5, 0.5, 0),
        Position = UDim2.fromScale(0, 0.75),
        TextXAlignment = Enum.TextXAlignment.Left,
        AnchorPoint = Vector2.new(0, 0.5),
        Visible = (props.Description ~= nil and props.Description ~= "")
    })
    descLabel.Parent = labelFrame

    -- If no description, make title fill height
    if not descLabel.Visible then
        titleLabel.Size = UDim2.new(1, -5, 1, 0)
        titleLabel.Position = UDim2.fromScale(0, 0.5)
    end

    local controlFrame = Instance.new("Frame")
    controlFrame.Name = "ControlFrame"
    controlFrame.BackgroundTransparency = 1
    controlFrame.Size = UDim2.fromScale(0.6, 1) -- Default 60% width for control
    controlFrame.Parent = base
    local controlLayout = Instance.new("UIListLayout") -- Layout for multiple controls if needed
    controlLayout.FillDirection = Enum.FillDirection.Horizontal
    controlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right -- Align controls to right
    controlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    controlLayout.Padding = UDim.new(0, 5)
    controlLayout.Parent = controlFrame

    return base, { LabelFrame=labelFrame, TitleLabel=titleLabel, DescLabel=descLabel, ControlFrame=controlFrame, Layout=layout }
end

-- Button Element Template
ComponentTemplates.Button = function(props)
    local button = Instance.new("TextButton")
    button.Name = props.Name or "Button"
    button.Text = props.ButtonText or "Click Me"
    button.Font = Theme.FontSemibold
    button.TextColor3 = Theme.Text
    button.BackgroundColor3 = Theme.BackgroundTertiary
    button.BorderSizePixel = 0
    button.Size = UDim2.new(0, 100, 1, -4) -- Example fixed size, or scale
    button.ZIndex = Theme.BaseZIndex + 3
    button.AutoButtonColor = false

    local corner = Instance.new("UICorner")
    corner.CornerRadius = Theme.CornerRadius
    corner.Parent = button

    local hoverFrame = ComponentTemplates.HoverFrame({ ParentZIndex = button.ZIndex, CornerRadius = Theme.CornerRadius, HoverColor = Theme.AccentDark })
    hoverFrame.Parent = button

    return button, { HoverFrame = hoverFrame }
end

-- Checkbox Element Template
ComponentTemplates.Checkbox = function(props)
    local checkbox = Instance.new("ImageButton")
    checkbox.Name = props.Name or "Checkbox"
    checkbox.BackgroundColor3 = Theme.BackgroundTertiary
    checkbox.BorderSizePixel = 0
    checkbox.Size = UDim2.new(0, 20, 0, 20) -- Square size
    checkbox.ZIndex = Theme.BaseZIndex + 3
    checkbox.AutoButtonColor = false

    local corner = Instance.new("UICorner")
    corner.CornerRadius = Theme.SmallCornerRadius
    corner.Parent = checkbox

    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = 1.0
    aspect.Parent = checkbox

    local selection = Instance.new("Frame") -- Visual indicator (check mark or fill)
    selection.Name = "Selection"
    selection.BackgroundColor3 = Theme.Accent
    selection.BorderSizePixel = 0
    selection.Size = UDim2.fromScale(0.8, 0.8) -- Slightly smaller than box
    selection.Position = UDim2.fromScale(0.5, 0.5)
    selection.AnchorPoint = Vector2.new(0.5, 0.5)
    selection.BackgroundTransparency = 1 -- Start hidden
    selection.ZIndex = checkbox.ZIndex + 1
    selection.Parent = checkbox
    local selCorner = Instance.new("UICorner")
    selCorner.CornerRadius = Theme.SmallCornerRadius * 0.5 -- Smaller radius for inner part
    selCorner.Parent = selection
    -- Optional: Add Checkmark image inside 'selection' instead of just color fill

    local hoverFrame = ComponentTemplates.HoverFrame({ ParentZIndex = checkbox.ZIndex, CornerRadius = Theme.SmallCornerRadius, HoverColor = Theme.BackgroundTertiary })
    hoverFrame.Name = "HoverOverlay" -- Renamed to avoid conflict if needed
    hoverFrame.Parent = checkbox

    return checkbox, { Selection = selection, HoverOverlay = hoverFrame }
end

-- Toggle Element Template
ComponentTemplates.Toggle = function(props)
    local toggle = Instance.new("ImageButton")
    toggle.Name = props.Name or "Toggle"
    toggle.BackgroundColor3 = Theme.BackgroundTertiary -- Off color
    toggle.BorderSizePixel = 0
    toggle.Size = UDim2.new(0, 40, 0, 20) -- Rectangular toggle
    toggle.ZIndex = Theme.BaseZIndex + 3
    toggle.AutoButtonColor = false

    local corner = Instance.new("UICorner")
    corner.CornerRadius = Theme.RoundCornerRadius -- Rounded ends
    corner.Parent = toggle

    local knob = Instance.new("Frame") -- The moving part
    knob.Name = "Knob"
    knob.BackgroundColor3 = Theme.Text -- White knob
    knob.BorderSizePixel = 0
    knob.Size = UDim2.new(0, 16, 0, 16) -- Square knob, slightly smaller than height
    knob.Position = UDim2.new(0, 2, 0.5, 0) -- Start left (Off position)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.ZIndex = toggle.ZIndex + 1
    knob.Parent = toggle
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = Theme.RoundCornerRadius -- Fully rounded knob
    knobCorner.Parent = knob

    local hoverFrame = ComponentTemplates.HoverFrame({ ParentZIndex = toggle.ZIndex, CornerRadius = Theme.RoundCornerRadius, HoverColor = Theme.BackgroundTertiary })
    hoverFrame.Name = "HoverOverlay"
    hoverFrame.Parent = toggle


    return toggle, { Knob = knob, HoverOverlay = hoverFrame }
end

-- Textbox Element Template
ComponentTemplates.Textbox = function(props)
    local textbox = Instance.new("TextBox")
    textbox.Name = props.Name or "Textbox"
    textbox.Font = Theme.Font
    textbox.Text = props.DefaultText or ""
    textbox.PlaceholderText = props.PlaceholderText or "Enter text..."
    textbox.TextColor3 = Theme.TextSecondary
    textbox.PlaceholderColor3 = Theme.TextTertiary
    textbox.BackgroundColor3 = Theme.BackgroundTertiary
    textbox.BorderSizePixel = 0
    textbox.Size = UDim2.new(1, -10, 1, -4) -- Fill most of the control area
    textbox.ZIndex = Theme.BaseZIndex + 3
    textbox.ClearTextOnFocus = props.ClearTextOnFocus or false
    textbox.TextXAlignment = Enum.TextXAlignment.Left

    local corner = Instance.new("UICorner")
    corner.CornerRadius = Theme.CornerRadius
    corner.Parent = textbox

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 5)
    padding.PaddingRight = UDim.new(0, 5)
    padding.Parent = textbox

    return textbox, {} -- No extra parts needed currently
end

-- Keybind Element Template
ComponentTemplates.Keybind = function(props)
    local keybindButton = Instance.new("TextButton")
    keybindButton.Name = props.Name or "Keybind"
    keybindButton.Text = props.DefaultKeybind or "..." -- Display current keybind or "..."
    keybindButton.Font = Theme.FontSemibold
    keybindButton.TextColor3 = Theme.TextSecondary
    keybindButton.BackgroundColor3 = Theme.BackgroundTertiary
    keybindButton.BorderSizePixel = 0
    keybindButton.Size = UDim2.new(0, 60, 1, -4) -- Fixed size? Or scale?
    keybindButton.ZIndex = Theme.BaseZIndex + 3
    keybindButton.AutoButtonColor = false

    local corner = Instance.new("UICorner")
    corner.CornerRadius = Theme.CornerRadius
    corner.Parent = keybindButton

    local hoverFrame = ComponentTemplates.HoverFrame({ ParentZIndex = keybindButton.ZIndex, CornerRadius = Theme.CornerRadius, HoverColor = Theme.AccentDark })
    hoverFrame.Parent = keybindButton

    return keybindButton, { HoverFrame = hoverFrame }
end

-- Slider Element Template
ComponentTemplates.Slider = function(props)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Name = props.Name or "SliderFrame"
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Size = UDim2.fromScale(1, 1) -- Fill control area height
    sliderFrame.ZIndex = Theme.BaseZIndex + 3

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 5)
    layout.Parent = sliderFrame

    -- Track background
    local track = Instance.new("Frame")
    track.Name = "Track"
    track.BackgroundColor3 = Theme.BackgroundTertiary
    track.BorderSizePixel = 0
    track.Size = UDim2.new(0.7, 0, 0, 6) -- Scaled width, fixed thin height
    track.ZIndex = sliderFrame.ZIndex
    track.Parent = sliderFrame
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = Theme.RoundCornerRadius
    trackCorner.Parent = track

    -- Filled part of the track
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0, 0, 1, 0) -- Width controlled by value, starts at 0
    fill.ZIndex = sliderFrame.ZIndex + 1
    fill.Parent = track
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = Theme.RoundCornerRadius
    fillCorner.Parent = fill

    -- Value display (TextBox)
    local valueBox = ComponentTemplates.Textbox({
        Name = "ValueBox",
        DefaultText = tostring(props.Min or 0),
        PlaceholderText = "",
        Size = UDim2.new(0.25, 0, 0.8, 0), -- Smaller size for value display
        ClearTextOnFocus = true
    })
    valueBox.TextSize = Theme.SmallTextSize
    valueBox.TextXAlignment = Enum.TextXAlignment.Center
    valueBox.LayoutOrder = 2 -- Place after track
    valueBox.Parent = sliderFrame

    -- Draggable Knob (optional, can just use track click) - simplified here
    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.BackgroundColor3 = Theme.Text
    knob.BorderSizePixel = 0
    knob.Size = UDim2.new(0, 12, 0, 12) -- Small knob
    knob.Position = UDim2.new(0, 0, 0.5, 0) -- Position controlled by value
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.ZIndex = sliderFrame.ZIndex + 2
    knob.Parent = fill -- Parent to fill to move with it easily
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = Theme.RoundCornerRadius
    knobCorner.Parent = knob


    return sliderFrame, { Track = track, Fill = fill, ValueBox = valueBox, Knob = knob }
end

-- Dropdown Element Template
ComponentTemplates.Dropdown = function(props)
    local dropdownFrame = Instance.new("Frame")
    dropdownFrame.Name = props.Name or "DropdownFrame"
    dropdownFrame.BackgroundTransparency = 1
    dropdownFrame.Size = UDim2.new(1, 0, 0, 30) -- Fixed height for main display
    dropdownFrame.ZIndex = Theme.BaseZIndex + 3

    -- Main display button (shows current selection)
    local mainButton = Instance.new("TextButton")
    mainButton.Name = "MainButton"
    mainButton.Text = props.DefaultText or "Select..."
    mainButton.Font = Theme.Font
    mainButton.TextColor3 = Theme.TextSecondary
    mainButton.BackgroundColor3 = Theme.BackgroundTertiary
    mainButton.BorderSizePixel = 0
    mainButton.Size = UDim2.fromScale(1, 1)
    mainButton.TextXAlignment = Enum.TextXAlignment.Left
    mainButton.ZIndex = dropdownFrame.ZIndex
    mainButton.AutoButtonColor = false
    mainButton.Parent = dropdownFrame
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = Theme.CornerRadius
    mainCorner.Parent = mainButton
    local mainPadding = Instance.new("UIPadding")
    mainPadding.PaddingLeft = UDim.new(0, 8)
    mainPadding.PaddingRight = UDim.new(0, 25) -- Make space for arrow
    mainPadding.Parent = mainButton

    -- Dropdown Arrow Icon
    local arrowIcon = Instance.new("ImageLabel")
    arrowIcon.Name = "ArrowIcon"
    arrowIcon.Image = Theme.DropdownArrowImage
    arrowIcon.ImageColor3 = Theme.TextTertiary
    arrowIcon.BackgroundTransparency = 1
    arrowIcon.Size = UDim2.new(0, 12, 0, 12)
    arrowIcon.Position = UDim2.new(1, -18, 0.5, 0) -- Positioned on the right
    arrowIcon.AnchorPoint = Vector2.new(1, 0.5)
    arrowIcon.ZIndex = mainButton.ZIndex + 1
    arrowIcon.Parent = mainButton

    -- Options Frame (ScrollingFrame, initially hidden and 0 size)
    local optionsFrame = Instance.new("ScrollingFrame")
    optionsFrame.Name = "OptionsFrame"
    optionsFrame.BackgroundColor3 = Theme.BackgroundTertiary
    optionsFrame.BorderSizePixel = 1 -- Or use shadow
    optionsFrame.BorderColor3 = Theme.Divider
    optionsFrame.Size = UDim2.new(1, 0, 0, 0) -- Starts closed
    optionsFrame.Position = UDim2.new(0, 0, 1, 2) -- Position below main button
    optionsFrame.Visible = false -- Start hidden
    optionsFrame.ClipsDescendants = true
    optionsFrame.ZIndex = Theme.PopupZIndex -- Appear above other elements
    optionsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    optionsFrame.CanvasSize = UDim2.fromScale(0, 0)
    optionsFrame.ScrollBarThickness = 4
    optionsFrame.Parent = dropdownFrame -- Parent to base frame
    local optsCorner = Instance.new("UICorner")
    optsCorner.CornerRadius = Theme.CornerRadius
    optsCorner.Parent = optionsFrame
    local optsLayout = Instance.new("UIListLayout")
    optsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    optsLayout.Parent = optionsFrame

    return dropdownFrame, { MainButton = mainButton, ArrowIcon = arrowIcon, OptionsFrame = optionsFrame, OptionsLayout = optsLayout }
end

-- ColorPicker Element Template (Button part)
ComponentTemplates.ColorPickerButton = function(props)
    local pickerButton = Instance.new("Frame") -- Frame container
    pickerButton.Name = props.Name or "ColorPickerButton"
    pickerButton.BackgroundTransparency = 1
    pickerButton.Size = UDim2.new(1, 0, 1, 0) -- Fill available space
    pickerButton.ZIndex = Theme.BaseZIndex + 3

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right -- Align to right
    layout.Padding = UDim.new(0, 5)
    layout.Parent = pickerButton

    -- Text display (optional, could show hex/rgb)
    local colorLabel = ComponentTemplates.BaseLabel({
        Name = "ColorLabel", Text = props.DefaultText or "#FFFFFF",
        Font = Theme.Font, TextSize = Theme.SmallTextSize,
        TextColor3 = Theme.TextTertiary,
        Size = UDim2.new(0.6, 0, 0.8, 0), -- Example size
        TextXAlignment = Enum.TextXAlignment.Right,
        LayoutOrder = 2 -- Show after preview
    })
    colorLabel.Parent = pickerButton

    -- Color Preview Button
    local previewButton = Instance.new("ImageButton")
    previewButton.Name = "PreviewButton"
    previewButton.BackgroundColor3 = props.DefaultColor or Color3.new(1, 1, 1)
    previewButton.BorderSizePixel = 1
    previewButton.BorderColor3 = Theme.Divider
    previewButton.Size = UDim2.new(0, 20, 0, 20) -- Square preview
    previewButton.ZIndex = pickerButton.ZIndex
    previewButton.AutoButtonColor = false
    previewButton.LayoutOrder = 1 -- Show before label
    previewButton.Parent = pickerButton
    local prevCorner = Instance.new("UICorner")
    prevCorner.CornerRadius = Theme.SmallCornerRadius
    prevCorner.Parent = previewButton
    local prevAspect = Instance.new("UIAspectRatioConstraint")
    prevAspect.AspectRatio = 1.0
    prevAspect.Parent = previewButton

    local hoverFrame = ComponentTemplates.HoverFrame({ ParentZIndex = previewButton.ZIndex, CornerRadius = Theme.SmallCornerRadius, HoverColor = Theme.BackgroundTertiary })
    hoverFrame.Name = "HoverOverlay"
    hoverFrame.Parent = previewButton


    return pickerButton, { PreviewButton = previewButton, ColorLabel = colorLabel, HoverOverlay = hoverFrame }
end

-- Notification Template
ComponentTemplates.Notification = function(props)
    local notifFrame = Instance.new("Frame")
    notifFrame.Name = props.Name or "Notification"
    notifFrame.BackgroundColor3 = Theme.BackgroundSecondary
    notifFrame.Size = UDim2.new(1, 0, 0, 60) -- Auto height? Or fixed?
    notifFrame.Position = UDim2.new(1, 0, 0, 0) -- Start off-screen right
    notifFrame.ZIndex = Theme.PopupZIndex + 5 -- High ZIndex

    local corner = Instance.new("UICorner")
    corner.CornerRadius = Theme.SmallCornerRadius
    corner.Parent = notifFrame

    local shadow = CreateDropShadow(notifFrame.ZIndex)
    shadow.DropShadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Parent = notifFrame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 5)
    layout.Parent = notifFrame
    local padding = Instance.new("UIPadding")
    padding.Padding = UDim.new(0, 8)
    padding.Parent = notifFrame

    -- Text Content Frame
    local textFrame = Instance.new("Frame")
    textFrame.Name = "TextFrame"
    textFrame.BackgroundTransparency = 1
    textFrame.Size = UDim2.new(0.8, 0, 1, 0) -- Majority of space for text
    textFrame.LayoutOrder = 1
    textFrame.Parent = notifFrame
    local textLayout = Instance.new("UIListLayout")
    textLayout.SortOrder = Enum.SortOrder.LayoutOrder
    textLayout.Padding = UDim.new(0, 2)
    textLayout.Parent = textFrame

    local titleLabel = ComponentTemplates.BaseLabel({ Name = "Title", Text = props.Title or "Notification", Font = Theme.FontSemibold, TextColor3 = Theme.Text, TextSize = Theme.TextSize })
    titleLabel.Parent = textFrame
    local descLabel = ComponentTemplates.BaseLabel({ Name = "Description", Text = props.Description or "", Font = Theme.Font, TextColor3 = Theme.TextSecondary, TextSize = Theme.SmallTextSize })
    descLabel.Parent = textFrame

    -- Close Button Frame
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "ButtonFrame"
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.Size = UDim2.new(0.15, 0, 1, 0) -- Space for button(s)
    buttonFrame.LayoutOrder = 2
    buttonFrame.Parent = notifFrame

    local closeButton = Instance.new("ImageButton")
    closeButton.Name = "CloseButton"
    closeButton.Image = Theme.CrossImage
    closeButton.ImageColor3 = Theme.TextTertiary
    closeButton.BackgroundTransparency = 1
    closeButton.Size = UDim2.new(0, 16, 0, 16)
    closeButton.Position = UDim2.fromScale(0.5, 0.5)
    closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
    closeButton.ZIndex = notifFrame.ZIndex + 1
    closeButton.Parent = buttonFrame

    return notifFrame, { TitleLabel = titleLabel, DescLabel = descLabel, CloseButton = closeButton }
end

-- Prompt Template (similar to Notification, but with Accept/Decline)
ComponentTemplates.Prompt = function(props)
    -- Reuse Notification template structure
    local promptFrame, parts = ComponentTemplates.Notification(props)
    promptFrame.Name = props.Name or "Prompt"
    parts.TitleLabel.Text = props.Title or "Prompt"
    parts.DescLabel.Text = props.Description or "Please choose an option."

    -- Modify button area for Accept/Decline
    parts.CloseButton.Parent = nil -- Remove single close button
    local buttonFrame = promptFrame:FindFirstChild("ButtonFrame")
    buttonFrame.Size = UDim2.new(0.3, 0, 1, 0) -- Wider for two buttons
    local buttonLayout = Instance.new("UIListLayout")
    buttonLayout.FillDirection = Enum.FillDirection.Horizontal
    buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    buttonLayout.Padding = UDim.new(0, 8)
    buttonLayout.Parent = buttonFrame

    local acceptButton = Instance.new("ImageButton")
    acceptButton.Name = "AcceptButton"
    acceptButton.Image = Theme.CheckmarkImage
    acceptButton.ImageColor3 = Theme.Success
    acceptButton.BackgroundTransparency = 1
    acceptButton.Size = UDim2.new(0, 20, 0, 20)
    acceptButton.Parent = buttonFrame

    local declineButton = Instance.new("ImageButton")
    declineButton.Name = "DeclineButton"
    declineButton.Image = Theme.CrossImage
    declineButton.ImageColor3 = Theme.Error
    declineButton.BackgroundTransparency = 1
    declineButton.Size = UDim2.new(0, 20, 0, 20)
    declineButton.Parent = buttonFrame

    return promptFrame, { TitleLabel = parts.TitleLabel, DescLabel = parts.DescLabel, AcceptButton = acceptButton, DeclineButton = declineButton }
end

--========================================================================
-- // Object Generator Module
--========================================================================
local ObjectGenerator = {}
ObjectGenerator.Templates = ComponentTemplates -- Reference templates

-- Creates an instance by cloning a template and applying properties
function ObjectGenerator.Create(templateName, properties)
    local templateFunc = ObjectGenerator.Templates[templateName]
    if not templateFunc then
        warn("[EDEN 12 ObjectGenerator] Template not found:", templateName)
        return nil, nil
    end

    -- The template function should return the main GUI object and a table of its key parts
    local instance, parts = templateFunc(properties or {})

    -- Apply additional properties if provided (overrides defaults set by template)
    if properties then
        for prop, value in pairs(properties) do
            -- Avoid trying to set non-scriptable properties or the Parts table itself
            if prop ~= "Parts" and pcall(function() instance[prop] = value end) then
                 -- Successfully set property
            else
                -- Optional: Warn about properties that couldn't be set
                -- warn("[EDEN 12 ObjectGenerator] Could not set property", prop, "on", instance.Name)
            end
        end
    end

    return instance, parts -- Return the main instance and its parts table
end

--========================================================================
-- // Main UI Library Module
--========================================================================
local UILibrary = {}
UILibrary.__index = UILibrary -- For metatable methods

local WindowInstances = {} -- Keep track of created windows

-- Constructor for the Window
function UILibrary.New(gameName, userId, rank)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "Eden12_UI_" .. HttpService:GenerateGUID(false)
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    screenGui.Parent = RunService:IsStudio() and LocalPlayer:WaitForChild("PlayerGui") or CoreGui

    local windowInstance, windowParts = ObjectGenerator.Create("Window", {})
    windowInstance.Parent = screenGui

    local self = setmetatable({
        ScreenGui = screenGui,
        WindowInstance = windowInstance,
        WindowParts = windowParts, -- Store references to window parts
        GameName = gameName or "Unknown Game",
        UserID = userId or "Unknown User",
        Rank = rank or "User",
        CurrentCategory = nil, -- Reference to the *active* category button instance
        CurrentTabFrame = nil, -- Reference to the *active* content tab frame
        Categories = {}, -- Store category info { Name = { ButtonInstance, TabFrame, Sections = {} } }
        Connections = {}, -- Store connections for easy cleanup
        Theme = Theme -- Reference to the theme table
    }, UILibrary)

    -- Initial Setup
    windowParts.Watermark.Text = string.format(Theme.DefaultWatermark, self.UserID, self.GameName)
    windowParts.UserNameLabel.Text = self.UserID
    windowParts.UserRankLabel.Text = self.Rank

    -- Make window draggable (using the main background as the handle for simplicity)
    local dragDisconnect = Draggable.EnableDrag(windowParts.MainUI, windowParts.MainUI) -- Drag main frame
    table.insert(self.Connections, dragDisconnect) -- Store disconnect function

    WindowInstances[screenGui] = self -- Track this window instance

    -- Initial Setup
    local baseWatermarkFormat = self.Theme.DefaultWatermark .. " | " -- Add separator for time
    windowParts.Watermark.Text = string.format(baseWatermarkFormat, self.UserID, self.GameName) .. os.date(self.Theme.TimeFormat) -- Initial text with time
    windowParts.UserNameLabel.Text = self.UserID
    windowParts.UserRankLabel.Text = self.Rank

    -- Make window draggable
    local dragDisconnect = Draggable.EnableDrag(windowParts.MainUI, windowParts.MainUI)
    table.insert(self.Connections, dragDisconnect)


    -- Time Update Loop (Add this section) ------------------
    local timeUpdateInterval = self.Theme.TimeUpdateInterval
    local timeFormat = self.Theme.TimeFormat
    -- Format the base text ONCE
    local baseWatermarkText = string.format(baseWatermarkFormat, self.UserID, self.GameName)

    local function updateTime()
        -- Check if UI elements still exist before trying to update
        if not self.ScreenGui or not self.ScreenGui.Parent or not windowParts.Watermark or not windowParts.Watermark.Parent then
            return false -- Stop the loop if UI is destroyed
        end
        local currentTime = os.date(timeFormat)
        windowParts.Watermark.Text = baseWatermarkText .. currentTime
        return true -- Continue loop
    end

    -- Use task.spawn for the loop
    local timeUpdateThread = task.spawn(function()
        while true do
            local continue = updateTime()
            if not continue then break end -- Exit loop if updateTime returns false
            task.wait(timeUpdateInterval)
        end
    end)
    -- Store thread to potentially cancel later if needed (optional)
    -- table.insert(self.Connections, timeUpdateThread) -- task.cancel(thread) could be used

    ----------------------------------------------------------

    WindowInstances[screenGui] = self -- Track this window instance

    return self -- Return self as before
end

-- Destructor (Example - Add if needed for full cleanup)
function UILibrary:Destroy()
    -- Disconnect all stored connections
    for _, disconnectFunc in ipairs(self.Connections) do
        if type(disconnectFunc) == "function" then
            disconnectFunc()
        elseif typeof(disconnectFunc) == "RBXScriptConnection" then
             disconnectFunc:Disconnect() -- Handle direct connections too
        end
    end
    self.Connections = {} -- Clear connections table

    -- Remove ScreenGui
    if self.ScreenGui then
        WindowInstances[self.ScreenGui] = nil -- Untrack
        self.ScreenGui:Destroy()
    end

    -- Nullify references
    for k in pairs(self) do
        self[k] = nil
    end
    -- Make unusable after destroy
    setmetatable(self, nil)
end


-- Method to change the active category
function UILibrary:SelectCategory(categoryName)
    local categoryData = self.Categories[categoryName]
    if not categoryData or categoryData.ButtonInstance == self.CurrentCategory then
        return -- No change needed or category doesn't exist
    end

    -- Deactivate previous category
    if self.CurrentCategory then
        local oldCategoryData = self.Categories[self.CurrentCategory.Name]
        if oldCategoryData then
             -- Visual deselection (using parts table from category creation)
             oldCategoryData.Parts.Title.TextColor3 = self.Theme.TextDisabled
             oldCategoryData.Parts.Icon.ImageColor3 = self.Theme.TextDisabled
             oldCategoryData.Parts.SelectionIndicator.Visible = false
             -- Hide old tab content
             if self.CurrentTabFrame then
                  self.CurrentTabFrame.Visible = false
                  Effects.Slide(self.CurrentTabFrame, UDim2.fromScale(0, 1), self.Theme.DefaultTweenInfo.Time) -- Slide out
             end
        end
    end

    -- Activate new category
    -- Visual selection
    categoryData.Parts.Title.TextColor3 = self.Theme.Accent
    categoryData.Parts.Icon.ImageColor3 = self.Theme.Accent
    categoryData.Parts.SelectionIndicator.Visible = true
    -- Show new tab content
    categoryData.TabFrame.Visible = true
    Effects.Slide(categoryData.TabFrame, UDim2.fromScale(0, 0), self.Theme.DefaultTweenInfo.Time) -- Slide in

    -- Update state
    self.CurrentCategory = categoryData.ButtonInstance
    self.CurrentTabFrame = categoryData.TabFrame

end

-- Add a new category
function UILibrary:AddCategory(categoryName, icon)
    if self.Categories[categoryName] then
        warn("[EDEN 12 UI] Category already exists:", categoryName)
        return self.Categories[categoryName].API -- Return existing API object
    end

    local categoryButton, categoryParts = ObjectGenerator.Create("CategoryButton", {
        Name = categoryName,
        Title = categoryName,
        Icon = icon
    })
    categoryButton.LayoutOrder = Utils.GetLayoutOrder(self.WindowParts.CategoryList)
    categoryButton.Parent = self.WindowParts.CategoryList

    -- Create the corresponding content tab frame (initially hidden)
    local tabFrame = Instance.new("ScrollingFrame")
    tabFrame.Name = categoryName .. "_Tab"
    tabFrame.BackgroundTransparency = 1
    tabFrame.Size = UDim2.fromScale(1, 1)
    tabFrame.Position = UDim2.fromScale(0, 1) -- Start off-screen (bottom)
    tabFrame.Visible = false
    tabFrame.ClipsDescendants = true
    tabFrame.BorderSizePixel = 0
    tabFrame.ScrollBarThickness = 6
    tabFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabFrame.CanvasSize = UDim2.fromScale(0,0)
    tabFrame.Parent = self.WindowParts.ContentArea -- Parent to main content area
    local tabLayout = Instance.new("UIListLayout") -- Default layout for sections
    tabLayout.Padding = UDim.new(0, 15)
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.Parent = tabFrame
    local tabPadding = Instance.new("UIPadding")
    tabPadding.Padding = UDim.new(0, 10)
    tabPadding.Parent = tabFrame


    local categoryData = {
        Name = categoryName,
        ButtonInstance = categoryButton,
        Parts = categoryParts, -- Store parts for later access (like title, icon)
        TabFrame = tabFrame,
        Sections = {}, -- { SectionName = { Instance, ContentFrame, Layout } }
        API = nil -- Placeholder for the API object to be returned
    }

    local categoryAPI = {
        -- Method to add a section to this category
        AddSection = function(sectionName)
            if categoryData.Sections[sectionName] then
                 warn("[EDEN 12 UI] Section already exists in category", categoryName, ":", sectionName)
                 return categoryData.Sections[sectionName].API -- Return existing API object
            end

            local sectionInstance, sectionParts = ObjectGenerator.Create("Section", {
                 Name = sectionName,
                 Title = sectionName
            })
            sectionInstance.LayoutOrder = Utils.GetLayoutOrder(categoryData.TabFrame)
            sectionInstance.Parent = categoryData.TabFrame

            local sectionData = {
                 Instance = sectionInstance,
                 Parts = sectionParts,
                 Elements = {}, -- Store elements within this section
                 API = nil -- Placeholder
            }

            local sectionAPI = {
                 -- Methods to add elements (Button, Checkbox, etc.)
                 AddButton = function(elementName, settings, callback)
                     return self:_AddElement(categoryData, sectionData, "Button", elementName, settings, callback)
                 end,
                 AddCheckbox = function(elementName, settings, callback)
                     return self:_AddElement(categoryData, sectionData, "Checkbox", elementName, settings, callback)
                 end,
                 AddToggle = function(elementName, settings, callback)
                    return self:_AddElement(categoryData, sectionData, "Toggle", elementName, settings, callback)
                 end,
                 AddTextbox = function(elementName, settings, callback)
                     return self:_AddElement(categoryData, sectionData, "Textbox", elementName, settings, callback)
                 end,
                 AddKeybind = function(elementName, settings, callback)
                     return self:_AddElement(categoryData, sectionData, "Keybind", elementName, settings, callback)
                 end,
                 AddSlider = function(elementName, settings, callback)
                     return self:_AddElement(categoryData, sectionData, "Slider", elementName, settings, callback)
                 end,
                 AddDropdown = function(elementName, settings, callback)
                     return self:_AddElement(categoryData, sectionData, "Dropdown", elementName, settings, callback)
                 end,
                 AddColorPicker = function(elementName, settings, callback)
                     return self:_AddElement(categoryData, sectionData, "ColorPickerButton", elementName, settings, callback) -- Use ColorPickerButton template
                 end,
                 -- Add other element types here...
            }
            sectionData.API = sectionAPI
            categoryData.Sections[sectionName] = sectionData

            return sectionAPI
        end
    }
    categoryData.API = categoryAPI
    self.Categories[categoryName] = categoryData

    -- Connect category button click
    local clickConn = categoryButton.MouseButton1Click:Connect(function()
        self:SelectCategory(categoryName)
        Effects.CircleClick(categoryButton) -- Add circle click effect
    end)
    table.insert(self.Connections, clickConn) -- Track connection

    -- Add hover effects (simple transparency example)
    local hoverDisconnect = Effects.AddHoverTransparency(categoryParts.HoverFrame, "BackgroundTransparency", 0.7, 1.0)
    table.insert(self.Connections, hoverDisconnect)

    -- Select the first category added automatically
    if not self.CurrentCategory then
        self:SelectCategory(categoryName)
    end

    return categoryAPI -- Return the API object for this category
end

-- Internal helper to add elements to sections and manage state/callbacks
function UILibrary:_AddElement(categoryData, sectionData, elementType, elementName, settings, callback)
    settings = settings or {}
    callback = callback or function() end -- Ensure callback is a function

    if sectionData.Elements[elementName] then
        warn(string.format("[EDEN 12 UI] Element '%s' already exists in section '%s'", elementName, sectionData.Instance.Name))
        return sectionData.Elements[elementName].API
    end

    -- Create the base container for the element (Label + Control Area)
    local elementBase, baseParts = ObjectGenerator.Create("ElementBase", {
        Name = elementName .. "_Base",
        Title = settings.Title or elementName,
        Description = settings.Description
    })
    elementBase.LayoutOrder = Utils.GetLayoutOrder(sectionData.Parts.ContentFrame)
    elementBase.Parent = sectionData.Parts.ContentFrame

    -- Create the specific control element
    local controlInstance, controlParts = ObjectGenerator.Create(elementType, settings)
    if not controlInstance then
         warn(string.format("[EDEN 12 UI] Failed to create control instance for type '%s'", elementType))
         elementBase:Destroy() -- Clean up base if control fails
         return nil
    end
    controlInstance.Parent = baseParts.ControlFrame -- Add control to the right side

    local elementAPI = {} -- The public API for this specific element instance
    local elementConnections = {} -- Connections specific to this element

    -- === Element Specific Setup and API Methods ===
    if elementType == "Button" then
        controlInstance.Text = settings.ButtonText or "Button" -- Set button text
        local clickEvent, disconnect = Effects.AddClickFeedback(controlInstance, "BackgroundColor3", self.Theme.Accent, controlInstance.BackgroundColor3)
        local clickConn = clickEvent:Connect(callback)
        table.insert(elementConnections, disconnect)
        table.insert(elementConnections, clickConn)
        -- Add hover effect to the button's hover frame
        local hoverDisconnect = Effects.AddHoverTransparency(controlParts.HoverFrame, "BackgroundTransparency", 0.5, 1)
        table.insert(elementConnections, hoverDisconnect)
        -- No specific API methods needed for a simple button usually

    elseif elementType == "Checkbox" then
        local checked = settings.Default or false
        local function SetCheckedVisuals(state)
            local targetSize = state and UDim2.fromScale(0.8, 0.8) or UDim2.fromScale(0, 0) -- Animate size
            local targetTransparency = state and 0 or 1
            Effects.Fade(controlParts.Selection, state, self.Theme.FastTweenInfo.Time) -- Fade transparency
            -- Optional: Animate size (might need custom tween)
            TweenService:Create(controlParts.Selection, self.Theme.FastTweenInfo, { Size = targetSize }):Play()
        end
        SetCheckedVisuals(checked) -- Set initial visual state

        elementAPI.IsChecked = function() return checked end
        elementAPI.SetValue = function(value, suppressCallback)
            value = not not value -- Force boolean
            if checked ~= value then
                 checked = value
                 SetCheckedVisuals(checked)
                 if not suppressCallback then
                      callback(checked)
                 end
            end
        end

        local clickConn = controlInstance.MouseButton1Click:Connect(function()
            elementAPI.SetValue(not checked)
        end)
        table.insert(elementConnections, clickConn)
        local hoverDisconnect = Effects.AddHoverTransparency(controlParts.HoverOverlay, "BackgroundTransparency", 0.7, 1)
        table.insert(elementConnections, hoverDisconnect)

    elseif elementType == "Toggle" then
         local enabled = settings.Default or false
         local function SetToggleVisuals(state)
             local targetKnobPos = state and UDim2.new(1, -2 - controlParts.Knob.Size.X.Offset, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
             local targetBgColor = state and self.Theme.Accent or self.Theme.BackgroundTertiary
             TweenService:Create(controlParts.Knob, self.Theme.FastTweenInfo, { Position = targetKnobPos }):Play()
             TweenService:Create(controlInstance, self.Theme.FastTweenInfo, { BackgroundColor3 = targetBgColor }):Play()
         end
         SetToggleVisuals(enabled)

         elementAPI.IsEnabled = function() return enabled end
         elementAPI.SetValue = function(value, suppressCallback)
             value = not not value
             if enabled ~= value then
                  enabled = value
                  SetToggleVisuals(enabled)
                  if not suppressCallback then
                       callback(enabled)
                  end
             end
         end

         local clickConn = controlInstance.MouseButton1Click:Connect(function()
            elementAPI.SetValue(not enabled)
         end)
         table.insert(elementConnections, clickConn)
         local hoverDisconnect = Effects.AddHoverTransparency(controlParts.HoverOverlay, "BackgroundTransparency", 0.7, 1)
         table.insert(elementConnections, hoverDisconnect)

     elseif elementType == "Textbox" then
          controlInstance.Text = settings.Default or ""
          elementAPI.GetValue = function() return controlInstance.Text end
          elementAPI.SetValue = function(value, suppressCallback)
              value = tostring(value)
              if controlInstance.Text ~= value then
                   controlInstance.Text = value
                   if not suppressCallback then
                        callback(value)
                   end
              end
          end

          local focusConn = controlInstance.FocusLost:Connect(function(enterPressed)
              if enterPressed then
                  elementAPI.SetValue(controlInstance.Text) -- Trigger callback on enter
              else
                  -- Optionally trigger on focus lost regardless of enter, or only on enter
                  callback(controlInstance.Text) -- Trigger callback on focus lost
              end
              -- Visual feedback on focus lost (e.g., change background back)
              TweenService:Create(controlInstance, self.Theme.FastTweenInfo, { BackgroundColor3 = self.Theme.BackgroundTertiary }):Play()
          end)
          table.insert(elementConnections, focusConn)

          local focusGainConn = controlInstance.Focused:Connect(function()
              -- Visual feedback on focus gain
              TweenService:Create(controlInstance, self.Theme.FastTweenInfo, { BackgroundColor3 = self.Theme.AccentDark }):Play()
          end)
          table.insert(elementConnections, focusGainConn)

     elseif elementType == "Keybind" then
         local currentKey = settings.Default or Enum.KeyCode.Unknown -- Store KeyCode or UserInputType
         local isBinding = false
         local inputConn = nil -- Connection for listening

         local function SetKeybindText(key)
             if type(key) == "userdata" then -- Check if it's an Enum (KeyCode or UserInputType)
                 controlInstance.Text = key.Name
             else
                 controlInstance.Text = "..." -- Default/unset text
             end
         end
         SetKeybindText(currentKey)

         elementAPI.GetKey = function() return currentKey end
         elementAPI.SetValue = function(key, suppressCallback)
             if currentKey ~= key then
                  currentKey = key
                  SetKeybindText(currentKey)
                  if not suppressCallback then
                       -- Pass the key itself in the callback
                       callback(currentKey)
                  end
             end
         end

         local function StopBinding(newKey)
             if inputConn then inputConn:Disconnect() inputConn = nil end
             isBinding = false
             elementAPI.SetValue(newKey or Enum.KeyCode.Unknown) -- Set to Unknown if cancelled
             -- Restore visual state
             TweenService:Create(controlInstance, self.Theme.FastTweenInfo, { BackgroundColor3 = self.Theme.BackgroundTertiary}):Play()
             controlInstance.TextColor3 = self.Theme.TextSecondary
         end

         local clickConn = controlInstance.MouseButton1Click:Connect(function()
             if isBinding then
                 StopBinding(currentKey) -- Cancel binding if clicked again
                 return
             end
             isBinding = true
             controlInstance.Text = "..."
             -- Visual indication of binding state
             TweenService:Create(controlInstance, self.Theme.FastTweenInfo, { BackgroundColor3 = self.Theme.Accent }):Play()
             controlInstance.TextColor3 = self.Theme.Text

             inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                  if gameProcessed and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end -- Allow click to cancel

                  local newKey = Enum.KeyCode.Unknown
                  if input.UserInputType == Enum.UserInputType.Keyboard then
                       newKey = input.KeyCode
                  elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                       newKey = input.UserInputType -- Store MouseButton UserInputType
                  elseif input.UserInputType == Enum.UserInputType.Focus then
                       -- Ignore focus events often triggered by clicking textboxes etc.
                       return
                  end

                  if newKey ~= Enum.KeyCode.Unknown and newKey ~= Enum.KeyCode.Escape then -- Escape cancels
                      StopBinding(newKey)
                  elseif input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton1 then
                      StopBinding(currentKey) -- Cancel binding, restore old key
                  end
             end)
         end)
         table.insert(elementConnections, clickConn)
         local hoverDisconnect = Effects.AddHoverTransparency(controlParts.HoverFrame, "BackgroundTransparency", 0.7, 1)
         table.insert(elementConnections, hoverDisconnect)


    --[[ --- Add Setup & API for other elements (Slider, Dropdown, ColorPicker) below ---

    elseif elementType == "Slider" then
        -- Setup slider logic (min, max, default, dragging, value box input)
        -- elementAPI.GetValue, elementAPI.SetValue
        -- Connect drag events, ValueBox FocusLost

    elseif elementType == "Dropdown" then
        -- Setup dropdown logic (options, multi-select?, default selection)
        -- elementAPI.GetSelected, elementAPI.SetValue, elementAPI.SetOptions
        -- Connect MainButton click to toggle optionsFrame, connect option clicks

    elseif elementType == "ColorPickerButton" then
        -- Setup color picker logic (default color)
        -- elementAPI.GetColor, elementAPI.SetValue
        -- Connect PreviewButton click to open the main color picker overlay
        -- Need to implement the Color Picker Overlay logic separately (likely methods on the main window API)

    --]]

    end

    -- Store element data
    sectionData.Elements[elementName] = {
        Base = elementBase,
        Control = controlInstance,
        Parts = controlParts,
        API = elementAPI,
        Connections = elementConnections,
        Settings = settings, -- Store original settings if needed
        Callback = callback
    }

    -- Finalize base layout adjustments if needed
    task.wait() -- Allow UI layout to update
    baseParts.Layout:ApplyLayout() -- Ensure layout is correct

    return elementAPI
end

-- Public method to add a notification
function UILibrary:Notify(settings)
    settings = settings or {}
    local title = settings.Title or "Notification"
    local desc = settings.Description or ""
    local duration = settings.Duration or 5 -- Default 5 seconds

    local notifInstance, notifParts = ObjectGenerator.Create("Notification", {
        Name = "Notification_" .. HttpService:GenerateGUID(false),
        Title = title,
        Description = desc
    })
    notifInstance.LayoutOrder = Utils.GetLayoutOrder(self.WindowParts.NotificationArea)
    notifInstance.Parent = self.WindowParts.NotificationArea

    -- Animate In
    Effects.Slide(notifInstance, UDim2.new(0, 0, 0, 0), self.Theme.DefaultTweenInfo.Time) -- Slide in from right

    local connections = {}
    local expired = false

    local function expire()
        if expired then return end
        expired = true
        -- Disconnect handlers
        for _, conn in pairs(connections) do conn:Disconnect() end
        connections = {} -- Clear table

        -- Animate Out
        Effects.Slide(notifInstance, UDim2.new(1, 0, 0, 0), self.Theme.DefaultTweenInfo.Time, function()
            notifInstance:Destroy() -- Destroy after sliding out
        end)
    end

    -- Handle close button
    connections.CloseClick = notifParts.CloseButton.MouseButton1Click:Connect(expire)
    -- Optional: Add hover effect to close button

    -- Auto-expire timer
    if duration > 0 then
        connections.Timer = task.delay(duration, expire)
    end

    -- Optional: Pause timer on hover?
    -- connections.MouseEnter = notifInstance.MouseEnter:Connect(function() ... end)
    -- connections.MouseLeave = notifInstance.MouseLeave:Connect(function() ... end)

end

-- Public method to show a prompt
function UILibrary:Prompt(settings)
    settings = settings or {}
    local title = settings.Title or "Confirm"
    local desc = settings.Description or "Are you sure?"
    -- Prompt doesn't auto-expire typically

    local promptInstance, promptParts = ObjectGenerator.Create("Prompt", {
        Name = "Prompt_" .. HttpService:GenerateGUID(false),
        Title = title,
        Description = desc
    })
    promptInstance.LayoutOrder = Utils.GetLayoutOrder(self.WindowParts.NotificationArea)
    promptInstance.Parent = self.WindowParts.NotificationArea

    -- Use a BindableEvent to return the result asynchronously
    local resultEvent = Instance.new("BindableEvent")

    -- Animate In
    Effects.Slide(promptInstance, UDim2.new(0, 0, 0, 0), self.Theme.DefaultTweenInfo.Time)

    local connections = {}
    local closed = false

    local function closePrompt(result)
        if closed then return end
        closed = true
        -- Disconnect handlers
        for _, conn in pairs(connections) do conn:Disconnect() end
        connections = {}

        -- Animate Out
        Effects.Slide(promptInstance, UDim2.new(1, 0, 0, 0), self.Theme.DefaultTweenInfo.Time, function()
             promptInstance:Destroy()
             resultEvent:Fire(result) -- Fire event with the result (true for accept, false for decline)
             resultEvent:Destroy() -- Clean up event
        end)
    end

    -- Handle buttons
    connections.AcceptClick = promptParts.AcceptButton.MouseButton1Click:Connect(function() closePrompt(true) end)
    connections.DeclineClick = promptParts.DeclineButton.MouseButton1Click:Connect(function() closePrompt(false) end)
    -- Optional: Add hover effects to buttons

    -- Return the event that will fire with the result
    return resultEvent.Event
end


return UILibrary
