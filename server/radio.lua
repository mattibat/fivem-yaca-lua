YacaServerRadio = {
    radioFrequencyMap = {},   -- [frequency] = { [src] = { muted = bool } }
    securedRadioFrequencies = {},  -- { { start = "...", ["end"] = "..." }, ... }
}

local function initServerRadioModule()
    YacaServerRadio:registerEvents()
    YacaServerRadio:registerExports()
end

function YacaServerRadio:registerEvents()
    RegisterNetEvent("server:yaca:enableRadio", function(state)
        self:enableRadio(source, state)
    end)

    RegisterNetEvent("server:yaca:changeRadioFrequency", function(channel, frequency)
        self:changeRadioFrequency(source, channel, frequency)
    end)

    RegisterNetEvent("server:yaca:muteRadioChannel", function(channel, state)
        self:radioChannelMute(source, channel, state)
    end)

    RegisterNetEvent("server:yaca:radioTalking", function(state, channel, distanceToTower)
        distanceToTower = distanceToTower or -1
        self:radioTalkingState(source, state, channel, distanceToTower)
    end)
end

function YacaServerRadio:registerExports()
    exports("getPlayersInRadioFrequency", function(frequency)
        return self:getPlayersInRadioFrequency(frequency)
    end)

    exports("setPlayerRadioChannel", function(src, channel, frequency)
        self:changeRadioFrequency(src, channel, frequency)
    end)

    exports("getPlayerHasLongRange", function(src)
        return self:getPlayerHasLongRange(src)
    end)

    exports("setPlayerHasLongRange", function(src, state)
        self:setPlayerHasLongRange(src, state)
    end)

    exports("setSecuredRadioFrequency", function(state, startFreq, endFreq)
        return self:setSecuredRadioFrequency(state, startFreq, endFreq)
    end)

    exports("getSecuredRadioFrequencies", function()
        return self:getSecuredRadioFrequencies()
    end)

    exports("setPermitRadioFrequency", function(src, state, startFreq, endFreq)
        return self:setPermitRadioFrequency(src, state, startFreq, endFreq)
    end)

    exports("getPermittedRadioFrequencies", function(src)
        return self:getPermittedRadioFrequencies(src)
    end)
end

