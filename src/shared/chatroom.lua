local chatroomMetatable = {}

---@class Chatroom
---@field id string
---@field ownerID ID
---@field name string
---@field channels iDIndexedTable<Channel>
---@field users ID[] -- List of user IDs in the chatroom
---@field bannedUsers ID[] -- List of user IDs that are banned from the chatroom
---@field lastMessageTimestamp number
local chatroomFunctions = {}
chatroomMetatable.__index = chatroomFunctions

--- Creates a new chatroom.
---@param name string
---@param id string|nil
---@param ownerID string|nil
---@return Chatroom
local function newChatroom(name, id, ownerID)
    local chatroom = {}
    chatroom.id = id or ID.newID()
    chatroom.ownerID = ownerID
    chatroom.name = name or "Unnamed Chatroom"

    chatroom.channels = Tables.newIdIndexedTable()
    chatroom.channels:setKeepOrder(true)
    chatroom.channels:add(Channel.newChannel("General", nil)) -- Default channel

    chatroom.users = {}
    chatroom.bannedUsers = {}
    chatroom.lastMessageTimestamp = 0

    setmetatable(chatroom, chatroomMetatable)

    return chatroom
end

--- Loads a chatroom from the given data.
---@param data table
---@return Chatroom
local function loadChatroom(data)
    local chatroom = setmetatable(data, chatroomMetatable)

    local channels = Tables.newIdIndexedTable()
    channels:setKeepOrder(true)
    for _, channelData in ipairs(data.channels or {}) do
        channels:add(Channel.loadChannel(channelData))
    end

    chatroom.channels = channels

    return chatroom
end

--- Decodes a new chatroom from the received data.
---@param data string
local function decodeNewChatroom(data)
    local decoded = Buffer.decode(data)

    if type(decoded) ~= "table" then
        return false, "Invalid chatroom data"
    end

    local chatroom = newChatroom(decoded.name, decoded.id)
    if decoded.messages then -- old data, channels didn't exist yet
        -- create "General" channel and add messages there
        local generalChannel = chatroom.channels.items[1] or Channel.newChannel("General", nil)

        for _, message in ipairs(decoded.messages) do
            generalChannel:addMessage(message)
        end

        chatroom.channels:add(generalChannel)
    end

    for _, channelData in ipairs(decoded.channels or {}) do
        local success, channel = Channel.decodeNewChannel(channelData)

        if success then
            chatroom.channels:add(channel)
        else
            print("Failed to decode channel: " .. channel)
        end
    end

    chatroom.users = decoded.users or {}
    chatroom.lastMessageTimestamp = decoded.lastMessageTimestamp or 0

    return true, chatroom
end

function chatroomFunctions:encode()
    local data = {
        id = self.id,
        ownerID = self.ownerID,
        name = self.name,
        channels = {},
        users = self.users,
        lastMessageTimestamp = self.lastMessageTimestamp,
    }

    for _, channel in ipairs(self.channels.items) do
        table.insert(data.channels, channel:encode())
    end

    return Buffer.encode(data)
end

--- Adds a user to the chatroom.
--- @param user User
function chatroomFunctions:addUser(user)
    if not self:isUserInChatroom(user.id) then
        table.insert(self.users, user.id)
        return true, "User added to chatroom"
    else
        return false, "User already in chatroom"
    end
end

--- Checks if a user is in the chatroom.
--- @param userID string
--- @return boolean
function chatroomFunctions:isUserInChatroom(userID)
    for _, id in ipairs(self.users) do
        if id == userID then
            return true
        end
    end
    return false
end

--- Removes a user from the chatroom.
--- @param userID string
--- @return boolean
function chatroomFunctions:removeUser(userID)
    for i, id in ipairs(self.users) do
        if id == userID then
            table.remove(self.users, i)
            return true
        end
    end
    return false
end

--- Gets the number of users in the chatroom.
--- @return number
function chatroomFunctions:getUserCount()
    return #self.users
end

--- Gets the number of channels in the chatroom.
--- @return number
function chatroomFunctions:getChannelCount()
    return #self.channels.items
end

--- Get the channels in the chatroom.
--- @return Channel[]
function chatroomFunctions:getChannels()
    return self.channels.items
end

--- Gets the channel by its name.
--- @param name string
--- @return Channel|nil
function chatroomFunctions:getChannelByName(name)
    for _, channel in pairs(self.channels.items) do
        if channel.name == name then
            return channel
        end
    end
    return nil
end

--- Get the channel by its ID.
--- @param id ID
--- @return Channel|nil
function chatroomFunctions:getChannelByID(id)
    return self.channels:get(id)
end

--- Adds a channel to the chatroom.
--- @param channel Channel
function chatroomFunctions:addChannel(channel)
    self.channels:add(channel)
    return true
end

return {
    newChatroom = newChatroom,
    decodeNewChatroom = decodeNewChatroom,
    loadChatroom = loadChatroom,
}
