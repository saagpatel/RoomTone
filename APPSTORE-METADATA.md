# App Store Metadata - Room Tone

## Identity

| Field | Value |
|---|---|
| Name | Room Tone: Resonance Synth |
| Subtitle | Hear Your Room's Resonance |
| Bundle ID | com.romtone.app |
| SKU | ROOMTONE-001 |
| Primary Category | Music |
| Secondary Category | Utilities |
| Age Rating | 4+ |
| Price | $2.99 |
| Availability | All territories |


Store settings above are proposed submission values, except the Name and Bundle ID supplied by the dispatcher. Confirm the remaining values in App Store Connect before submission.

---

## Keywords

*(100 character limit, comma-separated)*

```
LiDAR,acoustic,resonance,room,synthesis,sound,ARKit,spatial,ambient,drone,audio,scanner
```

Character count: 87

---

## Description

*(4,000 character limit; use the text inside the block)*

```
Your room has a sound. Room Tone lets you explore it.

Room Tone turns estimated room dimensions into a synthesized soundscape. It uses LiDAR and ARKit on a supported device to estimate geometry, then calculates resonant frequencies for a rectangular room model. A 4-meter dimension gives a fundamental axial mode near 42.9 Hz.

Scan and listen

Tap Start Scanning and pan around an enclosed room. The app looks for a floor and perpendicular walls. Ceiling height comes from a detected ceiling, mesh height, or a 2.7-meter default. Scans depend on the geometry ARKit can detect and may fail to confirm a room.

Up to 16 oscillators play frequencies calculated from the estimated dimensions. Your tracked position feeds a simplified amplitude model based on the scan origin and room dimensions.

Two timbres

Choose Drone for sine tones with a second harmonic and slow modulation. Choose Ambient for sine tones processed with time stretching. Reverb is adjusted using an estimate from the room dimensions.

See the model

The camera view includes abstract wave curves drawn on the screen. Open Settings to enable Technical Overlay and see calculated mode frequencies, estimated dimensions, and tracked position.

Requirements and privacy

Room Tone requires iOS 17 or later and an iPhone or iPad that supports LiDAR mesh reconstruction. Unsupported devices show LiDAR Required.

Geometry processing and audio synthesis run on your device. No microphone is used. The app does not save photos or video. There is no account, analytics, or tracking. Support and Privacy Policy open web pages. Sharing a file uses a destination you choose in the system share sheet.
```

---

## Promotional Text

*(170 character limit)*

```
Turn estimated room dimensions into sound with LiDAR. Explore calculated resonant modes and choose Drone or Ambient on a supported iPhone or iPad.
```

Character count: 146

---

## Support and Privacy URLs

| Field | URL |
|---|---|
| Support URL | https://github.com/saagpatel/RoomTone/issues |
| Marketing URL | https://github.com/saagpatel/RoomTone |
| Privacy Policy URL | https://github.com/saagpatel/RoomTone/blob/main/PRIVACY.md |

Confirm that these URLs resolve before submission.

---

## Screenshots Plan

Capture the current Release UI on supported LiDAR hardware. The plan uses portrait images. Frequency values and detected wireframes depend on the scan; use what the app displays. Wave curves are screen-space graphics. They are not projected onto walls and do not change shape with the timbre selection.

### iPhone 6.9-inch (1320x2868 px), four planned captures

| # | Screen | What to capture |
|---|---|---|
| 1 | Scan in progress | Camera view, "Pan your device around the room", Floor, Wall, Perpendicular wall, and progress bar. Detected wall planes can show wireframe outlines. |
| 2 | Main experience, Drone | Estimated dimensions at the top, displayed dominant frequency, abstract wave curves, and Timbre picker with Drone selected. |
| 3 | Main experience, Ambient | Ambient selected in the same Timbre picker. Use the current wave curves without inventing a different visualization. |
| 4 | Main experience, Technical Overlay | Tap the gear icon, enable Technical Overlay, then tap Done. Capture the dimensions, position, mode-frequency list, and Record control in the main view. |

### iPad 13-inch (2064x2752 px), four planned captures

The target includes iPad (`TARGETED_DEVICE_FAMILY = 1,2`), so include this set.

| # | Screen | What to capture |
|---|---|---|
| 1 | Scan in progress | Portrait camera view with Floor, Wall, Perpendicular wall, instruction, and progress bar. |
| 2 | Main experience, Drone | Portrait main view with dimensions, frequency display, screen-space wave curves, and Drone selected. |
| 3 | Main experience, Technical Overlay | Enable Technical Overlay in Settings, tap Done, and capture the mode-frequency list and tracked position in the main view. |
| 4 | Settings | Open the gear icon and capture Display, Technical Overlay, Room statistics, Privacy Policy, Support, and Done. Octave Shift appears only when applicable. |

---

## App Review Notes

**Device requirement:** The core scan requires LiDAR mesh reconstruction and iOS 17 or later. On a fresh launch, swipe through the three onboarding pages and tap "Get Started" on the last page. A simulator or unsupported device then shows "LiDAR Required". It cannot demonstrate the scan or soundscape. Use a compatible physical iPhone or iPad for the steps below. The build checks support at runtime; its declared device capability is `arkit`, not a LiDAR-specific store filter.

