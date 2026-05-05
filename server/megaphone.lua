YacaServerMegaphone = {}

local function initServerMegaphoneModule()
    YacaServerMegaphone:registerEvents()
end

function YacaServerMegaphone:registerEvents()
    RegisterNetEvent("server:yaca:useMegaphone", function(state)
        self:playerUseMegaphone(source, state)
    end)

    RegisterNetEvent("server:yaca:playerLeftVehicle", function()
        self:changeMegaphoneState(source, false, true)
    end)
end

function YacaServerMegaphone:playerUseMegaphone(src, state)
    local player = YacaServer:getPlayer(src)
    if not player then return end

    local playerState = Player(src).state

    if (not state and not playerState[YACA_STATE_MEGAPHONE]) or (state and playerState[YACA_STATE_MEGAPHONE]) then
        return
    end

    self:changeMegaphoneState(src, state)
    TriggerEvent("yaca:external:changeMegaphoneState", src, state)
end

function YacaServerMegaphone:changeMegaphoneState(src, state, forced)
    forced = forced or false
    local playerState = Player(src).state

    if not state and playerState[YACA_STATE_MEGAPHONE] then
        playerState:set(YACA_STATE_MEGAPHONE, nil, true)
        if forced then
            TriggerClientEvent("client:yaca:setLastMegaphoneState", src, false)
        end
    elseif state and not playerState[YACA_STATE_MEGAPHONE] then
        playerState:set(YACA_STATE_MEGAPHONE, YacaServer.sharedConfig.megaphone.range, true)
    end
end

Citizen.CreateThread(function()
    while not YacaServer.sharedConfig do
        Citizen.Wait(100)
    end
    initServerMegaphoneModule()
end)
