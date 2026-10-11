local _version = "1.6.66"
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/" .. _version .. "/main.lua"))()
WindUI:AddTheme({
Name = "Moon Space",
Accent = Color3.fromHex("#000000"),
Background = Color3.fromHex("#990000"),
Text = Color3.fromHex("#FFFFFF"),
Placeholder = Color3.fromHex("#FF0000"),
Button = Color3.fromHex("#FF0000"),
Icon = Color3.fromHex("#FFFFFF"),
Hover = Color3.fromHex("#FF0000"),
WindowBackground = Color3.fromHex("#000000"),
WindowShadow = Color3.fromHex("#000000"),
})
local Window = WindUI:CreateWindow({
Title = " ㅤㅤㅤㅤSaturn hubㅤㅤㅤㅤㅤㅤㅤㅤㅤㅤㅤㅤㅤㅤ",
Icon ="rbxassetid://131288947379751",
Author = " Premium",
Folder = "So hub X ",
Size = UDim2.fromOffset(400, 200),
MinSize = Vector2.new(560, 350),
MaxSize = Vector2.new(850, 560),
Transparent = true,
Theme = "Moon Space",
Resizable = true,
SideBarWidth = 200,
User = {
Enabled = true,
Anonymous = false,
Callback = function()
print("clicked")
end,
},
})



Window:Tag({
Title = "v1.0",
Icon = "",
Color = Color3.fromHex("#990000"),
Radius = 13,

})
Window:Section({
    Title = "Tab Section example", -- title. required
    Icon = "calendar", -- icon. optional
    Opened = true, -- whether the section is opened. optional
})
local Tab = Window:Tab({
    Title = "aimbot",
Icon = "target",
})
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-------------------------------------------------------------------------
-- CONFIGURATION (การตั้งค่า)
-------------------------------------------------------------------------
local Config = {
    SilentAim = false,         -- เปิด/ปิด การใช้งาน Silent Aim
    FOV = 100,                 -- ขนาดวงกลม FOV
    MaxDistance = 2000,        -- ระยะทางสูงสุดที่จะล็อกเป้า
    AimPart = "Head",          -- อวัยวะที่จะล็อก ("Head", "HumanoidRootPart", "UpperTorso")
    TeamCheck = true,          -- ไม่ล็อกเป้าใส่เพื่อนร่วมทีม
    WallCheck = true,          -- ไม่ล็อกเป้าที่อยู่หลังสิ่งกีดขวาง/กำแพง
    ShowFOV = true,            -- แสดงวงกลม FOV บนหน้าจอ
    ShowTracer = true,         -- แสดงเส้นชี้ไปยังเป้าหมาย
    FOVColor = Color3.fromRGB(255, 0, 0), -- สีของวงกลม FOV
    FOVThickness = 1.5,        -- ความหนาของเส้น FOV
    FOVFilled = false,         -- ถมสีเต็มวงกลม FOV
    CustomBulletSpeed = 2000,  -- ความเร็วลูกกระสุนสำหรับคำนวณยิงดัก (Prediction)
}

local CurrentTarget = nil
local hooked = false

-------------------------------------------------------------------------
-- DRAWING LIBRARY (ระบบวงกลม FOV & เส้น Tracer แบบ Drawing)
-------------------------------------------------------------------------
local FOVCircle = Drawing.new("Circle")
FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
FOVCircle.Radius = Config.FOV
FOVCircle.Color = Config.FOVColor
FOVCircle.Thickness = Config.FOVThickness
FOVCircle.Filled = Config.FOVFilled
FOVCircle.Visible = Config.ShowFOV and Config.SilentAim

local TracerLine = Drawing.new("Line")
TracerLine.Color = Color3.fromRGB(255, 50, 50)
TracerLine.Thickness = 1.5
TracerLine.Transparency = 1
TracerLine.Visible = false

-------------------------------------------------------------------------
-- UI CONTROLLER & TOGGLES
-------------------------------------------------------------------------
local ToggleSilentAim = Tab:Toggle({
    Title = "Enable Silent Aim",
    Default = false,
    Callback = function(state)
        Config.SilentAim = state
    end
})

local ToggleFOV = Tab:Toggle({
    Title = "Show FOV Circle",
    Default = true,
    Callback = function(state)
        Config.ShowFOV = state
    end
})

local ToggleTracer = Tab:Toggle({
    Title = "Show Tracer Line",
    Default = true,
    Callback = function(state)
        Config.ShowTracer = state
    end
})

local FOVSlider = Tab:Slider({
    Title = "FOV Size",
    Value = {
        Min = 10,
        Max = 500,
        Default = 100
    },
    Callback = function(value)
        Config.FOV = value
    end
})

local ThicknessSlider = Tab:Slider({
    Title = "Circle Thickness",
    Value = {
        Min = 1,
        Max = 10,
        Default = 1.5
    },
    Callback = function(value)
        Config.FOVThickness = value
    end
})

local FOVColorPicker = Tab:Colorpicker({
    Title = "FOV Color",
    Default = Color3.fromRGB(255, 0, 0),
    Callback = function(color)
        Config.FOVColor = color
    end
})

local FilledToggle = Tab:Toggle({
    Title = "Fill Circle",
    Default = false,
    Callback = function(state)
        Config.FOVFilled = state
    end
})


local function GetPing()
    local ping = 0.03
    pcall(function()
        if LocalPlayer.GetNetworkPing then
            ping = LocalPlayer:GetNetworkPing()
        else
            ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
        end
    end)
    return math.clamp(ping, 0, 0.5)
end

local function HasWallBetween(origin, targetPos, character)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    local result = Workspace:Raycast(origin, targetPos - origin, params)
    if result then
        return not result.Instance:IsDescendantOf(character)
    end
    return false
end

local function PredictPosition(origin, targetPart, bulletSpeed)
    if not targetPart or not targetPart.Parent then return nil end
    local pos = targetPart.Position
    local root = targetPart.Parent:FindFirstChild("HumanoidRootPart")
        or targetPart.Parent:FindFirstChild("Torso")
        or targetPart.Parent:FindFirstChild("UpperTorso")
        or targetPart
    local velocity = Vector3.zero
    pcall(function()
        velocity = root.AssemblyLinearVelocity or root.Velocity or Vector3.zero
    end)
    
    pos = pos + velocity * GetPing()
    local speed = math.max(bulletSpeed or Config.CustomBulletSpeed, 300)
    local toTarget = pos - origin
    local a = velocity:Dot(velocity) - (speed * speed)
    local b = 2 * toTarget:Dot(velocity)
    local c = toTarget:Dot(toTarget)
    local disc = (b * b) - (4 * a * c)
    local flyTime = toTarget.Magnitude / speed
    
    if disc >= 0 and math.abs(a) > 0.0001 then
        local t1 = (-b - math.sqrt(disc)) / (2 * a)
        local t2 = (-b + math.sqrt(disc)) / (2 * a)
        if t1 > 0 and t2 > 0 then flyTime = math.min(t1, t2)
        elseif t1 > 0 then flyTime = t1
        elseif t2 > 0 then flyTime = t2 end
    end
    
    pos = pos + velocity * flyTime
    pos = pos + Vector3.new(0, 0.5 * Workspace.Gravity * (flyTime * flyTime), 0)
    return pos
end

