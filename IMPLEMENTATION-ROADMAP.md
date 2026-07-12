# Room Tone — Implementation Roadmap

## Architecture

### System Overview
```
┌─────────────────────────────────────────────────────┐
│                    SwiftUI Layer                     │
│  ScanView → MainExperienceView → SettingsView        │
│  RecordingControls  AROverlayView  ModeSelector      │
└──────────────┬──────────────────────────┬────────────┘
               │                          │
     ┌─────────▼────────┐      ┌──────────▼───────────┐
     │   ARKit Layer    │      │  Audio Engine Layer   │
     │                  │      │                       │
     │ ARSessionManager │      │ RoomAudioEngine        │
     │ ARWorldTracking  │      │  ├─ OscillatorBank    │
     │   Configuration  │      │  │   (16x SourceNode) │
     │ ARPlaneAnchor    │      │  ├─ MixerNode         │
     │   detection      │      │  ├─ ReverbUnit        │
     │ LiDAR mesh       │      │  └─ OutputNode        │
     │   (refinement)   │      └──────────▲────────────┘
     └─────────┬────────┘                 │
               │                          │
     ┌─────────▼──────────────────────────┴────────────┐
     │                   RoomModel                      │
     │  dimensions: RoomDimensions   (from ARKit)       │
     │  modes: [RoomMode]            (computed)         │
     │  playerPosition: simd_float3  (live, from AR)    │
     │  func modeAmplitudes() → [Float]                 │
     └─────────────────────────────────────────────────┘
               │
     ┌─────────▼──────────────────────┐
     │      RoomGeometryProcessor     │
     │  input:  [ARPlaneAnchor]       │
     │  output: RoomDimensions        │
     │  - findFloor()                 │
     │  - findWalls() → Lx, Ly       │
     │  - findCeiling() → Lz         │
     │  - validateEnclosure()         │
     └────────────────────────────────┘
```

### File Structure
```
RoomTone/
├── RoomTone.xcodeproj/
├── RoomTone/
│   ├── App/
│   │   ├── RoomToneApp.swift              # @main, AVAudioSession .playback setup
│   │   └── AppState.swift                 # @Observable: scan phase, audio state, timbre
│   │
│   ├── ARKit/
│   │   ├── ARSessionManager.swift         # ARSession lifecycle, delegate, frame updates
│   │   ├── RoomGeometryProcessor.swift    # [ARPlaneAnchor] → RoomDimensions
│   │   └── LiDARRefinement.swift          # ARMeshAnchor bounding box → refine dimensions
│   │
│   ├── Audio/
│   │   ├── RoomAudioEngine.swift          # AVAudioEngine graph owner; start/stop/configure
│   │   ├── OscillatorBank.swift           # 16x AVAudioSourceNode; sine + harmonic generation
│   │   ├── ModeAmplitudeController.swift  # Player position → per-mode gain [Float]
│   │   ├── TimbreProcessor.swift          # Drone ↔ Ambient timbre switching + crossfade
│   │   └── AudioRecorder.swift            # installTap on mixer → AVAudioFile → share sheet
│   │
│   ├── Model/
│   │   ├── RoomDimensions.swift           # Struct: Lx, Ly, Lz in meters + derived properties
│   │   ├── RoomMode.swift                 # Struct: frequency, indices (n,m,l), axis, weight
│   │   └── RoomModel.swift                # @Observable: live dimensions + modes + position
│   │
│   ├── Physics/
│   │   └── RoomModeCalculator.swift       # f(n,m,l) formula; mode generation; octave-shift
│   │
│   ├── Views/
│   │   ├── ScanView.swift                 # Scan phase: progress, pan-prompt, mesh preview
│   │   ├── MainExperienceView.swift       # AR scene + audio active; timbre toggle; record
│   │   ├── AROverlayView.swift            # SwiftUI overlay: wireframe, wave anim, indicator
│   │   ├── UnsupportedDeviceView.swift    # LiDAR unavailable screen
│   │   └── SettingsView.swift             # Tech overlay toggle, room stats, export
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       ├── PrivacyInfo.xcprivacy          # Required for App Store since iOS 17
│       └── Info.plist                     # NSCameraUsageDescription, background audio mode
│
└── RoomToneTests/
    ├── RoomModeCalculatorTests.swift      # Unit tests: known rooms → verify frequencies
    └── RoomGeometryProcessorTests.swift   # Mock plane anchors → verify RoomDimensions
```

