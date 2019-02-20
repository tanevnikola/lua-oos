local function throw(e)
    error(e, 7);
end

local function try(f)
    local tryTable = {}

    local catchHandler;
    local finallyHandler;

    local function stop(convertHandler)
        local ok, e = pcall(f);
        
        if not ok and catchHandler then
            catchHandler(e);
        end
        
        if finallyHandler then
            finallyHandler();
        end
        
        if not ok and convertHandler then
            e = (type(convertHandler) == "function" and convertHandler(e) or e);
            throw(e);
        end
    end
    
    local function continue(convertHandler)
        return stop(convertHandler or true)
    end

    local finally;
    local function catch(handler)
        catchHandler = handler;
        return {
            finally     = finally;
            stop        = stop;
            continue    = continue;
        }
    end;
    
    finally = function(handler)
        finallyHandler = handler;
        return {
            stop        = stop;
            continue    = continue;
        }
    end;

    return {
        stop        = stop;
        catch       = catch;
        finally     = finally;
        continue    = continue;
    };
end;

return {
    throw   = throw;
    try     = try;
}