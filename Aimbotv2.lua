--[[
╔══════════════════════════════════════════════════════════════════╗
║              IRA RESUMMON — Universal Keyless Hub               ║
║          UI: Vape UI Library | Toggle: Right Shift              ║
╠══════════════════════════════════════════════════════════════════╣
║  COMBAT   · Aimbot · FOV · Wall Check · Smooth                  ║
║  VISUALS  · ESP · Fullbright · Snow · FOV · First Person        ║
║  MOVEMENT · Fly · Noclip · WalkSpeed · JumpPower · TP           ║
║  UTILITY  · Anti-AFK · Anti-Fling · Server Hop · Auto-Rejoin    ║
║  PERF     · Anti-Lag · Shadows · FPS Cap · Low Graphics         ║
╚══════════════════════════════════════════════════════════════════╝
--]]

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP PREVIOUS INSTANCE
-- ═══════════════════════════════════════════════════════════════
if _G.IraRunning then
    _G.IraRunning = false
    wait(0.15)
end
if _G.IraConnections then
    for _, c in ipairs(_G.IraConnections) do pcall(function() c:Disconnect() end) end
end
if _G.IraDrawings then
    for _, d in ipairs(_G.IraDrawings) do pcall(function() d:Remove() end) end
end
if _G.IraHighlights then
    for _, h in ipairs(_G.IraHighlights) do pcall(function() h:Destroy() end) end
end
for _, c in ipairs(game:GetService("CoreGui"):GetChildren()) do
    if c.Name == "ui" or c.Name:find("Ira") then pcall(function() c:Destroy() end) end
end

_G.IraRunning     = true
_G.IraConnections = {}
_G.IraDrawings    = {}
_G.IraHighlights  = {}

-- ═══════════════════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════════════════
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local HttpService        = game:GetService("HttpService")
local TeleportService    = game:GetService("TeleportService")
local StarterGui         = game:GetService("StarterGui")
local Lighting           = game:GetService("Lighting")
local SoundService       = game:GetService("SoundService")

local LocalPlayer        = Players.LocalPlayer
local Camera             = workspace.CurrentCamera
local CoreGui            = game:GetService("CoreGui")

-- ═══════════════════════════════════════════════════════════════
-- STATE TABLE
-- ═══════════════════════════════════════════════════════════════
local Cfg = {
    -- AIMBOT
    AimbotEnabled   = false,
    AimbotSmooth    = 0.15,
    AimbotFOV       = 120,
    AimbotPart      = "Head",
    AimbotTeamCheck = true,
    AimbotWallCheck = false,
    AimbotFOVCircle = true,
    AimbotPrediction= false,
    AimbotKey       = "RMB", -- "RMB" or "LAlt"

    -- ESP
    ESPEnabled      = false,
    ESPBoxEnabled   = false,
    ESPBoxFull      = true,
    ESPBoxCorner    = false,
    ESPBoxFilled    = false,
    ESPOutline      = false,
    ESPName         = true,
    ESPDistance     = false,
    ESPHealthBar    = false,
    ESPTeammates    = false,
    ESPTeamCheck    = false,
    ESPMaxDist      = 500,
    ESPRainbow      = false,
    ESPColor        = Color3.fromRGB(0, 200, 255),
    ESPTracers      = false,
    ESPTracerOrigin = "Bottom", -- "Bottom", "Top", "Center", "Mouse"

    -- VISUALS
    Fullbright      = false,
    OrigBrightness  = Lighting.Brightness,
    OrigAmbient     = Lighting.Ambient,
    OrigOutdoor     = Lighting.OutdoorAmbient,
    CustomFOV       = false,
    FOVValue        = 70,
    OrigFOV         = Camera.FieldOfView,
    Snow            = false,
    HideCursor      = false,
    FirstPerson     = false,

    -- MOVEMENT
    Fly             = false,
    FlySpeed        = 50,
    Noclip          = false,
    WalkSpeed       = 16,
    JumpPower       = 50,
    InfiniteJump    = false,
    TpBackPos       = nil,

    -- PERFORMANCE
    AntiLag         = false,
    Shadows         = true,
    FPSCap          = false,
    FPSCapValue     = 60,
    LowGraphics     = false,
    OrigGraphics    = settings().Rendering.QualityLevel,

    -- UTILITY
    AntiAFK         = true,
    AntiFling       = false,
    AutoRejoin      = false,
}

-- ═══════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════
local function rainbow() return Color3.fromHSV((tick() * 0.4) % 1, 1, 1) end
local function nD(t, p) local d = Drawing.new(t); for k,v in pairs(p or {}) do d[k]=v end; table.insert(_G.IraDrawings, d); return d end

local function getChar(p) return p and p.Character end
local function getRoot(p) local c = getChar(p); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum(p)  local c = getChar(p); return c and c:FindFirstChildOfClass("Humanoid") end

local function w2s(pos)
    local s, _, iv = Camera:WorldToViewportPoint(pos)
    return Vector2.new(s.X, s.Y), iv
end

