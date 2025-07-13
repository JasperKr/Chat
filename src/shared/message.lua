local messageMetatable = {}

local ffi = require("ffi")

local dataTypes = {
    string = 0,
    byteData = 1,
    table = 2,
}

---@class Message
---@field id string
---@field content love.ByteData | string | table
---@field from string
---@field to string
---@field timestamp number
---@field dataType "string" | "byteData" | "table"
local messageFunctions = {}
messageMetatable.__index = messageFunctions

---@param id ID?
---@param content love.ByteData | string | table
---@param from ID?
---@param to ID?
---@return Message?
local function newMessage(id, content, from, to)
    local message = {}
    message.id = id or ID.newID()
    message.content = content
    message.from = from or ""
    message.to = to or ""
    message.timestamp = os.time()
    message.dataType = type(content) == "string" and "string" or (type(content) == "table" and "table" or "byteData")

    setmetatable(message, messageMetatable)

    return message
end

--- Sends the message to the specified peer.
---@param peer any
---@param channel number|nil
---@return boolean, string
function messageFunctions:send(peer, channel)
    local content = self.content

    if type(content) == "table" then
        content = Buffer.encode(content)
    end

    if type(content) == "string" then
        content = love.data.newByteData(content)
    end

    if self.id == nil or self.from == nil or self.to == nil or self.timestamp == nil or not content or type(content) ~= "userdata" then
        return false, "Invalid message data"
    end

    ---@cast content love.ByteData

    local headerSize =
        16 + -- Message ID
        16 + -- From ID
        16 + -- To ID
        8 +  -- Timestamp uint64_t
        4 +  -- Content size uint32_t
        4    -- Data type uint32_t

    local message = love.data.newByteData(headerSize + content:getSize())
    local messagePtr = ffi.cast("char*", message:getFFIPointer())

    ffi.copy(messagePtr, self.id, 16)                                     -- [0] Copy ID
    ffi.copy(messagePtr + 16, self.from, 16)                              -- [16] Copy From ID
    ffi.copy(messagePtr + 32, self.to, 16)                                -- [32] Copy To ID
    ffi.cast("uint64_t*", messagePtr + 48)[0] = self.timestamp            -- [48] Copy timestamp
    ffi.cast("uint32_t*", messagePtr + 56)[0] = content:getSize()         -- [56] Copy content size
    ffi.cast("uint32_t*", messagePtr + 60)[0] = dataTypes[self.dataType]  -- [60] Copy data type

    ffi.copy(messagePtr + 64, content:getFFIPointer(), content:getSize()) -- [64] Copy content

    local compressedMessage = love.data.compress("data", "lz4", message, 9)

    if type(compressedMessage) == "string" then return false, "Compressed message must be a ByteData, not a string" end
    peer:send(compressedMessage:getPointer(), compressedMessage:getSize(), channel)

    return true, "Message sent successfully"
end

local function decodeMessage(message)
    local decompressedData = love.data.decompress("data", "lz4", message)
    if type(decompressedData) == "string" then return false, "Decompressed data must be a ByteData, not a string" end

    local messagePtr = ffi.cast("char*", decompressedData:getFFIPointer())
    local id = ffi.string(messagePtr, 16)                                    -- [0] Read ID
    local from = ffi.string(messagePtr + 16, 16)                             -- [16] Read From ID
    local to = ffi.string(messagePtr + 32, 16)                               -- [32] Read To ID
    local timestamp = ffi.cast("uint64_t*", messagePtr + 48)[0]              -- [48] Read timestamp
    local contentSize = ffi.cast("uint32_t*", messagePtr + 56)[0]            -- [56] Read content size
    local dataType = ffi.cast("uint32_t*", messagePtr + 60)[0]               -- [60] Read data type
    local content = love.data.newByteData(decompressedData, 64, contentSize) -- [64] Read content
    local data = content ---@type love.ByteData | string | table

    if dataType == dataTypes.string then
        data = ffi.string(content:getFFIPointer(), contentSize)
    elseif dataType == dataTypes.table then
        local tdata = Buffer.decode(ffi.string(content:getFFIPointer(), contentSize))

        if type(tdata) ~= "table" then
            return false, "Decoded data is not a table"
        end

        data = tdata
    end

    local decodedMessage = newMessage(id, data, from, to)
    decodedMessage.timestamp = timestamp

    return true, decodedMessage
end

function messageFunctions:getID()
    return self.id
end

function messageFunctions:getContent()
    return self.content
end

function messageFunctions:getFrom()
    return self.from
end

function messageFunctions:getTo()
    return self.to
end

function messageFunctions:getTimestamp()
    return self.timestamp
end

function messageFunctions:getDataType()
    return self.dataType
end

return {
    newMessage = newMessage,
    decodeMessage = decodeMessage,
}
