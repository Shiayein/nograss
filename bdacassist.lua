
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- CONFIGURATION
local TILE_SIZE = 29.39 / 3
local DETECTION_RANGE = 2.5 * TILE_SIZE
local STOP_DISTANCE = 0.5 * TILE_SIZE

local SPEED = 65
local KEY = Enum.KeyCode.V

-- NETTOYAGE SI LE SCRIPT EST RELANCÉ
local env = getgenv and getgenv() or _G

if env.DashCancelCleanup then
    env.DashCancelCleanup()
end

local movementConnection
local inputConnection
local notificationTween

local oldGui = playerGui:FindFirstChild("DashCancelLogGUI")
if oldGui then
    oldGui:Destroy()
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "DashCancelLogGUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local notification = Instance.new("TextLabel")
notification.Name = "Notification"
notification.AnchorPoint = Vector2.new(0.5, 0)
notification.Position = UDim2.new(0.5, 0, 0, -60)
notification.Size = UDim2.new(0, 270, 0, 42)
notification.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
notification.BackgroundTransparency = 0.1
notification.TextColor3 = Color3.fromRGB(80, 255, 140)
notification.Font = Enum.Font.GothamBold
notification.TextSize = 14
notification.Text = "✓ Script activé | Touche V"
notification.Visible = true
notification.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = notification

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 255, 140)
stroke.Thickness = 1
stroke.Transparency = 0.4
stroke.Parent = notification

-- NOTIFICATION UNIQUEMENT AU LANCEMENT
task.spawn(function()
    notificationTween = TweenService:Create(
        notification,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad),
        {Position = UDim2.new(0.5, 0, 0, 20)}
    )

    notificationTween:Play()
    notificationTween.Completed:Wait()

    task.wait(1.5)

    if not notification.Parent then return end

    notificationTween = TweenService:Create(
        notification,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad),
        {
            Position = UDim2.new(0.5, 0, 0, -60),
            TextTransparency = 1,
            BackgroundTransparency = 1
        }
    )

    notificationTween:Play()
    notificationTween.Completed:Wait()

    if notification.Parent then
        notification:Destroy()
    end
end)

-- PERSONNAGE
local function getRoot(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

-- JOUEUR LE PLUS PROCHE
local function getNearestTarget(root)
    local nearest = nil
    local nearestDistance = DETECTION_RANGE

    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player then
            local character = other.Character
            local targetRoot = getRoot(character)
            local humanoid = character
                and character:FindFirstChildOfClass("Humanoid")

            if targetRoot and humanoid and humanoid.Health > 0 then
                local offset = targetRoot.Position - root.Position
                local flatOffset = Vector3.new(
                    offset.X,
                    0,
                    offset.Z
                )

                local distance = flatOffset.Magnitude

                if distance <= nearestDistance then
                    nearest = targetRoot
                    nearestDistance = distance
                end
            end
        end
    end

    return nearest
end

local function stopMovement()
    if movementConnection then
        movementConnection:Disconnect()
        movementConnection = nil
    end
end

-- DÉPLACEMENT LINÉAIRE
local function startMovement()
    stopMovement()

    local character = player.Character
    local root = getRoot(character)

    if not root then return end

    local target = getNearestTarget(root)

    -- AUCUNE CIBLE À 2.5 TILES
    if not target then return end

    -- DÉJÀ À 0.5 TILE OU MOINS
    local initialOffset = target.Position - root.Position
    local initialDistance = Vector3.new(
        initialOffset.X, 0, initialOffset.Z
    ).Magnitude

    if initialDistance <= STOP_DISTANCE then return end

    movementConnection = RunService.Heartbeat:Connect(function(dt)
        local myHumanoid = character:FindFirstChildOfClass("Humanoid")
        local targetHumanoid = target.Parent
            and target.Parent:FindFirstChildOfClass("Humanoid")

        if not root.Parent
            or not target.Parent
            or not myHumanoid
            or myHumanoid.Health <= 0
            or not targetHumanoid
            or targetHumanoid.Health <= 0 then
            stopMovement()
            return
        end

        local offset = target.Position - root.Position
        local flatOffset = Vector3.new(offset.X, 0, offset.Z)
        local distance = flatOffset.Magnitude

        -- ARRÊT À 0.5 TILE
        if distance <= STOP_DISTANCE then
            stopMovement()
            return
        end

        local direction = flatOffset.Unit

        local step = math.min(
            SPEED * dt,
            distance - STOP_DISTANCE
        )

        local newPosition = root.Position + direction * step

        root.CFrame = CFrame.lookAt(
            newPosition,
            Vector3.new(
                target.Position.X,
                newPosition.Y,
                target.Position.Z
            )
        )

        if step >= distance - STOP_DISTANCE then
            stopMovement()
        end
    end)
end

-- TOUCHE V
inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == KEY then
        startMovement()
    end
end)

-- NETTOYAGE POUR ÉVITER LES DOUBLONS
env.DashCancelCleanup = function()
    stopMovement()

    if inputConnection then
        inputConnection:Disconnect()
        inputConnection = nil
    end

    if notificationTween then
        notificationTween:Cancel()
    end

    if gui.Parent then
        gui:Destroy()
    end
end
