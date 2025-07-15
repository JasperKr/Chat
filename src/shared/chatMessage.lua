---@class ChatMessage
---@field text string
---@field from ID
---@field fromName string
---@field timestamp number
---@field newLineCount number
---@field attachments Attachment[]? -- Optional, used for attachments like images or files
---@field comboTimeStart number? -- Optional, used for combo messages
---@field combinedMessages ChatMessage[] -- Optional, used for combo messages

--- Create a new chat message
---@param text string
---@param from ID
---@param fromName string? -- Name of the user sending the message
---@param attachments Attachment[]? -- List of attachments
---@param timestamp number? -- Timestamp of the message, defaults to current time
---@return ChatMessage
local function newChatMessage(text, from, fromName, attachments, timestamp)
    local chatMessage = {
        text = text,
        from = from,
        fromName = fromName or "Unknown",
        timestamp = timestamp or os.time(),
        newLineCount = CountNewLines(text),
        attachments = attachments,
        combinedMessages = {},
    }

    return chatMessage
end

return {
    newChatMessage = newChatMessage,
}
