---@class ChatMessage
---@field text string
---@field from ID
---@field fromName string
---@field timestamp number
---@field newLineCount number
---@field comboTimeStart number? -- Optional, used for combo messages
---@field combinedMessages table -- Optional, used for combo messages

--- Create a new chat message
---@param text string
---@param from ID
---@param timestamp number?
---@return ChatMessage
local function newChatMessage(text, from, fromName, timestamp)
    return {
        text = text,
        from = from,
        fromName = fromName or "Unknown",
        timestamp = timestamp or os.time(),
        newLineCount = CountNewLines(text),
        combinedMessages = { text },
    }
end

return {
    newChatMessage = newChatMessage,
}
