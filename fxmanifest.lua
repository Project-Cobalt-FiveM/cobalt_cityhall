fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
this_is_a_map 'yes'

data_file 'DLC_ITYP_REQUEST' 'stream/hotdog/cobalt_hotdog.ytyp'

name 'cobalt_cityhall'
description 'City Hall: the job center, licence cards and the DMV driving tests'
author 'Project Cobalt'
version '1.0.0'

ui_page '_nui/build/index.html'

dependencies {
    'cobalt_core',
    'cobalt_inventory',
    'cobalt_management',
    'cobalt_sound',
    'cobalt_vehiclekeys',
    'ox_lib',
    'ox_target',
}

shared_script '@ox_lib/init.lua'

ox_libs { 'locale' }

client_script 'client/init.lua'

server_script 'server/init.lua'

files {
    'config.lua',
    'shared/*.lua',
    'data/*.lua',
    'client/*.lua',
    'client/kinds/*.lua',
    'client/hotdog/*.lua',
    '_nui/build/index.html',
    '_nui/build/order.html',
    '_nui/build/assets/*',
    'locales/*.json',
}
