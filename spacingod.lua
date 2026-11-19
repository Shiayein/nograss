
-- TSB VOID ARENA V6 - HOOK SPACING TRAINER
-- Custom floor + red/yellow ESP + blue range + estimated enemy cooldowns
-- V10: no ragdoll filter + cooldown refresh on distinct new dash
-- ² = Arena ON/OFF
-- ALT = Blue circles ON/OFF

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- CLEAN PREVIOUS VERSIONS
for _, key in ipairs({
    "TSB_VoidArena_Stop",
    "TSB_RangeV2_Stop",
    "TSB_RangeV3_Stop",
    "TSB_RangeV4_Stop",
    "TSB_CircleArena_Stop",
    "TSB_CircleArenaV4_Stop",
    "TSB_CircleArenaV5_Stop",
    "TSB_CircleArenaV6_Stop",
    "TSB_HookSpacing_Stop",
    "TSB_EnemyCooldownESP_Stop",
    "TSB_NearestEnemyDash_Stop"
}) do
    if type(_G[key]) == "function" then
        pcall(_G[key])
    end
end

-- SETTINGS
local TILE_SIZE = 29.39 / 3

local ENEMY_RADIUS = TILE_SIZE * 3.5
local LOCAL_RADIUS = TILE_SIZE * 2.5
local BLUE_RADIUS = TILE_SIZE * 5.5

local PLATFORM_SIZE = 1500
local PLATFORM_THICKNESS = 1
local GROUND_OFFSET = 0.08
local CIRCLE_OFFSET = 0.12

local SEGMENTS = 48
local FILL_TRANSPARENCY = 0.8

local TEXTURE_ID = "rbxassetid://84947411349846"
local TEXTURE_TILE_SIZE = 30

local RED = Color3.fromRGB(255, 0, 0)
local YELLOW = Color3.fromRGB(255, 230, 0)
local BLUE = Color3.fromRGB(0, 140, 255)
local GREEN = Color3.fromRGB(45, 220, 125)
local AMBER = Color3.fromRGB(255, 187, 50)
local DIM = Color3.fromRGB(105, 115, 133)

-- Estimated enemy dash cooldowns; not server-authoritative.
local SIDE_CD = 2.0
local FRONT_CD = 5.0
local WARNING_SECONDS = 0.5
local SAMPLE_INTERVAL = 0.07
local MIN_DASH_SPEED = 43 -- studs/sec; tune with real tests
local MIN_SPEED_JUMP = 12
local MAX_SAMPLE_SPEED = 180
local DIRECTION_DOT = 0.55
local TRIGGER_GAP = 0.30
local DASH_END_SPEED = 30
local MAX_TARGET_DISTANCE = 250

local enabled = false
local blueEnabled = false

local connections = {}
local originals = {}
local circles = {}

-- MAIN CONTAINER
local arena = Instance.new("Folder")
arena.Name = "TSB_HookSpacing"

local platform = Instance.new("Part")
platform.Name = "TSB_CustomFloor"
platform.Anchored = true
platform.CanCollide = false
platform.CanTouch = false
platform.CanQuery = false
platform.CastShadow = false
platform.Material = Enum.Material.SmoothPlastic
platform.Color = Color3.fromRGB(255, 255, 255)
platform.Size = Vector3.new(
    PLATFORM_SIZE,
    PLATFORM_THICKNESS,
    PLATFORM_SIZE
)
platform.Parent = arena

-- REPEATING FLOOR TEXTURE
local texture = Instance.new("Texture")
texture.Name = "CustomFloorImage"
texture.Texture = TEXTURE_ID
texture.Face = Enum.NormalId.Top
texture.StudsPerTileU = TEXTURE_TILE_SIZE
texture.StudsPerTileV = TEXTURE_TILE_SIZE
texture.Parent = platform

local circleY = 0

-- COMPACT LEFT-SIDE COOLDOWN HUD (no top distance log)
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local oldHUD = playerGui:FindFirstChild("TSB_EnemyCooldown_CompactHUD")
if oldHUD then oldHUD:Destroy() end
local hud = Instance.new("ScreenGui")
hud.Name = "TSB_EnemyCooldown_CompactHUD"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.Enabled = false
hud.Parent = playerGui

