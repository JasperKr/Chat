-- Dear Imgui version: 1.88

M = {
    love = {},
    _common = {}
}


require("cimgui.cdef")

local ffi = require("ffi")
local library_path = assert(package.searchpath("cimgui", package.cpath))
M.C = ffi.load(library_path)

require("cimgui.enums")
require("cimgui.wrap")
require("cimgui.love")
require("cimgui.shortcuts")

-- remove access to M._common
M._common = nil

return M