### Data Model

```swift
// MARK: - RoomDimensions.swift

struct RoomDimensions {
    let Lx: Float    // meters, longest horizontal dimension
    let Ly: Float    // meters, shortest horizontal dimension
    let Lz: Float    // meters, ceiling height

    var isValid: Bool { Lx > 0.5 && Ly > 0.5 && Lz > 0.5 }
    var volume: Float { Lx * Ly * Lz }

    /// True when any dimension > 8.5m (modes drop below 20Hz threshold)
    var requiresOctaveShift: Bool { max(Lx, Ly, Lz) > 8.5 }

    /// Reverberation time estimate (Sabine approximation, assumes avg absorption 0.15)
    var estimatedRT60: Float { (0.161 * volume) / (0.15 * 2 * (Lx*Ly + Lx*Lz + Ly*Lz)) }
}

// MARK: - RoomMode.swift

struct RoomMode: Identifiable {
    let id: UUID
    let n: Int            // x-axis index (0 = no variation along x)
    let m: Int            // y-axis index
    let l: Int            // z-axis index
    let frequency: Float  // Hz, post octave-shift if applied
    let axis: ModeAxis
    let perceptualWeight: Float  // 0.0–1.0; lower modes weight higher
    let wallAxis: WallAxis?      // which wall pair this mode is associated with (axial only)
}

enum ModeAxis {
    case axial      // energy in one dimension only (n,0,0 or 0,m,0 or 0,0,l)
    case tangential // energy in two dimensions
    case oblique    // energy in all three dimensions
}

enum WallAxis {
    case x  // associated with Lx walls (left/right)
    case y  // associated with Ly walls (front/back)
    case z  // associated with Lz surfaces (floor/ceiling)
}

// MARK: - AppState.swift

enum ScanPhase: Equatable {
    case idle
    case scanning(progress: Float)        // 0.0–1.0
    case confirmed(dimensions: RoomDimensions)
    case failed(reason: ScanFailureReason)
}

enum ScanFailureReason {
    case noEnclosure    // outdoor or open space: no ceiling detected after 20s
    case timeout        // 30s with no valid geometry
    case deviceUnsupported
}

enum AudioTimbre {
    case drone    // sine + 2nd harmonic at 5%, LFO 0.1Hz ±3% pitch drift
    case ambient  // sine → AVAudioUnitTimePitch (rate=0.85, overlap=8)
}
```

### Type Definitions

```swift
// MARK: - RoomModel.swift (live @Observable object)

@Observable
class RoomModel {
    var dimensions: RoomDimensions?
    var modes: [RoomMode] = []          // sorted by perceptualWeight desc; max 16 entries
    var playerPosition: simd_float3 = .zero
    var scanProgress: Float = 0.0       // 0.0–1.0
    var isEnclosureConfirmed: Bool = false
    var octaveShiftActive: Bool = false

    /// Primary output consumed by OscillatorBank on every audio frame
    /// Returns amplitude multiplier [0.0–1.0] for each mode in self.modes
    func modeAmplitudes() -> [Float]

    /// Called by ARSessionManager on every ARFrame (main thread)
    func updatePlayerPosition(_ transform: simd_float4x4)

    /// Called by RoomGeometryProcessor when new plane anchors confirmed
    func updateDimensions(_ dimensions: RoomDimensions)
}

// MARK: - ModeAmplitudeController.swift (pure struct, testable)

struct AmplitudeCalculation {
    let modeIndex: Int
    let baseWeight: Float         // perceptualWeight from RoomMode
    let proximityBoost: Float     // 0.0–1.0, from player distance to associated wall
    let lfoModulation: Float      // slow oscillation, ±0.05
    let finalAmplitude: Float     // baseWeight × (1 + proximityBoost) × (1 + lfoModulation)
}

// Proximity boost formula:
// wallDistance = distance from playerPosition to mode's associated wall plane
// proximityBoost = max(0, 1 - (wallDistance / peakRadius)) where peakRadius = 0.3m
// Result: amplitude peaks when player is within 30cm of wall; drops linearly to 0 at 30cm+
```

### API Contracts

No external APIs. All processing is on-device.

