local exception = require "lib.ex"

exception.try(function()

local oos       = require "lib.oos"
local ann       = require "lib.ann"
local luna      = require "lib.luna"

local ns = oos.class;


ann.annotate(
    luna.stereotype["@Component"] {
        ns.B
    }
)(ns.A() {
    { print = print };
    
    constructor = function(a)
        print(a)
        a.foo();
    end;
    
    foo = function()
        print("DSADS");
    end;
});
ann.annotate(
    luna.stereotype["@Component"] {
    }
)(ns.B() {
    { print = print };
    
    constructor = function()
    this.a=5;
    end;
    
    foo = function()
        print("DSADS");
    end;
});

luna.ctx.Loader().load()

end)
.continue(function(ex)
    return (ex.error or ex) .. (ex.traceback and ("\n" .. ex.traceback) or "");
end);

