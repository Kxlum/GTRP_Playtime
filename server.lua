ESX = exports.es_extended:getSharedObject()

local onlinePlayers = {}
local milestoneCache = {}

local titles = {
    {hours = 1, title = 'Newcomer', icon = '🌱'},
    {hours = 24, title = 'Regular', icon = '⭐'},
    {hours = 100, title = 'Veteran', icon = '🛡️'},
    {hours = 250, title = 'Expert', icon = '🔥'},
    {hours = 500, title = 'Master', icon = '👑'},
    {hours = 1000, title = 'Legend', icon = '🏆'}
}

local function GetTitleForHours(hours)
    local currentTitle = nil
    for _, title in ipairs(titles) do
        if hours >= title.hours then
            currentTitle = title
        else
            break
        end
    end
    return currentTitle
end

local function CheckAndAnnounceMilestone(source, playtime, name)
    local hours = math.floor(playtime / 60)
    local playerKey = tostring(source)
    
    if not milestoneCache[playerKey] then
        milestoneCache[playerKey] = {}
    end
    
    for _, milestone in ipairs({1, 24, 100, 250, 500, 1000}) do
        if hours >= milestone and not milestoneCache[playerKey][milestone] then
            milestoneCache[playerKey][milestone] = true
            
            local milestoneIcon = ''
            for _, title in ipairs(titles) do
                if milestone == title.hours then
                    milestoneIcon = title.icon
                    break
                end
            end
            
            TriggerClientEvent('chat:addMessage', -1, {
                args = {milestoneIcon .. ' ' .. name .. ' has reached ' .. milestone .. ' hours of playtime!'}
            })
            
            break
        end
    end
end

local function SavePlayerPlaytime(source, forceSave)
    local playerData = onlinePlayers[source]
    if not playerData then return end
    
    local currentTime = os.time()
    local sessionSeconds = currentTime - playerData.joinTime
    local sessionMinutes = math.floor(sessionSeconds / 60)
    
    if forceSave or sessionMinutes >= 1 then
        local totalPlaytime = playerData.basePlaytime + math.max(sessionMinutes, 0)
        
        MySQL.update('UPDATE users SET playtime = ? WHERE identifier = ? AND id = ?', 
            {totalPlaytime, playerData.identifier, playerData.characterId})
        
        onlinePlayers[source].basePlaytime = totalPlaytime
        onlinePlayers[source].joinTime = currentTime
        
        CheckAndAnnounceMilestone(source, totalPlaytime, playerData.name)
        
        return totalPlaytime
    end
    return playerData.basePlaytime
end

AddEventHandler('esx:playerLoaded', function(source, xPlayer)
    local identifier = xPlayer.identifier
    local name = xPlayer.getName()
    
    local charInfo = xPlayer.get('character') or {}
    local firstname = charInfo.firstname or ''
    local lastname = charInfo.lastname or ''
    
    if firstname == '' or lastname == '' then
        firstname = xPlayer.get('firstName') or xPlayer.get('firstname') or ''
        lastname = xPlayer.get('lastName') or xPlayer.get('lastname') or ''
    end
    
    if firstname == '' or lastname == '' then
        return
    end
    
    local result = MySQL.query.await('SELECT id, playtime FROM users WHERE identifier = ? AND firstname = ? AND lastname = ?', 
        {identifier, firstname, lastname})
    
    if not result[1] then
        return
    end
    
    local characterId = result[1].id
    local playtime = result[1].playtime or 0
    
    onlinePlayers[source] = {
        identifier = identifier,
        characterId = characterId,
        name = name,
        basePlaytime = playtime,
        joinTime = os.time()
    }
    
    local playerKey = tostring(source)
    milestoneCache[playerKey] = {}
    local currentHours = math.floor(playtime / 60)
    
    for _, milestone in ipairs({1, 24, 100, 250, 500, 1000}) do
        if currentHours >= milestone then
            milestoneCache[playerKey][milestone] = true
        end
    end
    
    SavePlayerPlaytime(source, true)
end)

AddEventHandler('playerDropped', function()
    local source = source
    local playerData = onlinePlayers[source]
    
    if playerData then
        SavePlayerPlaytime(source, true)
        onlinePlayers[source] = nil
        milestoneCache[tostring(source)] = nil
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000)
        
        for source, data in pairs(onlinePlayers) do
            if data then
                SavePlayerPlaytime(source, false)
            end
        end
    end
end)

lib.callback.register('GTRP_Playtime:GetLeaderboardData', function(source)
    local result = MySQL.query.await('SELECT firstname, lastname, playtime FROM users WHERE playtime > 0 ORDER BY playtime DESC LIMIT 100')
    local leaderboard = {}
    
    for i, row in ipairs(result) do
        local fullName = row.firstname .. ' ' .. row.lastname
        local hours = math.floor((row.playtime or 0) / 60)
        local titleInfo = GetTitleForHours(hours)
        
        table.insert(leaderboard, {
            name = fullName,
            playtime = row.playtime or 0,
            rank = i,
            title = titleInfo and titleInfo.title or '',
            titleIcon = titleInfo and titleInfo.icon or ''
        })
    end
    
    return leaderboard
end)

