local QBCore = exports['qb-core']:GetCoreObject()

if not Config then
    print("^1[greve-helihud]^7 config.lua not loaded!")
    return
end

-- HUD STATE
local blink = false
local HUDVisible = true -- default visible
local lastFuelAlert, lastRotorAlert, lastLandingAlert = false, false, false

-- BLINK THREAD
Citizen.CreateThread(function()
    while true do
        blink = not blink
        Citizen.Wait(500)
    end
end)

-- CURRENT HELI HUD TOGGLE KEY (from config)
local HUDToggleKey = Config.HUDToggleKey or 96 -- default Numpad 0

-- FUNCTION TO TOGGLE HUD
local function ToggleHUD()
    HUDVisible = not HUDVisible
    if HUDVisible then
        QBCore.Functions.Notify("Helikopter HUD Aktivert!", "success")
    else
        QBCore.Functions.Notify("Helikopter HUD Deaktivert", "error")
    end
end

-- BIND KEY THREAD
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsControlJustReleased(0, HUDToggleKey) then
            ToggleHUD()
        end
    end
end)

-- FUNCTION TO RESET HUD/UI POSITIONS
local function ResetHUD()
    -- Reset main heli HUD position to preset from config
    Config.UI = { x = 0.3, y = 0.43 }        -- default position
    -- Reset damage panel
    Config.DamageUI = { x = 0.88, y = 0.20 } -- default damage panel position
    QBCore.Functions.Notify("Helikopter HUD og UI har blitt tilbakestilt!", "success")
end

-- TOGGLE HELI HUD COMMAND
RegisterCommand("togglehelihud", function()
    ToggleHUD()
end, false)

-- RESET HELI HUD COMMAND
RegisterCommand("resethelihud", function()
    ResetHUD()
end, false)

-- ADD CHAT SUGGESTIONS
TriggerEvent('chat:addSuggestion', '/togglehelihud', 'Slår på eller av helikopter HUD.')
TriggerEvent('chat:addSuggestion', '/resethelihud', 'Tilbakestiller helikopter HUD og UI til standard posisjon.')

-- REGISTER KEY MAPPINGS
RegisterKeyMapping("togglehelihud", "Slår på/av helikopter HUD", "keyboard", "F3")
RegisterKeyMapping("resethelihud", "Tilbakestill helikopter HUD og UI", "keyboard", "F5")

