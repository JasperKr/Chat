package.path = package.path .. ";" .. love.filesystem.getSourceBaseDirectory() .. "/shared/?.lua"
require("init")

Connection = {
    host = Enet.host_create(),
}

Connection.server = Connection.host:connect("127.0.0.1:5111")

---@param file love.DroppedFile
function love.filedropped(file)

end

local flags = bit.bor(
    Imgui.ImGuiWindowFlags_NoTitleBar,
    Imgui.ImGuiWindowFlags_NoResize,
    Imgui.ImGuiWindowFlags_NoCollapse,
    Imgui.ImGuiWindowFlags_NoMove,
    Imgui.ImGuiWindowFlags_NoSavedSettings,
    Imgui.ImGuiWindowFlags_NoScrollbar
)

local maxUserInputLength = 4096
local maxUsernameLength = 80
local maxPasswordLength = 128

---@param text string
function CountNewLines(text)
    local _, count = text:gsub("\n", "")
    return count
end

GUIState = {
    justSentMessage = false,
    hasKeyboardFocus = false,
    anyKeypressed = false,
    hoveredChatWindow = false,

    loginPageOpen = false,
    registerPageOpen = false,
    settingsPageOpen = false,

    userInput = ffi.new("char[?]", maxUserInputLength),
    currentChatroom = nil, ---@type Chatroom|nil
    loginUsername = ffi.new("char[?]", maxUsernameLength),
    loginPassword = ffi.new("char[?]", maxPasswordLength),
}

local pendingChatroomRequests = {}
local chatrooms = {}
local user
local contentRegionAvailable = ffi.new("ImVec2", 0, 0)

local function login(username, password)
    Request.request(
        "user.login",
        {
            username,
            password
        },
        nil,
        function(...)
            local status, userOrError = ...
            if not status then
                print("Login failed:", userOrError)
                GUIState.loginPageOpen = true
                GUIState.registerPageOpen = false
                return
            end

            status, user = User.loadUser(userOrError)

            if not status or type(user) ~= "table" then
                print("Failed to load user:", user)
                GUIState.loginPageOpen = true
                GUIState.registerPageOpen = false
                user = nil
                return
            end

            GUIState.loginPageOpen = false
            GUIState.registerPageOpen = false

            print("User loaded:", user.id)
        end,
        nil,
        "post"
    )
end

