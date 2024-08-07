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
meta-slint
```
Check the [layer.conf](conf/layer.conf) LAYERSERIES_COMPAT_meta for yocto version compatibility

By default, yocto will pick the `_git` recipe of `slint-cpp`, which means the development version
of Slint will be built. To select a specific Slint version, in your `conf/local.conf`, set
set `PREFERRED_VERSION_slint-cpp = "x.x.x"` and `PREFERRED_VERSION_slint-cpp-native = "x.x.x"`.

## Features

For git builds and builds from Slint version 1.3 onwards, certain features are
configurable via `PACKAGECONFIG`.

| Feature Name       | Description                         | Enabled by Default |
|--------------------|-------------------------------------|--------------------|
| `renderer-skia`    | Skia OpenGL renderer                | No                 |
| `renderer-femtovg` | Lightweight FemtoVG OpenGL renderer | Yes                |
| `backend-linuxkms` | Backend for rendering via KMS/DRM   | No                 |
| `interpreter`      | C++ API for Slint Interpreter       | Yes                |

Set the `PACKAGECONFIG:pn-slint-cpp` variable in your `conf/local.conf` to tweak.
For example, to disable the FemtoVG renderer, enable Skia, and the linuxkms
backend, set them like this:

```
PACKAGECONFIG:append:pn-slint-cpp = " backend-linuxkms renderer-skia "
PACKAGECONFIG:remove:pn-slint-cpp = " renderer-femtovg "
```

## Yocto Release Specific Notes

### Kirkstone

For compiling against Kirkstone, you need to upgrade Rust to match the minimum
required Rust version required by the Slint release you're compiling.

This means that you may have to either backport the rust recipes or add [meta-rust](https://github.com/meta-rust/meta-rust)
to your project.

### Mickledore

For compiling against Kirkstone, you need to upgrade Rust to match the minimum
required Rust version required by the Slint release you're compiling.

Unfortunately [meta-rust](https://github.com/meta-rust/meta-rust) does not work with
Mickledore at the moment because bitbake's `classes` directory was split up into
`classes-global`, `classes-recipe`, and `classes`. The rust recipes in openembedded-core
are in `classes-recipe` and are thus always found before the rust recipes in `meta-rust`
that are supposed to override them, as they are there located in `classes`.

A workaround is to cherry-pick a series of commits from upstream oe/master:
   * [39e05f9b0fdc3f76f8b80a12989f78614bc9ea5c](https://github.com/openembedded/openembedded-core/commit/39e05f9b0fdc3f76f8b80a12989f78614bc9ea5c)
   * [d1af583c290eb0cff5e36363f7531832a863a1a8](https://github.com/openembedded/openembedded-core/commit/d1af583c290eb0cff5e36363f7531832a863a1a8)
   * [c3eba94ee44adcd3a0aa61f6b087c15c02e4697f](https://github.com/openembedded/openembedded-core/commit/c3eba94ee44adcd3a0aa61f6b087c15c02e4697f)
   * [ad4369d7901c1239e5f07473b1f2517edc4a23ea](https://github.com/openembedded/openembedded-core/commit/ad4369d7901c1239e5f07473b1f2517edc4a23ea)
   * [30637cdeb31fae02544fdc643a455d0ebb126ee6](https://github.com/openembedded/openembedded-core/commit/30637cdeb31fae02544fdc643a455d0ebb126ee6)
   * [d1386bbf2211c7616527e62f2f7b069a935b0d68](https://github.com/openembedded/openembedded-core/commit/d1386bbf2211c7616527e62f2f7b069a935b0d68)
   * [728c40b939c6af6358a483237298ca834cbb8993](https://github.com/openembedded/openembedded-core/commit/728c40b939c6af6358a483237298ca834cbb8993)

into your local openembedded-core layer.

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
  - Add [meta-rust](https://github.com/meta-rust/meta-rust)
  - Edit your `conf/local.conf`:
    - Make sure `DISTRO` is set to `"fus-imx-wayland"`
    - Select the Rust version from `meta-rust` by adding this line (adjust path to layer accordingly):
      `include ../../sources/meta-rust/conf/distro/include/rust_versions.inc`
  - Run `bitbake fus-image-slint-demos` to build an image that ships various Slint demos in a minimal image. The demos run directly on the framebuffer with the LinuxKMS backend.
