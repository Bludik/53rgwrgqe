-- Lightweight Toilet Tower Defense Script (PC & Xeno Safe)
-- No WindUI, no Cobalt, no require(MultiboxFramework), no getgc, no setthreadidentity.

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local P = Players.LocalPlayer
while not P do
    task.wait(0.1)
    P = Players.LocalPlayer
end

-- Unlock FPS cap if executor supports it
do
    local setCap = setfpscap or set_fps_cap or setfps
    if type(setCap) == "function" then pcall(setCap, 240) end
    pcall(function() UserSettings():GetService("UserGameSettings").FramerateCap = 240 end)
end

-- Prevent duplicate instances
local ENV = (type(getgenv) == "function" and getgenv()) or _G
if ENV.__XenoTTD and type(ENV.__XenoTTD.Destroy) == "function" then
    pcall(ENV.__XenoTTD.Destroy)
end

local State = {
    Running = true,
    AutoSkip = true,
    AntiAFK = true,
    AutoExecute = true,
    TeleportQueued = false,
    LastSkipAt = 0,
    Connections = {},
}
ENV.__XenoTTD = State

-- Settings persistence
local SETTINGS_FILE = "ToiletTD_XenoSettings.json"
local function loadSettings()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    local ok, raw = pcall(readfile, SETTINGS_FILE)
    if not ok or type(raw) ~= "string" then return end
    local okJson, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if okJson and type(data) == "table" then
        if type(data.AutoSkip) == "boolean" then State.AutoSkip = data.AutoSkip end
        if type(data.AntiAFK) == "boolean" then State.AntiAFK = data.AntiAFK end
        if type(data.AutoExecute) == "boolean" then State.AutoExecute = data.AutoExecute end
    end
end

local function saveSettings()
    if type(writefile) ~= "function" then return end
    pcall(function()
        writefile(SETTINGS_FILE, HttpService:JSONEncode({
            AutoSkip = State.AutoSkip,
            AntiAFK = State.AntiAFK,
            AutoExecute = State.AutoExecute,
        }))
    end)
end

loadSettings()

-- Teleport auto-reexecute
local function queueTeleport()
    if not State.AutoExecute or State.TeleportQueued then return end
    local queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
    if type(queue) ~= "function" then return end
    local code = [[
if not game:IsLoaded() then game.Loaded:Wait() end
local P = game:GetService("Players")
while not P.LocalPlayer do task.wait(0.1) end
task.wait(1)
loadstring(game:HttpGet("https://raw.githubusercontent.com/Bludik/53rgwrgqe/main/xeno_ttd.lua"))()
]]
    local ok = pcall(queue, code)
    if ok then State.TeleportQueued = true end
end

pcall(queueTeleport)
if P.OnTeleport then
    State.Connections[#State.Connections + 1] = P.OnTeleport:Connect(function(tpState)
        if tpState == Enum.TeleportState.Started then pcall(queueTeleport) end
    end)
end

-- Safe UI helpers
local function getChild(root, ...)
    local cur = root
    for i = 1, select("#", ...) do
        if not cur then return nil end
        cur = cur:FindFirstChild(select(i, ...))
    end
    return cur
end

local function isVisible(obj)
    local cur = obj
    while cur do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return true
end

local function fireGuiButton(button)
    if not button then return false end
    if not button:IsA("GuiButton") then
        button = button:FindFirstChildWhichIsA("GuiButton", true)
        if not button then return false end
    end
    local fired = false
    for _, sigName in ipairs({"Activated", "MouseButton1Click"}) do
        local okSig, sig = pcall(function() return button[sigName] end)
        if okSig and sig then
            if type(firesignal) == "function" then
                if pcall(firesignal, sig) then fired = true end
            end
            if not fired and type(getconnections) == "function" then
                local okConn, conns = pcall(getconnections, sig)
                if okConn and type(conns) == "table" then
                    for _, conn in ipairs(conns) do
                        if conn and conn.Fire then
                            pcall(function() conn:Fire() end)
                            fired = true
                        end
                    end
                end
            end
        end
    end
    return fired
end

