local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Mouse = LocalPlayer:GetMouse() -- Note: GetMouse() is legacy, UserInputService is preferred for positions.
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
	if IconName and Icons[IconName] ~= nil then
		return Icons[IconName]
	else
		return nil
	end
end

local Orion = Instance.new("ScreenGui")
Orion.Name = "Orion"
Orion.ResetOnSpawn = false
Orion.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if syn then
	pcall(syn.protect_gui, Orion) -- Use pcall for safety
	Orion.Parent = game:GetService("CoreGui")
else
	Orion.Parent = gethui and gethui() or game:GetService("CoreGui")
end

-- Cleanup duplicate GUIs more robustly
local parentService = gethui and gethui() or game:GetService("CoreGui")
if parentService then
	for _, Interface in ipairs(parentService:GetChildren()) do
		if Interface:IsA("ScreenGui") and Interface.Name == Orion.Name and Interface ~= Orion then
            warn("OrionLib: Destroying duplicate UI instance.")
			Interface:Destroy()
		end
	end
end

function OrionLib:IsRunning()
	local currentParent = Orion and Orion.Parent
    if not currentParent then return false end
	local expectedParent = gethui and gethui() or game:GetService("CoreGui")
    return currentParent == expectedParent
end

local function AddConnection(Signal, Function)
	if not Signal or not Signal:IsA("RBXScriptSignal") then
		warn("OrionLib AddConnection: Invalid Signal provided.")
		return { Disconnect = function() end }
	end
	if not OrionLib:IsRunning() then
		return { Disconnect = function() end }
	end
	local safeFunc = function(...)
        local success, err = pcall(Function, ...)
        if not success then warn("OrionLib Connection Error:", err) end
    end
    local SignalConnect = Signal:Connect(safeFunc)
	table.insert(OrionLib.Connections, SignalConnect)
	return SignalConnect
end

task.spawn(function()
	while OrionLib:IsRunning() do
		task.wait(1)
	end
    print("OrionLib: Main GUI parent lost or changed. Disconnecting signals.")
	for i = #OrionLib.Connections, 1, -1 do -- Iterate backwards for safe removal
		local Connection = OrionLib.Connections[i]
		if Connection and typeof(Connection.Disconnect) == "function" then
			pcall(Connection.Disconnect)
		end
		table.remove(OrionLib.Connections, i)
	end
end)

--[[ Revised MakeDraggable: Using direct position update on RenderStepped ]]
local function MakeDraggable(DragPoint, Main)
	pcall(function()
        DragPoint.Active = true -- Ensure the drag handle is interactable
		local Dragging = false
		local MouseStartPos = Vector2.new(0, 0)
        local FrameStartPos = UDim2.new(0, 0, 0, 0)
        local DragConnection = nil
		local InputChangedConnection = nil

		AddConnection(DragPoint.InputBegan, function(Input)
			if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) and Dragging == false then
				if UserInputService:GetFocusedTextBox() then UserInputService:GetFocusedTextBox():ReleaseFocus(false) end

				Dragging = true
				MouseStartPos = Input.Position
				FrameStartPos = Main.Position

				-- Disconnect previous connections if they exist
				if DragConnection then DragConnection:Disconnect(); DragConnection = nil end
				if InputChangedConnection then InputChangedConnection:Disconnect(); InputChangedConnection = nil end

                -- Connect to RenderStepped *only* while dragging
                DragConnection = RunService.RenderStepped:Connect(function()
					-- No need for 'if Dragging' check here as it's disconnected on InputEnded
					local CurrentMousePos = UserInputService:GetMouseLocation()
					local Delta = CurrentMousePos - MouseStartPos
					Main.Position = UDim2.new(FrameStartPos.X.Scale, FrameStartPos.X.Offset + Delta.X, FrameStartPos.Y.Scale, FrameStartPos.Y.Offset + Delta.Y)
				end)

				-- Handle drag end separately using the InputObject.Changed event
				InputChangedConnection = Input.Changed:Connect(function()
					if Input.UserInputState == Enum.UserInputState.End then
						Dragging = false
						-- Disconnect RenderStepped connection
						if DragConnection then DragConnection:Disconnect(); DragConnection = nil end
						-- Disconnect self
						if InputChangedConnection then InputChangedConnection:Disconnect(); InputChangedConnection = nil end
					end
				end)
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
	for Property, Value in pairs(Props) do
        pcall(function() Element[Property] = Value end)
	end
	return Element
end

local function SetChildren(Element, Children)
	for _, Child in ipairs(Children) do
		Child.Parent = Element
	end
	return Element
end

local function Round(Number, Factor)
    if Factor == 0 then return Number end
	local Result = math.floor(Number/Factor + 0.5) * Factor
	return Result
end

local function ReturnProperty(Object)
	if Object:IsA("Frame") or Object:IsA("TextButton") or Object:IsA("ImageButton") then return "BackgroundColor3" end
	if Object:IsA("ScrollingFrame") then return "ScrollBarImageColor3" end
	if Object:IsA("UIStroke") then return "Color" end
	if Object:IsA("TextLabel") or Object:IsA("TextBox") then return "TextColor3" end
	if Object:IsA("ImageLabel") then return "ImageColor3" end
	return nil
end

local function AddThemeObject(Object, Type)
	if not OrionLib.ThemeObjects[Type] then OrionLib.ThemeObjects[Type] = {} end
	table.insert(OrionLib.ThemeObjects[Type], Object)
    local prop = ReturnProperty(Object)
    local themeColor = OrionLib.Themes[OrionLib.SelectedTheme][Type]
    if prop and themeColor then Object[prop] = themeColor end
	return Object
end

local function SetTheme()
	local selectedThemeData = OrionLib.Themes[OrionLib.SelectedTheme]
	for Name, Type in pairs(OrionLib.ThemeObjects) do
		local themeColor = selectedThemeData[Name]
		if themeColor then
			for i = #Type, 1, -1 do
                local Object = Type[i]
				if Object and Object.Parent then
                    local prop = ReturnProperty(Object)
                    if prop then Object[prop] = themeColor end
                else table.remove(Type, i) end
			end
		end
	end
end

local function PackColor(Color)
	return {R = math.floor(Color.R * 255 + 0.5), G = math.floor(Color.G * 255 + 0.5), B = math.floor(Color.B * 255 + 0.5)}
end

local function UnpackColor(Color)
    if type(Color) == "table" and Color.R and Color.G and Color.B then
	    return Color3.fromRGB(Color.R, Color.G, Color.B)
    else
        warn("OrionLib UnpackColor: Invalid color data provided.")
        return Color3.fromRGB(255, 255, 255) -- Return white as fallback
    end
end

local function LoadCfg(Config)
    pcall(function()
	    local Data = HttpService:JSONDecode(Config)
	    for a, b in pairs(Data) do
		    if OrionLib.Flags[a] then
			    task.spawn(function()
                    local flagObj = OrionLib.Flags[a]
                    if flagObj and flagObj.Set then
                        local valueToSet = b
                        local skipCallback = true -- Always skip callback on load
                        if flagObj.Type == "Colorpicker" then
                            valueToSet = UnpackColor(b)
                        elseif flagObj.Type == "Bind" then
                            local enumType = Enum.KeyCode
                            if type(b) == "string" and string.find(b, "MouseButton") then enumType = Enum.UserInputType end
                            local success, enumValue = pcall(function() return enumType[b] end)
                            if success and enumValue then valueToSet = enumValue else valueToSet = Enum.KeyCode.None end
                        end
                        pcall(flagObj.Set, flagObj, valueToSet, skipCallback)
                    else warn("Orion Library Config Loader - Flag object invalid or missing Set method:", a) end
			    end)
		    else warn("Orion Library Config Loader - Could not find flag: ", a) end
	    end
    end)
end

local function SaveCfg(Name)
    if not OrionLib.SaveCfg then return end
    pcall(function()
	    local Data = {}
	    for i, v in pairs(OrionLib.Flags) do
		    if v and v.Save then
                local valueToSave = v.Value
                if v.Type == "Colorpicker" then
				    Data[i] = PackColor(valueToSave)
                elseif v.Type == "Bind" and typeof(valueToSave) == "EnumItem" then
                    Data[i] = valueToSave.Name
			    else Data[i] = valueToSave end
		    end
	    end
        local configFileName = OrionLib.Folder .. "/" .. Name .. ".txt"
	    writefile(configFileName, HttpService:JSONEncode(Data))
    end)
end

-- Standard hover/click colors
local function GetHoverColor(baseColor) return baseColor:Lerp(Color3.new(1, 1, 1), 0.1) end
local function GetClickColor(baseColor) return baseColor:Lerp(Color3.new(1, 1, 1), 0.2) end

-- Standard tween info
local TWEEN_INFO_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TWEEN_INFO_NORMAL = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TWEEN_INFO_SLOW = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local WhitelistedMouse = {Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2,Enum.UserInputType.MouseButton3}
local BlacklistedKeys = {Enum.KeyCode.Unknown, Enum.KeyCode.Slash, Enum.KeyCode.Tab, Enum.KeyCode.Backspace, Enum.KeyCode.Escape}

local function CheckKey(Table, Key)
	for _, v in ipairs(Table) do if v == Key then return true end end
	return false
end

-- Element Creation Functions (Ensure Active=true for buttons/inputs) --
CreateElement("Corner", function(Scale, Offset) return Create("UICorner", {CornerRadius = UDim.new(Scale or 0, Offset or 6)}) end)
CreateElement("Stroke", function(Color, Thickness) return Create("UIStroke", {Color = Color or Color3.fromRGB(255, 255, 255), Thickness = Thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}) end)
CreateElement("List", function(Scale, Offset) return Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(Scale or 0, Offset or 0)}) end)
CreateElement("Padding", function(Bottom, Left, Right, Top) return Create("UIPadding", {PaddingBottom = UDim.new(0, Bottom or 4), PaddingLeft = UDim.new(0, Left or 4), PaddingRight = UDim.new(0, Right or 4), PaddingTop = UDim.new(0, Top or 4)}) end)
CreateElement("TFrame", function() return Create("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0}) end)
CreateElement("Frame", function(Color) return Create("Frame", {BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255), BorderSizePixel = 0}) end)
CreateElement("RoundFrame", function(Color, Scale, Offset) return Create("Frame", {BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255), BorderSizePixel = 0}, {Create("UICorner", {CornerRadius = UDim.new(Scale or 0, Offset or 6)})}) end)
CreateElement("Button", function() return Create("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Active = true}) end)
CreateElement("ScrollFrame", function(Color, Width) return Create("ScrollingFrame", {BackgroundTransparency = 1, ScrollBarImageColor3 = Color or Color3.fromRGB(60, 60, 60), BorderSizePixel = 0, ScrollBarThickness = Width or 6, CanvasSize = UDim2.new(0, 0, 0, 0), ScrollingDirection = Enum.ScrollingDirection.Y, VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, HorizontalScrollBarInset = Enum.ScrollBarInset.None, Active = true}) end)
CreateElement("Image", function(ImageID) local i=Create("ImageLabel", {Image = ImageID or "", BackgroundTransparency = 1}); if ImageID and GetIcon(ImageID) then i.Image = GetIcon(ImageID) end; return i end)
CreateElement("ImageButton", function(ImageID) local i=Create("ImageButton", {Image = ImageID or "", BackgroundTransparency = 1, AutoButtonColor = false, Active = true}); if ImageID and GetIcon(ImageID) then i.Image = GetIcon(ImageID) end; return i end)
CreateElement("Label", function(Text, TextSize, Transparency) return Create("TextLabel", {Text = Text or "", TextColor3 = Color3.fromRGB(240, 240, 240), TextTransparency = Transparency or 0, TextSize = TextSize or 14, Font = Enum.Font.GothamSemibold, RichText = true, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left}) end)

-- Notification Holder (Unchanged)
local NotificationHolder = SetProps(SetChildren(MakeElement("TFrame"), {SetProps(MakeElement("List"), {HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8)})}), {Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0, 300, 1, -10), AnchorPoint = Vector2.new(1, 0), Parent = Orion})

