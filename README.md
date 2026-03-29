# Room Tone

[![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-lightgrey?logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/swift-5.10-orange?logo=swift)](https://www.swift.org)
[![Xcode](https://img.shields.io/badge/xcode-16-blue?logo=xcode)](https://developer.apple.com/xcode/)
[![Requires LiDAR](https://img.shields.io/badge/requires-LiDAR-blueviolet)](https://support.apple.com/en-us/111901)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Room Tone uses the LiDAR scanner on supported iPhones and iPads to measure your room's physical dimensions, computes its acoustic resonant modes, and synthesizes those frequencies as audible sound. Walk around the space and hear how your position within the standing-wave field changes the character of what you're listening to.

---

## How it works

1. **Scan** — ARKit plane detection and LiDAR mesh reconstruction extract floor, wall, and ceiling geometry and produce a bounding-box measurement (length × width × height in meters).
2. **Calculate** — `RoomModeCalculator` applies the room-mode formula `f(n,m,l) = (c/2) × √((n/Lx)² + (m/Ly)² + (l/Lz)²)` to produce up to 16 axial, tangential, and oblique resonant frequencies.
3. **Synthesize** — An `OscillatorBank` of 16 `AVAudioSourceNode` oscillators is tuned to those frequencies. A `TimbreProcessor` applies pitch modulation and a reverb unit whose RT60 is estimated from room volume and surface area (Sabine approximation).
4. **Track** — As you move, your position within the standing-wave field is computed per frame and drives each oscillator's amplitude in real time via `RoomModel.modeAmplitudes()`.
5. **Record** — An on-screen record button captures the live audio output to a file you can share directly from the app.

## Screenshots

| Scan | Experience |
|------|------------|
| ![Scan screen placeholder](docs/screenshot-scan.png) | ![Experience screen placeholder](docs/screenshot-experience.png) |

## Tech stack

| Layer | Technology |
|-------|------------|
| Language | Swift 5.10 |
| UI | SwiftUI + `@Observable` |
| Spatial sensing | ARKit (`ARWorldTrackingConfiguration`, LiDAR mesh reconstruction) |
| 3D overlay | SceneKit (`ARSCNView`) |
| Audio | AVFoundation (`AVAudioEngine`, `AVAudioSourceNode`) |
| Physics | Custom room-mode calculator (pure Swift) |

## Prerequisites

- **Device with LiDAR scanner**: iPhone 12 Pro or later, iPad Pro (2020) or later
- iOS 17.0+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the `.xcodeproj` is generated from `project.yml`

## Getting started

```bash
# 1. Clone
git clone https://github.com/saagpatel/RoomTone.git
cd RoomTone

# 2. Generate the Xcode project
xcodegen generate

# 3. Open and run on a physical LiDAR device
open RoomTone.xcodeproj
```

Build and run the **RoomTone** scheme on a connected LiDAR-capable device. The app does not function in Simulator because it requires the LiDAR sensor and a real camera feed.

## Project structure

```
RoomTone/
├── App/
│   ├── RoomToneApp.swift          # @main entry point, AVAudioSession setup
│   └── AppState.swift             # Global state: scan phase, timbre, playback
├── ARKit/
│   ├── ARSessionManager.swift     # ARSession lifecycle, delegate, per-frame updates
│   ├── RoomGeometryProcessor.swift# ARPlaneAnchor → RoomDimensions
│   └── WireframeOverlayManager.swift
├── Audio/
│   ├── RoomAudioEngine.swift      # AVAudioEngine graph owner
│   ├── OscillatorBank.swift       # 16 oscillators, lock-free amplitude updates
│   ├── ModeAmplitudeController.swift
│   ├── TimbreProcessor.swift      # Reverb + pitch modulation
│   └── AudioRecorder.swift        # Live output capture
├── Model/
│   ├── RoomModel.swift            # Dimensions, modes, player position, LFO
│   ├── RoomDimensions.swift       # Value type: Lx/Ly/Lz, RT60, octave-shift
│   └── RoomMode.swift             # Single resonant mode (n, m, l, frequency, weight)
├── Physics/
│   └── RoomModeCalculator.swift   # Room-mode formula, perceptual ranking
└── Views/
    ├── MainExperienceView.swift   # AR + standing-wave overlay + controls
    ├── ScanView.swift             # Guided scan UI with progress
    ├── StandingWaveOverlay.swift
    ├── TechnicalOverlayView.swift # Optional debug overlay (frequencies, RT60)
    ├── SettingsView.swift
    └── OnboardingView.swift
RoomToneTests/
├── RoomModeCalculatorTests.swift
├── RoomDimensionsTests.swift
├── RoomGeometryProcessorTests.swift
└── ModeAmplitudeControllerTests.swift
```

## License

MIT — see [LICENSE](LICENSE).
