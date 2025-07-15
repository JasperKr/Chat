local tempTable = {}

return
{
    {
        create = function(userID, name)
            local chatroom = Chatroom.newChatroom(name, nil, userID)

            if not chatroom then
                return false, "Failed to create chatroom"
            end

            local user = UserService.get(userID)

            if not user then
                return false, "User not found"
            end

            if ChatroomService.getChatroomByName(name) then
                return false, "Chatroom with this name already exists"
            end

            local success, errmsg = ChatroomService.addChatroom(chatroom)

            if not success then
                return false, errmsg
            end

            success, errmsg = chatroom:addUser(user)

            if not success then
                return false, errmsg
            end

            if not user:addChatroom(chatroom) then
                return false, "Failed to add chatroom to user"
            end

            return true, chatroom
        end,

        get = function(chatroomID)
            local chatroom = ChatroomService.getChatroom(chatroomID)

            if not chatroom then
                return false, "Chatroom not found"
            end

            return true, {
                name = chatroom.name,
                id = chatroom.id,
                ownerID = chatroom.ownerID,
            }
        end,

        remove = function(userID, chatroomID)
            local user = UserService.get(userID)

            if not user then
                return false, "User not found"
            end

            if not Privileges.hasPrivileges(user.privileges, 3) then
                return false, "Insufficient privileges"
            end

            return true, ChatroomService.removeChatroom(chatroomID)
        end,

        transferOwnership = function(userID, chatroomID, newOwnerID)
            local chatroom = ChatroomService.getChatroom(chatroomID)

            if not chatroom then
                return false, "Chatroom not found"
            end

            local currentOwner = UserService.get(chatroom.ownerID)
            local newOwner = UserService.get(newOwnerID)

            if not currentOwner or not newOwner then
                return false, "User not found"
            end

            if chatroom.ownerID ~= userID or currentOwner.id ~= userID then
                return false, "Only the current owner can transfer ownership"
            end

            chatroom.ownerID = newOwnerID
            return true, "Ownership transferred successfully"
        end,

        getMessages = function(chatroomID, channelID, from, to)
            local chatroom = ChatroomService.getChatroom(chatroomID)

            if not chatroom then
                return false, "Chatroom not found"
            end

            local channel = chatroom.channels:get(channelID)

            if not channel then
                print("Channel not found in chatroom: " .. chatroomID)
                for _, c in ipairs(chatroom.channels.items) do
                    print("Available channel: " .. c.name, c.id)
                end
                return false, "Channel not found"
            end

            to = math.min(to, #channel.messages)
            print("Getting messages from " .. from .. " to " .. to .. " in chatroom " .. chatroomID)

            if from < 1 or from > to then
                return false, "Invalid message range"
            end

            table.clear(tempTable)

            for i = from, to do
                table.insert(tempTable, channel.messages[i])
            end

            return true, tempTable
        end,

        getUsers = function(chatroomID)
            local chatroom = ChatroomService.getChatroom(chatroomID)

            if not chatroom then
                return false, "Chatroom not found"
            end

            return true, chatroom.users
        end,

        join = function(userID, chatroomID)
            print("User " .. userID .. " is trying to join chatroom " .. chatroomID)
            local chatroom = ChatroomService.getChatroom(chatroomID)

            if not chatroom then
                return false, "Chatroom not found"
            end

            if chatroom:isUserInChatroom(userID) then
                return false, "User already in chatroom"
            end

            local user = UserService.get(userID)
            if not user then
                return false, "User not found"
            end

            if not chatroom:addUser(user) then
                return false, "Failed to add user to chatroom"
            end

            if not user:addChatroom(chatroom) then
                return false, "Failed to add chatroom to user"
            end

            print("User " .. userID .. " joined chatroom " .. chatroomID)

            return true, "User added to chatroom"
        end,

        leave = function(userID, chatroomID)
            local chatroom = ChatroomService.getChatroom(chatroomID)

            if not chatroom then
                return false, "Chatroom not found"
            end

            if not chatroom:isUserInChatroom(userID) then
                return false, "User not in chatroom"
            end

            chatroom:removeUser(userID)
            return true, "User removed from chatroom"
        end,

        kick = function(userID, chatroomID, targetUserID)
            local chatroom = ChatroomService.getChatroom(chatroomID)

            if not chatroom then
                return false, "Chatroom not found"
            end

            if not chatroom:isUserInChatroom(targetUserID) then
                return false, "Target user not in chatroom"
            end

            local user = UserService.get(userID)
            if not user or not Privileges.hasPrivileges(user.privileges, 2) then
                return false, "Insufficient privileges"
            end

            chatroom:removeUser(targetUserID)
            return true, "User kicked from chatroom"
        end,

        ban = function(userID, chatroomID, targetUserID)
            local chatroom = ChatroomService.getChatroom(chatroomID)

            if not chatroom then
                return false, "Chatroom not found"
            end

            if not chatroom:isUserInChatroom(targetUserID) then
                return false, "Target user not in chatroom"
            end

            local user = UserService.get(userID)
            if not user or not Privileges.hasPrivileges(user.privileges, 2) then
                return false, "Insufficient privileges"
            end

            table.insert(chatroom.bannedUsers, targetUserID)
            chatroom:removeUser(targetUserID)
            return true, "User banned from chatroom"
        end,

        --- Adds a message to the chatroom.
        ---@param chatroomID string
        ---@param message ChatMessage
        ---@return boolean
        ---@return string
        addMessage = function(chatroomID, channelID, message)
            message.timestamp = os.time() -- use server time for consistency
            local chatroom = ChatroomService.getChatroom(chatroomID)

            if not chatroom then
                return false, "Chatroom not found"
            end

            if not chatroom:isUserInChatroom(message.from) then
                return false, "User not in chatroom"
            end

            local user = UserService.get(message.from)
            if not user then
                return false, "User not found"
            end

            local channel = chatroom.channels:get(channelID)

            if not channel then
                return false, "Channel not found"
            end

            channel:addMessage(message)

            local messageUpdate = Message.newMessage(nil,
                {
                    type = "message",
                    chatroomID = chatroomID,
                    message = message
                }, nil, nil)

            if not messageUpdate then
                return false, "Failed to create message update"
            end

            messageUpdate:send(Event.peer)

            return true, "Message added successfully"
        end,
    },
    {

    },
    "chatroom"
}
