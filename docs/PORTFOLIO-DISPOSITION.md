# Room Tone — Portfolio Disposition

**Status:** Release Frozen (iOS App Store) — SwiftUI + ARKit + LiDAR
acoustic-resonance synthesizer on `origin/main` with full App Store
submission scaffolding (`APPSTORE-METADATA.md`, fastlane `deliver`
config, DEVELOPMENT_TEAM, Privacy Manifest with **UserDefaults
Required Reason API declaration**, scheme generation, copyright +
ExportOptions, privacy policy, archive prep). Classified as **Music**
(primary) + **Utilities** (secondary) at **$2.99 paid**. **Eighth
iOS App Store cluster member; third paid app.** Requires
**LiDAR-equipped device** (iPad Pro M-series, iPhone Pro 12+) —
device support matrix is the load-bearing operator concern.

> Disposition uses strict `origin/main` verification.

---

## Verification posture

This repo has **only `origin`** (`saagpatel/RoomTone`) — no
`legacy-origin` remote. Clean migration state.

Specifically verified on `origin/main`:

- Tip: `4021d95` chore: add fastlane deliver config for App Store
  metadata upload
- Substantive App Store prep commits:
  - `4021d95` fastlane deliver config
  - `d744050` app store archive prep
  - `f8c0974` privacy policy + metadata URLs
  - `9077d9c` copyright + ExportOptions
  - `4510244` App Store Connect metadata
  - `dc6d4fe` **fix(security): add UserDefaults declaration to
    PrivacyInfo.xcprivacy** (Required Reason API compliance)
  - `cf6c963` App Store prep — DEVELOPMENT_TEAM, Privacy Manifest,
    scheme generation
- App Store identity:
  - Name: **Room Tone**
  - Subtitle: **Hear Your Room's Resonance**
  - Bundle ID: `com.roomtone.app`, SKU: `ROOMTONE-001`
  - Categories: **Music** + **Utilities**
  - Age Rating: 4+, **Price: $2.99**, All territories
- Default branch: `main`

---

## Current state in one paragraph

Room Tone is a SwiftUI + ARKit iOS app that uses **LiDAR** to scan
the geometry of the user's room and **synthesizes ambient / drone
audio** shaped by the computed resonant modes of that geometry —
"hear your room's resonance." No microphone is used; all audio is
synthesized from the ARKit plane-detection data. Per memory: all phases done, pending device test (LiDAR
hardware required for QA). The release commits on canonical main
confirm full App Store prep cadence, including the **`dc6d4fe`
PrivacyInfo.xcprivacy UserDefaults declaration** (Apple's iOS 17+
Required Reason API enforcement for UserDefaults access). Music
category + Utilities = the operator has positioned this as a
musical instrument tool rather than a pure novelty.

---

## Why "Release Frozen (iOS App Store, paid)" — eighth cluster member

The cluster signature applies cleanly. Room Tone adds two new
concerns:

| Concern | Notes |
|---|---|
| **LiDAR device requirement** | Limits supported devices to iPad Pro (2020+, M-series) and iPhone Pro (12+). Operator must declare supported devices clearly in App Store listing — 1-star reviews from non-LiDAR users are a known failure mode. |
| **UserDefaults Required Reason API** | iOS 17+ requires apps to declare why they use UserDefaults in `PrivacyInfo.xcprivacy`. The `dc6d4fe` commit adds this — important compliance fix that other iOS cluster members may need to verify. |

Pricing: $2.99 = third paid iOS app (Liminal $4.99 / Redact $3.99 /
**Room Tone $2.99**). Paid sub-class growing.

---

## Cluster taxonomy update

| Cluster | Count | Notes |
|---|---|---|
| Signing (Apple desktop) | 24 | … |
| **iOS App Store** | **8** | 6 local-first + 1 cloud-backed + paid sub-class at 3 of 8 |
| (others unchanged) | | |

---

## Unblock trigger (operator)

