-- taxijob.lua -- WhipFX edition
-- The clerk hands a cab out, fares are hailed around the city, and the meter rides on a WhipFX
-- objective card instead of its own NUI page.

local RESOURCE = GetCurrentResourceName()
local MARKER_COLOUR = { r = 240, g = 200, b = 60, a = 200 }
local METER_CARD = 'meter'

-- Runtime state for this player's shift
local state = {
    active = false,       -- a cab is signed out
    vehicle = nil,        -- the cab entity
    pickup = nil,         -- index into Config.PickupLocations
    drop = nil,           -- index into Config.DropLocations
    lastPickup = nil,
    lastDrop = nil,
    passenger = nil,      -- the hailing ped
    carrying = false,     -- passenger is aboard
    target = nil,         -- the vector4 the marker sits on
    routeBlip = nil,
    actions = {},
    awayFor = 0,
}

-- The meter
local meter = {
    open = false,
    fare = 0,
    miles = 0,
    lastCoords = nil,
    from = nil,           -- where the fare was picked up
    to = nil,             -- where it is going
}

local function notify(text, kind)
    exports.whip_core:Notify(text, kind or 'info')
end

--- What a prompt asks of the player. On 'open' there is no job to ask for, so only `extra` is
--- required -- the server checks the same way (see mayWork).
local function workRequire(extra)
    local req, any = {}, false
    for k, v in pairs(extra or {}) do req[k] = v; any = true end
    if Config.DutyMode ~= 'open' then
        req.job = Config.JobKey
        req.onDuty = true
        any = true
    end
    return any and req or nil
end

local function onDuty()
    return exports.whip_core:IsPlayerClockedOn(Config.JobKey) == true
end

local function removeAction(slot)
    if state.actions[slot] then
        exports.whip_core:RemoveAction(state.actions[slot])
        state.actions[slot] = nil
    end
end

--- The cab this player signed out, only while they are driving it.
local function jobVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= state.vehicle or GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return veh
end

-- Blips --------------------------------------------------------------------

local function clearBlip(handle)
    if handle and DoesBlipExist(handle) then RemoveBlip(handle) end
    return nil
end

--- The route to the next place the cab has to be. The depot blip is the server's (ShowBlip);
--- this one changes with every fare, so it lives and dies on this client.
local function routeBlip(coords)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipColour(blip, 5)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 5)
    return blip
end

-- The meter ----------------------------------------------------------------

local function showMeter()
    exports.whip_core:ShowObjective(METER_CARD, Lang:t('info.meter_title', meter.fare), {
        name = Lang:t('info.meter_distance', meter.miles),
        icon = 'cash',
    })
end

local function startMeter(from, to)
    meter.open = true
    meter.fare = Config.Meter.startingPrice
    meter.miles = 0
    meter.lastCoords = GetEntityCoords(PlayerPedId())
    meter.from = from
    meter.to = to
    showMeter()
end

local function stopMeter()
    meter.open = false
    meter.fare = 0
    meter.miles = 0
    meter.lastCoords = nil
    meter.from, meter.to = nil, nil
    exports.whip_core:HideObjective(METER_CARD)
end

