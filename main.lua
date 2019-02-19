local oos   = require "lib.oos"
local ann   = require "lib.ann"
local luna  = require "lib.luna"

local ns = oos.class;

local classA = ann.annotate(
    luna.stereotype["@Component"]
)(
ns.A(){

});


local annotated = ann.getAnnotated(luna.stereotype["@Component"])
print(oos.type(annotated[1]));
print(oos.type(classA))