local function makeWidget(label, y)
    local box = Instance.new("Frame")
    box.Name = label .. "Widget"
    box.Position = UDim2.new(0, 12, 0.5, y)
    box.Size = UDim2.fromOffset(102, 64)
    box.BackgroundColor3 = Color3.fromRGB(18, 23, 32)
    box.BackgroundTransparency = 0.12
    box.BorderSizePixel = 0
    box.Parent = hud
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 9)
    corner.Parent = box
    local outline = Instance.new("UIStroke")
    outline.Color = Color3.fromRGB(68, 80, 95)
    outline.Transparency = 0.35
    outline.Parent = box
    local indicator = Instance.new("Frame")
    indicator.Name = "StatusSquare"
    indicator.Size = UDim2.fromOffset(19, 19)
    indicator.Position = UDim2.fromOffset(10, 8)
    indicator.BackgroundColor3 = DIM
    indicator.BorderSizePixel = 0
    indicator.Parent = box
    local squareCorner = Instance.new("UICorner")
    squareCorner.CornerRadius = UDim.new(0, 4)
    squareCorner.Parent = indicator
    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromOffset(66, 22)
    title.Position = UDim2.fromOffset(32, 6)
    title.BackgroundTransparency = 1
    title.Text = label
    title.TextColor3 = Color3.fromRGB(238, 240, 245)
    title.TextSize = 10
    title.Font = Enum.Font.GothamBold
    title.Parent = box
    local timer = Instance.new("TextLabel")
    timer.Name = "Cooldown"
    timer.Size = UDim2.fromOffset(86, 24)
    timer.Position = UDim2.fromOffset(8, 33)
    timer.BackgroundTransparency = 1
    timer.Text = "?"
    timer.TextColor3 = DIM
    timer.TextSize = 15
    timer.Font = Enum.Font.GothamBold
    timer.Parent = box
    return {Indicator=indicator, Timer=timer}
end
local sideWidget = makeWidget("SIDE A/D", -70)
local frontWidget = makeWidget("FRONT/BACK", 3)

-- This tracks only the closest living player and observes displacement.
-- Other clients' FireServer calls are NOT exposed to this client.
local target = nil
local previousPosition = nil
local previousSpeed = 0
local lastTrigger = -math.huge
local dashBurstActive = false
local previousCharacter = nil
local sampleAccum = 0
local seen = {Side=false, Front=false}
local readyAt = {Side=0, Front=0}

local function resetTarget(nextTarget)
    target = nextTarget
    previousPosition = nil
    previousSpeed = 0
    lastTrigger = -math.huge
    dashBurstActive = false
    previousCharacter = nil
    seen.Side, seen.Front = false, false
    readyAt.Side, readyAt.Front = 0, 0
end

local function findNearest()
    local character = LocalPlayer.Character
    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local nearest, distance = nil, MAX_TARGET_DISTANCE
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local offset = root.Position - myRoot.Position
                local flatDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
                if flatDistance < distance then
                    nearest, distance = player, flatDistance
                end
            end
        end
    end
    return nearest
end

local function trackEstimatedDash(now, dt)
    if not target then return end
    local char = target.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then
        previousPosition, previousSpeed = nil, 0
        dashBurstActive = false
        return
    end
    -- Same player may respawn: do not compare the new position to old body.
    if char ~= previousCharacter then
        previousCharacter = char
        previousPosition, previousSpeed = root.Position, 0
        dashBurstActive = false
        seen.Side, seen.Front = false, false
        readyAt.Side, readyAt.Front = 0, 0
        return
    end
    local position = root.Position
    if not previousPosition then
        previousPosition, previousSpeed = position, 0
        return
    end
    if dt <= 0 then return end
    local move = position - previousPosition
    previousPosition = position
    local flat = Vector3.new(move.X, 0, move.Z)
    local speed = flat.Magnitude / dt

    -- Ignore only implausibly large jumps (possible teleport / replication correction).
    if speed > MAX_SAMPLE_SPEED then
        dashBurstActive = false
        previousSpeed = 0
        return
    end
    if speed < DASH_END_SPEED then
        dashBurstActive = false
    end

    -- A new movement burst may restart an estimate, even when green.
    -- Do not restart every frame of the same dash animation.
    local speedSpike = speed - previousSpeed >= MIN_SPEED_JUMP
    if speed >= MIN_DASH_SPEED and speedSpike
        and flat.Magnitude > 0.01
        and now - lastTrigger >= TRIGGER_GAP then
        local direction = flat.Unit
        local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
        local right = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)
        if look.Magnitude > 0.001 and right.Magnitude > 0.001 then
            local forward = math.abs(direction:Dot(look.Unit))
            local lateral = math.abs(direction:Dot(right.Unit))
            local kind = nil
            if lateral > forward and lateral >= DIRECTION_DOT then
                kind = "Side"
            elseif forward >= DIRECTION_DOT then
                kind = "Front"
            end
            if kind and (not dashBurstActive or now - lastTrigger >= 0.6) then
                -- Restart on EVERY distinct detected dash, even during cooldown.
                seen[kind] = true
                readyAt[kind] = now + (kind == "Side" and SIDE_CD or FRONT_CD)
                lastTrigger = now
                dashBurstActive = true
            end
        end
    end
    previousSpeed = speed
