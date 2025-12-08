## Introduction

This layer contains recipes and classes for building Slint's C++ API, as well as the Rust based
demos.

For a Rust based application using Slint, use [meta-rust](https://github.com/meta-rust/meta-rust) directly,

For a C++ based application, the recipes in this layer assume that your application is built using CMake and
uses `find_package(Slint)` to locate Slint, and then uses `slint_target_sources` to compile `.slint` files to C++
as well as links against `Slint::Slint`. For more details, check out our [C++ Getting Started](https://slint.dev/releases/1.2.2/docs/cpp/getting_started).
When creating a Bitbake recipe for, use this layer, and in your application's recipe inherit from `cmake` and `slint`.

## Prerequisites

Meta-slint requires:

```
meta-openembedded/meta-oe
meta-rust-bin
```
Check the [layer.conf](conf/layer.conf) LAYERSERIES_COMPAT_meta for yocto version compatibility

By default, yocto will pick the `_git` recipe of `slint-cpp`, which means the development version
of Slint will be built. To select a specific Slint version, in your `conf/local.conf`, set
set `PREFERRED_VERSION_slint-cpp = "x.x.x"` and `PREFERRED_VERSION_slint-cpp-native = "x.x.x"`.

## Features

For git builds and builds from Slint version 1.3 onwards, certain features are
configurable via `PACKAGECONFIG`.

| Feature Name        | Description                         | Enabled by Default |
|---------------------|-------------------------------------|--------------------|
| `renderer-skia`     | Skia OpenGL renderer                | No                 |
| `renderer-femtovg`  | Lightweight FemtoVG OpenGL renderer | Yes                |
| `backend-linuxkms`  | Backend for rendering via KMS/DRM   | No                 |
| `renderer-software` | Slint softwware renderer            | Yes                |
| `interpreter`       | C++ API for Slint Interpreter       | Yes                |

Set the `PACKAGECONFIG:pn-slint-cpp` variable in your `conf/local.conf` to tweak.
For example, to disable the FemtoVG renderer, enable Skia, and the linuxkms
backend, set them like this:

```
PACKAGECONFIG:append:pn-slint-cpp = " backend-linuxkms renderer-skia "
PACKAGECONFIG:remove:pn-slint-cpp = " renderer-femtovg "
```

## Compiling the Skia Renderer

The Skia renderer requires clang to compile. The [meta-clang](https://github.com/kraj/meta-clang) layer
provides current versions of clang that work with the recipes in this layer.

## Building an SDK that contains Slint

With Slint version 1.3 or newer, the `nativesdk-slint-cpp` package allows for including Slint in your SDK,
so that CMake based applications that use Slint and the Slint C++ compiler can be used.

Either add the package to your corresponding package groups or add the following to your `conf/local.conf`:

```
TOOLCHAIN_HOST_TASK:append = " nativesdk-slint-cpp"
```

## Building an SDK for external Slint builds

A regular Yocto SDK should be suitable for building Slint against, out of the box. Make sure to source
your `environment-setup` before invoking `cmake` on the Slint build, and pass `-DRust_CARGO_TARGET=<your triplet>`.

If your build of Slint enables the Skia renderer (`SLINT_FEATURE_RENDERER_SKIA`), make sure to include the
[meta-clang](https://github.com/kraj/meta-clang) layer in your project and set `CLANGSDK = "1"` in your `conf/local.conf`
before running the `populate_sdk` task on your image.

## Demo Images

### STM32 MPU OpenSTLinux

When building for [STM32 MPU OpenSTLinux](https://www.st.com/en/embedded-software/stm32-mpu-openstlinux-distribution.html),
adding this `meta-slint` layer to your environment enables an additional `st-example-image-slint` image target. In your
`conf/local.conf` set `DISTRO = "openstlinux-eglfs"` and run `bitbake st-example-image-slint` to build an image that ships
various Slint demos in a minimal image. The demos run directly on the framebuffer with the LinuxKMS backend.

(Tested on stm32mp157-disco)

## F&S Elektronik Systeme

When building for F&S Elektronik [meta-fus](https://github.com/FSEmbedded/meta-fus), adding this `meta-slint` layer to your
environment enables an additional `fus-image-slint-demos` image target.

Steps:
  - Add `meta-slint`
  - Add [meta-clang](https://github.com/kraj/meta-clang)
  - Add [meta-rust-bin](https://github.com/rust-embedded/meta-rust-bin)
  - Edit your `conf/local.conf`:
    - Make sure `DISTRO` is set to `"fus-imx-wayland"`
  - Run `bitbake fus-image-slint-demos` to build an image that ships various Slint demos in a minimal image. The demos run directly on the framebuffer with the LinuxKMS backend.

## Renesas Arm-based MPUs

When building for Renesas Arm-based MPUs with the [meta-renesas](https://github.com/renesas-rz/meta-renesas) layer,
adding this `meta-slint` layer to your environment enables an additional `core-image-slint` image target.

Steps:
  - Add `meta-slint`
  - Add [meta-clang](https://github.com/kraj/meta-clang)
  - Add [meta-rust-bin](https://github.com/rust-embedded/meta-rust-bin)
  - Run `bitbake core-image-slint-demos` to build an image that ships various Slint demos in a minimal image. The demos run directly on the framebuffer with the LinuxKMS backend.

## NXP i.MX Series

When building for NXP i.MX series MPUs with [ themeta-imx](https://github.com/nxp-imx/meta-imx) layer,
adding this `meta-slint` layer to your enrivonment enables an additional `imx-image-slint-demos` image target.

Steps:
  - Add `meta-slint`
  - Add [meta-clang](https://github.com/kraj/meta-clang)
  - Add [meta-rust-bin](https://github.com/rust-embedded/meta-rust-bin)
  - Run `bitbake imx-image-slint-demos` to build an image that ships various Slint demos in a minimal image. The demos run directly on the framebuffer with the LinuxKMS backend.

