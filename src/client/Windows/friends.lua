local available = ffi.new("ImVec2", 0, 0)

local pfpSize = 50
local pfpSizeVec = ffi.new("ImVec2", pfpSize, pfpSize)

function DrawFriends()
    if Imgui.Begin("Friends") then
        local friends = CurrentUser.friends

        if Imgui.Button("Friends") then
            SetCurrentWindow("friends list")
        end

        Imgui.Separator()

        if #friends == 0 then
            Imgui.Text("No friends lol.")
        end

        local hoveredColor = Imgui.GetColorU32_Vec4(Imgui.GetStyleColorVec4(Imgui.ImGuiCol_Button)[0])

        -- set background color to transparent
        Imgui.PushStyleColor_Vec4(Imgui.ImGuiCol_Button, ffi.new("ImVec4", 0, 0, 0, 0))
        Imgui.PushStyleColor_Vec4(Imgui.ImGuiCol_ButtonHovered, ffi.new("ImVec4", 0, 0, 0, 0))
        Imgui.PushStyleColor_Vec4(Imgui.ImGuiCol_ButtonActive, ffi.new("ImVec4", 0, 0, 0, 0))

        local drawlist = Imgui.GetWindowDrawList()
        Imgui.ImDrawList["ChannelsSplit"](drawlist, 2)
        Imgui.ImDrawList["ChannelsSetCurrent"](drawlist, 1)
        local style = Imgui.GetStyle()

        for _, friendID in ipairs(friends) do
            Imgui.GetContentRegionAvail(available)

            local friend = GetUser(friendID)

            if friend then
                if not friend.profilePictureTexture then
                    friend.profilePictureTexture = love.graphics.newTexture(friend.profilePicture)
                end

                local cursorPos = Imgui.GetCursorPos()
                Imgui.BeginGroup()
                Imgui.Image(friend.profilePictureTexture, pfpSizeVec)
                Imgui.SameLine()

                Imgui.SetCursorPosY(Imgui.GetCursorPosY() + (pfpSize - Imgui.GetTextLineHeight()) / 2)
                Imgui.Text(friend.name)
                Imgui.EndGroup()

                local min = Imgui.GetItemRectMin() - style.FramePadding
                local max = Imgui.GetItemRectMax() + style.FramePadding
                local hovered = Imgui.IsItemHovered()

                Imgui.ImDrawList["ChannelsSetCurrent"](drawlist, 0)
                Imgui.ImDrawList["AddRectFilled"](
                    drawlist,
                    min, max,
                    hovered and hoveredColor or Imgui.GetColorU32_Col(Imgui.ImGuiCol_ChildBg),
                    6
                )

                Imgui.SetCursorPos(cursorPos)
                if Imgui.InvisibleButton(friend.id .. "##friend_invisible_button", max - min) then
                    GUIState.currentDirectMessage = friend

                    Request.request(
                        "directMessages.getMessages",
                        {
                            GUIState.currentChatroom.id,
                            friend.id,
                            1,
                            100
                        },
                        CurrentUser.id,
                        function(success, messages)
                            if not success then
                                print("Failed to load messages for friend:", friend.name)
                            else
                                friend.messages = messages
                            end
                        end
                    )
                end
            end
        end

        Imgui.PopStyleColor(3)

        Imgui.ImDrawList["ChannelsSetCurrent"](drawlist, 1)
        Imgui.ImDrawList["ChannelsMerge"](drawlist)
    end
    Imgui.End()
end

function DrawAddFriend()
    if Imgui.Begin("Add Friend") then
        if not GUIState.addFriendUsername then
            GUIState.addFriendUsername = ffi.new("char[?]", GUIState.maxUsernameLength)
        end

        Imgui.Text("Friend's Username:")
        Imgui.InputText("##FriendUsername", GUIState.addFriendUsername, GUIState.maxUsernameLength)

        if Imgui.Button("Add Friend") then
            local friendUsername = ffi.string(GUIState.addFriendUsername)

            Request.request(
                "user.requestFriend",
                {
                    CurrentUser.id,
                    friendUsername
                },
                CurrentUser.id,
                function(success, response)
                    if not success then
                        print("Failed to add friend:", response)
                    else
                        print("Friend added successfully")
                        -- Optionally refresh friends list here
                    end
                end,
                nil,
                "post"
            )
        end
    end
    Imgui.End()
end

function DrawAllFriends()
    if Imgui.Begin("All Friends") then
        if Imgui.Button("Add friend") then
            SetCurrentWindow("add friend")
        end
        if #GUIState.friends == 0 then
            Imgui.Text("You have no friends added.")
        else
            for _, friend in ipairs(GUIState.friends) do
                Imgui.Text(friend.name)
            end
        end
    end
    Imgui.End()
end