local function GetClosestTarget()
    if not Config.SilentAim then
        CurrentTarget = nil
        return nil
    end
    
    local closestPart, closestPlayer = nil, nil
    local shortest = Config.FOV + 1
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local myRoot = LocalPlayer.Character and (
        LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        or LocalPlayer.Character:FindFirstChild("UpperTorso")
        or LocalPlayer.Character:FindFirstChild("Torso")
    )
    
    if not myRoot then
        CurrentTarget = nil
        return nil
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local part = char:FindFirstChild(Config.AimPart) or char:FindFirstChild("Head")
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
            
            if hum and hum.Health > 0 and part and root then
                if Config.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
                    continue
                end
                
                local dist3D = (myRoot.Position - root.Position).Magnitude
                if dist3D <= Config.MaxDistance then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen and screenPos.Z > 0 then
                        local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if dist2D <= Config.FOV then
                            local blocked = Config.WallCheck and HasWallBetween(Camera.CFrame.Position, part.Position, char)
                            if not blocked then
                                if dist2D < shortest then
                                    shortest = dist2D
                                    closestPart = part
                                    closestPlayer = player
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    CurrentTarget = closestPlayer
    return closestPart
end

local function ApplyHook()
    if hooked then return end
    local ok, handler = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ProjectileHandler"))
    end)
    
    if not ok or not handler or not handler.SimulateProjectile then
        warn("[SILENT AIM] ไม่พบโมดูล SimulateProjectile ในเกมนี้")
        return
    end
    
    local old = handler.SimulateProjectile
    handler.SimulateProjectile = function(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15)
        if Config.SilentAim and type(a2) == "table" then
            pcall(function()
                a2.Spread = 0
                a2.Inaccuracy = 0
                a2.Recoil = 0
            end)
        end
        
        if Config.SilentAim then
            local targetPart = GetClosestTarget()
            if targetPart then
                local origin = nil
                if a8 and a8.WorldPosition then
                    origin = a8.WorldPosition
                elseif a4 then
                    local gfp = a4:FindFirstChild("GunFirePoint")
                    if gfp then origin = gfp.WorldPosition end
                end
                
                if not origin and LocalPlayer.Character then
                    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then origin = hrp.Position end
                end
                
                if origin then
                    local speed = Config.CustomBulletSpeed
                    if type(a2) == "table" then
                        local s = a2.BulletSpeed or a2.Speed or a2.MuzzleVelocity
                        if type(s) == "number" and s > 50 then speed = s end
                    end
                    
                    local predicted = PredictPosition(origin, targetPart, speed)
                    if predicted then
                        local dir = predicted - origin
                        if dir.Magnitude > 0.001 then
                            dir = dir.Unit
                            if typeof(a6) == "table" then for i = 1, #a6 do a6[i] = dir end end
                            if typeof(a7) == "table" then for i = 1, #a7 do a7[i] = dir end end
                        end
                    end
                end
            end
        end
        return old(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15)
    end
    hooked = true
end

ApplyHook()

-------------------------------------------------------------------------
-- RENDER LOOP (อัปเดตการแสดงผล FOV & Tracer)
-------------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    -- อัปเดต FOV Circle
    FOVCircle.Position = screenCenter
    FOVCircle.Radius = Config.FOV
    FOVCircle.Color = Config.FOVColor
    FOVCircle.Thickness = Config.FOVThickness
    FOVCircle.Filled = Config.FOVFilled
    FOVCircle.Visible = Config.ShowFOV and Config.SilentAim

    -- ค้นหาเป้าหมาย
    local targetPart = GetClosestTarget()

    -- อัปเดต Tracer Line
    if Config.SilentAim and Config.ShowTracer and CurrentTarget and CurrentTarget.Character and targetPart then
        local pos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if onScreen and pos.Z > 0 then
            TracerLine.From = screenCenter
            TracerLine.To = Vector2.new(pos.X, pos.Y)
            TracerLine.Visible = true
        else
            TracerLine.Visible = false
        end
    else
        TracerLine.Visible = false
    end
end)
local FaceTarget = false

local FaceTargetToggle = Tab:Toggle({
    Title = "Face Locked Target",
    Default = false,
    Callback = function(state)
        FaceTarget = state
    end
})

RunService.RenderStepped:Connect(function()
    if not FaceTarget or not Config.SilentAim then
        return
    end

    local Character = LocalPlayer.Character
    if not Character then return end

    local Root = Character:FindFirstChild("HumanoidRootPart")
    if not Root then return end

    if CurrentTarget and CurrentTarget.Character then
        local TargetRoot =
            CurrentTarget.Character:FindFirstChild("HumanoidRootPart")
            or CurrentTarget.Character:FindFirstChild("UpperTorso")
            or CurrentTarget.Character:FindFirstChild("Torso")

        if TargetRoot then
            local myPos = Root.Position
            local targetPos = TargetRoot.Position

            local lookPos = Vector3.new(
                targetPos.X,
                myPos.Y,
                targetPos.Z
            )

            if (lookPos - myPos).Magnitude > 0.1 then
                Root.CFrame = CFrame.lookAt(myPos, lookPos)
            end
        end
    end
end)
local Tab = Window:Tab({
    Title = "Weapon",
    Icon = "layout-dashboard", -- optional
})
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Button = Tab:Button({
    Title = "ไม่ได้ถืออะไร",
    Callback = function()
        print("กำลังถือ:", "Tool")
    end
})

RunService.Heartbeat:Connect(function()
    local Character = LocalPlayer.Character
    if not Character then return end

    local Tool = Character:FindFirstChildOfClass("Tool")

    if Tool then
        Button:SetTitle(Tool.Name)
    else
        Button:SetTitle(">> ไม่ได้ถืออะไรกรุณนาถือปืนเพื่อใช้ฟั่งชั่น <<")
    end
end)
-- ปุ่มที่ 1: กระสุนไม่จำกัด (Infinite Ammo)
local InfiniteAmmoButton = Tab:Button({
    Title = "Infinite Ammo",
    Callback = function()
        pcall(function()
            local tool = game.Players.LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if tool and tool:FindFirstChild("Setting") then
                local g = require(tool.Setting)
                
                -- ปรับค่ากระสุนเป็นอนันต์
                g.MaxAmmo = math.huge
                g.Ammo = math.huge
                g.AmmoPerMag = math.huge
                g.LimitedAmmoEnabled = false
                
                print("[SUCCESS] เปิดใช้งานกระสุนไม่จำกัดเรียบร้อย!")
            else
                warn("[WARNING] กรุณาถือปืนก่อนกดปุ่ม!")
            end
        end)
    end
})

-- ปุ่มที่ 2: ตั้งค่าความเร็วปืนและรีโหลด (Super Gun Mod)
local FastGunButton = Tab:Button({
    Title = "Fast Reload & Fire Rate",
    Callback = function()
        pcall(function()
            local tool = game.Players.LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if tool and tool:FindFirstChild("Setting") then
                local g = require(tool.Setting)
                
                
                g.DelayBeforeFiring = 0.01    -- หน่วงเวลาก่อนเริ่มยิง
                g.BulletSpeed = 99999         -- ความเร็วกระสุน
                
                -- ปรับอัตราการยิงรัวเพิ่มเติม (ถ้ามี)
                if g.FireRate then g.FireRate = 0.01 end
                if g.Auto ~= nil then g.Auto = true end
                
                print("[SUCCESS] เปิดใช้งานสปีดปืนเรียบร้อย!")
            else
                warn("[WARNING] กรุณาถือปุ่มก่อนกด!")
            end
        end)
    end
})


