# swift-vcpkg-plugin

Experimental Swift Package Manager [Build Tool plugin](https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/Plugins.md) for [Microsoft/vcpkg](https://github.com/microsoft/vcpkg)

* https://github.com/swiftlang/swift-package-manager
* https://github.com/microsoft/vcpkg
* https://github.com/microsoft/vcpkg-tool

## How To

### Use

```swift
// swift-tools-version: 6.0
import PackageDescription

let dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/luncliff/swift-vcpkg-plugin", branch: "main"),
    // ...
]

let targets: [Target] = [
    .target(
        name: "...",
        // ...
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

When you build your project with this plugin,  
the sandbox created by the Swift package manager causes error while `curl`'s DNS usage.

```log
curl: (6) Could not resolve host: github.com
```

```bash
# Disable sandbox to allow plugin to download & extract .zip file
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

Install the tools with [Homebrew](https://brew.sh)

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
