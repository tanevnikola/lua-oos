local ft = require "lib/oos"
require "lib/ann"

ft.class.A() {

    { print = print; tostring = tostring; };

}

print(ft.reflection.getInfo(ft.class.A).getName())