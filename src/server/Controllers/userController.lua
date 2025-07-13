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

        getAll = function()
            return true, UserService.getAll()
        end,

        update = function(id, data)
            local user = UserService.get(id)
            if not user then
                return false, "User not found"
            end

            for key, value in pairs(data) do
                if key ~= "id" and user[key] ~= nil then
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
