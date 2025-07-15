function LoginWith(username, password)
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

            local u
            status, u = User.loadUser(userOrError)

            if not status or type(u) == "string" then
                print("Failed to load user:", u)
                GUIState.loginPageOpen = true
                GUIState.registerPageOpen = false

                ---@type User | nil
                CurrentUser = nil

                return
            else
                CurrentUser = u
            end

            GUIState.loginPageOpen = false
            GUIState.registerPageOpen = false

            print("User loaded:", CurrentUser.id)
        end,
        nil,
        "post"
    )
end

function DrawLoginPage()
    Imgui.SetNextWindowSize(ffi.new("ImVec2", 400, 300))
    Imgui.SetNextWindowPos(ffi.new("ImVec2", (love.graphics.getWidth() - 400) / 2, (love.graphics.getHeight() - 300) / 2))

    if Imgui.Begin("Login", nil, bit.bor(Imgui.ImGuiWindowFlags_NoResize, Imgui.ImGuiWindowFlags_NoMove, Imgui.ImGuiWindowFlags_NoCollapse)) then
        Imgui.Text("Username:")
        Imgui.InputText("##Username", GUIState.loginUsername, GUIState.maxUsernameLength)

        Imgui.Text("Password:")
        Imgui.InputText("##Password", GUIState.loginPassword, GUIState.maxPasswordLength,
            bit.bor(Imgui.ImGuiInputTextFlags_Password))

        if Imgui.Button("Login") then
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

            love.filesystem.write("lastLogin.txt", Buffer.encode({
                username = username,
                password = password
            }))

            LoginWith(username, password)

            GUIState.currentChatroom = nil -- Reset to global chat after login
        end

        Imgui.Separator()
        Imgui.Text("Don't have an account?");

        if Imgui.Button("Register") then
            -- Switch to register page
            GUIState.loginUsername = ffi.new("char[?]", GUIState.maxUsernameLength)
            GUIState.loginPassword = ffi.new("char[?]", GUIState.maxPasswordLength)

            GUIState.loginPageOpen = false
            GUIState.registerPageOpen = true
        end
    end
    Imgui.End()
end
