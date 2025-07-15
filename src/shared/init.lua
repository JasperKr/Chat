table.clear = require("table.clear")
table.new = require("table.new")

ffi = require("ffi")
bit = require("bit")

if not SERVER then
    require("imguiLoader")

    Imgui.PushStyleColor_Vec4(Imgui.ImGuiCol_Button, Imgui.ImVec4_Float(1.0, 1.0, 1.0, 0.0))
    Imgui.PushStyleColor_Vec4(Imgui.ImGuiCol_ButtonHovered, Imgui.ImVec4_Float(1.0, 1.0, 1.0, 0.1))
    Imgui.PushStyleColor_Vec4(Imgui.ImGuiCol_ButtonActive, Imgui.ImVec4_Float(1.0, 1.0, 1.0, 0.2))
    Imgui.PushStyleVar_Float(Imgui.ImGuiStyleVar_FrameRounding, 5.0)

    local imio = Imgui.GetIO()

    local baseConfig = Imgui.ImFontConfig()
    baseConfig.FontDataOwnedByAtlas = false
    baseConfig.Name = "FireCode-VariableFont"
    baseConfig.MergeMode = false
    baseConfig.PixelSnapH = true
    baseConfig.OversampleH = 5
    baseConfig.OversampleV = 5
    baseConfig.SizePixels = 16

    local font_size = 16

    local content, size = love.filesystem.read("Assets/FiraCode-SemiBold.ttf")

    assert(content, "Failed to load user interface font")

    local font = imio.Fonts:AddFontFromMemoryTTF(ffi.cast("void*", content), size, font_size, baseConfig)

    imio.FontDefault = font

    Imgui.love.BuildFontAtlas()
    Imgui.StyleColorsLight();
end

Tables = require("tables")
ID = require("id")
Message = require("message")
User = require("user")
Chatroom = require("chatroom")
Enet = require("enet")
Buffer = require("string.buffer")
Privileges = require("privileges")
Request = require("request")
ChatMessage = require("chatMessage")
Stringh = require("stringHelpers")
