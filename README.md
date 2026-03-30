# MindReader

MindReader is a native macOS menu bar app for intelligent file renaming. It can read dropped files or Finder selections, extract document text from PDFs and scanned images, generate proposed filenames, and let you confirm renames one file at a time.

## Current Capabilities

- Menu bar app built with SwiftUI and `MenuBarExtra`
- Floating rename queue window with drag and drop
- Per-file editable rename proposals
- Per-row confirm, revert, and Quick Look actions
- AI-assisted metadata extraction through a local Ollama runtime
- OCR for scanned PDFs and raster images via Vision
- Finder selection processing
- Rename preview and revert support

## Tech Stack

- Swift 5.10
- SwiftUI
- macOS 13+
- XcodeGen 2.38.0+
- PDFKit
- Vision
- Ollama (optional, local)

## Project Structure

- `MindReader/Sources/App` — app shell, menu bar UI, floating queue window, preferences
- `MindReader/Sources/AI` — Ollama integration and AI model lifecycle
- `MindReader/Sources/Services` — ingestion, OCR, Finder access, rename engine, execution
- `MindReader/Resources` — app icon assets and entitlements
- `MindReaderTests` — unit tests

## Getting Started

### Prerequisites

- macOS 13 or later
- Xcode with command line tools installed
- XcodeGen 2.38.0 or later

Install XcodeGen if needed:

```bash
brew install xcodegen
```

### Generate the Project

```bash
xcodegen generate
```

### Regenerate the App Icon

The canonical icon source is the SVG at `MindReader/Resources/IconSource/AppIcon.svg`.
Generate the PNG asset catalog entries with:

```bash
./scripts/generate_app_icon.sh
```

The script renders the SVG with macOS Quick Look, writes the full macOS app icon size set into `MindReader/Resources/Assets.xcassets/AppIcon.appiconset`, and refreshes `Contents.json` to match.

### Build a Debug App

```bash
xcodebuild -scheme MindReader -configuration Debug
```

### Run Tests

```bash
xcodebuild test -scheme MindReader -destination 'platform=macOS'
```

## Local Signing

Debug builds work without signing.

If you want local signed or release builds:

1. Copy `MindReader/Config/Signing.xcconfig.example` to `MindReader/Config/Signing.xcconfig`
2. Fill in your local values

```xcconfig
DEVELOPMENT_TEAM = YOURTEAMID
CODE_SIGN_IDENTITY = Apple Development
```

`MindReader/Config/Signing.xcconfig` is gitignored and should not be committed.

## Using the App

### Menu Bar Flow

1. Launch `MindReader.app`
2. Open the menu bar item
3. Process the current Finder selection
4. Review proposed filenames
5. Apply or revert changes

### Floating Rename Queue

1. Open `Open Rename Window...` from the menu bar menu
2. Drag files into the queue window or click `Add Files...`
3. Review each queued file in its lozenge row
4. Edit the proposed filename if needed
5. Confirm a single row or use `Confirm All`

## AI and OCR

MindReader supports two extraction paths:

- Searchable PDFs and text documents are parsed directly
- Scanned PDFs and images use Vision OCR

If Ollama is running locally and a supported model is available, MindReader uses the extracted text to infer a date, entity, and short description for the filename.

Without Ollama, the app falls back to heuristic metadata extraction.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