-- MakeNotification (Unchanged)
function OrionLib:MakeNotification(NotificationConfig) spawn(function() NotificationConfig.Name = NotificationConfig.Name or "Notification"; NotificationConfig.Content = NotificationConfig.Content or "Test"; NotificationConfig.Image = NotificationConfig.Image or "rbxassetid://4384403532"; NotificationConfig.Time = NotificationConfig.Time or 5; local nt=OrionLib.Themes[OrionLib.SelectedTheme]; local np=SetProps(MakeElement("TFrame"),{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,Parent=NotificationHolder,ClipsDescendants=true,LayoutOrder=tick()}); local nf=SetChildren(SetProps(MakeElement("RoundFrame",nt.Main,0,8),{Parent=np,Size=UDim2.new(1,0,0,0),Position=UDim2.new(1,10,0,0),BackgroundTransparency=0.1,AutomaticSize=Enum.AutomaticSize.Y}),{MakeElement("Stroke",nt.Stroke,1),MakeElement("Padding",10,10,10,10),SetProps(MakeElement("Image",NotificationConfig.Image),{Size=UDim2.new(0,20,0,20),ImageColor3=nt.Text,Name="Icon",LayoutOrder=1}),SetProps(MakeElement("Label","<b>"..NotificationConfig.Name.."</b>",15),{Size=UDim2.new(1,-30,0,20),Position=UDim2.new(0,30,0,0),Font=Enum.Font.GothamBold,Name="Title",TextColor3=nt.Text,LayoutOrder=2}),SetProps(MakeElement("Label",NotificationConfig.Content,14),{Size=UDim2.new(1,0,0,0),Position=UDim2.new(0,0,0,25),Font=Enum.Font.GothamSemibold,Name="Content",AutomaticSize=Enum.AutomaticSize.Y,TextColor3=nt.TextDark,TextWrapped=true,LayoutOrder=3})});TweenService:Create(nf,TWEEN_INFO_NORMAL,{Position=UDim2.new(0,0,0,0),BackgroundTransparency=0.1}):Play();task.wait(NotificationConfig.Time);local fo=TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out);TweenService:Create(nf,fo,{Position=UDim2.new(-1,-10,0,0),BackgroundTransparency=1}):Play();local cfo=TweenInfo.new(0.3,Enum.EasingStyle.Quint,Enum.EasingDirection.Out);TweenService:Create(nf.Icon,cfo,{ImageTransparency=1}):Play();TweenService:Create(nf.Title,cfo,{TextTransparency=1}):Play();TweenService:Create(nf.Content,cfo,{TextTransparency=1}):Play();local s=nf:FindFirstChildOfClass("UIStroke");if s then TweenService:Create(s,cfo,{Transparency=1}):Play()end;task.wait(0.5);if np and np.Parent then np:Destroy()end end) end

-- Init (Unchanged)
function OrionLib:Init() if OrionLib.SaveCfg then pcall(function() local cf=OrionLib.Folder.."/"..game.GameId..".txt";if isfile(cf)then LoadCfg(readfile(cf));OrionLib:MakeNotification({Name="Configuration Loaded",Content="Loaded config for game "..game.GameId..".",Time=4})end end)end end

