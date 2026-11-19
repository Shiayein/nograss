
-- PREDICTIVE FACE LOCK V3
-- P = NEUTRAL / TURTLE
-- F maintenu = tracking predictif
-- RightShift = afficher/masquer le GUI
-- Mode par defaut : NEUTRAL (74 ms)
-- Rotation predictive : 180 degres maximum

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

-- Nettoyage si le script est execute plusieurs fois
local ENV = getgenv()

if ENV.PredictiveFaceLockV3 then
    pcall(function()
        ENV.PredictiveFaceLockV3.Destroy()
    end)
end

local CONFIG = {
    NeutralMs = 74,
    TurtleMs = 446,
    MaxAngle = 180
}

local currentMode = "Neutral"
local holding = false
local savedHumanoid = nil
local savedAutoRotate = nil
local connections = {}

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function getParts()
    local character = player.Character

    if not character then
        return nil, nil
    end

    return character:FindFirstChild("HumanoidRootPart"),
           character:FindFirstChildOfClass("Humanoid")
end

local function getClosest(root)
    local nearest = nil
    local nearestDistance = math.huge

    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and other.Character then
            local humanoid =
                other.Character:FindFirstChildOfClass("Humanoid")

            local enemyRoot =
                other.Character:FindFirstChild("HumanoidRootPart")

            if humanoid and humanoid.Health > 0 and enemyRoot then
                local offset = enemyRoot.Position - root.Position

                local distance = Vector3.new(
                    offset.X, 0, offset.Z
                ).Magnitude

                if distance < nearestDistance then
                    nearestDistance = distance
                    nearest = enemyRoot
                end
            end
        end
    end

    return nearest
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "PredictiveFaceLockV3_GUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false

pcall(function()
    gui.Parent = CoreGui
end)

if not gui.Parent then
    gui.Parent = player:WaitForChild("PlayerGui")
end

local function make(className, properties, parent)
    local object = Instance.new(className)

    for property, value in pairs(properties) do
        object[property] = value
    end

    object.Parent = parent
    return object
end

-- Indicateur permanent en bas a gauche
local indicator = make("TextLabel", {
    Name = "ModeIndicator",
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 15, 1, -18),
    Size = UDim2.fromOffset(185, 40),

    BackgroundColor3 = Color3.fromRGB(24, 28, 38),
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,

    Text = "",
    TextSize = 15,
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(90, 170, 255)
}, gui)

make("UICorner", {
    CornerRadius = UDim.new(0, 9)
}, indicator)

local indicatorStroke = make("UIStroke", {
    Thickness = 1,
    Color = Color3.fromRGB(90, 170, 255),
    Transparency = 0.25
}, indicator)

-- Fenetre principale
local frame = make("Frame", {
    Size = UDim2.fromOffset(305, 195),
    Position = UDim2.new(0.5, -152, 0.35, 0),

    BackgroundColor3 = Color3.fromRGB(22, 24, 32),
    BorderSizePixel = 0,
    Active = true
}, gui)

make("UICorner", {
    CornerRadius = UDim.new(0, 12)
}, frame)

local title = make("TextLabel", {
    Position = UDim2.fromOffset(14, 0),
    Size = UDim2.new(1, -60, 0, 42),

    BackgroundTransparency = 1,

    Text = "PREDICTIVE FACE LOCK",
    TextColor3 = Color3.fromRGB(245, 245, 255),
    TextSize = 15,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left
}, frame)

local close = make("TextButton", {
    Position = UDim2.new(1, -39, 0, 7),
    Size = UDim2.fromOffset(30, 30),

    BackgroundColor3 = Color3.fromRGB(155, 48, 62),
    BorderSizePixel = 0,

    Text = "X",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 16,
    Font = Enum.Font.GothamBold
}, frame)

make("UICorner", {
    CornerRadius = UDim.new(0, 7)
}, close)

connect(close.MouseButton1Click, function()
    frame.Visible = false
end)

local info = make("TextLabel", {
    Position = UDim2.fromOffset(16, 48),
    Size = UDim2.new(1, -32, 0, 55),

    BackgroundTransparency = 1,

    Text = "F = Hold Tracking\nP = Switch Mode\nRightShift = Show / Hide GUI",
    TextColor3 = Color3.fromRGB(190, 200, 220),
    TextSize = 13,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top
}, frame)

local modeLabel = make("TextLabel", {
    Position = UDim2.fromOffset(16, 113),
    Size = UDim2.new(1, -32, 0, 30),

    BackgroundTransparency = 1,
    Text = "",
    TextSize = 14,
    Font = Enum.Font.GothamBold
}, frame)

local status = make("TextLabel", {
    Position = UDim2.fromOffset(16, 151),
    Size = UDim2.new(1, -32, 0, 25),

    BackgroundTransparency = 1,

    Text = "TRACKING : OFF",
    TextColor3 = Color3.fromRGB(170, 180, 200),
    TextSize = 12,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Left
}, frame)

local function getCurrentPreshot()
    if currentMode == "Turtle" then
        return CONFIG.TurtleMs
    end

    return CONFIG.NeutralMs
end

