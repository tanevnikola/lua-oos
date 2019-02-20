local function throw(e)
    error(debug.traceback(e, 0));
end

local function try(f)
    local tryTable = {}

    local catchHandler;
    local finalizeHandler;

    local function stop(rethrow)
        local ok, e = pcall(f);
        if not ok and catchHandler then
            catchHandler(e);
        end
        if finalizeHandler then
            finalizeHandler();
        end
        
        if not ok and rethrow then
            throw(e)
        end
    end

    local finally;
    local function catch(handler)
        catchHandler = handler;
        return {
            finally     = finally;
            stop        = stop;
            continue    = function() return stop(true) end;
        }
    end;
    
    finally = function(handler)
        finalizeHandler = handler;
        return {
            stop        = stop;
            continue    = function() return stop(true) end;
        }
    end;

    return {
        stop        = stop;
        catch       = catch;
        finally     = finally;
    };
end;

return {
    throw   = throw;
    try     = try;
}