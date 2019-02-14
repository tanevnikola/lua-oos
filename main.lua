local ft = require "lib/oos"

ft.class.reflection.Provider() {
  { print = print; };
  
  testBase = function()
    print("auuu"); 
  end;
}

ft.class.reflection.Listener(ft.class.reflection.Provider) {
  constructor = function() 
    print("hello"); 
  end;
  testExtended = function()
    print("auuu"); 
  end
  
}

local info = ft.reflection.getInfo(ft.class.reflection.Listener);
print(info.getName());
print(info.getClass());
print(ft.type(info.getClass()));
print(info.getBaseClassInfo().getName());
