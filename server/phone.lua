YacaServerPhone = {}

local function initServerPhoneModule()
    YacaServerPhone:registerEvents()
    YacaServerPhone:registerExports()
end

function YacaServerPhone:registerEvents()
    RegisterNetEvent("server:yaca:phoneSpeakerEmitWhisper", function(enableForTargets, disableForTargets)
        local player = YacaServer:getPlayer(source)
        if not player then return end

        local targets = {}
        for callTarget in pairs(player.voiceSettings.inCallWith) do
            local target = YacaServer:getPlayer(callTarget)
            if target then
                targets[#targets + 1] = callTarget
            end
        end

        if #targets > 0 and enableForTargets and #enableForTargets > 0 then
            YacaTriggerClientEvent("client:yaca:playersToPhoneSpeakerEmitWhisper", targets, enableForTargets, true)
        end

        if #targets > 0 and disableForTargets and #disableForTargets > 0 then
            YacaTriggerClientEvent("client:yaca:playersToPhoneSpeakerEmitWhisper", targets, disableForTargets, false)
        end
    end)

    RegisterNetEvent("server:yaca:phoneEmit", function(enableForTargets, disableForTargets)
        if not YacaServer.sharedConfig.phoneHearPlayersNearby then return end

        local player = YacaServer:getPlayer(source)
        if not player then return end

        local enableReceive = {}
        local disableReceive = {}

        if enableForTargets and #enableForTargets > 0 then
            for callTarget in pairs(player.voiceSettings.inCallWith) do
                local target = YacaServer:getPlayer(callTarget)
                if target then
                    enableReceive[#enableReceive + 1] = callTarget

                    for _, targetID in ipairs(enableForTargets) do
                        if not player.voiceSettings.emittedPhoneSpeaker[targetID] then
                            player.voiceSettings.emittedPhoneSpeaker[targetID] = {}
                        end
                        player.voiceSettings.emittedPhoneSpeaker[targetID][callTarget] = true
                    end
                end
            end
        end

        if disableForTargets and #disableForTargets > 0 then
            for _, targetID in ipairs(disableForTargets) do
                local emittedFor = player.voiceSettings.emittedPhoneSpeaker[targetID]
                if emittedFor then
                    for emittedTarget in pairs(emittedFor) do
                        local target = YacaServer:getPlayer(emittedTarget)
                        if target then
                            disableReceive[#disableReceive + 1] = emittedTarget
                        end
                    end
                    player.voiceSettings.emittedPhoneSpeaker[targetID] = nil
                end
            end
        end

        if #enableReceive > 0 and enableForTargets and #enableForTargets > 0 then
            local enableForTargetsData = {}
            for _, enableTarget in ipairs(enableForTargets) do
                local target = YacaServer:getPlayer(enableTarget)
                if target and target.voicePlugin then
                    enableForTargetsData[#enableForTargetsData + 1] = target.voicePlugin.clientId
                end
            end
            YacaTriggerClientEvent("client:yaca:phoneHearAround", enableReceive, enableForTargetsData, true)
        end

        if #disableReceive > 0 and disableForTargets and #disableForTargets > 0 then
            local disableForTargetsData = {}
            for _, disableTarget in ipairs(disableForTargets) do
                local target = YacaServer:getPlayer(disableTarget)
                if target and target.voicePlugin then
                    disableForTargetsData[#disableForTargetsData + 1] = target.voicePlugin.clientId
                end
            end
            YacaTriggerClientEvent("client:yaca:phoneHearAround", disableReceive, disableForTargetsData, false)
        end
    end)
end

function YacaServerPhone:registerExports()
    exports("callPlayer", function(src, target, state)
        self:callPlayer(src, target, state)
    end)

    exports("callPlayerOldEffect", function(src, target, state)
        self:callPlayer(src, target, state, YacaFilterEnum.PHONE_HISTORICAL)
    end)

    exports("muteOnPhone", function(src, state)
        self:muteOnPhone(src, state)
    end)

    exports("enablePhoneSpeaker", function(src, state)
        self:enablePhoneSpeaker(src, state)
    end)

    exports("isPlayerInCall", function(src)
        local player = YacaServer:getPlayer(src)
        if not player then return false, {} end

        local inCall = next(player.voiceSettings.inCallWith) ~= nil
        local callList = {}
        for id in pairs(player.voiceSettings.inCallWith) do
            callList[#callList + 1] = id
        end

        return inCall, callList
    end)
end

function YacaServerPhone:callPlayer(src, target, state, filter)
    filter = filter or YacaFilterEnum.PHONE

    local player = YacaServer:getPlayer(src)
    local targetPlayer = YacaServer:getPlayer(target)
    if not player or not targetPlayer then return end

    TriggerClientEvent("client:yaca:phone", target, src, state, filter)
    TriggerClientEvent("client:yaca:phone", src, target, state, filter)

    local playerState = Player(src).state
    local targetState = Player(target).state

    if state then
        player.voiceSettings.inCallWith[target] = true
        targetPlayer.voiceSettings.inCallWith[src] = true

        if playerState[YACA_STATE_PHONE_SPEAKER] then
            self:enablePhoneSpeaker(src, true)
        end

        if targetState[YACA_STATE_PHONE_SPEAKER] then
            self:enablePhoneSpeaker(target, true)
        end
    else
        self:muteOnPhone(src, false, true)
        self:muteOnPhone(target, false, true)

        player.voiceSettings.inCallWith[target] = nil
        targetPlayer.voiceSettings.inCallWith[src] = nil

        if playerState[YACA_STATE_PHONE_SPEAKER] then
            self:enablePhoneSpeaker(src, false)
        end

        if targetState[YACA_STATE_PHONE_SPEAKER] then
            self:enablePhoneSpeaker(target, false)
        end
    end

    TriggerEvent("yaca:external:phoneCall", src, target, state, filter)
end

function YacaServerPhone:muteOnPhone(src, state, onCallStop)
    onCallStop = onCallStop or false

    local player = YacaServer:getPlayer(src)
    if not player then return end

    player.voiceSettings.mutedOnPhone = state
    TriggerClientEvent("client:yaca:phoneMute", -1, src, state, onCallStop)
    TriggerEvent("yaca:external:phoneMute", src, state)
end

function YacaServerPhone:enablePhoneSpeaker(src, state)
    local player = YacaServer:getPlayer(src)
    if not player then return end

    local playerState = Player(src).state

    if state and next(player.voiceSettings.inCallWith) ~= nil then
        local callList = {}
        for id in pairs(player.voiceSettings.inCallWith) do
            callList[#callList + 1] = id
        end
        playerState:set(YACA_STATE_PHONE_SPEAKER, callList, true)
        TriggerEvent("yaca:external:phoneSpeaker", src, true)
    else
        playerState:set(YACA_STATE_PHONE_SPEAKER, nil, true)
        TriggerEvent("yaca:external:phoneSpeaker", src, false)
    end
end

Citizen.CreateThread(function()
    while not YacaServer.sharedConfig do
        Citizen.Wait(100)
    end
    initServerPhoneModule()
end)
