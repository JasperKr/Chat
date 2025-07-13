local stringh = {}

--- Returns the filename from a path
--- Example: C:/Users/JohnDoe/Desktop/MyFile.txt -> MyFile.txt
--- @param path string
--- @return string
function stringh.filename(path)
    return path:match("^.+[\\/]([^/]+)$") or path
end

--- Returns the extension from a filename
--- Example: MyFile.txt -> .txt
--- @param filename string
--- @return string
function stringh.extension(filename)
    return filename:match("^.+(%..+)$")
end

--- Returns the filename without the extension
--- Example: MyFile.txt -> MyFile
--- @param filename string
--- @return string
function stringh.filenameWithoutExtension(filename)
    return filename:match("^(.-)%.") or filename
end

--- Returns the directory from a path
--- Example: C:/Users/JohnDoe/Desktop/MyFile.txt -> C:/Users/JohnDoe/Desktop
--- @param path string
--- @return string
function stringh.directory(path)
    return path:match("^(.+)/[^/]+$")
end

--- Sanitises the filepath
--- Example: C:\Users\JohnDoe\Desktop/MyFile.txt -> C:/Users/JohnDoe/Desktop/MyFile.txt
--- @param path string
--- @return string
function stringh.sanitise(path)
    return path:gsub("\\", "/") or error("Invalid path")
end

--- Checks if a file is of a certain extension
--- Example: C:/Users/JohnDoe/Desktop/MyFile.txt, txt -> true
--- @param path string
--- @param ext string
--- @return boolean
function stringh.hasExtension(path, ext)
    return path:match("^.+%.(" .. ext .. ")$")
end

--- Splits a string into a table
--- Example: "Hello, world, how are you?" -> {"Hello", "world", "how", "are", "you?"}
--- Default separator is " "
--- @param str string
--- @param sep string
--- @param out table?
--- @return table
function stringh.split(str, sep, out)
    out = out or {}
    sep = sep or " "
    for s in str:gmatch("([^" .. sep .. "]+)") do
        table.insert(out, s)
    end
    return out
end

local tempTable = {}

--- Combines paths
--- Example: C:/Users/JohnDoe/Desktop, MyFile.txt -> C:/Users/JohnDoe/Desktop/MyFile.txt
--- @param ... string
--- @return string
function stringh.combinePath(...)
    table.clear(tempTable)
    local count = select("#", ...)

    for i = 1, count do
        local path = stringh.sanitise(select(i, ...))

        if not path or path == "" then
            goto continue
        end

        -- remove "./" but not "../"
        path = path:gsub("^%./", ""):gsub("/%./", "/")

        -- remove trailing and leading slashes
        if path:sub(-1) == "/" then path = path:sub(1, -2) end
        if path:sub(1, 1) == "/" then path = path:sub(2) end

        table.insert(tempTable, path)
        ::continue::
    end

    return table.concat(tempTable, "/")
end

return stringh
