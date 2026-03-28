# Platform constraints: iPhone/iPad vs macOS

This document captures the major engineering constraints that make an iOS implementation different from Whisky/CrossOver on macOS or GameNative/Winlator on Android.

## 1. CPU translation is the first deep technical fork

### Direct evidence

- Whisky is a **macOS** app and includes an explicit Rosetta installer flow in `WhiskyKit/Sources/WhiskyKit/Utils/Rosetta2.swift`.
- Whisky’s README says it is built on top of **CrossOver 22.1.1** and **Apple’s Game Porting Toolkit**.
- GameNative/Winlator expose Box86/Box64-style settings and container knobs heavily tied to Android/Linux userland assumptions.

### Implication

A typical Windows game runtime on iPhone has to pick one of these strategies:

1. **Windows ARM64 / ARM64EC only**
   - Simplest CPU story.
   - Narrower compatibility catalog.
   - Best “first engine” candidate.

2. **x86/x64 Windows via usermode translation**
   - Box64 / FEX / QEMU-user / TCTI-like path.
   - Broader catalog.
   - Stronger dependence on JIT or a high-quality interpreter.

3. **Full-system emulation/VM fallback**
   - Broadest compatibility research path.
   - Weakest UX and usually poorest performance.

### Recommendation

Treat **ARM64-first Wine-style execution** and **x64 translation** as separate backends from day one.

## 2. JIT availability changes everything

### Direct evidence

- UTM README: `UTM/QEMU requires dynamic code generation (JIT) for maximum performance.`
- UTM iOS development doc: `For JIT to work on the latest version of iOS, it must be launched through the debugger.`
- UTM’s `Platform/Main.swift` checks multiple JIT-enabling conditions:
  - entitlement,
  - jailbreak states,
  - ptrace/debugger tricks.
- UTM’s `Platform/UTMData.swift` includes both **AltJIT** and **JitStreamer** attach flows.
- UTM SE exists specifically because no-JIT fallback matters.
- UTM’s QEMU patchset includes iOS-version-specific JIT workarounds (`patches/qemu-10.0.2-utm.patch`).

### Practical consequence

For x86/x64 game execution on stock iPhone/iPad, you should assume:

- **best case:** developer-signed or side-loaded build launched with debugger/JIT assist,
- **acceptable fallback:** threaded interpreter / TCTI-style mode,
- **worst case:** no workable dynarec path for mainstream game performance.

### Decision rule

The runtime should never assume “JIT just exists.” It should compute capabilities at launch time and pick a backend accordingly.

Suggested capability model:

- `nativeEntitlement`
- `debuggerAttached`
- `altJIT`
- `jitStreamer`
- `jailbreak`
- `threadedInterpreterOnly`
- `noDynamicExecution`

## 3. iOS process model is much tighter than macOS

### Direct evidence

UTM architecture docs say:
- on iOS, there is no practical ability to launch QEMU the macOS way with `fork`/XPC,
- so QEMU runs in a `pthread` inside the app process.

### Implication

A CellarKit-iOS runtime should assume an **embedded-in-process architecture**:

- SwiftUI app shell
- runtime bridge layer
- embedded C/C++ runtime loop(s) in threads
- no dependence on helper daemons or arbitrary child processes

This strongly affects:
- crash isolation,
- restartability,
- cleanup semantics,
- multi-instance support,
- memory reclamation.

### Engineering consequence

A simple `launch game subprocess` design is the wrong starting point for iOS.

## 4. Filesystem access is sandboxed and user-mediated

### Direct evidence

- App Store Review Guideline 2.5.2 says apps must be self-contained and may not read/write outside designated containers.
- UTM architecture docs describe using **security-scoped bookmarks** and `startAccessingSecurityScopedResource()` for files chosen by the user.
- GameNative’s Android implementation uses `MANAGE_EXTERNAL_STORAGE`, which iOS does not provide.

### Implication

The iOS version should use one of two storage modes:

1. **Managed copy mode**
   - import game content into app-managed storage,
   - simpler runtime access,
   - higher storage duplication.

2. **External reference mode**
   - hold security-scoped bookmarks to user-selected folders/files,
   - less duplication,
   - more bookkeeping and access-lifetime complexity.

### Recommendation

Default to:
- **managed copy mode** for early MVP reliability,
- **bookmark-backed external reference mode** later for large libraries.

## 5. Memory pressure is real and JIT cache makes it worse

### Direct evidence

- UTM iOS docs mention a paid developer account can request the **increased memory limit entitlement**.
- UTM localizable strings explicitly warn:
  - `Running low on memory! UTM might soon be killed by iOS.`
  - `The JIT cache size is additive to the RAM size in the total memory usage!`

### Implication

