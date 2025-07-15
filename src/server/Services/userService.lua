UserService = {
    users = Tables.newIdIndexedTable(),

    ---@return User|nil
    get = function(userID)
        return UserService.users:get(userID)
    end,

    addUser = function(user)
        UserService.users:add(user)
    end,

    setPrivilege = function(userID, privilege)
        local user = UserService.get(userID)
        if user then
            user.privileges = privilege
            return true
        end
        return false
    end,

    getAll = function(userID)
        if not userID then
            return nil, "User not provided"
        end

        local user = UserService.get(userID)

        if not user then
            return nil, "User not found"
        end

        local privileges = user.privileges

        if Privileges.hasPrivileges(privileges, 3) then
            return UserService.users.items
        end

        return nil, "Insufficient privileges"
    end,

    removeUser = function(userID)
        return UserService.users:remove(userID)
    end,

    getByName = function(name)
        for _, user in pairs(UserService.users.items) do
            if user.name == name then
                return user
            end
        end
        return nil, "User not found"
    end,

    save = function()
        -- save users
        love.filesystem.createDirectory("users")
        for _, user in ipairs(UserService.users.items) do
            local fileName = "users/" .. user.id .. ".bin"
            love.filesystem.write(fileName, Buffer.encode(user))
        end
    end,

    load = function()
        -- load users
        local files = love.filesystem.getDirectoryItems("users")
        for _, file in ipairs(files) do
            if file:match("%.bin$") then
                local userData = love.filesystem.read("users/" .. file)
                if userData then
                    local user = Buffer.decode(userData)
                    if user and type(user) == "table" then
                        local loadedUser, u = User.loadUser(user)
                        if loadedUser then
                            UserService.addUser(u)
                        else
                            print("Failed to load user: " .. u)
                        end
                    else
                        print("Failed to decode user from file: " .. file)
                    end
                end
            end
        end
    end,
}
UserService.load()