local Tab = Window:Tab({
    Title = "ESP",
    Icon = "eye", -- optional
})
local BoxedSection = Tab:Section({
    Title = " Settings Esp",
    Box = true,
    BoxBorder = true,
    Icon = "hand",
    Opened = false
})
 

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ESPEnabled = false
local ESPObjects = {}

local function CreateESP(player)
    if player == Players.LocalPlayer then return end

    local lines = {}

    for i = 1, 8 do
        local line = Drawing.new("Line")
        line.Thickness = 2
        line.Color = Color3.fromRGB(255, 255, 255)
        line.Transparency = 1
        line.Visible = false
        lines[i] = line
    end

    ESPObjects[player] = lines
end

local function RemoveESP(player)
    if ESPObjects[player] then
        for _, line in ipairs(ESPObjects[player]) do
            line:Remove()
        end
        ESPObjects[player] = nil
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    CreateESP(player)
end

Players.PlayerAdded:Connect(CreateESP)
Players.PlayerRemoving:Connect(RemoveESP)

local function HideESP()
    for _, lines in pairs(ESPObjects) do
        for _, line in ipairs(lines) do
            line.Visible = false
        end
    end
end

RunService.RenderStepped:Connect(function()
    if not ESPEnabled then
        HideESP()
        return
    end

    local Camera = workspace.CurrentCamera

    for player, lines in pairs(ESPObjects) do
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if root and humanoid and humanoid.Health > 0 then
            local cf = character:GetBoundingBox()
            local size = character:GetExtentsSize()

            local top = cf.Position + Vector3.new(0, size.Y / 2, 0)
            local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)

            local topPos, topVisible = Camera:WorldToViewportPoint(top)
            local bottomPos, bottomVisible = Camera:WorldToViewportPoint(bottom)

            if topVisible and bottomVisible and topPos.Z > 0 and bottomPos.Z > 0 then
                local height = math.abs(bottomPos.Y - topPos.Y)
                local width = height * 0.55
                local x = (topPos.X + bottomPos.X) / 2
                local yTop = topPos.Y
                local yBottom = bottomPos.Y

                local cornerX = width / 4
                local cornerY = height / 4

                -- มุมซ้ายบน
                lines[1].From = Vector2.new(x - width / 2, yTop)
                lines[1].To = Vector2.new(x - width / 2 + cornerX, yTop)

                lines[2].From = Vector2.new(x - width / 2, yTop)
                lines[2].To = Vector2.new(x - width / 2, yTop + cornerY)

                -- มุมขวาบน
                lines[3].From = Vector2.new(x + width / 2, yTop)
                lines[3].To = Vector2.new(x + width / 2 - cornerX, yTop)

                lines[4].From = Vector2.new(x + width / 2, yTop)
                lines[4].To = Vector2.new(x + width / 2, yTop + cornerY)

                -- มุมซ้ายล่าง
                lines[5].From = Vector2.new(x - width / 2, yBottom)
                lines[5].To = Vector2.new(x - width / 2 + cornerX, yBottom)

                lines[6].From = Vector2.new(x - width / 2, yBottom)
                lines[6].To = Vector2.new(x - width / 2, yBottom - cornerY)

                -- มุมขวาล่าง
                lines[7].From = Vector2.new(x + width / 2, yBottom)
                lines[7].To = Vector2.new(x + width / 2 - cornerX, yBottom)

                lines[8].From = Vector2.new(x + width / 2, yBottom)
                lines[8].To = Vector2.new(x + width / 2, yBottom - cornerY)

                for _, line in ipairs(lines) do
                    line.Visible = true
                end
            else
                for _, line in ipairs(lines) do
                    line.Visible = false
                end
            end
        else
            for _, line in ipairs(lines) do
                line.Visible = false
            end
        end
    end
end)

BoxedSection:Toggle({
    Title = "ESP",
    Icon = "scan-eye", -- optional
    Callback = function(state)
        ESPEnabled = state
    end
})
local Tab = Window:Tab({
    Title = "Aura",
    Desc = "Tab description", -- optional
    Icon = "sparkles", -- lucide icon or "rbxassetid://" or URL. optional
    IconColor = Color3.fromRGB(255, 0, 0), -- custom icon color. optional
    IconShape = "Square", -- "Square" or "Circle". optional
    IconThemed = true, -- use theme colors. optional
    Locked = false, -- disable tab interaction. optional
    ShowTabTitle = false, -- show title inside tab. optional
    Border = true, -- add border around tab. optional
    CustomEmptyPage = { -- custom empty page when no elements are added to the tab. optional
		Icon = "lucide:smile", -- icon for empty page. optional
		Title = "This is a cool empty tab", -- title for empty page. optional
		Desc = "I like it. its so great tab with cool 'custom empty page'", -- description for empty page. optional
	},
})
local BoxedSection = Tab:Section({
    Title = "Settings Aura",
    Box = true,
    BoxBorder = true,
    Icon = "sparkle",
    Opened = false
})
 

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local AuraEnabled = false
local WingsEnabled = false

local Aura1
local Aura2
local LeftWing
local RightWing

local Aura1Color = Color3.fromRGB(0,125,175)
local Aura2Color = Color3.fromRGB(0,125,175)
local WingColor = Color3.fromRGB(255,255,255)

local function AuraSequence(color)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(
			0.49,
			color:Lerp(Color3.new(1,1,1),0.3)
		),
		ColorSequenceKeypoint.new(1, color)
	})
end

local function UpdateAuraColors()
	if Aura1 then
		Aura1.Color = AuraSequence(Aura1Color)
	end

	if Aura2 then
		Aura2.Color = AuraSequence(Aura2Color)
	end
end

local function UpdateWingColor()
	if LeftWing then
		LeftWing.Color = ColorSequence.new(WingColor)
	end

	if RightWing then
		RightWing.Color = ColorSequence.new(WingColor)
	end
end

