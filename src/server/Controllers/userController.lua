return
{
    { -- endpoints
        create = function(username, password)
            if not username or not password then
                return false, "Username and password are required"
            end

            if #username < 3 or #username > 80 then
                return false, "Username must be between 3 and 80 characters"
            end

            if UserService.getByName(username) then
                return false, "User already exists"
            end

            local user = User.newUser(nil, username, password)

            UserService.addUser(user)

            return true, user
        end,

        login = function(username, password)
            if not username or not password then
                return false, "Username and password are required"
            end

            local user = UserService.getByName(username)
            if not user then
                return false, "User not found"
            end

            if user.password ~= password then
                return false, "Invalid password"
            end

            return true, user
        end,

        get = function(id)
            local user = UserService.get(id)
            return user ~= nil, user or "User not found"
        end,

        getByUsername = function(username)
            local user = UserService.getByName(username)
            return user ~= nil, user or "User not found"
        end,

        getAll = function()
            return true, UserService.getAll()
        end,

        update = function(id, data)
            local user = UserService.get(id)
            if not user then
                return false, "User not found"
            end

            for key, value in pairs(data) do
                if key ~= "id" then
                    user[key] = value
                end
            end

            return true
        end,

        delete = function(id)
            for i, peer in ipairs(Connection.peers) do
                if peer.id == id then
                    table.remove(Connection.peers, i)
                    return true
                end
            end
            return false
        end,

        getChatrooms = function(id)
            local user = UserService.get(id)
            if not user then
                return false, "User not found"
            end

            return true, user.chatrooms
        end,

        requestFriend = function(userID, friendUsername)
            local user = UserService.get(userID)
            if not user then
                return false, "User not found"
            end

            local friend = UserService.getByName(friendUsername)
            if not friend then
                return false, "Friend not found"
            end

            if user.id == friend.id then
                return false, "Cannot add yourself as a friend"
            end

            for _, f in ipairs(user.friends) do
                if f == friend.id then
                    return false, "Already friends"
                end
            end

            table.insert(user.friends, friend.id)
            table.insert(friend.friends, user.id)

            return true
        end,

        getFriends = function(id)
            local user = UserService.get(id)
            if not user then
                return false, "User not found"
            end

            return true, user.friends
        end,

        removeFriend = function(userID, friendID)
            local user = UserService.get(userID)
            if not user then
                return false, "User not found"
            end

            local friend = UserService.get(friendID)
            if not friend then
                return false, "Friend not found"
            end

            local removed = false

            for i, f in ipairs(user.friends) do
                if f == friend.id then
                    table.remove(user.friends, i)
                    removed = true
                    break
                end
            end

            for i, f in ipairs(friend.friends) do
                if f == user.id then
                    table.remove(friend.friends, i)
                    break
                end
            end

            if not removed then
                return false, "Not friends"
            end

            return true
        end,
    },
    { -- autorization
        delete = function(userID, id)
            -- only the owner of an account can delete it
            return userID == id
        end,
        update = function(userID, id)
            -- only the owner of an account can update it
            return userID == id
        end,
        getAll = function(userID)
            -- only admins can get all users
            local user = UserService.get(userID)
            if user and user.privileges >= 3 then
                return true
            end
            return false, "Insufficient privileges"
        end,
    }, -- path
    "user"
}
