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
        print("foo _B")
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
        print("foo B")
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
        print("foo A")
    end;
});

ann.annotate(
    luna.stereotype["@Component"] {
        ns._B
    }
)(ns.A1() {
    { print = print };
    
    constructor = function(_b)
        _b.foo();
        print("A1")
    end;
    
    foo = function()
        print("foo A1")
    end;
});

ann.annotate(
    luna.stereotype["@Component"] {
        ns.A1
    }
)(ns.A2() {
    { print = print };
    
    constructor = function(_b)
        _b.foo();
        print("A2")
    end;
    
    foo = function()
        print("foo A2")
    end;
});

ann.annotate(
    luna.stereotype["@Component"] {
        ns.A2
    }
)(ns.A3() {
    { print = print };
    
    constructor = function(_b)
        _b.foo();
        print("A3")
    end;
    
    foo = function()
        print("foo A3")
    end;
});


luna.ctx.Loader().load();
