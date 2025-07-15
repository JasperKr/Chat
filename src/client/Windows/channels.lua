local available = ffi.new("ImVec2", 0, 0)
local cursorPos = ffi.new("ImVec2", 0, 0)

local function smallButtonFloatRight(text, id)
    Imgui.GetContentRegionAvail(available)
    Imgui.SameLine()
    Imgui.GetCursorPos(cursorPos)
    local buttonWidth = Imgui.CalcTextSize(text).x
    Imgui.SetCursorPosX(available.x - buttonWidth)
    Imgui.SetCursorPosY(cursorPos.y)
    return Imgui.SmallButton(text .. "##" .. id)
end

function DrawChannels()
    if Imgui.Begin("Channels") then
        if not GUIState.currentChatroom or not GUIState.currentChatroom.channels then
            Imgui.Text("No chatroom selected.")
            Imgui.End()
            return
        end

        local channels = GUIState.currentChatroom.channels.items

        if #channels == 0 then
            Imgui.Text("No channels available.")
        end

        for _, channel in ipairs(channels) do
            Imgui.GetContentRegionAvail(available)
            local textWidth = Imgui.CalcTextSize("Edit").x
            local selectableSize = ffi.new("ImVec2", available.x - textWidth - 20, 0)
            if Imgui.Selectable_Bool(channel.name .. "##" .. channel.id, GUIState.currentChannel and GUIState.currentChannel.id == channel.id, nil, selectableSize) then
                GUIState.currentChannel = channel
                GUIState.selectedChannelPerChatroom[GUIState.currentChatroom.id] = channel.id

                Request.request(
                    "chatroom.getMessages",
                    {
                        GUIState.currentChatroom.id,
                        channel.id,
                        1,
                        100
                    },
                    CurrentUser.id,
                    function(success, messages)
                        if not success then
                            print("Failed to load messages for channel:", channel.name)
                        else
                            channel.messages = messages
                        end
                    end
                )
            end

            if GUIState.currentChatroom.ownerID == CurrentUser.id then
                if smallButtonFloatRight("Edit", channel.id) then
                    Imgui.OpenPopup_Str("EditChannelPopup")
                end
            end

            if Imgui.BeginPopup("EditChannelPopup") then
                Imgui.Text("Edit Channel: " .. channel.name)
                if not channel.ffiName then
                    channel.ffiName = ffi.new("char[?]", 100, channel.name)
                end

                Imgui.InputText("Channel Name", channel.ffiName, 100)

                if Imgui.Button("Save") then
                    Request.request(
                        "channel.update",
                        { GUIState.currentChatroom.id, channel.id, ffi.string(channel.ffiName) },
                        CurrentUser.id,
                        function(success, response)
                            channel.name = ffi.string(channel.ffiName)
                        end
                    )
                    Imgui.CloseCurrentPopup()
                end

                if Imgui.Button("Delete") then
                    Request.request(
                        "channel.delete",
                        { GUIState.currentChatroom.id, channel.id },
                        CurrentUser.id,
                        function(success, response)
                            if success then
                                GUIState.currentChatroom.channels:removeById(channel.id)
                                GUIState.currentChannel = nil
                            end
                        end
                    )
                    Imgui.CloseCurrentPopup()
                end

                Imgui.EndPopup()
            end
        end
    end
    Imgui.End()
end