function YacaServerRadio:getPlayersInRadioFrequency(frequency)
    local allPlayersInChannel = self.radioFrequencyMap[frequency]
    local playersArray = {}

    if not allPlayersInChannel then return playersArray end

    for key in pairs(allPlayersInChannel) do
        local target = YacaServer:getPlayer(key)
        if target then
            playersArray[#playersArray + 1] = key
        end
    end

    return playersArray
end

function YacaServerRadio:getPlayerHasLongRange(src)
    local player = YacaServer:getPlayer(src)
    if not player then return false end
    return player.radioSettings.hasLong
end

function YacaServerRadio:setPlayerHasLongRange(src, state)
    local player = YacaServer:getPlayer(src)
    if not player then return end
    player.radioSettings.hasLong = state
end

function YacaServerRadio:enableRadio(src, state)
    local player = YacaServer:getPlayer(src)
    if not player then return end

    player.radioSettings.activated = state
    TriggerEvent("yaca:export:enabledRadio", src, state)
end

function YacaServerRadio:changeRadioFrequency(src, channel, frequency)
    local player = YacaServer:getPlayer(src)
    if not player then return end

    if not player.radioSettings.activated then
        TriggerClientEvent("client:yaca:notification", src, YacaLocale("radio_not_activated"), YacaNotificationType.ERROR)
        return
    end

    if not channel or channel < 1 or channel > YacaServer.sharedConfig.radioSettings.channelCount then
        TriggerClientEvent("client:yaca:notification", src, YacaLocale("radio_channel_invalid"), YacaNotificationType.ERROR)
        return
    end

    local oldFrequency = player.radioSettings.frequencies[channel]

    if frequency == "0" then
        self:leaveRadioFrequency(src, channel, oldFrequency)
        return
    end

    if oldFrequency and oldFrequency ~= frequency then
        self:leaveRadioFrequency(src, channel, oldFrequency)
    end

    if not self:hasAccessToRadioFrequency(src, frequency) then
        return
    end

    if not self.radioFrequencyMap[frequency] then
        self.radioFrequencyMap[frequency] = {}
    end
    self.radioFrequencyMap[frequency][src] = { muted = false }

    player.radioSettings.frequencies[channel] = frequency

    TriggerClientEvent("client:yaca:setRadioFreq", src, channel, frequency)
    TriggerEvent("yaca:external:changedRadioFrequency", src, channel, frequency)
end

function YacaServerRadio:leaveRadioFrequency(src, channel, frequency)
    local player = YacaServer:getPlayer(src)
    if not player then return end

    local allPlayersInChannel = self.radioFrequencyMap[frequency]
    if not allPlayersInChannel then return end

    player.radioSettings.frequencies[channel] = "0"

    local playersArray = {}
    local allTargets = {}
    for key in pairs(allPlayersInChannel) do
        local target = YacaServer:getPlayer(key)
        if target then
            playersArray[#playersArray + 1] = key
            if key ~= src then
                allTargets[#allTargets + 1] = key
            end
        end
    end

    if YacaServer.serverConfig.useWhisper then
        TriggerClientEvent("client:yaca:radioTalkingWhisper", src, allTargets, frequency, false)
    elseif player.voicePlugin then
        YacaTriggerClientEvent("client:yaca:leaveRadioChannel", playersArray, player.voicePlugin.clientId, frequency)
    end

    allPlayersInChannel[src] = nil

    local isEmpty = true
    for _ in pairs(allPlayersInChannel) do isEmpty = false break end
    if isEmpty then
        self.radioFrequencyMap[frequency] = nil
    end
end

function YacaServerRadio:radioChannelMute(src, channel, state)
    local player = YacaServer:getPlayer(src)
    if not player then return end

    local radioFrequency = player.radioSettings.frequencies[channel]
    if not radioFrequency then return end

    local freqMap = self.radioFrequencyMap[radioFrequency]
    if not freqMap or not freqMap[src] then return end

    if state ~= nil then
        freqMap[src].muted = state
    else
        freqMap[src].muted = not freqMap[src].muted
    end

    TriggerClientEvent("client:yaca:setRadioMuteState", src, channel, freqMap[src].muted)
    TriggerEvent("yaca:external:changedRadioMuteState", src, channel, freqMap[src].muted)
end

function YacaServerRadio:radioTalkingState(src, state, channel, distanceToTower)
    local player = YacaServer:getPlayer(src)
    if not player or not player.radioSettings.activated then return end

    local radioFrequency = player.radioSettings.frequencies[channel]
    if not radioFrequency or radioFrequency == "0" then return end

    local getPlayers = self.radioFrequencyMap[radioFrequency]
    if not getPlayers then return end

    if not self:hasAccessToRadioFrequency(src, radioFrequency) then
        self:leaveRadioFrequency(src, channel, radioFrequency)
        return
    end

    local targets = {}
    local targetsToSender = {}
    local radioInfos = {}
    local skipAll = false

    for key, values in pairs(getPlayers) do
        if values.muted then
            if key == src then
                skipAll = true
                break
            end
        else
            if key ~= src then
                local target = YacaServer:getPlayer(key)
                if target and target.radioSettings.activated then
                    local shortRange = not player.radioSettings.hasLong and not target.radioSettings.hasLong
                    if (player.radioSettings.hasLong and target.radioSettings.hasLong) or shortRange then
                        targets[#targets + 1] = key
                        radioInfos[tostring(key)] = { shortRange = shortRange }
                        targetsToSender[#targetsToSender + 1] = key
                    end
                end
            end
        end
    end

    if skipAll then targets = {} end

    local senderPos = GetEntityCoords(GetPlayerPed(tostring(src)))

    YacaTriggerClientEvent(
        "client:yaca:radioTalking", targets,
        src, radioFrequency, state, radioInfos, distanceToTower, senderPos
    )

    if YacaServer.serverConfig.useWhisper then
        TriggerClientEvent("client:yaca:radioTalkingWhisper", src, targetsToSender, radioFrequency, state, senderPos)
    end
end

function YacaServerRadio:setSecuredRadioFrequency(state, startFreq, endFreq)
    local index = nil
    for i, freq in ipairs(self.securedRadioFrequencies) do
        if freq.start == startFreq and freq["end"] == endFreq then
            index = i
            break
        end
    end

    if state and not index then
        self.securedRadioFrequencies[#self.securedRadioFrequencies + 1] = { start = startFreq, ["end"] = endFreq }

        for frequency, players in pairs(self.radioFrequencyMap) do
            if self:isSecuredRadioFrequency(frequency) then
                for srcId in pairs(players) do
                    local pl = YacaServer:getPlayer(srcId)
                    if pl and not self:hasAccessToRadioFrequency(srcId, frequency, false) then
                        for ch, freq in pairs(pl.radioSettings.frequencies) do
                            if freq == frequency then
                                self:leaveRadioFrequency(srcId, ch, frequency)
                            end
                        end
                    end
                end
            end
        end

        return true
    elseif not state and index then
        table.remove(self.securedRadioFrequencies, index)
        return true
    end

    return false
end

function YacaServerRadio:getSecuredRadioFrequencies()
    return self.securedRadioFrequencies
end

function YacaServerRadio:setPermitRadioFrequency(src, state, startFreq, endFreq)
    local player = YacaServer:getPlayer(src)
    if not player then return false end

    local index = nil
    for i, freq in ipairs(player.radioSettings.permittedRadioFrequencies) do
        if freq.start == startFreq and freq["end"] == endFreq then
            index = i
            break
        end
    end

    if state and not index then
        player.radioSettings.permittedRadioFrequencies[#player.radioSettings.permittedRadioFrequencies + 1] = { start = startFreq, ["end"] = endFreq }
        return true
    elseif not state and index then
        table.remove(player.radioSettings.permittedRadioFrequencies, index)

        for ch, frequency in pairs(player.radioSettings.frequencies) do
            if not self:hasAccessToRadioFrequency(src, frequency) then
                self:leaveRadioFrequency(src, ch, frequency)
            end
        end

        return true
    end

    return false
end

function YacaServerRadio:getPermittedRadioFrequencies(src)
    local player = YacaServer:getPlayer(src)
    if not player then return {} end
    return player.radioSettings.permittedRadioFrequencies or {}
end

function YacaServerRadio:parseRadioFrequencyAsFloat(frequency)
    return tonumber(frequency:gsub(",", ".")) or 0
end

function YacaServerRadio:isSecuredRadioFrequency(frequency)
    for _, freq in ipairs(self.securedRadioFrequencies) do
        local testFreq = self:parseRadioFrequencyAsFloat(frequency)
        local startFreq = self:parseRadioFrequencyAsFloat(freq.start)

        if not freq["end"] then
            if testFreq == startFreq then return true end
        else
            local endFreq = self:parseRadioFrequencyAsFloat(freq["end"])
            local minFreq = math.min(startFreq, endFreq)
            local maxFreq = math.max(startFreq, endFreq)

            if testFreq >= minFreq and testFreq <= maxFreq then return true end
        end
    end

    return false
end

function YacaServerRadio:hasAccessToRadioFrequency(src, frequency, notification)
    if notification == nil then notification = true end

    if not self:isSecuredRadioFrequency(frequency) then
        return true
    end

    local permittedFrequencies = self:getPermittedRadioFrequencies(src)
    if #permittedFrequencies == 0 then
        if notification then
            TriggerClientEvent("client:yaca:notification", src, YacaLocale("radio_secured_channel"), YacaNotificationType.ERROR)
        end
        return false
    end

    local testFreq = self:parseRadioFrequencyAsFloat(frequency)

    for _, perm in ipairs(permittedFrequencies) do
        local startFreq = self:parseRadioFrequencyAsFloat(perm.start)

        if not perm["end"] then
            if testFreq == startFreq then return true end
        else
            local endFreq = self:parseRadioFrequencyAsFloat(perm["end"])
            local minFreq = math.min(startFreq, endFreq)
            local maxFreq = math.max(startFreq, endFreq)

            if testFreq >= minFreq and testFreq <= maxFreq then return true end
        end
    end

    if notification then
        TriggerClientEvent("client:yaca:notification", src, YacaLocale("radio_secured_channel"), YacaNotificationType.ERROR)
    end
    return false
end

Citizen.CreateThread(function()
    while not YacaServer.sharedConfig do
        Citizen.Wait(100)
    end
    initServerRadioModule()
end)
