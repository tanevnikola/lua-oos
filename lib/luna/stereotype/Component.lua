return function(ns, ann)
    return ns.ann.stereotype["@Component"](ann.Annotation){};
end