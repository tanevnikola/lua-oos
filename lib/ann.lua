local oos = require "lib.oos"

local ns = oos.class.ann[oos.utils.uuid()];

local registry = setmetatable({}, {__mode = "k"});

ns.Annotation() {
    { print = print; tostring = tostring };

    constructor = function(md)
        annotate = function(o)
            registry[o] = registry[o] or {};
            registry[o][oos.type(this)] = md;
            return o;
        end
    end;

    __call = function(o)
        return annotate(o);
    end
}

local function getAnnotations(o, ann)
    ann = oos.type(ann);
    return registry[o] and registry[o][ann] or {};
end

local function getAllAnnotations(o)
    return registry[o] or {};
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

local function getAnnotated(annotation)
    local result = {}
    for k,v in pairs(registry) do
        table.insert(result, v[oos.type(annotation)] and k or nil)
    end
    return result;
end

return {
    annotate            = annotate;

    getAnnotations      = getAnnotations;
    getAllAnnotations   = getAllAnnotations;
    getAnnotated        = getAnnotated;
    
    Annotation          = ns.Annotation;
};
