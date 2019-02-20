local oos       = require "lib.oos"
local ann       = require "lib.ann"

local ns = oos.class.luna;

local stereotype = {
    ["@Component"] = (require "lib.luna.stereotype.Component")(ns, ann);
}

return {
    stereotype  = stereotype;
    ctx         = { Loader = (require "lib.luna.ctx")(oos, ns, stereotype, ann)};
};