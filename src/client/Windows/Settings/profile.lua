--- Loads image data from a file and returns it.
---@param files string[]
---@param filtername string
---@param errorstring string|nil
---@return boolean
---@return love.ImageData|love.CompressedImageData|string
local function loadImagedata(files, filtername, errorstring)
    if errorstring then
        return false, "Error: " .. errorstring
    end

    if #files == 0 then
        return false, "No files selected"
    end

    local file = files[1]:gsub("\\", "/") ---@type string

    local directory = file:match("^(.+)/[^/]+$")    -- "C:/path/to/file.png" -> "C:/path/to/"
    local filename = file:match("^.+[\\/]([^/]+)$") -- "C:/path/to/file.png" -> "file.png"
    local extension = file:match("^.+(%..+)$")      -- "file.png" -> ".png"

    love.filesystem.mountFullPath(directory, "profile_pictures", "read")
    local imageData

    if extension == ".DDS" or extension == ".dds" then
        imageData = love.image.newCompressedData("profile_pictures/" .. filename)
    else
        imageData = love.image.newImageData("profile_pictures/" .. filename)
    end
    love.filesystem.unmountFullPath("profile_pictures")

    if not imageData then
        return false, "Failed to load image data from file: " .. file
    end

    if imageData:getWidth() > 512 or imageData:getHeight() > 512 then
        return false, "Profile picture must be at most 512x512 pixels"
    end

    return true, imageData
end

function DrawProfileSettings()
    Imgui.Text("Profile Settings")
    Imgui.Separator()

    if Imgui.Button("Change Profile Picture") then
        -- Open file dialog to select a new profile picture
        love.window.showFileDialog("openfile", function(files, filtername, errorstring)
            local success, loaded, imagedata = pcall(loadImagedata, files, filtername, errorstring)
            if not success or not imagedata then
                print("Failed to load image data:", loaded)
                return
            end
            if not loaded then
                print("Error loading image data:", imagedata)
                return
            end

            CurrentUser:setProfilePicture(imagedata)
            CurrentUser:updateServerData()
        end, { title = "Select Profile Picture", filter = { "png", "jpg", "jpeg", "DDS", "dds", "bmp" } })
    end
    Imgui.Text("Max profile picture size: 512x512 pixels")

    if CurrentUser.profilePicture then
        if not CurrentUser.profilePictureTexture then
            CurrentUser.profilePictureTexture = love.graphics.newTexture(CurrentUser.profilePicture)
        end
        Imgui.Image(CurrentUser.profilePictureTexture, ffi.new("ImVec2", 100, 100))
    else
        Imgui.Text("No profile picture set")
    end

    if Imgui.Button("Set Custom Status") then
        -- Open a dialog to set custom status
        local status = Imgui.InputText("Custom Status", CurrentUser.customStatus or "", 256)
        CurrentUser:setCustomStatus(status)
    end

    local status, expires = CurrentUser:getCustomStatus()
    if status then
        Imgui.Text("Custom Status: " .. status)
        if expires then
            Imgui.Text("Expires at: " .. os.date("%Y-%m-%d %H:%M:%S", expires))
        end
    else
        Imgui.Text("No custom status set")
    end
end