**ARKit Interfaces Used:**
| API | Purpose | Notes |
|-----|---------|-------|
| `ARWorldTrackingConfiguration.sceneReconstruction = .mesh` | Enable LiDAR mesh | Requires LiDAR hardware |
| `ARWorldTrackingConfiguration.planeDetection = [.horizontal, .vertical]` | Floor + wall detection | Primary dimension source |
| `ARSession.currentFrame?.camera.transform` | Player position (simd_float4x4) | Called every frame at 60fps |
| `ARPlaneAnchor.center`, `.extent`, `.transform` | Wall/floor dimensions | Extent gives width × height in plane local space |
| `ARPlaneAnchor.classification` | `.floor`, `.wall`, `.ceiling` | iOS 12+ classification accuracy |
| `ARSession.currentFrame?.sceneReconstruction?.anchors` | LiDAR mesh anchors | Used for bounding box refinement only |

**AVAudioEngine Graph:**
```
AVAudioSourceNode (×16, one per mode)
    └─→ AVAudioMixerNode (main mix)
            ├─→ AVAudioUnitTimePitch (Ambient timbre only; bypassed for Drone)
            ├─→ AVAudioUnitReverb (room reverb, wetDryMix from RT60 estimate)
            └─→ AVAudioEngine.outputNode
```

### Dependencies

```bash
# No package manager needed — all system frameworks
# In Xcode → Target → Frameworks, Libraries, and Embedded Content:
# These are auto-included with the ARKit project template:
#   ARKit.framework
#   AVFoundation.framework (includes AVAudioEngine)
#   SceneKit.framework (for AR overlay wireframe geometry)
# simd is part of the Swift standard library — no import needed beyond `import simd`

# Xcode project requirements:
# - Deployment Target: iOS 17.0
# - Supported Destinations: iPhone (not iPad — LiDAR check will gate non-Pro iPads anyway)
# - Capabilities: Background Modes → Audio, AirPlay, and Picture in Picture
# - Info.plist keys to add manually:
#   NSCameraUsageDescription: "Room Tone uses the camera to map room geometry 
#     for acoustic synthesis — no images are stored or transmitted."
#   UIRequiredDeviceCapabilities → arkit (array entry); LiDAR remains runtime-checked
```

---

## Scope Boundaries

**In scope:**
- LiDAR room scanning via ARKit plane detection + mesh
- Real-time resonant mode calculation from room dimensions
- 16-oscillator audio synthesis responding to player position
- Drone timbre (sine + 2nd harmonic + LFO) and Ambient timbre (granular via AVAudioUnitTimePitch)
- Seamless timbre crossfade (< 50ms)
- Audio recording (tap on mixer → WAV) + share sheet export
- Minimal AR visual overlay: translucent wireframe + standing wave animation on walls
- Player position indicator with dominant frequency readout
- Technical overlay toggle (Hz values, room dimensions, mode indices)
- Scan calibration UX (progress indicator, pan prompt)
- Unsupported device screen
- Outdoor/open space detection with graceful prompt
- Large room octave-shift (auto, when any dimension > 8.5m)
- 3-screen onboarding (first launch only)
- App Store submission

**Out of scope (v1):**
- Non-LiDAR device fallback
- iPad as a separate layout (iPhone-only UI)
- Microphone input of any kind
- Network connectivity, analytics, or backend
- Sound design export (Ableton preset, etc.)
- Multi-room composition
- Collaborative mode
- Haptic feedback layer

**Deferred to v2:**
- Multi-room composition (scan multiple rooms, transition between characters)
- Sound design export as Ableton/DAW preset
- Room comparison mode (A/B two rooms)
- Haptic feedback pulsing with dominant mode

---

## Security & Credentials

- **No credentials.** No backend, no API keys, no user accounts.
- **No microphone.** All audio is synthesized. `NSMicrophoneUsageDescription` must NOT be added (would cause App Store confusion about audio recording purpose).
- **Camera usage:** ARKit only. No `AVCaptureSession`, no `PHPhotoLibrary`, no image storage. `NSCameraUsageDescription` must be specific: *"Room Tone uses the camera to map room geometry for acoustic synthesis — no images are stored or transmitted."*
- **Recorded audio:** Written to `FileManager.default.temporaryDirectory` only. Handed to `UIActivityViewController` for user control. Deleted from temp on next app launch.
- **Privacy manifest (PrivacyInfo.xcprivacy):** Required for App Store. Declare: no data collection, camera used for room mapping (not stored), no tracking, no required reason APIs used.
- **`UIRequiredDeviceCapabilities`:** Declare Apple's supported `arkit` capability and retain the runtime LiDAR mesh-reconstruction check. Apple does not document a `lidar-sensor` capability key.

