# Prior art and what each project proves

This document separates **directly reusable patterns** from **platform-specific assumptions**.

## CrossOver / CodeWeavers

### What it proves

- The commercial-grade Wine stack for Apple hardware is still fundamentally a composition of upstream and semi-upstream projects, not a single monolith.
- CodeWeavers openly documents a FOSS component list for CrossOver 26.0.0, including:
  - Wine
  - VKD3D
  - GnuTLS
  - cabextract
  - Samba
  - Sparkle
  - PyObjC
  - wine-mono
  - FAudio
  - SDL
  - DXVK
  - LLVM
  - MoltenVK
  - Python
  - FreeType
  - and others
- CodeWeavers also states that CrossOver contains **proprietary value-add components**, so “CrossOver parity” is not the same thing as “rebuild everything from open source.”

### Direct evidence

- `https://www.codeweavers.com/open-source`
  - states CodeWeavers does most of its work against upstream Wine first,
  - and says CrossOver is primarily open-source core plus proprietary value-add.
- `https://www.codeweavers.com/crossover/source`
  - lists the FOSS projects used in CrossOver 26.0.0.
- `https://www.codeweavers.com/wine`
  - describes CodeWeavers’ Wine contribution model.

### Reusable ideas

- Component inventory and attribution discipline.
- Treat Wine + graphics + audio + font + update + installer pieces as a **bundle of subsystems**.
- Keep a clean separation between:
  - upstreamable runtime changes,
  - app-shell UX,
  - proprietary/non-redistributable integrations.

### Not directly portable to iOS

- CrossOver’s proprietary patches.
- macOS-specific execution assumptions.
- Any reliance on Rosetta/GPTK/macOS app model.

## Whisky

### What it proves

- A Wine wrapper with a clean Apple-native UX can be built in **SwiftUI**.
- A “bottle” can be modeled as:
  - a filesystem location,
  - a metadata plist,
  - per-prefix settings,
  - per-title launch configuration,
  - environment-variable composition.
- Prefix orchestration can stay relatively small if the low-level Wine pieces are treated as external binaries/libraries.

### High-value code paths

- `README.md`
  - documents project goals, dependencies, and credits.
- `WhiskyKit/Sources/WhiskyKit/Whisky/Bottle.swift`
  - bottle model and metadata loading.
- `WhiskyKit/Sources/WhiskyKit/Whisky/BottleSettings.swift`
  - per-bottle settings, DXVK flags, Metal HUD, sync mode, AVX advertisement.
- `WhiskyKit/Sources/WhiskyKit/Wine/Wine.swift`
  - launch/environment logic, prefix selection, DXVK enablement, logging.
- `WhiskyKit/Sources/WhiskyKit/WhiskyWine/WhiskyWineInstaller.swift`
  - install/update flow for runtime payloads.
- `WhiskyKit/Sources/WhiskyKit/Utils/Rosetta2.swift`
  - explicit macOS Rosetta dependency.

### Key takeaway for iOS

Use Whisky as inspiration for:
- SwiftUI app structure,
- prefix metadata format,
- launch configuration layering,
- log handling,
- config UI.

Do **not** assume its runtime portability. Whisky is a **macOS** wrapper, not an iOS runtime blueprint.

Source:
- https://github.com/Whisky-App/Whisky

## Proton

### What it proves

- The “compatibility tool” model scales when you treat a runtime as:
  - a default prefix template,
  - a prefix upgrade engine,
  - DLL/component injection rules,
  - per-title compatibility flags,
  - a reproducible build/runtime container.
- Proton’s `proton` launcher script is essentially a runtime planner plus prefix lifecycle manager.

### High-value code paths

- `README.md`
  - high-level architecture and build/runtime model.
- `proton`
  - prefix creation, upgrade, DLL placement, Steam integration, runtime env handling.

### Relevant patterns for this project

