
-- AUTO STRAFING V5 : GLITCH TORNADO
-- K = ON / OFF
-- Q / S / F = STOP
-- AZERTY
-- Changements d'orientation ultra rapides
-- Camera non modifiee directement

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local RNG = Random.new()
local ENV = getgenv()

-- Nettoyer les anciennes versions
for _, name in ipairs({
    "AutoStrafingV1",
    "AutoStrafingV2",
    "AutoStrafingV3",
    "AutoStrafingV4",
    "AutoStrafingV5"
}) do
    if ENV[name] and ENV[name].Destroy then
        pcall(ENV[name].Destroy)
    end
end

local CONFIG = {
    -- Environ 20x plus rapide que V4
    MinInterval = 0.020,
    MaxInterval = 0.035,

    MinAngle = 90,
    MaxAngle = 480,

    -- Nombre maximal de changements
    -- par frame pour eviter les boucles excessives
    MaxStepsPerFrame = 3
}

local enabled = false
local accumulator = 0
local nextInterval = CONFIG.MinInterval

local savedHumanoid = nil
local savedAutoRotate = nil
local connections = {}

local renderName = "AutoStrafingV5_Render"

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

local function getParts()
    local character = player.Character
    if not character then
        return nil, nil
    end

    return character:FindFirstChild("HumanoidRootPart"),
           character:FindFirstChildOfClass("Humanoid")
end

local function restore()
    if savedHumanoid
        and savedHumanoid.Parent
        and savedAutoRotate ~= nil then

        savedHumanoid.AutoRotate = savedAutoRotate
    end

    savedHumanoid = nil
    savedAutoRotate = nil
end

local function stop()
    enabled = false
    accumulator = 0
    restore()
end

local function start()
    enabled = true
    accumulator = 0
    nextInterval = 0
end

local function randomTurn(root)
    local angle = RNG:NextNumber(
        CONFIG.MinAngle,
        CONFIG.MaxAngle
    )

    local sign = RNG:NextInteger(0, 1) == 0
        and -1 or 1

    -- Rotation instantanee, aucun lissage
    -- 480 degres donne la meme orientation
    -- finale que 120 degres, mais en cumul
    -- cela conserve l'idee des sauts aleatoires
    local radians = math.rad(angle * sign)

    local position = root.Position
    local newRotation =
        root.CFrame.Rotation
        * CFrame.Angles(0, radians, 0)

    -- Conserver la position, changer uniquement
    -- la direction du personnage
    root.CFrame = CFrame.new(position) * newRotation
end

-- CONTROLES
connect(UIS.InputBegan, function(input, processed)
    if processed then return end

    local key = input.KeyCode

    if key == Enum.KeyCode.K then
        if enabled then
            stop()
        else
            start()
        end

    elseif key == Enum.KeyCode.Q
        or key == Enum.KeyCode.S
        or key == Enum.KeyCode.F then

        stop()
    end
end)

connect(player.CharacterRemoving, stop)

-- Tourner apres la mise a jour standard
-- de la camera, sans modifier son CFrame.
RunService:BindToRenderStep(
    renderName,
    Enum.RenderPriority.Camera.Value + 1,
    function(dt)
        if not enabled then return end

        local root, humanoid = getParts()

        if not root
            or not humanoid
            or humanoid.Health <= 0 then
            return
        end

        if savedHumanoid ~= humanoid then
            restore()
            savedHumanoid = humanoid
            savedAutoRotate = humanoid.AutoRotate
        end

        humanoid.AutoRotate = false

        accumulator = accumulator + math.min(dt, 0.1)

        local steps = 0

        while accumulator >= nextInterval
            and steps < CONFIG.MaxStepsPerFrame do

            accumulator = accumulator - nextInterval
            randomTurn(root)

            nextInterval = RNG:NextNumber(
                CONFIG.MinInterval,
                CONFIG.MaxInterval
            )

            steps = steps + 1
        end

        -- Eviter d'accumuler un retard massif
        if steps >= CONFIG.MaxStepsPerFrame then
            accumulator = math.min(
                accumulator,
                nextInterval
            )
        end
    end
)

ENV.AutoStrafingV5 = {
    Destroy = function()
        stop()

        pcall(function()
            RunService:UnbindFromRenderStep(renderName)
        end)

        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end

        ENV.AutoStrafingV5 = nil
    end
}

print("[GLITCH TORNADO V5] LOADED")
print("K = ON/OFF | Q/S/F = STOP")
