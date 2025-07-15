package.path = package.path .. ";" .. love.filesystem.getSourceBaseDirectory() .. "/shared/?.lua"

require("init")
require("Windows.chat")
require("Windows.login")
require("Windows.connect")
require("Windows.chatrooms")
require("Windows.register")
require("Windows.channels")

require("Windows.Settings.profile")

Attachments = require("attachments")
Shutdown = false

Connection = {
    connected = false,
}

local flags = bit.bor(
    Imgui.ImGuiWindowFlags_NoTitleBar,
    Imgui.ImGuiWindowFlags_NoResize,
    Imgui.ImGuiWindowFlags_NoCollapse,
    Imgui.ImGuiWindowFlags_NoMove,
    Imgui.ImGuiWindowFlags_NoSavedSettings,
    Imgui.ImGuiWindowFlags_NoScrollbar
)

function SmoothStep(a, b, t)
    t = t * t * (3 - 2 * t) -- smoothstep
    return a + (b - a) * t
end

---@param text string
function CountNewLines(text)
    local _, count = text:gsub("\n", "")
    return count
end

local maxUserInputLength = 4096
local maxUsernameLength = 80
local maxPasswordLength = 128

GUIState = {
    justSentMessage = false,
    hasKeyboardFocus = false,
    anyKeypressed = false,
    hoveredChatWindow = false,

    loginPageOpen = false,
    registerPageOpen = false,
    settingsPageOpen = false,

    currentChatroom = nil, ---@type Chatroom|nil
    currentChannel = nil, ---@type Channel|nil
    selectedChannelPerChatroom = {}, -- Stores selected channel for each chatroom

    userInput = ffi.new("char[?]", maxUserInputLength),
    loginUsername = ffi.new("char[?]", maxUsernameLength),
    loginPassword = ffi.new("char[?]", maxPasswordLength),

    selectedSettingsPage = 1,                       -- Index of the currently selected settings page
    profilePictureSize = ffi.new("ImVec2", 32, 32), -- Size for profile picture display

    attachments = {},                               -- List of attachments for the current message
    scrollToBottom = false,                         -- Flag to scroll to the bottom of the chat window
    scrollStarted = false,
    scrollStartY = 0,                               -- Starting Y position for scrolling
    scrollMaxY = 0,                                 -- Maximum Y position for scrolling
    scrollI = 0,                                    -- Scroll index for smooth scrolling

    maxUserInputLength = maxUserInputLength,
    maxUsernameLength = maxUsernameLength,
    maxPasswordLength = maxPasswordLength
}

Cache = {
    users = {},     --- @type { [ID]: User }
    chatrooms = {}, --- @type Chatroom[]
}

function SmoothScrollToTop()
    if not GUIState.scrollToBottom then
        return
    end

    if not GUIState.scrollStarted then
        GUIState.scrollStarted = true
        GUIState.scrollStartY = Imgui.GetScrollY()
        GUIState.scrollMaxY = Imgui.GetScrollMaxY()
    end

    GUIState.scrollI = GUIState.scrollI + love.timer.getDelta() * 2 -- 0.5 sec

    if GUIState.scrollI > 1 then
        GUIState.scrollI = 1
        GUIState.scrollToBottom = false -- Stop scrolling when we reach the top
        GUIState.scrollStarted = false
    end

    Imgui.SetScrollY(SmoothStep(GUIState.scrollStartY, GUIState.scrollMaxY, GUIState.scrollI))
end

local function loginFromLastLogin()
    GUIState.registerPageOpen = false
    if love.filesystem.getInfo("lastLogin.txt") then
        local data = love.filesystem.read("lastLogin.txt")
        local loginData = Buffer.decode(data)

        if type(loginData) == "table" and loginData.username and loginData.password then
            LoginWith(loginData.username, loginData.password)
            print("Attempting to login with last login data:", loginData.username)
        else
            GUIState.loginPageOpen = true
            print("Invalid last login data")
        end
    else
        GUIState.loginPageOpen = true
    end
end

