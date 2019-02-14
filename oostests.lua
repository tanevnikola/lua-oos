local function assertErrorMessage(msg, f)
  local status, result = pcall(f);
  return not status and string.match(result, msg) and (print(result) or true) or error("\n\nnot found: '" .. msg .. "' in: " .. (result or "<NO ERROR FOUND>"))
end

local function inScope(f)
  return function()
    local status, result = pcall(f, require "lib/oos");
    package.loaded["lib/oos"] = nil
    if not status then error(result) end
  end
end

-------------------------- TESTS --------------------------
local function testNominalClassCreation()
  inScope(function(ft)
      ft.class.A() {}
      ft.class.A();
  end)()
end
testNominalClassCreation();

local function testInvalidTypeInMex()
    local function buildTest(x)
      return inScope(function(ft) 
        ft.class.A() {
          { x = x };
          constructor = function() f(x) end;
        }
        ft.class.A();
      end)
    end
    
    assertErrorMessage("Invalid type 'boolean' found in MEX", buildTest(true));
    assertErrorMessage("Invalid type 'string' found in MEX", buildTest(""));
    assertErrorMessage("Invalid type 'number' found in MEX", buildTest(1));
end
testInvalidTypeInMex();

local function testDuplicateFieldInMEX()
    local testFunc = inScope(function(ft)
        ft.class.A() {
          { x = {} };
        }
        ft.class.B(ft.class.A) {
          { x = {} };
          constructor = function() f(x) end
        }
        ft.class.B();
    end)
    
    assertErrorMessage("Duplicate field 'x' found in MEX", testFunc);
end
testDuplicateFieldInMEX();

local function testAmbiguousFieldInMEX()
    local function buildTest()
      return inScope(function(ft) 
        local x = 5;
        ft.class.A() {
          { x = {} };
          constructor = function() f(x) end
        }
        ft.class.A();
      end)
    end
    
    assertErrorMessage("Ambiguous field 'x' found in MEX, there is an upvalue with the same name", buildTest());
end
testAmbiguousFieldInMEX();

local function testInvalidFieldInClassDefinition()
    local function buildTest()
      return inScope(function(ft)
        ft.class.A() {
          invalid = true;
          constructor = function() f(this.invalid); end
        }
        ft.class.A();
      end)
    end
    
    assertErrorMessage("Invalid field 'invalid' %(of type 'boolean'%) found in class definition", buildTest());
end
testInvalidFieldInClassDefinition();

print("TESTS COMPLETED");