local oos       = require "lib.oos"
local ann       = require "lib.ann"
local luna      = require "lib.luna.luna"

local ns = oos.class;

ann.annotate(
    luna.stereotype["@Component"]{
    }
)(ns.B(){
    {print = print};
    
    constructor = function()
        print("_B")
    end;
    
     foo = function()
        print("foo _B")
    end;
});

ann.annotate(
    luna.stereotype["@Component"] {
        ns.B
    }
)(ns.A() {
    { print = print };
    
    constructor = function(x)
        x.foo();
        print("A")
    end;
    
    foo = function()
        print("foo A")
    end;
});

luna.ctx.Loader().load();
