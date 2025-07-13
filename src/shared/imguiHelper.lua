function Imgui.ButtonRight(name, size)
    local style = Imgui.style
    local width = size and size.x or (Imgui.CalcTextSize(name).x + style.FramePadding.x * 2)
    local widthNeeded = width + style.ItemSpacing.x
    Imgui.SetCursorPosX(Imgui.GetCursorPos().x + Imgui.GetContentRegionAvail().x - widthNeeded)
    return Imgui.Button(name, size)
end

function Imgui.TextRight(name)
    local style = Imgui.style
    local width = Imgui.CalcTextSize(name).x + style.FramePadding.x * 2
    local widthNeeded = width + style.ItemSpacing.x
    Imgui.SetCursorPosX(Imgui.GetCursorPos().x + Imgui.GetContentRegionAvail().x - widthNeeded)
    return Imgui.Text(name)
end

function Imgui.TextCentered(name)
    local style = Imgui.style
    local width = Imgui.CalcTextSize(name).x + style.FramePadding.x * 2
    local widthNeeded = width + style.ItemSpacing.x
    Imgui.SetCursorPosX(Imgui.GetCursorPos().x + (Imgui.GetContentRegionAvail().x - widthNeeded) / 2)
    return Imgui.Text(name)
end
