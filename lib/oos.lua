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
        LUA             = "LUA",
        NAMESPACE       = "NAMESPACE",
        CLASS           = "CLASS",
        CLASS_INSTANCE  = "CLASS_INSTANCE",
        METHOD          = "METHOD",
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

    ismethod        = function(x)
        return ft_type.getstereotype(x) == ft_reflection.stereotype.METHOD;
    end;

    isclass         = function(x)
        return ft_type.getstereotype(x) == ft_reflection.stereotype.CLASS;
    end;

    isclassinstance = function(x)
        return ft_type.getstereotype(x) == ft_reflection.stereotype.CLASS_INSTANCE;
    end;

    issubclass      = function(x, y)
        local annX = getAnnotation(x);
        local annY = getAnnotation(y);
        return 
            (ft_type.isclass(x) or ft_type.isclassinstance(x)) and (ft_type.isclass(y) or ft_type.isclassinstance(y))
            and (annX.name == annY.name or annX.base and ft_type.issubclass(annX.base.class, y) or false);
    end;

    -- compare types
    issame      = function(x, y) return ft_type(x) == ft_type(y);                                               end;
    isdifferent = function(x, y) return ft_type(x) ~= ft_type(y);                                               end;
    issamebase  = function(x, y) return ft_type.getbasetype(x) == ft_type.getbasetype(y);                       end;

    getbasetype = function(x)
        local ann = getAnnotation(x);
        return ann and ann.base and ann.base.name or ft_type(x);
    end;
    
    getstereotype = function(x)
        local a = getAnnotation(x);
        return a and a.stereotype or ft_reflection.stereotype.LUA;
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
            or
            (ann.stereotype == ft_reflection.stereotype.NAMESPACE) and "namespace"
            or
            (ann.stereotype == ft_reflection.stereotype.CLASS_INSTANCE) and ann.class
            
            )
            or type(x)
    end
});

----------------------------------------------------------
-- oos
----------------------------------------------------------

-- env    : the environment to extend
-- cInfo  : class info
local function extendEnv(env, cInfo)
    env = cInfo.base and extendEnv(env, cInfo.base) or env;
    local mex = cInfo.class.classdef[1];

    if ft_type.istable(mex) then
        for k, v in pairs(mex) do
            if env[k] then
                instantiationError("duplicate field '" .. k ..  "' found in MEX", ft_type(cInfo.class));
            end
            if not (ft_type.isfunction(v) or ft_type.istablelike(v) or ft_type.isfunction(v)) then
                instantiationError("invalid type '" .. ft_type(v) .. "' found in MEX", ft_type(cInfo.class));
            end
            env[k] = v;
        end
    end
    return env;
end

-- f      : the function to create method from
-- cInfo  : class info
-- icctx  : class instance creation context
local function loadMethodFunction(f, cInfo, icctx)
    local env = icctx.env.internal[cInfo];

    -- create the method
    local method = load(string.dump(f));
    local i = 1;
    local  up = debug.getupvalue(f, i);
    while up do
        if up == "_ENV" then
            debug.setupvalue(method, i, env);
        elseif env[up] then
            instantiationError("ambiguous field '" .. up .. "' found in MEX, there is an upvalue with the same name", ft_type(cInfo.class));
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
-- cInfo  : class info
-- icctx  : class instance creation context
local function createMethod(f, cInfo, icctx)
    if not icctx.env.internal[cInfo] then
        icctx.env.internal[cInfo] = setmetatable(extendEnv({ this = icctx.instance }, cInfo), {
            __newindex = function(_, k, v)
                icctx.env.private[k] = v;
            end;

            __index = function(_, k, v)
                return icctx.env.private[k]
            end;
        });
        -- super
        if cInfo.base then
            rawset(icctx.env.internal[cInfo], "super", createMethods({}, cInfo.base, icctx));
        end
    end

    return loadMethodFunction(f, cInfo, icctx);
end

-- h      : host, the table that will host the methods
-- cInfo  : class info
-- icctx  : class instance creation context
createMethods = function(h, cInfo, icctx)
    for k, v in pairs(cInfo.class.classdef) do
        if k ~= "constructor" and not h[k] then
            if ft_type.ismethod(v) then
                h[k] = createMethod(v, cInfo, icctx);
                h[k] = h[k] and annotate(h[k], getAnnotation(v));
            elseif ft_type.isfunction(v) then
                h[k] = v;
            elseif not ft_type.isfunction(v) and not (ft_type.istable(v) and k == 1) then
                instantiationError("invalid field '" .. k .. "' (of type '" .. ft_type(v) .. "') found in class definition", ft_type(cInfo.class));
            end
        end
    end
    return cInfo.base and createMethods(h, cInfo.base, icctx) or h;
end

local function createInstance(cInfo, ...)
    local cInstanceInfo = {}
    for k, v in pairs(cInfo) do
        cInstanceInfo[k] = cInfo[k];
    end
    cInstanceInfo.stereotype = ft_reflection.stereotype.CLASS_INSTANCE;

    -- the instance creation context
    local icctx = {
        instance        = annotate({}, cInstanceInfo),
        constructors    = {},
        env             = {
            private     = {},
            internal    = {}
        },
    }

    createMethods(icctx.instance, cInfo, icctx);

    -- invoke constructor
    local function invokeconstructor(cInfo, ...)
        if cInfo.base then
            invokeconstructor(cInfo.base, ...)
        end
        local constructor = cInfo.class.classdef.constructor and createMethod(cInfo.class.classdef.constructor, cInfo, icctx);
        local _ = constructor and constructor(...);
    end
    invokeconstructor(cInfo, ...);

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
        local info = ft_type.isclass(self);
        if info then
            return createInstance(ft_reflection.getInfo(self), ...);
        end
        
        local baseClass = ({...})[1];
        if baseClass and not ft_type.isclass(baseClass) then
            exception.throw("invalid base class provided. Expected '<classname>' got '" .. ft_type(baseClass) .. "'", 1);
        end

        return function(...)
            self.classdef = ({...})[1];
            local methodAnnotations = {}

            annotate(self, {
                class               = self;
                
                stereotype          = ft_reflection.stereotype.CLASS;
                name                = self._ft_ns;
                simpleName          = self._ft_ns_simple;
                base                = baseClass and getAnnotation(baseClass) or nil;
                methods             = methodAnnotations;
            });
            
            for k, v in pairs(self.classdef) do
                if ft_type.isfunction(v) and k ~= "constructor" then
                    annotate(v, {
                        stereotype          = ft_reflection.stereotype.METHOD;
                        name                = self._ft_ns .. "." .. k;
                        simpleName          = k;
                        classInfo           = getAnnotation(self);
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
        return annotate(self[key], {
            stereotype  = ft_reflection.stereotype.NAMESPACE;
        });
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
