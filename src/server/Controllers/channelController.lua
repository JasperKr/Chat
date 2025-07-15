return
{
    {
        create = function(userID, chatroomID, name)
            local channel = Channel.newChannel(name)

            if not channel then
                return false, "Failed to create channel"
            end

            local chatroom = ChatroomService.getChatroom(chatroomID)

            if not chatroom then
                return false, "Chatroom not found"
            end

            if chatroom.ownerID ~= userID then
                return false, "Only the owner can create channels"
            end

            if chatroom:getChannelByName(name) then
                return false, "Channel with this name already exists"
            end

            local success, errmsg = chatroom:addChannel(channel)

            if not success then
                return false, errmsg
            end

            return true, channel
        end,

        get = function(chatroomID, channelID)
            local chatroom = ChatroomService.getChatroom(chatroomID)

            if not chatroom then
                return false, "Chatroom not found"
            end

            local channel = chatroom:getChannelByID(channelID)

            if not channel then
                return false, "Channel not found"
            end

            return true, channel
        end,

        getAll = function(chatroomID)
            local chatroom = ChatroomService.getChatroom(chatroomID)

            if not chatroom then
                return false, "Chatroom not found"
            end

            return true, chatroom:getChannels()
        end,

        update = function(chatroomID, channelID, newName)
            local chatroom = ChatroomService.getChatroom(chatroomID)

            if not chatroom then
                return false, "Chatroom not found"
            end

            local channel = chatroom:getChannelByID(channelID)

            if not channel then
                return false, "Channel not found"
            end

            channel.name = newName

            return true
        end,

        delete = function(chatroomID, channelID)
            local chatroom = ChatroomService.getChatroom(chatroomID)

            if not chatroom then
                return false, "Chatroom not found"
            end

            local channel = chatroom:getChannelByID(channelID)

            if not channel then
                return false, "Channel not found"
            end

            chatroom.channels:remove(channelID)

            return true
        end,
    },
    {

    },
    "channel"
}
