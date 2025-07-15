local userMetatable = {}

---@class User
---@field id string
---@field name string
---@field status "online" | "offline" | "away"
---@field lastActive number
---@field chatrooms ID[]
---@field friends ID[]
---@field blockedUsers ID[]
---@field privileges number -- Server side only
---@field profilePicture love.ImageData | love.CompressedImageData | nil
---@field profilePictureTexture love.Texture | nil -- Client side only
---@field customStatus string | nil
---@field customStatusExpires number | nil -- Timestamp when the custom status expires
local userFunctions = {}
userMetatable.__index = userFunctions

---@param id ID?
---@param name string
---@param password string
---@return User
local function newUser(id, name, password)
    local user = {}
    user.id = id or ID.newID()
    user.name = name or "Unnamed User"
    user.password = password
    user.status = "offline"
    user.lastActive = os.time()
    user.chatrooms = {}
    user.friends = {}
    user.blockedUsers = {}
    user.privileges = 1              -- Server side only
    user.profilePicture = nil
    user.profilePictureTexture = nil -- Client side only
    user.customStatus = nil
    user.customStatusExpires = nil

    setmetatable(user, userMetatable)

    return user
end

--- Circularizes the profile picture to make it round.
---@param imagedata love.ImageData
local function circularizeProfilePicture(imagedata)
    local w, h = imagedata:getDimensions()
    local cw, ch = w / 2, h / 2
    local center = math.min(cw, ch) - 5

    imagedata:mapPixel(function(x, y, r, g, b, a)
        local dx = x - cw
        local dy = y - ch

        local distance = math.sqrt(dx * dx + dy * dy)

        if distance >= center then
            return r, g, b, math.min(1 - math.max(math.min((distance - center) * 0.2, 1), 0), a) -- bit of antialiasing
        end
        return r, g, b,
            a -- Keep the original pixel color
    end)
end

--- Loads a user from a table.
---@param user table
---@return boolean
---@return string | User
local function loadUser(user)
    if not user.id or not user.name or not user.password then
        return false, "Invalid user data"
    end

    -- Ensure the user has a valid status
    if not (user.status == "online" or user.status == "offline" or user.status == "away") then
        user.status = "offline"
    end

    print("Loading user:", user.id, user.name, type(user.profilePicture))
    if user.profilePicture and type(user.profilePicture) == "string" then
        if not SERVER then
            user.profilePicture = love.image.newImageData(love.data.newByteData(user.profilePicture))

            circularizeProfilePicture(user.profilePicture)
        end
    end

    setmetatable(user, userMetatable)

    return true, user
end

--- Updates the user's status.
--- @param status "online" | "offline" | "away"
--- @return boolean
function userFunctions:updateStatus(status)
    if status ~= "online" and status ~= "offline" and status ~= "away" then
        return false
    end
    self.status = status
    self.lastActive = os.time()

    return true
end

--- Adds a chatroom to the user's list of chatrooms.
--- @param chatroom Chatroom
function userFunctions:addChatroom(chatroom)
    for _, existingChatroom in ipairs(self.chatrooms) do
        if existingChatroom == chatroom.id then
            return false -- Chatroom already exists
        end
    end

    table.insert(self.chatrooms, chatroom.id)
    return true
end

--- Adds a friend to the user's list of friends.
--- @param friend User
--- @return boolean
function userFunctions:addFriend(friend)
    for _, existingFriend in ipairs(self.friends) do
        if existingFriend == friend.id then
            return false -- Friend already exists
        end
    end

    table.insert(self.friends, friend.id)
    return true
end

--- Removes a friend from the user's list of friends.
--- @param friend User
--- @return boolean
function userFunctions:removeFriend(friend)
    for i, existingFriend in ipairs(self.friends) do
        if existingFriend == friend.id then
            table.remove(self.friends, i)
            return true -- Friend removed successfully
        end
    end

    return false -- Friend not found
end

