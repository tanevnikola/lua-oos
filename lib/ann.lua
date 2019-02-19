return function(ft)
    local registry = setmetatable({}, {__mode = "k"});
    
    ft.class.annotation.Annotation() {
        { print = print; tostring = tostring };
        
        constructor = function(md)
            annotate = function(o)
                registry[o] = registry[o] or {};
                registry[o][ft.type(this)] = md;
                return o;
            end
        end;
        
        __call = function(o)
            return annotate(o);
        end
    }
    
    function ft.class.annotation.get(o, ann)
        ann = ft.type(ann);
        return registry[o] and registry[o][ann] or {};
    end
    
    function ft.class.annotation.getAll(o)
        return registry[o] or {};
    end

    return ft;
end
