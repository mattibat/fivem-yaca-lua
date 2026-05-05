YacaPhone = {
    inCallWith = {},
    phoneSpeakerActive = false,
}

local function initPhoneModule()
    YacaPhone:registerEvents()
    YacaPhone:registerExports()
    YacaPhone:registerStateBagHandlers()
end

function YacaPhone:registerEvents()
    RegisterNetEvent("client:yaca:phone", function(targetIDs, state, filter)
        filter = filter or YacaFilterEnum.PHONE

        if type(targetIDs) ~= "table" then
            targetIDs = { targetIDs }
        end

        self:enablePhoneCall(targetIDs, state, filter)
    end)

    RegisterNetEvent("client:yaca:phoneHearAround", function(targetClientIds, state)
        if not targetClientIds or #targetClientIds == 0 then return end

        local commTargets = {}
        for _, clientId in ipairs(targetClientIds) do
            commTargets[#commTargets + 1] = { clientId = clientId }
        end

        YacaClient:setPlayersCommType(
            commTargets, YacaFilterEnum.PHONE, state,
            nil, nil, nil, CommDeviceMode.TRANSCEIVER,
            GlobalState[YACA_STATE_PHONE_SPEAKER]
        )
    end)

    RegisterNetEvent("client:yaca:phoneMute", function(targetID, state, onCallStop)
        onCallStop = onCallStop or false

        local target = YacaClient:getPlayerByID(targetID)
        if not target then return end

        target.mutedOnPhone = state

        if onCallStop then return end

        if YacaClient.useWhisper and target.remoteID == YacaCache.serverId then
            YacaClient:setPlayersCommType({}, YacaFilterEnum.PHONE, not state, nil, nil, CommDeviceMode.SENDER)
        elseif not YacaClient.useWhisper and self.inCallWith[targetID] then
            YacaClient:setPlayersCommType(
                target, YacaFilterEnum.PHONE, state,
                nil, nil, CommDeviceMode.TRANSCEIVER, CommDeviceMode.TRANSCEIVER
            )
        end
    end)

    RegisterNetEvent("client:yaca:playersToPhoneSpeakerEmitWhisper", function(playerIDs, state)
        if not YacaClient.useWhisper then return end

        if type(playerIDs) ~= "table" then
            playerIDs = { playerIDs }
        end

        local targets = {}
        for _, playerID in ipairs(playerIDs) do
            local player = YacaClient:getPlayerByID(playerID)
            if player then
                targets[#targets + 1] = player
            end
        end

        if #targets < 1 then return end

        YacaClient:setPlayersCommType(
            targets, YacaFilterEnum.PHONE_SPEAKER, state,
            nil, nil, CommDeviceMode.SENDER, CommDeviceMode.RECEIVER
        )
    end)
end

function YacaPhone:registerExports()
    exports("isInCall", function()
        return next(self.inCallWith) ~= nil
    end)
end

function YacaPhone:registerStateBagHandlers()
    AddStateBagChangeHandler(YACA_STATE_PHONE_SPEAKER, "", function(bagName, _, value, _)
        local playerId = GetPlayerFromStateBagName(bagName)
        if playerId == 0 then return end

        local playerSource = GetPlayerServerId(playerId)
        if playerSource == 0 then return end

        if playerSource == YacaCache.serverId then
            self.phoneSpeakerActive = value ~= nil
        end

        self:removePhoneSpeakerFromEntity(playerSource)

        if value ~= nil then
            local memberIds = value
            if type(value) ~= "table" then
                memberIds = { value }
            end
            YacaClient:setPlayerVariable(playerSource, "phoneCallMemberIds", memberIds)
        end
    end)
end

function YacaPhone:removePhoneSpeakerFromEntity(player)
    local entityData = YacaClient:getPlayerByID(player)
    if not entityData or not entityData.phoneCallMemberIds then return end

    local playersToSet = {}
    for _, phoneCallMemberId in ipairs(entityData.phoneCallMemberIds) do
        local phoneCallMember = YacaClient:getPlayerByID(phoneCallMemberId)
        if phoneCallMember then
            playersToSet[#playersToSet + 1] = phoneCallMember
        end
    end

    YacaClient:setPlayersCommType(
        playersToSet, YacaFilterEnum.PHONE_SPEAKER, false,
        nil, nil, CommDeviceMode.RECEIVER, CommDeviceMode.SENDER
    )

    entityData.phoneCallMemberIds = nil
end

function YacaPhone:handleDisconnect(targetID)
    self.inCallWith[targetID] = nil
end

function YacaPhone:reestablishCalls(targetIDs)
    if not next(self.inCallWith) then return end

    if type(targetIDs) ~= "table" then
        targetIDs = { targetIDs }
    end

    if #targetIDs == 0 then return end

    local targetsToReestablish = {}
    for _, targetId in ipairs(targetIDs) do
        if self.inCallWith[targetId] then
            targetsToReestablish[#targetsToReestablish + 1] = targetId
        end
    end

    if #targetsToReestablish > 0 then
        self:enablePhoneCall(targetsToReestablish, true, YacaFilterEnum.PHONE)
    end
end

function YacaPhone:enablePhoneCall(targetIDs, state, filter)
    filter = filter or YacaFilterEnum.PHONE
    if not targetIDs or #targetIDs == 0 then return end

    local commTargets = {}
    for _, targetID in ipairs(targetIDs) do
        local target = YacaClient:getPlayerByID(targetID)
        if not target then
            if not state then self.inCallWith[targetID] = nil end
        else
            if state then
                self.inCallWith[targetID] = true
            else
                self.inCallWith[targetID] = nil
            end
            commTargets[#commTargets + 1] = target
        end
    end

    local ownMode = nil
    if state or (not state and next(self.inCallWith) ~= nil) then
        ownMode = CommDeviceMode.TRANSCEIVER
    end

    YacaClient:setPlayersCommType(
        commTargets, filter, state,
        nil, nil, ownMode, CommDeviceMode.TRANSCEIVER,
        GlobalState[YACA_STATE_GLOBAL_ERROR_LEVEL]
    )
end

Citizen.CreateThread(function()
    while not YacaClient.sharedConfig do
        Citizen.Wait(100)
    end
    initPhoneModule()
end)
