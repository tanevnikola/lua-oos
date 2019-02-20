local exception = require "lib.ex"

exception.try(function()

local oos       = require "lib.oos"
local ann       = require "lib.ann"
local luna      = require "lib.luna"

local ns = oos.class;

ann.annotate(
    luna.stereotype["@Component"] {
        ns.A
    }
)(ns.B() {
    { print = print };
    
    constructor = function(x)
    end;
    
    foo = function()
    end;
});

ann.annotate(
    luna.stereotype["@Component"] {
    }
)(ns.A() {
    { print = print };
    
    constructor = function()
    this.a = 6;
    end;
    
    foo = function()
    end;
});

luna.ctx.Loader().load()

end)
.continue(function(ex)
    return (ex.error or ex) .. (ex.traceback and ("\n" .. ex.traceback) or "");
end);

