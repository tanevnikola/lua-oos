local oos       = require "lib.oos"
local ann       = require "lib.ann"
local Graph     = require "lib.graph.graph"

local ns = oos.class.luna;

local stereotype = {
    ["@Component"] = (require "lib.luna.stereotype.Component")(ns, ann);
}

local ctx = (require "lib.luna.ctx")(oos, ns, stereotype, ann, Graph);

return {
    stereotype  = stereotype;
    ctx         = ctx;
};