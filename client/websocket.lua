YacaWebSocket = {
    readyState = 0, -- 0 = connecting, 1 = open, 3 = closed
    nuiReady = false,
    initialized = false,
    connectLoopActive = false,
    listeners = {},
}

---@param event string "message", "open", "close"
---@param callback function
function YacaWebSocket:on(event, callback)
    if not self.listeners[event] then
        self.listeners[event] = {}
    end
    self.listeners[event][#self.listeners[event] + 1] = callback
end

---@param event string
---@vararg any
function YacaWebSocket:emit(event, ...)
    local callbacks = self.listeners[event]
    if callbacks then
        for _, cb in ipairs(callbacks) do
            cb(...)
        end
    end
end

function YacaWebSocket:start()
    if self.connectLoopActive then return end

    self.connectLoopActive = true
    self.readyState = 0

    Citizen.CreateThread(function()
        while self.connectLoopActive do
            while self.connectLoopActive and not self.nuiReady do
                Citizen.Wait(100)
            end

            if not self.connectLoopActive then
                break
            end

            if self.readyState == 1 then
                break
            end

            SendNuiMessage(json.encode({ action = "connect" }))

            local waited = 0
            while self.connectLoopActive and self.readyState ~= 1 and waited < 3000 do
                Citizen.Wait(100)
                waited = waited + 100
            end
        end

        self.connectLoopActive = false
    end)
end

---@param data table
function YacaWebSocket:send(data)
    if self.readyState ~= 1 then return end
    SendNuiMessage(json.encode({
        action = "command",
        data = data,
    }))
end

function YacaWebSocket:close()
    self.connectLoopActive = false
    if self.readyState == 3 then return end
    SendNuiMessage(json.encode({ action = "close" }))
end

RegisterNuiCallbackType("YACA_OnNuiReady")
RegisterNuiCallbackType("YACA_OnMessage")
RegisterNuiCallbackType("YACA_OnConnected")
RegisterNuiCallbackType("YACA_OnDisconnected")

RegisterNUICallback("YACA_OnNuiReady", function(_, cb)
    YacaWebSocket.nuiReady = true
    cb({})
end)

RegisterNUICallback("YACA_OnMessage", function(data, cb)
    YacaWebSocket:emit("message", data)
    cb({})
end)

RegisterNUICallback("YACA_OnConnected", function(_, cb)
    YacaWebSocket.readyState = 1
    YacaWebSocket.connectLoopActive = false
    YacaWebSocket:emit("open")
    cb({})
end)

RegisterNUICallback("YACA_OnDisconnected", function(data, cb)
    YacaWebSocket.readyState = 3
    YacaWebSocket.connectLoopActive = false
    YacaWebSocket:emit("close", data.code, data.reason)

    if YacaWebSocket.initialized and YacaWebSocket.nuiReady then
        SetTimeout(2500, function()
            if YacaWebSocket.initialized and YacaWebSocket.nuiReady and YacaWebSocket.readyState ~= 1 then
                YacaWebSocket:start()
            end
        end)
    end

    cb({})
end)