1. **App Store Connect record + Tier 3 pricing** ($2.99).
2. **LiDAR device support matrix** — declare explicitly in App
   Store description. Apple's "Compatibility" section will list
   supported devices, but redundant copy in description ("Requires
   LiDAR; iPad Pro 2020+ or iPhone 12 Pro+") preempts 1-star
   reviews from non-LiDAR users.
3. **Verify PrivacyInfo.xcprivacy completeness** — `dc6d4fe`
   added UserDefaults declaration; verify other Required Reason
   APIs (file timestamp, disk space, system boot time, active
   keyboards) are also declared if used. Do NOT add
   `NSMicrophoneUsageDescription` — the app uses no microphone.
4. **Music-category review** — Music reviewers expect audio
   demos. Submission note: "Audio sample requires LiDAR scan;
   provide test environment if reviewer cannot demonstrate."
5. **Refreshed screenshots in local stash** (screenshot-1, -2, -3
   modified) — decide whether to commit and re-upload.
6. **Submit for Review.**

Estimated operator time: ~4-5 hours (LiDAR device test is the
constraint; if operator has LiDAR-equipped device on hand,
faster).

---

## Portfolio operating system instructions

| Aspect | Posture |
|---|---|
| Portfolio status | `Release Frozen (iOS App Store, local-first, paid)` |
| Distribution channel | **App Store Connect** — Music + Utilities, $2.99 |
| Device support | **LiDAR-equipped only** — iPad Pro 2020+, iPhone 12 Pro+ |
| Review cadence | Suspend overdue counting |
| Resurface conditions | (a) Device test completes + submission, (b) Apple Required Reason API expansion adds new categories Room Tone uses, (c) review feedback (Music or LiDAR-related), or (d) v1.1 scope packet |
| Co-batch with | iOS App Store cluster — **now 8 repos** |
| Special concern | **LiDAR device support matrix in App Store listing.** Non-LiDAR users will leave 1-star reviews if not declared. |
| Special concern | **PrivacyInfo.xcprivacy Required Reason APIs.** `dc6d4fe` added UserDefaults; audit other RR API usages. Pattern worth applying to all iOS cluster members. |
| Special concern | **No microphone is used.** All audio is synthesized from LiDAR geometry. Do NOT add `NSMicrophoneUsageDescription` — would cause App Store confusion. |
| Special concern | **Refreshed screenshots in local stash.** Resolve before submission. |

---

## Reactivation procedure

1. Verify `git branch -vv` shows `main` tracking `origin/main`.
2. Review stash `r14-roomtone-stash` (CLAUDE.md + 3 screenshot
   PNGs modified).
3. Open Xcode → confirm DEVELOPMENT_TEAM valid + LiDAR
   capability declared.
4. **Run on LiDAR-equipped device** before submission — Simulator
   doesn't support LiDAR scans.
5. **Audit `PrivacyInfo.xcprivacy`** for all Required Reason API
   declarations (UserDefaults is in; verify the others).
6. Run XCTest target.
7. **Decide screenshot disposition + re-run fastlane deliver if
   needed.**

---

## Last known reference

| Field | Value |
|---|---|
| `origin/main` tip | `4021d95` chore: add fastlane deliver config for App Store metadata upload |
| Default branch | `main` |
| Build system | iOS / iPadOS / Swift / SwiftUI / **ARKit / LiDAR** / XcodeGen / XCTest |
| Bundle ID | `com.roomtone.app` |
| App Store category | Music + Utilities |
| Price | **$2.99** (third paid iOS cluster member) |
| Device requirement | **LiDAR-equipped (iPad Pro 2020+, iPhone 12 Pro+)** |
| Phases shipped | All per memory; pending LiDAR device test |
| Notable | **`PrivacyInfo.xcprivacy` Required Reason API compliance** (`dc6d4fe`) — pattern other iOS cluster members may need to verify |
| Migration state | No `legacy-origin` remote |
| Distinguishing feature | **Eighth iOS App Store cluster member; third paid app; first to require LiDAR-equipped device.** Introduces Required Reason API audit as cluster-wide concern. |
