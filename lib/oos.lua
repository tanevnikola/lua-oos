local ft = {}




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
    istablelike = function(x) return type(x) == "table";                                                        end;
    
    isclass     = function(x) return type(x) == "table" and ft_type.isfunction(x._ft_gettype)                   end;
    
    -- compare types
    issame      = function(x, y) return ft_type(x) == ft_type(y);                                               end;
    isdifferent = function(x, y) return ft_type(x) ~= ft_type(y);                                               end;
    issamebase  = function(x, y) return ft_type.getbasetype(x) == ft_type.getbasetype(y);                       end;
    issubclass  = function(x, y) return ft_type.isclass(x) and x._ft_issubclassof(y) or ft_type.issame(x, y);   end;

    getbasetype = function(x) return ft_type.isclass(x) and x._ft_getbasetype() or ft_type(x)                   end;
}, 
{
    __call = function(this, x)
        local t = type(x)
        -- handle custom types
        if t == "table" and ft_type.isfunction(x._ft_gettype) then
            t = x._ft_gettype()
        end
        return t
    end
});

----------------------------------------------------------
-- error
----------------------------------------------------------
function ft_error(msg, level)
    error("\n\n[Error]\n" .. debug.traceback(msg, (level or 0) + 2));
    os.exit(-1);
end

local function instantiationError(msg, t)
    error("Cannot make instance of '" .. t .. "'\n[Reason]\n" .. msg .. "\n");
end

----------------------------------------------------------
-- reflection
----------------------------------------------------------
local annotationRegistry = setmetatable({}, {__mode = "kv"});
local function annotate(o, md) 
    annotationRegistry[o] = md;
    return o; 
end

local function getAnnotation(o) 
    return annotationRegistry[o]; 
end

local ft_reflection = {};

function ft_reflection.getInfo(o)
    return getAnnotation(o);
end

----------------------------------------------------------
-- oos
----------------------------------------------------------

-- env    : the environment to extend
-- c      : class definition
local function extendEnv(env, c)
    env = c._ft_base and extendEnv(env, c._ft_base) or env;
    
    local mex = c[1];
    
    if ft_type.istable(mex) then
        for k, v in pairs(mex) do
            if env[k] then
                instantiationError("Duplicate field '" .. k ..  "' found in MEX", ft_type(c));
            end
            if ft_type.isboolean(v) or ft_type.isnumber(v) or ft_type.isstring(v) then
                instantiationError("Invalid type '" .. ft_type(v) .. "' found in MEX", ft_type(c));
            end
            env[k] = v;
        end
    end
    return env;
end

-- n      : the method name
-- f      : the function to create method from
-- c      : class definition
-- icctx  : class instance creation context
local function loadMethodFunction(n, f, c, icctx)
    local env = icctx.env.public[c];
    
    -- create the method
    local method = load(string.dump(f, true), nil, "b", nil);
    local i = 1;
    local  up = debug.getupvalue(f, i);
    while up do
        if up == "_ENV" then
            debug.setupvalue(method, i, env);
        elseif env[up] then
            instantiationError("Ambiguous field '" .. up .. "' found in MEX, there is an upvalue with the same name", ft_type(c));
        else
            debug.upvaluejoin(method, i, f, i);
        end
        i = i + 1;
        up = debug.getupvalue(f, i);
    end;
    
    if n == "constructor" then
        icctx.constructors[c] = method;
        method = nil;
    end

    return method;
end

local createMethods; -- forward declaration

-- n      : the method name
-- f      : the function to create method from
-- c      : class definition
-- icctx  : class instance creation context
local function createMethod(n, f, c, icctx)
    if not icctx.env.public[c] then
        icctx.env.public[c] = setmetatable(extendEnv({ this = icctx.instance }, c), {
            __newindex = function(_, k, v) 
              icctx.env.private[k] = v;
            end;
            
            __index = function(_, k, v) 
              return rawget(icctx.env.public[c], k) or icctx.env.private[k]
            end;
        });
        -- super
        if c._ft_base then
          rawset(icctx.env.public[c], "super", createMethods({}, c._ft_base, icctx));
        end
    end
    
    local methodFunction = loadMethodFunction(n, f, c, icctx);
    
    if methodFunction then
        local methodMetadata = {
            getClass        = function() return c; end;
            getSimpleName   = function() return n; end;
            getName         = function() return c._ft_gettype() .. ":" .. n; end;
        };
        return setmetatable(methodMetadata, { __call = function(_, ...) return methodFunction(...); end });
    end
    
    return nil;
end

