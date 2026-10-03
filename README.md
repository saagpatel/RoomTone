# Room Tone

[![Swift](https://img.shields.io/badge/Swift-f05138?style=flat-square&logo=swift)](#) [![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](#)

> Your room has a sound. Room Tone lets you hear it.

Room Tone uses the LiDAR scanner on supported iPhones and iPads to measure your room's physical dimensions, computes its acoustic resonant modes, and synthesizes those frequencies as audible sound. Walk around the space and hear how your proximity to the estimated walls changes the character of what you're listening to.

## Features

- **LiDAR room scanning** — ARKit plane detection and mesh reconstruction estimate length × width × height automatically
- **Room mode calculator** — applies `f(n,m,l) = (c/2) × √((n/Lx)² + (m/Ly)² + (l/Lz)²)` for up to 16 axial, tangential, and oblique frequencies
- **Real-time synthesis** — 16-oscillator AVAudioEngine bank tuned to frequencies calculated from the estimated geometry
- **Positional amplitude** — move through the space and axial-mode amplitudes increase within 0.3m of the estimated walls, floor, or ceiling
- **Sabine reverb** — RT60 estimated from room volume and surface area for authentic acoustic character
- **Audio recording** — capture the live output to a shareable file

## Quick Start

### Prerequisites
- iPhone 12 Pro or later, or iPad Pro (2020) or later (LiDAR required)
- iOS 17.0+, Xcode 16+
- XcodeGen (`brew install xcodegen`)

### Installation
```bash
git clone https://github.com/saagpatel/RoomTone.git
cd RoomTone
xcodegen generate
open RoomTone.xcodeproj
```

### Usage
Build and run on a LiDAR-equipped device. Tap **Start Scanning** and move your phone around the room perimeter. Audio starts automatically once preliminary dimensions are available; scan confirmation opens the main experience.

## Verification

Run from the repository root. Use full Xcode with active Xcode developer tools and an installed iOS simulator;
Command Line Tools alone cannot run these checks. `make test` generates the project
with XcodeGen before running tests.

```bash
# Simulator unit suite; signing is disabled by the Makefile
make test

# Compile the Release configuration without signing or uploading an archive
make release
```

The Makefile's simulator destination must exist locally. Override `SIMULATOR` if
needed, for example `make test SIMULATOR='platform=iOS Simulator,name=iPhone 17'`
for an installed simulator with that name. For a focused pure-data check, open the
generated project in Xcode and run `RoomModeCalculatorTests` in the Test navigator.
The broader simulator suite and Release build remain the checks before delivery.
There is no configured standalone lint or formatter command.

The focused calculator suite uses synthetic room dimensions and needs no LiDAR
scan, microphone recording, or audio output. For UI/scan/synthesis changes, also
check the affected flow on a LiDAR-equipped device with a disposable room scan;
simulator unit tests do not establish sensor or audible behavior.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Language | Swift 5.10 |
| UI | SwiftUI + @Observable |
| Spatial sensing | ARKit (LiDAR mesh reconstruction) |
| 3D overlay | SceneKit (ARSCNView) |
| Audio | AVFoundation (AVAudioEngine, AVAudioSourceNode) |
| Physics | Custom room-mode calculator (pure Swift) |

## License

MIT