An iPhone-targeted runtime must treat memory as a first-class product constraint:

- runtime code cache size,
- shader cache size,
- Wine prefix size,
- imported game size,
- texture uploads,
- audio buffers,
- overlay UI layers.

### Product consequence

Per-game profiles should include memory/cache tuning and safe defaults.

## 6. Lifecycle handling is not optional

### Why it matters

Phones suspend, background, thermal-throttle, and can be killed far more aggressively than laptops.

### What the runtime must handle

- app moved to background while a game is running,
- screen lock / unlock,
- audio session interruptions,
- controller disconnect/reconnect,
- low-memory warnings,
- thermal state changes,
- partial install / resume / cleanup.

### Recommendation

The first MVP should include:
- explicit suspend/resume semantics,
- crash-safe logs,
- a “recover last session” path,
- per-title safe shutdown if the app backgrounds beyond an allowed window.

## 7. Graphics translation on iOS is plausible, but not plug-and-play

### Direct evidence

- MoltenVK README says it targets `macOS, iOS, tvOS, and visionOS`.
- MoltenVK says it uses public APIs and is App Store compatible.
- DXVK upstream expects Wine + Vulkan environments.
- DXVK-macOS exists as Apple-specific adaptation work.
- Whisky credits include DXVK-macOS, MoltenVK, D3DMetal, and CrossOver.

### Implication

Potential graphics paths include:

1. **D3D9/10/11 -> DXVK-style layer -> Vulkan -> MoltenVK -> Metal**
2. **D3D12 -> VKD3D-Proton -> Vulkan -> MoltenVK -> Metal**
3. **WineD3D / alternate Metal-native path** for fallback or special cases

### Key caution

“MoltenVK exists on iOS” does **not** mean the full Mac Whisky graphics stack exists on iOS. You still need:
- a valid Wine integration story,
- a valid CPU translation story,
- shader compilation and cache management that survive iOS memory constraints,
- input/render presentation tuned for mobile.

## 8. Input must be designed for touch-first, not added later

### Direct evidence

GameNative/Winlator code paths show substantial work around:
- virtual gamepad profiles,
- physical controller mappings,
- rumble,
- on-screen control persistence.

Relevant files:
- `com/winlator/inputcontrols/ControlsProfile.java`
- `com/winlator/winhandler/WinHandler.java`

### Implication

A viable iPhone implementation needs, from early on:
- touch overlay profiles,
- GameController.framework support,
- keyboard/mouse support on iPad and external devices,
- haptics/rumble fallback behavior,
- runtime overlay to adjust controls without leaving the game.

## 9. Audio plumbing is a real subsystem

Game runtimes often assume desktop mixer semantics. iOS expects:
- explicit `AVAudioSession` setup,
- interruption handling,
- route changes,
- headphone/Bluetooth transitions,
- silent-mode expectations.

This should be treated as a dedicated integration layer rather than an afterthought.

## 10. App Store policy is likely the biggest product blocker

### Direct evidence

App Store Review Guideline 2.5.2 states:

> Apps should be self-contained in their bundles ... nor may they download, install, or execute code which introduces or changes features or functionality of the app ...

Source:
- https://developer.apple.com/app-store/review/guidelines/

### Interpretation for this project

#### Lower-risk cases

- import-only runtime shell,
- interpreter-based technical demonstrator,
- generic emulator-like tooling without integrated Windows game storefront downloads.

#### Higher-risk cases

- log into Steam/Epic/GOG/Amazon inside the app,
- download Windows game binaries directly,
- run those binaries as the main advertised feature.

### Recommendation

Plan for **two product lanes**:

1. **Research / side-load / developer-signed lane**
   - full technical ambition,
   - debugger/JIT workflows allowed,
   - store downloads allowed if desired.

2. **Policy-constrained lane**
   - import-first,
   - more conservative execution model,
   - App Store compatibility evaluated separately.

## 11. Suggested constraint matrix

| Scenario | Likely technical status | Likely product status |
|---|---|---|
| Developer-signed + debugger JIT + local import | strongest early MVP path | good for research |
| AltStore / side-load + JIT assist | plausible | good for enthusiasts |
| Jailbreak build | technically strongest | niche distribution |
| App Store + UTM-SE-style interpreter shell | plausible as a constrained product | uncertain but precedent exists |
| App Store + Steam/Epic/GOG/Amazon downloads of Windows games | technically possible in theory | high policy risk |

## Bottom line

The path is viable if the project is designed around **capability-driven runtime selection** and **distribution-channel-aware product boundaries**.

The project is not viable if it assumes:
- macOS Rosetta/GPTK behavior,
- Android-like storage freedom,
- permanent JIT availability,
- or guaranteed App Store approval for a full Windows storefront launcher.
