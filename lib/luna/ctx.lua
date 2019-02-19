return function(oos, ns, stereotype, ann, Graph)

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
            local components = ann.getAnnotated(stereotype["@Component"]);
            
            local depGraph = Graph();
            
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
                local deps = getDependencies(v.c);
                local args = {};
                for _, dep in ipairs(deps) do
                    local b = oos.type.isclass(dep) and dep or oos.type.isfunction(dep) and dep() or nil;
                    if b then
                        table.insert(args, registry[b] or oos.error("Cannot create component '" .. oos.type(v.c) ..  "', missing dependency '" .. oos.type(b) .. "'"));
                    end
                end
                registry[v.c] = v.c(table.unpack(args));
            end
            
            
        end;
    }
    
    return {
        Loader = ns.ctx.Loader;
    };
end