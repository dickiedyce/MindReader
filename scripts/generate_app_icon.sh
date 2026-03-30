#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SVG="${1:-$ROOT_DIR/MindReader/Resources/IconSource/AppIcon.svg}"
APPICON_DIR="$ROOT_DIR/MindReader/Resources/Assets.xcassets/AppIcon.appiconset"
CORNER_RADIUS_RATIO="0.22"

if [[ ! -f "$SOURCE_SVG" ]]; then
  echo "Source SVG not found: $SOURCE_SVG" >&2
  exit 1
fi

if ! command -v qlmanage >/dev/null 2>&1; then
  echo "qlmanage not found. This script requires macOS Quick Look tools." >&2
  exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "sips not found. This script requires macOS image tools." >&2
  exit 1
fi

mkdir -p "$APPICON_DIR"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

qlmanage -t -s 1024 -o "$TMP_DIR" "$SOURCE_SVG" >/dev/null 2>&1

MASTER_PNG="$(find "$TMP_DIR" -maxdepth 1 -name '*.png' | head -n 1)"
if [[ -z "$MASTER_PNG" ]]; then
  echo "Failed to render PNG from SVG using qlmanage." >&2
  exit 1
fi

render() {
  local size="$1"
  local filename="$2"
  local out_png="$APPICON_DIR/$filename"

  sips -z "$size" "$size" "$MASTER_PNG" --out "$out_png" >/dev/null

  swift - "$out_png" "$CORNER_RADIUS_RATIO" <<'SWIFT' >/dev/null
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
  fputs("Usage: swift - <png-path> <corner-radius-ratio>\n", stderr)
  exit(1)
}

let imagePath = CommandLine.arguments[1]
let ratio = max(0.0, min(0.5, Double(CommandLine.arguments[2]) ?? 0.22))
let imageURL = URL(fileURLWithPath: imagePath)

guard
  let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
  fputs("Failed to load PNG: \(imagePath)\n", stderr)
  exit(1)
}

let width = image.width
let height = image.height
let radius = CGFloat(Double(min(width, height)) * ratio)
let rect = CGRect(x: 0, y: 0, width: width, height: height)

guard let context = CGContext(
  data: nil,
  width: width,
  height: height,
  bitsPerComponent: 8,
  bytesPerRow: 0,
  space: CGColorSpaceCreateDeviceRGB(),
  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
  fputs("Failed to create graphics context\n", stderr)
  exit(1)
}

context.clear(rect)
let roundedPath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
context.addPath(roundedPath)
context.clip()
context.draw(image, in: rect)

guard let maskedImage = context.makeImage() else {
  fputs("Failed to create masked image\n", stderr)
  exit(1)
}

guard
  let destination = CGImageDestinationCreateWithURL(imageURL as CFURL, UTType.png.identifier as CFString, 1, nil)
else {
  fputs("Failed to create PNG destination\n", stderr)
  exit(1)
}

CGImageDestinationAddImage(destination, maskedImage, nil)
if !CGImageDestinationFinalize(destination) {
  fputs("Failed to write PNG: \(imagePath)\n", stderr)
  exit(1)
}
SWIFT
}

rm -f "$APPICON_DIR"/*.png

render 16 icon_16x16.png
render 32 icon_16x16@2x.png
render 32 icon_32x32.png
render 64 icon_32x32@2x.png
render 128 icon_128x128.png
render 256 icon_128x128@2x.png
render 256 icon_256x256.png
render 512 icon_256x256@2x.png
render 512 icon_512x512.png
render 1024 icon_512x512@2x.png

cat > "$APPICON_DIR/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "App icons generated in: $APPICON_DIR"