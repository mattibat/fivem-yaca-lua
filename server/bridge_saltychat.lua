YacaServerSaltyChatBridge = {
    callMap = {},  -- [callIdentifier] = { [playerId] = true }
}

local function saltyChatExport(method, cb)
    AddEventHandler("__cfx_export_saltychat_" .. method, function(setCb)
        setCb(cb)
    end)
end

function YacaServerSaltyChatBridge:init()
    self:registerSaltyChatExports()

    print("[YaCA] SaltyChat bridge loaded (server)")

    AddEventHandler("onResourceStop", function(resourceName)
        if GetCurrentResourceName() ~= resourceName then return end
        TriggerEvent("onServerResourceStop", "saltychat")
    end)
end

function YacaServerSaltyChatBridge:registerSaltyChatExports()
    saltyChatExport("GetPlayerAlive", function(netId)
        return YacaServer:getPlayerAliveStatus(netId)
    end)

    saltyChatExport("SetPlayerAlive", function(netId, isAlive)
        YacaServer:changePlayerAliveStatus(netId, isAlive)
    end)

    saltyChatExport("GetPlayerVoiceRange", function(netId)
        return YacaServer:getPlayerVoiceRange(netId)
    end)

    saltyChatExport("SetPlayerVoiceRange", function(netId, voiceRange)
        YacaServer:changeVoiceRange(netId, voiceRange)
    end)

    saltyChatExport("AddPlayerToCall", function(callIdentifier, playerHandle)
        self:addPlayerToCall(callIdentifier, playerHandle)
    end)

    saltyChatExport("AddPlayersToCall", function(callIdentifier, playerHandles)
        self:addPlayerToCall(callIdentifier, playerHandles)
    end)

    saltyChatExport("RemovePlayerFromCall", function(callIdentifier, playerHandle)
        self:removePlayerFromCall(callIdentifier, playerHandle)
    end)

    saltyChatExport("RemovePlayersFromCall", function(callIdentifier, playerHandles)
        self:removePlayerFromCall(callIdentifier, playerHandles)
    end)

    saltyChatExport("SetPhoneSpeaker", function(playerHandle, toggle)
        YacaServerPhone:enablePhoneSpeaker(playerHandle, toggle)
    end)

    saltyChatExport("SetPlayerRadioSpeaker", function()
        print("[YaCA] SetPlayerRadioSpeaker is not implemented in YaCA")
    end)

    saltyChatExport("GetPlayersInRadioChannel", function(radioChannelName)
        return YacaServerRadio:getPlayersInRadioFrequency(radioChannelName)
    end)

    saltyChatExport("SetPlayerRadioChannel", function(netId, radioChannelName, primary)
        if primary == nil then primary = true end
        local channel = primary and 1 or 2
        local newRadioChannelName = radioChannelName == "" and "0" or radioChannelName
        YacaServerRadio:changeRadioFrequency(netId, channel, newRadioChannelName)
    end)

    saltyChatExport("RemovePlayerRadioChannel", function(netId, primary)
        local channel = primary and 1 or 2
        YacaServerRadio:changeRadioFrequency(netId, channel, "0")
    end)

    saltyChatExport("SetRadioTowers", function()
        print("[YaCA] SetRadioTowers is not implemented in YaCA")
    end)

    saltyChatExport("EstablishCall", function(callerId, targetId)
        YacaServerPhone:callPlayer(callerId, targetId, true)
    end)

    saltyChatExport("EndCall", function(callerId, targetId)
        YacaServerPhone:callPlayer(callerId, targetId, false)
    end)
end

function YacaServerSaltyChatBridge:addPlayerToCall(callIdentifier, playerHandle)
    if type(playerHandle) ~= "table" then
        playerHandle = { playerHandle }
    end

    local currentlyInCall = self.callMap[callIdentifier] or {}
    local newInCall = {}

    for _, player in ipairs(playerHandle) do
        if not currentlyInCall[player] then
            currentlyInCall[player] = true
            newInCall[player] = true
        end
    end

    self.callMap[callIdentifier] = currentlyInCall

    for player in pairs(currentlyInCall) do
        for otherPlayer in pairs(newInCall) do
            if player ~= otherPlayer then
                YacaServerPhone:callPlayer(player, otherPlayer, true)
            end
        end
    end
end

function YacaServerSaltyChatBridge:removePlayerFromCall(callIdentifier, playerHandle)
    if type(playerHandle) ~= "table" then
        playerHandle = { playerHandle }
    end

    local beforeInCall = self.callMap[callIdentifier]
    if not beforeInCall then return end

    local nowInCall = {}
    for k, v in pairs(beforeInCall) do nowInCall[k] = v end

    local removedFromCall = {}
    for _, player in ipairs(playerHandle) do
        if beforeInCall[player] then
            nowInCall[player] = nil
            removedFromCall[player] = true
        end
    end

    self.callMap[callIdentifier] = nowInCall

    for player in pairs(removedFromCall) do
        for otherPlayer in pairs(beforeInCall) do
            if player ~= otherPlayer then
                YacaServerPhone:callPlayer(player, otherPlayer, false)
            end
        end
    end
end
