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
        print("B")
    end;
    
    foo = function()
        print("there is foo in B")
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

print(debug.traceback())

exception.throw("")

luna.ctx.Loader().load()

end)
.continue(function(a,b)
 return debug.traceback(); end);