local function loginFromLastLogin()
    GUIState.registerPageOpen = false
    if love.filesystem.getInfo("lastLogin.txt") then
        local data = love.filesystem.read("lastLogin.txt")
        local loginData = Buffer.decode(data)

        if type(loginData) == "table" and loginData.username and loginData.password then
            login(loginData.username, loginData.password)
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
            Imgui.Text("Username: " .. user.name)
            Imgui.SetItemTooltip("ID: " .. user.id)

            if Imgui.Button("Logout") then
                user = nil
                GUIState.currentChatroom = nil
                GUIState.loginPageOpen = true
                GUIState.registerPageOpen = false
            end

            Imgui.Separator()

            if Imgui.Button("Settings") then
                GUIState.settingsPageOpen = true
            end

            Imgui.End()
        end

        local room = GUIState.currentChatroom
        if Imgui.Begin("Chat") and GUIState.currentChatroom and room then
            Imgui.Text(GUIState.currentChatroom.name)
            Imgui.Separator()

            ---TODO: dynamically load messages

            table.sort(room.messages, function(a, b)
                return a.timestamp < b.timestamp
            end)

            Imgui.GetContentRegionAvail(contentRegionAvailable)

            -- local textLineHeight = Imgui.GetTextLineHeight()

            for i, message in ipairs(room.messages) do
                -- local messageHeight = textLineHeight * (message.newLineCount + 2) + 8
                Imgui.BeginGroup()
                Imgui.Text(message.fromName)
                Imgui.SameLine()
                Imgui.TextDisabled(os.date("%H:%M:%S", message.timestamp))
                Imgui.Text(message.text)
                Imgui.EndGroup()
            end

            GUIState.hoveredChatWindow = Imgui.IsWindowHovered()
        end
        Imgui.End()

        if GUIState.overedChatWindow and not GUIState.hasKeyboardFocus and GUIState.anyKeypressed then
            print("Setting keyboard focus to message box")
            Imgui.SetNextWindowFocus()
        end

        if Imgui.Begin("Message Box") and GUIState.currentChatroom then
            if GUIState.justSentMessage or (GUIState.hoveredChatWindow and not GUIState.hasKeyboardFocus and GUIState.anyKeypressed) then
                Imgui.SetKeyboardFocusHere(); GUIState.justSentMessage = false
            end
            local textLineHeight = Imgui.GetTextLineHeight()

            local lines = CountNewLines(ffi.string(GUIState.userInput)) + 2
            local size = ffi.new("ImVec2", -1, textLineHeight * lines + 8)

            if Imgui.InputTextMultiline("##MessageInput", GUIState.userInput, maxUserInputLength, size,
                    bit.bor(Imgui.ImGuiInputTextFlags_EnterReturnsTrue, Imgui.ImGuiInputTextFlags_CtrlEnterForNewLine, Imgui.ImGuiInputTextFlags_CharsNoBlank)) then
                local message = ffi.string(GUIState.userInput)
                ffi.fill(GUIState.userInput, maxUserInputLength)

                GUIState.justSentMessage = true

                Request.request(
                    "chatroom.addMessage",
                    {
                        GUIState.currentChatroom.id,
                        ChatMessage.newChatMessage(message, user.id, user.name)
                    },
                    user.id,
                    nil,
                    nil,
                    "post"
                )
            end

            GUIState.hasKeyboardFocus = Imgui.IsItemActive()
        end
        Imgui.End()

        if Imgui.Begin("Chat rooms") then
            for _, chatroom in ipairs(chatrooms) do
                if Imgui.Selectable_Bool(chatroom.name, false, Imgui.ImGuiSelectableFlags_AllowDoubleClick) then
                    GUIState.currentChatroom = chatroom

                    Request.request(
                        "chatroom.getMessages",
                        {
                            chatroom.id,
                            1,
                            100
                        },
                        user.id,
                        function(success, messages)
                            if not success then
                                print("Failed to load messages for chatroom:", chatroom.id)
                                return
                            end

                            chatroom.messages = messages or {}

                            table.sort(chatroom.messages, function(a, b)
                                return a.timestamp < b.timestamp
                            end)

                            print("Loaded " .. #chatroom.messages .. " messages for chatroom: " .. chatroom.id)
                        end,
                        nil,
                        "get"
                    )
                end
            end
        end
        Imgui.End()
    end

    Imgui.End()
    GUIState.anyKeypressed = false
end

local function loginPage()
    Imgui.SetNextWindowSize(ffi.new("ImVec2", 400, 300))
    Imgui.SetNextWindowPos(ffi.new("ImVec2", (love.graphics.getWidth() - 400) / 2, (love.graphics.getHeight() - 300) / 2))

    if Imgui.Begin("Login", nil, bit.bor(Imgui.ImGuiWindowFlags_NoResize, Imgui.ImGuiWindowFlags_NoMove, Imgui.ImGuiWindowFlags_NoCollapse)) then
        Imgui.Text("Username:")
        Imgui.InputText("##Username", GUIState.loginUsername, maxUsernameLength, Imgui.ImGuiInputTextFlags_CharsNoBlank)

        Imgui.Text("Password:")
        Imgui.InputText("##Password", GUIState.loginPassword, maxPasswordLength,
            bit.bor(Imgui.ImGuiInputTextFlags_Password, Imgui.ImGuiInputTextFlags_CharsNoBlank))

        if Imgui.Button("Login") then
            local username = ffi.string(GUIState.loginUsername)
            local password = ffi.string(GUIState.loginPassword)

            if username == "" or password == "" then
                print("Username and password cannot be empty")
                Imgui.End()
                return
            end

            -- username must be at least 3 characters and at most 80 characters
            if #username < 3 or #username > maxUsernameLength then
                print("Username must be between 3 and " .. maxUsernameLength .. " characters")
                Imgui.End()
                return
            end

            -- password must be at least 6 characters and at most 128 characters
            if #password < 6 or #password > maxPasswordLength then
                print("Password must be between 6 and " .. maxPasswordLength .. " characters")
                Imgui.End()
                return
            end

            password = love.data.hash("string", "sha256", password)

            love.filesystem.write("lastLogin.txt", Buffer.encode({
                username = username,
                password = password
            }))

            login(username, password)

            GUIState.currentChatroom = nil -- Reset to global chat after login
        end

        Imgui.Separator()
        Imgui.Text("Don't have an account?");

        if Imgui.Button("Register") then
            -- Switch to register page
            GUIState.loginUsername = ffi.new("char[?]", maxUsernameLength)
            GUIState.loginPassword = ffi.new("char[?]", maxPasswordLength)

            GUIState.loginPageOpen = false
            GUIState.registerPageOpen = true
        end
    end
    Imgui.End()
end

local function registerPage()
    Imgui.SetNextWindowSize(ffi.new("ImVec2", 400, 300))
    Imgui.SetNextWindowPos(ffi.new("ImVec2", (love.graphics.getWidth() - 400) / 2, (love.graphics.getHeight() - 300) / 2))

    if Imgui.Begin("Register", nil, bit.bor(Imgui.ImGuiWindowFlags_NoResize, Imgui.ImGuiWindowFlags_NoMove, Imgui.ImGuiWindowFlags_NoCollapse)) then
        Imgui.Text("Username:")
        Imgui.InputText("##Username", GUIState.loginUsername, maxUsernameLength, Imgui.ImGuiInputTextFlags_CharsNoBlank)

        Imgui.Text("Password:")
        Imgui.InputText("##Password", GUIState.loginPassword, maxPasswordLength,
            bit.bor(Imgui.ImGuiInputTextFlags_Password, Imgui.ImGuiInputTextFlags_CharsNoBlank))

        if Imgui.Button("Register") then
            local username = ffi.string(GUIState.loginUsername)
            local password = ffi.string(GUIState.loginPassword)

            if username == "" or password == "" then
                print("Username and password cannot be empty")
                Imgui.End()
                return
            end

            -- username must be at least 3 characters and at most 80 characters
            if #username < 3 or #username > maxUsernameLength then
                print("Username must be between 3 and " .. maxUsernameLength .. " characters")
                Imgui.End()
                return
            end

            -- password must be at least 6 characters and at most 128 characters
            if #password < 6 or #password > maxPasswordLength then
                print("Password must be between 6 and " .. maxPasswordLength .. " characters")
                Imgui.End()
                return
            end

            password = love.data.hash("string", "sha256", password)

            local success, errmsg = Request.request(
                "user.create",
                {
                    username,
                    password
                },
                nil,
                function(...)
                    local success, userOrError = ...
                    if not success then
                        print("Registration failed:", userOrError)
                        return
                    end

                    success, user = User.loadUser(userOrError)
                    print("User loaded:", user.id)

                    if not success or type(user) ~= "table" then
                        print("Failed to load user:", user)
                        return
                    end

                    GUIState.currentChatroom = nil -- Reset to global chat after registration
                    GUIState.loginPageOpen = false
                    GUIState.registerPageOpen = false

                    Request.request(
                        "chatroom.join",
                        {
                            user.id,
                            "GLOBAL_CHAT_ID__" -- Join the global chatroom after registration
                        },
                        user.id,
                        function(success, errmsg)
                            if not success then
                                print("Failed to join global chatroom:", errmsg)
                                return
                            end

                            user:refresh()
                        end
                    )
                end,
                nil,
                "post"
            )

            if not success then
                print("Registration failed:", errmsg)
                Imgui.End()
                return
            end
        end

        Imgui.Separator()
        Imgui.Text("Already have an account?");

        if Imgui.Button("Login") then
            -- Switch to login page
            GUIState.loginUsername = ffi.new("char[?]", maxUsernameLength)
            GUIState.loginPassword = ffi.new("char[?]", maxPasswordLength)

            GUIState.loginPageOpen = true
            GUIState.registerPageOpen = false
        end
    end
    Imgui.End()
end

local function settingsPage()
    Imgui.SetNextWindowSize(ffi.new("ImVec2", love.graphics.getDimensions()))
    Imgui.SetNextWindowPos(ffi.new("ImVec2", 0, 0))

    if Imgui.Begin("Settings", nil, bit.bor(Imgui.ImGuiWindowFlags_NoResize, Imgui.ImGuiWindowFlags_NoMove, Imgui.ImGuiWindowFlags_NoCollapse)) then
        if Imgui.Button("Close") then
            GUIState.settingsPageOpen = false
        end

        Imgui.Separator()

        Imgui.ShowStyleEditor()
    end
    Imgui.End()
end

local function fetchChatrooms()
    for i, chatroom in ipairs(user.chatrooms) do
        local roomLoaded = false
        for j, room in ipairs(chatrooms) do
            if room.id == chatroom then
                roomLoaded = true
                break
            end
        end

        if pendingChatroomRequests[chatroom] then
            -- If a request is already pending, skip loading this chatroom
            roomLoaded = true
        end

        if not roomLoaded then
            pendingChatroomRequests[chatroom] = true
            print("Requesting chatroom:", chatroom)

            local success, errmsg = Request.request(
                "chatroom.get",
                { chatroom },
                user.id,
                function(success, chatroomData)
                    print("Received chatroom data:", chatroomData)
                    pendingChatroomRequests[chatroomData.id] = nil
                    if not success then
                        print("Failed to get chatroom:", chatroomData)
                        return
                    end

                    table.insert(chatrooms,
                        Chatroom.newChatroom(chatroomData.name, chatroomData.id, chatroomData.ownerID))
                end,
                nil,
                "get"
            )

            if not success then
                print("Request failed:", errmsg)
            else
                print("Chatroom request sent successfully")
            end
        end
    end
end

local onReceive = {
    ["message"] = function(content)
        if GUIState.currentChatroom and GUIState.currentChatroom.id == content.chatroomID then
            -- If the current chatroom is the one receiving the message, add it to the chatroom's messages
            GUIState.currentChatroom:addMessage(content.message)
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
    if not Connection.host then return end
    if not Connection.server then return end

    local event = Connection.host:service()

    while event do
        if event.type == "connect" then
            print("Connected to server")
            loginFromLastLogin()
        elseif event.type == "disconnect" then
            print("Disconnected from server")
        elseif event.type == "receive" then
            local message = event.data
            print("Received message from server")
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

    if user then
        fetchChatrooms()
    end
end

function love.draw()
    Imgui.love.Update(love.timer.getDelta())
    Imgui.NewFrame()

    if GUIState.loginPageOpen and GUIState.registerPageOpen then
        GUIState.registerPageOpen = false
    end

    if GUIState.loginPageOpen then
        loginPage()
    elseif GUIState.registerPageOpen then
        registerPage()
    elseif user then
        if GUIState.settingsPageOpen then
            settingsPage()
        else
            drawApp()
        end
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
    if Connection.server then
        Connection.server:disconnect_now()
    end
    Connection.host:destroy()
    Imgui.love.Shutdown()
    print("Application closed")
end
