-- Standalone Legacy controls; does not replace the upstream macro recorder.
if not game:IsLoaded() then game.Loaded:Wait() end
local players=game:GetService("Players")
local player=players.LocalPlayer
while not player do task.wait(.1);player=players.LocalPlayer end
local env=type(getgenv)=="function" and getgenv() or _G
if env.__TTDLegacyExtras then env.__TTDLegacyExtras.Destroy() end
local gui=Instance.new("ScreenGui")
gui.Name="TTDLegacyExtrasR2";gui.ResetOnSpawn=false;gui.DisplayOrder=50
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=player:WaitForChild("PlayerGui")
local frame=Instance.new("Frame")
frame.Size=UDim2.fromOffset(256,132);frame.Position=UDim2.new(1,-268,0,100)
frame.BackgroundColor3=Color3.fromRGB(24,24,27);frame.BorderSizePixel=0;frame.Parent=gui
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,8)
local title=Instance.new("TextLabel")
title.Size=UDim2.new(1,-42,0,32);title.Position=UDim2.fromOffset(12,0)
title.BackgroundTransparency=1;title.Text="Legacy · Extras r2";title.TextSize=14
title.TextColor3=Color3.fromRGB(240,240,240);title.Font=Enum.Font.GothamMedium
title.TextXAlignment=Enum.TextXAlignment.Left;title.Parent=frame
local close=Instance.new("TextButton")
close.Size=UDim2.fromOffset(32,32);close.Position=UDim2.new(1,-34,0,0)
close.BackgroundTransparency=1;close.Text="×";close.TextSize=22
close.TextColor3=Color3.fromRGB(200,200,200);close.Parent=frame
local status=Instance.new("TextLabel")
status.Size=UDim2.new(1,-24,0,46);status.Position=UDim2.fromOffset(12,81)
status.BackgroundTransparency=1;status.Text="Visual controls only · macro recorder unchanged"
status.TextWrapped=true;status.TextSize=12;status.Font=Enum.Font.Gotham
status.TextColor3=Color3.fromRGB(175,175,180);status.Parent=frame
local H={}
function H.Notify(message) status.Text=tostring(message) end
function H.Destroy() gui:Destroy();env.__TTDLegacyExtras=nil end
local tab={}
function tab:Toggle(options)
    local button=Instance.new("TextButton")
    button.Size=UDim2.new(1,-24,0,42);button.Position=UDim2.fromOffset(12,36)
    button.TextSize=14;button.Font=Enum.Font.GothamMedium
    button.TextColor3=Color3.fromRGB(245,245,245);button.BorderSizePixel=0;button.Parent=frame
    Instance.new("UICorner",button).CornerRadius=UDim.new(0,6)
    local enabled=false
    local function refresh()
        button.Text="Hide 50% Enemies: "..(enabled and "ON" or "OFF")
        button.BackgroundColor3=enabled and Color3.fromRGB(43,94,160) or Color3.fromRGB(48,48,54)
    end
    button.Activated:Connect(function()
        enabled=not enabled;refresh()
        local ok,why=pcall(options.Callback,enabled)
        if not ok then H.Notify("Error: "..tostring(why)) end
    end)
    refresh()