-- Build lightweight native UI (DisplayOrder = 5, Modal = false)
local gui = Instance.new("ScreenGui")
gui.Name = "XenoTTDLite"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 5
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parented = false
local candidates = {}
if type(gethui) == "function" then
    local ok, h = pcall(gethui)
    if ok and h then candidates[#candidates + 1] = h end
end
local okCore, coreGui = pcall(function() return game:GetService("CoreGui") end)
if okCore and coreGui then candidates[#candidates + 1] = coreGui end
local pg = P:FindFirstChildOfClass("PlayerGui") or P:WaitForChild("PlayerGui", 10)
if pg then candidates[#candidates + 1] = pg end

for _, parent in ipairs(candidates) do
    if pcall(function() gui.Parent = parent end) and gui.Parent == parent then
        parented = true
        break
    end
end

if not parented then return end

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(250, 195)
frame.Position = UDim2.new(0, 20, 0.5, -97)
frame.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 105, 160)
stroke.Thickness = 1
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 32)
title.Position = UDim2.fromOffset(12, 0)
title.BackgroundTransparency = 1
title.Text = "TTD Lite (Xeno / PC)"
title.TextColor3 = Color3.fromRGB(235, 240, 255)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(26, 26)
closeBtn.Position = UDim2.new(1, -30, 0, 3)
closeBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 38)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 130, 145)
closeBtn.TextSize = 13
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Modal = false
closeBtn.Parent = frame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -20, 0, 22)
statusLbl.Position = UDim2.fromOffset(10, 34)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "Status: Ready"
statusLbl.TextColor3 = Color3.fromRGB(165, 175, 205)
statusLbl.TextSize = 12
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = frame

local function makeToggle(labelText, yPos, initial, onToggle)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 34)
    btn.Position = UDim2.fromOffset(10, yPos)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.Modal = false
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local value = initial
    local function refresh()
        btn.Text = labelText .. ": " .. (value and "ON" or "OFF")
        btn.BackgroundColor3 = value and Color3.fromRGB(46, 115, 78) or Color3.fromRGB(45, 48, 64)
        btn.TextColor3 = Color3.fromRGB(245, 248, 255)
    end
    refresh()

    btn.Activated:Connect(function()
        value = not value
        refresh()
        onToggle(value)
        saveSettings()
    end)
    return btn
end

makeToggle("Auto Skip Waves", 64, State.AutoSkip, function(v) State.AutoSkip = v end)
makeToggle("Anti-AFK", 106, State.AntiAFK, function(v) State.AntiAFK = v end)
makeToggle("Auto Re-Execute", 148, State.AutoExecute, function(v)
    State.AutoExecute = v
    if v then pcall(queueTeleport) end
end)

function State.Destroy()
    State.Running = false
    for _, c in ipairs(State.Connections) do
        pcall(function() c:Disconnect() end)
    end
    State.Connections = {}
    pcall(function() gui:Destroy() end)
end

closeBtn.Activated:Connect(State.Destroy)

-- Anti-AFK listener
State.Connections[#State.Connections + 1] = P.Idled:Connect(function()
    if State.Running and State.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

-- Lightweight Auto Skip loop (0.35s interval)
task.spawn(function()
    while State.Running do
        if State.AutoSkip then
            local ok, err = pcall(function()
                local matchData = RS:FindFirstChild("MatchData")
                if not matchData then
                    statusLbl.Text = "Status: Lobby"
                    return
                end
                local waveObj = matchData:FindFirstChild("CurrentWave")
                local waveText = waveObj and tostring(waveObj.Value) or "?"
                local skipFolder = matchData:FindFirstChild("Skip")
                local canSkipObj = skipFolder and skipFolder:FindFirstChild("CanSkip")
                local canSkip = canSkipObj and canSkipObj.Value == true

                local voters = skipFolder and skipFolder:FindFirstChild("VotedPlayers")
                local alreadyVoted = voters and voters:FindFirstChild(tostring(P.UserId)) ~= nil

                local skipFrame = getChild(P:FindFirstChild("PlayerGui"), "Match", "MatchInfo", "TopText", "SkipWave")
                local button = getChild(skipFrame, "SkipButton", "SkipWave") or getChild(skipFrame, "SkipButton")

                if not canSkipObj and button then
                    canSkip = isVisible(button)
                end

                statusLbl.Text = "Wave: " .. waveText .. (alreadyVoted and " (Voted)" or canSkip and " (Skipping...)" or "")

                if canSkip and not alreadyVoted and (os.clock() - State.LastSkipAt) >= 1.0 then
                    if button and isVisible(button) then
                        State.LastSkipAt = os.clock()
                        fireGuiButton(button)
                    end
                end
            end)
            if not ok then
                statusLbl.Text = "Error: " .. tostring(err):sub(1, 30)
            end
        else
            statusLbl.Text = "Status: Auto Skip OFF"
        end
        task.wait(0.35)
    end
end)
