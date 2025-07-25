local requests = {}
local replies = {}

--- Sends a request to the server.
---@param path string
---@param args table
---@param userID string|nil
---@param callback function|nil
---@param timeout number|nil
---@param type "post" | "get" | "put" | "delete" | nil
---@param amount "once" | "many" | nil
---@param id string|nil
---@return boolean
---@return string
local function Request(path, args, userID, callback, timeout, type, amount, id)
    amount = amount or "many"

    if amount == "once" then
        if id == nil then
            return false, "ID must be provided for 'once' requests"
        end
        -- If we've already sent a request with this path and id, we should not send it again until we get a reply
        for _, request in ipairs(requests) do
            if request.path == path and request.id == id then
                return false, "Request with this path and ID already exists"
            end
        end
    end

    local data = {
        type = type,
        path = path,
        args = args or {},
        userID = userID,
    }

    local message = Message.newMessage(nil, data, userID or "")

    if not message then
        return false, "Failed to create message"
    end

    table.insert(requests, {
        messageID = message.id,
        callback = callback,
        timeout = timeout or 10,
        startTime = love.timer.getTime(),
        path = path,
        id = id,
    })

    return message:send(Connection.server)
end

local function updateRequests()
    -- match get requests with replies
    for i = #requests, 1, -1 do
        local request = requests[i]
        local messageID = request.messageID

        local reply = replies[messageID]
        if reply then
            table.remove(requests, i)

            if request.callback then
                request.callback(unpack(reply))
            end
        end
    end

    -- remove timed out requests
    local currentTime = love.timer.getTime()
    for i = #requests, 1, -1 do
        local request = requests[i]
        if currentTime - request.startTime > request.timeout then
            table.remove(requests, i)
            if request.callback then
                request.callback(false, "Request timed out")
            end
        end
    end

    -- remove any replies that are no longer needed
    table.clear(replies) -- if a reply is left after get request matching, it means it was not used
end

return {
    request = Request,
    replies = replies,
    requests = requests,
    updateRequests = updateRequests
}
