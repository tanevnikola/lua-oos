return function(ft)
        local registry = setmetatable({}, {__mode = "k"});
        ft.class.annotation.Annotation() {
            constructor = function(md)
                function annotate(o)
                    registry[o] = md;
                    return o;
                end
            end;

            __call = function(o)
                return annotate(o);
            end
        }

        return ft;
end
