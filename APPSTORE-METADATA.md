# App Store Metadata — Room Tone

## Identity

| Field | Value |
|---|---|
| Name | Room Tone |
| Subtitle | Hear Your Room's Resonance |
| Bundle ID | com.roomtone.app |
| SKU | ROOMTONE-001 |
| Primary Category | Music |
| Secondary Category | Utilities |
| Age Rating | 4+ |
| Price | $2.99 |
| Availability | All territories |

---

## Keywords

*(100 character limit — comma-separated)*

```
LiDAR,acoustic,resonance,room,synthesis,sound,ARKit,spatial,ambient,drone,audio,scanner
```

Character count: 88

---

## Description

*(4,000 character limit)*

**Every room has a voice. Room Tone lets you hear it.**

Physics says that any enclosed space has natural resonant frequencies — specific pitches determined by its exact dimensions. A 4-meter room resonates at 42.75 Hz along its length. Your bedroom, your kitchen, a parking garage — each one has a unique acoustic fingerprint that has always been there, inaudible until now.

Room Tone uses your iPhone Pro's LiDAR scanner to map your room's geometry in seconds, then synthesizes a real-time soundscape from its resonant modes. Walk toward a wall and that wall's frequency rises in the mix. Stand in a corner and the converging modes create something no speaker, no synthesizer, and no recording has ever produced — the voice of that specific space.

**How it works**

Point your iPhone around the room for a few seconds. Room Tone detects the floor, walls, and ceiling through ARKit plane detection, computes the room's axial, tangential, and oblique resonant modes, and brings up to 16 oscillators tuned precisely to those frequencies. The result is a generative soundscape that exists only in this room, only right now.

Move through the space and the sound changes. The synthesizer tracks your position continuously — amplitude rises as you approach the wall whose frequency is playing, falls as you move away. The room becomes a spatial instrument.

**Two timbres**

Switch between Drone and Ambient at any time:

- **Drone** — pure sine oscillators with a subtle second harmonic and a slow 0.1 Hz pitch drift that gives the sound organic warmth
- **Ambient** — the same oscillators processed through a granular time-stretch algorithm, creating a textural, cloud-like soundscape from the same room geometry

**Record and share**

Tap the record button to capture a WAV recording of your room's voice. Share it directly from the app — to Voice Memos, Files, AirDrop, or any other destination. Every room produces a unique recording.

**Requirements**

Room Tone requires a LiDAR-equipped device: iPhone 12 Pro, iPhone 13 Pro, iPhone 14 Pro, iPhone 15 Pro, iPhone 16 Pro, or any iPad Pro with LiDAR. The app displays a clear explanation screen on unsupported devices.

Room Tone works best in enclosed spaces with a ceiling. Open-plan spaces and outdoor environments will produce a prompt to try an enclosed room, with the option to continue with estimated dimensions.

**No microphone. No recording of your environment.**

Room Tone synthesizes audio entirely from geometry — it does not listen to your room. The camera is used only for LiDAR spatial mapping; no images are stored or transmitted. There is no backend, no user account, no analytics, and no network connection of any kind.

---

## Promotional Text

*(170 character limit — can be updated without a new app review)*

```
Scan any room. Hear its resonant frequencies synthesized in real time. A generative instrument that lives in your walls.
```

Character count: 120

---

## Support and Privacy URLs

| Field | URL |
|---|---|
| Support URL | https://[placeholder]/roomtone/support |
| Marketing URL | https://[placeholder]/roomtone |
| Privacy Policy URL | https://[placeholder]/roomtone/privacy |

*Replace with actual URLs before submission.*

---

## Screenshots Plan

### iPhone 6.9" (iPhone 16 Pro Max — 1320×2868 px) — 4 required

| # | Screen | Description | Key elements to show |
|---|---|---|---|
| 1 | Scan phase in progress | ScanView during active scan showing scan progress indicators and AR mesh preview | Progress checklist (floor ✓, wall 1 ✓, wall 2 pending), AR wireframe mesh visible on walls, "pan your device around the room" instruction |
| 2 | Main experience — Drone timbre | MainExperienceView active with audio playing in a living room | Translucent wireframe overlay on walls, standing wave animation visible on the nearest wall, player position indicator at screen center with dominant frequency readout (e.g. "42 Hz"), Drone/Ambient toggle in corner |
| 3 | Ambient timbre — textural visualization | Same room, Ambient timbre selected | Standing wave animation subtly different (more diffuse), Ambient button highlighted, same wireframe overlay — shows the two distinct visual states |
| 4 | Technical overlay + record button active | SettingsView technical overlay enabled, recording in progress | Room dimensions (Lx / Ly / Lz) displayed, all active mode frequencies listed in Hz, record button showing elapsed time, room stats visible |

