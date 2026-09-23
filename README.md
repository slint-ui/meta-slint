## Introduction

This layer contains recipes and classes for building Slint's C++ API, a class for building Rust
applications that use Slint, as well as the Rust based demos.

For a Rust based application using Slint, inherit the `slint_rust` class in your application's recipe.
See [Rust Applications](#rust-applications) below.

For a C++ based application, the recipes in this layer assume that your application is built using CMake and
uses `find_package(Slint)` to locate Slint, and then uses `slint_target_sources` to compile `.slint` files to C++
as well as links against `Slint::Slint`. For more details, check out our [C++ Getting Started](https://docs.slint.dev/latest/docs/cpp/getting_started).
When creating a Bitbake recipe for, use this layer, and in your application's recipe inherit from `cmake` and `slint`.

## Prerequisites

Meta-slint requires:

```
meta-openembedded/meta-oe
meta-rust-bin
```

The layer supports kirkstone through wrynose. Check the
[layer.conf](conf/layer.conf) `LAYERSERIES_COMPAT_meta-slint` for the exact list of supported
Yocto releases.

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

## Rust Applications

The `slint_rust` class builds a Rust application that uses Slint with
[meta-rust-bin](https://github.com/rust-embedded/meta-rust-bin)'s `cargo_bin` class. Select the renderers
and backends your application uses, and the class adds the matching build dependencies, required
`DISTRO_FEATURES`, and cargo features, and sets up the environment that the Skia renderer needs to build:

```
SUMMARY = "My Slint application"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=..."
SRC_URI = "git://github.com/me/my-app.git;protocol=https;branch=main"
SRCREV = "..."

inherit slint_rust

SLINT_RENDERERS = "skia"
SLINT_BACKENDS = "linuxkms"
```

| Variable                     | Values                                                               | Default    |
|------------------------------|----------------------------------------------------------------------|------------|
| `SLINT_RENDERERS`            | `skia`, `skia-opengl`, `skia-vulkan`, `femtovg`, `software`          | `skia`     |
| `SLINT_BACKENDS`             | `linuxkms`, `linuxkms-noseat`, `winit`, `winit-wayland`, `winit-x11` | `linuxkms` |
| `SLINT_CARGO_FEATURE_PREFIX` | Prepended to each selected cargo feature                             | `slint/`   |

Each entry enables the Slint cargo feature of the same name, for example `renderer-skia` or
`backend-linuxkms-noseat`. With the default prefix, the features are enabled on the `slint` crate
(`slint/renderer-skia`), which works when your package depends on `slint` directly. If your application
has features of the same name that forward to Slint, set `SLINT_CARGO_FEATURE_PREFIX = ""`. To select the
features yourself in `CARGO_FEATURES`, set `SLINT_CARGO_FEATURES = ""`.

The selected features are added to the `slint` crate's default features, unless your `Cargo.toml`
disables those. Use `linuxkms-noseat` to run on LinuxKMS without seatd, for example as the only
application on a device.

Some things to keep in mind:

 - The Skia renderer requires the [meta-clang](https://github.com/kraj/meta-clang) layer. Without it, the
   recipe is skipped, and bitbake reports that meta-clang is missing.
 - cargo fetches the crates, and the Skia renderer fetches Skia's sources, while `do_compile` runs, so
   the build needs network access.
 - Compiling Skia uses a lot of memory. The class disables LTO, and you can bound the number of parallel
   jobs with `export CARGO_BUILD_JOBS = "..."` in your `conf/local.conf`.
 - The class doesn't set `S`. For a git checkout on releases before whinlatter, set
   `S = "${WORKDIR}/git"` as usual.

The [slint-hello-world-rust](recipes-example/slint-hello-rust/slint-hello-world-rust_git.bb) recipe
builds the [Slint Rust template](https://github.com/slint-ui/slint-rust-template) this way.

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
`conf/local.conf` set `DISTRO_FEATURES:append = " opengl "` as well as `DISTRO_FEATURES:remove = " wayland x11 vulkan opencl"` and run
`bitbake st-example-image-slint` to build an image that ships various Slint demos in a minimal image. The demos run directly
on the framebuffer with the LinuxKMS backend.

(Tested on stm32mp157-disco)

## F&S Elektronik Systeme

When building for F&S Elektronik [meta-fus](https://github.com/FSEmbedded/meta-fus), adding this `meta-slint` layer to your
environment enables an additional `fus-image-slint-demos` image target.

Steps:
  - Add [meta-clang](https://github.com/kraj/meta-clang)
  - Add [meta-rust-bin](https://github.com/rust-embedded/meta-rust-bin)
  - Add `meta-slint`
  - Edit your `conf/local.conf`:
    - Make sure `DISTRO` is set to `"fus-imx-wayland"`
  - Run `bitbake fus-image-slint-demos` to build an image that ships various Slint demos in a minimal image. The demos run directly on the framebuffer with the LinuxKMS backend.

## Renesas Arm-based MPUs

When building for Renesas Arm-based MPUs with the [meta-renesas](https://github.com/renesas-rz/meta-renesas) layer,
adding this `meta-slint` layer to your environment enables an additional `core-image-slint` image target.

Steps:
  - Add [meta-clang](https://github.com/kraj/meta-clang)
  - Add [meta-rust-bin](https://github.com/rust-embedded/meta-rust-bin)
  - Add `meta-slint`
  - Run `bitbake core-image-slint-demos` to build an image that ships various Slint demos in a minimal image. The demos run directly on the framebuffer with the LinuxKMS backend.

## NXP i.MX Series

When building for NXP i.MX series MPUs with the [meta-imx](https://github.com/nxp-imx/meta-imx) layer,
adding this `meta-slint` layer to your enrivonment enables an additional `imx-image-slint-demos` image target.

Steps:
  - Add [meta-clang](https://github.com/kraj/meta-clang)
  - Add [meta-rust-bin](https://github.com/rust-embedded/meta-rust-bin)
  - Add `meta-slint`
  - Run `bitbake imx-image-slint-demos` to build an image that ships various Slint demos in a minimal image. The demos run directly on the framebuffer with the LinuxKMS backend.

## TI Sitara MPUs

When building for TI's K3-generation Sitara MPUs (those with a display, e.g. the AM62x family) with TI's [meta-ti](https://git.yoctoproject.org/meta-ti) BSP
(as delivered by the [Arago Processor SDK](https://git.ti.com/cgit/arago-project/oe-layersetup/),
which layers `meta-ti-bsp` and `meta-arago` on top of OpenEmbedded), adding this `meta-slint`
layer to your environment enables an additional `ti-image-slint-demos` image target.

Steps:
  - Add [meta-clang](https://github.com/kraj/meta-clang)
  - Add [meta-rust-bin](https://github.com/rust-embedded/meta-rust-bin)
  - Add `meta-slint`
  - Run `bitbake ti-image-slint-demos` to build an image that boots straight into the Slint demo
    launcher — a menu that discovers and runs the installed demos — on the framebuffer with the
    LinuxKMS backend.

The image adapts to the board's graphics stack: on the AM62Px (`am62pxx-evm`, SK-AM62P-LP) the
demos render on the Imagination GPU through the PowerVR driver, while on the GPU-less AM62L
(`am62lxx-evm`, AM62L EVM) they render in software with Skia.

(Tested on SK-AM62P-LP and the AM62L EVM)