local function RemoveAura(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local a1 = root:FindFirstChild("AuraAttachment")
	if a1 then
		a1:Destroy()
	end

	local a2 = root:FindFirstChild("Ambient2")
	if a2 then
		a2:Destroy()
	end

	Aura1 = nil
	Aura2 = nil
end

local function CreateAura(character)
	local root = character:WaitForChild("HumanoidRootPart")

	RemoveAura(character)

	if not AuraEnabled then
		return
	end

	-- Aura 1
	local att1 = Instance.new("Attachment")
	att1.Name = "AuraAttachment"
	att1.Position = Vector3.new(0,-2.8,0)
	att1.Parent = root

	Aura1 = Instance.new("ParticleEmitter")
	Aura1.Name = "Aura1"
	Aura1.Parent = att1

	Aura1.Texture = "rbxassetid://7216855136"
	Aura1.Brightness = 2
	Aura1.LightEmission = 1
	Aura1.LightInfluence = 0
	Aura1.Orientation = Enum.ParticleOrientation.VelocityPerpendicular

	Aura1.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0,0),
		NumberSequenceKeypoint.new(0.3,2),
		NumberSequenceKeypoint.new(0.6,5),
		NumberSequenceKeypoint.new(0.88,1),
		NumberSequenceKeypoint.new(1,0)
	})

	Aura1.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,1),
		NumberSequenceKeypoint.new(0.2,0),
		NumberSequenceKeypoint.new(0.3,0),
		NumberSequenceKeypoint.new(1,1)
	})

	Aura1.Squash = NumberSequence.new({
		NumberSequenceKeypoint.new(0,0),
		NumberSequenceKeypoint.new(1,0.2)
	})

	Aura1.Lifetime = NumberRange.new(2,2)
	Aura1.Rate = 20
	Aura1.Rotation = NumberRange.new(0,360)
	Aura1.RotSpeed = NumberRange.new(-40,40)
	Aura1.Speed = NumberRange.new(0.001,0.001)
	Aura1.SpreadAngle = Vector2.new(0.001,0.001)
	Aura1.VelocitySpread = 0.001
	Aura1.Acceleration = Vector3.new(0,0,0)
	Aura1.Drag = 0
	Aura1.LockedToPart = true
	Aura1.TimeScale = 1
	Aura1.VelocityInheritance = 0
	Aura1.EmissionDirection = Enum.NormalId.Top

	Aura1.Shape = Enum.ParticleEmitterShape.Box
	Aura1.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	Aura1.ShapePartial = 1
	Aura1.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume

	-- Aura 2
	local att2 = Instance.new("Attachment")
	att2.Name = "Ambient2"
	att2.Position = Vector3.new(0,-2.8,0)
	att2.Parent = root

	Aura2 = Instance.new("ParticleEmitter")
	Aura2.Name = "Aura2"
	Aura2.Parent = att2

	Aura2.Texture = "rbxassetid://12713358087"
	Aura2.Brightness = 2
	Aura2.LightEmission = 1
	Aura2.LightInfluence = 0
	Aura2.Orientation = Enum.ParticleOrientation.VelocityPerpendicular

	Aura2.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0,0),
		NumberSequenceKeypoint.new(0.31,0.6),
		NumberSequenceKeypoint.new(0.62,5),
		NumberSequenceKeypoint.new(0.84,1),
		NumberSequenceKeypoint.new(1,0)
	})

	Aura2.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,0),
		NumberSequenceKeypoint.new(1,0)
	})

	Aura2.Squash = NumberSequence.new({
		NumberSequenceKeypoint.new(0,0),
		NumberSequenceKeypoint.new(1,0.2)
	})

	Aura2.ZOffset = 0
	Aura2.Acceleration = Vector3.new(0,0,0)
	Aura2.Drag = 0
	Aura2.LockedToPart = true
	Aura2.TimeScale = 1
	Aura2.VelocityInheritance = 0
	Aura2.WindAffectsDrag = false

	Aura2.EmissionDirection = Enum.NormalId.Top
	Aura2.Lifetime = NumberRange.new(2,2)
	Aura2.Rate = 20
	Aura2.Rotation = NumberRange.new(0,360)
	Aura2.RotSpeed = NumberRange.new(-600,600)
	Aura2.Speed = NumberRange.new(0.001,0.001)
	Aura2.SpreadAngle = Vector2.new(0.001,0.001)
	Aura2.VelocitySpread = 0.001

	Aura2.Shape = Enum.ParticleEmitterShape.Box
	Aura2.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	Aura2.ShapePartial = 1
	Aura2.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume

	UpdateAuraColors()
end

local function RemoveWings(character)
	local torso = character:FindFirstChild("Torso")
		or character:FindFirstChild("UpperTorso")

	if not torso then
		return
	end

	local left = torso:FindFirstChild("WingLeft")
	if left then
		left:Destroy()
	end

	local right = torso:FindFirstChild("WingRight")
	if right then
		right:Destroy()
	end

	LeftWing = nil
	RightWing = nil
end

local function CreateWing(att, dir)
	local Wing = Instance.new("ParticleEmitter")

	Wing.Name = "Wing"
	Wing.Texture = "rbxassetid://13267054240"
	Wing.Brightness = 1
	Wing.Color = ColorSequence.new(WingColor)
	Wing.LightEmission = 1
	Wing.LightInfluence = 0
	Wing.Orientation = Enum.ParticleOrientation.VelocityPerpendicular

	Wing.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0,0.8),
		NumberSequenceKeypoint.new(0.12,3.5),
		NumberSequenceKeypoint.new(0.35,3.5),
		NumberSequenceKeypoint.new(0.7,3.2),
		NumberSequenceKeypoint.new(1,0)
	})

	Wing.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,1),
		NumberSequenceKeypoint.new(0.08,0.4),
		NumberSequenceKeypoint.new(0.15,0),
		NumberSequenceKeypoint.new(0.8,0),
		NumberSequenceKeypoint.new(1,1)
	})

	Wing.Speed = NumberRange.new(0.05,0.15)
	Wing.Lifetime = NumberRange.new(1.8,2.2)
	Wing.Rate = 3

	Wing.Rotation = NumberRange.new(-15)
	Wing.RotSpeed = NumberRange.new(0)
	Wing.SpreadAngle = Vector2.new(0,0)
	Wing.LockedToPart = true
	Wing.EmissionDirection = dir
	Wing.Enabled = true

	Wing.Parent = att

	return Wing
end

local function CreateWings(character)
	local torso = character:FindFirstChild("Torso")
		or character:FindFirstChild("UpperTorso")

	if not torso then
		return
	end

	RemoveWings(character)

	if not WingsEnabled then
		return
	end

	local left = Instance.new("Attachment")
	left.Name = "WingLeft"
	left.Position = Vector3.new(-1.8,0.5,0.6)
	left.Parent = torso

	local right = Instance.new("Attachment")
	right.Name = "WingRight"
	right.Position = Vector3.new(1.8,0.5,0.6)
	right.Parent = torso

	LeftWing = CreateWing(left, Enum.NormalId.Back)
	RightWing = CreateWing(right, Enum.NormalId.Front)

	UpdateWingColor()
end
BoxedSection:Toggle({
	Title = "Aura",
	Default = false,

	Callback = function(state)
		AuraEnabled = state

		local character = player.Character
		if not character then
			return
		end

		if state then
			CreateAura(character)
		else
			RemoveAura(character)
		end
	end
})

BoxedSection:Toggle({
	Title = "Wings",
	Default = false,

	Callback = function(state)
		WingsEnabled = state

		local character = player.Character
		if not character then
			return
		end

		if state then
			CreateWings(character)
		else
			RemoveWings(character)
		end
	end
})

BoxedSection:Colorpicker({
	Title = "Aura 1 Color",
	Default = Aura1Color,
	Locked = false,
	Flag = "Aura1_Color",

	Callback = function(color)
		Aura1Color = color
		UpdateAuraColors()
	end
})

BoxedSection:Colorpicker({
	Title = "Aura 2 Color",
	Default = Aura2Color,
	Locked = false,
	Flag = "Aura2_Color",

	Callback = function(color)
		Aura2Color = color
		UpdateAuraColors()
	end
})



BoxedSection:Colorpicker({
	Title = "Wing Color",
	Default = WingColor,
	Locked = false,
	Flag = "Wing_Color",

	Callback = function(color)
		WingColor = color
		UpdateWingColor()
	end
})

local character = player.Character or player.CharacterAdded:Wait()

if AuraEnabled then
	CreateAura(character)
end

if WingsEnabled then
	CreateWings(character)
end

player.CharacterAdded:Connect(function(char)
	task.wait(0.5)

	if AuraEnabled then
		CreateAura(char)
	end

	if WingsEnabled then
		CreateWings(char)
	end
end)
local BoxedSection = Tab:Section({
    Title = " Settings player",
    Box = true,
    BoxBorder = true,
    Icon = "wand-sparkles",
    Opened = false
})
 local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local CrosshairGui
local Crosshair
local RotationConnection