local function updateMode()
    if currentMode == "Neutral" then
        indicator.Text = "NEUTRAL | 74 MS"
        indicator.TextColor3 = Color3.fromRGB(90, 170, 255)

        indicatorStroke.Color =
            Color3.fromRGB(90, 170, 255)

        modeLabel.Text = "MODE : NEUTRAL (74 MS)"
        modeLabel.TextColor3 =
            Color3.fromRGB(90, 170, 255)
    else
        indicator.Text = "TURTLE | 446 MS"
        indicator.TextColor3 = Color3.fromRGB(75, 235, 125)

        indicatorStroke.Color =
            Color3.fromRGB(75, 235, 125)

        modeLabel.Text = "MODE : TURTLE (446 MS)"
        modeLabel.TextColor3 =
            Color3.fromRGB(75, 235, 125)
    end
end

updateMode()

-- Fenetre deplacable
local dragging = false
local dragStart = nil
local frameStart = nil

connect(title.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        frameStart = frame.Position
    end
end)

connect(UIS.InputChanged, function(input)
    if dragging and input.UserInputType ==
        Enum.UserInputType.MouseMovement then

        local delta = input.Position - dragStart

        frame.Position = UDim2.new(
            frameStart.X.Scale,
            frameStart.X.Offset + delta.X,
            frameStart.Y.Scale,
            frameStart.Y.Offset + delta.Y
        )
    end
end)

connect(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

local function restore()
    holding = false

    if savedHumanoid
        and savedHumanoid.Parent
        and savedAutoRotate ~= nil then

        savedHumanoid.AutoRotate = savedAutoRotate
    end

    savedHumanoid = nil
    savedAutoRotate = nil

    status.Text = "TRACKING : OFF"
end

-- Commandes
connect(UIS.InputBegan, function(input, processed)
    if input.KeyCode == Enum.KeyCode.RightShift then
        frame.Visible = not frame.Visible
        return
    end

    if processed then
        return
    end

    -- P : alterner entre les deux modes
    if input.KeyCode == Enum.KeyCode.P then
        if currentMode == "Neutral" then
            currentMode = "Turtle"
        else
            currentMode = "Neutral"
        end

        updateMode()
        return
    end

    -- F : tracking maintenu
    if input.KeyCode == Enum.KeyCode.F and not holding then
        holding = true

        local _, humanoid = getParts()

        if humanoid then
            savedHumanoid = humanoid
            savedAutoRotate = humanoid.AutoRotate
            humanoid.AutoRotate = false
        end
    end
end)

connect(UIS.InputEnded, function(input)
    if input.KeyCode == Enum.KeyCode.F then
        restore()
    end
end)

connect(player.CharacterRemoving, restore)

-- Prediction par vitesse
local function predictedDirection(myPosition, enemy, preshotMs)
    local enemyPosition = enemy.Position
    local velocity = enemy.AssemblyLinearVelocity

    local lead = preshotMs / 1000

    local predictedPosition = enemyPosition + Vector3.new(
        velocity.X * lead,
        0,
        velocity.Z * lead
    )

    local actual = Vector3.new(
        enemyPosition.X - myPosition.X,
        0,
        enemyPosition.Z - myPosition.Z
    )

    local predicted = Vector3.new(
        predictedPosition.X - myPosition.X,
        0,
        predictedPosition.Z - myPosition.Z
    )

    if actual.Magnitude < 0.05
        or predicted.Magnitude < 0.05 then
        return actual
    end

    local base = actual.Unit
    local aim = predicted.Unit

    local signedAngle = math.atan2(
        base:Cross(aim).Y,
        math.clamp(base:Dot(aim), -1, 1)
    )

    -- Angle maximum fixe : 180 degres
    signedAngle = math.clamp(
        signedAngle,
        -math.pi,
        math.pi
    )

    return CFrame.lookAt(Vector3.zero, base)
        * CFrame.Angles(0, signedAngle, 0)
        * Vector3.new(0, 0, -1)
end

local renderName = "PredictiveFaceLockV3_Render"

pcall(function()
    RunService:UnbindFromRenderStep(renderName)
end)

RunService:BindToRenderStep(
    renderName,
    Enum.RenderPriority.Character.Value + 2,
    function()
        if not holding then
            return
        end

        local root, humanoid = getParts()

        if not root or not humanoid then
            return
        end

        -- Conserver le tracking meme en Shift Lock
        humanoid.AutoRotate = false

        local enemy = getClosest(root)

        if not enemy then
            status.Text = "TRACKING : NO TARGET"
            return
        end

        local preshotMs = getCurrentPreshot()

        local direction = predictedDirection(
            root.Position,
            enemy,
            preshotMs
        )

        if direction.Magnitude > 0.001 then
            local position = root.Position

            root.CFrame = CFrame.lookAt(
                position,
                position + direction.Unit
            )
        end

        status.Text =
            "TRACKING : ON | " .. preshotMs .. " MS"
    end
)

ENV.PredictiveFaceLockV3 = {
    Destroy = function()
        restore()

        RunService:UnbindFromRenderStep(renderName)

        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end

        gui:Destroy()
        ENV.PredictiveFaceLockV3 = nil
    end
}
