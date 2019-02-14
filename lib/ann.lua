return function(ft)

  ft.class.annotation.Annotation() {
    { registry = setmetatable({}, {__mode = "kv"}); };
    
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
  
  ft.class.annotation.Annotation.Utils(ft.class.annotation.Annotation) {
    getAnnotation = function(o) 
      return registry[o]; 
    end
  }
  
  return ft;
end