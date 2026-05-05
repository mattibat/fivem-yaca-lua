YacaIntercom = {}

local function initIntercomModule()
    YacaIntercom:registerEvents()
end

function YacaIntercom:registerEvents()
    RegisterNetEvent("client:yaca:addRemovePlayerIntercomFilter", function(playerIDs, state)
        if type(playerIDs) ~= "table" then
            playerIDs = { playerIDs }
        end

        local playersToAddRemove = {}
        for _, playerID in ipairs(playerIDs) do
            local player = YacaClient:getPlayerByID(playerID)
            if player then
                playersToAddRemove[#playersToAddRemove + 1] = player
            end
        end

        if #playersToAddRemove < 1 then return end

        YacaClient:setPlayersCommType(
            playersToAddRemove, YacaFilterEnum.INTERCOM, state,
            nil, nil, CommDeviceMode.TRANSCEIVER, CommDeviceMode.TRANSCEIVER
        )
    end)
end

Citizen.CreateThread(function()
    while not YacaClient.sharedConfig do
        Citizen.Wait(100)
    end
    initIntercomModule()
end)
