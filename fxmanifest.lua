fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'whip-taxijob'
author 'Whippy'
description 'Taxi job for WhipFX: a depot clerk signs cabs out, NPC fares are hailed around the city, and the meter rides on a WhipFX objective card.'
version '2.0.0'

dependency 'whip_core'
whip_requires '1.0'

shared_scripts {
    '@whip_core/lib/satellite.lua',
    'shared/locale.lua',
    'locales/*.lua',
    'config/config.lua',
    'config/locations.lua',
}

client_script 'client/taxijob.lua'
server_script 'server/main.lua'