local function CreateCrosshair()
    if CrosshairGui then
        CrosshairGui:Destroy()
    end

    CrosshairGui = Instance.new("ScreenGui")
    CrosshairGui.Name = "CrosshairGUI"
    CrosshairGui.ResetOnSpawn = false
    CrosshairGui.IgnoreGuiInset = true
    CrosshairGui.Parent = player:WaitForChild("PlayerGui")

    Crosshair = Instance.new("Frame")
    Crosshair.Name = "Crosshair"
    Crosshair.Size = UDim2.new(0, 1, 0, 1)
    Crosshair.Position = UDim2.new(0.5, 0, 0.5, 0)
    Crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
    Crosshair.BackgroundTransparency = 1
    Crosshair.Parent = CrosshairGui

    local function CreateLine(size, position)
        local line = Instance.new("Frame")
        line.Size = size
        line.Position = position
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        line.BorderSizePixel = 0
        line.Parent = Crosshair

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = line
    end

    -- บน
    CreateLine(
        UDim2.new(0, 1, 0, 12),
        UDim2.new(0, 0, 0, -10)
    )

    -- ล่าง
    CreateLine(
        UDim2.new(0, 1, 0, 12),
        UDim2.new(0, 0, 0, 10)
    )

    -- ซ้าย
    CreateLine(
        UDim2.new(0, 12, 0, 1),
        UDim2.new(0, -10, 0, 0)
    )

    -- ขวา
    CreateLine(
        UDim2.new(0, 12, 0, 1),
        UDim2.new(0, 10, 0, 0)
    )

    local rotation = 0

    RotationConnection = RunService.RenderStepped:Connect(function(deltaTime)
        if Crosshair and Crosshair.Parent then
            rotation = rotation + (15 * deltaTime)
            Crosshair.Rotation = rotation
        end
    end)
end

local function RemoveCrosshair()
    if RotationConnection then
        RotationConnection:Disconnect()
        RotationConnection = nil
    end

    if CrosshairGui then
        CrosshairGui:Destroy()
        CrosshairGui = nil
        Crosshair = nil
    end
end

BoxedSection:Toggle({
    Title = "Crosshair",
    Callback = function(state)
        if state then
            CreateCrosshair()
        else
            RemoveCrosshair()
        end
    end
})

local Players = game:GetService("Players")

local function WatchPlayer(player)
    if player == Players.LocalPlayer then
        return
    end

    local function SetupCharacter(character)
        local humanoid = character:WaitForChild("Humanoid", 5)
        if not humanoid then
            return
        end

        humanoid.Died:Connect(function()
            local creator = humanoid:FindFirstChild("creator")

            if creator and creator.Value == Players.LocalPlayer then
                WindUI:Notify({
                    Title = "ฆ่า " .. player.Name .. " สำเร็จ",
                    Content = "กำจัด " .. player.Name .. " สำเร็จ",
                    Duration = 3
                })
            end
        end)
    end

    if player.Character then
        SetupCharacter(player.Character)
    end

    player.CharacterAdded:Connect(SetupCharacter)
end

for _, player in ipairs(Players:GetPlayers()) do
    WatchPlayer(player)
end

Players.PlayerAdded:Connect(WatchPlayer)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local HeadHidden = false
local OriginalHeadTransparency = {}

local function SetHeadHidden(state)
    local Character = LocalPlayer.Character
    if not Character then return end

    local Head = Character:FindFirstChild("Head")
    if not Head then return end

    if state then
        if OriginalHeadTransparency[Head] == nil then
            OriginalHeadTransparency[Head] = Head.Transparency
        end

        Head.Transparency = 1
    else
        if OriginalHeadTransparency[Head] ~= nil then
            Head.Transparency = OriginalHeadTransparency[Head]
        else
            Head.Transparency = 0
        end
    end
end

BoxedSection:Toggle({
    Title = "Hide Head",
    Callback = function(state)
        HeadHidden = state
        SetHeadHidden(state)
    end
})

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)

    if HeadHidden then
        SetHeadHidden(true)
    end
end)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Enabled = false
local SelectedColor = Color3.fromRGB(255, 255, 255)
local OriginalMaterials = {}
local OriginalColors = {}
local OriginalHeadTransparency = nil

local function ApplyEffect()
    local Character = LocalPlayer.Character
    if not Character then return end

    for _, Part in ipairs(Character:GetDescendants()) do
        if Part:IsA("BasePart") then
            if OriginalMaterials[Part] == nil then
                OriginalMaterials[Part] = Part.Material
                OriginalColors[Part] = Part.Color
            end

            Part.Material = Enum.Material.ForceField
            Part.Color = SelectedColor
        end
    end

    local Head = Character:FindFirstChild("Head")
    if Head then
        if OriginalHeadTransparency == nil then
            OriginalHeadTransparency = Head.Transparency
        end

        Head.Transparency = 1
    end
end

local function RemoveEffect()
    local Character = LocalPlayer.Character
    if not Character then return end

    for _, Part in ipairs(Character:GetDescendants()) do
        if Part:IsA("BasePart") then
            if OriginalMaterials[Part] then
                Part.Material = OriginalMaterials[Part]
            end

            if OriginalColors[Part] then
                Part.Color = OriginalColors[Part]
            end
        end
    end

    local Head = Character:FindFirstChild("Head")
    if Head and OriginalHeadTransparency ~= nil then
        Head.Transparency = OriginalHeadTransparency
    end

    OriginalMaterials = {}
    OriginalColors = {}
    OriginalHeadTransparency = nil
end

BoxedSection:Toggle({
    Title = "ForceField",
    Callback = function(state)
        Enabled = state

        if state then
            ApplyEffect()
        else
            RemoveEffect()
        end
    end
})

BoxedSection:Colorpicker({
    Title = "ForceField Color",
    Callback = function(color)
        SelectedColor = color

        if Enabled then
            ApplyEffect()
        end
    end
})

LocalPlayer.CharacterAdded:Connect(function()
    OriginalMaterials = {}
    OriginalColors = {}
    OriginalHeadTransparency = nil

    task.wait(0.5)

    if Enabled then
        ApplyEffect()
    end
end)
local BoxedSection = Tab:Section({
    Title = "Display",
    Box = true,
    BoxBorder = true,
    Icon = "sun",
    Opened = false
})
 
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Enabled = false

local DamageGui = Instance.new("ScreenGui")
DamageGui.Name = "MinecraftDamageUI"
DamageGui.ResetOnSpawn = false
DamageGui.IgnoreGuiInset = true
DamageGui.Parent = PlayerGui

local DamageContainer = Instance.new("Frame")
DamageContainer.BackgroundTransparency = 1
DamageContainer.Size = UDim2.new(0, 500, 0, 300)
DamageContainer.Position = UDim2.new(0.61, 0, 0.45, 0)
DamageContainer.AnchorPoint = Vector2.new(0.5, 0.5)
DamageContainer.Parent = DamageGui

local lastHealth = {}

local Colors = {
    Color3.fromRGB(255, 55, 55),
    Color3.fromRGB(25, 25, 25),
    Color3.fromRGB(190, 190, 190)
}

local activePositions = {}

local function getSpreadPosition()
    local positions = {
        {-120, -70},
        {-80, 0},
        {-40, 70},
        {0, -80},
        {0, 0},
        {0, 80},
        {40, -70},
        {80, 0},
        {120, 70}
    }

    for _, position in ipairs(positions) do
        local used = false

        for _, active in ipairs(activePositions) do
            if math.abs(active[1] - position[1]) < 45
            and math.abs(active[2] - position[2]) < 45 then
                used = true
                break
            end
        end

        if not used then
            table.insert(activePositions, position)
            return position[1], position[2]
        end
    end

    local x = math.random(-140, 140)
    local y = math.random(-90, 90)

    table.insert(activePositions, {x, y})

    return x, y