-- PLAY ALERT SOUNDS
local function PlayAlertSound(type)
    if not Config.SoundAlerts then return end

    if type == "fuel" then
        PlaySoundFrontend(-1, "Lose_Health", "HUD_Awareness_Sounds", true)
    elseif type == "rotor" then
        PlaySoundFrontend(-1, "Oneshot_Final", "MP_MISSION_COUNTDOWN_SOUNDSET", true)
    elseif type == "landing" then
        PlaySoundFrontend(-1, "MP_Alert", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    end
end

-- DRAW TEXT HELPER
local function Text(text, x, y, scale)
    SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextOutline()
    SetTextJustification(0)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

-- DAMAGE STATUS COLOR
local function StatusColor(value, good, warn)
    if value >= good then
        return "~g~OKEI"
    elseif value >= warn then
        return "~y~ØDELAGT"
    else
        return "~r~KRITISK"
    end
end

-- QBX JOB + ON DUTY CHECK
local function CanSeeHUD()
    local PlayerData = QBCore.Functions.GetPlayerData()
    local job = PlayerData.job.name
    local onDuty = PlayerData.job.onduty
    if not onDuty then return false end

    for _, allowedJob in pairs(Config.AllowedJobs) do
        if job == allowedJob then
            return true
        end
    end
    return false
end

-- CALCULATE HUD WIDTH DYNAMICALLY
local function GetHUDWidth()
    local width = 0.305 -- Base rectangle width
    if not Config.ShowFuel then width = width - 0.05 end
    if not Config.ShowLandingAssist then width = width - 0.05 end
    return width
end

-- MAIN HELI HUD THREAD
Citizen.CreateThread(function()
    while true do
        local sleep = 500
        local Ped = PlayerPedId()

        if IsPedInAnyHeli(Ped) and CanSeeHUD() and HUDVisible then
            sleep = 0
            local Veh = GetVehiclePedIsIn(Ped, false)
            local Speed = GetEntitySpeed(Veh) * 2.24
            local Height = GetEntityHeightAboveGround(Veh)
            local Engine = GetIsVehicleEngineRunning(Veh)

            local MainRotor = GetHeliMainRotorHealth(Veh)
            local TailRotor = GetHeliTailRotorHealth(Veh)
            local EngineHealth = GetVehicleEngineHealth(Veh)
            local BodyHealth = GetVehicleBodyHealth(Veh)
            local Fuel = GetVehicleFuelLevel(Veh)

            local hudWidth = GetHUDWidth()

            -- ENGINE
            Text((Engine and "~g~MTR" or "~r~MTR"), Config.UI.x + 0.4016, Config.UI.y + 0.476, 0.55)
            Text((Engine and "~g~__" or "~r~__"), Config.UI.x + 0.4016, Config.UI.y + 0.47, 0.79)

            -- ROTORS
            local MainColor = (MainRotor < 200 or not Engine) and "~r~" or (MainRotor < 800 and "~y~" or "~g~")
            local TailColor = (TailRotor < 100 or not Engine) and "~r~" or (TailRotor < 300 and "~y~" or "~g~")
            Text(MainColor .. "HOVED", Config.UI.x + 0.4516, Config.UI.y + 0.476, 0.55)
            Text(MainColor .. "__", Config.UI.x + 0.4516, Config.UI.y + 0.47, 0.79)
            Text(TailColor .. "HALE", Config.UI.x + 0.5, Config.UI.y + 0.476, 0.55)
            Text(TailColor .. "__", Config.UI.x + 0.5, Config.UI.y + 0.47, 0.79)

            -- ALTITUDE / SPEED
            Text(math.ceil(Height), Config.UI.x + 0.549, Config.UI.y + 0.476, 0.45)
            Text("HØYDE", Config.UI.x + 0.549, Config.UI.y + 0.502, 0.29)
            Text(math.ceil(Speed), Config.UI.x + 0.598, Config.UI.y + 0.476, 0.45)
            Text("LUFTHASTIGHET", Config.UI.x + 0.598, Config.UI.y + 0.502, 0.29)

            -- FUEL
            if Config.ShowFuel then
                local FuelColor = Fuel < 20 and "~r~" or Fuel < 40 and "~y~" or "~g~"
                Text(FuelColor .. math.ceil(Fuel) .. "%", Config.UI.x + 0.647, Config.UI.y + 0.476, 0.45)
                Text("DRIVSTOFF", Config.UI.x + 0.647, Config.UI.y + 0.502, 0.29)
            end

            -- BACKGROUND RECTANGLE
            DrawRect(Config.UI.x + 0.52, Config.UI.y + 0.5, hudWidth, 0.085, 25, 25, 25, 255)
            DrawRect(Config.UI.x + 0.52, Config.UI.y + 0.5, hudWidth - 0.01, 0.075, 51, 51, 51, 255)
            for i = 0, 5 do
                DrawRect(Config.UI.x + 0.402 + (i * 0.049), Config.UI.y + 0.5, 0.040, 0.050, 25, 25, 25, 255)
            end

            -- LANDING ASSIST
            if Config.ShowLandingAssist then
                local VerticalSpeed = math.abs(GetEntityVelocity(Veh).z)
                if Height < 30.0 then
                    if VerticalSpeed < 1.5 and Speed < 10 then
                        Text("~g~TRYGG FOR LANDING", Config.UI.x + 0.5, Config.UI.y + 0.415, 0.40)
                    elseif VerticalSpeed < 3.0 then
                        Text("~y~FORSIKTIG NEDSTIGNING", Config.UI.x + 0.5, Config.UI.y + 0.415, 0.40)
                    elseif blink then
                        Text("~r~HARD LANDING", Config.UI.x + 0.5, Config.UI.y + 0.415, 0.45)
                        if not lastLandingAlert then
                            PlayAlertSound("landing")
                            lastLandingAlert = true
                        end
                    else
                        lastLandingAlert = false
                    end
                end
            end

            -- WARNINGS
            if Config.ShowFuelWarnings then
                if Fuel < 20 and blink then
                    Text("~r~LAVT DRIVSTOFF", Config.UI.x + 0.5, Config.UI.y + 0.385, 0.45)
                    if not lastFuelAlert then
                        PlayAlertSound("fuel")
                        lastFuelAlert = true
                    end
                else
                    lastFuelAlert = false
                end
            end

            if MainRotor < 200 and blink then
                Text("~r~ROTORFEIL", Config.UI.x + 0.5, Config.UI.y + 0.355, 0.45)
                if not lastRotorAlert then
                    PlayAlertSound("rotor")
                    lastRotorAlert = true
                end
            else
                lastRotorAlert = false
            end

            -- DAMAGE PANEL
            if Config.ShowDamagePanel then
                local panelX = Config.DamageUI.x
                local panelY = Config.DamageUI.y
                local panelWidth = 0.18
                local panelHeight = 0.14

                DrawRect(panelX, panelY + 0.05, panelWidth, panelHeight, 20, 20, 20, 200)

                local centerX = panelX

                local function CenteredText(text, yOffset, scale)
                    SetTextFont(4)
                    SetTextProportional(0)
                    SetTextScale(scale, scale)
                    SetTextEdge(1, 0, 0, 0, 255)
                    SetTextDropShadow(0, 0, 0, 0, 255)
                    SetTextOutline()
                    SetTextCentre(true)
                    SetTextEntry("STRING")
                    AddTextComponentString(text)
                    DrawText(centerX, panelY + yOffset)
                end

                CenteredText("SYSTEM STATUS", -0.045, 0.35)
                local entryStart = -0.015
                local entryGap = 0.03
                CenteredText("MOTOR: " .. StatusColor(EngineHealth, 700, 300), entryStart + entryGap * 0, 0.30)
                CenteredText("HOVED: " .. StatusColor(MainRotor, 800, 200), entryStart + entryGap * 1, 0.30)
                CenteredText("HALE: " .. StatusColor(TailRotor, 300, 100), entryStart + entryGap * 2, 0.30)
                CenteredText("Helikopterskrog: " .. StatusColor(BodyHealth, 700, 300), entryStart + entryGap * 3, 0.30)
            end

            -- AUTO SHUTDOWN EMPTY FUEL
            if Config.AutoEngineOffOnEmptyFuel and Fuel <= 0 and Engine then
                SetVehicleEngineOn(Veh, false, true, true)
            end
        end

        Citizen.Wait(sleep)
    end
end)

-- AUTO SHUTDOWN AFTER LANDING
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        local Ped = PlayerPedId()
        if IsPedInAnyHeli(Ped) and CanSeeHUD() then
            local Veh = GetVehiclePedIsIn(Ped, false)
            if GetEntityHeightAboveGround(Veh) < 3.0 and GetEntitySpeed(Veh) < 0.5 and GetIsVehicleEngineRunning(Veh) then
                Citizen.Wait(5000)
                SetVehicleEngineOn(Veh, false, true, true)
            end
        end
    end
end)
