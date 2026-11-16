Config = Config or {}
-- config.lua -- WhipFX edition

Config.Locale = 'en'

---------- Main settings ----------

Config.DebugMarkers = false   -- Draws every pickup and drop-off marker, for laying out new ones

-- Who may drive, and whether they go on duty first.
--   'open'   -- anyone walks up to the clerk and signs a cab out. No duty at all.
--   'signon' -- anyone may sign on at the clerk: they are taken on as a driver and put on duty in
--               one go. Sign off at the clerk when the shift is done.
--   'hired'  -- only drivers hired in /whip -> Economy -> Jobs may work. They clock on at the clerk.
-- The job below is created whichever you pick, so this is the only line that has to change.
Config.DutyMode = 'signon'

-- 'signon' only: let a driver go on sign-off, so the roster does not fill up with everyone who ever
-- drove a cab. Anyone who has been promoted above the starting role keeps their job either way.
Config.ReleaseOnSignOff = true

-- The job WhipFX creates for this resource. Hire drivers in /whip -> Economy -> Jobs.
Config.JobKey = 'taxi'
Config.JobName = 'Downtown Cab Co.'
Config.JobRoles = {
    { name = 'Driver', level = 1 },
}

-- Deposit taken when a cab is signed out, returned when it is parked back at the rank.
Config.CabDeposit = 1

-- The meter. The fare is worked out on the client as the cab drives and settled on the server,
-- which caps it at Config.MaxFare.
Config.Meter = {
    pricePerMile  = 125.0,   -- what a mile of the route is worth
    startingPrice = 0,       -- flat amount added to every fare
    useGpsPrice   = true,    -- bill the GPS route length rather than raw distance driven
}

Config.MaxFare = 2000           -- the server refuses anything above this
Config.FareCooldown = 5         -- seconds between two fares being settled
Config.TipChance = 40           -- % chance of a tip on top of the fare
Config.Tip = { min = 10, max = 20 }

-- A chance of an item on top of the fare. Set Item to nil to turn it off.
Config.ChanceItem = { item = 'money', amount = 1, percent = 26 }

-- Cabs the clerk will sign out. The model has to exist in the vehicle catalog.
Config.Vehicles = {
    { model = 'taxi', label = 'Standard Cab' },
}

-- The depot: the rank the cab comes back to, and the clerk who hands them out.
Config.Depot = {
    rank  = vector4(909.5, -177.35, 74.22, 238.5),
    clerk = {
        model    = 'a_m_m_indian_01',
        coords   = vector4(894.93, -179.12, 74.7, 237.09),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
    },
    blip = { sprite = 198, colour = 5, scale = 0.6 },
}

Config.Reach = {
    rank    = 8.0,    -- how close the cab has to be parked to count as returned
    fare    = 6.0,    -- how close to a pickup or drop-off the prompt shows
}

-- Walking away from the cab for this many seconds cancels the fare.
Config.AwaySeconds = 20