- Prefix versioning and migration.
- Managed “base prefix” copied into title-specific compat data.
- Runtime-selected DLL stacks (DXVK, VKD3D, NVAPI, wined3d fallback).
- Per-title compatibility flags as data, not hardcoded UI state.

### Limits for iOS

- Proton is designed around Linux/Steam assumptions.
- Its container/runtime model will not transplant 1:1 to iOS sandboxing.

Source:
- https://github.com/ValveSoftware/Proton

## Bottles

### What it proves

- A modern Wine front-end can expose:
  - multiple runner types,
  - installable components,
  - dependency catalogs,
  - store-specific managers,
  - versioning/snapshot systems,
  - playtime/session tracking,
  - a library/importer layer.

### High-value code paths

- `README.md`
  - distribution/build assumptions.
- `bottles/backend/managers/manager.py`
  - central runner/component/dependency manager.

### Relevant patterns for iOS

- Treat “runner,” “graphics translation layer,” and “dependency pack” as separately versioned units.
- Build a manager layer that resolves:
  - available runtime backends,
  - installable compatibility components,
  - per-game dependencies.

### Limits for iOS

- Bottles assumes Linux/Flatpak worlds.
- Its sandbox and distribution assumptions are not Apple-mobile assumptions.

Source:
- https://github.com/bottlesdevs/Bottles

## UTM / UTM SE

### What it proves

UTM is the single most useful iOS-native reference for this problem space.

It proves that an iOS app can:
- embed a large C/C++ runtime,
- expose a native Apple UI on top of it,
- handle debugger/JIT workflows on stock devices,
- use a threaded-interpreter fallback when JIT is unavailable,
- manage imported files through sandbox-safe access patterns,
- submit an `iOS SE` flavor to App Store tooling.

### High-value code paths

- `README.md`
  - JIT vs UTM SE summary.
- `Documentation/Architecture.md`
  - process model, iOS runtime embedding, security-scoped file access, backend layering.
- `Documentation/iOSDevelopment.md`
  - build, signing, increased-memory-limit, JIT launch requirements.
- `Documentation/TetheredLaunch.md`
  - debugger-assisted launch flow.
- `Platform/Main.swift`
  - runtime JIT availability checks.
- `Platform/UTMData.swift`
  - AltJIT and JitStreamer attach flows.
- `patches/qemu-10.0.2-utm.patch`
  - concrete example of iOS-version-specific JIT workarounds.
- `Documentation/Release.md`
  - `IOS_SE_PROFILE_DATA` / `IOS_SE_PROFILE_UUID` for App Store submission infrastructure.

### Why it matters here

UTM gives a practical template for:
- **embedding** runtime loops in-app,
- **capability gating** around JIT,
- **signing channel awareness**,
- **imported-file sandbox handling**,
- **separate SKUs** for fast vs policy-friendly execution modes.

Source:
- https://github.com/utmapp/UTM

## iSH

### What it proves

- A usermode x86 emulation app can ship on iOS.
- A threaded/gadget interpreter can be a viable no-JIT strategy.

### Direct evidence

- iSH README: `using usermode x86 emulation and syscall translation`
- iSH README explains its interpreter as an array of “gadgets” with tailcalls, delivering a material speedup over a simpler switch interpreter.

### Relevance

iSH is not a Windows gaming stack, but it is strong proof that:
- no-JIT dynamic execution can be packaged for iOS,
- interpreter engineering matters a lot when the platform restricts normal dynarec.

Source:
- https://github.com/ish-app/ish

## Pluvia

### What it proves

- A mobile-first app can make Windows compatibility tooling feel like a storefront-native UX.
- Steam integration, game downloads, cloud saves, and Winlator-backed play can be combined in one user-facing app shell.

### Direct evidence

Pluvia README lists:
- view and download games,
- play DRM-free games using Winlator built into the app,
- configure game containers,
- Steam Cloud integration,
- friends list.

### Key value

