
DEPENDS:append:class-target = " slint-cpp-native"
DEPENDS:append = " slint-cpp"
EXTRA_OECMAKE:append:class-target = " -DSLINT_COMPILER:FILEPATH=${RECIPE_SYSROOT_NATIVE}${prefix_native}/bin/slint-compiler "
