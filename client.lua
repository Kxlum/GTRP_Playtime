local ESX = exports.es_extended:getSharedObject()

local sessionStart = GetGameTimer()

local function FormatPlaytime(minutes)
    minutes = tonumber(minutes) or 0
    local days = math.floor(minutes / 1440)
    local hours = math.floor((minutes % 1440) / 60)
    local mins = math.floor(minutes % 60)
    
    if days > 0 then
        return string.format('%dd %dh %dm', days, hours, mins)
    elseif hours > 0 then
        return string.format('%dh %dm', hours, mins)
    else
        return string.format('%dm', mins)
    end
end

local function ShowMyStats()
    lib.callback('GTRP_Playtime:GetPlayerStats', false, function(stats)
        if not stats then
            lib.notify({
                title = 'Playtime',
                description = 'Could not load your stats',
                type = 'error'
            })
            return
        end
        
        lib.callback('GTRP_Playtime:GetPlayerTitle', false, function(title)
            local sessionMinutes = math.floor((GetGameTimer() - sessionStart) / 60000)
            local titleText = title.icon .. ' ' .. title.title
            if title.title == 'None' then
                titleText = 'No title yet'
            end
            
            local options = {
                {
                    title = 'Global Rank',
                    description = '#' .. stats.rank .. ' (Top ' .. stats.percentile .. '%)',
                    icon = 'ranking-star'
                },
                {
                    title = 'Current Title',
                    description = titleText,
                    icon = 'crown'
                },
                {
                    title = 'Total Playtime',
                    description = FormatPlaytime(stats.playtime),
                    icon = 'clock'
                },
                {
                    title = 'Current Session',
                    description = FormatPlaytime(sessionMinutes),
                    icon = 'hourglass-half'
                }
            }
            
            lib.registerContext({
                id = 'playtime_mystats',
                title = 'Your Playtime Stats',
                menu = 'playtime_main',
                options = options
            })
            
            lib.showContext('playtime_mystats')
        end)
    end)
end

local function ShowPlaytimeLeaderboard()
    lib.callback('GTRP_Playtime:GetLeaderboardData', false, function(leaderboard)
        if leaderboard and #leaderboard > 0 then
            local options = {}
            
            for i, player in ipairs(leaderboard) do
                local icon = 'user'
                if i == 1 then icon = 'trophy'
                elseif i == 2 then icon = 'medal'
                elseif i == 3 then icon = 'award' end
                
                local displayName = player.name
                if player.titleIcon and player.titleIcon ~= '' then
                    displayName = player.titleIcon .. ' ' .. player.name
                end
                
                table.insert(options, {
                    title = ('#%d - %s'):format(player.rank, displayName),
                    description = FormatPlaytime(player.playtime),
                    icon = icon
                })
            end
            
            lib.registerContext({
                id = 'playtime_leaderboard',
                title = 'Playtime Leaderboard',
                menu = 'playtime_main',
                options = options
            })
            
            lib.showContext('playtime_leaderboard')
        else
            lib.notify({
                title = 'Playtime',
                description = 'No player data found',
                type = 'error'
            })
        end
    end)
end

local function ShowPlaytimeMenu()
    local options = {
        {
            title = 'Global Leaderboard',
            description = 'View top 100 players',
            icon = 'trophy',
            onSelect = ShowPlaytimeLeaderboard
        },
        {
            title = 'View Your Playtime',
            description = 'Check your personal playtime stats',
            icon = 'user',
            onSelect = ShowMyStats
        }
    }
    
    lib.registerContext({
        id = 'playtime_main',
        title = 'GTRP Playtime',
        options = options
    })
    
    lib.showContext('playtime_main')
end

RegisterCommand('playtime', function()
    ShowPlaytimeMenu()
end, false)

RegisterNetEvent('GTRP_Playtime:ShowMenu', function()
    ShowPlaytimeMenu()
end)

RegisterNetEvent('GTRP_Playtime:ShowLeaderboard', function()
    ShowPlaytimeLeaderboard()
end)

RegisterNetEvent('GTRP_Playtime:ShowMyStats', function()
    ShowMyStats()
end)

AddEventHandler('esx:playerLoaded', function()
    sessionStart = GetGameTimer()
end)

TriggerEvent('chat:addSuggestion', '/playtime', 'Show playtime system menu')