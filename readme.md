# swift-vcpkg-plugin

Experimental Swift Package Manager [Build Tool plugin](https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/Plugins.md) for [Microsoft/vcpkg](https://github.com/microsoft/vcpkg)

* https://github.com/swiftlang/swift-package-manager
* https://github.com/microsoft/vcpkg
* https://github.com/microsoft/vcpkg-tool

## How To

### Use

Because vcpkg may not configure native libraries properly, you will need a propert [vcpkg triplet](https://learn.microsoft.com/en-us/vcpkg/concepts/triplets).
Please check [the overlay triplets example](https://learn.microsoft.com/en-us/vcpkg/users/examples/overlay-triplets-linux-dynamic).

For example, if you're building for ARM64, macOS environment...

```cmake
# arm64-osx.cmake
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)

set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_CMAKE_SYSTEM_VERSION 10.15) # For minimum SDK
list(APPEND VCPKG_CMAKE_CONFIGURE_OPTIONS
    "-DCMAKE_CXX_STANDARD=20"
)

set(VCPKG_OSX_ARCHITECTURES arm64) # or x86_64, some ports won't support universal build
```

After the custom triplet, set [the environment variables](https://learn.microsoft.com/en-us/vcpkg/users/config-environment)
* `VCPKG_OVERLAY_TRIPLETS`
* ...

```bash
# Suppose this folder contains your CMake scripts
export VCPKG_OVERLAY_TRIPLETS="$(pwd)/vcpkg-triplets"
```

In your Package.swift,

```swift
// swift-tools-version: 6.0
import PackageDescription

let dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/luncliff/swift-vcpkg-plugin", branch: "main"),
    // ...
]

let triplet = "arm64-osx" // we will use libraries with the triplet, arm64-osx.cmake

let targets: [Target] = [
    .target(
        name: "...",
        cxxSettings: [
            // path to the installed header files
            .unsafeFlags(["-I.build/artifacts/\(triplet)/include"])
        ],
        linkerSettings: [
            // path to the installed libraries
            .unsafeFlags(["-L.build/artifacts/\(triplet)/lib"])
        ],
        plugins: [
            .plugin(name: "swift-vcpkg-plugin", package: "swift-vcpkg-plugin")
        ]
    )
]

let package = Package(
    name: "...",
    // ...
    dependencies: dependencies,
    targets: targets
)
```

>
> [!WARNING]
> * When you build your project with this plugin, the sandbox created by the Swift package manager causes error while `curl`'s DNS usage.
> ```log
> curl: (6) Could not resolve host: github.com
> ```
>

Disable sandbox to allow plugin to download & extract .zip file and executables...

```bash
swift build --disable-sandbox
```

### Build/Test

>
> [!WARNING]
> * Source organization may change later
>

```bash
# swift package resolve
# swift package show-dependencies
swift build
```

```bash
swift test
```

### Format/Lint

Install some tools with [Homebrew](https://brew.sh)

* https://formulae.brew.sh/formula/swiftformat
* https://formulae.brew.sh/formula/swiftlint

```bash
brew install swiftformat swiftlint
```

Then run the commands in following order.

```bash
swiftformat **/*.swift --swiftversion 6.0
swiftlint --autocorrect **/*.swift
```
