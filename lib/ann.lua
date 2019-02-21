local oos = require "lib.oos"

local ns = oos.class.ann;

local registry = setmetatable({}, {__mode = "k"});

ns.Annotation() {
    { };

    constructor = function(md)
        annotate = function(o)
            registry[o] = registry[o] or {};
            registry[o][oos.type(this)] = md or {};
            return o;
        end
    end;

    __call = function(o)
        return annotate(o);
    end
}

local function getMetadata(o, a)
    return registry[o] and registry[o][a] or {};
end

local function getAnnotations(o)
    return registry[o] or {};
end

local function getAnnotated(a)
    local result = {}
    for k,v in pairs(registry) do
        table.insert(result, v[a] and k or nil)
    end
    return result;
end

local function annotate(...)
    local annotations = {...}
    return function(o)
        for k,v in pairs(annotations) do
            v(o);
        end
        return o;
    end
end



return {
    annotate            = annotate;

    getMetadata         = getMetadata;
    getAnnotations      = getAnnotations;
    getAnnotated        = getAnnotated;
    
    Annotation          = ns.Annotation;
};