-- ## MakeWindow ## --
function OrionLib:MakeWindow(WindowConfig)
	local FirstTab = true; local Minimized = false; local Loaded = false; local UIHidden = false; local CurrentTab = nil
	WindowConfig=WindowConfig or{};WindowConfig.Name=WindowConfig.Name or"Orion Library";WindowConfig.ConfigFolder=WindowConfig.ConfigFolder or WindowConfig.Name;WindowConfig.SaveConfig=WindowConfig.SaveConfig or false;WindowConfig.HidePremium=WindowConfig.HidePremium or false;if WindowConfig.IntroEnabled==nil then WindowConfig.IntroEnabled=true end;WindowConfig.IntroText=WindowConfig.IntroText or"Orion Library";WindowConfig.CloseCallback=WindowConfig.CloseCallback or function()end;WindowConfig.ShowIcon=WindowConfig.ShowIcon or false;WindowConfig.Icon=WindowConfig.Icon or"rbxassetid://8834748103";WindowConfig.IntroIcon=WindowConfig.IntroIcon or"rbxassetid://8834748103";OrionLib.Folder=WindowConfig.ConfigFolder;OrionLib.SaveCfg=WindowConfig.SaveConfig;if WindowConfig.SaveConfig then if not isfolder(WindowConfig.ConfigFolder)then makefolder(WindowConfig.ConfigFolder)end end;local wt=OrionLib.Themes[OrionLib.SelectedTheme];local th=AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame",wt.Divider,4),{Size=UDim2.new(1,0,1,-50),Position=UDim2.new(0,0,0,0),BackgroundTransparency=1}),{MakeElement("List",0,4),MakeElement("Padding",8,8,8,8)}),"Divider");AddConnection(th.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"),function()local l=th.UIListLayout;local p=th.UIPadding;if l and p then th.CanvasSize=UDim2.new(0,0,0,l.AbsoluteContentSize.Y+p.PaddingTop.Offset+p.PaddingBottom.Offset)end end);local bcf=AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",wt.Second,0,7),{Size=UDim2.new(0,70,0,30),Position=UDim2.new(1,-80,0,10),Name="ButtonControls",ZIndex=5}),{AddThemeObject(MakeElement("Stroke"),"Stroke"),AddThemeObject(SetProps(MakeElement("Frame"),{Size=UDim2.new(0,1,1,-10),Position=UDim2.new(0.5,0,0,5),AnchorPoint=Vector2.new(0.5,0)}),"Stroke"),SetChildren(SetProps(MakeElement("ImageButton"),{Size=UDim2.new(0.5,-1,1,0),Position=UDim2.new(0,0,0,0),Name="MinimizeButton",BackgroundTransparency=1}),{AddThemeObject(SetProps(MakeElement("Image","rbxassetid://7072719338"),{Position=UDim2.new(0.5,0,0.5,0),AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.new(0,16,0,16),Name="Ico",BackgroundTransparency=1}),"Text")}),SetChildren(SetProps(MakeElement("ImageButton"),{Size=UDim2.new(0.5,-1,1,0),Position=UDim2.new(0.5,1,0,0),Name="CloseButton",BackgroundTransparency=1}),{AddThemeObject(SetProps(MakeElement("Image","rbxassetid://7072725342"),{Position=UDim2.new(0.5,0,0.5,0),AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.new(0,16,0,16),BackgroundTransparency=1}),"Text")})}),"Second");local cb=bcf.CloseButton;local mb=bcf.MinimizeButton;local dp=SetProps(MakeElement("TFrame"),{Size=UDim2.new(1,0,0,50),ZIndex=2});local ws=AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",wt.Second,0,8),{Size=UDim2.new(0,150,1,-50),Position=UDim2.new(0,0,0,50)}),{AddThemeObject(SetProps(MakeElement("Frame"),{Size=UDim2.new(0,1,1,0),Position=UDim2.new(1,-1,0,0)}),"Stroke"),th,SetChildren(SetProps(MakeElement("TFrame"),{Size=UDim2.new(1,0,0,50),Position=UDim2.new(0,0,1,-50)}),{AddThemeObject(SetProps(MakeElement("Frame"),{Size=UDim2.new(1,0,0,1)}),"Stroke"),AddThemeObject(SetChildren(SetProps(MakeElement("Frame"),{AnchorPoint=Vector2.new(0,0.5),Size=UDim2.new(0,32,0,32),Position=UDim2.new(0,10,0.5,0),BackgroundTransparency=1}),{SetProps(MakeElement("Image","https://www.roblox.com/headshot-thumbnail/image?userId="..LocalPlayer.UserId.."&width=420&height=420&format=png"),{Size=UDim2.new(1,0,1,0),ZIndex=2}),AddThemeObject(SetProps(MakeElement("Image","rbxassetid://4031889928"),{Size=UDim2.new(1,0,1,0),ImageTransparency=0.5,ZIndex=1}),"Second"),MakeElement("Corner",1,0)}),"Divider"),AddThemeObject(SetProps(MakeElement("Label","<b>"..LocalPlayer.DisplayName.."</b>",WindowConfig.HidePremium and 14 or 13),{Size=UDim2.new(1,-55,0,13),Position=WindowConfig.HidePremium and UDim2.new(0,50,0.5,-7)or UDim2.new(0,50,0,12),AnchorPoint=WindowConfig.HidePremium and Vector2.new(0,0.5)or Vector2.new(0,0),Font=Enum.Font.GothamBold,ClipsDescendants=true}),"Text"),AddThemeObject(SetProps(MakeElement("Label","@"..LocalPlayer.Name,12),{Size=UDim2.new(1,-60,0,12),Position=UDim2.new(0,50,1,-18),AnchorPoint=Vector2.new(0,1),Visible=not WindowConfig.HidePremium,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left}),"TextDark")})}),"Second");local wn=AddThemeObject(SetProps(MakeElement("Label",WindowConfig.Name,20),{Size=UDim2.new(1,-30,1,0),Position=UDim2.new(0,WindowConfig.ShowIcon and 50 or 15,0,0),Font=Enum.Font.GothamBlack,TextYAlignment=Enum.TextYAlignment.Center,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=1}),"Text");local wtl=AddThemeObject(SetProps(MakeElement("Frame"),{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),ZIndex=3}),"Stroke");local tf=SetChildren(SetProps(MakeElement("TFrame"),{Size=UDim2.new(1,0,0,50),Name="TopBar"}),{wn,wtl,bcf,dp});local mw=AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",wt.Main,0,10),{Parent=Orion,Position=UDim2.new(0.5,0,0.5,0),AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.new(0,615,0,344),ClipsDescendants=true,Active=true}),{tf,ws}),"Main");if WindowConfig.ShowIcon then local wi=SetProps(MakeElement("Image",WindowConfig.Icon),{Size=UDim2.new(0,24,0,24),Position=UDim2.new(0,15,0.5,0),AnchorPoint=Vector2.new(0,0.5),ZIndex=2});wi.Parent=tf end;MakeDraggable(dp,mw);local function stb(b,pf)b.Active=true;local bc=wt.Second;local hc=GetHoverColor(bc);local cc=GetClickColor(bc);AddConnection(b.MouseEnter,function()TweenService:Create(pf,TWEEN_INFO_FAST,{BackgroundColor3=hc}):Play()end);AddConnection(b.MouseLeave,function()TweenService:Create(pf,TWEEN_INFO_FAST,{BackgroundColor3=bc}):Play()end);AddConnection(b.MouseButton1Down,function()TweenService:Create(pf,TWEEN_INFO_FAST,{BackgroundColor3=cc}):Play()end);AddConnection(b.MouseButton1Up,function()local mp=UserInputService:GetMouseLocation();local bp,bs=b.AbsolutePosition,b.AbsoluteSize;if mp.X>=bp.X and mp.X<=bp.X+bs.X and mp.Y>=bp.Y and mp.Y<=bp.Y+bs.Y then TweenService:Create(pf,TWEEN_INFO_FAST,{BackgroundColor3=hc}):Play()else TweenService:Create(pf,TWEEN_INFO_FAST,{BackgroundColor3=bc}):Play()end end)end;stb(cb,bcf);stb(mb,bcf);AddConnection(cb.Activated,function()if mw then local ct=TweenService:Create(mw,TWEEN_INFO_NORMAL,{Size=mw.Size*Vector2.new(0.9,0.9),Transparency=1});ct:Play();ct.Completed:Wait();if mw then mw.Visible=false;mw.Size=UDim2.new(0,615,0,344);mw.Transparency=0;UIHidden=true;OrionLib:MakeNotification({Name="Interface Hidden",Content="Press RightShift to reopen.",Time=4});pcall(WindowConfig.CloseCallback)end else warn("OrionLib: MainWindow not found during CloseBtn Activated.")end end);AddConnection(UserInputService.InputBegan,function(i,gp)if gp then return end;if i.KeyCode==Enum.KeyCode.RightShift then if UIHidden then UIHidden=false;if mw then mw.Visible=true;mw.Size=UDim2.new(0,615,0,344)*0.9;mw.Transparency=1;TweenService:Create(mw,TWEEN_INFO_NORMAL,{Size=UDim2.new(0,615,0,344),Transparency=0}):Play()end end end end);AddConnection(mb.Activated,function()local mi=mb:FindFirstChild("Ico");if not mi then warn("OrionLib: Minimize button icon not found.");return end;local ts;local tc;local ttlv;local twsv;local ti;if Minimized then ts=UDim2.new(0,615,0,344);ti="rbxassetid://7072719338";tc=false;ttlv=true;twsv=true else local minW=wn.TextBounds.X+(WindowConfig.ShowIcon and 50 or 15)+90;ts=UDim2.new(0,math.max(200,minW),0,50);ti="rbxassetid://7072720870";tc=true;ttlv=false;twsv=false end;Minimized=not Minimized;if not Minimized then if mw then mw.ClipsDescendants=tc;ws.Visible=twsv;wtl.Visible=ttlv end end;if mw then TweenService:Create(mw,TWEEN_INFO_SLOW,{Size=ts}):Play()end;mi.Image=ti;task.delay(Minimized and 0 or 0.1,function()if Minimized then if mw then mw.ClipsDescendants=tc end end;if ws then ws.Visible=twsv end;if wtl then wtl.Visible=ttlv end end)end);local function ls()if not WindowConfig.IntroEnabled then if mw then mw.Visible=true end;OrionLib:Init();return end;if mw then mw.Visible=false end;local it=OrionLib.Themes[OrionLib.SelectedTheme];local lsl=SetProps(MakeElement("Image",WindowConfig.IntroIcon),{Parent=Orion,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.45,0),Size=UDim2.new(0,48,0,48),ImageColor3=it.Text,ImageTransparency=1,Rotation=-15});local lst=SetProps(MakeElement("Label",WindowConfig.IntroText,16),{Parent=Orion,Size=UDim2.new(1,0,0,30),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.55,20),TextXAlignment=Enum.TextXAlignment.Center,Font=Enum.Font.GothamBold,TextTransparency=1,TextColor3=it.TextDark});TweenService:Create(lsl,TweenInfo.new(0.6,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{ImageTransparency=0,Position=UDim2.new(0.5,0,0.5,-10),Rotation=0}):Play();task.wait(0.4);TweenService:Create(lst,TweenInfo.new(0.5,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency=0,Position=UDim2.new(0.5,0,0.5,20)}):Play();task.wait(1.5);local fot=TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.In);TweenService:Create(lsl,fot,{ImageTransparency=1,Position=UDim2.new(0.5,0,0.45,0)}):Play();TweenService:Create(lst,fot,{TextTransparency=1,Position=UDim2.new(0.5,0,0.55,40)}):Play();task.wait(0.4);if mw then mw.Visible=true;mw.Size=UDim2.new(0,615,0,344)*0.9;mw.Transparency=1;TweenService:Create(mw,TWEEN_INFO_NORMAL,{Size=UDim2.new(0,615,0,344),Transparency=0}):Play()end;OrionLib:Init();if lsl and lsl.Parent then lsl:Destroy()end;if lst and lst.Parent then lst:Destroy()end end;ls();local tfu={};function tfu:MakeTab(tc)tc=tc or{};tc.Name=tc.Name or"Tab";tc.Icon=tc.Icon or"rbxassetid://5107100128";tc.PremiumOnly=tc.PremiumOnly or false;local tt=OrionLib.Themes[OrionLib.SelectedTheme];local is=false;local tct=AddThemeObject(SetProps(MakeElement("RoundFrame",tt.Second,0,6),{Size=UDim2.new(1,0,0,35),Parent=th,BackgroundTransparency=1}),"Second");local tfr=SetChildren(SetProps(MakeElement("Button"),{Size=UDim2.new(1,0,1,0),Parent=tct,BackgroundTransparency=1,Active=true}),{AddThemeObject(SetProps(MakeElement("Image",tc.Icon),{AnchorPoint=Vector2.new(0,0.5),Size=UDim2.new(0,18,0,18),Position=UDim2.new(0,12,0.5,0),ImageTransparency=0.6,Name="Ico"}),"Text"),AddThemeObject(SetProps(MakeElement("Label",tc.Name,14),{Size=UDim2.new(1,-35,1,0),Position=UDim2.new(0,40,0,0),Font=Enum.Font.GothamSemibold,TextTransparency=0.6,Name="Title",TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center}),"Text")});if GetIcon(tc.Icon)then tfr.Ico.Image=GetIcon(tc.Icon)end;local con=AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame",wt.Divider,5),{Size=UDim2.new(1,-150,1,-50),Position=UDim2.new(0,150,0,50),Parent=mw,Visible=false,BackgroundTransparency=1,Name="ItemContainer",Active=true}),{MakeElement("List",0,8),MakeElement("Padding",15,15,15,15)}),"Divider");AddConnection(con.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"),function()local l=con.UIListLayout;local p=con.UIPadding;if l and p then con.CanvasSize=UDim2.new(0,0,0,l.AbsoluteContentSize.Y+p.PaddingTop.Offset+p.PaddingBottom.Offset)end end);local function ss(s)is=s;local ti=s and 0 or 0.6;local tt=s and 0 or 0.6;local tf=s and Enum.Font.GothamBlack or Enum.Font.GothamSemibold;local tb=s and 0 or 1;if tfr and tfr.Parent then tfr.Title.Font=tf;TweenService:Create(tfr.Ico,TWEEN_INFO_NORMAL,{ImageTransparency=ti}):Play();TweenService:Create(tfr.Title,TWEEN_INFO_NORMAL,{TextTransparency=tt}):Play()end;if tct and tct.Parent then TweenService:Create(tct,TWEEN_INFO_NORMAL,{BackgroundTransparency=tb}):Play()end;if con and con.Parent then con.Visible=s end end;if FirstTab then FirstTab=false;ss(true);CurrentTab={Frame=tfr,Container=tct,SetSelected=ss}end;local btc=tt.Second;local htc=GetHoverColor(btc);local ctc=GetClickColor(btc);AddConnection(tfr.MouseEnter,function()if not is then TweenService:Create(tct,TWEEN_INFO_FAST,{BackgroundTransparency=0.8}):Play();TweenService:Create(tfr.Ico,TWEEN_INFO_FAST,{ImageTransparency=0.4}):Play();TweenService:Create(tfr.Title,TWEEN_INFO_FAST,{TextTransparency=0.4}):Play()end end);AddConnection(tfr.MouseLeave,function()if not is then TweenService:Create(tct,TWEEN_INFO_FAST,{BackgroundTransparency=1}):Play();TweenService:Create(tfr.Ico,TWEEN_INFO_FAST,{ImageTransparency=0.6}):Play();TweenService:Create(tfr.Title,TWEEN_INFO_FAST,{TextTransparency=0.6}):Play()end end);AddConnection(tfr.MouseButton1Down,function()if not is then TweenService:Create(tct,TWEEN_INFO_FAST,{BackgroundColor3=ctc,BackgroundTransparency=0.7}):Play()end end);AddConnection(tfr.Activated,function()if is then return end;if CurrentTab and CurrentTab.SetSelected then CurrentTab.SetSelected(false)end;ss(true);CurrentTab={Frame=tfr,Container=tct,SetSelected=ss}end);local function ge(ip)local et=OrionLib.Themes[OrionLib.SelectedTheme];local ef={};local function see(ef,co)if co and typeof(co)=="Instance"and co:IsA("GuiButton")then co.Active=true end;ef.Active=true;local bc=et.Second;local hc=GetHoverColor(bc);local cc=GetClickColor(bc);AddConnection(co.MouseEnter,function()TweenService:Create(ef,TWEEN_INFO_FAST,{BackgroundColor3=hc}):Play()end);AddConnection(co.MouseLeave,function()TweenService:Create(ef,TWEEN_INFO_FAST,{BackgroundColor3=bc}):Play()end);AddConnection(co.MouseButton1Down,function()TweenService:Create(ef,TWEEN_INFO_FAST,{BackgroundColor3=cc}):Play()end);AddConnection(co.MouseButton1Up,function()local mp=UserInputService:GetMouseLocation();local fp,fs=ef.AbsolutePosition,ef.AbsoluteSize;if mp.X>=fp.X and mp.X<=fp.X+fs.X and mp.Y>=fp.Y and mp.Y<=fp.Y+fs.Y then TweenService:Create(ef,TWEEN_INFO_FAST,{BackgroundColor3=hc}):Play()else TweenService:Create(ef,TWEEN_INFO_FAST,{BackgroundColor3=bc}):Play()end end)end;function ef:AddLabel(t)local lf=AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",et.Second,0,5),{Size=UDim2.new(1,0,0,30),BackgroundTransparency=0.7,Parent=ip}),{AddThemeObject(SetProps(MakeElement("Label",t,14),{Size=UDim2.new(1,-24,1,0),Position=UDim2.new(0,12,0,0),Font=Enum.Font.GothamBold,Name="Content",TextYAlignment=Enum.TextYAlignment.Center}),"Text"),AddThemeObject(MakeElement("Stroke"),"Stroke")}),"Second");local lfu={};function lfu:Set(tc)if lf and lf.Parent then lf.Content.Text=tc end end;return lfu end;function ef:AddParagraph(t,c)t=t or"Paragraph Title";c=c or"Paragraph content goes here.";local pf=AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",et.Second,0,5),{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=0.7,Parent=ip}),{MakeElement("Padding",8,12,12,10),AddThemeObject(SetProps(MakeElement("Label","<b>"..t.."</b>",14),{Size=UDim2.new(1,0,0,18),Font=Enum.Font.GothamBold,Name="Title",LayoutOrder=1}),"Text"),AddThemeObject(SetProps(MakeElement("Label",c,13),{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,Font=Enum.Font.Gotham,Name="Content",TextWrapped=true,LayoutOrder=2}),"TextDark"),AddThemeObject(MakeElement("Stroke"),"Stroke"),MakeElement("List",0,4)}),"Second");local pfu={};function pfu:Set(tc)if pf and pf.Parent then pf.Content.Text=tc end end;return pfu end;function ef:AddButton(bc)bc=bc or{};bc.Name=bc.Name or"Button";bc.Callback=bc.Callback or function()print("Button Clicked:",bc.Name)end;bc.Icon=bc.Icon;local b={};local cl=SetProps(MakeElement("Button"),{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Active=true});local hi=bc.Icon~=nil and bc.Icon~="";local bf=AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",et.Second,0,5),{Size=UDim2.new(1,0,0,35),Parent=ip,Active=true}),{AddThemeObject(SetProps(MakeElement("Label",bc.Name,14),{Size=UDim2.new(1,hi and-42 or-24,1,0),Position=UDim2.new(0,12,0,0),Font=Enum.Font.GothamBold,Name="Content",TextYAlignment=Enum.TextYAlignment.Center}),"Text"),(hi and AddThemeObject(SetProps(MakeElement("Image",bc.Icon),{Size=UDim2.new(0,18,0,18),Position=UDim2.new(1,-30,0.5,0),AnchorPoint=Vector2.new(1,0.5),Name="Ico"}),"TextDark")or nil),AddThemeObject(MakeElement("Stroke"),"Stroke"),cl}),"Second");see(bf,cl);AddConnection(cl.Activated,function()local os=bf.Size;TweenService:Create(bf,TweenInfo.new(0.1,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=os*0.98}):Play();task.wait(0.1);TweenService:Create(bf,TWEEN_INFO_FAST,{Size=os}):Play();task.spawn(bc.Callback);SaveCfg(game.GameId)end);function b:Set(bt)if bf and bf.Parent then bf.Content.Text=bt end end;return b end;function ef:AddToggle(tc)tc=tc or{};tc.Name=tc.Name or"Toggle";tc.Default=tc.Default or false;tc.Callback=tc.Callback or function(v)print("Toggle:",tc.Name,v)end;tc.Color=tc.Color or Color3.fromRGB(40,167,69);tc.Flag=tc.Flag or nil;tc.Save=tc.Save or true;local t={Value=tc.Default,Save=tc.Save,Type="Toggle"};local cl=SetProps(MakeElement("Button"),{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Active=true});local tco=tc.Color;local tcf=et.Divider;local tb=SetChildren(SetProps(MakeElement("RoundFrame",tcf,0.5,0),{Size=UDim2.new(0,20,0,20),Position=UDim2.new(1,-30,0.5,0),AnchorPoint=Vector2.new(0.5,0.5),Name="ToggleIndicator",BorderSizePixel=0}),{SetProps(MakeElement("Stroke"),{Color=tcf,Name="Stroke",Transparency=0}),SetProps(MakeElement("Image","rbxassetid://3944680095"),{Size=UDim2.fromScale(0.7,0.7),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),ImageColor3=Color3.fromRGB(255,255,255),Name="Ico",ImageTransparency=1}),MakeElement("UIAspectRatioConstraint",{AspectRatio=1})});local tf=AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",et.Second,0,5),{Size=UDim2.new(1,0,0,38),Parent=ip,Active=true}),{AddThemeObject(SetProps(MakeElement("Label",tc.Name,14),{Size=UDim2.new(1,-50,1,0),Position=UDim2.new(0,12,0,0),Font=Enum.Font.GothamBold,Name="Content",TextYAlignment=Enum.TextYAlignment.Center}),"Text"),AddThemeObject(MakeElement("Stroke"),"Stroke"),tb,cl}),"Second");see(tf,cl);function t:Set(v,sc)if not tb or not tb.Parent then return end;t.Value=v;local bg=t.Value and tco or tcf;local st=t.Value and tco or et.Stroke;local it=t.Value and 0 or 1;local is=t.Value and UDim2.fromScale(0.7,0.7)or UDim2.fromScale(0.4,0.4);TweenService:Create(tb,TWEEN_INFO_NORMAL,{BackgroundColor3=bg}):Play();TweenService:Create(tb.Stroke,TWEEN_INFO_NORMAL,{Color=st}):Play();TweenService:Create(tb.Ico,TWEEN_INFO_NORMAL,{ImageTransparency=it,Size=is}):Play();if not sc then task.spawn(tc.Callback,t.Value)end end;t:Set(t.Value,true);AddConnection(cl.Activated,function()t:Set(not t.Value);if t.Save then SaveCfg(game.GameId)end end);if tc.Flag then OrionLib.Flags[tc.Flag]=t end;return t end;function ef:AddSlider(sc)sc=sc or{};sc.Name=sc.Name or"Slider";sc.Min=sc.Min or 0;sc.Max=sc.Max or 100;sc.Increment=sc.Increment or 1;sc.Default=sc.Default or sc.Min;sc.Callback=sc.Callback or function(v)print("Slider:",sc.Name,v)end;sc.ValueName=sc.ValueName or"";sc.Color=sc.Color or Color3.fromRGB(0,123,255);sc.Flag=sc.Flag or nil;sc.Save=sc.Save or true;local s={Value=sc.Default,Save=sc.Save,Type="Slider"};local dr=false;local slc=sc.Color;local sbc=et.Divider;local vl=AddThemeObject(SetProps(MakeElement("Label","",12),{Size=UDim2.new(0,50,0,14),Position=UDim2.new(1,-12,0,10),AnchorPoint=Vector2.new(1,0),Font=Enum.Font.GothamBold,Name="ValueLabel",TextXAlignment=Enum.TextXAlignment.Right,BackgroundTransparency=1}),"TextDark");local sd=SetChildren(SetProps(MakeElement("RoundFrame",slc,0,4),{Size=UDim2.new(0,0,1,0),BackgroundTransparency=0,ClipsDescendants=true,BorderSizePixel=0}),{});local sb=SetChildren(SetProps(MakeElement("RoundFrame",sbc,0,4),{Size=UDim2.new(1,-24,0,10),Position=UDim2.new(0,12,1,-18),AnchorPoint=Vector2.new(0,1),BackgroundTransparency=0,ClipsDescendants=true,BorderSizePixel=0,Active=true}),{sd});local sf=AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",et.Second,0,5),{Size=UDim2.new(1,0,0,55),Parent=ip,Active=true}),{AddThemeObject(SetProps(MakeElement("Label",sc.Name,14),{Size=UDim2.new(1,-70,0,14),Position=UDim2.new(0,12,0,10),Font=Enum.Font.GothamBold,Name="Content"}),"Text"),vl,AddThemeObject(MakeElement("Stroke"),"Stroke"),sb}),"Second");local function us(v,sk)if not sd or not sd.Parent then return end;local cv=math.clamp(Round(v,sc.Increment),sc.Min,sc.Max);if s.Value==cv and not sk then return end;s.Value=cv;local p=(cv-sc.Min)/(sc.Max-sc.Min);if sc.Max==sc.Min then p=1 end;TweenService:Create(sd,TWEEN_INFO_FAST,{Size=UDim2.fromScale(p,1)}):Play();vl.Text=tostring(cv)..(sc.ValueName~=""and(" "..sc.ValueName)or"");if not sk then task.spawn(sc.Callback,s.Value)end end;local ic=nil;AddConnection(sb.InputBegan,function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dr=true;local p=i.Position;local rx=math.clamp(p.X-sb.AbsolutePosition.X,0,sb.AbsoluteSize.X);local pc=rx/sb.AbsoluteSize.X;local nv=sc.Min+(sc.Max-sc.Min)*pc;us(nv);if ic then ic:Disconnect()end;ic=AddConnection(UserInputService.InputChanged,function(ci)if dr and(ci.UserInputType==Enum.UserInputType.MouseMovement or ci.UserInputType==Enum.UserInputType.Touch)then local cp=ci.Position;local crx=math.clamp(cp.X-sb.AbsolutePosition.X,0,sb.AbsoluteSize.X);local cpc=crx/sb.AbsoluteSize.X;local cnu=sc.Min+(sc.Max-sc.Min)*cpc;us(cnu)end end)end end);AddConnection(sb.InputEnded,function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then if dr then dr=false;if ic then ic:Disconnect();ic=nil end;if s.Save then SaveCfg(game.GameId)end end end end);function s:Set(v,sk)us(v,sk)end;s:Set(s.Value,true);if sc.Flag then OrionLib.Flags[sc.Flag]=s end;return s end;function ef:AddDropdown(dc)dc=dc or{};dc.Name=dc.Name or"Dropdown";dc.Options=dc.Options or{};dc.Default=dc.Default or"";dc.Callback=dc.Callback or function(v)print("Dropdown:",dc.Name,v)end;dc.Flag=dc.Flag or nil;dc.Save=dc.Save or true;dc.MaxHeight=dc.MaxHeight or 150;local d={Value=dc.Default,Options=dc.Options,Buttons={},Toggled=false,Type="Dropdown",Save=dc.Save};if #d.Options>0 and not table.find(d.Options,d.Value)then d.Value=dc.Options[1]elseif #d.Options==0 then d.Value="No Options"end;local dl=MakeElement("List",0,2);local dc=AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame",et.Divider,4),{dl}),{Position=UDim2.new(0,0,1,1),Size=UDim2.new(1,0,0,0),ClipsDescendants=true,BackgroundTransparency=0,BorderSizePixel=0,Visible=false,ZIndex=3,Active=true}),"Second");local df=AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",et.Second,0,5),{Size=UDim2.new(1,0,0,38),Parent=ip,ClipsDescendants=true,ZIndex=2,Active=true}),{dc,SetProps(SetChildren(MakeElement("TFrame"),{AddThemeObject(SetProps(MakeElement("Label",dc.Name,14),{Size=UDim2.new(1,-100,1,0),Position=UDim2.new(0,12,0,0),Font=Enum.Font.GothamBold,Name="Content",TextYAlignment=Enum.TextYAlignment.Center}),"Text"),AddThemeObject(SetProps(MakeElement("Image","rbxassetid://7072706796"),{Size=UDim2.new(0,16,0,16),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),ImageColor3=et.TextDark,Name="Ico",Rotation=0}),"TextDark"),AddThemeObject(SetProps(MakeElement("Label",d.Value,13),{Size=UDim2.new(1,-50,1,0),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-35,0.5,0),Font=Enum.Font.Gotham,Name="Selected",TextXAlignment=Enum.TextXAlignment.Right,TextYAlignment=Enum.TextYAlignment.Center}),"TextDark"),AddThemeObject(SetProps(MakeElement("Frame"),{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,0),Name="Line",Visible=false}),"Stroke"),SetProps(MakeElement("Button"),{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Name="Click",Active=true})}),{Size=UDim2.new(1,0,1,0),ClipsDescendants=true,Name="F"}),AddThemeObject(MakeElement("Stroke"),"Stroke")}),"Second");local cl=df.F.Click;dc.Parent=df;AddConnection(dl:GetPropertyChangedSignal("AbsoluteContentSize"),function()local h=dl.AbsoluteContentSize.Y;dc.CanvasSize=UDim2.new(0,0,0,h)end);local obc=et.Second;local ohc=GetHoverColor(obc);local occ=GetClickColor(obc);local osc=GetClickColor(occ);local function ao(o)for _,b in pairs(d.Buttons)do if b and b.Parent then b:Destroy()end end;d.Buttons={};for i,op in ipairs(o)do local ob=AddThemeObject(SetProps(SetChildren(MakeElement("Button"),{AddThemeObject(SetProps(MakeElement("Label",op,13),{Position=UDim2.new(0,8,0,0),Size=UDim2.new(1,-16,1,0),Name="Title",TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextTransparency=0}),"Text")}),{Parent=dc,Size=UDim2.new(1,0,0,30),BackgroundTransparency=1,ClipsDescendants=true,AutoButtonColor=false,LayoutOrder=i,Active=true}),"Divider");local is=op==d.Value;ob.BackgroundTransparency=is and 0 or 1;ob.BackgroundColor3=is and osc or obc;ob.Title.TextColor3=is and et.Text or et.TextDark;ob.Title.Font=is and Enum.Font.GothamBold or Enum.Font.Gotham;AddConnection(ob.MouseEnter,function()if not(op==d.Value)then TweenService:Create(ob,TWEEN_INFO_FAST,{BackgroundColor3=ohc,BackgroundTransparency=0}):Play()end end);AddConnection(ob.MouseLeave,function()if not(op==d.Value)then TweenService:Create(ob,TWEEN_INFO_FAST,{BackgroundTransparency=1}):Play()end end);AddConnection(ob.MouseButton1Down,function()if not(op==d.Value)then TweenService:Create(ob,TWEEN_INFO_FAST,{BackgroundColor3=occ,BackgroundTransparency=0}):Play()end end);AddConnection(ob.Activated,function()if op~=d.Value then d:Set(op);if d.Save then SaveCfg(game.GameId)end end;if d.Toggled then cl.Activated:Fire()end end);d.Buttons[op]=ob end;task.wait();local h=dl.AbsoluteContentSize.Y;dc.CanvasSize=UDim2.new(0,0,0,h)end;function d:Refresh(o,del)d.Options=o or{};ao(d.Options);d:Set(d.Value,true)end;function d:Set(v,sk)local f=false;for _,o in ipairs(d.Options)do if o==v then f=true;break end end;if not f then if #d.Options>0 then d.Value=d.Options[1]else d.Value="No Options"end else d.Value=v end;if df and df.Parent then df.F.Selected.Text=d.Value end;for o,b in pairs(d.Buttons)do if b and b.Parent then local is=o==d.Value;local tb=is and 0 or 1;local tc=is and osc or obc;local tt=is and et.Text or et.TextDark;local tf=is and Enum.Font.GothamBold or Enum.Font.Gotham;TweenService:Create(b,TWEEN_INFO_FAST,{BackgroundTransparency=tb,BackgroundColor3=tc}):Play();TweenService:Create(b.Title,TWEEN_INFO_FAST,{TextColor3=tt}):Play();b.Title.Font=tf end end;if not sk then task.spawn(dc.Callback,d.Value)end end;see(df,cl);AddConnection(cl.Activated,function()if not df or not df.Parent then return end;d.Toggled=not d.Toggled;df.F.Line.Visible=d.Toggled;dc.Visible=d.Toggled;df.ClipsDescendants=not d.Toggled;TweenService:Create(df.F.Ico,TWEEN_INFO_FAST,{Rotation=d.Toggled and-180 or 0}):Play();local th=0;if d.Toggled then th=math.min(dc.CanvasSize.Y.Offset,dc.MaxHeight)end;TweenService:Create(dc,TWEEN_INFO_NORMAL,{Size=UDim2.new(1,0,0,th)}):Play()end);d:Refresh(d.Options);d:Set(d.Value,true);if dc.Flag then OrionLib.Flags[dc.Flag]=d end;return d end;function ef:AddBind(bc)bc=bc or{};bc.Name=bc.Name or"Bind";bc.Default=bc.Default or Enum.KeyCode.None;bc.Hold=bc.Hold or false;bc.Callback=bc.Callback or function(v)print("Bind:",bc.Name,v)end;bc.Flag=bc.Flag or nil;bc.Save=bc.Save or true;local b={Value=bc.Default,Binding=false,Type="Bind",Save=bc.Save};local ho=false;local cl=SetProps(MakeElement("Button"),{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Active=true});local bvl=AddThemeObject(SetProps(MakeElement("Label","...",13),{Size=UDim2.new(1,-16,1,-8),Position=UDim2.new(0.5,0,0.5,0),AnchorPoint=Vector2.new(0.5,0.5),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,Name="Value",BackgroundTransparency=1}),"Text");local bb=AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",et.Main,0,4),{Size=UDim2.new(0,60,0,24),Position=UDim2.new(1,-12,0.5,0),AnchorPoint=Vector2.new(1,0.5),ClipsDescendants=true}),{AddThemeObject(MakeElement("Stroke"),"Stroke"),bvl}),"Main");local bf=AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",et.Second,0,5),{Size=UDim2.new(1,0,0,38),Parent=ip,Active=true}),{AddThemeObject(SetProps(MakeElement("Label",bc.Name,14),{Size=UDim2.new(1,-80,1,0),Position=UDim2.new(0,12,0,0),Font=Enum.Font.GothamBold,Name="Content",TextYAlignment=Enum.TextYAlignment.Center}),"Text"),AddThemeObject(MakeElement("Stroke"),"Stroke"),bb,cl}),"Second");local cic=nil;AddConnection(bvl:GetPropertyChangedSignal("TextBounds"),function()if bb and bb.Parent then local w=bvl.TextBounds.X+20;w=math.max(40,w);TweenService:Create(bb,TWEEN_INFO_FAST,{Size=UDim2.new(0,w,0,24)}):Play()end end);local function sb(nk)if not b.Binding then return end;b.Binding=false;bvl.TextColor3=et.Text;if cic then cic:Disconnect();cic=nil end;local kts=nk or b.Value;if kts~=Enum.KeyCode.Escape then b:Set(kts);if b.Save then SaveCfg(game.GameId)end else b:Set(b.Value)end end;AddConnection(cl.Activated,function()if b.Binding then return end;b.Binding=true;bvl.Text="...";bvl.TextColor3=Color3.fromRGB(255,255,0);if cic then cic:Disconnect();cic=nil end;cic=AddConnection(UserInputService.InputBegan,function(i,gp)if gp then return end;if not b.Binding then return end;local k=nil;if i.UserInputType.Name:find("Mouse")and table.find(WhitelistedMouse,i.UserInputType)then k=i.UserInputType elseif i.KeyCode~=Enum.KeyCode.Unknown and not table.find(BlacklistedKeys,i.KeyCode)then k=i.KeyCode end;if k then sb(k)elseif i.KeyCode==Enum.KeyCode.Escape then sb(Enum.KeyCode.Escape)end end)end);AddConnection(UserInputService.InputBegan,function(i)if b.Binding and i.UserInputType==Enum.UserInputType.MouseButton1 then local mp=i.Position;local bp,bs=bb.AbsolutePosition,bb.AbsoluteSize;if not(mp.X>=bp.X and mp.X<=bp.X+bs.X and mp.Y>=bp.Y and mp.Y<=bp.Y+bs.Y)then sb(Enum.KeyCode.Escape)end end end);AddConnection(UserInputService.InputBegan,function(i,gp)if gp or UserInputService:GetFocusedTextBox()or b.Binding then return end;local bv=b.Value;local im=i.KeyCode==bv or i.UserInputType==bv;if im then if bc.Hold then ho=true;task.spawn(bc.Callback,ho)else task.spawn(bc.Callback)end end end);AddConnection(UserInputService.InputEnded,function(i)local bv=b.Value;local im=i.KeyCode==bv or i.UserInputType==bv;if im and bc.Hold and ho then ho=false;task.spawn(bc.Callback,ho)end end);see(bf,cl);function b:Set(k,sk)if not bvl or not bvl.Parent then return end;b.Value=k or b.Value;local n="";if type(b.Value)=="EnumItem"then n=b.Value.Name;if n=="None"then n="None"elseif n:find("MouseButton")then n="M"..n:sub(12)end else n=tostring(b.Value)end;bvl.Text=n;b.Binding=false;if cic then cic:Disconnect();cic=nil end end;b:Set(bc.Default,true);if bc.Flag then OrionLib.Flags[bc.Flag]=b end;return b end;function ef:AddTextbox(tc)tc=tc or{};tc.Name=tc.Name or"Textbox";tc.Default=tc.Default or"";tc.Placeholder=tc.Placeholder or"Input...";tc.TextDisappear=tc.TextDisappear or false;tc.NumbersOnly=tc.NumbersOnly or false;tc.Callback=tc.Callback or function(v)print("Textbox:",tc.Name,v)end;tc.Flag=tc.Flag or nil;tc.Save=tc.Save or true;local t={Value=tc.Default,Type="Textbox",Save=tc.Save};local cl=SetProps(MakeElement("Button"),{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Active=true});local ta=AddThemeObject(Create("TextBox",{Size=UDim2.new(1,-10,1,-6),Position=UDim2.new(0.5,0,0.5,0),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,TextColor3=et.Text,TextSize=14,PlaceholderColor3=et.TextDark,PlaceholderText=tc.Placeholder,Font=Enum.Font.GothamSemibold,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ClearTextOnFocus=false,MultiLine=false,Text=tc.Default,Name="InputBox",Active=true}),"Text");if tc.NumbersOnly then AddConnection(ta:GetPropertyChangedSignal("Text"),function()if ta then ta.Text=ta.Text:match("[\-%.%d]*")or""end end)end;local tct=AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",et.Main,0,4),{Size=UDim2.new(1,-50,0,24),Position=UDim2.new(1,-12,0.5,0),AnchorPoint=Vector2.new(1,0.5),ClipsDescendants=true}),{AddThemeObject(MakeElement("Stroke"),"Stroke"),ta}),"Main");local tf=AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",et.Second,0,5),{Size=UDim2.new(1,0,0,38),Parent=ip,Active=true}),{AddThemeObject(SetProps(MakeElement("Label",tc.Name,14),{Size=UDim2.new(1,-12,1,0),Position=UDim2.new(0,12,0,0),Font=Enum.Font.GothamBold,Name="Content",TextYAlignment=Enum.TextYAlignment.Center}),"Text"),AddThemeObject(MakeElement("Stroke"),"Stroke"),tct,cl}),"Second");AddConnection(ta.FocusLost,function(ep)if not ta or not ta.Parent then return end;local nv=ta.Text;if t.Value~=nv then t.Value=nv;task.spawn(tc.Callback,nv);if t.Save then SaveCfg(game.GameId)end end;if ep and tc.TextDisappear then ta.Text="";t.Value=""end end);see(tf,cl);AddConnection(cl.Activated,function()if ta and ta.Parent then ta:CaptureFocus()end end);function t:Set(v,sk)if not ta or not ta.Parent then return end;ta.Text=tostring(v);local nv=ta.Text;if t.Value~=nv then t.Value=nv;if not sk then task.spawn(tc.Callback,nv)end end end;t:Set(tc.Default,true);if tc.Flag then OrionLib.Flags[tc.Flag]=t end;return t end;function ef:AddColorpicker(cc)cc=cc or{};cc.Name=cc.Name or"Colorpicker";cc.Default=cc.Default or Color3.fromRGB(255,255,255);cc.Callback=cc.Callback or function(v)print("Colorpicker:",cc.Name,v)end;cc.Flag=cc.Flag or nil;cc.Save=cc.Save or true;local ch,cs,cv=Color3.toHSV(cc.Default);local c={Value=cc.Default,Toggled=false,Type="Colorpicker",Save=cc.Save};local pd=nil;local cos=Create("ImageLabel",{Size=UDim2.new(0,18,0,18),Position=UDim2.fromScale(cs,1-cv),ScaleType=Enum.ScaleType.Fit,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Image="http://www.roblox.com/asset/?id=4805639000",ZIndex=4});local hs=Create("ImageLabel",{Size=UDim2.new(0,18,0,18),Position=UDim2.fromScale(0.5,ch),ScaleType=Enum.ScaleType.Fit,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Image="http://www.roblox.com/asset/?id=4805639000",ZIndex=4});local co=Create("Frame",{Size=UDim2.new(1,-35,1,0),Position=UDim2.new(0,0,0,0),Visible=false,ClipsDescendants=false,BackgroundColor3=Color3.fromHSV(ch,1,1),ZIndex=2,Active=true},{Create("UICorner",{CornerRadius=UDim.new(0,5)}),Create("UIGradient",{Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(1,Color3.fromHSV(ch,1,1))},Rotation=0}),Create("UIGradient",{Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.new(0,0,0)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))},Transparency=NumberSequence.new{NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)},Rotation=90}),cos});local hu=Create("Frame",{Size=UDim2.new(0,20,1,0),Position=UDim2.new(1,-20,0,0),Visible=false,ClipsDescendants=false,ZIndex=2,Active=true},{Create("UIGradient",{Rotation=90,Color=ColorSequence.new{ColorSequenceKeypoint.new(0.00,Color3.fromRGB(255,0,0)),ColorSequenceKeypoint.new(1/6,Color3.fromRGB(255,255,0)),ColorSequenceKeypoint.new(2/6,Color3.fromRGB(0,255,0)),ColorSequenceKeypoint.new(3/6,Color3.fromRGB(0,255,255)),ColorSequenceKeypoint.new(4/6,Color3.fromRGB(0,0,255)),ColorSequenceKeypoint.new(5/6,Color3.fromRGB(255,0,255)),ColorSequenceKeypoint.new(1.00,Color3.fromRGB(255,0,0))}}),Create("UICorner",{CornerRadius=UDim.new(0,5)}),hs});local cpc=Create("Frame",{Position=UDim2.new(0,0,1,1),Size=UDim2.new(1,0,0,110),BackgroundTransparency=1,ClipsDescendants=true,Visible=false},{hu,co,Create("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),PaddingBottom=UDim.new(0,10),PaddingTop=UDim.new(0,10)})});local cl=SetProps(MakeElement("Button"),{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Active=true});local cpb=AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",c.Value,0,4),{Size=UDim2.new(0,24,0,24),Position=UDim2.new(1,-12,0.5,0),AnchorPoint=Vector2.new(1,0.5),Name="ColorDisplay"}),{AddThemeObject(MakeElement("Stroke"),"Stroke")}),"Main");local cpf=AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame",et.Second,0,5),{Size=UDim2.new(1,0,0,38),Parent=ip,ClipsDescendants=true,ZIndex=2,Active=true}),{cpc,SetProps(SetChildren(MakeElement("TFrame"),{AddThemeObject(SetProps(MakeElement("Label",cc.Name,14),{Size=UDim2.new(1,-50,1,0),Position=UDim2.new(0,12,0,0),Font=Enum.Font.GothamBold,Name="Content",TextYAlignment=Enum.TextYAlignment.Center}),"Text"),cpb,cl,AddThemeObject(SetProps(MakeElement("Frame"),{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,0),Name="Line",Visible=false}),"Stroke")}),{Size=UDim2.new(1,0,1,0),ClipsDescendants=true,Name="F"}),AddThemeObject(MakeElement("Stroke"),"Stroke")}),"Second");local cot=nil;AddConnection(cl.Activated,function()if not cpf or not cpf.Parent then return end;c.Toggled=not c.Toggled;if cot and cot.PlaybackState==Enum.PlaybackState.Playing then cot:Cancel()end;local tfs=c.Toggled and(38+1+110)or 38;local tcv=c.Toggled;cot=TweenService:Create(cpf,TWEEN_INFO_NORMAL,{Size=UDim2.new(1,0,0,tfs)});cot:Play();if c.Toggled then cpf.ClipsDescendants=false;cpc.Visible=true;cpc.ClipsDescendants=false;co.Visible=true;hu.Visible=true;cpf.F.Line.Visible=true else cpf.F.Line.Visible=false;task.delay(TWEEN_INFO_NORMAL.Time,function()if cpf and cpf.Parent and not c.Toggled then co.Visible=false;hu.Visible=false;cpc.Visible=false;cpf.ClipsDescendants=true;cpc.ClipsDescendants=true end end)end end);see(cpf,cl);local function uc(sk)if not cpb or not cpb.Parent then return end;local nc=Color3.fromHSV(ch,cs,cv);if c.Value==nc then return end;c.Value=nc;cpb.BackgroundColor3=c.Value;local hc=Color3.fromHSV(ch,1,1);co.BackgroundColor3=hc;local g=co:FindFirstChildOfClass("UIGradient");if g then g.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(1,hc)}end;if not sk then task.spawn(cc.Callback,c.Value)end end;local ic=nil;local function sd(it)pd=it;if ic then ic:Disconnect()end;ic=AddConnection(UserInputService.InputChanged,function(i)if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then if pd=="Color"and co and co.Parent then local mp=i.Position;local rx=math.clamp(mp.X-co.AbsolutePosition.X,0,co.AbsoluteSize.X);local ry=math.clamp(mp.Y-co.AbsolutePosition.Y,0,co.AbsoluteSize.Y);cs=rx/co.AbsoluteSize.X;cv=1-(ry/co.AbsoluteSize.Y);cos.Position=UDim2.fromScale(cs,1-cv);uc()elseif pd=="Hue"and hu and hu.Parent then local mp=i.Position;local ry=math.clamp(mp.Y-hu.AbsolutePosition.Y,0,hu.AbsoluteSize.Y);ch=ry/hu.AbsoluteSize.Y;hs.Position=UDim2.fromScale(0.5,ch);uc()end end end)end;local function spd()if pd and c.Save then SaveCfg(game.GameId)end;pd=nil;if ic then ic:Disconnect();ic=nil end end;AddConnection(co.InputBegan,function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sd("Color");uc()end end);AddConnection(hu.InputBegan,function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sd("Hue");uc()end end);AddConnection(UserInputService.InputEnded,function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then if pd then spd()end end end);function c:Set(v,sk)if type(v)~="Color3"or not cpb or not cpb.Parent then return end;ch,cs,cv=Color3.toHSV(v);c.Value=v;cpb.BackgroundColor3=c.Value;cos.Position=UDim2.fromScale(cs,1-cv);hs.Position=UDim2.fromScale(0.5,ch);local hc=Color3.fromHSV(ch,1,1);co.BackgroundColor3=hc;local g=co:FindFirstChildOfClass("UIGradient");if g then g.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(1,hc)}end;if not sk then task.spawn(cc.Callback,c.Value)end end;c:Set(c.Value,true);if cc.Flag then OrionLib.Flags[cc.Flag]=c end;return c end;return ef end;local ef={};function ef:AddSection(sc)sc=sc or{};sc.Name=sc.Name or"Section";local sf=SetChildren(SetProps(MakeElement("TFrame"),{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,Parent=con,LayoutOrder=#con:GetChildren()+1}),{AddThemeObject(SetProps(MakeElement("Label","<b>"..sc.Name.."</b>",14),{Size=UDim2.new(1,0,0,20),Position=UDim2.new(0,0,0,0),Font=Enum.Font.GothamBold,TextYAlignment=Enum.TextYAlignment.Bottom,Name="SectionTitle",LayoutOrder=1}),"TextDark"),SetChildren(SetProps(MakeElement("TFrame"),{AnchorPoint=Vector2.new(0,0),Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,Position=UDim2.new(0,0,0,23),Name="Holder",LayoutOrder=2}),{MakeElement("List",0,6)}),MakeElement("List",0,5)});local sfu={};for i,v in pairs(ge(sf.Holder))do sfu[i]=v end;return sfu end;for i,v in pairs(ge(con))do ef[i]=v end;if tc.PremiumOnly and WindowConfig.HidePremium then if tct and tct.Parent then tct.Visible=false end;if con and con.Parent then con:Destroy()end;local dfu=function()return{Set=function()end,Refresh=function()end}end;for i,_ in pairs(ef)do ef[i]=dfu end;return ef end;return ef end;return tfu end;function OrionLib:Destroy()print("OrionLib: Destroy called.");for i=#OrionLib.Connections,1,-1 do local c=OrionLib.Connections[i];if c and typeof(c.Disconnect)=="function"then pcall(c.Disconnect)end;table.remove(OrionLib.Connections,i)end;if Orion and Orion.Parent then Orion:Destroy()end;OrionLib.Flags={};OrionLib.ThemeObjects={}end;return OrionLib
