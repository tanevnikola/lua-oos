local oos       = require "lib.oos"
local ann       = require "lib.ann"
local exception = require "lib.ex"

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

        function hasPath (a, b)
            for _,v in pairs(vertexRegistry(a)) do
                if v == b or hasPath(v, b) then
                    return true;
                end
            end;
        end;
    end;

    validateDependency = function(a, b)
        local reg = vertexRegistry(a);
        reg[b] =
            hasPath(b, a) and exception.throw("circular dependency between '" .. tostring(a) .. "' and '" .. tostring(b) .. "'", 2)
            or
            reg[b] and exception.throw("edge '" .. tostring(a) .. "' > '" .. tostring(b) .. "' already exists", 2)
            or b
    end;
}

ns.ctx.Loader() {
    {
        pairs   = pairs;
        ipairs  = ipairs;
        table   = table;
    }; -- mex

    constructor = function()
        registry = {};

        function getDependencies(c)
            return ann.getMetadata(c, stereotype["@Component"]);
        end
        
        function forEachDependency(f)
            for _, dep in ipairs(ann.getMetadata(c, stereotype["@Component"])) do
                if not (oos.type.isclass(dep) or oos.type.isobject(dep)) then
                    exception.throw("invalid dependency '" .. oos.type(c) ..  "'");
                end;
                f(dep);
            end
        end

        function instantiate(c)
            if not registry[c] then
                local deps = getDependencies(c);
                -- resolve component dependencies (args passed to the constructor are ordered)
                local args = {};
                for _, dep in ipairs(deps) do
                    if not (oos.type.isclass(dep) or oos.type.isobject(dep)) then
                        exception.throw("cannot create component '" .. oos.type(c) ..  "', missing one or more dependencies");
                    end;
                    table.insert(args, registry[dep] or instantiate(dep)
                        or exception.throw("cannot create component '" .. oos.type(c) ..  "', missing dependency '" .. oos.type(dep) .. "'"));
                end
                -- create component instance
                registry[c] = c(table.unpack(args));
            end
            return registry[c]
        end
    end;

    load = function()
        -- validate dependencies and build dependency list
        local components = ann.getAnnotated(stereotype["@Component"]);
        local depGraph = DependencyGraph();
        local depList = {}
        for _,a in pairs(components) do
            local numDep = 0
            for var, dep in pairs(getDependencies(a)) do
                local b = (oos.type.isclass(dep) or oos.type.isobject(dep)) and dep or nil;
                if b then
                    depGraph.validateDependency(oos.type(a), oos.type(b));
                    numDep = numDep + 1;
                end;
            end
            table.insert(depList, { c = a, n = numDep });
        end

        -- instantiate components
        table.sort(depList, function(a, b) return a.n < b.n; end)
        for _, v in pairs(depList) do
            instantiate(v.c);
        end
    end;
}

return {
    stereotype  = stereotype;
    ctx         = { Loader = ns.ctx.Loader };
};
