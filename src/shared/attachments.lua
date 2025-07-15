---@class Attachment
---@field data string
---@field type "texture" | "file"

local filePreviewTexture = love.graphics.newTexture("assets/uploadedFile.png")
local attachmentIDToTexture = {}

--- Attachments for chat messages
---@param data love.FileData | love.ByteData
---@param attachmentType "texture" | "file"
---@return Attachment
local function newChatMessageAttachment(data, attachmentType)
    if attachmentType ~= "texture" and attachmentType ~= "file" then
        error("Invalid attachment type: " .. tostring(attachmentType))
    end

    local id = ID.newID()

    return {
        id = id,
        data = data:getString(),
        type = attachmentType,
    }
end

local function getAttachmentTexture(attachment)
    if not attachment or not attachment.id or not attachment.type then
        return nil
    end
    if attachment.type == "texture" then
        if not attachmentIDToTexture[attachment.id] then
            local imageData = love.image.newImageData(love.data.newByteData(attachment.data))
            attachmentIDToTexture[attachment.id] = love.graphics.newImage(imageData)
        end
        return attachmentIDToTexture[attachment.id]
    elseif attachment.type == "file" then
        return filePreviewTexture
    end
    return nil
end

return {
    newChatMessageAttachment = newChatMessageAttachment,
    getAttachmentTexture = getAttachmentTexture,
}
