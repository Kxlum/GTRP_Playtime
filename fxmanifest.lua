fx_version 'cerulean'
game 'gta5'
author 'YourName'
description 'Playtime tracking system'
version '1.0.0'

lua54 'yes'

shared_script '@ox_lib/init.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

client_scripts {
    'client.lua'
}