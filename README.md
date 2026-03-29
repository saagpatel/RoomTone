# Room Tone

[![Swift](https://img.shields.io/badge/Swift-f05138?style=flat-square&logo=swift)](#) [![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](#)

> Your room has a sound. Room Tone lets you hear it.

Room Tone uses the LiDAR scanner on supported iPhones and iPads to measure your room's physical dimensions, computes its acoustic resonant modes, and synthesizes those frequencies as audible sound. Walk around the space and hear how your position within the standing-wave field changes the character of what you're listening to.

## Features

- **LiDAR room scanning** — ARKit plane detection and mesh reconstruction extract length × width × height automatically
- **Room mode calculator** — applies `f(n,m,l) = (c/2) × √((n/Lx)² + (m/Ly)² + (l/Lz)²)` for up to 16 axial, tangential, and oblique frequencies
- **Real-time synthesis** — 16-oscillator AVAudioEngine bank tuned to those exact frequencies
- **Positional amplitude** — move through the space and oscillator amplitudes respond to your standing-wave position
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
Build and run on a LiDAR-equipped device. Tap **Scan** and move your phone around the room perimeter, then tap **Synthesize** to hear your room's resonant modes.

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
