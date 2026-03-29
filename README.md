# MindReader

Native macOS menu bar app for intelligent file renaming.

## Requirements

- Swift 5.10
- macOS 13+
- XcodeGen 2.38.0+

## Setup

1. Copy `MindReader/Config/Signing.xcconfig.example` to `MindReader/Config/Signing.xcconfig`.
2. Fill in local signing values.
3. Run:

```bash
xcodegen generate
xcodebuild -scheme MindReader -configuration Debug
xcodebuild -scheme MindReader -configuration Release
```

## Tests

```bash
xcodebuild test -scheme MindReader -destination 'platform=macOS'
```
