local currentLocale = "en"

---@param loc string
function YacaInitLocale(loc)
    currentLocale = loc or "en"
    if not YacaLocales[currentLocale] then
        print(("[YaCA] Locale '%s' not found, falling back to 'en'"):format(currentLocale))
        currentLocale = "en"
    end
end

---@param key string
---@vararg any
---@return string
function YacaLocale(key, ...)
    local localeTable = YacaLocales[currentLocale] or YacaLocales["en"] or {}
    local str = localeTable[key]
    if not str then
        return key
    end
    if select("#", ...) > 0 then
        return string.format(str, ...)
    end
    return str
end

---@param value number
---@param min number
---@param max number
---@return number
function YacaClamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

local math_floor = math.floor

---@param value number
---@param decimals number
---@return number
function YacaRoundFloat(value, decimals)
    local mult = decimals and 10 ^ decimals or 100
    return math_floor(value * mult + 0.5) / mult
end

---@param level number
function YacaSetGlobalErrorLevel(level)
    if level < 0 or level > 1 then return end
    GlobalState:set(YACA_STATE_GLOBAL_ERROR_LEVEL, level, true)
end

---@return number
function YacaGetGlobalErrorLevel()
    return GlobalState[YACA_STATE_GLOBAL_ERROR_LEVEL] or 0
end
