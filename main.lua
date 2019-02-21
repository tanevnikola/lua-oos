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
        a.foo();
    end;
    
    foo = function()
        print(a);
    end;
});

ann.annotate(
    luna.stereotype["@Component"] {
    }
)(ns.B() {
    { print = print };
    
    constructor = function(a)
    end;
    
    foo = function()
        print("DSADS");
    end;
});

luna.ctx.Loader().load();