**Camera permission:** Tap "Start Scanning", then grant camera permission if prompted. Camera access is used for ARKit geometry mapping. The app does not save photos or video and requests no microphone access. If permission is denied, the screen shows "Camera Access Required" with "Open Settings" and "Retry". Enable camera access in system Settings, return to Room Tone, tap "Retry", then "Start Scanning".

**Core flow on supported hardware:**

1. After onboarding, tap "Start Scanning" and allow camera access.
2. Slowly pan across the floor and perpendicular walls of an enclosed room. The scan shows "Pan your device around the room", "Floor", "Wall", and "Perpendicular wall" with a progress bar. Ceiling height can be estimated without detecting a ceiling.
3. When dimensions stabilize, the main view opens with estimated dimensions and a frequency display. Audio can start while preliminary dimensions are available. Scan duration and audible output depend on the device and detected geometry; there is no promised completion time or fade tied to the progress bar.
4. Move the device to exercise position tracking. Position feeds an axis-aligned amplitude approximation based on the scan origin. It does not map detected physical walls or corners to the sound, and movement may not produce a noticeable change at a given location.
5. In "Timbre", select "Ambient" or "Drone". Switching briefly mutes the mixer. The wave visualization does not have separate timbre styles.
6. Tap the gear icon to open "Settings". Enable "Technical Overlay" and tap "Done" to see dimensions, position, and mode frequencies in the main view.
7. To inspect the file controls, tap "Record", then "Stop Recording". If a file is returned, "Share Recording" appears; tap it for the system share sheet. Available destinations depend on the device. The file uses a WAV extension, but audible capture of the live synthesis has not been verified: the recorder taps the main mixer while synthesis is routed directly to output. Do not treat file creation as proof of captured sound. If recording cannot start, the app shows "Recording Unavailable".

**If scanning fails:** The current location may not provide enough geometry. "No Enclosed Space" can appear when detection progress is insufficient after 20 seconds. "Scan Timed Out" can appear after 30 seconds without confirmation. These are not tests for ceiling absence or for being outdoors. Tap "Retry", then "Start Scanning" to try a room with detectable geometry. The Release build has no "Try Anyway" action or fixed-room bypass. The simulator cannot supply this hardware flow.

**Background audio:** The build declares the `audio` background mode. Locked-device playback still requires a hardware check; continued position tracking while locked is not promised.

**Privacy and links:** Geometry processing and synthesis stay on-device. The app has no backend, account, analytics, or tracking service. "Support" and "Privacy Policy" in Settings open web pages, and user-selected sharing destinations may use a network.

---

## Submission Checklist

### Metadata
- [ ] App name: "Room Tone: Resonance Synth"; confirm trademark availability
- [ ] Name and subtitle within 30 characters each
- [ ] Keywords within 100 characters; actual count recorded below
- [ ] Description within 4,000 characters; claims limited to modeled synthesis and current UI
- [ ] Promotional text within 170 characters
- [ ] Support and Privacy Policy URLs resolve; policy covers on-device processing and user-directed links and sharing
- [ ] Review notes use current labels and disclose simulator, location, and recording limitations

### Screenshots
- [ ] iPhone 6.9-inch captures at 1320x2868 px on supported LiDAR hardware
- [ ] iPad 13-inch captures at 2064x2752 px on supported LiDAR hardware
- [ ] Use current UI values and screen-space wave curves; review screenshot content before upload
- [ ] No identifiable room contents, faces, or personal items

### Build and device verification
- [ ] Release archive and tests pass outside this copy pass
- [ ] Privacy manifest declares no tracking or collected data and the required-reason APIs used by the target
- [ ] Runtime "LiDAR Required" path verified on unsupported hardware
- [ ] Camera grant and denial paths verified on supported hardware
- [ ] Release has no "Try Anyway" fixed-dimension bypass
- [ ] Audible synthesis, timbre switching, and position tracking checked on LiDAR hardware
- [ ] Recording file played back to verify non-silent capture of the live synthesis before describing it as audio capture in store copy
- [ ] Available share destinations and locked-device audio checked on hardware
- [ ] App icon, version 1.0, and build 2 verified in the submission archive

### App Store Connect
- [ ] Confirm age rating, SKU, categories, price, territories, and compatible-device availability against proposed Identity values
- [ ] Confirm privacy label against the app and privacy policy
- [ ] Confirm export compliance against `ITSAppUsesNonExemptEncryption = false`; no custom cryptography is implemented
- [ ] Confirm screenshot slots and dimensions; planned captures are not evidence of store acceptance
- [ ] Complete TestFlight device checks, including enclosed-room scans and failed scans
- [ ] Enter review notes with the LiDAR requirement and current test path

## Field Counts

Python character counts of the exact field values, including spaces and description newlines. Description excludes the surrounding code fence.

| Field | Characters | Limit |
|---|---|---|
| Name | 26 | 30 |
| Subtitle | 26 | 30 |
| Promotional text | 146 | 170 |
| Keywords | 87 | 100 |
| Description | 1659 | 4000 |

## Copyright
© 2026 saagpatel