---

## Phase 0: Foundation (Weeks 1–2)

**Objective:** Working Xcode project, LiDAR device check, AVAudioEngine producing a single sine tone, basic SwiftUI shell. Zero ARKit. This phase is entirely about learning the iOS toolchain before stacking the hard stuff.

**Tasks:**
1. Create Xcode project: App template, SwiftUI interface, iOS 17.0 minimum deployment target, Team set to your developer account — **Acceptance:** App runs on physical device and in simulator without warnings or signing errors
2. Add LiDAR device capability check: in `RoomToneApp.swift`, call `ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)` at launch; if false, present `UnsupportedDeviceView` and disable all AR — **Acceptance:** iPhone 13 Pro shows experience; iPhone 11 shows `UnsupportedDeviceView` (use an older device or have a colleague test)
3. Configure `Info.plist`: add `NSCameraUsageDescription` (exact text from Security section above); add `UIBackgroundModes` array with `audio` value; add `UIRequiredDeviceCapabilities` array with Apple's supported `arkit` entry; keep LiDAR as a runtime capability check — **Acceptance:** Running on device, camera permission prompt appears with correct description text; no entitlement warnings in Xcode build log
4. Build `AVAudioEngine` skeleton in `RoomAudioEngine.swift`: instantiate engine, attach `AVAudioMixerNode`, connect mixer → `engine.outputNode`, call `engine.prepare()` and `engine.start()` — **Acceptance:** No crash on launch; `engine.isRunning == true` logged to console on device
5. Add one `AVAudioSourceNode` generating a 440Hz sine wave and connect it to the mixer; implement render callback with pre-allocated `[Float]` buffer — **Acceptance:** Audible 440Hz tone on device speaker; no audio glitches or dropouts over 60 seconds of playback
6. Build `AppState.swift` with `ScanPhase` enum; build `ScanView.swift` shell with a "Start Scanning" button that transitions `AppState.phase` to `.scanning(progress: 0.0)` — **Acceptance:** Phase transitions compile cleanly; `ScanView` renders in Preview and on device

**Verification checklist:**
- [ ] Run on physical LiDAR device → single 440Hz sine plays for 60s, no glitch
- [x] Run on non-LiDAR Simulator → `UnsupportedDeviceView` appears (verified July 2026)
- [ ] Rotate device → `ScanView` layout adapts without overflow or clipping
- [ ] Xcode Organizer → no crashes logged after 5 minutes of idle + tone playing

**Risks:**
- `AVAudioSession` category conflict with Silent Mode: set `.playback` category explicitly in `RoomToneApp.init()` before `engine.start()`. Silent Mode should not mute synthesized audio. If it does, add `.mixWithOthers` option.
- Signing / provisioning on first physical device: allocate 1–2 hours for this on day 1 if you haven't shipped to a physical device before. Apple Developer account required.

---

## Phase 1: Audio Engine (Weeks 3–4)

**Objective:** Full `OscillatorBank` with 16 oscillators, per-mode amplitude control, both timbres operational, and audio recording — all driven by hardcoded `RoomDimensions` for a 4m × 3m × 2.5m test room. No ARKit yet. The concept becomes audible this phase.