end
local install=(function()
-- Local rendering reduction. Never removes models or changes collision/networking.
return function(H,WS,Players,tab,window)
    local C={Enabled=false,Alive=true,Hidden={},Connections={},RootConnections={},Count=0,Total=0}
    H.EnemyVisibility=C
    local names={"Toilets","Enemies","EnemyUnits","EnemyTroops"}
    local roots={}
    local pending=false
    local function disconnect(list) for _,c in ipairs(list) do c:Disconnect() end;table.clear(list) end
    local function restore(record,obj)
        local values=record.Values[obj]
        if not values then return end
        for key,pair in pairs(values) do
            pcall(function() if obj[key]==pair.Applied then obj[key]=pair.Original end end)
        end
        record.Values[obj]=nil
    end
    local function show(model)
        local record=C.Hidden[model]
        if not record then return end
        disconnect(record.Connections)
        for obj in pairs(record.Values) do restore(record,obj) end
        C.Hidden[model]=nil
    end
    local function hide(model)
        if C.Hidden[model] then return end
        local record={Values={},Connections={}};C.Hidden[model]=record
        local function set(obj,key,value)
            local ok,old=pcall(function() return obj[key] end)
            if not ok or old==value then return end
            local changed=pcall(function() obj[key]=value end)
            if changed then record.Values[obj]=record.Values[obj] or {};record.Values[obj][key]={Original=old,Applied=value} end
        end
        local function apply(obj)
            if obj:IsA("BasePart") then set(obj,"LocalTransparencyModifier",1);set(obj,"CastShadow",false)
            elseif obj:IsA("Decal") or obj:IsA("Texture") then set(obj,"Transparency",1)
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Light") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") or obj:IsA("Highlight") then set(obj,"Enabled",false) end
        end
        record.Connections[1]=model.DescendantAdded:Connect(apply)
        record.Connections[2]=model.DescendantRemoving:Connect(function(obj) restore(record,obj) end)
        for _,obj in ipairs(model:GetDescendants()) do apply(obj) end
    end
    local function eligible(model)
        return model:IsA("Model") and not model:FindFirstChild("TroopOwner") and not Players:GetPlayerFromCharacter(model)
    end
    function C.Reconcile()
        pending=false
        if not C.Alive or not C.Enabled then return end
        local models,live={},{}
        for _,root in ipairs(roots) do
            if root.Parent==WS then for _,model in ipairs(root:GetChildren()) do
                if eligible(model) then models[#models+1]=model;live[model]=true end
            end end
        end
        for model in pairs(C.Hidden) do if not live[model] then show(model) end end
        local count=0;for _ in pairs(C.Hidden) do count=count+1 end
        local target=math.floor(#models/2)
        -- Preserve the existing selection so living enemies do not flicker.
        for i=#models,1,-1 do
            if count<=target then break end
            if C.Hidden[models[i]] then show(models[i]);count=count-1 end
        end
        for pass=1,2 do
            for i,model in ipairs(models) do
                if count>=target then break end
                if not C.Hidden[model] and (pass==2 or i%2==0) then hide(model);count=count+1 end
            end
        end
        C.Count=count;C.Total=#models
    end
    local function schedule()
        if pending or not C.Enabled or not C.Alive then return end
        pending=true;task.defer(C.Reconcile)
    end
    local function bindRoots()
        disconnect(C.RootConnections);table.clear(roots)
        if not C.Enabled then return end
        for _,name in ipairs(names) do
            local root=WS:FindFirstChild(name)
            if root and (root:IsA("Folder") or root:IsA("Model")) then
                roots[#roots+1]=root
                C.RootConnections[#C.RootConnections+1]=root.ChildAdded:Connect(schedule)
                C.RootConnections[#C.RootConnections+1]=root.ChildRemoved:Connect(schedule)
            end
        end
        schedule()
    end
    function C.Set(enabled)
        C.Enabled=enabled==true
        disconnect(C.Connections);disconnect(C.RootConnections)
        if not C.Enabled then
            for model in pairs(C.Hidden) do show(model) end
            C.Count=0;C.Total=0;return
        end
        C.Connections[1]=WS.ChildAdded:Connect(bindRoots)
        C.Connections[2]=WS.ChildRemoved:Connect(bindRoots)
        bindRoots();C.Reconcile()
        if #roots==0 then H.Notify("Hide 50% Enemies: waiting for an enemy folder (Toilets / Enemies).")
        else H.Notify("Enemy visuals hidden: "..C.Count.." / "..C.Total) end
    end
    tab:Toggle({Title="Hide 50% Enemies",Desc="Hide half the enemy models and their effects on this device. Turn off to restore.",Value=false,Callback=C.Set})
    local destroy=H.Destroy
    function H.Destroy()
        C.Set(false);C.Alive=false
        return destroy()
    end
    if window and type(window.OnDestroy)=="function" then
        window:OnDestroy(function() C.Set(false);C.Alive=false end)
    end
    return C
end

end)()
install(H,workspace,players,tab)
env.__TTDLegacyExtras=H
close.Activated:Connect(function() H.Destroy() end)
return H
