# NASA Wallpapers

A macOS app for searching and downloading space imagery from multiple sources.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green)

## Sources

- **NASA Image & Video Library** — the full NASA media archive
- **ESA/Webb** — James Webb Space Telescope imagery
- **ESA/Hubble** — Hubble Space Telescope imagery

## Features

- Multi-source search with source checklist
- Parallel search across selected sources
- Unified results grid with source badges
- Detail panel with metadata (instrument, facility, credit)
- Download original-resolution images
- Direct links to source websites

## Building

Requires Xcode 15+ and macOS 14+. Uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation.

```bash
cd NASAWallpapers
xcodegen generate
open NASAWallpapers.xcodeproj
```

## Inspiration

Inspired by [this post](https://www.threads.com/@wongmjane/post/DT573NKku8k/i-spun-up-a-one-off-mac-os-app-to-view-nasa-images-in-swift-ui-using-opus) by @wongmjane.
