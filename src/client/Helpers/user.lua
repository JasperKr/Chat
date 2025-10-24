function GetUser(id)
    if not Cache.users[id] then
        Request.request(
            "user.get",
            { id },
            CurrentUser.id,
            function(success, userData)
                if not success then
                    print("Failed to load user data for ID:", id)
                    Cache.users[id] = User.newUser(id, "Unknown User", "-")
                    return
                end

                local success, loadedUser = User.loadUser(userData)
                if not success or type(loadedUser) ~= "table" then
                    print("Failed to load user data for ID:", id, "Error:", loadedUser)
                    return
                end

                Cache.users[id] = loadedUser
            end,
            nil,
            "get",
            "once",
            id -- use other userID as message ID to avoid multiple requests for the same user
        )
    else
        return Cache.users[id]
    end
end
