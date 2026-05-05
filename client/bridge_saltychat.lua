YacaSaltyChatBridge = {
    currentPluginState = -1,
    isPrimarySending = false,
    isSecondarySending = false,
    isPrimaryReceiving = false,
    isSecondaryReceiving = false,
}

local function saltyChatExport(method, cb)
    AddEventHandler("__cfx_export_saltychat_" .. method, function(setCb)
        setCb(cb)
    end)
end

function YacaSaltyChatBridge:init()
    self:registerSaltyChatExports()
    self:enableRadio()

    print("[YaCA] SaltyChat bridge loaded")

    AddEventHandler("onResourceStop", function(resourceName)
        if YacaCache.resource ~= resourceName then return end
        TriggerEvent("onClientResourceStop", "saltychat")
    end)
end

function YacaSaltyChatBridge:enableRadio()
    Citizen.CreateThread(function()
        while not YacaClient:isPluginInitialized(true) do
            Citizen.Wait(1000)
        end

        if YacaRadio then
            YacaRadio:enableRadio(true)
        end
    end)
end

function YacaSaltyChatBridge:registerSaltyChatExports()
    saltyChatExport("GetVoiceRange", function()
        return YacaClient:getVoiceRange()
    end)

    saltyChatExport("GetRadioChannel", function(primary)
        local channel = primary and 1 or 2
        local currentFrequency = YacaRadio and YacaRadio:getRadioFrequency(channel) or "0"
        if currentFrequency == "0" then return "" end
        return currentFrequency
    end)

    saltyChatExport("GetRadioVolume", function()
        return YacaRadio and YacaRadio:getRadioChannelVolume(1) or 0
    end)

    saltyChatExport("GetRadioSpeaker", function()
        print("[YaCA] GetRadioSpeaker is not implemented in YaCA")
        return false
    end)

    saltyChatExport("GetMicClick", function()
        print("[YaCA] GetMicClick is not implemented in YaCA")
        return false
    end)

    saltyChatExport("SetRadioChannel", function(radioChannelName, primary)
        local channel = primary and 1 or 2
        local newRadioChannelName = radioChannelName == "" and "0" or radioChannelName

        if YacaRadio then
            YacaRadio:changeRadioFrequencyRaw(newRadioChannelName, channel)
        end
    end)

    saltyChatExport("SetRadioVolume", function(volume)
        if YacaRadio then
            YacaRadio:changeRadioChannelVolumeRaw(volume, 1)
            YacaRadio:changeRadioChannelVolumeRaw(volume, 2)
        end
    end)

    saltyChatExport("SetRadioSpeaker", function()
        print("[YaCA] SetRadioSpeaker is not implemented in YaCA")
    end)

    saltyChatExport("SetMicClick", function()
        print("[YaCA] SetMicClick is not implemented in YaCA")
    end)

    saltyChatExport("GetPluginState", function()
        return self.currentPluginState
    end)
end

function YacaSaltyChatBridge:handleChangePluginState(response)
    local state = 0

    if response == YacaPluginStates.IN_EXCLUDED_CHANNEL then
        state = 3
    elseif response == YacaPluginStates.IN_INGAME_CHANNEL then
        state = 2
    elseif response == YacaPluginStates.CONNECTED then
        state = 1
    elseif response == YacaPluginStates.WRONG_TS_SERVER or response == YacaPluginStates.OUTDATED_VERSION then
        state = 0
    elseif response == YacaPluginStates.NOT_CONNECTED then
        state = -1
    else
        return
    end

    TriggerEvent("SaltyChat_PluginStateChanged", state)
    self.currentPluginState = state
end

function YacaSaltyChatBridge:sendRadioTalkingState()
    TriggerEvent("SaltyChat_RadioTrafficStateChanged",
        self.isPrimaryReceiving, self.isPrimarySending,
        self.isSecondaryReceiving, self.isSecondarySending
    )
end

function YacaSaltyChatBridge:handleRadioTalkingStateChange(state, channel)
    if channel == 1 then
        self.isPrimarySending = state
    else
        self.isSecondarySending = state
    end
    self:sendRadioTalkingState()
end

function YacaSaltyChatBridge:handleRadioReceivingStateChange(state, channel)
    if channel == 1 then
        self.isPrimaryReceiving = state
    else
        self.isSecondaryReceiving = state
    end
    self:sendRadioTalkingState()
end
