local oos       = require "lib.oos"
local ann       = require "lib.ann"
local luna      = require "lib.luna.luna"
local Graph     = require "lib.graph.graph"

local ns = oos.class;

ann.annotate(
    luna.stereotype["@Component"]{
    }
)(ns._B(){
    {print = print};
    
    constructor = function()
        print("_B")
    end;
    
     foo = function()
        print("dasdsads _B")
    end;
});

ann.annotate(
    luna.stereotype["@Component"]{
        function() return ns.A end;
    }
)(ns.B(){
    {print = print};
    
    constructor = function(a)
        a.foo();
        print("B")
    end;
    
    foo = function()
        print("dasdsads B")
    end;

});

ann.annotate(
    luna.stereotype["@Component"] {
        ns._B
    }
)(ns.A() {
    { print = print };
    
    constructor = function(_b)
        _b.foo();
        print("A")
    end;
    
    foo = function()
        print("DASDSA")
    end;
});


luna.ctx.Loader().load();