lib.callback.register('GTRP_Playtime:GetPlayerStats', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end
    
    local charInfo = xPlayer.get('character') or {}
    local firstname = charInfo.firstname or ''
    local lastname = charInfo.lastname or ''
    
    if firstname == '' or lastname == '' then
        firstname = xPlayer.get('firstName') or xPlayer.get('firstname') or ''
        lastname = xPlayer.get('lastName') or xPlayer.get('lastname') or ''
    end
    
    if firstname == '' or lastname == '' then
        return nil
    end
    
    local result = MySQL.query.await('SELECT id, playtime FROM users WHERE identifier = ? AND firstname = ? AND lastname = ?', 
        {xPlayer.identifier, firstname, lastname})
    
    if not result[1] then 
        return nil
    end
    
    local characterId = result[1].id
    local playtime = result[1].playtime or 0
    
    local rankResult = MySQL.query.await('SELECT COUNT(*) as player_count FROM users WHERE playtime > ?', {playtime})
    local playerCount = rankResult[1] and rankResult[1].player_count or 0
    local totalPlayers = playerCount + 1
    local rank = totalPlayers
    
    local percentile = 0
    if totalPlayers > 1 then
        percentile = math.floor(((totalPlayers - rank) / (totalPlayers - 1)) * 100)
        percentile = 100 - percentile
    end
    
    return {
        playtime = playtime,
        rank = rank,
        percentile = percentile
    }
end)

lib.callback.register('GTRP_Playtime:GetPlayerTitle', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {title = 'None', icon = ''} end
    
    local charInfo = xPlayer.get('character') or {}
    local firstname = charInfo.firstname or ''
    local lastname = charInfo.lastname or ''
    
    if firstname == '' or lastname == '' then
        firstname = xPlayer.get('firstName') or xPlayer.get('firstname') or ''
        lastname = xPlayer.get('lastName') or xPlayer.get('lastname') or ''
    end
    
    if firstname == '' or lastname == '' then
        return {title = 'None', icon = ''}
    end
    
    local result = MySQL.query.await('SELECT id, playtime FROM users WHERE identifier = ? AND firstname = ? AND lastname = ?', 
        {xPlayer.identifier, firstname, lastname})
    
    if not result[1] then 
        return {title = 'None', icon = ''}
    end
    
    local playtime = result[1].playtime or 0
    local hours = math.floor(playtime / 60)
    
    local currentTitle = nil
    for _, title in ipairs(titles) do
        if hours >= title.hours then
            currentTitle = title
        else
            break
        end
    end
    
    return currentTitle or {title = 'None', icon = ''}
end)

ESX.RegisterCommand('playtime', 'user', function(xPlayer, args, showError)
    TriggerClientEvent('GTRP_Playtime:ShowMenu', xPlayer.source)
end, false, {help = 'Show playtime system menu'})

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Citizen.Wait(5000)
        
        local players = ESX.GetPlayers()
        for _, playerId in ipairs(players) do
            local xPlayer = ESX.GetPlayerFromId(playerId)
            if xPlayer then
                local identifier = xPlayer.identifier
                local charInfo = xPlayer.get('character') or {}
                local firstname = charInfo.firstname or ''
                local lastname = charInfo.lastname or ''
                
                if firstname == '' or lastname == '' then
                    firstname = xPlayer.get('firstName') or xPlayer.get('firstname') or ''
                    lastname = xPlayer.get('lastName') or xPlayer.get('lastname') or ''
                end
                
                if firstname ~= '' and lastname ~= '' then
                    local result = MySQL.query.await('SELECT id, playtime FROM users WHERE identifier = ? AND firstname = ? AND lastname = ?', 
                        {identifier, firstname, lastname})
                    
                    if result[1] then
                        local characterId = result[1].id
                        local playtime = result[1].playtime or 0
                        
                        onlinePlayers[playerId] = {
                            identifier = identifier,
                            characterId = characterId,
                            name = xPlayer.getName(),
                            basePlaytime = playtime,
                            joinTime = os.time()
                        }
                        
                        local playerKey = tostring(playerId)
                        milestoneCache[playerKey] = {}
                        local currentHours = math.floor(playtime / 60)
                        
                        for _, milestone in ipairs({1, 24, 100, 250, 500, 1000}) do
                            if currentHours >= milestone then
                                milestoneCache[playerKey][milestone] = true
                            end
                        end
                        
                        SavePlayerPlaytime(playerId, true)
                    end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for source, playerData in pairs(onlinePlayers) do
            if playerData then
                SavePlayerPlaytime(source, true)
            end
        end
    end
end)