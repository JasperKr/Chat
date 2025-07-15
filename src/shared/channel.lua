local channelMetatable = {}

---@class Channel
---@field id string
---@field name string
---@field messages ChatMessage[]
---@field lastMessageTimestamp number
local channelFunctions = {}
channelMetatable.__index = channelFunctions

--- Creates a new channel.
---@param name string
---@param id string|nil
---@return Channel
local function newChannel(name, id)
    local channel = {}
    channel.id = id or ID.newID()
    channel.name = name or "Unnamed Channel"
    channel.messages = {}
    channel.lastMessageTimestamp = 0

    setmetatable(channel, channelMetatable)

    return channel
end

--- Loads a channel from the given data.
---@param data table
---@return Channel
local function loadChannel(data)
    return setmetatable(data, channelMetatable) -- no special handling needed for now
end

--- Decodes a new channel from the received data.
---@param data string
local function decodeNewChannel(data)
    local decoded = Buffer.decode(data)

    if type(decoded) ~= "table" then
        return false, "Invalid channel data"
    end

    local channel = newChannel(decoded.name, decoded.id)
    channel.messages = decoded.messages or {}

    return true, channel
end

function channelFunctions:encode()
    return Buffer.encode({
        id = self.id,
        name = self.name,
        messages = self.messages,
        lastMessageTimestamp = self.lastMessageTimestamp,
    })
end

--- Adds a message to the channel.
--- @param message ChatMessage
function channelFunctions:addMessage(message)
    local lastMessage = self:getLastMessage()

    if lastMessage and lastMessage.from == message.from then
        -- if combo start or last message timestamp is within 10 minutes, combine messages

        if message.timestamp - lastMessage.timestamp <= 600 then
            table.insert(lastMessage.combinedMessages, message)
        else
            table.insert(self.messages, message)
        end
    else
        table.insert(self.messages, message)
    end

    self.lastMessageTimestamp = math.max(self.lastMessageTimestamp, message.timestamp)
end

--- Gets the last message in the channel.
--- @return ChatMessage|nil
function channelFunctions:getLastMessage()
    if #self.messages == 0 then
        return nil
    end
    return self.messages[#self.messages]
end

--- Gets the number of messages in the channel.
--- @return number
function channelFunctions:getMessageCount()
    return #self.messages
end

return {
    newChannel = newChannel,
    decodeNewChannel = decodeNewChannel,
    loadChannel = loadChannel,
}