local function isEnemy(p)
    if not Cfg.ESPTeamCheck then return true end
    return p.Team ~= LocalPlayer.Team
end

local function inDist(root)
    local mr = getRoot(LocalPlayer)
    return mr and root and (root.Position - mr.Position).Magnitude <= Cfg.ESPMaxDist
end

local function hasLOS(from, to)
    local ray = workspace:Raycast(from, (to - from).Unit * (to - from).Magnitude,
        RaycastParams.new())
    return not ray
end

local function getBBox(player)
    local char = getChar(player)
    if not char then return nil end
    local mn2, mn2y, mx2, mx2y = math.huge, math.huge, -math.huge, -math.huge
    local valid = false
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            local cf, sz = part.CFrame, part.Size / 2
            for _, corner in ipairs({
                cf*Vector3.new( sz.X, sz.Y, sz.Z), cf*Vector3.new(-sz.X, sz.Y, sz.Z),
                cf*Vector3.new( sz.X,-sz.Y, sz.Z), cf*Vector3.new(-sz.X,-sz.Y, sz.Z),
                cf*Vector3.new( sz.X, sz.Y,-sz.Z), cf*Vector3.new(-sz.X, sz.Y,-sz.Z),
                cf*Vector3.new( sz.X,-sz.Y,-sz.Z), cf*Vector3.new(-sz.X,-sz.Y,-sz.Z),
            }) do
                -- WorldToViewportPoint returns Vector3(screenX, screenY, depth), depth, inView
                local sv = Camera:WorldToViewportPoint(corner)
                -- sv is a Vector3: .X = screenX, .Y = screenY, .Z = depth
                -- Skip corners behind the camera (negative depth)
                if sv.Z <= 0 then continue end
                if sv.X < mn2  then mn2  = sv.X end
                if sv.Y < mn2y then mn2y = sv.Y end
                if sv.X > mx2  then mx2  = sv.X end
                if sv.Y > mx2y then mx2y = sv.Y end
                valid = true
            end
        end
    end
    if not valid then return nil end
    return mn2, mn2y, mx2, mx2y
end

-- ═══════════════════════════════════════════════════════════════
-- ESP ENGINE
-- ═══════════════════════════════════════════════════════════════
local ESPObjects = {}

local function mkESP(p)
    if ESPObjects[p] then return end
    local d = {}
    d.BL = {}; for i=1,4 do d.BL[i] = nD("Line",{Visible=false,Color=Cfg.ESPColor,Thickness=1.5,ZIndex=3}) end
    d.CL = {}; for i=1,8 do d.CL[i] = nD("Line",{Visible=false,Color=Cfg.ESPColor,Thickness=1.5,ZIndex=3}) end
    d.FB  = nD("Square",{Visible=false,Color=Cfg.ESPColor,Filled=true,Transparency=0.7,ZIndex=2})
    d.NT  = nD("Text",{Visible=false,Color=Color3.fromRGB(255,255,255),Text=p.Name,Size=13,Font=2,Center=true,Outline=true,OutlineColor=Color3.fromRGB(0,0,0),ZIndex=5})
    d.DT  = nD("Text",{Visible=false,Color=Color3.fromRGB(200,200,200),Text="0m",Size=11,Font=2,Center=true,Outline=true,OutlineColor=Color3.fromRGB(0,0,0),ZIndex=5})
    d.HBb = nD("Square",{Visible=false,Color=Color3.fromRGB(0,0,0),Filled=true,Transparency=0.5,ZIndex=4})
    d.HBf = nD("Square",{Visible=false,Color=Color3.fromRGB(80,255,80),Filled=true,Transparency=0,ZIndex=4})
    d.TR  = nD("Line",{Visible=false,Color=Cfg.ESPColor,Thickness=1,ZIndex=3})
    -- 3D outline via SelectionBox
    local sb = Instance.new("SelectionBox")
    sb.SurfaceTransparency = 1; sb.LineThickness = 0.04
    sb.Color3 = Cfg.ESPColor; sb.SurfaceColor3 = Cfg.ESPColor
    sb.Parent = workspace
    d.SB = sb
    table.insert(_G.IraHighlights, sb)
    ESPObjects[p] = d
end

local function rmESP(p)
    local d = ESPObjects[p]; if not d then return end
    for _, v in pairs(d) do
        if type(v) == "table" then for _, l in ipairs(v) do pcall(function() l:Remove() end) end
        elseif typeof(v) == "Instance" then pcall(function() v:Destroy() end)
        else pcall(function() v:Remove() end) end
    end
    ESPObjects[p] = nil
end

-- ═══════════════════════════════════════════════════════════════
-- AIMBOT ENGINE
-- ═══════════════════════════════════════════════════════════════
local fovCircle = nD("Circle",{Visible=false,Color=Color3.fromRGB(220,220,220),Thickness=1,Filled=false,Transparency=0,NumSides=64,ZIndex=10})
local prevPos   = {}

