Fast and powerful OOP library for Lua. Generates simple classes without metatables. 

The code is readable and people with OOP experience will feel at home using it.

```lua
ft.class.Test() {
    -- capture global print
    {print = print};
    
    constructor = function()
        print("Hello World!")
    end;
}
local example1 = ft.class.Test();
```

## Features:
- Inheritance,
- Dynamic polymorphism,
- Encapsulation,
- Static variables,
- Namespaces,
- Sandboxing,
- Utilities such as: isclass, issubclass, issamebase, issame, isdifferent...

[Documentation](../../wiki)

** Under work **