--- Walks the meter on by however far the cab moved since the last tick.
local function tickMeter()
    if not meter.open or not meter.lastCoords then return end

    local coords = GetEntityCoords(PlayerPedId())
    if coords == meter.lastCoords then return end

    meter.miles = meter.miles + (#(coords - meter.lastCoords) / 1609.0)
    meter.lastCoords = coords

    local fare
    if Config.Meter.useGpsPrice and meter.from and meter.to then
        -- Bill the route the GPS would have taken, filled in as the cab covers it.
        local route = CalculateTravelDistanceBetweenPoints(
            meter.from.x, meter.from.y, meter.from.z,
            meter.to.x, meter.to.y, meter.to.z) / 1609.0
        local progress = route > 0 and math.min(meter.miles / route, 1.0) or 1.0
        fare = (route * progress * Config.Meter.pricePerMile) + Config.Meter.startingPrice
    else
        fare = (meter.miles * Config.Meter.pricePerMile) + Config.Meter.startingPrice
    end

    local was = meter.fare
    meter.fare = math.floor(math.min(fare, Config.MaxFare))
    if meter.fare ~= was then showMeter() end
end

-- Passengers ---------------------------------------------------------------

local function spawnPassenger(at)
    local model = exports.whip_core:LoadModel(Config.NpcSkins[math.random(1, #Config.NpcSkins)])
    if not model then return nil end

    local ped = CreatePed(3, model, at.x, at.y, at.z - 0.98, at.w, false, true)
    SetModelAsNoLongerNeeded(model)
    PlaceObjectOnGroundProperly(ped)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    return ped
end

--- Let the passenger wander off on their own and tidy them up a minute later.
local function releasePassenger(ped)
    if not ped or not DoesEntityExist(ped) then return end
    SetEntityAsMissionEntity(ped, false, true)
    SetEntityAsNoLongerNeeded(ped)
    SetTimeout(60000, function()
        if DoesEntityExist(ped) then DeletePed(ped) end
    end)
end

local function clearPassenger()
    if state.passenger and DoesEntityExist(state.passenger) then
        DeletePed(state.passenger)
    end
    state.passenger = nil
end

-- Fares --------------------------------------------------------------------

--- Picks an index that is not the one just used, so two fares never run back to back.
local function pickIndex(list, last)
    if #list < 2 then return 1 end
    local index
    repeat index = math.random(1, #list) until index ~= last
    return index
end

local offerPickup, offerDropoff

--- The prompt on the ped waiting at the kerb.
function offerPickup()
    removeAction('fare')
    clearPassenger()

    state.pickup = pickIndex(Config.PickupLocations, state.lastPickup)
    state.lastPickup = state.pickup
    state.target = Config.PickupLocations[state.pickup]
    state.passenger = spawnPassenger(state.target)

    state.routeBlip = clearBlip(state.routeBlip)
    state.routeBlip = routeBlip(state.target)
    notify(Lang:t('info.npc_on_gps'), 'success')

    local at = state.target
    state.actions.fare = exports.whip_core:AddAction({
        id = RESOURCE .. ':pickup',
        at = { coords = at.xyz },
        label = Lang:t('info.call_npc'),
        icon = 'ped',
        reach = Config.Reach.fare,
        focusMode = 'near',
        require = workRequire({ vehicle = 'in' }),
        canInteract = function()
            return state.active and not state.carrying and jobVehicle() ~= nil
        end,
        onSelect = function()
            local veh = jobVehicle()
            if not veh then return notify(Lang:t('error.not_in_taxi'), 'error') end

            local seat
            for i = GetVehicleMaxNumberOfPassengers(veh) - 1, 0, -1 do
                if IsVehicleSeatFree(veh, i) then seat = i break end
            end
            if not seat then
                return notify(Lang:t('error.cab_full'), 'error')
            end

            if state.passenger and DoesEntityExist(state.passenger) then
                ClearPedTasksImmediately(state.passenger)
                FreezeEntityPosition(state.passenger, false)
                TaskEnterVehicle(state.passenger, veh, -1, seat, 1.0, 0)
            end

            state.carrying = true
            state.routeBlip = clearBlip(state.routeBlip)
            removeAction('fare')

            notify(Lang:t('info.go_to_location'))
            offerDropoff()
        end,
    })
end

--- The prompt at the address the passenger asked for.
function offerDropoff()
    removeAction('fare')

    state.drop = pickIndex(Config.DropLocations, state.lastDrop)
    state.lastDrop = state.drop
    state.target = Config.DropLocations[state.drop]

    state.routeBlip = clearBlip(state.routeBlip)
    state.routeBlip = routeBlip(state.target)

    startMeter(GetEntityCoords(PlayerPedId()), state.target.xyz)

    local at = state.target
    local drop = state.drop
    state.actions.fare = exports.whip_core:AddAction({
        id = RESOURCE .. ':dropoff',
        at = { coords = at.xyz },
        label = Lang:t('info.drop_off_npc'),
        icon = 'car',
        reach = Config.Reach.fare,
        focusMode = 'near',
        require = workRequire({ vehicle = 'in' }),
        canInteract = function()
            return state.active and state.carrying and jobVehicle() ~= nil
        end,
        onSelect = function()
            local veh = jobVehicle()
            if not veh then return notify(Lang:t('error.not_in_taxi'), 'error') end

            -- Settle before the meter is cleared: the server caps and tips the amount itself.
            TriggerServerEvent(RESOURCE .. ':settleFare', drop, meter.fare)
            stopMeter()

            local ped = state.passenger
            if ped and DoesEntityExist(ped) then
                TaskLeaveVehicle(ped, veh, 0)
                TaskGoStraightToCoord(ped, at.x, at.y, at.z, 1.0, -1, at.w, 0.0)
                releasePassenger(ped)
            end
            state.passenger = nil
            state.carrying = false
            state.routeBlip = clearBlip(state.routeBlip)
            removeAction('fare')

            notify(Lang:t('success.person_was_dropped_off'), 'success')
            offerPickup()
        end,
    })
end

-- Shifts -------------------------------------------------------------------

local function stopShift(silent)
    removeAction('fare')
    state.routeBlip = clearBlip(state.routeBlip)
    clearPassenger()
    stopMeter()
    state.active = false
    state.carrying = false
    state.vehicle = nil
    state.target = nil
    state.awayFor = 0
    if not silent then
        notify(Lang:t('success.taxi_returned'), 'success')
    end
end

local function takeCab(model)
    if state.active then
        return notify(Lang:t('error.one_cab_active'), 'error')
    end

    -- The server picks the rank spot: it walks the rank until one is clear, and says so when
    -- none is.
    local netId, why = exports.whip_core:Callback(RESOURCE .. ':takeVehicle', model)
    if not netId then
        return notify(why or Lang:t('error.no_spawn_point'), 'error')
    end

    local timeout = GetGameTimer() + 10000
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < timeout do
        Wait(50)
    end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(veh) then
        TriggerServerEvent(RESOURCE .. ':cancelShift')
        return notify(Lang:t('error.parking_blocked'), 'error')
    end

    state.active = true
    state.carrying = false
    state.vehicle = veh
    state.awayFor = 0

    SetVehicleEngineOn(veh, true, true, false)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)

    offerPickup()
end

-- Setup --------------------------------------------------------------------

local function clerkOptions()
    local options = {}

    -- Going on duty. On 'signon' anyone may: the server takes them on and clocks them on in one go.
    -- On 'hired' only an existing driver may, through whip_core's own ClockOn.
    if Config.DutyMode == 'signon' then
        options[#options + 1] = {
            id = 'signon',
            label = Lang:t('info.sign_on'),
            icon = 'timer',
            canInteract = function() return not onDuty() end,
            onSelect = function(ctx)
                local ok, why = exports.whip_core:Callback(RESOURCE .. ':signOn')
                if not ok then return ctx.refuse(why) end
            end,
        }
    elseif Config.DutyMode == 'hired' then
        options[#options + 1] = {
            id = 'clockon',
            label = Lang:t('info.clock_on'),
            icon = 'timer',
            require = { job = Config.JobKey },
            canInteract = function() return not onDuty() end,
            onSelect = function(ctx)
                local ok, why = exports.whip_core:ClockOn(Config.JobKey)
                if not ok then return ctx.refuse(why) end
                notify(Lang:t('success.clocked_on'), 'success')
            end,
        }
    end

    for _, cab in ipairs(Config.Vehicles) do
        local display = GetLabelText(GetDisplayNameFromVehicleModel(joaat(cab.model)))
        if display == 'NULL' or display == '' then display = cab.label end
        options[#options + 1] = {
            id = 'take:' .. cab.model,
            label = Lang:t('info.take_cab', display),
            icon = 'car',
            require = workRequire(),
            canInteract = function() return not state.active end,
            onSelect = function() takeCab(cab.model) end,
        }
    end

    -- A driver who lost the thread of a fare can ask for a new one.
    options[#options + 1] = {
        id = 'hail',
        label = Lang:t('info.hail_fare'),
        icon = 'car',
        require = workRequire(),
        canInteract = function() return state.active and not state.carrying end,
        onSelect = function() offerPickup() end,
    }

    -- ...and off it again. The cab has to be back on the rank first.
    if Config.DutyMode == 'signon' then
        options[#options + 1] = {
            id = 'signoff',
            label = Lang:t('info.sign_off'),
            icon = 'timer',
            require = workRequire(),
            canInteract = function() return not state.active end,
            onSelect = function(ctx)
                local ok, why = exports.whip_core:Callback(RESOURCE .. ':signOff')
                if not ok then return ctx.refuse(why) end
            end,
        }
    elseif Config.DutyMode == 'hired' then
        options[#options + 1] = {
            id = 'clockoff',
            label = Lang:t('info.clock_off'),
            icon = 'timer',
            require = workRequire(),
            canInteract = function() return not state.active end,
            onSelect = function()
                exports.whip_core:ClockOff(Config.JobKey)
                notify(Lang:t('success.clocked_off'), 'success')
            end,
        }
    end

    return options
end

Whip.register(function()
    -- The depot clerk: clock on or off and sign a cab out. The server publishes its netId in
    -- GlobalState, which may land after we register, so wait for it.
    CreateThread(function()
        local deadline = GetGameTimer() + 60000
        local netId
        repeat
            netId = GlobalState[RESOURCE .. ':clerk']
            if not netId then Wait(500) end
        until netId or GetGameTimer() > deadline

        if not netId then return end
        removeAction('clerk')
        state.actions.clerk = exports.whip_core:AddAction({
            id = RESOURCE .. ':clerk',
            at = { netId = netId, offset = vector3(0.0, 0.0, 0.4) },
            label = Lang:t('info.clerk_label'),
            icon = 'car',
            options = clerkOptions(),
        })
    end)

    -- Parking the cab back on the rank ends the shift and returns the deposit.
    removeAction('rank')
    state.actions.rank = exports.whip_core:AddAction({
        id = RESOURCE .. ':rank',
        at = { coords = Config.Depot.rank.xyz },
        label = Lang:t('info.park_cab'),
        icon = 'car',
        reach = Config.Reach.rank,
        focusMode = 'near',
        require = workRequire({ vehicle = 'in' }),
        canInteract = function()
            return state.active and jobVehicle() ~= nil
        end,
        onSelect = function()
            if state.carrying then
                return notify(Lang:t('error.passenger_aboard'), 'error')
            end
            TriggerServerEvent(RESOURCE .. ':returnVehicle')
        end,
    })
end)

RegisterNetEvent(RESOURCE .. ':client:shiftEnded', function(cancelled)
    stopShift(cancelled)
    if cancelled then
        notify(Lang:t('error.killed_job'), 'error')
    end
end)

-- Threads ------------------------------------------------------------------

-- The meter, and the watchdog on a driver who walks away from the cab.
CreateThread(function()
    while true do
        Wait(1000)
        if state.active then
            if jobVehicle() then
                state.awayFor = 0
                tickMeter()
            else
                state.awayFor = state.awayFor + 1
                if state.awayFor >= Config.AwaySeconds then
                    state.awayFor = 0
                    TriggerServerEvent(RESOURCE .. ':cancelShift')
                end
            end
        end
    end
end)

-- A marker on wherever the cab has to be next.
CreateThread(function()
    while true do
        local sleep = 500
        local coords = GetEntityCoords(PlayerPedId())

        if state.active and state.target then
            local at = state.target
            if #(coords - at.xyz) < 50.0 then
                sleep = 0
                DrawMarker(1, at.x, at.y, at.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    3.0, 3.0, 1.0, MARKER_COLOUR.r, MARKER_COLOUR.g, MARKER_COLOUR.b, MARKER_COLOUR.a,
                    false, false, 2, false, nil, nil, false)
            end
        end

        if Config.DebugMarkers then
            sleep = 0
            for _, list in ipairs({ Config.PickupLocations, Config.DropLocations }) do
                for _, at in ipairs(list) do
                    if #(coords - at.xyz) < 100.0 then
                        DrawMarker(1, at.x, at.y, at.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            3.0, 3.0, 1.0, 255, 80, 80, 120, false, false, 2, false, nil, nil, false)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    state.routeBlip = clearBlip(state.routeBlip)
    clearPassenger()
end)