Pluvia is an excellent UX reference for:
- library-first design,
- installation flow shape,
- cloud-save expectations,
- how much end-user complexity can be hidden behind a mobile shell.

Source:
- https://github.com/oxters168/Pluvia

## GameNative

### What it proves

GameNative is the strongest Android-side reference for the **north-star UX** described for this project.

It proves that a mobile app can unify:
- storefront login and library sync,
- downloads/install management,
- container creation and activation,
- controller/touch mapping,
- Steam Auto Cloud sync,
- additional storefronts beyond Steam.

### High-value code paths

#### Storefront and service layer

- `app/src/main/java/app/gamenative/service/SteamService.kt`
- `app/src/main/java/app/gamenative/service/SteamAutoCloud.kt`
- `app/src/main/java/app/gamenative/service/epic/EpicService.kt`
- `app/src/main/java/app/gamenative/service/gog/GOGService.kt`
- `app/src/main/java/app/gamenative/service/amazon/AmazonService.kt`

#### Container/runtime layer

- `app/src/main/java/com/winlator/container/ContainerManager.java`
  - container creation, duplication, extraction, prefix-pack handling.
- `app/src/main/java/com/winlator/inputcontrols/ControlsProfile.java`
  - input/touch/virtual-gamepad profile persistence.
- `app/src/main/java/com/winlator/winhandler/WinHandler.java`
  - controller state, rumble, virtual gamepad, input dispatch.

### Notable capabilities

- Steam Auto Cloud conflict handling and prefix-path resolution.
- Epic/GOG/Amazon services split into manager/auth/download/cloud responsibilities.
- Real “containerized game launcher” patterns rather than generic emulator UX.

### iOS caveat

GameNative’s Android storage model includes broad filesystem access assumptions (`MANAGE_EXTERNAL_STORAGE`) that will need to be replaced on iOS with document pickers and security-scoped bookmarks.

Source:
- local repo: `/Users/danhimebauch/Developer/GameNative`

## MoltenVK

### What it proves

- Vulkan-on-Apple-platforms is available on **iOS**, not just macOS.
- MoltenVK explicitly says it targets `macOS, iOS, tvOS, and visionOS` and uses public APIs only.
- It also claims App Store compatibility.

### Relevance

If the runtime uses a Vulkan-based graphics path, MoltenVK is a serious candidate for the Apple side of the stack.

Source:
- https://github.com/KhronosGroup/MoltenVK
- `https://raw.githubusercontent.com/KhronosGroup/MoltenVK/main/README.md`

## DXVK-macOS and wine-msync

### Why they matter

- `DXVK-macOS` shows that DXVK-style translation has already been adapted for Apple/Wine contexts.
- `wine-msync` shows a Mach-semaphore synchronization path tailored to Apple platforms.

### Likely use here

These are more likely to be **reference inputs** than directly dropped-in dependencies, but they matter for evaluating Apple-specific Wine adaptations.

Sources:
- https://github.com/Gcenx/DXVK-macOS
- https://github.com/marzent/wine-msync

## Summary table

| Project | Main value to copy | Main thing not to copy blindly |
|---|---|---|
| CrossOver | component inventory and layering model | proprietary patches/value-add |
| Whisky | SwiftUI bottle UX and environment modeling | macOS/Rosetta/GPTK assumptions |
| Proton | prefix lifecycle and compatibility-tool architecture | Linux/Steam container assumptions |
| Bottles | runner/component/dependency orchestration | Flatpak/Linux distribution assumptions |
| UTM | iOS runtime embedding, JIT gating, file sandbox patterns | VM-centric UX as the main product shape |
| iSH | no-JIT interpreter strategy | Linux-shell-specific syscall model |
| Pluvia | storefront-first mobile UX | Android runtime/storage assumptions |
| GameNative | multi-store mobile game-runtime shell | Android permissions and service assumptions |
| MoltenVK | Vulkan→Metal bridge on iOS | assuming Vulkan alone solves Wine portability |
