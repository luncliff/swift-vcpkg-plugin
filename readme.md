
## How To

### Build

```bash
swift package resolve
swift package show-dependencies
```

```bash
swift build
```

### Lint

```bash
brew install swiftformat swiftlint
```

```bash
swiftformat **/*.swift --swiftversion 6.0
swiftlint --autocorrect **/*.swift
```
