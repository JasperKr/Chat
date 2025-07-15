local function connect()
    Connection.host = Enet.host_create()
    Connection.server = Connection.host:connect("127.0.0.1:5111")
end

function DrawConnectPage(callback)
    if Connection.server == nil then
        connect()
    end

    local event = Connection.host:service()

    if event then
        if event.type == "connect" then
            print("Connected to server")
            GUIState.loginPageOpen = true
            GUIState.registerPageOpen = false

            Connection.connected = true

            callback()
        elseif event.type == "disconnect" then
            print("Disconnected from server")
            Connection.connected = false
            connect()
        else
            print("Received event, but not handled:", event.type)
        end
    end

    Imgui.SetNextWindowSize(ffi.new("ImVec2", 400, 300))
    Imgui.SetNextWindowPos(ffi.new("ImVec2", (love.graphics.getWidth() - 400) / 2, (love.graphics.getHeight() - 300) / 2))
    if Imgui.Begin("Connect", nil, bit.bor(Imgui.ImGuiWindowFlags_NoResize, Imgui.ImGuiWindowFlags_NoMove, Imgui.ImGuiWindowFlags_NoCollapse)) then
        Imgui.Text("Connecting to server...")

        Imgui.Separator()

        if Imgui.Button("Retry") then
            print("Retry connecting to server...")

            Connection.server = nil
            Connection.host:destroy()
            Connection.connected = false

            connect()
        end

        Imgui.SameLine()

        if Imgui.Button("Exit") then
            love.event.quit()
        end
    end
    Imgui.End()
end