**Tasks:**
1. Build `RoomModeCalculator.swift`: implement `f(n,m,l) = (343.0 / 2.0) * sqrt(pow(Float(n)/Lx, 2) + pow(Float(m)/Ly, 2) + pow(Float(l)/Lz, 2))`; generate modes for n,m,l in 0...3 (excluding 0,0,0); sort by `perceptualWeight = 1.0 / (1.0 + frequency)`; return top 16; apply octave-shift if `dimensions.requiresOctaveShift` — **Acceptance:** `RoomModeCalculatorTests` pass: 5m×4m×3m room produces axial modes at 34.3Hz (x), 42.9Hz (y), 57.2Hz (z) ±1.5Hz
2. Build `OscillatorBank.swift`: 16 `AVAudioSourceNode` instances connected to mixer; each node stores its assigned `RoomMode` and renders the frequency in its callback using `phase += (2π × frequency) / sampleRate` accumulator; connect all 16 to `AVAudioMixerNode` — **Acceptance:** 16 oscillators running simultaneously; CPU < 15% on device (verify in Instruments → Time Profiler); no audio dropout over 2 minutes
3. Build `ModeAmplitudeController.swift`: pure struct; input: player position (`simd_float3`) + `RoomDimensions` + `[RoomMode]`; compute per-mode amplitude using proximity boost formula (see Type Definitions section); return `[Float]` of length 16 — **Acceptance:** With a slider simulating player x-position 0→Lx, the mode associated with the x-axis wall rises from ~0.3 to ~1.0 in amplitude; ≥ 6dB change audible
4. Implement Drone timbre: each oscillator renders fundamental + 2nd harmonic (amplitude = 0.05 × fundamental); add LFO: `phaseOffset = sin(lfoPhase) * 0.03 * frequency` where lfoPhase advances at 0.1Hz — **Acceptance:** Audible tonal warmth vs raw sine; no beating artifacts between adjacent modes
5. Implement Ambient timbre in `TimbreProcessor.swift`: insert `AVAudioUnitTimePitch` between mixer output and reverb; set `pitch = 0`, `rate = 0.85`, `overlap = 8`; crossfade between Drone (unit bypassed) and Ambient (unit active) over 80ms — **Acceptance:** Distinct granular/textural character in Ambient mode; crossfade produces no audible click or gap; < 50ms perceived transition
6. Build `AudioRecorder.swift`: `engine.mainMixerNode.installTap(onBus:bufferSize:format:block:)` → write PCM to `AVAudioFile` at `FileManager.default.temporaryDirectory/roomtone-{timestamp}.wav`; stop tap and present `UIActivityViewController` on demand — **Acceptance:** 60-second recording exports as .wav; file plays correctly in iOS Files app; file size ~10MB for 60s at 44.1kHz mono

**Verification checklist:**
- [ ] `RoomModeCalculatorTests` — all test cases green in Xcode
- [ ] On device: 16 oscillators active, CPU < 15% (Instruments → Time Profiler, 2-minute run)
- [ ] Slider → x-axis wall mode amplitude change audible + confirmed in debug log
- [ ] Record 60s → share → open in Voice Memos → clean playback
- [ ] Drone timbre → Ambient timbre toggle → no click/pop; distinct character difference

**Risks:**
- Render callback thread safety: `OscillatorBank` must expose a lock-free mechanism for `ModeAmplitudeController` to update amplitudes. Use a double-buffer: maintain two `[Float]` arrays; the audio thread reads from the current buffer; the main thread writes to the pending buffer; use `os_unfair_lock` for the swap only (not inside the callback).
- `AVAudioUnitTimePitch` granular mode latency: it introduces ~100ms of latency at `rate=0.85`. This is acceptable — the experience is ambient, not reactive. Document in code comments.

---

## Phase 2: ARKit Integration (Weeks 5–6)

**Objective:** Real room scan produces real `RoomDimensions`; audio responds to actual player movement. The concept works end-to-end. Demo video becomes possible at end of this phase.

**Tasks:**
1. Build `ARSessionManager.swift`: configure `ARWorldTrackingConfiguration` with `.sceneReconstruction = .mesh` and `planeDetection = [.horizontal, .vertical]`; implement `ARSessionDelegate`; publish detected `[ARPlaneAnchor]` via `@Observable` property — **Acceptance:** Plane anchors detected and logged to console within 10 seconds of scanning a rectangular room
2. Build `RoomGeometryProcessor.swift`: input `[ARPlaneAnchor]`; identify floor (`.floor` classification, lowest y-value); find ≥2 perpendicular wall anchors; extract Lx from wall with larger extent, Ly from wall with smaller extent; estimate Lz from ceiling anchor extent or (if no ceiling) from LiDAR mesh bounding box top minus floor y — **Acceptance:** Scan a 4m × 3m × 2.5m room → `RoomDimensions` within 15% of tape measure values
3. Wire `RoomModel.updatePlayerPosition()` to `ARFrame.camera.transform` in `ARSessionManager.session(_:didUpdate:)` — **Acceptance:** `playerPosition` updating at 30fps+ confirmed via console logging; no main thread warnings in Xcode runtime issues
4. Connect live `RoomModel.modeAmplitudes()` → `OscillatorBank.setAmplitudes()`: call this on every ARFrame update; `OscillatorBank` writes to pending amplitude buffer; audio thread reads from current buffer — **Acceptance:** Walking toward a wall → audible amplitude increase in that wall's associated mode within 500ms
5. Implement scan confirmation logic in `RoomModel`: `scanProgress` increments as each plane classification is confirmed (floor = 0.33, first wall = 0.66, second perpendicular wall = 1.0); transition `AppState.scanPhase` to `.confirmed` — **Acceptance:** Scan phase completes in real room within 20 seconds of normal device panning
6. Implement large room octave-shift: when `dimensions.requiresOctaveShift == true`, in `RoomModeCalculator` multiply all frequencies by `pow(2, ceil(log2(40.0 / lowestFrequency)))` — **Acceptance:** Simulated 10m × 8m × 4m dimensions produce no frequencies below 40Hz in generated modes

