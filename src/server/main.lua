SERVER = true
package.path = package.path .. ";src/shared/?.lua"

require("init")

require("Services.userService")
require("Services.chatroomService")

---@type {[1]: {[1]:{string: function}, [2]: {string: function}, [3]: string}} Endpoints, Authorization, Path
Controllers = {}

local function addController(info)
    local endpoints, authorization, path = unpack(info)

    if not Controllers[path] then
        Controllers[path] = { endpoints, authorization }
    else
        print("Controller for path '" .. path .. "' already exists.")
    end
end

addController(require("Controllers.userController"))
addController(require("Controllers.chatroomController"))

Connection = {
    host = Enet.host_create("127.0.0.1:5111"),
    peers = {}
}

Chatrooms = {}

local function addPeer(peer)
    table.insert(Connection.peers, peer)
end

local function removePeer(peer)
    for i, p in ipairs(Connection.peers) do
        if p == peer then
            table.remove(Connection.peers, i)
            return true
        end
    end

    return false
end

--- Handle a controller request
---@param content table
local function handleControllerRequest(content)
    local path = content.path ---@type string for example "user.getAll"

    local keys = {}
    for key in string.gmatch(path, "[^.]+") do table.insert(keys, key) end

    local controller = Controllers[keys[1]]
    if controller then
        local method = controller[1][keys[2]]
        local autorization = controller[2][keys[2]]

        if autorization then
            local userID = content.userID
            if not userID or not autorization(userID, unpack(content.args or {})) then
                print("Unauthorized access to method: " .. keys[2])
                return false, "Unauthorized"
            end
        end

        if method then
            local ret = { method(unpack(content.args or {})) }

            if type(ret[1]) ~= "boolean" then
                print("Method  [" .. path .. "] did not return a boolean as the first value")
                return false, "Invalid method return"
            end

            local success = ret[1] ---@type boolean
            if not success then
                print("Error in method " .. keys[2] .. ": " .. tostring(ret[2]))
                return ret
            end

            return ret
        else
            print("Method not found: " .. keys[2])
        end
    else
        print("Controller not found: " .. keys[1])
    end
end

function love.update()
    Event = Connection.host:service()

    while Event do
        if Event.type == "connect" then
            print("Connected to server")
            addPeer(Event.peer)
        elseif Event.type == "disconnect" then
            print("Disconnected from server")
            removePeer(Event.peer)
        elseif Event.type == "receive" then
            local message = Event.data
            local success, decodedMessage = Message.decodeMessage(message)

            if not success or type(decodedMessage) == "string" then
                print("Failed to decode message: " .. decodedMessage)
            else
                local content = decodedMessage:getContent()
                if decodedMessage:getDataType() == "table" and type(content) == "table" then
                    print(decodedMessage:getFrom() .. " -> " .. content.path, unpack(content.args or {}))

                    -- check for non-list args

                    local count = 0
                    local hadError = false
                    for key, value in pairs(content.args or {}) do
                        if type(key) ~= "number" then
                            print("Invalid Key: '" .. tostring(key) .. "' in args, expected a list")
                            hadError = true
                        end
                        count = count + 1
                    end

                    if not hadError and #(content.args or {}) ~= count then
                        print("Invalid args: expected a list, got a table with " .. count .. " items")
                    end

                    local reply = handleControllerRequest(content)
                    if reply then
                        local replyMessage = Message.newMessage(nil,
                            { id = decodedMessage:getID(), type = "requestReply", reply = reply },
                            decodedMessage:getFrom(),
                            decodedMessage:getTo())

                        if not replyMessage then
                            print("Failed to create reply message")
                        else
                            replyMessage:send(Event.peer)
                        end
                    else
                        print("Failed to handle controller request")
                    end
                end
            end
        end

        Event = Connection.host:service()
    end
end

function love.quit()
    for _, peer in ipairs(Connection.peers) do
        peer:disconnect_now()
    end

    Connection.host:destroy()

    -- save chatrooms

    love.filesystem.createDirectory("chatrooms")
    for _, chatroom in ipairs(Chatrooms) do
        local fileName = "chatrooms/" .. chatroom.id .. ".bin"
        love.filesystem.write(fileName, Buffer.encode(chatroom))
    end

    -- save users

    love.filesystem.createDirectory("users")
    UserService.save()
    ChatroomService.save()
end
