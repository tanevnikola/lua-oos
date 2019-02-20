local exception = require "lib.ex"
----------------------------------------------------------
-- error
----------------------------------------------------------
local function instantiationError(msg, t)
    exception.throw("Cannot make instance of '" .. t .. "'\nReason: " .. msg, 1);
end

----------------------------------------------------------
-- reflection
----------------------------------------------------------
local annotationRegistry = setmetatable({}, {__mode = "k"});
local function annotate(o, md)
    annotationRegistry[o] = md;
    return o;
end

local function getAnnotation(o)
    return annotationRegistry[o];
end

local ft_reflection = {
    stereotype = {
        CLASS   = "CLASS",
        METHOD  = "METHOD",
    }
};

function ft_reflection.getInfo(o)
    return getAnnotation(o);
end

----------------------------------------------------------
-- type
----------------------------------------------------------

local ft_type;
ft_type = setmetatable({
    -- base types validation
    isnil       = function(x) return x == nil;                                                                  end;
    isboolean   = function(x) return ft_type(x) == "boolean";                                                   end;
    isstring    = function(x) return ft_type(x) == "string";                                                    end;
    isnumber    = function(x) return ft_type(x) == "number";                                                    end;
    isfunction  = function(x) return ft_type(x) == "function";                                                  end;
    istable     = function(x) return ft_type(x) == "table";                                                     end;
    istablelike = function(x) return type(x)    == "table";                                                     end;

    ismethod    = function(x)
        local ann = getAnnotation(x);
        return ann and (ann.stereotype == ft_reflection.stereotype.METHOD) or false;
    end;

    isclass     = function(x)
        local ann = getAnnotation(x);
        return ann and (ann.stereotype == ft_reflection.stereotype.CLASS) or false;
    end;

    isobject    = function(x)
        local ann = getAnnotation(x);
        return ann and (ann.stereotype == ft_reflection.stereotype.CLASS) or false;
    end;

    issubclass  = function(x, y)
        local ann = getAnnotation(x);
        local baseX = ann and ann.base
        return ft_type.issame(x, y) or baseX and ft_type.issubclass(baseX.class, y) or false;
    end;

    -- compare types
    issame      = function(x, y) return ft_type(x) == ft_type(y);                                               end;
    isdifferent = function(x, y) return ft_type(x) ~= ft_type(y);                                               end;
    issamebase  = function(x, y) return ft_type.getbasetype(x) == ft_type.getbasetype(y);                       end;

    getbasetype = function(x)
        local ann = getAnnotation(x);
        return ann and ann.base and ann.base.name or ft_type(x);
    end;
},
{
    __call = function(_, x)
        local ann = getAnnotation(x);
        return
            ann
            and
            (   (ann.stereotype == ft_reflection.stereotype.CLASS) and ann.name
            or
            (ann.stereotype == ft_reflection.stereotype.METHOD) and "method"
            )
            or type(x)
    end
});

----------------------------------------------------------
-- oos
----------------------------------------------------------

-- env    : the environment to extend
-- c      : class definition
local function extendEnv(env, c)
    local cInfo = getAnnotation(c);
    local baseClass = cInfo and cInfo.base and cInfo.base.class;

    env = baseClass and extendEnv(env, baseClass) or env;
    local mex = c[1];

    if ft_type.istable(mex) then
        for k, v in pairs(mex) do
            if env[k] then
                instantiationError("duplicate field '" .. k ..  "' found in MEX", ft_type(c));
            end
            if not (ft_type.isfunction(v) or ft_type.istablelike(v) or ft_type.isfunction(v)) then
                instantiationError("invalid type '" .. ft_type(v) .. "' found in MEX", ft_type(c));
            end
            env[k] = v;
        end
    end
    return env;
end

-- f      : the function to create method from
-- c      : class definition
-- icctx  : class instance creation context
local function loadMethodFunction(f, c, icctx)
    local env = icctx.env.internal[c];

    -- create the method
    local method = load(string.dump(f, true), nil, "b", nil);
    local i = 1;
    local  up = debug.getupvalue(f, i);
    while up do
        if up == "_ENV" then
            debug.setupvalue(method, i, env);
        elseif env[up] then
            instantiationError("ambiguous field '" .. up .. "' found in MEX, there is an upvalue with the same name", ft_type(c));
        else
            debug.upvaluejoin(method, i, f, i);
        end
        i = i + 1;
        up = debug.getupvalue(f, i);
    end;

    return method;
end

local createMethods; -- forward declaration

