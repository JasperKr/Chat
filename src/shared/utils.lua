function PrintTable(data, depth)
    if type(data) == "table" then
        depth = depth or 0
        local indent = string.rep("  ", depth)
        for k, v in pairs(data) do
            if type(v) == "table" then
                print(indent .. tostring(k) .. ":")
                PrintTable(v, depth + 1)
            else
                print(indent .. tostring(k) .. ": " .. tostring(v))
            end
        end
    else
        print(tostring(data))
    end
end
