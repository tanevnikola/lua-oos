local ft = {};

local setmetatable = setmetatable;
local tostring = tostring;
local pairs = pairs;
local table = table;
local _G = _G;
local string = string;
local type = type;

------------- type -------------
ft.type = {
    -- base types validation
    isnil       = function(x) return x == nil;                  end;
    isboolean   = function(x) return ft.type(x) == "boolean";   end;
    isstring    = function(x) return ft.type(x) == "string";    end;
    isnumber    = function(x) return ft.type(x) == "number";    end;
    isfunction  = function(x) return ft.type(x) == "function";  end;
    istable     = function(x) return ft.type(x) == "table";     end;
    istablelike = function(x) return type(x) == "table";        end;
    
    -- compare types
    issame      = function(x, y) return ft.type(x) == ft.type(y); end;
    isdifferent = function(x, y) return ft.type(x) ~= ft.type(y); end;
}

setmetatable(ft.type, 
{
    __call = function(this, x)
        local t = type(x)
        -- handle custom types
        if t == "table" and ft.type.isfunction(x._ft_gettype) then
            t = x._ft_gettype()
        end
        return t
    end
})

------------- exception -------------
function ft.exception(msg, level)
    print("[Error]  " .. debug.traceback(msg, (level or 0) + 2));
    os.exit(-1);
end

------------- format -------------
ft.format = {};
function ft.format.tablekey(k)
    return ft.type.isstring( k ) and string.match( k, "^[_%a][_%a%d]*$" )  and k or "[" .. ft.format.value( k ) .. "]";
end

function ft.format.value(v)
    if ft.type.isstring( v ) then
        v = string.gsub( v, "\n", "\\n" )
        if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
            return "'" .. v .. "'"
        end
        return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
    else
        return ft.type.istable( v ) and ft.table.tostring( v ) or tostring( v )
    end
end

------------- string -------------
ft.string = {}
function ft.string.isstartswith(str, start)
    return string.sub(str, 1, string.len(start)) == start;
end

------------- table -------------
ft.table = {}

function ft.table.count(tbl)
    local count = 0
    for k,v in pairs(tbl) do
        count = count + 1
    end
    return count
end

function ft.table.tostring(tbl)
    if not tbl then
        return "nil"
    end

    local result = {}
    for k, v in pairs( tbl ) do
        table.insert( result, ft.format.tablekey( k ) .. " = " .. ft.format.value( v ) )
    end
    
    return "{" .. table.concat( result, ", " ) .. "}"
end

function ft.table.copy(src, dest)
    for k, v in pairs(src) do
        dest[k] = v;
    end
    return dest;
end


function ft.table.clone(tblSource)
    local clone = {}
    for k,v in pairs(tblSource) do
        clone[k] = ft.type.istablelike(v) and ft.table.clone(v) or v;
    end
    return clone;
end

return ft;