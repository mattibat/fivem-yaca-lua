let webSocket = null
let reconnectTimeout = null
let readyHeartbeat = null
let connectRequested = false
let manualClose = false

function hasActiveSocket() {
    return webSocket && (webSocket.readyState === WebSocket.OPEN || webSocket.readyState === WebSocket.CONNECTING)
}

function clearReconnectTimeout() {
    if (!reconnectTimeout) {
        return
    }

    clearTimeout(reconnectTimeout)
    reconnectTimeout = null
}

function stopReadyHeartbeat() {
    if (!readyHeartbeat) {
        return
    }

    clearInterval(readyHeartbeat)
    readyHeartbeat = null
}

function sendNuiReady() {
    return sendNuiData('YACA_OnNuiReady')
}

function startReadyHeartbeat() {
    if (readyHeartbeat) {
        return
    }

    sendNuiReady()
    readyHeartbeat = setInterval(() => {
        sendNuiReady()
    }, 3000)
}

function scheduleReconnect() {
    if (!connectRequested || manualClose || reconnectTimeout) {
        return
    }

    reconnectTimeout = setTimeout(() => {
        reconnectTimeout = null
        connect()
    }, 1500)
}

/**
 * Connect to the YaCA voice plugin
 */
function connect() {
    if (!connectRequested || manualClose) {
        return
    }

    if (hasActiveSocket()) {
        return
    }

    console.log('[YaCA-Websocket] Trying to Connect to YaCA WebSocket...')

    try {
        webSocket = new window.WebSocket('ws://127.0.0.1:30125/')
    } catch (error) {
        console.error('[YaCA-Websocket] Failed to create websocket:', error)
        scheduleReconnect()
        return
    }

    webSocket.onmessage = (event) => {
        if (!event) return
        sendNuiData('YACA_OnMessage', event.data)
    }

    webSocket.onopen = (event) => {
        if (!event) return

        stopReadyHeartbeat()
        clearReconnectTimeout()
        sendNuiData('YACA_OnConnected')
    }

    webSocket.onclose = (event) => {
        if (!event) return

        sendNuiData('YACA_OnDisconnected', {
            code: event.code,
            reason: event.reason,
        })

        webSocket = null

        if (!manualClose) {
            startReadyHeartbeat()
            scheduleReconnect()
        }
    }

    webSocket.onerror = () => {
        if (!manualClose) {
            scheduleReconnect()
        }
    }
}

function requestConnection() {
    manualClose = false
    connectRequested = true

    startReadyHeartbeat()
    connect()
}

function closeConnection() {
    connectRequested = false
    manualClose = true

    stopReadyHeartbeat()
    clearReconnectTimeout()

    if (webSocket) {
        const socket = webSocket
        webSocket = null

        if (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING) {
            socket.close()
        }
    }
}

/**
 * Send a command to the YaCA voice plugin
 *
 * @param command - The command to send as a object
 */
function runCommand(command) {
    if (!webSocket || webSocket.readyState !== WebSocket.OPEN) {
        return
    }

    webSocket.send(JSON.stringify(command))
}

/**
 * Send a NUI message to the client
 *
 * @param event - The name of the callback
 * @param data - The data to send
 */
function sendNuiData(event, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${event}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(data),
    })
        .then(() => true)
        .catch((error) => {
            console.error('[YaCA-Websocket] Error sending NUI Message:', error)
            return false
        })
}

window.addEventListener('DOMContentLoaded', () => {
    startReadyHeartbeat()
})

startReadyHeartbeat()

window.addEventListener('message', (event) => {
    if (event.data.action === 'connect') {
        requestConnection()
    } else if (event.data.action === 'command') {
        runCommand(event.data.data)
    } else if (event.data.action === 'close') {
        closeConnection()
    } else {
        console.error('[YaCA-Websocket] Unknown message:', event.data)
    }
})