local function getTarget()
    local vp  = Camera.ViewportSize
    local ctr = Vector2.new(vp.X/2, vp.Y/2)
    local bestD, bestP = Cfg.AimbotFOV, nil

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if Cfg.AimbotTeamCheck and p.Team == LocalPlayer.Team then continue end
        local char = getChar(p); if not char then continue end
        local hum  = getHum(p);  if not hum or hum.Health <= 0 then continue end
        local part = char:FindFirstChild(Cfg.AimbotPart) or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end
        local s, iv = w2s(part.Position)
        if not iv then continue end
        if Cfg.AimbotWallCheck then
            if not hasLOS(Camera.CFrame.Position, part.Position) then continue end
        end
        local d = (s - ctr).Magnitude
        if d < bestD then bestD = d; bestP = part end
    end
    return bestP
end

local function predict(part, player)
    local cur  = part.Position
    if not Cfg.AimbotPrediction then return cur end
    local prev = prevPos[player]
    prevPos[player] = cur
    if not prev then return cur end
    return cur + (cur - prev) * 3
end

-- ═══════════════════════════════════════════════════════════════
-- MOVEMENT STATE
-- ═══════════════════════════════════════════════════════════════
local flyBodyVelocity  = nil
local flyBodyGyro      = nil
local noclipConn       = nil

local function enableFly()
    local char = getChar(LocalPlayer)
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum  = getHum(LocalPlayer)
    if hum then hum.PlatformStand = true end

    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.Velocity        = Vector3.zero
    flyBodyVelocity.MaxForce        = Vector3.new(1e6,1e6,1e6)
    flyBodyVelocity.Parent          = hrp

    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.MaxTorque           = Vector3.new(1e6,1e6,1e6)
    flyBodyGyro.D                   = 50
    flyBodyGyro.CFrame              = hrp.CFrame
    flyBodyGyro.Parent              = hrp
end

local function disableFly()
    local char = getChar(LocalPlayer)
    local hum  = getHum(LocalPlayer)
    if hum then hum.PlatformStand = false end
    if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
    if flyBodyGyro     then flyBodyGyro:Destroy();     flyBodyGyro     = nil end
end