-- f      : the function to create method from
-- c      : class definition
-- icctx  : class instance creation context
local function createMethod(f, c, icctx)
    if not icctx.env.internal[c] then
        icctx.env.internal[c] = setmetatable(extendEnv({ this = icctx.instance }, c), {
            __newindex = function(_, k, v)
                icctx.env.private[k] = v;
            end;

            __index = function(_, k, v)
                return icctx.env.private[k]
            end;
        });
        -- super
        local cInfo = getAnnotation(c);
        local baseClass = cInfo and cInfo.base and cInfo.base.class;
        if baseClass then
            rawset(icctx.env.internal[c], "super", createMethods({}, baseClass, icctx));
        end
    end

    return loadMethodFunction(f, c, icctx);
end

-- h      : host, the table that will host the methods
-- c      : class definition
-- icctx  : class instance creation context
createMethods = function(h, c, icctx)
    for k, v in pairs(c) do
        if k ~= "constructor" and not h[k] then
            if ft_type.ismethod(v) then
                h[k] = createMethod(v, c, icctx);
                h[k] = h[k] and annotate(h[k], getAnnotation(v));
            elseif ft_type.isfunction(v) then
                h[k] = v;
            elseif not ft_type.isfunction(v) and not (ft_type.istable(v) and k == 1) then
                instantiationError("invalid field '" .. k .. "' (of type '" .. ft_type(v) .. "') found in class definition", ft_type(c));
            end
        end
    end
    local cInfo = getAnnotation(c);
    local baseClass = cInfo and cInfo.base and cInfo.base.class;
    return baseClass and createMethods(h, baseClass, icctx) or h;
end

local function createInstance(c, ...)
    -- the instance creation context
    local icctx = {
        instance        = annotate({}, getAnnotation(c)),
        constructors    = {},
        env             = {
            private     = {},
            internal    = {}
        },
    }

    createMethods(icctx.instance, c, icctx);

    -- invoke constructor
    local function invokeconstructor(c, ...)
        local cInfo = getAnnotation(c);
        local baseClass = cInfo and cInfo.base and cInfo.base.class;    
        if baseClass then
            invokeconstructor(baseClass, ...)
        end
        local constructor = c.constructor and createMethod(c.constructor, c, icctx);
        local _ = constructor and constructor(...);
    end
    invokeconstructor(c, ...);

    -- protect the instance
    local pInstance = setmetatable(icctx.instance, {
        __metatable = {};

        __index = function(self, k)
            return 
                rawget(self, k)
                or 
                exception.throw("no field named '" .. ft_type(icctx.instance) .. ":" .. k .. "'");
        end;
        __newindex = function(self, k, v)
            exception.throw("cannot set value for field '" .. ft_type(icctx.instance) .. ":" .. k .. "'");
        end;

        __call = function(self, ...)
            if ft_type.ismethod(self.__call) then
                return self.__call(...)
            end
            exception.throw("attempt to call '" .. ft_type(icctx.instance) .. "' value");
        end;
    });

    return pInstance;
end;

local ft_class = {_ft_ns = "ns", _ft_ns_simple = "ns"};

local class_functor_mtbl
class_functor_mtbl = {
    __metatable = {},
    __call = function(self, ...)
        local info = getAnnotation(self);
        if info then
            return info.createInstance(...);
        end
        
        local base = ({...})[1];
        if base and not ft_type.isclass(base) then
            exception.throw("invalid base class provided. Expected '<classname>' got '" .. ft_type(base) .. "'", 1);
        end

        return function(...)
            local classdef = ({...})[1];
            local methodAnnotations = {}

            annotate(self, {
                class               = classdef;
                
                createInstance      = function(...) return createInstance(classdef, ...); end;

                stereotype          = ft_reflection.stereotype.CLASS;
                name                = self._ft_ns;
                simpleName          = self._ft_ns_simple;
                base                = base and getAnnotation(base) or nil;
                methods             = methodAnnotations;
            });
            annotate(classdef, getAnnotation(self));

            for k, v in pairs(classdef) do
                if ft_type.isfunction(v) and k ~= "constructor" then
                    annotate(v, {
                        stereotype          = ft_reflection.stereotype.METHOD;
                        name                = self._ft_ns .. "." .. k;
                        simpleName          = k;
                        class               = getAnnotation(self);
                    });

                    methodAnnotations[k] = getAnnotation(v);
                end
            end
            return self;
        end;
    end;

    __index = function(self, key)
        if string.sub(key, 1, string.len("_ft_")) =="_ft_" then
            return rawget(self, key);
        end;
        self[key] = setmetatable({_ft_ns = rawget(self, "_ft_ns") .. "." .. key, _ft_ns_simple = key}, class_functor_mtbl);
        return self[key];
    end;
};


setmetatable(ft_class, {
    __index = class_functor_mtbl.__index;
});

return {
    type            = ft_type;
    class           = ft_class;
    reflection      = ft_reflection;
};
