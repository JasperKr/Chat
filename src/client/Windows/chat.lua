local function calculateChatboxHeight()
    local textLineHeight = Imgui.GetTextLineHeight() ---@type number
    local lines = CountNewLines(ffi.string(GUIState.userInput)) + 2

    local textHeight = textLineHeight * lines + 8
    local largestAttachmentHeight = 0

    for _, attachment in ipairs(GUIState.attachments) do
        local texture = Attachments.getAttachmentTexture(attachment)
        if texture then
            largestAttachmentHeight = math.max(largestAttachmentHeight, math.min(200, texture:getHeight()))
        else
            largestAttachmentHeight = math.max(largestAttachmentHeight, 200)
        end
    end

    if largestAttachmentHeight > 0 then
        textHeight = textHeight + largestAttachmentHeight + 8 -- Add some padding
    end

    return textHeight
end

local unknownUser = User.newUser("unknown", "Unknown User", "-")
local contentRegionAvailable = ffi.new("ImVec2", 0, 0)

local function drawMessage(message, isSubMessage, sizeAvailable)
    if not message or not message.from or not message.text then
        return
    end

    local from = Cache.users[message.from] or unknownUser
    if from.profilePicture and not from.profilePictureTexture then
        from.profilePictureTexture = love.graphics.newTexture(from.profilePicture)
    end

    if not isSubMessage then
        if from.profilePictureTexture then
            Imgui.Image(from.profilePictureTexture, GUIState.profilePictureSize)
        else
            Imgui.Dummy(GUIState.profilePictureSize)
        end
        Imgui.SameLine()
        Imgui.Text(from.name)
        Imgui.SameLine()
        Imgui.TextDisabled(os.date("%H:%M:%S", message.timestamp))
    end

    Imgui.Text(message.text)

    if message.attachments and #message.attachments > 0 then
        for _, attachment in ipairs(message.attachments) do
            local texture = Attachments.getAttachmentTexture(attachment)
            if texture then
                local width, height = texture:getDimensions()
                local widthAvailable = sizeAvailable.x
                local heightAvailable = 500

                local scale = math.min(widthAvailable / width, heightAvailable / height)
                local scaledWidth = width * scale
                local scaledHeight = height * scale

                Imgui.Image(texture, ffi.new("ImVec2", scaledWidth, scaledHeight))
            else
                Imgui.TextColored(Imgui.ImVec4_Float(1, 0, 0, 1), "Failed to load attachment")
            end
        end
    end

    if message.combinedMessages then
        for _, subMessage in ipairs(message.combinedMessages) do
            drawMessage(subMessage, true, sizeAvailable)
        end
    end
end

local function validateUserMessage(text)
    if not text or text == "" then
        return false, "Message cannot be empty"
    end

    if #text > GUIState.maxUserInputLength then
        return false, "Message is too long (max " .. GUIState.maxUserInputLength .. " characters)"
    end

    if text:match("^%s*$") then
        return false, "Message cannot be empty or contain only whitespace"
    end

    return true, nil
end

function DrawChat()
    local room = GUIState.currentChatroom
    if Imgui.Begin("Chat") then
        local height = calculateChatboxHeight()

        if GUIState.currentChatroom and room then
            Imgui.Text(GUIState.currentChatroom.name)
            Imgui.Separator()
        end

        Imgui.GetContentRegionAvail(contentRegionAvailable)
        local messagesChildHeight = contentRegionAvailable.y - height - 20 -- Reserve space for message input

        if Imgui.BeginChild_Str("Messages", ffi.new("ImVec2", 0, messagesChildHeight), true) and GUIState.currentChatroom and room then
            ---TODO: dynamically load messages

            table.sort(room.messages, function(a, b)
                return a.timestamp < b.timestamp
            end)

            Imgui.GetContentRegionAvail(contentRegionAvailable)

            -- local textLineHeight = Imgui.GetTextLineHeight()

            for i, message in ipairs(room.messages) do
                -- local messageHeight = textLineHeight * (message.newLineCount + 2) + 8

                if not Cache.users[message.from] then
                    Request.request(
                        "user.get",
                        { message.from },
                        CurrentUser.id,
                        function(success, userData)
                            if not success then
                                print("Failed to load user data for ID:", message.from)
                                Cache.users[message.from] = User.newUser(message.from, "Unknown User", "-")
                                return
                            end

                            local success, loadedUser = User.loadUser(userData)
                            if not success or type(loadedUser) ~= "table" then
                                print("Failed to load user data for ID:", message.from, "Error:", loadedUser)
                                return
                            end

                            Cache.users[message.from] = loadedUser

                            GUIState.scrollToBottom = true -- Scroll to bottom after loading user data
                        end,
                        nil,
                        "get",
                        "once",
                        message.from -- use other userID as message ID to avoid multiple requests for the same user
                    )
                end

                drawMessage(message, false, contentRegionAvailable)
            end

            SmoothScrollToTop()

            GUIState.hoveredChatWindow = Imgui.IsWindowHovered()
        end
        Imgui.EndChild()
        -- if GUIState.overedChatWindow and not GUIState.hasKeyboardFocus and GUIState.anyKeypressed then
        --     print("Setting keyboard focus to message box")
        --     Imgui.SetNextWindowFocus()
        -- end

        if Imgui.BeginChild_Str("Message Box", nil, true) and GUIState.currentChatroom then
            for i, attachment in ipairs(GUIState.attachments) do
                local texture = Attachments.getAttachmentTexture(attachment)
                if texture then
                    local width, height = texture:getDimensions()
                    local widthAvailable = contentRegionAvailable.x
                    local heightAvailable = 200
                    local scale = math.min(widthAvailable / width, heightAvailable / height)
                    local scaledWidth = width * scale
                    local scaledHeight = height * scale

                    Imgui.Image(texture, ffi.new("ImVec2", scaledWidth, scaledHeight))

                    if i ~= #GUIState.attachments then Imgui.SameLine() end
                end
            end

            if GUIState.justSentMessage or (GUIState.hoveredChatWindow and not GUIState.hasKeyboardFocus and GUIState.anyKeypressed) then
                Imgui.SetKeyboardFocusHere(); GUIState.justSentMessage = false
            end
            local textLineHeight = Imgui.GetTextLineHeight()

            local lines = CountNewLines(ffi.string(GUIState.userInput)) + 2
            local size = ffi.new("ImVec2", -1, textLineHeight * lines + 8)

            if Imgui.InputTextMultiline("##MessageInput", GUIState.userInput, GUIState.maxUserInputLength, size,
                    bit.bor(Imgui.ImGuiInputTextFlags_EnterReturnsTrue, Imgui.ImGuiInputTextFlags_CtrlEnterForNewLine)) then
                local message = ffi.string(GUIState.userInput)

                if validateUserMessage(message) then
                    ffi.fill(GUIState.userInput, GUIState.maxUserInputLength)

                    GUIState.justSentMessage = true

                    Request.request(
                        "chatroom.addMessage",
                        {
                            GUIState.currentChatroom.id,
                            ChatMessage.newChatMessage(message, CurrentUser.id, CurrentUser.name,
                                GUIState.attachments)
                        },
                        CurrentUser.id,
                        nil,
                        nil,
                        "post"
                    )

                    table.clear(GUIState.attachments)
                end
            end

            GUIState.hasKeyboardFocus = Imgui.IsItemActive()
        end
        Imgui.EndChild()
    end
    Imgui.End()
end
