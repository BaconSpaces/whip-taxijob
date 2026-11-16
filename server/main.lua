-- main.lua -- WhipFX edition
-- The cab rank signs cabs out, settles fares and takes them back. Every value a client sends is
-- declared on a SecureEvent/SecureCallback, so whip_core checks who asked, how often, from where
-- and what before a handler runs.

local RESOURCE = GetCurrentResourceName()
local TAG = RESOURCE .. ':cabs'

-- Who has a cab out: [source] = { vehicleId, receipt, session, charId, lastPay }
local shifts = {}

local MODELS = {}
for _, v in ipairs(Config.Vehicles) do MODELS[#MODELS + 1] = v.model end

local function rollTip()
    if math.random(1, 100) > Config.TipChance then return 0 end
    return math.random(Config.Tip.min, Config.Tip.max)
end

local function makePlate()
    return 'TAXI' .. math.random(1000, 9999)
end

--- The level a driver starts on, so sign-off can tell a casual driver from a promoted one.
local STARTING_LEVEL = 100
for _, role in ipairs(Config.JobRoles) do
    if (role.level or 1) < STARTING_LEVEL then STARTING_LEVEL = role.level or 1 end
end

--- May this player work? On 'open' anybody may; on 'signon' and 'hired' they must be on duty.
--- The client asks the same way (see workRequire).
local function mayWork(src)
    if Config.DutyMode == 'open' then return true end
    return exports.whip_core:IsPlayerClockedOn(src, Config.JobKey) == true
end

--- End a shift. `settle` returns the deposit; a ditched cab forfeits it.
local function endShift(src, settle)
    local shift = shifts[src]
    if not shift then return nil end
    shifts[src] = nil
    if shift.vehicleId then
        exports.whip_core:DespawnVehicle(shift.vehicleId)
    end
    if settle and shift.receipt then
        exports.whip_core:RefundPlayer(shift.receipt)
    end
    return shift
end

-- Declarations -------------------------------------------------------------

Whip.register(function()
    Whip.core:EnsureJob(Config.JobKey, {
        name = Config.JobName,
        icon = 'taxi',
        roles = Config.JobRoles,
    })

    -- The depot clerk, as a WHIP NPC so every player sees the same one in the same place.
    local npcId, netId = Whip.core:SpawnNpc({
        model = Config.Depot.clerk.model,
        coords = Config.Depot.clerk.coords,
        behaviour = 'stand',
        conditions = { invincible = true, canMove = false, reacts = false },
    }, { tag = TAG })

    if npcId then
        if Config.Depot.clerk.scenario then
            Whip.core:SetNpcState(npcId, { anim = { scenario = Config.Depot.clerk.scenario } })
        end
        -- The client hangs its clerk prompt on this.
        GlobalState[RESOURCE .. ':clerk'] = netId
    else
        Whip.startProblem('could not spawn the cab depot clerk: %s', tostring(netId))
    end

    -- The depot on the map. On 'hired' only the firm's drivers see it; on 'open' and 'signon'
    -- anyone may turn up, so everyone has to be able to find it.
    Whip.core:ShowBlip(
        Config.DutyMode == 'hired' and { job = Config.JobKey } or 'everyone',
        RESOURCE .. ':depot',
        {
            coords     = Config.Depot.rank.xyz,
            label      = Lang:t('info.blip_name'),
            sprite     = Config.Depot.blip.sprite,
            color      = Config.Depot.blip.colour,
            scale      = Config.Depot.blip.scale,
            shortRange = true,
        }
    )

    -- Signing on and off ('signon' only) -----------------------------------
    -- A driver who walks up is taken on at the starting role and put on duty in one go, so nobody
    -- has to be hired by hand first. On 'hired' the clerk uses whip_core's own ClockOn instead.
    if Config.DutyMode == 'signon' then
        Whip.core:SecureCallback(RESOURCE .. ':signOn', {
            rateLimit = 2000,
            params = {},
            near = {
                range = 10.0,
                at = function() return Config.Depot.clerk.coords.xyz end,
                message = Lang:t('error.you_notworker'),
            },
        }, function(source)
            if not exports.whip_core:GetPlayerRole(source, Config.JobKey) then
                local hired, why = exports.whip_core:HirePlayer(source, Config.JobKey)
                if not hired then
                    return false, why or Lang:t('error.you_notworker')
                end
            end

            local on, why = exports.whip_core:ClockOn(source, Config.JobKey)
            if not on then
                return false, why or Lang:t('error.not_on_duty')
            end

            exports.whip_core:NotifyPlayer(source, Lang:t('success.signed_on'), 'success')
            return true
        end)

        Whip.core:SecureCallback(RESOURCE .. ':signOff', {
            rateLimit = 2000,
            params = {},
        }, function(source)
            if shifts[source] then
                return false, Lang:t('error.cab_still_out')
            end

            exports.whip_core:ClockOff(source, Config.JobKey)

            -- Let a casual driver go, so the roster does not fill up with everyone who ever drove a
            -- cab. Anyone promoted above the starting role keeps their job.
            if Config.ReleaseOnSignOff then
                local role = exports.whip_core:GetPlayerRole(source, Config.JobKey)
                if role and (role.level or 1) <= STARTING_LEVEL then
                    exports.whip_core:FirePlayer(source, Config.JobKey)
                end
            end

            exports.whip_core:NotifyPlayer(source, Lang:t('success.signed_off'), 'success')
            return true
        end)
    end

    -- Signing a cab out of the rank ----------------------------------------
    Whip.core:SecureCallback(RESOURCE .. ':takeVehicle', {
        rateLimit = 2000,
        params = {
            { 'model', 'enum', MODELS },
        },
        near = {
            range = 30.0,
            at = function() return Config.Depot.rank.xyz end,
            message = Lang:t('error.you_notworker'),
        },
    }, function(source, player, model)
        if not mayWork(source) then
            return false, Lang:t('error.not_on_duty')
        end
        if shifts[source] then
            return false, Lang:t('error.one_cab_active')
        end

        local receipt, err = exports.whip_core:ChargePlayer(source, Config.CabDeposit, {
            reason = Config.JobName .. ' -- cab deposit',
        })
        if not receipt then
            return false, err or Lang:t('error.you_have_nofunds', Config.CabDeposit)
        end

        -- SpawnTempVehicle refuses a spot that is not clear, so walk the rank until one takes.
        local vehicleId, why
        for _, coords in ipairs(Config.CabSpawns) do
            vehicleId, why = exports.whip_core:SpawnTempVehicle(model, coords, {
                forSource = source,
                locked = false,
                keyInIgnition = true,
                plate = makePlate(),
                idleDespawn = false,
                tag = TAG,
            })
            if vehicleId then break end
        end
        if not vehicleId then
            exports.whip_core:RefundPlayer(receipt)
            return false, why or Lang:t('error.parking_blocked')
        end

        -- They could have logged out between the charge and the spawn.
        if not exports.whip_core:IsSessionCurrent(source, player.session) then
            exports.whip_core:DespawnVehicle(vehicleId)
            exports.whip_core:RefundPlayer(receipt)
            return false
        end

        shifts[source] = {
            vehicleId = vehicleId,
            receipt = receipt,
            session = player.session,
            charId = player.charId,
        }

        exports.whip_core:NotifyPlayer(source, Lang:t('success.deposit_paid', Config.CabDeposit), 'success')

        local vehicle = exports.whip_core:GetVehicle(vehicleId)
        return vehicle and vehicle.netId or false
    end)

    -- A fare dropped off: settle the meter ---------------------------------
    Whip.core:SecureEvent(RESOURCE .. ':settleFare', {
        rateLimit = 2000,
        params = {
            { 'drop', 'id', 1, #Config.DropLocations },
            { 'fare', 'amount', Config.MaxFare },
        },
        near = {
            range = 25.0,
            at = function(_, _, drop)
                local at = Config.DropLocations[drop]
                return at and at.xyz or nil
            end,
            message = Lang:t('error.not_in_taxi'),
        },
    }, function(source, player, drop, fare)
        local shift = shifts[source]
        if not shift then
            return false, Lang:t('error.no_cab_out')
        end
        if not mayWork(source) then
            return false, Lang:t('error.not_on_duty')
        end

        -- They must be driving the cab they signed out, not standing next to it.
        local vehicleId = exports.whip_core:GetPlayerVehicle(source, { driver = true })
        if vehicleId ~= shift.vehicleId then
            return false, Lang:t('error.not_in_taxi')
        end

        -- A second payout inside the cooldown is a replayed event, not a second fare.
        local now = os.time()
        if shift.lastPay and (now - shift.lastPay) < Config.FareCooldown then
            exports.whip_core:RecordEventRejection(RESOURCE .. ':settleFare', source, 'Fare settled inside the cooldown')
            return false
        end
        shift.lastPay = now

        local amount = math.min(fare + rollTip(), Config.MaxFare)
        if not exports.whip_core:PayPlayer(source, amount, {
            reason = Config.JobName .. ' -- fare',
        }) then
            return false
        end

        exports.whip_core:NotifyPlayer(source, Lang:t('success.fare_paid', amount), 'success')

        local chance = Config.ChanceItem
        if chance and chance.item and math.random(1, 100) <= (chance.percent or 0) then
            exports.whip_core:AddItem(source, chance.item, chance.amount or 1, nil, Config.JobName .. ' -- tip')
        end
    end)

    -- The cab parked back up on the rank -----------------------------------
    Whip.core:SecureEvent(RESOURCE .. ':returnVehicle', {
        rateLimit = 2000,
        params = {},
        near = {
            range = 20.0,
            at = function() return Config.Depot.rank.xyz end,
            message = Lang:t('error.you_notworker'),
        },
    }, function(source)
        local shift = shifts[source]
        if not shift then
            return false, Lang:t('error.no_cab_out')
        end

        local vehicleId = exports.whip_core:GetPlayerVehicle(source, { driver = true })
        if vehicleId ~= shift.vehicleId then
            return false, Lang:t('error.not_in_taxi')
        end

        endShift(source, true)
        exports.whip_core:NotifyPlayer(source, Lang:t('success.taxi_returned'), 'success')
        TriggerClientEvent(RESOURCE .. ':client:shiftEnded', source, false)
    end)

    -- The driver walked away from the cab ----------------------------------
    Whip.core:SecureEvent(RESOURCE .. ':cancelShift', {
        rateLimit = 1000,
        params = {},
    }, function(source)
        if not shifts[source] then return end
        endShift(source, false)   -- a ditched cab forfeits the deposit
        TriggerClientEvent(RESOURCE .. ':client:shiftEnded', source, true)
    end)
end)

-- Cleanup ------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    endShift(source, false)
end)

AddEventHandler('whip_core:player:logout', function(data)
    if data and data.source then endShift(data.source, false) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    for src in pairs(shifts) do
        endShift(src, false)
    end
end)

Whip.sayStarted()