### iPad 13" (iPad Pro M4 — 2064×2752 px) — 4 required

| # | Screen | Description |
|---|---|---|
| 1 | Scan phase on iPad | Wider AR scan view showing more room coverage, progress indicators in larger format |
| 2 | Main experience in landscape | Full landscape AR experience view showing wall wireframes across a wide angle |
| 3 | Standing wave animation close-up | Close crop of wall wireframe with standing wave animation clearly visible, dominant frequency prominent |
| 4 | Share sheet open | WAV export share sheet presented over the main experience view, showing share destination options |

---

## App Review Notes

**Device requirement:** Room Tone requires LiDAR hardware. Testing on an unsupported device (any non-Pro iPhone, or iPhone Pro earlier than 12 Pro) will show the `UnsupportedDeviceView` screen — this is correct and intentional behavior, not a bug. The `UIRequiredDeviceCapabilities` key in `Info.plist` includes `lidar-sensor`, which restricts App Store visibility to compatible devices.

**Camera permission:** The app requests camera access for ARKit LiDAR scanning only. The exact permission string is: *"Room Tone uses the camera to map room geometry for acoustic synthesis — no images are stored or transmitted."* No `AVCaptureSession` is used; no photos or video are captured or stored.

**How to test the core flow:**

1. Launch the app on a supported LiDAR device (iPhone Pro or iPad Pro)
2. Grant camera permission when prompted
3. On the Scan view, slowly pan the device to cover the floor, then both walls, then ceiling
4. Scan typically completes in 10–20 seconds in a normally sized room
5. Audio will fade in automatically as scan progress reaches 100%
6. Walk toward any wall — the audio will change as proximity to that wall increases
7. Tap the Drone/Ambient toggle to switch timbres (no audio gap)
8. Tap Record, wait 10 seconds, tap Stop, then use the share sheet to export

**Background audio:** The app uses the `audio` background mode so users can lock their device while walking through a space. Audio continues playing when the device is locked. This is declared in `Info.plist` and justified under App Store guideline §2.5.4 (continuous audio experience).

**No network connections.** Room Tone makes zero outbound network requests. It contains no analytics SDK, no crash reporter, and no advertising SDK.

**Outdoor / open space behavior:** If the scanner does not detect a ceiling within 20 seconds, the app presents a "Room Tone works best in enclosed spaces" message with a "Try Anyway" button. Tapping "Try Anyway" uses estimated dimensions and continues. This is not a crash or error state.

---

## Submission Checklist

### Metadata
- [ ] App name: "Room Tone" — confirm no trademark conflict
- [ ] Subtitle within 30 characters
- [ ] Keywords within 100 characters
- [ ] Description does not claim microphone access or environmental recording (the app does not use a microphone — description is accurate)
- [ ] Promotional text within 170 characters
- [ ] Support URL live and resolves
- [ ] Privacy Policy URL live — states: no data collected, camera used for geometry mapping only, no images stored

### Screenshots
- [ ] iPhone 6.9" — 4 screenshots at 1320×2868 px, captured on physical LiDAR device
- [ ] iPhone 6.1" — 4 screenshots (or promote 6.9" screenshots — accepted)
- [ ] iPad 13" — 4 screenshots at 2064×2752 px
- [ ] No screenshots contain identifiable room contents, faces, or personal items
- [ ] Standing wave animation visible in at least one screenshot (captures an in-progress frame, not a static moment)

### Build
- [ ] `xcodebuild archive` succeeds on Release scheme, zero warnings under Swift 5.10
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) declares: camera used for room mapping, no data collection, no tracking, no required-reason APIs
- [ ] `Info.plist` contains `UIRequiredDeviceCapabilities` → `lidar-sensor`
- [ ] `Info.plist` contains `NSCameraUsageDescription` with exact approved text
- [ ] `Info.plist` contains `UIBackgroundModes` → `audio`
- [ ] App icon present in all required sizes
- [ ] Version 1.0, build number set

### App Store Connect
- [ ] Age rating: 4+
- [ ] Export compliance: standard encryption only (HTTPS) — answer "No" to proprietary encryption
- [ ] Primary category: Music; Secondary: Utilities
- [ ] Price: $2.99
- [ ] `UIRequiredDeviceCapabilities` restriction means the App Store will automatically hide this app from users on non-LiDAR devices — verify this filter is active in Connect
- [ ] TestFlight: tested on at least 3 room types (bedroom, kitchen, open-plan/garage as unsupported test), 0 crashes across all testers
- [ ] App Review Notes field completed with LiDAR device requirement and test instructions