end

local function estimatedState(kind, now)
    if not target or not seen[kind] then
        return DIM, "?"
    end
    local remaining = math.max(0, readyAt[kind] - now)
    if remaining > WARNING_SECONDS then
        return GREEN, string.format("%.1f s", remaining)
    elseif remaining > 0 then
        return AMBER, string.format("%.1f s", remaining)
    end
    return RED, "PRET ?"
end

local function paintWidget(widget, color, value)
    widget.Indicator.BackgroundColor3 = color
    widget.Timer.TextColor3 = color
    widget.Timer.Text = value
end

local function recolorCircle(circle, color)
    if circle.LastColor == color then return end
    circle.LastColor = color
    for _, part in ipairs(circle.Main:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Color = color
        end
    end
end

-- DETECT REAL GROUND
local function detectGround()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return nil, nil end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local excluded = {arena}
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(excluded, player.Character)
        end
    end

    params.FilterDescendantsInstances = excluded
    params.IgnoreWater = true

    local result = Workspace:Raycast(
        root.Position + Vector3.new(0, 5, 0),
        Vector3.new(0, -300, 0),
        params
    )

    local groundY = result and result.Position.Y
        or root.Position.Y - 3

    return groundY, root.Position
end

-- VISUAL PART
local function newPart(parent, name, color)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Parent = parent
    return part
end

-- BUILD CIRCLE
local function buildCircle(parent, name, radius, color)
    local model = Instance.new("Model")
    model.Name = name
    model.WorldPivot = CFrame.new()
    model.Parent = parent

    local fill = newPart(model, "Fill", color)
    fill.Shape = Enum.PartType.Cylinder
    fill.Size = Vector3.new(0.06, radius * 2, radius * 2)
    fill.Transparency = FILL_TRANSPARENCY
    fill.CFrame = CFrame.Angles(0, 0, math.rad(90))

    for i = 1, SEGMENTS do
        local a1 = (i - 1) * math.pi * 2 / SEGMENTS
        local a2 = i * math.pi * 2 / SEGMENTS

        local p1 = Vector3.new(
            math.cos(a1) * radius,
            0,
            math.sin(a1) * radius
        )

        local p2 = Vector3.new(
            math.cos(a2) * radius,
            0,
            math.sin(a2) * radius
        )

        local border = newPart(model, "Border", color)
        border.Size = Vector3.new(
            0.25,
            0.08,
            (p2 - p1).Magnitude + 0.03
        )
        border.CFrame = CFrame.lookAt((p1 + p2) / 2, p2)
    end

    return model
end

-- CREATE PLAYER CIRCLES
local function createPlayerCircles(player)
    if circles[player] then return end

    local container = Instance.new("Folder")
    container.Name = player.Name .. "_Ranges"
    container.Parent = arena

    local isLocal = player == LocalPlayer

    local main = buildCircle(
        container,
        isLocal and "YellowRange" or "RedRange",
        isLocal and LOCAL_RADIUS or ENEMY_RADIUS,
        isLocal and YELLOW or RED
    )

    local blue = nil
    if not isLocal then
        blue = buildCircle(
            container,
            "BlueRange",
            BLUE_RADIUS,
            BLUE
        )
        blue.Parent = nil
    end

    circles[player] = {
        Container = container,
        Main = main,
        Blue = blue,
        LastColor = isLocal and YELLOW or RED
    }
end

local function removePlayerCircles(player)
    local data = circles[player]
    if not data then return end

    if data.Blue then
        data.Blue:Destroy()
    end

    data.Container:Destroy()
    circles[player] = nil
end

for _, player in ipairs(Players:GetPlayers()) do
    createPlayerCircles(player)
end

table.insert(connections, Players.PlayerAdded:Connect(createPlayerCircles))
table.insert(connections, Players.PlayerRemoving:Connect(removePlayerCircles))

-- BLUE VISIBILITY
local function updateBlueVisibility()
    for _, data in pairs(circles) do
        if data.Blue then
            data.Blue.Parent = blueEnabled and data.Container or nil
        end
    end
end

-- MAP VISIBILITY
local map = Workspace:FindFirstChild("Map")

local function hideObject(obj)
    if not enabled then return end

    if obj:IsA("BasePart") then
        if originals[obj] == nil then
            originals[obj] = obj.LocalTransparencyModifier
        end
        obj.LocalTransparencyModifier = 1

    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        if originals[obj] == nil then
            originals[obj] = obj.Transparency
        end
        obj.Transparency = 1

    elseif obj:IsA("ParticleEmitter")
        or obj:IsA("Trail")
        or obj:IsA("Beam") then
        if originals[obj] == nil then
            originals[obj] = obj.Enabled
        end
        obj.Enabled = false
    end
end

if map then
    table.insert(connections, map.DescendantAdded:Connect(hideObject))
end

local function hideMap()
    map = Workspace:FindFirstChild("Map")
    if not map then return end

    for _, obj in ipairs(map:GetDescendants()) do
        hideObject(obj)
    end
end

local function restoreMap()
    for obj, value in pairs(originals) do
        if obj and obj.Parent then
            pcall(function()
                if obj:IsA("BasePart") then
                    obj.LocalTransparencyModifier = value
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    obj.Transparency = value
                else
                    obj.Enabled = value
                end
            end)
        end
    end
    table.clear(originals)
end

-- ARENA ON
local function enableArena()
    if enabled then return end

    local groundY, position = detectGround()
    if not groundY then return end

    platform.Position = Vector3.new(
        position.X,
        groundY - PLATFORM_THICKNESS / 2 - GROUND_OFFSET,
        position.Z
    )

    circleY = groundY - GROUND_OFFSET + CIRCLE_OFFSET

    arena.Parent = Workspace
    enabled = true
    hud.Enabled = true
    hideMap()
    updateBlueVisibility()

    print("[TSB] ARENA ON")
end

-- ARENA OFF
local function disableArena()
    if not enabled then return end

    enabled = false
    hud.Enabled = false
    arena.Parent = nil
    restoreMap()

    print("[TSB] ARENA OFF")
end

-- SMOOTH UPDATE
table.insert(connections,
    RunService.RenderStepped:Connect(function(dt)
        if not enabled then return end

        sampleAccum = sampleAccum + dt
        if sampleAccum >= SAMPLE_INTERVAL then
            local elapsed = sampleAccum
            sampleAccum = 0
            local nearest = findNearest()
            if nearest ~= target then resetTarget(nearest) end
            trackEstimatedDash(os.clock(), elapsed)
        end

        local now = os.clock()
        local sideColor, sideText = estimatedState("Side", now)
        local frontColor, frontText = estimatedState("Front", now)
        paintWidget(sideWidget, sideColor, sideText)
        paintWidget(frontWidget, frontColor, frontText)

        for player, data in pairs(circles) do
            if player ~= LocalPlayer then
                recolorCircle(data, player == target and (seen.Side and sideColor or RED) or RED)
            end
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")

            if root then
                local cf = CFrame.new(
                    root.Position.X,
                    circleY,
                    root.Position.Z
                )

                data.Main:PivotTo(cf)

                if data.Blue and blueEnabled then
                    data.Blue:PivotTo(cf)
                end
            end
        end
    end)
)

-- KEYBINDS
table.insert(connections,
    UIS.InputBegan:Connect(function(input, processed)
        if processed then return end

        -- ² = entire arena toggle
        if input.KeyCode == Enum.KeyCode.Backquote
            or input.KeyCode == Enum.KeyCode.Tilde then

            if enabled then
                disableArena()
            else
                enableArena()
            end
        end

        -- ALT = blue circles toggle
        if input.KeyCode == Enum.KeyCode.LeftAlt then
            blueEnabled = not blueEnabled
            updateBlueVisibility()

            print("[TSB] BLUE RANGE:", blueEnabled and "ON" or "OFF")
        end
    end)
)

-- FULL CLEANUP
_G.TSB_EnemyCooldownESP_Stop = function()
    disableArena()

    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end

    for player in pairs(circles) do
        removePlayerCircles(player)
    end

    arena:Destroy()
    hud:Destroy()

    table.clear(connections)
    table.clear(originals)
    table.clear(circles)

    if _G.TSB_EnemyCooldownESP_Stop then
        _G.TSB_EnemyCooldownESP_Stop = nil
    end
end

-- START
enableArena()

print("[TSB] Enemy cooldown ESP (visual estimate) loaded")
print("[TSB] ² = Arena ON/OFF")
print("[TSB] ALT = Blue range ON/OFF")
print("[TSB] Side cooldown estimate:", SIDE_CD, "Front/Back:", FRONT_CD)

-- END OF COMPLETE SCRIPT