**Verification checklist:**
- [ ] Scan a real room → `ScanPhase.confirmed` within 20 seconds
- [ ] Log `RoomDimensions` → values within 15% of measurements with tape measure
- [ ] Walk to wall → dominant mode amplitude increases (logged + audible)
- [ ] Stand in room center → amplitudes roughly equal across modes (no single dominant)
- [ ] Set Lx=10.0 in processor manually → no sub-40Hz frequencies generated

**Risks:**
- Plane anchor instability: ARKit anchors shift during the first 5–10 seconds of a session. Add debounce: only accept a `RoomDimensions` update when 3 consecutive anchor readings are within 10% of each other. Implement in `RoomGeometryProcessor` with a reading history buffer.
- Thread safety on `RoomModel`: `updatePlayerPosition()` is called on the main thread (ARKit delegate); `modeAmplitudes()` may be called from audio thread. Make `playerPosition` a `var` with `nonisolated(unsafe)` or use an `Atomic` wrapper to avoid Swift 6 concurrency warnings. Document the pattern clearly.
- No ceiling anchor in open-plan spaces: fall back to LiDAR mesh bounding box top. If mesh is also unavailable, use 2.7m (standard ceiling height) as default and log a warning.

---

## Phase 3: Visual Overlay (Weeks 7–8)

**Objective:** Minimal AR visual layer — translucent wall wireframes, standing wave animations, player position indicator. Sound remains primary; visuals reinforce without competing.

**Tasks:**
1. Wrap `ARSCNView` in `UIViewRepresentable` for use in SwiftUI; layer `AROverlayView` (SwiftUI `ZStack`) on top as transparent overlay — **Acceptance:** Camera feed visible; SwiftUI overlay renders at correct size on iPhone 14 Pro and iPhone 15 Pro screen sizes; no visual artifacts at overlay edges
2. Render translucent wall wireframes: for each confirmed wall `ARPlaneAnchor`, add an `SCNPlane` node with a wireframe material (`fillMode = .lines`, diffuse color white at 10% opacity) sized to anchor extent — **Acceptance:** Wall planes highlighted in subtle overlay; wireframes track plane anchors as they update; no floating geometry in non-planar areas
3. Implement standing wave animation on wall surfaces: in `AROverlayView`, draw a sine wave path using SwiftUI `Canvas` with `Path`; animate node positions (bright) and antinode positions (dim) by driving phase offset with a `TimelineView(.animation(minimumInterval: 0.1))`; scale wave amplitude by current mode amplitude from `RoomModel` — **Acceptance:** Wall animation visually responds to player movement; amplitude changes visible within 500ms of position change; update rate 10fps (not 30fps — intentionally subtle)
4. Add player position indicator: centered in screen, a small radial gradient pulse view; below it, display dominant mode frequency in Hz (largest amplitude in `RoomModel.modes`) — **Acceptance:** Indicator renders without obscuring main camera view; frequency value updates as player moves and dominant mode changes
5. Build `SettingsView.swift`: toggle for technical overlay (shows all mode frequencies in Hz, room dimensions Lx/Ly/Lz, scan quality indicator); toggle is off by default — **Acceptance:** Technical overlay toggle persists across sessions via `UserDefaults`; Hz values match `RoomModeCalculator` output for current room

