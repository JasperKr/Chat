---@alias ID string 128-bit utf-8 string

local ffi = require("ffi")
local tempID = ffi.new("char[16]")
local tempIDPtr = ffi.cast("uint8_t*", tempID)

local alphaNumericChars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

local function newID()
    -- 16 bytes, 16 chars

    for i = 0, 15 do
        local j = love.math.random(1, #alphaNumericChars)
        tempIDPtr[i] = string.sub(alphaNumericChars, j, j):byte()
    end

    return ffi.string(tempID, 16)
end

--- Decode ID from a pointer
---@param id ffi.cdata*
local function decodeID(id)
    return ffi.string(id, 16)
end

--- Encode ID to a pointer
--- @param id ID
---@return ffi.cdata*
local function encodeID(id)
    local data = ffi.new("char[16]", id)
    return data
end

return {
    newID = newID,
    decodeID = decodeID,
    encodeID = encodeID,
}
