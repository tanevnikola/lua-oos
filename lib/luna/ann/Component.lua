return function(ns)
    local ann = require "lib.ann"

    return ns.stereotype.Component(ann.Annotation){}({})
end