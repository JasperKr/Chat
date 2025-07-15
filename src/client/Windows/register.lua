function DrawRegisterPage()
    Imgui.SetNextWindowSize(ffi.new("ImVec2", 400, 300))
    Imgui.SetNextWindowPos(ffi.new("ImVec2", (love.graphics.getWidth() - 400) / 2, (love.graphics.getHeight() - 300) / 2))

    if Imgui.Begin("Register", nil, bit.bor(Imgui.ImGuiWindowFlags_NoResize, Imgui.ImGuiWindowFlags_NoMove, Imgui.ImGuiWindowFlags_NoCollapse)) then
        Imgui.Text("Username:")
        Imgui.InputText("##Username", GUIState.loginUsername, GUIState.maxUsernameLength)

        Imgui.Text("Password:")
        Imgui.InputText("##Password", GUIState.loginPassword, GUIState.maxPasswordLength,
            bit.bor(Imgui.ImGuiInputTextFlags_Password))

        if Imgui.Button("Register") then
            local username = ffi.string(GUIState.loginUsername)
            local password = ffi.string(GUIState.loginPassword)

            if username == "" or password == "" then
                print("Username and password cannot be empty")
                Imgui.End()
                return
            end

            -- username must be at least 3 characters and at most 80 characters
            if #username < 3 or #username > GUIState.maxUsernameLength then
                print("Username must be between 3 and " .. GUIState.maxUsernameLength .. " characters")
                Imgui.End()
                return
            end

            -- password must be at least 6 characters and at most 128 characters
            if #password < 6 or #password > GUIState.maxPasswordLength then
                print("Password must be between 6 and " .. GUIState.maxPasswordLength .. " characters")
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

                    local u

                    success, u = User.loadUser(userOrError)

                    if not success or type(u) == "string" then
                        print("Failed to load user:", u)
                        return
                    end

                    CurrentUser = u

                    GUIState.currentChatroom = nil -- Reset to global chat after registration
                    GUIState.loginPageOpen = false
                    GUIState.registerPageOpen = false

                    Request.request(
                        "chatroom.join",
                        {
                            CurrentUser.id,
                            "GLOBAL_CHAT_ID__" -- Join the global chatroom after registration
                        },
                        CurrentUser.id,
                        function(success, errmsg)
                            if not success then
                                print("Failed to join global chatroom:", errmsg)
                                return
                            end

                            CurrentUser:refresh()
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
            GUIState.loginUsername = ffi.new("char[?]", GUIState.maxUsernameLength)
            GUIState.loginPassword = ffi.new("char[?]", GUIState.maxPasswordLength)

            GUIState.loginPageOpen = true
            GUIState.registerPageOpen = false
        end
    end
    Imgui.End()
end
