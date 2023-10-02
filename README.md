## Usage

Meta-slint requires:  
  
```
meta-openembedded/meta-oe  
meta-rust  
meta-clang  
meta-slint  
```
Check the [layer.conf](conf/layer.conf) LAYERSERIES_COMPAT_meta for yocto version compatibility   
  
For local version locking just copy the slint-cpp_x.x.x.bb and modify the SLINT_REV 
and set PREFERRED_VERSION_slint-cpp = "x.x.x"

## Features

For git builds and builds from Slint version 1.3 onwards, certain features are
configurable via `PACKAGECONFIG`.

| Feature Name       | Description                         | Enabled by Default |
|--------------------|-------------------------------------|--------------------|
| `renderer-skia`    | Skia OpenGL renderer                | Yes                |
| `renderer-femtovg` | Lightweight FemtoVG OpenGL renderer | No                 |
| `backend-linuxkms` | Backend for rendering via KMS/DRM   | No                 |
| `interpreter`      | C++ API for Slint Interpreter       | Yes                |

Set the `PACKAGECONFIG:pn-slint-cpp` variable in your `conf/local.conf` to tweak.
For example, to disable the Skia renderer, enable FemtoVG, and the linuxkms
backend, set them like this:

```
PACKAGECONFIG:append:pn-slint-cpp = " backend-linuxkms renderer-femtovg "
PACKAGECONFIG:remove:pn-slint-cpp = " renderer-skia "
```