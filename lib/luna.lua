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
        depGraph = DependencyGraph();

        function getDependencies(c)
            return ann.getMetadata(c, stereotype["@Component"]);
        end
        
        function isValidComponentDependency(x)
            return oos.type.isclass(x);
        end

        function instantiate(c)
            if not registry[c] then
                -- resolve component dependencies (args passed to the constructor are ordered)
                local args = {};
                for _, dep in ipairs(getDependencies(c)) do
                    if not isValidComponentDependency(dep) then
                        exception.throw("cannot create component '" .. oos.type(c) ..  "', invalid dependency '" .. oos.type(dep) .. "'");
                    end;
                    table.insert(args, registry[dep] or instantiate(dep)
                        or exception.throw("cannot create component '" .. oos.type(c) ..  "', missing dependency '" .. oos.type(dep) .. "'"));

                    depGraph.validateDependency(oos.type(c), oos.type(dep));
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
        for _, c in pairs(components) do
            instantiate(c);
        end
        
        for _, c in pairs(registry) do
            local cInfo = oos.reflection.getInfo(c);
            if cInfo.methods.init then
                local args = {}
                for _, dep in ipairs(getDependencies(c)) do
                    table.insert(args, registry[dep] 
                        or exception.throw("cannot initialize component '" .. oos.type(c) ..  "', missing dependency '" .. oos.type(dep) .. "'"));

                    c.init(table.unpack(args))
                end
            end
        end
    end;
}

return {
    stereotype  = stereotype;
    ctx         = { Loader = ns.ctx.Loader };
};
