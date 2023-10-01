
DEPENDS:append:class-target = " slint-cpp-native"
EXTRA_OECMAKE:append:class-target = " -DSLINT_COMPILER:PATH=${RECIPE_SYSROOT_NATIVE}${prefix_native}/bin/slint-compiler "
