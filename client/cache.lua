YacaCache = {
    playerId = PlayerId(),
    serverId = GetPlayerServerId(PlayerId()),
    ped = PlayerPedId(),
    vehicle = false,
    seat = false,
    resource = GetCurrentResourceName(),
    game = GetGameName(),
}

local function updateCache()
    local ped = PlayerPedId()
    YacaCache.ped = ped

    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle > 0 then
        if vehicle ~= YacaCache.vehicle then
            YacaCache.seat = false
        end

        YacaCache.vehicle = vehicle

        if not YacaCache.seat or GetPedInVehicleSeat(vehicle, YacaCache.seat) ~= ped then
            for i = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 2 do
                if GetPedInVehicleSeat(vehicle, i) == ped then
                    YacaCache.seat = i
                    break
                end
            end
        end
    else
        YacaCache.vehicle = false
        YacaCache.seat = false
    end
end

Citizen.CreateThread(function()
    while true do
        updateCache()
        Citizen.Wait(100)
    end
end)
