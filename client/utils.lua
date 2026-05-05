local isFiveM = (YacaCache and YacaCache.game == "fivem") or (GetGameName() == "fivem")

local math_sin = math.sin
local math_cos = math.cos
local math_abs = math.abs
local DEG_TO_RAD = math.pi / 180.0

---@param arr table
---@return table
function YacaConvertToXYZ(arr)
    return {
        x = YacaRoundFloat(arr.x or arr[1] or 0),
        y = YacaRoundFloat(arr.y or arr[2] or 0),
        z = YacaRoundFloat(arr.z or arr[3] or 0),
    }
end

---@return table
function YacaGetCamDirection()
    local rot = GetGameplayCamRot(2)
    local rotX = rot.x * DEG_TO_RAD
    local rotZ = rot.z * DEG_TO_RAD
    local cosx = math_abs(math_cos(rotX))
    return {
        x = YacaRoundFloat(-math_sin(rotZ) * cosx),
        y = YacaRoundFloat(math_cos(rotZ) * cosx),
        z = YacaRoundFloat(math_sin(rotX)),
    }
end

---@param input string
---@return number
function YacaJoaat(input)
    input = string.lower(input)
    local hash = 0
    for i = 1, #input do
        hash = hash + string.byte(input, i)
        hash = hash + (hash << 10)
        hash = hash ~ (hash >> 6)
    end
    hash = hash + (hash << 3)
    hash = hash ~ (hash >> 11)
    hash = hash + (hash << 15)
    return hash & 0xFFFFFFFF
end

local windowBones = {
    [0] = "window_lf",
    [1] = "window_rf",
    [2] = "window_lr",
    [3] = "window_rr",
}

local doorBones = {
    [0] = "door_dside_f",
    [1] = "door_pside_f",
    [2] = "door_dside_r",
    [3] = "door_pside_r",
    [4] = "bonnet",
    [5] = "boot",
}

---@param vehicle number
---@param windowId number
---@return boolean
function YacaHasWindow(vehicle, windowId)
    local boneName = windowBones[windowId]
    if not boneName then return false end
    return GetEntityBoneIndexByName(vehicle, boneName) ~= -1
end

---@param vehicle number
---@param doorId number
---@return boolean
function YacaHasDoor(vehicle, doorId)
    local boneName = doorBones[doorId]
    if not boneName then return false end
    return GetEntityBoneIndexByName(vehicle, boneName) ~= -1
end

---@param vehicle number
---@return boolean
function YacaVehicleHasOpening(vehicle)
    local hasDoors = false
    for i = 0, 5 do
        if i ~= 4 then
            local boneName = doorBones[i]
            if boneName and GetEntityBoneIndexByName(vehicle, boneName) ~= -1 then
                hasDoors = true
                if GetVehicleDoorAngleRatio(vehicle, i) > 0 or IsVehicleDoorDamaged(vehicle, i) then
                    return true
                end
            end
        end
    end

    if not hasDoors then return true end

    if not AreAllVehicleWindowsIntact(vehicle) then
        return true
    end

    for i = 0, 3 do
        local boneName = windowBones[i]
        if boneName and GetEntityBoneIndexByName(vehicle, boneName) ~= -1 and not IsVehicleWindowIntact(vehicle, i) then
            return true
        end
    end

    if IsVehicleAConvertible(vehicle, false) and GetConvertibleRoofState(vehicle) ~= 0 then
        return true
    end

    return false
end

---@param animDict string
---@param timeout number|nil
---@return boolean
function YacaRequestAnimDict(animDict, timeout)
    if HasAnimDictLoaded(animDict) then return true end
    if not DoesAnimDictExist(animDict) then
        print(("[YaCA] Invalid animDict: %s"):format(animDict))
        return false
    end

    RequestAnimDict(animDict)
    local timer = timeout or 30000
    local elapsed = 0
    while not HasAnimDictLoaded(animDict) and elapsed < timer do
        Citizen.Wait(10)
        elapsed = elapsed + 10
    end

    return HasAnimDictLoaded(animDict)
end

---@param modelName string|number
---@param timeout number|nil
---@return number|nil The
function YacaRequestModel(modelName, timeout)
    local modelHash = modelName
    if type(modelName) == "string" then
        modelHash = YacaJoaat(modelName)
    end

    if HasModelLoaded(modelHash) then return modelHash end
    if not IsModelValid(modelHash) then
        print(("[YaCA] Invalid model: %s"):format(tostring(modelName)))
        return nil
    end

    RequestModel(modelHash)
    local timer = timeout or 30000
    local elapsed = 0
    while not HasModelLoaded(modelHash) and elapsed < timer do
        Citizen.Wait(10)
        elapsed = elapsed + 10
    end

    if HasModelLoaded(modelHash) then
        return modelHash
    end
    return nil
end

---@param model string|number
---@param boneId number
---@param offset table
---@param rotation table
---@return number|nil The
function YacaCreateProp(model, boneId, offset, rotation)
    offset = offset or { 0.0, 0.0, 0.0 }
    rotation = rotation or { 0.0, 0.0, 0.0 }

    local modelHash = YacaRequestModel(model)
    if not modelHash then return nil end

    local coords = GetEntityCoords(YacaCache.ped, true)
    local obj = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, false)
    SetEntityCollision(obj, false, false)
    AttachEntityToEntity(
        obj, YacaCache.ped,
        GetPedBoneIndex(YacaCache.ped, boneId),
        offset[1], offset[2], offset[3],
        rotation[1], rotation[2], rotation[3],
        true, false, false, true, 2, true
    )

    SetModelAsNoLongerNeeded(modelHash)
    return obj
end
