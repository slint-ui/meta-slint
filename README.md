## Introduction

This layer contains recipes/classes/etc. for building Slint's C++ API, as well as the Rust based
demos.

For a Rust based application using Slint, use [meta-rust](https://github.com/meta-rust/meta-rust) directly,
For a C++ based application, use this layer, and in your application's recipe inherit from `cmake` and `slint`.

## Prerequisites

Meta-slint requires:  
  
```
meta-openembedded/meta-oe
meta-slint
```
Check the [layer.conf](conf/layer.conf) LAYERSERIES_COMPAT_meta for yocto version compatibility   
  
For local version locking just copy the slint-cpp_x.x.x.bb and modify the SLINT_REV 
and set PREFERRED_VERSION_slint-cpp = "x.x.x"

In your application's recipe

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