--- Blocks a user.
--- @param user User
--- @return boolean
function userFunctions:blockUser(user)
    for _, blockedUser in ipairs(self.blockedUsers) do
        if blockedUser == user.id then
            return false -- User already blocked
        end
    end

    table.insert(self.blockedUsers, user.id)
    return true
end

--- Unblocks a user.
--- @param user User
--- @return boolean
function userFunctions:unblockUser(user)
    for i, blockedUser in ipairs(self.blockedUsers) do
        if blockedUser == user.id then
            table.remove(self.blockedUsers, i)
            return true -- User unblocked successfully
        end
    end

    return false -- User not found in blocked list
end

--- Gets if a user is blocked.
--- @param user User
--- @return boolean
function userFunctions:isBlocked(user)
    for _, blockedUser in ipairs(self.blockedUsers) do
        if blockedUser == user.id then
            return true -- User is blocked
        end
    end

    return false -- User is not blocked
end

--- Gets if a user is a friend.
--- @param user User
--- @return boolean
function userFunctions:isFriend(user)
    for _, friend in ipairs(self.friends) do
        if friend == user.id then
            return true -- User is a friend
        end
    end

    return false -- User is not a friend
end

--- Sets a custom status for the user.
--- @param status string
--- @param expires number | nil -- Timestamp when the custom status expires
--- @return boolean
function userFunctions:setCustomStatus(status, expires)
    if type(status) ~= "string" or (expires and type(expires) ~= "number") then
        return false
    end

    self.customStatus = status
    self.customStatusExpires = expires or nil

    return true
end

--- Gets the user's custom status.
--- @return string | nil, number | nil -- status, expires
function userFunctions:getCustomStatus()
    if self.customStatusExpires and os.time() > self.customStatusExpires then
        self.customStatus = nil
        self.customStatusExpires = nil
    end
    return self.customStatus, self.customStatusExpires
end

--- Gets the user's profile picture.
--- @return love.ImageData | nil
function userFunctions:getProfilePicture()
    return self.profilePicture
end

--- Sets the user's profile picture.
--- @param imageData love.ImageData
--- @return boolean
function userFunctions:setProfilePicture(imageData)
    self.profilePicture = imageData
    return true
end

--- Refresh userdata from the server.
function userFunctions:refresh()
    if SERVER then return false end

    Request.request(
        "user.get",
        { self.id },
        self.id,
        function(success, user)
            if not success then
                return false, user -- user is the error message
            end

            if not user or type(user) ~= "table" then
                return false, "Invalid user data received"
            end

            -- Update the current user's data
            for key, value in pairs(user) do
                if self[key] ~= nil then
                    if key == "profilePicture" and value then
                        -- If the profile picture is provided, decode it
                        self.profilePicture = love.image.newImageData(value)

                        circularizeProfilePicture(self.profilePicture)

                        self.profilePictureTexture:release()
                    else
                        self[key] = value
                    end
                end
            end

            return true, self
        end,
        10,
        "get"
    )
end

--- Update server-side user data.
--- @return boolean, string?
function userFunctions:updateServerData()
    if SERVER then return false, "This function can only be called on the client" end

    local imageStr

    if self.profilePicture then
        if self.profilePicture:type() == "ImageData" then
            imageStr = self.profilePicture:encode("png"):getString()
        elseif self.profilePicture:type() == "CompressedImageData" then
            imageStr = self.profilePicture:getString()
        else
            print("Warning: Unsupported profile picture type:", self.profilePicture:type())
        end
    end

    local success, err = Request.request(
        "user.update",
        { self.id, {
            name = self.name,
            status = self.status,
            lastActive = self.lastActive,
            chatrooms = self.chatrooms,
            friends = self.friends,
            blockedUsers = self.blockedUsers,
            privileges = self.privileges,
            profilePicture = imageStr,
            customStatus = self.customStatus,
            customStatusExpires = self.customStatusExpires
        } },
        self.id,
        nil, -- No reply needed
        10,
        "put"
    )

    if not success then
        return false, err
    end

    return true
end

return {
    newUser = newUser,
    userMetatable = userMetatable,
    userFunctions = userFunctions,
    loadUser = loadUser,
}
