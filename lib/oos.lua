local ft = require "lib.utils"

local function clonefunction(func, env)
    return load(string.dump(func, true), nil, "b", env);
end

local function instantiateClass(inst_class_tbl, ...)
    local inst_tbl = {}
    local environments = {};
    local constructors = {}
    
    
    local function builderrormessage(msg)
        return "Cannot make an instance of the class '" .. ft.type(inst_class_tbl) .. "'.\n[Reason] " .. msg .. "\n";
    end
    
    local function extendmethodenv(env, class_tbl)
        local _ = class_tbl._ft_base and extendmethodenv(env, class_tbl._ft_base);
        
        if class_tbl[1] and ft.type.istable(class_tbl[1]) then
            for k, v in pairs(class_tbl[1]) do
                if env[k] then
                    error(builderrormessage("Duplicate field name '" .. k 
                            ..  "' found in method environment definition of class '" 
                            .. ft.type(class_tbl) .. "'."), 0);
                end
                if ft.type.isboolean(v) or ft.type.isnumber(v) or ft.type.isstring(v) then
                    error(builderrormessage("Invalid type '" .. ft.type(v) 
                            .. "' found in method environment definition of class '" 
                            .. ft.type(class_tbl) .. "'."), 0);
                end
                env[k] = v;
            end
        end
        return env;
    end
    
    local createmethods; -- forward declaration
    local function createmethod(func, inst_tbl, class_tbl)
        -- method environment
        local envKey = tostring(class_tbl);
        local env = environments[envKey];
        if not env then
            env = extendmethodenv({ this = inst_tbl; }, class_tbl);
            environments[envKey] = env;
            -- super
            if class_tbl._ft_base then
                env.super = createmethods({}, class_tbl._ft_base);
            end
        end
        
        -- create the method
        local method = clonefunction(func);
        local i = 1;
        local  up = debug.getupvalue(func, i);
        while up do
            if up == "_ENV" then
                debug.setupvalue(method, i, env);
            elseif env[up] then
                error(builderrormessage("Ambiguous method environment found in '" .. ft.type(class_tbl) 
                    ..  "': there is an upvalue with the same name '" .. up .. "'"), 0);
            else
                debug.upvaluejoin(method, i, func, i);
            end
            i = i + 1;
            up = debug.getupvalue(func, i);
        end;
        
        return method;
    end

    createmethods = function(where, class_tbl)
        for k, v in pairs(class_tbl) do
            if not where[k] then
                if ft.type.isfunction(v) and not ft.string.isstartswith(k, "_ft_") then
                    local method = createmethod(v, inst_tbl, class_tbl);
                    if k == "constructor" then
                        constructors[class_tbl] = method;
                    else
                        where[k] = method;
                    end

                elseif ft.type.isfunction(v) and ft.string.isstartswith(k, "_ft_") then
                    where[k] = v;
                elseif not ft.type.isfunction(v) and not (ft.type.istable(v) and k == 1) then
                    error(builderrormessage("Invalid class syntax. Field named '" .. k 
                            ..  "' of type '" .. ft.type(v) .. "' not allowed in class definition."), 0);
                end
            end
        end
        return class_tbl._ft_base and createmethods(where, class_tbl._ft_base) and where or where;
    end
    
    createmethods(inst_tbl, inst_class_tbl);
    
    -- invoke constructor
    local function invokeconstructor(class_tbl, ...)
        if class_tbl._ft_base then 
            invokeconstructor(class_tbl._ft_base)
        end
        local _ = constructors[class_tbl] and constructors[class_tbl](...);
    end
    invokeconstructor(inst_class_tbl, ...);
    return inst_tbl;
end;

local function defineClass(classpath, base, classdef)
    local class_tbl = { };
    for k,v in pairs(classdef) do
        class_tbl[k] = v;
    end
    
    -- static methods for each instance - dont have this and super
    local namespace = (string.gsub(classpath, "(.*)%.%a$", "%1"));
    local classtype = "[class " .. tostring(classpath) .. "]";
    function class_tbl._ft_getclassname ()          return classpath; end
    function class_tbl._ft_gettype      ()          return classtype; end
    function class_tbl._ft_getbasetype  (class_tbl) return base and base._ft_getbasetype(base) or ft.type(class_tbl); end
    function class_tbl._ft_issubclassof (x)         return ((ft.type(class_tbl) == ft.type(x)) or (base and base._ft_issubclassof(x))) == true; end
    
    -- meta
    local class_mtbl = { _ft_base = base; __metatable = {};  __call = instantiateClass; }
    function class_mtbl.__index(self, key)
        return class_mtbl[key];
    end
    
    return setmetatable(class_tbl, class_mtbl);
end;

ft.class = {_ft_ns = "ft.class", _ft_nspath = "ft.class"};

local class_functor_mtbl = {__metatable = {}};

function class_functor_mtbl.__call(self, ...)
    if ft.type.isclass(self._ft_classdef) then
        local status, result = pcall(self._ft_classdef, ...);
        return status and result or ft.exception(result, 1);
    else
        local arg = {...};
        
        local base = arg[1];
        local baseclass = ft.type.isclass(base) and ft.type.isclass(base._ft_classdef) and base._ft_classdef or ft.type.isclass(base) and base  or nil;  
        if base and not baseclass then
            ft.exception("invalid base class provided. Expected '[class <classname>]' got '" .. ft.type(base) .. "'", 1);
        end

        return function(classdef)
            local status, result = pcall(defineClass, self._ft_nspath, baseclass, classdef);
            if not status then ft.exception(result, 1) end

            self._ft_classdef = result;
            self._ft_gettype = function() return ft.type(self._ft_classdef); end;
            return self._ft_classdef;
        end;
    end;
end;

function class_functor_mtbl.__index(this, key)
    if string.sub(key, 1, string.len("_ft_"))=="_ft_" then
        return rawget(this, key);
    end;
    local val = rawget(this, key) or setmetatable({_ft_ns = key, _ft_nspath = rawget(this, "_ft_nspath") .. "." .. key}, class_functor_mtbl);
    rawset(this, key, val); 
    return val;
end;

setmetatable(ft.class, {
    __index = class_functor_mtbl.__index;
});







-- extend utils
---------------------------------------------
local original_clone = ft.table.clone;
function ft.table.clone(tblSource)
    local clone = original_clone(tblSource);
    if ft.type.isclass(tblSource) then
        clone = tblSource._ft_finishclone(clone);
    end
    return clone;
end

function ft.type.isclass(x)
    local _
    local c
    _,_,c = string.find(ft.type(x), "%[(class) ft%.class[%.%a%d]+%]")
    return c == "class"
end;

function ft.type.issubclass(x, y)
    if ft.type.isclass(x) then
        return x._ft_issubclassof(y)
    else
        return ft.type.issame(x, y)
    end
    return false
end;

function ft.type.issamebase(x, y)
    return ft.type.base(x) == ft.type.base(y)
end;

function ft.type.base(x)
    if ft.type.isclass(x) then
        return x._ft_getbasetype()
    end
    return ft.type(x)
end;

return ft;