end

local function removeSpreadPosition(x, y)
    for i = #activePositions, 1, -1 do
        if activePositions[i][1] == x
        and activePositions[i][2] == y then
            table.remove(activePositions, i)
            break
        end
    end
end

local function showDamage(damage)
    if not Enabled or damage <= 0 then
        return
    end

    local offsetX, offsetY = getSpreadPosition()

    local DamageFrame = Instance.new("Frame")
    DamageFrame.Name = "DamageNumber"
    DamageFrame.BackgroundTransparency = 1
    DamageFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    DamageFrame.Size = UDim2.new(0, 250, 0, 70)

    DamageFrame.Position = UDim2.new(
        0.5,
        offsetX,
        0.5,
        35 + offsetY
    )

    DamageFrame.Rotation = math.random(-12, -5)
    DamageFrame.Parent = DamageContainer

    local Scale = Instance.new("UIScale")
    Scale.Scale = 0.4
    Scale.Parent = DamageFrame

    local DamageText = tostring(math.floor(damage + 0.5))
    local TextWidth = 42
    local StartX = -((#DamageText - 1) * TextWidth) / 2

    for i = 1, #DamageText do
        local Digit = Instance.new("TextLabel")

        Digit.BackgroundTransparency = 1
        Digit.AnchorPoint = Vector2.new(0.5, 0.5)
        Digit.Size = UDim2.new(0, TextWidth + 8, 0, 70)

        Digit.Position = UDim2.new(
            0.5,
            StartX + ((i - 1) * TextWidth),
            0.5,
            0
        )

        Digit.Text = string.sub(DamageText, i, i)
        Digit.Font = Enum.Font.Arcade
        Digit.TextScaled = true
        Digit.TextColor3 = Colors[((i - 1) % #Colors) + 1]
        Digit.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
        Digit.TextStrokeTransparency = 0.05
        Digit.TextTransparency = 1
        Digit.Rotation = math.random(-5, 5)
        Digit.ZIndex = 2
        Digit.Parent = DamageFrame

        local Shadow = Instance.new("TextLabel")

        Shadow.BackgroundTransparency = 1
        Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
        Shadow.Size = Digit.Size

        Shadow.Position = UDim2.new(
            0.5,
            StartX + ((i - 1) * TextWidth) + 3,
            0.5,
            4
        )

        Shadow.Text = Digit.Text
        Shadow.Font = Enum.Font.Arcade
        Shadow.TextScaled = true
        Shadow.TextColor3 = Color3.fromRGB(0, 0, 0)
        Shadow.TextTransparency = 1
        Shadow.ZIndex = 1
        Shadow.Rotation = Digit.Rotation
        Shadow.Parent = DamageFrame
    end

    local EndPosition = UDim2.new(
        0.5,
        offsetX + math.random(-15, 15),
        0.5,
        offsetY - 20
    )

    local InInfo = TweenInfo.new(
        0.38,
        Enum.EasingStyle.Back,
        Enum.EasingDirection.Out
    )

    TweenService:Create(
        DamageFrame,
        InInfo,
        {
            Position = EndPosition,
            Rotation = math.random(5, 10)
        }
    ):Play()

    TweenService:Create(
        Scale,
        InInfo,
        {Scale = 1}
    ):Play()

    for _, Object in ipairs(DamageFrame:GetChildren()) do
        if Object:IsA("TextLabel") then
            local IsShadow = Object.Name == "Shadow"

            TweenService:Create(
                Object,
                TweenInfo.new(0.22),
                {
                    TextTransparency = IsShadow and 0.35 or 0,
                    TextStrokeTransparency = IsShadow and 1 or 0.05
                }
            ):Play()
        end
    end

    task.delay(2.5, function()
        if not DamageFrame.Parent then
            removeSpreadPosition(offsetX, offsetY)
            return
        end

        local OutInfo = TweenInfo.new(
            0.55,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        )

        TweenService:Create(
            DamageFrame,
            OutInfo,
            {
                Position = EndPosition - UDim2.new(0, 15, 0, 45),
                Rotation = 12
            }
        ):Play()

        TweenService:Create(
            Scale,
            OutInfo,
            {Scale = 0.8}
        ):Play()

        for _, Object in ipairs(DamageFrame:GetChildren()) do
            if Object:IsA("TextLabel") then
                TweenService:Create(
                    Object,
                    OutInfo,
                    {
                        TextTransparency = 1,
                        TextStrokeTransparency = 1
                    }
                ):Play()
            end
        end

        task.wait(0.6)

        removeSpreadPosition(offsetX, offsetY)
        DamageFrame:Destroy()
    end)
end

local function isOurDamage(Humanoid)
    local Character = Humanoid.Parent

    if not Character then
        return false
    end

    local Tags = {
        "creator",
        "Creator",
        "Attacker",
        "attacker",
        "LastAttacker",
        "lastAttacker",
        "DamageDealer",
        "damager"
    }

    for _, TagName in ipairs(Tags) do
        local Tag = Humanoid:FindFirstChild(TagName)
            or Character:FindFirstChild(TagName)

        if Tag then
            if Tag:IsA("ObjectValue") then
                if Tag.Value == LocalPlayer then
                    return true
                end
            elseif Tag:IsA("StringValue") then
                if Tag.Value == LocalPlayer.Name
                or Tag.Value == tostring(LocalPlayer.UserId) then
                    return true
                end
            end
        end
    end

    return false
end

local function watchHumanoid(Humanoid)
    if not Humanoid:IsA("Humanoid") then
        return
    end

    if Humanoid.Parent == LocalPlayer.Character then
        return
    end

    if lastHealth[Humanoid] ~= nil then
        return
    end

    lastHealth[Humanoid] = Humanoid.Health

    Humanoid.HealthChanged:Connect(function(NewHealth)
        local OldHealth = lastHealth[Humanoid]

        if OldHealth == nil then
            lastHealth[Humanoid] = NewHealth
            return
        end

        if NewHealth < OldHealth then
            local Damage = OldHealth - NewHealth

            if Enabled and isOurDamage(Humanoid) then
                showDamage(Damage)
            end
        end

        lastHealth[Humanoid] = NewHealth
    end)

    Humanoid.Destroying:Connect(function()
        lastHealth[Humanoid] = nil
    end)
end

for _, Object in ipairs(workspace:GetDescendants()) do
    if Object:IsA("Humanoid") then
        watchHumanoid(Object)
    end
end

workspace.DescendantAdded:Connect(function(Object)
    if Object:IsA("Humanoid") then
        task.wait()
        watchHumanoid(Object)
    end
end)

BoxedSection:Toggle({
    Title = "Damage Number",
    Callback = function(state)
        Enabled = state

        if not state then
            for _, Object in ipairs(DamageContainer:GetChildren()) do
                if Object:IsA("Frame") then
                    Object:Destroy()
                end
            end

            table.clear(activePositions)
        end
    end
})

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Enabled = false
local Combo = 0
local LastHit = 0
local ComboResetTime = 1.5

local LastHealth = {}
local ActivePositions = {}

local OldGui = PlayerGui:FindFirstChild("DamageComboUI")
if OldGui then
    OldGui:Destroy()
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "DamageComboUI"
Gui.IgnoreGuiInset = true
Gui.ResetOnSpawn = false
Gui.Parent = PlayerGui

local Container = Instance.new("Frame")
Container.Name = "DamageContainer"
Container.BackgroundTransparency = 1
Container.AnchorPoint = Vector2.new(0.5, 0.5)
Container.Position = UDim2.new(0.61, 0, 0.45, 0)
Container.Size = UDim2.fromOffset(440, 260)
Container.ClipsDescendants = false
Container.Parent = Gui

local function makeText(parent, name, text, size, position)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = position
    label.Size = size
    label.Text = text
    label.Font = Enum.Font.LuckiestGuy
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(255, 190, 35)
    label.TextStrokeColor3 = Color3.fromRGB(45, 20, 10)
    label.TextStrokeTransparency = 0
    label.Parent = parent
    return label
end

local function getPosition()
    local slots = {
        {-100, -65}, {-35, -80}, {40, -65},
        {100, -25}, {-95, 15}, {0, 35},
        {95, 35}, {-45, 75}, {45, 75}
    }

    for _, slot in ipairs(slots) do
        local occupied = false

        for _, active in ipairs(ActivePositions) do
            if math.abs(active.x - slot[1]) < 45
                and math.abs(active.y - slot[2]) < 40 then
                occupied = true
                break
            end
        end

        if not occupied then
            local record = {x = slot[1], y = slot[2]}
            table.insert(ActivePositions, record)
            return record
        end
    end

    local record = {
        x = math.random(-110, 110),
        y = math.random(-75, 75)
    }

    table.insert(ActivePositions, record)
    return record
end

local function freePosition(record)
    local index = table.find(ActivePositions, record)
    if index then
        table.remove(ActivePositions, index)
    end
end

local function showDamage(damage)
    if not Enabled or damage <= 0 then
        return
    end

    local now = os.clock()

    if now - LastHit > ComboResetTime then
        Combo = 0
    end

    Combo += 1
    LastHit = now

    local slot = getPosition()

    local frame = Instance.new("Frame")
    frame.Name = "DamageNumber"
    frame.BackgroundTransparency = 1
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Size = UDim2.fromOffset(200, 76)
    frame.Position = UDim2.new(0.5, slot.x, 0.5, slot.y)
    frame.Rotation = math.random(-4, 4)
    frame.Parent = Container

    local scale = Instance.new("UIScale")
    scale.Scale = 0.82
    scale.Parent = frame

    local number = tostring(math.floor(damage + 0.5))
    local digitWidth = 27
    local numberWidth = digitWidth * #number

    for i = 1, #number do
        local digit = makeText(
            frame,
            "Digit" .. i,
            number:sub(i, i),
            UDim2.fromOffset(34, 48),
            UDim2.new(
                0.5,
                -numberWidth / 2 + digitWidth * (i - 0.5),
                0,
                24
            )
        )

        digit.TextTransparency = 1

        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 70)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 105, 20))
        })
        gradient.Rotation = 90
        gradient.Parent = digit
    end

    local comboText = makeText(
        frame,
        "ComboText",
        tostring(Combo) .. " HITS COMBO",
        UDim2.fromOffset(190, 22),
        UDim2.new(0.5, 0, 0, 58)
    )

    comboText.Font = Enum.Font.GothamBlack
    comboText.TextColor3 = Color3.fromRGB(255, 255, 255)
    comboText.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
    comboText.TextStrokeTransparency = 0
    comboText.TextTransparency = 1

    local startPosition = frame.Position

    local endPosition = startPosition - UDim2.fromOffset(
        math.random(-6, 6),
        24
    )

    TweenService:Create(
        frame,
        TweenInfo.new(
            0.45,
            Enum.EasingStyle.Quart,
            Enum.EasingDirection.Out
        ),
        {
            Position = endPosition,
            Rotation = math.random(-3, 3)
        }
    ):Play()

    TweenService:Create(
        scale,
        TweenInfo.new(
            0.4,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        ),
        {Scale = 1}
    ):Play()

    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA("TextLabel") then
            TweenService:Create(
                child,
                TweenInfo.new(
                    0.3,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                ),
                {TextTransparency = 0}
            ):Play()
        end
    end

    task.delay(2.2, function()
        if not frame.Parent then
            freePosition(slot)
            return
        end

        local fadeInfo = TweenInfo.new(
            0.45,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        )

        TweenService:Create(
            frame,
            fadeInfo,
            {
                Position = endPosition - UDim2.fromOffset(0, 24),
                Rotation = 5
            }
        ):Play()

        TweenService:Create(
            scale,
            fadeInfo,
            {Scale = 0.88}
        ):Play()

        for _, child in ipairs(frame:GetChildren()) do
            if child:IsA("TextLabel") then
                TweenService:Create(
                    child,
                    fadeInfo,
                    {
                        TextTransparency = 1,
                        TextStrokeTransparency = 1
                    }
                ):Play()
            end
        end

        task.wait(0.5)
        freePosition(slot)

        if frame.Parent then
            frame:Destroy()
        end
    end)
