local ft = require "lib.ann"(require "lib/oos")
local class = ft.class;
local markAs = {
    Service = class.AnnExample(class.annotation.Annotation) {};
}


markAs.Service({
    a = "this is a service"
})(class.A() {

});

local md = class.annotation.get(class.A, class.AnnExample);
print(md.a);