local function enableNoclip()
    noclipConn = RunService.Stepped:Connect(function()
        if not Cfg.Noclip then return end
        local char = getChar(LocalPlayer)
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
    table.insert(_G.IraConnections, noclipConn)
end

-- ═══════════════════════════════════════════════════════════════
-- PERFORMANCE HELPERS
-- ═══════════════════════════════════════════════════════════════
local function applyLowGraphics(on)
    if on then
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e8
    else
        pcall(function() settings().Rendering.QualityLevel = Cfg.OrigGraphics end)
        Lighting.GlobalShadows = Cfg.Shadows
    end
end

local function setFPSCap(on, cap)
    if on then
        setfpscap(cap)
    else
        pcall(function() setfpscap(9999) end)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- SNOW PARTICLES
-- ═══════════════════════════════════════════════════════════════
local snowGui = nil
local function toggleSnow(on)
    if snowGui then snowGui:Destroy(); snowGui = nil end
    if not on then return end
    snowGui = Instance.new("ScreenGui")
    snowGui.Name = "IraSnow"
    snowGui.IgnoreGuiInset = true
    snowGui.ResetOnSpawn = false
    snowGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local targetParent = (gethui and gethui()) or LocalPlayer:FindFirstChild("PlayerGui")
    snowGui.Parent = targetParent

    for i = 1, 60 do
        local f = Instance.new("Frame")
        f.BackgroundColor3 = Color3.fromRGB(255,255,255)
        f.BackgroundTransparency = math.random(0,40)/100
        f.BorderSizePixel = 0
        local sz = math.random(2,5)
        f.Size = UDim2.fromOffset(sz, sz)
        f.Position = UDim2.fromScale(math.random(), 0)
        f.Parent = snowGui
        coroutine.wrap(function()
            local speed = math.random(60,160)
            local drift = math.random(-30,30)
            while snowGui and snowGui.Parent and Cfg.Snow do
                local dt = 1/60
                local xp = f.Position.X.Scale + (drift*dt)/workspace.CurrentCamera.ViewportSize.X
                local yp = f.Position.Y.Scale + (speed*dt)/workspace.CurrentCamera.ViewportSize.Y
                if yp > 1 then yp = 0; xp = math.random() end
                f.Position = UDim2.new(xp,0,yp,0)
                RunService.Heartbeat:Wait()
            end
        end)()
    end
end

-- ═══════════════════════════════════════════════════════════════
-- STATS DRAWING (FPS / Ping / Uptime)
-- ═══════════════════════════════════════════════════════════════
local statsLabel = nD("Text",{
    Visible  = false,
    Color    = Color3.fromRGB(0,220,255),
    Text     = "FPS: 0 | Ping: 0ms | Up: 0s",
    Size     = 13,
    Font     = 2,
    Outline  = true,
    OutlineColor = Color3.fromRGB(0,0,0),
    ZIndex   = 8,
    Position = Vector2.new(6, 6),
})
local startTime    = tick()
local frameCount   = 0
local lastFPSTime  = tick()
local currentFPS   = 0

-- ═══════════════════════════════════════════════════════════════
-- ANTI-FLING ENGINE
-- ═══════════════════════════════════════════════════════════════
local function setupAntiFling()
    local char = getChar(LocalPlayer)
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(0,0,0)
    bv.Parent   = hrp
    _G.IraAntiFlingBV = bv
end
local function disableAntiFling()
    if _G.IraAntiFlingBV then
        pcall(function() _G.IraAntiFlingBV:Destroy() end)
        _G.IraAntiFlingBV = nil
    end
end

-- ═══════════════════════════════════════════════════════════════
-- MAIN RENDER LOOP
-- ═══════════════════════════════════════════════════════════════
enableNoclip()

local mainConn = RunService.RenderStepped:Connect(function(dt)
    if not _G.IraRunning then return end

    local vp  = Camera.ViewportSize
    local ctr = Vector2.new(vp.X/2, vp.Y/2)
    local rb  = rainbow()

    -- Stats
    frameCount = frameCount + 1
    if tick() - lastFPSTime >= 1 then
        currentFPS = frameCount
        frameCount = 0
        lastFPSTime = tick()
    end
    local uptime = math.floor(tick() - startTime)
    local pingVal = 0
    pcall(function() pingVal = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
    if statsLabel.Visible then
        statsLabel.Text = string.format("FPS: %d | Ping: %dms | Up: %ds", currentFPS, pingVal, uptime)
    end

    -- FOV circle
    fovCircle.Position = ctr
    fovCircle.Radius   = Cfg.AimbotFOV

    -- AIMBOT
    if Cfg.AimbotEnabled then
        local keyHeld = false
        if Cfg.AimbotKey == "RMB" then
            keyHeld = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        else
            keyHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
        end

        if keyHeld then
            local targetPart = getTarget()
            if targetPart then
                local owner = nil
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character and p.Character:IsAncestorOf(targetPart) then owner = p; break end
                end
                local aimPos = predict(targetPart, owner)
                -- mousemoverel is the only real approach: Camera.CFrame gets
                -- overwritten every frame by Roblox's own camera controller.
                -- Moving the mouse physically is what the camera script reacts to.
                local screenPos, inView = w2s(aimPos)
                if inView then
                    local delta  = screenPos - ctr
                    local factor = math.clamp(1 - Cfg.AimbotSmooth, 0.05, 1.0)
                    pcall(function()
                        mousemoverel(delta.X * factor, delta.Y * factor)
                    end)
                end
            end
        end
    end

    -- ESP
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then
            if ESPObjects[p] then rmESP(p) end
            continue
        end

        if not ESPObjects[p] then mkESP(p) end
        local d = ESPObjects[p]; if not d then continue end

        local root = getRoot(p)
        local hum  = getHum(p)
        local show = Cfg.ESPEnabled and root and hum and hum.Health > 0
                     and inDist(root)
                     and (Cfg.ESPTeammates or isEnemy(p))

        if not show then
            for _, v in pairs(d) do
                if type(v) == "table" then for _, l in ipairs(v) do if l.Visible then l.Visible = false end end
                elseif typeof(v) == "Instance" then v.Adornee = nil
                else if v.Visible then v.Visible = false end end
            end
            continue
        end

        local mr   = getRoot(LocalPlayer)
        local dist = mr and math.floor((root.Position - mr.Position).Magnitude) or 0
        local bC   = Cfg.ESPRainbow and rb or Cfg.ESPColor
        local x1, y1, x2, y2 = getBBox(p)
        local bv   = x1 ~= nil

        -- Box lines
        if Cfg.ESPBoxEnabled and Cfg.ESPBoxFull and bv then
            d.BL[1].From=Vector2.new(x1,y1); d.BL[1].To=Vector2.new(x2,y1); d.BL[1].Color=bC; d.BL[1].Visible=true
            d.BL[2].From=Vector2.new(x1,y2); d.BL[2].To=Vector2.new(x2,y2); d.BL[2].Color=bC; d.BL[2].Visible=true
            d.BL[3].From=Vector2.new(x1,y1); d.BL[3].To=Vector2.new(x1,y2); d.BL[3].Color=bC; d.BL[3].Visible=true
            d.BL[4].From=Vector2.new(x2,y1); d.BL[4].To=Vector2.new(x2,y2); d.BL[4].Color=bC; d.BL[4].Visible=true
        else for _, l in ipairs(d.BL) do l.Visible=false end end

        -- Corner box
        local cLn = bv and (x2-x1)*0.22 or 0
        local cHt = bv and (y2-y1)*0.22 or 0
        if Cfg.ESPBoxEnabled and Cfg.ESPBoxCorner and bv then
            d.CL[1].From=Vector2.new(x1,y1); d.CL[1].To=Vector2.new(x1+cLn,y1); d.CL[1].Color=bC; d.CL[1].Visible=true
            d.CL[2].From=Vector2.new(x1,y1); d.CL[2].To=Vector2.new(x1,y1+cHt); d.CL[2].Color=bC; d.CL[2].Visible=true
            d.CL[3].From=Vector2.new(x2,y1); d.CL[3].To=Vector2.new(x2-cLn,y1); d.CL[3].Color=bC; d.CL[3].Visible=true
            d.CL[4].From=Vector2.new(x2,y1); d.CL[4].To=Vector2.new(x2,y1+cHt); d.CL[4].Color=bC; d.CL[4].Visible=true
            d.CL[5].From=Vector2.new(x1,y2); d.CL[5].To=Vector2.new(x1+cLn,y2); d.CL[5].Color=bC; d.CL[5].Visible=true
            d.CL[6].From=Vector2.new(x1,y2); d.CL[6].To=Vector2.new(x1,y2-cHt); d.CL[6].Color=bC; d.CL[6].Visible=true
            d.CL[7].From=Vector2.new(x2,y2); d.CL[7].To=Vector2.new(x2-cLn,y2); d.CL[7].Color=bC; d.CL[7].Visible=true
            d.CL[8].From=Vector2.new(x2,y2); d.CL[8].To=Vector2.new(x2,y2-cHt); d.CL[8].Color=bC; d.CL[8].Visible=true
        else for _, l in ipairs(d.CL) do l.Visible=false end end

        -- Filled box
        if Cfg.ESPBoxEnabled and Cfg.ESPBoxFilled and bv then
            d.FB.Position=Vector2.new(x1,y1); d.FB.Size=Vector2.new(x2-x1,y2-y1); d.FB.Color=bC; d.FB.Transparency=0.75; d.FB.Visible=true
        else d.FB.Visible=false end

        -- Outline (3D SelectionBox)
        if Cfg.ESPOutline and p.Character then
            d.SB.Adornee = p.Character; d.SB.Color3 = bC; d.SB.SurfaceColor3 = bC
        else d.SB.Adornee = nil end

        -- Name (uses HRP fallback if no bounding box)
        if Cfg.ESPName then
            local nPos
            if bv then
                nPos = Vector2.new((x1+x2)/2, y1 - 17)
            else
                local sv = Camera:WorldToViewportPoint(root.Position)
                if sv.Z > 0 then nPos = Vector2.new(sv.X, sv.Y - 30) end
            end
            if nPos then
                d.NT.Text = p.Name; d.NT.Position = nPos; d.NT.Visible = true
            else d.NT.Visible = false end
        else d.NT.Visible = false end

        -- Distance (uses HRP fallback if no bounding box)
        if Cfg.ESPDistance then
            local dPos
            if bv then
                dPos = Vector2.new((x1+x2)/2, y2 + 3)
            else
                local sv = Camera:WorldToViewportPoint(root.Position)
                if sv.Z > 0 then dPos = Vector2.new(sv.X, sv.Y + 16) end
            end
            if dPos then
                d.DT.Text = dist.."m"; d.DT.Position = dPos; d.DT.Visible = true
            else d.DT.Visible = false end
        else d.DT.Visible = false end


        -- Health bar
        local hp = hum.Health; local mhp = hum.MaxHealth; local hpr = mhp > 0 and hp/mhp or 0
        local hpC = Color3.fromRGB(math.floor(255*(1-hpr)), math.floor(255*hpr), 40)
        if Cfg.ESPHealthBar and bv then
            local bW = 3; local bH = y2-y1
            d.HBb.Position=Vector2.new(x1-bW-3,y1); d.HBb.Size=Vector2.new(bW,bH); d.HBb.Visible=true
            d.HBf.Position=Vector2.new(x1-bW-3,y1+bH*(1-hpr)); d.HBf.Size=Vector2.new(bW,bH*hpr); d.HBf.Color=hpC; d.HBf.Visible=true
        else d.HBb.Visible=false; d.HBf.Visible=false end
        
        -- Tracers
        if Cfg.ESPTracers then
            local tPos
            if bv then
                tPos = Vector2.new((x1+x2)/2, y2) -- Bottom of box
            else
                local sv = Camera:WorldToViewportPoint(root.Position)
                if sv.Z > 0 then tPos = Vector2.new(sv.X, sv.Y) end
            end
            
            if tPos then
                local origin = Vector2.new(vp.X/2, vp.Y)
                if Cfg.ESPTracerOrigin == "Top" then origin = Vector2.new(vp.X/2, 0)
                elseif Cfg.ESPTracerOrigin == "Center" then origin = Vector2.new(vp.X/2, vp.Y/2)
                elseif Cfg.ESPTracerOrigin == "Mouse" then 
                    local ms = UserInputService:GetMouseLocation()
                    origin = Vector2.new(ms.X, ms.Y)
                end
                
                d.TR.From = origin
                d.TR.To = tPos
                d.TR.Color = bC
                d.TR.Visible = true
            else
                d.TR.Visible = false
            end
        else
            d.TR.Visible = false
        end
    end

    -- FLY
    if Cfg.Fly and flyBodyVelocity then
        local cf = Camera.CFrame
        local vel = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel = vel + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel = vel - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel = vel - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel = vel + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.new(0,1,0) end
        flyBodyVelocity.Velocity = vel * Cfg.FlySpeed
        flyBodyGyro.CFrame       = cf
    end

    -- Custom FOV
    if Cfg.CustomFOV then
        Camera.FieldOfView = Cfg.FOVValue
    end

    -- Hide cursor
    if Cfg.HideCursor then
        pcall(function() UserInputService.MouseIconEnabled = false end)
    end

    -- First person
    if Cfg.FirstPerson then
        Camera.CameraMinZoomDistance = 0
        Camera.CameraMaxZoomDistance = 0
    end
end)
table.insert(_G.IraConnections, mainConn)

-- Infinite Jump
local jumpConn = UserInputService.JumpRequest:Connect(function()
    if not Cfg.InfiniteJump then return end
    local hum = getHum(LocalPlayer)
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)
table.insert(_G.IraConnections, jumpConn)

-- WalkSpeed / JumpPower enforcer (Heartbeat)
local moveConn = RunService.Heartbeat:Connect(function()
    if not _G.IraRunning then return end
    local hum = getHum(LocalPlayer)
    if not hum then return end
    hum.WalkSpeed = Cfg.WalkSpeed
    hum.JumpPower = Cfg.JumpPower
end)
table.insert(_G.IraConnections, moveConn)

-- Anti-AFK
local afkConn = LocalPlayer.Idled:Connect(function()
    if not Cfg.AntiAFK then return end
    local vu = game:GetService("VirtualUser")
    vu:Button2Down(Vector2.zero, workspace.CurrentCamera.CFrame)
    wait(1)
    vu:Button2Up(Vector2.zero, workspace.CurrentCamera.CFrame)
end)
table.insert(_G.IraConnections, afkConn)

-- Player cleanup
table.insert(_G.IraConnections, Players.PlayerRemoving:Connect(rmESP))

-- ═══════════════════════════════════════════════════════════════
-- VAPE UI — WINDOW
-- ═══════════════════════════════════════════════════════════════
local VapeLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/GhostDuckyy/UI-Libraries/main/Vape%20ui%20lib/source.lua"))()
local Window  = VapeLib:Window("Ira Resummon", Color3.fromRGB(0, 200, 255), Enum.KeyCode.RightShift)

-- ─────────────────────────────────────────────
-- TAB 1: COMBAT (Aimbot)
-- ─────────────────────────────────────────────
local CombatTab = Window:Tab("Combat")

CombatTab:Toggle("Aimbot", false, function(s)
    Cfg.AimbotEnabled = s
    fovCircle.Visible = s or Cfg.AimbotFOVCircle
end)

CombatTab:Toggle("Hold RMB to Aim (else LAlt)", true, function(s)
    Cfg.AimbotKey = s and "RMB" or "LAlt"
end)

CombatTab:Toggle("Team Check", true, function(s)
    Cfg.AimbotTeamCheck = s
end)

CombatTab:Toggle("Wall Check (LOS)", false, function(s)
    Cfg.AimbotWallCheck = s
end)

CombatTab:Toggle("Prediction (Lead Targets)", false, function(s)
    Cfg.AimbotPrediction = s
end)

CombatTab:Toggle("Show FOV Circle", true, function(s)
    Cfg.AimbotFOVCircle = s
    fovCircle.Visible = s
end)

CombatTab:Dropdown("Aim Priority Part", {"Head", "HumanoidRootPart"}, function(sel)
    Cfg.AimbotPart = sel
end)

CombatTab:Slider("FOV Radius", 20, 500, 120, function(v)
    Cfg.AimbotFOV = v
end)

CombatTab:Slider("Smooth (0=Snap 10=Slow)", 0, 10, 2, function(v)
    Cfg.AimbotSmooth = v == 0 and 0.01 or (v/10)*0.95
end)

-- ─────────────────────────────────────────────
-- TAB 2: VISUALS (ESP)
-- ─────────────────────────────────────────────
local VisTab = Window:Tab("Visuals")

VisTab:Toggle("ESP Enabled", false, function(s)
    Cfg.ESPEnabled = s
end)

VisTab:Toggle("Box ESP", false, function(s)
    Cfg.ESPBoxEnabled = s; if s then Cfg.ESPBoxFull = true end
end)

VisTab:Toggle("Full Box", true, function(s)
    Cfg.ESPBoxFull = s; Cfg.ESPBoxCorner = not s
end)

VisTab:Toggle("Corner Box", false, function(s)
    Cfg.ESPBoxCorner = s; Cfg.ESPBoxFull = not s
end)

VisTab:Toggle("Filled Box", false, function(s)
    Cfg.ESPBoxFilled = s
end)

VisTab:Toggle("3D Outline (SelectionBox)", false, function(s)
    Cfg.ESPOutline = s
    if not s then for _, d in pairs(ESPObjects) do if d.SB then d.SB.Adornee = nil end end end
end)

VisTab:Toggle("Names", true, function(s)
    Cfg.ESPName = s
end)

VisTab:Toggle("Distance", false, function(s)
    Cfg.ESPDistance = s
end)

VisTab:Toggle("Health Bar", false, function(s)
    Cfg.ESPHealthBar = s
end)

VisTab:Toggle("Show Teammates", false, function(s)
    Cfg.ESPTeammates = s
end)

VisTab:Toggle("Team Check (Hide Enemies Only)", false, function(s)
    Cfg.ESPTeamCheck = s
end)

VisTab:Toggle("Rainbow ESP", false, function(s)
    Cfg.ESPRainbow = s
end)

VisTab:Toggle("Tracers", false, function(s)
    Cfg.ESPTracers = s
end)

VisTab:Dropdown("Tracer Origin", {"Bottom", "Top", "Center", "Mouse"}, function(sel)
    Cfg.ESPTracerOrigin = sel
end)

VisTab:Slider("Max Distance", 50, 2000, 500, function(v)
    Cfg.ESPMaxDist = v
end)

VisTab:Toggle("Fullbright", false, function(s)
    Cfg.Fullbright = s
    if s then
        Lighting.Brightness      = 10
        Lighting.Ambient         = Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient  = Color3.fromRGB(255,255,255)
    else
        Lighting.Brightness      = Cfg.OrigBrightness
        Lighting.Ambient         = Cfg.OrigAmbient
        Lighting.OutdoorAmbient  = Cfg.OrigOutdoor
    end
end)

VisTab:Toggle("Snow Effect", false, function(s)
    Cfg.Snow = s
    toggleSnow(s)
end)

VisTab:Toggle("Custom FOV", false, function(s)
    Cfg.CustomFOV = s
    if not s then Camera.FieldOfView = Cfg.OrigFOV end
end)

VisTab:Slider("FOV Value", 30, 140, 70, function(v)
    Cfg.FOVValue = v
end)

VisTab:Toggle("Hide Cursor", false, function(s)
    Cfg.HideCursor = s
    if not s then pcall(function() UserInputService.MouseIconEnabled = true end) end
end)

VisTab:Toggle("Force First Person", false, function(s)
    Cfg.FirstPerson = s
    if not s then
        Camera.CameraMinZoomDistance = 0
        Camera.CameraMaxZoomDistance = 400
    end
end)

VisTab:Toggle("FPS / Ping / Uptime HUD", false, function(s)
    statsLabel.Visible = s
end)

-- ─────────────────────────────────────────────
-- TAB 3: MOVEMENT
-- ─────────────────────────────────────────────
local MoveTab = Window:Tab("Movement")

MoveTab:Toggle("Fly", false, function(s)
    Cfg.Fly = s
    if s then enableFly() else disableFly() end
end)

MoveTab:Slider("Fly Speed", 5, 250, 50, function(v)
    Cfg.FlySpeed = v
end)

MoveTab:Toggle("Noclip", false, function(s)
    Cfg.Noclip = s
    if not s then
        -- restore collision
        local char = getChar(LocalPlayer)
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
    end
end)

MoveTab:Slider("WalkSpeed", 16, 500, 16, function(v)
    Cfg.WalkSpeed = v
end)

MoveTab:Slider("JumpPower", 50, 500, 50, function(v)
    Cfg.JumpPower = v
end)

MoveTab:Toggle("Infinite Jump", false, function(s)
    Cfg.InfiniteJump = s
end)

MoveTab:Button("Save Teleport Position", function()
    local root = getRoot(LocalPlayer)
    if root then
        Cfg.TpBackPos = root.CFrame
        print("[Ira] TP position saved:", root.Position)
    end
end)

MoveTab:Button("Teleport Back to Saved Position", function()
    if Cfg.TpBackPos then
        local root = getRoot(LocalPlayer)
        if root then root.CFrame = Cfg.TpBackPos end
    else
        print("[Ira] No saved position!")
    end
end)

MoveTab:Dropdown("Teleport to Player", {"(choose after opening)"}, function(sel) end)

-- Rebuild player list on tab open (best effort via button)
MoveTab:Button("Teleport to Nearest Enemy", function()
    local bestDist, bestRoot = math.huge, nil
    local myRoot = getRoot(LocalPlayer)
    if not myRoot then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local r = getRoot(p)
        if r then
            local d = (r.Position - myRoot.Position).Magnitude
            if d < bestDist then bestDist = d; bestRoot = r end
        end
    end
    if bestRoot then myRoot.CFrame = bestRoot.CFrame * CFrame.new(0,0,-4) end
end)

-- ─────────────────────────────────────────────
-- TAB 4: PERFORMANCE
-- ─────────────────────────────────────────────
local PerfTab = Window:Tab("Performance")

PerfTab:Toggle("Anti-Lag (Disable FX)", false, function(s)
    Cfg.AntiLag = s
    if s then
        Lighting.FogEnd          = 9e8
        Lighting.GlobalShadows   = false
        SoundService.RespectFilteringEnabled = false
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("ParticleEmitter") or p:IsA("Trail") or p:IsA("Beam") then
                p.Enabled = false
            end
        end
    else
        Lighting.FogEnd        = 1e6
        Lighting.GlobalShadows = Cfg.Shadows
    end
end)

PerfTab:Toggle("Disable Shadows", false, function(s)
    Cfg.Shadows = not s
    Lighting.GlobalShadows = not s
end)

PerfTab:Toggle("FPS Cap", false, function(s)
    Cfg.FPSCap = s
    pcall(function() setFPSCap(s, Cfg.FPSCapValue) end)
end)

PerfTab:Slider("FPS Cap Value", 15, 240, 60, function(v)
    Cfg.FPSCapValue = v
    if Cfg.FPSCap then pcall(function() setFPSCap(true, v) end) end
end)

PerfTab:Toggle("Low Graphics Mode", false, function(s)
    Cfg.LowGraphics = s
    applyLowGraphics(s)
end)

-- ─────────────────────────────────────────────
-- TAB 5: UTILITY
-- ─────────────────────────────────────────────
local UtilTab = Window:Tab("Utility")

UtilTab:Toggle("Anti-AFK", true, function(s)
    Cfg.AntiAFK = s
end)

UtilTab:Toggle("Anti-Fling", false, function(s)
    Cfg.AntiFling = s
    if s then setupAntiFling() else disableAntiFling() end
end)

UtilTab:Toggle("Auto-Rejoin on Kick", false, function(s)
    Cfg.AutoRejoin = s
    if s then
        game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(state)
            if state == Enum.TeleportState.Failed then
                TeleportService:Teleport(game.PlaceId)
            end
        end)
    end
end)

UtilTab:Button("Copy JobId to Clipboard", function()
    local id = game.JobId
    if setclipboard then
        setclipboard(id)
        print("[Ira] Copied JobId:", id)
    else
        print("[Ira] JobId:", id)
    end
end)

UtilTab:Button("Quick Leave (Rejoin)", function()
    TeleportService:Teleport(game.PlaceId)
end)

UtilTab:Button("Server Hop (Smallest Server)", function()
    local placeId = game.PlaceId
    local servers = {}
    local ok, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        local res = game:HttpGet(url)
        local data = HttpService:JSONDecode(res)
        for _, s in ipairs(data.data or {}) do
            if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
                table.insert(servers, {id=s.id, pop=s.playing})
            end
        end
        table.sort(servers, function(a,b) return a.pop < b.pop end)
        if #servers > 0 then
            TeleportService:TeleportToPlaceInstance(placeId, servers[1].id)
        else
            print("[Ira] No other servers found.")
        end
    end)
    if not ok then print("[Ira] Server hop error:", result) end
end)