end

local function isOurDamage(humanoid)
    local character = humanoid.Parent
    if not character then
        return false
    end

    local tags = {
        "creator",
        "Creator",
        "Attacker",
        "attacker",
        "LastAttacker",
        "lastAttacker",
        "DamageDealer",
        "damager"
    }

    for _, name in ipairs(tags) do
        local tag = humanoid:FindFirstChild(name)
            or character:FindFirstChild(name)

        if tag then
            if tag:IsA("ObjectValue") and tag.Value == LocalPlayer then
                return true
            elseif tag:IsA("StringValue") then
                if tag.Value == LocalPlayer.Name
                    or tag.Value == tostring(LocalPlayer.UserId) then
                    return true
                end
            end
        end
    end

    return false
end

local function watchHumanoid(humanoid)
    if not humanoid:IsA("Humanoid") then
        return
    end

    if humanoid.Parent == LocalPlayer.Character then
        return
    end

    if LastHealth[humanoid] ~= nil then
        return
    end

    LastHealth[humanoid] = humanoid.Health

    humanoid.HealthChanged:Connect(function(newHealth)
        local oldHealth = LastHealth[humanoid]

        if oldHealth == nil then
            LastHealth[humanoid] = newHealth
            return
        end

        if newHealth < oldHealth and Enabled and isOurDamage(humanoid) then
            showDamage(oldHealth - newHealth)
        end

        LastHealth[humanoid] = newHealth
    end)

    humanoid.Destroying:Connect(function()
        LastHealth[humanoid] = nil
    end)
end

for _, object in ipairs(workspace:GetDescendants()) do
    if object:IsA("Humanoid") then
        watchHumanoid(object)
    end
end

workspace.DescendantAdded:Connect(function(object)
    if object:IsA("Humanoid") then
        task.defer(watchHumanoid, object)
    end
end)

BoxedSection:Toggle({
    Title = "Damage Number + Combo",
    Callback = function(state)
        Enabled = state

        if not state then
            Combo = 0
            LastHit = 0
            table.clear(ActivePositions)

            for _, object in ipairs(Container:GetChildren()) do
                if object:IsA("Frame") then
                    object:Destroy()
                end
            end
        end
    end
})

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Enabled = false
local Combo = 0
local LastHit = 0
local ComboResetTime = 1.5

local LastHealth = {}
local ActivePositions = {}

local OldGui = PlayerGui:FindFirstChild("DamageComboUI")
if OldGui then
    OldGui:Destroy()
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "DamageComboUI"
Gui.IgnoreGuiInset = true
Gui.ResetOnSpawn = false
Gui.Parent = PlayerGui

