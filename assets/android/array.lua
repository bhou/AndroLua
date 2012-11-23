
local array = {}
array.__index = array

local function _array (a)
    return setmetatable(a,array)
end

function array.new (x1,x2,dx)
    local xvalues = {}
    if x1 ~= nil then
        if type(x1) == 'table' then return _array(x1) end
        local i = 1
        for x = x1, x2 , dx do
            xvalues[i] = x
            i = i + 1
        end
    end
    return _array(xvalues)
end

local _function_cache = {}

local function _function_arg (f)
    if type(f) == 'string' then
        if _function_cache[f] then return _function_cache[f] end
        local args = f:match '_2' and '_1,_2' or '_'
        local chunk,err = loadstring('return function('..args..') return '..f..' end',f)
        if err then error("bad function argument "..err,3) end
        local fn = chunk()
        _function_cache[f] = fn
        return fn
    end
    return f
end

local function _map (src,i1,i2,dest,j,f,...)
    f = _function_arg(f)
    for i = i1,i2 do
        dest[j] = f(src[i],...)
        j = j + 1
    end
    return dest
end

function array:map (f,...)
    return _array(_map(self,1,#self,{},1,f,...))
end

function array:apply (f,...)
    _map(self,1,#self,self,1,f,...)
end

function array:map2 (f,other)
    if #self ~= #other then error("arrays not the same size",2) end
    f = _function_arg(f)
    local res = {}
    for i = 1,#self do
        res[i] = f(self[i],other[i])
    end
    return _array(res)
end

function array:find (value)
    for i = 1,#self do
        local v = self[i]
        if v >= value then
            if v > value then
                local x1,x2 = self[i-1],self[i]
                return {i-1,(value-x1)/(x2-x1),x=value}
            else
                return i -- on the nose!
            end
        end
    end
end

function array:at (idx)
    if type(idx) == 'number' then
        return self[idx],true
    else
        local i,delta = idx[1],idx[2]
        return delta*(self[i+1]-self[i]) + self[i]
    end
end

array.append = table.insert

function array:extend (other)
    _map(other,1,#other,self,#self+1,'_')
end

function array:sub (i1,i2)
    i2 = i2 or -1
    if i2 < 0 then i2 = #self + i2 + 1 end  -- -1 is #self, and so forth
    return _array(_map(self,i1,i2,{},1,'_'))
end

--- operator overloads: concatenation
function array:__concat (other)
    local res = self:sub(1)
    res:extend(other)
    return res
end

function mapm(a1,op,a2)
  local M = type(a2)=='table' and array.map2 or array.map
  return M(a1,op,a2)
end

--- elementwise arithmetric operations
function array.__add(a1,a2) return mapm(a1,'_1 + _2',a2) end
function array.__sub(a1,a2) return mapm(a1,'_1 - _2',a2) end
function array.__div(a1,a2) return mapm(a1,'_1 / _2',a2) end
function array.__mul(a1,a2) return mapm(a2,'_1 * _2',a1) end

function array:__tostring ()
    local n,cb = #self,']'
    if n > 15 then
        n = 15
        cb = '...]'
    end
    local strs = _map(self,1,n,{},1,tostring)
    return '['..table.concat(strs,',')..cb
end

function array.minmax (values)
    local min,max = math.huge,-math.huge
    for i = 1,#values do
        local val = values[i]
        if val > max then max = val end
        if val < min then min = val end
    end
    return min,max
end

setmetatable(array,{
    __call = function(_,...) return array.new(...) end
})

return array
