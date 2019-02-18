local ft = {}

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
        CLASS   = "ft.stereotype.CLASS",
        METHOD  = "ft.stereotype.METHOD",
    }
};

function ft_reflection.getInfo(o)
    return setmetatable({}, {__index = function(_, x) return getAnnotation(o)[x]; end;});
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
        return ann and (ann.getStereotype() == ft_reflection.stereotype.METHOD) or false;
    end;

    isclass     = function(x) 
        local ann = getAnnotation(x); 
        return ann and (ann.getStereotype() == ft_reflection.stereotype.CLASS) or false;
    end;
    
    issubclass  = function(x, y)
        local ann = getAnnotation(x);
        local baseX = ann and ann.getBaseClassInfo()
        return ft_type.issame(x, y) or baseX and ft_type.issubclass(baseX.getClass(), y) or false;
    end;

    -- compare types
    issame      = function(x, y) return ft_type(x) == ft_type(y);                                               end;
    isdifferent = function(x, y) return ft_type(x) ~= ft_type(y);                                               end;
    issamebase  = function(x, y) return ft_type.getbasetype(x) == ft_type.getbasetype(y);                       end;

    getbasetype = function(x) 
        local ann = getAnnotation(x);
        return ann and ann.getBaseClassInfo() and ann.getBaseClassInfo().getName() or ft_type(x);
    end;
}, 
{
    __call = function(this, x)
        local ann = getAnnotation(x);
        return 
            ann 
            and 
                (((ann.getStereotype() == ft_reflection.stereotype.CLASS) and ann.getName()) 
                or
                (ann.getStereotype() == ft_reflection.stereotype.METHOD) and "method")
            or type(x)
    end
});

----------------------------------------------------------
-- error
----------------------------------------------------------
local function ft_error(msg, level)
    error(debug.traceback("\n[Error]\n" .. msg, (level or 0) + 2));
    os.exit(-1);
end

local function instantiationError(msg, t)
    ft_error("Cannot make instance of '" .. t .. "'\n[Reason]\n" .. msg, 1);
end

----------------------------------------------------------
-- oos
----------------------------------------------------------

-- env    : the environment to extend
-- c      : class definition
local function extendEnv(env, c)
    local mex = c[1];
    
    if ft_type.istable(mex) then
        for k, v in pairs(mex) do
            if env[k] then
                instantiationError("Duplicate field '" .. k ..  "' found in MEX", ft_type(c));
            end
            if not ft_type.isfunction(v) then
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
    local env = icctx.env.internal[c];
    
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
    else
        annotate(method, getAnnotation(f))
    end

    return method;
end

local createMethods; -- forward declaration

-- n      : the method name
-- f      : the function to create method from
-- c      : class definition
-- icctx  : class instance creation context
local function createMethod(n, f, c, icctx)
    if not icctx.env.internal[c] then
        icctx.env.internal[c] = setmetatable(extendEnv({ this = icctx.instance }, c), {
            __newindex = function(_, k, v) 
              icctx.env.private[k] = v;
            end;
            
            __index = function(_, k, v) 
              return rawget(icctx.env.internal[c], k) or icctx.env.private[k]
            end;
        });
        -- super
        if c._ft_base then
          rawset(icctx.env.internal[c], "super", createMethods({}, c._ft_base, icctx));
        end
    end
    
    return loadMethodFunction(n, f, c, icctx);
end

-- h      : host, the table that will host the methods
-- c      : class definition
-- icctx  : class instance creation context
createMethods = function(h, c, icctx)
    for k, v in pairs(c) do
        if not h[k] then
            if ft_type.ismethod(v) then
                h[k] = createMethod(k, v, c, icctx);
            elseif ft_type.isfunction(v) then
                h[k] = v;
            elseif not ft_type.isfunction(v) and not (ft_type.istable(v) and k == 1) then
                instantiationError("Invalid field '" .. k .. "' (of type '" .. ft_type(v) .. "') found in class definition", ft_type(c));
            end
        end
    end
    return h;
end

local function createInstance(c, ...)
    -- the instance creation context
    local icctx = {
      instance      = {},
      constructors  = setmetatable({}, {__mode = "kv"}),
      env           = {
          private   = setmetatable({}, {__mode = "kv"}),
          internal  = setmetatable({}, {__mode = "kv"})
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
    
    return annotate(pInstance, getAnnotation(c));
end;

local function defineClass(classpath, base, cl)

    local c = {};
    local function copyMembers(class)
        local ann = getAnnotation(class)
        local base = ann and ann.getBaseClassInfo() and ann.getBaseClassInfo().getClass()
        if base then copyMembers(base) end
        
        for k, v in pairs(class) do
            c[k] = v;
        end
        return c;
    end
    
    c = base and copyMembers(base) and copyMembers(cl) or copyMembers(cl);

    -- meta
    local class_mtbl;
    class_mtbl = { _ft_base = base; __metatable = {}; __call = createInstance; __newindex = function() ft_error("Cannot extend classes"); end; __index = function(_, key) return class_mtbl[key]; end}
    
    return setmetatable(c, class_mtbl);
end;

local ft_class = {_ft_ns = "ft.class", _ft_ns_simple = "ft.class"};

local class_functor_mtbl
class_functor_mtbl = {
  __metatable = {},
  __call = function(self, ...) 
    local arg = {...};
    local base = arg[1];
    local baseclass = ft_type.isclass(base) and ft_type.isclass(base._ft_classdef) and base._ft_classdef or ft_type.isclass(base) and base  or nil;  
    if base and not baseclass then
        ft_error("invalid base class provided. Expected 'class <classname>' got '" .. ft_type(base) .. "'", 1);
    end
      
    return function(classdef)
        self._ft_classdef = annotate(defineClass(self._ft_ns, baseclass, classdef), {
            getStereotype     = function() return ft_reflection.stereotype.CLASS;           end;
            getName           = function() return self._ft_ns;                              end;
            getSimpleName     = function() return self._ft_ns_simple;                       end;
            
            getClass          = function() return self._ft_classdef;                        end;

            getBaseClassInfo  = function() return baseclass and getAnnotation(baseclass);   end;
        });
        for k, v in pairs(self._ft_classdef) do
            if ft_type.isfunction(v) then
                annotate(v, {
                    getStereotype     = function() return ft_reflection.stereotype.METHOD;  end;
                    getName           = function() return self._ft_ns .. ":" .. k;          end;
                    getSimpleName     = function() return k;                                end;

                    getClassInfo      = function() return getAnnotation(self._ft_classdef); end;
                });
            end
        end
    end;
  end;
  
  __index = function(self, key)
      if rawget(self, "classRecord") == nil then
          self.classRecord = {};
      end
      
      if string.sub(key, 1, string.len("_ft_"))=="_ft_" then
          return rawget(self, key);
      end;
      self.classRecord[key] = self.classRecord[key] or setmetatable({_ft_ns = rawget(self, "_ft_ns") .. "." .. key, _ft_ns_simple = key}, class_functor_mtbl);
      return self.classRecord[key]._ft_classdef or self.classRecord[key];
  end;
};


setmetatable(ft_class, {
    __index = class_functor_mtbl.__index;
});


ft.type = ft_type;
ft.class = ft_class;
ft.reflection = ft_reflection;
ft.error = ft_error

return ft;