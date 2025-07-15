ChatroomService = {
    chatrooms = Tables.newIdIndexedTable(),

    addChatroom = function(chatroom)
        if not chatroom or not chatroom.id then
            return false, "Invalid chatroom"
        end

        -- Check if the chatroom already exists
        if ChatroomService.chatrooms:get(chatroom.id) then
            return false, "Chatroom already exists"
        end

        -- Add the chatroom to the service
        ChatroomService.chatrooms:add(chatroom)

        return true, "Chatroom created successfully"
    end,

    ---@return Chatroom|nil
    getChatroom = function(chatroomID)
        return ChatroomService.chatrooms:get(chatroomID)
    end,

    getChatroomByName = function(name)
        for _, chatroom in ipairs(ChatroomService.chatrooms.items) do
            if chatroom.name == name then
                return chatroom
            end
        end
        return nil
    end,

    getAllChatrooms = function()
        return ChatroomService.chatrooms.items
    end,

    removeChatroom = function(chatroomID)
        return ChatroomService.chatrooms:remove(chatroomID)
    end,

    save = function()
        -- Save chatrooms to disk
        love.filesystem.createDirectory("chatrooms")
        for _, chatroom in ipairs(ChatroomService.chatrooms.items) do
            local fileName = "chatrooms/" .. chatroom.id .. ".bin"
            love.filesystem.write(fileName, chatroom:encode())
        end
    end,

    load = function()
        -- Load chatrooms from disk
        local files = love.filesystem.getDirectoryItems("chatrooms")
        for _, fileName in ipairs(files) do
            if fileName:match("%.bin$") then
                local filePath = "chatrooms/" .. fileName
                local data = love.filesystem.read(filePath)
                if data then
                    local success, chatroom = Chatroom.decodeNewChatroom(data)
                    if success then
                        ChatroomService.chatrooms:add(chatroom)
                    else
                        print("Failed to decode chatroom from file: " .. filePath)
                    end
                else
                    print("Failed to read chatroom file: " .. filePath)
                end
            end
        end
    end,
}
ChatroomService.load()
