---@param src number
---@param nameSet table
---@param namePattern string
---@return string|nil
function YacaGenerateRandomName(src, nameSet, namePattern)
    local playerName = GetPlayerName(tostring(src)) or "Unknown"

    for _ = 1, 10 do
        local generatedName = namePattern
        generatedName = generatedName:gsub("{serverid}", tostring(src))
        generatedName = generatedName:gsub("{playername}", playerName)

        local guid = ""
        local chars = "0123456789abcdef"
        for i = 1, 32 do
            local idx = math.random(1, #chars)
            guid = guid .. chars:sub(idx, idx)
        end
        generatedName = generatedName:gsub("{guid}", guid)

        if #generatedName > 30 then
            generatedName = generatedName:sub(1, 30)
        end

        if not nameSet[generatedName] then
            nameSet[generatedName] = true
            return generatedName
        end
    end

    print(("[YaCA] Couldn't generate a random name for player %s (ID: %d)."):format(playerName, src))
    return nil
end

function YacaCheckVersion()
    local currentVersion = GetResourceMetadata(GetCurrentResourceName(), "version", 0)
    if not currentVersion then
        print("[YaCA] Version check failed, no version found in resource manifest.")
        return
    end

    local parsedVersion = currentVersion:match("%d+%.%d+%.%d+")
    if not parsedVersion then
        print("[YaCA] Version check failed, version in resource manifest is not in the correct format.")
        return
    end

    PerformHttpRequest("https://api.github.com/repos/mattibat/yaca-voice/releases/latest", function(statusCode, responseText)
        if statusCode ~= 200 then
            print("[YaCA] Version check failed, unable to fetch latest release.")
            return
        end

        local data = json.decode(responseText)
        if not data or not data.tag_name then
            print("[YaCA] Version check failed, unable to parse latest release.")
            return
        end

        local latestVersion = data.tag_name:match("%d+%.%d+%.%d+")
        if not latestVersion then
            print("[YaCA] Version check failed, latest release is not in the correct format.")
            return
        end

        if parsedVersion ~= latestVersion then
            local cv = {}
            for v in parsedVersion:gmatch("%d+") do cv[#cv + 1] = tonumber(v) end
            local lv = {}
            for v in latestVersion:gmatch("%d+") do lv[#lv + 1] = tonumber(v) end

            for i = 1, math.max(#cv, #lv) do
                local c = cv[i] or 0
                local l = lv[i] or 0
                if c < l then
                    print(("[YaCA] You are running an outdated version of YaCA. (current: %s, latest: %s)"):format(currentVersion, data.tag_name))
                    if data.html_url then
                        print(("[YaCA] %s"):format(data.html_url))
                    end
                    return
                elseif c > l then
                    return
                end
            end
        end
    end, "GET", "", { ["User-Agent"] = "yaca-voice" })
end

---@param eventName string
---@param targetIds number|table
---@vararg any
function YacaTriggerClientEvent(eventName, targetIds, ...)
    if type(targetIds) ~= "table" then
        targetIds = { targetIds }
    end

    if #targetIds < 1 then return end

    for _, targetId in ipairs(targetIds) do
        TriggerClientEvent(eventName, targetId, ...)
    end
end
