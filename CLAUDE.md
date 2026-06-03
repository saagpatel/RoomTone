# Room Tone

LiDAR-required iOS app (iPhone Pro / iPad Pro) that maps room geometry via ARKit Scene Reconstruction and synthesizes a real-time soundscape from the room's resonant modes. Player position modulates dominant frequencies. Two timbres (Drone, Ambient), audio recording, minimal AR overlay. Target: App Store release.

## Stack

- Swift: 5.10, SwiftUI iOS 17+ minimum deployment target
- ARKit 6.0 — Scene Reconstruction + plane detection; LiDAR device required
- AVAudioEngine / AVFoundation iOS 17 — real-time audio graph, synthesis, recording
- simd (built-in Swift) — vector math for position/distance calculations
- Xcode 16.x; no third-party dependencies — pure Apple frameworks only

## Build / Test / Run

Build and run on a LiDAR-equipped device (iPhone 12 Pro+ or iPad Pro 2020+). Unit tests required for all pure-math modules: `RoomModeCalculator`, `RoomGeometryProcessor`. Run via `xcodebuild test`.

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Device requirement | LiDAR required; `UnsupportedDeviceView` for others | Experience quality gap too large to compromise |
| Room dimensions | ARKit plane anchors primary; LiDAR mesh bounding box secondary | Plane anchors stable; mesh drifts during scan |
| Oscillator architecture | One `AVAudioSourceNode` per mode, mixed via `AVAudioMixerNode` | Clean graph; direct per-mode amplitude control |
| Max oscillators | 16 active simultaneously | A15/A16/A17 ceiling; above 20 risks scheduling artifacts |
| Positional audio | Manual amplitude from player-wall distance | `AVAudioEnvironmentNode` HRTF fights drone synthesis |
| Ambient timbre | Sine through `AVAudioUnitTimePitch` (rate=0.85, overlap=8) | Granular texture without custom DSP |
| Large rooms (>8.5m dim) | Auto octave-shift until all fundamentals ≥ 40Hz | Transparent to user; labeled "architectural transposition" in UI |
| Recording | `installTap` on mixer → `AVAudioFile` → share sheet | Standard pattern; no extra permissions needed |
| Overlay renderer | ARKit direct + SceneKit | Lighter than RealityKit for this use case |

## Constraints

- ARKit: run `ARSession` on main thread only — background thread setup crashes.
- Audio render callbacks (`AVAudioSourceNode`): zero Swift allocations, no locks, no ObjC calls — use pre-allocated `Float` buffers only.
- Positional audio: manual amplitude calculation only — `AVAudioEnvironmentNode` is excluded (HRTF conflict above).
- Non-LiDAR fallback: do not add a non-LiDAR fallback path — `UnsupportedDeviceView` is the correct behavior for unsupported hardware.
- Scope: implement only features present in the current phase of `IMPLEMENTATION-ROADMAP.md`.

## Conventions

- No force-unwraps; use `guard let` / `if let` throughout.
- `@Observable` (iOS 17 macro) for all model classes — not `ObservableObject`.
- File naming: PascalCase types, camelCase properties/methods.
- Conventional commits: `feat:`, `fix:`, `chore:`, `test:`.

See `IMPLEMENTATION-ROADMAP.md` for phase details. See `HANDOFF.md` for next steps (device test → TestFlight → App Store submission).

<!-- portfolio-context:start -->
# Portfolio Context

## What This Project Is

Room Tone is a LiDAR-required iOS app (iPhone Pro / iPad Pro) that maps physical room geometry via ARKit Scene Reconstruction and synthesizes a real-time soundscape derived from the room's resonant modes. The player's position modulates which frequencies dominate. Two audio timbres (Drone, Ambient), audio recording, and a minimal AR visual overlay complete the experience. Primary goals: App Store release + viral demo video as portfolio showcase.

## Current State

**All phases complete — pending device testing on LiDAR hardware**
See HANDOFF.md for current status and next steps (device test → TestFlight → App Store submission).

## Stack

- Swift: 5.10
- SwiftUI: iOS 17+ minimum deployment target
- ARKit: 6.0 — Scene Reconstruction + plane detection; LiDAR device required
- AVAudioEngine / AVFoundation: iOS 17 — real-time audio graph, synthesis, recording
- simd: built-in Swift — vector math for position/distance calculations
- Xcode: 16.x
- No third-party dependencies — pure Apple frameworks only

## How To Run

Build and run on a LiDAR-equipped device. Tap **Scan** and move your phone around the room perimeter, then tap **Synthesize** to hear your room's resonant modes.

## Known Risks

- Do not use RealityKit — ARKit direct + SceneKit for the overlay is sufficient and lighter
- Do not put ARKit session setup on a background thread — ARSession must run on main thread
- Do not allocate memory inside AVAudioSourceNode render callbacks — use pre-allocated Float buffers
- Do not use AVAudioEnvironmentNode for positional audio — manual amplitude control only
- Do not add a non-LiDAR fallback path in v1 — UnsupportedDeviceView is the correct behavior
- Do not add features not in the current phase of IMPLEMENTATION-ROADMAP.md

## Next Recommended Move

Run on a LiDAR-equipped device (iPhone 12 Pro+ or iPad Pro 2020+) to complete end-to-end QA, then proceed to TestFlight and App Store submission. See HANDOFF.md for the full step-by-step sequence.

<!-- portfolio-context:end -->

<!-- secondbrain-breadcrumb -->
## SecondBrain knowledge vault

Prior lessons, decisions, and context for this project live in SecondBrain at `wiki/maps/projects/room-tone.md`. The whole vault is searchable via the `engraph` MCP — query it for this project + its stack before non-trivial work.