**Verification checklist:**
- [ ] Instruments → GPU Frame Capture during full AR + overlay session: frame time < 16ms
- [ ] Wall wireframes appear only on confirmed plane anchors (not floating mid-air)
- [ ] Standing wave animation responds visually to walking toward a wall
- [ ] Technical overlay off by default on fresh install; toggle persists after restart
- [ ] Dominant frequency indicator shows plausible Hz value (verify against room dimensions)

**Risks:**
- `ARSCNView` + SwiftUI ZStack compositing: if the camera feed flickers, ensure `ARSCNView` is the base layer with `backgroundColor = .clear` on the SwiftUI overlay. Do not nest `ARSCNView` inside a `GeometryReader`.
- `SCNPlane` wireframe on large walls: if wall extent is very large (> 5m), the `SCNPlane` may have visible seams. Use `SCNPlane(width:height:)` sized to `anchor.extent.x × anchor.extent.z` and position it at `anchor.center` in world space.

---

## Phase 4: Polish + App Store (Weeks 9–10)

**Objective:** Onboarding, App Store assets, TestFlight beta, submission.

**Tasks:**
1. Build onboarding: 3-screen `TabView` carousel on first launch; screens: (1) "Your room has a voice." — concept framing, (2) "Walk to hear it change." — interaction explanation, (3) "LiDAR maps the geometry." — technical hook. Store `hasSeenOnboarding: Bool` in `UserDefaults` — **Acceptance:** Shows on first launch; absent on second launch; dismisses cleanly to `ScanView`
2. Build scan calibration UX in `ScanView`: animated "pan your device around the room" prompt with plane detection progress (floor ✓ / wall 1 ✓ / wall 2 ✓); audio fades in from 0 over 3 seconds as `scanProgress` goes 0 → 1 — **Acceptance:** New user in a real room reaches `.confirmed` state following prompts in < 30 seconds; audio fade-in is smooth (no click)
3. Implement outdoor/open space handling: if no ceiling plane detected and `scanProgress` has not reached 0.66 after 20 seconds, transition to `.failed(.noEnclosure)`; show "Room Tone works best in enclosed spaces — try a room with a ceiling" with "Try Anyway" button that forces `.confirmed` with estimated dimensions — **Acceptance:** Tested in an outdoor or large open area; no crash; prompt appears with both options functional
4. Generate App Store assets: screenshots at required sizes for iPhone 15 Pro (6.7" — 1290×2796) and iPhone 15 Pro Max (6.7" — same); App Preview video 30 seconds maximum, landscape or portrait, showing: scan → sound emerges → walk → sound evolves → corner cluster — **Acceptance:** All required screenshot sizes in App Store Connect; video < 30s; exports at 1080p minimum
5. TestFlight beta: invite 3–5 testers across different room types (bedroom, kitchen, parking garage, office); provide structured test script: "scan the room, walk to each wall, stand in the center, try both timbres, record 30 seconds, share the recording" — **Acceptance:** 0 crashes across all testers; collect and triage feedback in Xcode Organizer
6. App Store submission: complete privacy manifest (`PrivacyInfo.xcprivacy`), set age rating to 4+, write app description emphasizing "room geometry → synthesized sound, no recording of the environment", submit for review — **Acceptance:** App passes review on first submission; no rejection for camera usage or audio background mode

**Verification checklist:**
- [ ] Clean install → onboarding appears → dismissed → does not appear on relaunch
- [ ] Full user journey under 2 minutes: open → scan → hear room → record → share
- [ ] TestFlight: 0 crash reports in Xcode Organizer across all testers
- [ ] App Store Connect: no missing metadata, all screenshots uploaded, binary processed successfully
- [ ] Privacy manifest: Xcode → Product → Archive → Validate → no privacy policy warnings

**Risks:**
- App Review rejection for camera: the most common reason for ARKit app rejection is an unclear or missing `NSCameraUsageDescription`. Use exact text from Security section. If rejected, respond within 24 hours via Resolution Center with clarification that no images are captured or stored.
- App Review timeline: 1–7 business days is typical; plan to submit 2 weeks before any target date.
- Audio background mode justification: if Apple asks why background audio mode is needed, the answer is: "Users may lock their device while walking through a space and listening — the audio experience should continue." This is legitimate under App Store guidelines §2.5.4.