local function drawApp()
    Imgui.SetNextWindowSize(ffi.new("ImVec2", love.graphics.getDimensions()))
    Imgui.SetNextWindowPos(ffi.new("ImVec2", 0, 0))

    if Imgui.Begin("App", nil, flags) then
        Imgui.SetCursorScreenPos(ffi.new("ImVec2", 0, 0))
        Imgui.DockSpace(1, ffi.new("ImVec2", love.graphics.getDimensions()),
            bit.bor(
                Imgui.ImGuiDockNodeFlags_AutoHideTabBar
            )
        )

        if Imgui.Begin("Profile & Settings") then
            Imgui.Text("Username: " .. CurrentUser.name)
            Imgui.SetItemTooltip("ID: " .. CurrentUser.id)

            if Imgui.Button("Logout") then
                CurrentUser = nil

                GUIState.currentChatroom = nil
                GUIState.loginPageOpen = true
                GUIState.registerPageOpen = false

                love.filesystem.remove("lastLogin.txt")
            end

            Imgui.SameLine()

            if Imgui.Button("Settings") then
                GUIState.settingsPageOpen = true
            end

            Imgui.End()
        end

        if CurrentUser == nil then
            Imgui.End()
            return
        end

        DrawChannels()

        DrawChat()

        DrawChatRoom()
    end

    Imgui.End()
    GUIState.anyKeypressed = false
end

---@param file love.DroppedFile
function love.filedropped(file)
    local filename = file:getFilename()
    local extension = Stringh.extension(filename)

    if extension == ".png" or extension == ".jpg" or extension == ".jpeg" or extension == ".bmp" or extension == ".dds" then
        local attachment = Attachments.newChatMessageAttachment(file:read("data"), "texture")

        table.insert(GUIState.attachments, attachment)
    end
end

local settingsPages = {
    { name = "Theme",         draw = Imgui.ShowStyleEditor },
    { name = "Profile",       draw = DrawProfileSettings },
    { name = "Privacy",       draw = function() Imgui.Text("Privacy settings go here") end },
    { name = "Notifications", draw = function() Imgui.Text("Notification settings go here") end },
}

local function settingsPage()
    Imgui.SetNextWindowSize(ffi.new("ImVec2", love.graphics.getDimensions()))
    Imgui.SetNextWindowPos(ffi.new("ImVec2", 0, 0))

    if Imgui.Begin("App", nil, flags) then
        Imgui.SetCursorScreenPos(ffi.new("ImVec2", 0, 0))
        Imgui.DockSpace(1, ffi.new("ImVec2", love.graphics.getDimensions()),
            bit.bor(
                Imgui.ImGuiDockNodeFlags_AutoHideTabBar
            )
        )

        if Imgui.Begin("Settings") then
            if Imgui.Button("Close") then
                GUIState.settingsPageOpen = false
            end

            Imgui.Separator()

            settingsPages[GUIState.selectedSettingsPage].draw()
        end
        Imgui.End()

        if Imgui.Begin("Settings Select") then
            for i, page in ipairs(settingsPages) do
                if Imgui.Selectable_Bool(page.name, GUIState.selectedSettingsPage == i) then
                    GUIState.selectedSettingsPage = i
                end
            end

            Imgui.End()
        end
    end
    Imgui.End()
end

local function printTable(data, depth)
    if type(data) == "table" then
        depth = depth or 0
        local indent = string.rep("  ", depth)
        for k, v in pairs(data) do
            if type(v) == "table" then
                print(indent .. tostring(k) .. ":")
                printTable(v, depth + 1)
            else
                print(indent .. tostring(k) .. ": " .. tostring(v))
            end
        end
    else
        print(tostring(data))
    end
end

