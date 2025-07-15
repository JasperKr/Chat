local function validateChatroomName(name)
    if type(name) ~= "string" then
        return false, "Chatroom name must be a string."
    end

    if #name < 3 or #name > 50 then
        return false, "Chatroom name must be between 3 and 50 characters."
    end

    -- filter any escaped characters, newline, or tab characters, but allow " and '
    if name:match("[\n\r\t]") then
        return false, "Chatroom name cannot contain newlines or tabs."
    end

    return true
end

function DrawChatRoom()
    if Imgui.Begin("Chat rooms") then
        if Imgui.Button("Create Chat Room") then
            GUIState.createChatRoomWindowOpen = true
        end

        Imgui.Separator()

        if not Cache.chatrooms or #Cache.chatrooms == 0 then
            Imgui.Text("Loading chatrooms...")
            Cache.chatrooms = Cache.chatrooms or {}
        end

        table.sort(Cache.chatrooms, function(a, b)
            return a.name < b.name
        end)

        for _, chatroom in ipairs(Cache.chatrooms) do
            if Imgui.Selectable_Bool(chatroom.name) then
                GUIState.currentChatroom = chatroom
                local channelID = GUIState.selectedChannelPerChatroom[chatroom.id]

                if not channelID then
                    print("No channel selected for chatroom: " .. chatroom.name)

                    -- Select the first channel by default
                    local firstChannel = chatroom.channels.items[1]

                    if firstChannel then
                        channelID = firstChannel.id

                        print("Selecting first channel: " .. firstChannel.name)
                    end
                end

                GUIState.selectedChannelPerChatroom[chatroom.id] = channelID
                GUIState.currentChannel = chatroom.channels:get(channelID)
            end
        end
    end
    Imgui.End()

    if GUIState.createChatRoomWindowOpen then
        if not GUIState.newChatRoomName then
            GUIState.newChatRoomName = ffi.new("char[?]", 100)
        end

        local width, height = love.graphics.getDimensions()
        local windowWidth, windowHeight = 400, 200

        Imgui.SetNextWindowSize(ffi.new("ImVec2", windowWidth, windowHeight))
        Imgui.SetNextWindowPos(ffi.new("ImVec2", (width - windowWidth) / 2, (height - windowHeight) / 2))
        Imgui.SetNextWindowFocus()

        local flags = bit.bor(
            Imgui.ImGuiWindowFlags_NoResize,
            Imgui.ImGuiWindowFlags_NoCollapse,
            Imgui.ImGuiWindowFlags_AlwaysAutoResize,
            Imgui.ImGuiWindowFlags_NoMove,
            Imgui.ImGuiWindowFlags_NoDocking
        )

        if Imgui.Begin("Create Chat Room", nil, flags) then
            Imgui.Text("Enter chat room name:")
            Imgui.InputText("##ChatRoomName", GUIState.newChatRoomName, 100)
            local name = ffi.string(GUIState.newChatRoomName)

            local valid, errorMsg = validateChatroomName(name)
            if not valid then
                Imgui.Text(errorMsg)
            elseif Imgui.Button("Create") then
                Request.request(
                    "chatroom.create",
                    { CurrentUser.id, name },
                    CurrentUser.id,
                    function(success, chatroom)
                        if success then
                            print("Chat room created:", chatroom.name)

                            GUIState.createChatRoomWindowOpen = false

                            ffi.fill(GUIState.newChatRoomName, 100, 0)

                            Cache.chatrooms = Cache.chatrooms or {}
                            table.insert(Cache.chatrooms, chatroom)
                        else
                            GUIState.createChatRoomWindowOpen = false
                        end
                    end,
                    nil,
                    "post"
                )
            end
        end
        Imgui.End()
    end
end
