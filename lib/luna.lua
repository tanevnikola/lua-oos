local oos       = require "lib.oos"
local ann       = require "lib.ann"
local ex        = require "lib.ex"

local ns = oos.class.luna;

local stereotype = {
    ["@Component"] =  ns.ann.stereotype["@Component"](ann.Annotation){};
}

local DependencyGraph = ns.__hidden__.DependencyGraph() {
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
            hasPath(b, a) and ex.throw("Circular dependency between '" .. tostring(a) .. "' and '" .. tostring(b) .. "'", 2)
            or
            reg[b] and ex.throw("Edge '" .. tostring(a) .. "' > '" .. tostring(b) .. "' already exists", 2)
            or b
    end;
}

ns.ctx.Loader() {
    {
        pairs = pairs,
        ipairs = ipairs,
        table = table
    }; -- mex

    constructor = function()
        registry = {};

        function getDependencies(c)
            return ann.getMetadata(c, stereotype["@Component"]);
        end
    end;

    load = function()
        local function instantiate(c)
            if not registry[c] then
                local deps = getDependencies(c);
                local args = {};
                for _, dep in ipairs(deps) do
                    local b = oos.type.isclass(dep) and dep or oos.type.isfunction(dep) and dep() or nil;
                    if b then
                        table.insert(args, registry[b] or instantiate(b) or ex.throw("Cannot create component '" .. oos.type(c) ..  "', missing dependency '" .. oos.type(b) .. "'"));
                    end
                end
                registry[c] = c(table.unpack(args));
            end
            return registry[c]
        end

        local components = ann.getAnnotated(stereotype["@Component"]);
        local depGraph = DependencyGraph();
        local compDep = {}
        for _,a in pairs(components) do
            local numDep = 0
            for var, dep in pairs(getDependencies(a)) do
                local b = oos.type.isclass(dep) and dep or oos.type.isfunction(dep) and dep() or nil;
                if b then
                    depGraph.addEdge(oos.type(a), oos.type(b));
                    numDep = numDep + 1;
                end;
            end
            table.insert(compDep, { c = a, n = numDep });
        end

        table.sort(compDep, function(a, b) return a.n < b.n; end)
        for _, v in pairs(compDep) do
            instantiate(v.c);
        end


    end;
}

return {
    stereotype  = stereotype;
    ctx         = { Loader = ns.ctx.Loader };
};