-- Save / Load config (to JSON in clipboard)
UtilTab:Button("Save Config to Clipboard", function()
    local save = {
        AimbotEnabled   = Cfg.AimbotEnabled,
        AimbotFOV       = Cfg.AimbotFOV,
        AimbotSmooth    = Cfg.AimbotSmooth,
        AimbotPart      = Cfg.AimbotPart,
        AimbotTeamCheck = Cfg.AimbotTeamCheck,
        ESPEnabled      = Cfg.ESPEnabled,
        WalkSpeed       = Cfg.WalkSpeed,
        JumpPower       = Cfg.JumpPower,
        FlySpeed        = Cfg.FlySpeed,
    }
    local j = HttpService:JSONEncode(save)
    if setclipboard then setclipboard(j) end
    print("[Ira] Config saved to clipboard!")
end)

-- ─────────────────────────────────────────────
-- TAB 6: SETTINGS
-- ─────────────────────────────────────────────
local SetTab = Window:Tab("Settings")

SetTab:Toggle("Anti-AFK (Global)", true, function(s)
    Cfg.AntiAFK = s
end)

SetTab:Button("Reset All Movement", function()
    Cfg.WalkSpeed = 16; Cfg.JumpPower = 50
    Cfg.Fly = false; disableFly()
    Cfg.Noclip = false
    Cfg.InfiniteJump = false
    print("[Ira] Movement reset.")
end)

SetTab:Button("Unload Ira Resummon", function()
    _G.IraRunning = false
    for _, c in ipairs(_G.IraConnections) do pcall(function() c:Disconnect() end) end
    for _, d in ipairs(_G.IraDrawings) do pcall(function() d:Remove() end) end
    for _, h in ipairs(_G.IraHighlights) do pcall(function() h:Destroy() end) end
    disableFly()
    disableAntiFling()
    if snowGui then snowGui:Destroy() end
    if not Cfg.Fullbright then
        Lighting.Brightness     = Cfg.OrigBrightness
        Lighting.Ambient        = Cfg.OrigAmbient
        Lighting.OutdoorAmbient = Cfg.OrigOutdoor
    end
    Camera.FieldOfView = Cfg.OrigFOV
    pcall(function() UserInputService.MouseIconEnabled = true end)
    Camera.CameraMaxZoomDistance = 400
    for _, c in ipairs(CoreGui:GetChildren()) do
        if c.Name == "ui" or c.Name == "IraSnow" then pcall(function() c:Destroy() end) end
    end
    print("[Ira Resummon] Unloaded cleanly.")
end)

print("[Ira Resummon] Loaded! RShift = toggle UI")
