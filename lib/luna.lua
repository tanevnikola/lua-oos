local oos = require "lib.oos"

local ns = oos.class.luna[oos.utils.uuid()];

return {
    stereotype = {
        ["@Component"] = (require "lib.luna.ann.Component"(ns));
    }
}