local function fetchChatrooms()
    for i, chatroom in ipairs(CurrentUser.chatrooms) do
        local roomLoaded = false
        for j, room in ipairs(Cache.chatrooms) do
            if room.id == chatroom then
                roomLoaded = true
                break
            end
        end

        if not roomLoaded then
            Request.request(
                "chatroom.get",
                { chatroom },
                CurrentUser.id,
                function(success, chatroomData)
                    if not success then
                        print("Failed to get chatroom:", chatroomData)
                        return
                    end

                    local room = Chatroom.loadChatroom(chatroomData)

                    table.insert(Cache.chatrooms, room)

                    Request.request(
                        "channel.getAll",
                        { room.id },
                        CurrentUser.id,
                        function(success, channels)
                            if not success then
                                print("Failed to get channels for chatroom:", room.id, channels)
                            else
                                for _, channel in ipairs(channels) do
                                    room.channels:add(Channel.loadChannel(channel))
                                end
                            end
                        end,
                        nil,
                        "get"
                    )
                end,
                nil,
                "get",
                "once",
                chatroom
            )
        end
    end
end

local onReceive = {
    ["message"] = function(content)
        if GUIState.currentChannel and GUIState.currentChatroom.id == content.chatroomID then
            -- If the current chatroom is the one receiving the message, add it to the chatroom's messages
            GUIState.currentChannel:addMessage(content.message)
        end
    end,
    ["requestReply"] = function(content)
        local reply = content.reply
        if reply then
            Request.replies[content.id] = reply
        end
    end
}

function love.update(dt)
    if Shutdown then return end
    if not Connection.host then return end
    if not Connection.server then return end
    if not Connection.connected then return end

    local event = Connection.host:service()

    while event do
        if event.type == "connect" then
            print("Invalid connection event received")
        elseif event.type == "disconnect" then
            print("Disconnected from server")

            CurrentUser = nil
            GUIState.currentChatroom = nil
            GUIState.currentChannel = nil

            Connection.server = nil
            Connection.connected = false
            Connection.host:destroy()

            return
        elseif event.type == "receive" then
            local message = event.data
            local success, decodedMessage = Message.decodeMessage(message)

            if not success then
                print("Failed to decode message: " .. decodedMessage)
            else
                if onReceive[decodedMessage.content.type] then
                    local handler = onReceive[decodedMessage.content.type]
                    local success, result = pcall(handler, decodedMessage.content)
                    if not success then
                        print("Error in message handler:", result)
                    end
                else
                    print("Unknown message type:", decodedMessage.content.type)
                end
            end
        end

        event = Connection.host:service()
    end

    if CurrentUser then
        fetchChatrooms()
    end
end

function love.draw()
    if Shutdown then return end
    Imgui.love.Update(love.timer.getDelta())
    Imgui.NewFrame()

    if GUIState.loginPageOpen and GUIState.registerPageOpen then
        GUIState.registerPageOpen = false
    end

    if Connection.connected then
        if GUIState.loginPageOpen then
            DrawLoginPage()
        elseif GUIState.registerPageOpen then
            DrawRegisterPage()
        elseif CurrentUser then
            if GUIState.settingsPageOpen then
                settingsPage()
            else
                drawApp()
            end
        end
    else
        DrawConnectPage(loginFromLastLogin)
    end

    Request.updateRequests()

    Imgui.Render()
    Imgui.love.RenderDrawLists()
end

love.keyboard.setTextInput(true)

function love.textinput(text)
    Imgui.love.TextInput(text)
end

function love.resize()
end

function love.mousepressed(x, y, button)
    Imgui.love.MousePressed(button)
end

function love.keypressed(key, scancode, isrepeat)
    Imgui.love.KeyPressed(key)
    GUIState.anyKeypressed = true
end

function love.keyreleased(key)
    Imgui.love.KeyReleased(key)
end

function love.mousereleased(x, y, button)
    Imgui.love.MouseReleased(button)
end

function love.mousemoved(x, y, dx, dy)
    Imgui.love.MouseMoved(x, y)
end

function love.wheelmoved(x, y)
    Imgui.love.WheelMoved(x, y)
end

function love.quit()
    Connection.connected = false
    Shutdown = true
    if Connection.server then
        Connection.server:disconnect_now()
    end
    Connection.host:destroy()
    -- Imgui.love.Shutdown() -- Sometimes errors due to event after shutdown
    return false
end
