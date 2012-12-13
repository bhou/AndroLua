--- I/O Utilities
-- @module android.utils
require 'android.import'
local L = luajava.package 'java.lang'
local IO = luajava.package 'java.io'
local BUFSZ = 4*1024

local utils = {}

--- read all the bytes from a stream as a byte array.
-- @tparam L.InputStream f
-- @treturn [byte]
function utils.readbytes(f)
    local buff = L.Byte{n = BUFSZ}
    local out = IO.ByteArrayOutputStream(BUFSZ)
    local n = f:read(buff)
    while n ~= -1 do
        out:write(buff,0,n)
        n = f:read(buff,0,BUFSZ)
    end
    f:close()
    return out:toByteArray()
end

--- read all the bytes from a stream as a string.
-- @tparam L.InputStream f
-- @treturn string
function utils.readstring(f)
    return tostring(L.String(utils.readbytes(f)))
end


return utils

