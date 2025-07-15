function DrawChatRoom()
    if Imgui.Begin("Chat rooms") then
        for _, chatroom in ipairs(Cache.chatrooms) do
            if Imgui.Selectable_Bool(chatroom.name, false, Imgui.ImGuiSelectableFlags_AllowDoubleClick) then
                GUIState.currentChatroom = chatroom

                Request.request(
                    "chatroom.getMessages",
                    {
                        chatroom.id,
                        1,
                        100
                    },
                    CurrentUser.id,
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
