local oos = require "lib.oos"

local ns = oos.class.graph;

ns.Graph() {
    {
        pairs       = pairs,
        tostring    = tostring
    };
    
    constructor = function()
        registry = {}
        
        function vertexRegistry(x)
            registry[x] = registry[x] or {};
            return registry[x];
        end;
        
        hasPath = function(a, b)
            for _,v in pairs(vertexRegistry(a)) do
                if v == b or hasPath(v, b) then 
                    return true; 
                end
            end;
        end;
    end;

    addEdge = function(a, b)
        local reg = vertexRegistry(a);
        reg[b] = 
            hasPath(b, a) and oos.error("Circular dependency between '" .. tostring(a) .. "' and '" .. tostring(b) .. "'") 
            or 
            reg[b] and oos.error("Edge '" .. tostring(a) .. "' > '" .. tostring(b) .. "' already exists") 
            or b
    end;
}

return ns.Graph;