local Container = Instance.new("Frame")
Container.Name = "DamageContainer"
Container.BackgroundTransparency = 1
Container.AnchorPoint = Vector2.new(0.5, 0.5)
Container.Position = UDim2.new(0.61, 0, 0.45, 0)
Container.Size = UDim2.fromOffset(440, 260)
Container.ClipsDescendants = false
Container.Parent = Gui

local function makeText(parent, name, text, size, position)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = position
    label.Size = size
    label.Text = text
    label.Font = Enum.Font.LuckiestGuy
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(255, 190, 35)
    label.TextStrokeColor3 = Color3.fromRGB(45, 20, 10)
    label.TextStrokeTransparency = 0
    label.Parent = parent
    return label
end

local function getPosition()
    local slots = {
        {-100, -65}, {-35, -80}, {40, -65},
        {100, -25}, {-95, 15}, {0, 35},
        {95, 35}, {-45, 75}, {45, 75}
    }

    for _, slot in ipairs(slots) do
        local occupied = false

        for _, active in ipairs(ActivePositions) do
            if math.abs(active.x - slot[1]) < 45
                and math.abs(active.y - slot[2]) < 40 then
                occupied = true
                break
            end
        end

        if not occupied then
            local record = {x = slot[1], y = slot[2]}
            table.insert(ActivePositions, record)
            return record
        end
    end

    local record = {
        x = math.random(-110, 110),
        y = math.random(-75, 75)
    }

    table.insert(ActivePositions, record)
    return record
end

local function freePosition(record)
    local index = table.find(ActivePositions, record)
    if index then
        table.remove(ActivePositions, index)
    end
end

local function showDamage(damage)
    if not Enabled or damage <= 0 then
        return
    end

    local now = os.clock()

    if now - LastHit > ComboResetTime then
        Combo = 0
    end

    Combo += 1
    LastHit = now

    local slot = getPosition()

    local frame = Instance.new("Frame")
    frame.Name = "DamageNumber"
    frame.BackgroundTransparency = 1
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Size = UDim2.fromOffset(200, 76)
    frame.Position = UDim2.new(0.5, slot.x, 0.5, slot.y)
    frame.Rotation = math.random(-4, 4)
    frame.Parent = Container

    local scale = Instance.new("UIScale")
    scale.Scale = 0.82
    scale.Parent = frame

    local number = tostring(math.floor(damage + 0.5))
    local digitWidth = 27
    local numberWidth = digitWidth * #number

    for i = 1, #number do
        local digit = makeText(
            frame,
            "Digit" .. i,
            number:sub(i, i),
            UDim2.fromOffset(34, 48),
            UDim2.new(
                0.5,
                -numberWidth / 2 + digitWidth * (i - 0.5),
                0,
                24
            )
        )

        digit.TextTransparency = 1

        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 70)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 105, 20))
        })
        gradient.Rotation = 90
        gradient.Parent = digit
    end

    local comboText = makeText(
        frame,
        "ComboText",
        tostring(Combo) .. " HITS COMBO",
        UDim2.fromOffset(190, 22),
        UDim2.new(0.5, 0, 0, 58)
    )

    comboText.Font = Enum.Font.GothamBlack
    comboText.TextColor3 = Color3.fromRGB(255, 255, 255)
    comboText.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
    comboText.TextStrokeTransparency = 0
    comboText.TextTransparency = 1

    local startPosition = frame.Position

    local endPosition = startPosition - UDim2.fromOffset(
        math.random(-6, 6),
        24
    )

    TweenService:Create(
        frame,
        TweenInfo.new(
            0.45,
            Enum.EasingStyle.Quart,
            Enum.EasingDirection.Out
        ),
        {
            Position = endPosition,
            Rotation = math.random(-3, 3)
        }
    ):Play()

    TweenService:Create(
        scale,
        TweenInfo.new(
            0.4,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        ),
        {Scale = 1}
    ):Play()

    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA("TextLabel") then
            TweenService:Create(
                child,
                TweenInfo.new(
                    0.3,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                ),
                {TextTransparency = 0}
            ):Play()
        end
    end

    task.delay(2.2, function()
        if not frame.Parent then
            freePosition(slot)
            return
        end

        local fadeInfo = TweenInfo.new(
            0.45,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        )

        TweenService:Create(
            frame,
            fadeInfo,
            {
                Position = endPosition - UDim2.fromOffset(0, 24),
                Rotation = 5
            }
        ):Play()

        TweenService:Create(
            scale,
            fadeInfo,
            {Scale = 0.88}
        ):Play()

        for _, child in ipairs(frame:GetChildren()) do
            if child:IsA("TextLabel") then
                TweenService:Create(
                    child,
                    fadeInfo,
                    {
                        TextTransparency = 1,
                        TextStrokeTransparency = 1
                    }
                ):Play()
            end
        end

        task.wait(0.5)
        freePosition(slot)

        if frame.Parent then
            frame:Destroy()
        end
    end)
end

local function isOurDamage(humanoid)
    local character = humanoid.Parent
    if not character then
        return false
    end

    local tags = {
        "creator",
        "Creator",
        "Attacker",
        "attacker",
        "LastAttacker",
        "lastAttacker",
        "DamageDealer",
        "damager"
    }

    for _, name in ipairs(tags) do
        local tag = humanoid:FindFirstChild(name)
            or character:FindFirstChild(name)

        if tag then
            if tag:IsA("ObjectValue") and tag.Value == LocalPlayer then
                return true
            elseif tag:IsA("StringValue") then
                if tag.Value == LocalPlayer.Name
                    or tag.Value == tostring(LocalPlayer.UserId) then
                    return true
                end
            end
        end
    end

    return false
end

local function watchHumanoid(humanoid)
    if not humanoid:IsA("Humanoid") then
        return
    end

    if humanoid.Parent == LocalPlayer.Character then
        return
    end

    if LastHealth[humanoid] ~= nil then
        return
    end

    LastHealth[humanoid] = humanoid.Health

    humanoid.HealthChanged:Connect(function(newHealth)
        local oldHealth = LastHealth[humanoid]

        if oldHealth == nil then
            LastHealth[humanoid] = newHealth
            return
        end

        if newHealth < oldHealth and Enabled and isOurDamage(humanoid) then
            showDamage(oldHealth - newHealth)
        end

        LastHealth[humanoid] = newHealth
    end)

    humanoid.Destroying:Connect(function()
        LastHealth[humanoid] = nil
    end)
end

for _, object in ipairs(workspace:GetDescendants()) do
    if object:IsA("Humanoid") then
        watchHumanoid(object)
    end
end

workspace.DescendantAdded:Connect(function(object)
    if object:IsA("Humanoid") then
        task.defer(watchHumanoid, object)
    end
end)

BoxedSection:Toggle({
    Title = "Damage Number + Combo",
    Callback = function(state)
        Enabled = state

        if not state then
            Combo = 0
            LastHit = 0
            table.clear(ActivePositions)

            for _, object in ipairs(Container:GetChildren()) do
                if object:IsA("Frame") then
                    object:Destroy()
                end
            end
        end
    end
})
Window:EditOpenButton({
    Title = "Open Example UI",
    Icon = "rbxassetid://131288947379751",
    CornerRadius = UDim.new(25,50),
    StrokeThickness = 0
,
    Color = ColorSequence.new( -- gradient
        Color3.fromHex("DCDCDC"), 
        Color3.fromHex("DCDCDC")
    ),
    OnlyMobile = false,
    Enabled = true,
    Draggable = true,
})
