# Room Tone

## Overview
Room Tone is a LiDAR-required iOS app (iPhone Pro / iPad Pro) that maps physical room geometry via ARKit Scene Reconstruction and synthesizes a real-time soundscape derived from the room's resonant modes. The player's position modulates which frequencies dominate. Two audio timbres (Drone, Ambient), audio recording, and a minimal AR visual overlay complete the experience. Primary goals: App Store release + viral demo video as portfolio showcase.

## Tech Stack
- Swift: 5.10
- SwiftUI: iOS 17+ minimum deployment target
- ARKit: 6.0 — Scene Reconstruction + plane detection; LiDAR device required
- AVAudioEngine / AVFoundation: iOS 17 — real-time audio graph, synthesis, recording
- simd: built-in Swift — vector math for position/distance calculations
- Xcode: 16.x
- No third-party dependencies — pure Apple frameworks only

## Development Conventions
- Swift: no force-unwraps; use guard-let or if-let throughout
- @Observable (iOS 17 macro) for all model classes — no legacy ObservableObject
- File naming: PascalCase for types, camelCase for properties and methods
- AVAudioSourceNode render callbacks: zero Swift allocations, no locks, no ObjC calls — pre-allocated buffers only
- Unit tests required for all pure math (RoomModeCalculator, RoomGeometryProcessor)
- Conventional commits: feat:, fix:, chore:, test:

## Current Phase
**Phase 0: Foundation (Weeks 1–2)**
See IMPLEMENTATION-ROADMAP.md for full phase details, acceptance criteria, and verification checklists.

## Key Decisions
| Decision | Choice | Why |
|----------|--------|-----|
| Device requirement | LiDAR required, no fallback | Experience quality difference is too large to compromise for v1 |
| Room dimensions source | ARKit plane anchors primary; LiDAR mesh bounding box secondary | Plane anchors are stable; mesh drifts during scanning |
| Oscillator architecture | One AVAudioSourceNode per mode, mixed via AVAudioMixerNode | Clean graph, direct per-mode amplitude control |
| Max oscillators | 16 active simultaneously | A15/A16/A17 performance ceiling; above 20 risks scheduling artifacts |
| Positional audio | Manual amplitude calculation from player-wall distance | AVAudioEnvironmentNode HRTF fights with drone synthesis |
| Ambient timbre | Sine through AVAudioUnitTimePitch (rate=0.85, overlap=8) | Granular texture without custom DSP |
| Large rooms (>8.5m dim) | Auto octave-shift until all fundamentals ≥ 40Hz | Transparent to user; labeled "architectural transposition" in UI |
| Recording | installTap on mixer node → AVAudioFile → share sheet | Standard pattern, no extra permissions needed |

## Do NOT
- Do not use RealityKit — ARKit direct + SceneKit for the overlay is sufficient and lighter
- Do not put ARKit session setup on a background thread — ARSession must run on main thread
- Do not allocate memory inside AVAudioSourceNode render callbacks — use pre-allocated Float buffers
- Do not use AVAudioEnvironmentNode for positional audio — manual amplitude control only
- Do not add a non-LiDAR fallback path in v1 — UnsupportedDeviceView is the correct behavior
- Do not add features not in the current phase of IMPLEMENTATION-ROADMAP.md