-- h      : host, the table that will host the methods
-- c      : class definition
-- icctx  : class instance creation context
createMethods = function(h, c, icctx)
    for k, v in pairs(c) do
        local funcIsUtility = (string.find(k, "_ft_") == 1)
        if not h[k] then
            if ft_type.isfunction(v) and not funcIsUtility then
                h[k] = createMethod(k, v, c, icctx);
            elseif ft_type.isfunction(v) and funcIsUtility then
                h[k] = v;
            elseif not ft_type.isfunction(v) and not (ft_type.istable(v) and k == 1) then
                instantiationError("Invalid field '" .. k .. "' (of type '" .. ft_type(v) .. "') found in class definition", ft_type(c));
            end
        end
    end
    return (c._ft_base and createMethods(h, c._ft_base, icctx) or true) and h;
end

local function createInstance(c, ...)
    -- the instance creation context
    local icctx = {
      instance      = {},
      constructors  = setmetatable({}, {__mode = "kv"}),
      env           = {
          private = setmetatable({}, {__mode = "kv"}),
          public = setmetatable({}, {__mode = "kv"})
      },
    }
    
    createMethods(icctx.instance, c, icctx);
    
    -- invoke constructor
    local function invokeconstructor(c, ...)
        if c._ft_base then 
            invokeconstructor(c._ft_base, ...)
        end
        local _ = icctx.constructors[c] and icctx.constructors[c](...);
    end
    invokeconstructor(c, ...);
    
    -- protect the instance
    local pInstance = setmetatable(icctx.instance, {
        __metatable = {};
        __index = function(self, k)
          return rawget(self, k) or error("No field named '" .. ft_type(icctx.instance) .. ":" .. k .. "'");
        end;
        __newindex = function(self, k, v) 
          error("Cannot set value for field '" .. ft_type(icctx.instance) .. ":" .. k .. "'");
        end;
        
        __call = function(self, ...)
          if ft_type.isfunction(self.__call) then return self.__call(...) end
        end;
    });
    
    return pInstance;
end;

local function defineClass(classpath, base, c)
    -- static methods for each instance - dont have this and super
    function c._ft_gettype      ()          return tostring(classpath);                                                         end
    function c._ft_getbasetype  ()          return base and base._ft_getbasetype() or ft_type(c);                               end
    function c._ft_issubclassof (x)         return ((ft_type(c) == ft_type(x)) or (base and base._ft_issubclassof(x))) == true; end
    
    -- meta
    local class_mtbl;
    class_mtbl = { _ft_base = base; __metatable = {};  __call = createInstance; __index = function(_, key) return class_mtbl[key]; end}
    
    return setmetatable(c, class_mtbl);
end;

local ft_class = {_ft_ns = "ft.class"};

local class_functor_mtbl
class_functor_mtbl = {
  __metatable = {},
  __call = function(self, ...) 
    if ft_type.isclass(self._ft_classdef) then
      local status, result = pcall(self._ft_classdef, ...);
      return status and result or ft_error(result, 1);
    else
      local arg = {...};
      local base = arg[1];
      local baseclass = ft_type.isclass(base) and ft_type.isclass(base._ft_classdef) and base._ft_classdef or ft_type.isclass(base) and base  or nil;  
      if base and not baseclass then
        ft_error("invalid base class provided. Expected 'class <classname>' got '" .. ft_type(base) .. "'", 1);
      end
      
      return function(classdef)
        local status, result = pcall(defineClass, self._ft_ns, baseclass, classdef);

        if not status then ft_error(result, 1) end
        self._ft_classdef = result;
        --self._ft_gettype = function() return ft_type(self._ft_classdef); end;

        annotate(self._ft_classdef, {
            getClass          = function() return self._ft_classdef;        end;
            getName           = function() return self._ft_ns;              end;
            getBaseClassInfo  = function() return getAnnotation(baseclass); end;
        });

        return self._ft_classdef;
      end;
    end;
  end;
  
  __index = function(self, key)
      if rawget(self, "nsRecord") == nil then
          self.nsRecord = {};
      end
      
      if string.sub(key, 1, string.len("_ft_"))=="_ft_" then
          return rawget(self, key);
      end;
      self.nsRecord[key] = self.nsRecord[key] or setmetatable({_ft_ns = rawget(self, "_ft_ns") .. "." .. key}, class_functor_mtbl);
      return self.nsRecord[key]._ft_classdef or self.nsRecord[key];
  end;
};


setmetatable(ft_class, {
    __index = class_functor_mtbl.__index;
});


ft.type = ft_type;
ft.class = ft_class;
ft.reflection = ft_reflection;

return ft;