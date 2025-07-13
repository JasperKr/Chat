local chatroomMetatable = {}

---@class Chatroom
---@field id string
---@field ownerID ID
---@field name string
---@field messages ChatMessage[]
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
    chatroom.messages = {}
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
    return setmetatable(data, chatroomMetatable) -- no special handling needed for now
end

--- Decodes a new chatroom from the received data.
---@param data string
local function decodeNewChatroom(data)
    local decoded = Buffer.decode(data)

    if type(decoded) ~= "table" then
        return false, "Invalid chatroom data"
    end

    local chatroom = newChatroom(decoded.name, decoded.id)
    chatroom.messages = decoded.messages or {}
    chatroom.users = decoded.users or {}
    chatroom.lastMessageTimestamp = decoded.lastMessageTimestamp or 0

    return true, chatroom
end

--- Adds a message to the chatroom.
--- @param message ChatMessage
function chatroomFunctions:addMessage(message)
    local lastMessage = self:getLastMessage()

    if lastMessage and lastMessage.from == message.from then
        local comboOrSentTime = lastMessage.comboTimeStart or lastMessage.timestamp

        -- if combo start or last message timestamp is within 10 minutes, combine messages

        if os.time() - comboOrSentTime <= 600 and #lastMessage.text + #message.text < 4096 then
            lastMessage.text = lastMessage.text .. "\n" .. message.text
            lastMessage.newLineCount = lastMessage.newLineCount + message.newLineCount
            lastMessage.timestamp = math.min(lastMessage.timestamp, message.timestamp)
            lastMessage.comboTimeStart = comboOrSentTime -- keep the original combo start time
        else
            table.insert(self.messages, message)
        end
    else
        table.insert(self.messages, message)
        self.lastMessageTimestamp = math.max(self.lastMessageTimestamp, message.timestamp)
    end
end

--- Adds a user to the chatroom.
--- @param user User
function chatroomFunctions:addUser(user)
    if not self:isUserInChatroom(user.id) then
        table.insert(self.users, user.id)
        return true
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

--- Gets the last message in the chatroom.
--- @return ChatMessage|nil
function chatroomFunctions:getLastMessage()
    if #self.messages == 0 then
        return nil
    end
    return self.messages[#self.messages]
end

--- Gets the number of messages in the chatroom.
--- @return number
function chatroomFunctions:getMessageCount()
    return #self.messages
end

--- Gets the number of users in the chatroom.
--- @return number
function chatroomFunctions:getUserCount()
    return #self.users
end

return {
    newChatroom = newChatroom,
    decodeNewChatroom = decodeNewChatroom,
    chatroomMetatable = chatroomMetatable,
    chatroomFunctions = chatroomFunctions,
    loadChatroom = loadChatroom,
}
