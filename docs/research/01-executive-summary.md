# Executive summary

## Short version

A CrossOver/Whisky-style Windows game runtime for **iPhone and iPad is technically plausible**, but **not as a straight port of the macOS stack**.

The biggest conclusions from this research pass are:

1. **A direct Whisky/CrossOver port is not realistic.**
   - Whisky explicitly targets **Apple Silicon Macs on macOS Sonoma+** and depends on **Rosetta 2**, **CrossOver 22.1.1**, and **Apple's Game Porting Toolkit**.
   - Source evidence:
     - Whisky README: `Whisky is built on top of CrossOver 22.1.1, and Apple's own Game Porting Toolkit.`
     - Whisky README system requirements: `CPU: Apple Silicon (M-series chips)` and `OS: macOS Sonoma 14.0 or later`.
     - `WhiskyKit/Sources/WhiskyKit/Utils/Rosetta2.swift` shells out to `/usr/sbin/softwareupdate --install-rosetta` and checks `/Library/Apple/usr/libexec/oah/libRosettaRuntime`, which is a macOS flow, not an iOS flow.
   - Sources:
     - https://github.com/Whisky-App/Whisky
     - Local reference paths under `/tmp/winnative-ios-refs/Whisky/...`

2. **iOS already proves that large emulation stacks can ship, but the launch mode matters.**
   - UTM shows three important patterns:
     - regular JIT builds for higher performance,
     - debugger-assisted / AltJIT / remote-debugger workflows for stock devices,
     - `UTM SE` using a **threaded interpreter** when JIT is unavailable.
   - Source evidence:
     - UTM README: `UTM SE ("slow edition") uses a threaded interpreter ... slower than JIT.`
     - UTM iOS docs: `For JIT to work on the latest version of iOS, it must be launched through the debugger.`
     - UTM architecture docs: on iOS there is no practical `fork`/XPC style child-process model for app-managed emulation, so QEMU runs in a `pthread`.
   - Sources:
     - https://github.com/utmapp/UTM
     - `/tmp/winnative-ios-refs/UTM/README.md`
     - `/tmp/winnative-ios-refs/UTM/Documentation/iOSDevelopment.md`
     - `/tmp/winnative-ios-refs/UTM/Documentation/TetheredLaunch.md`
     - `/tmp/winnative-ios-refs/UTM/Documentation/Architecture.md`

3. **The main technical blocker is not raw CPU power; it is the iOS execution model.**
   - On macOS Apple Silicon, Whisky/CrossOver can lean on Rosetta and macOS-specific runtime behavior.
   - On iOS, if you want to run typical x86/x64 Windows games, you need **another CPU translation layer** such as Box64/FEX/QEMU-user/TCTI-like machinery.
   - Without JIT, that path becomes much slower.
   - Existing iOS prior art for no-JIT dynamic execution is UTM SE and iSH, both using interpreter/threaded-interpreter strategies rather than normal dynarec.
   - Sources:
     - https://github.com/ish-app/ish
     - `/tmp/winnative-ios-refs/UTM/README.md`
     - `/tmp/winnative-ios-refs/UTM/Documentation/Architecture.md`
     - https://raw.githubusercontent.com/ktemkin/qemu/with_tcti/tcg/aarch64-tcti/README.md

4. **An App Store-distributed “log into Steam / Epic / GOG / Amazon and download Windows binaries” product is high policy risk.**
   - Apple App Store Review Guideline **2.5.2** says apps may not `download, install, or execute code which introduces or changes features or functionality of the app`.
   - UTM SE demonstrates that Apple may accept some interpreter/emulator cases, but a storefront-driven Windows game downloader is materially riskier than a generic emulator shell.
   - Direct evidence vs inference:
     - **Direct evidence:** guideline 2.5.2 exists.
     - **Inference:** a Steam/Epic/GOG/Amazon launcher that downloads Windows executables is likely much harder to approve than UTM SE.
   - Source:
     - https://developer.apple.com/app-store/review/guidelines/

5. **A side-loaded / developer-signed / jailbreak-first MVP is the most credible path.**
   - This matches UTM’s JIT reality on stock iOS and keeps the first milestone focused on technical feasibility instead of App Store policy.
   - The end-user GameNative-style experience can still be the long-term target, but the initial MVP should probably:
     - import a Windows game folder or executable,
     - create/manage one prefix or container,
     - launch with capability-based backend selection,
     - prove graphics/audio/input/lifecycle first.

## Recommended MVP sequence

### Phase A — feasibility MVP

Target distribution:
- developer-signed build,
- AltStore / side-load build,
- or jailbreak build.

Target UX:
- no storefront login yet,
- import local game payload or test executable,
- create prefix/container,
- launch with touch controls + controller support + logging.

Target runtime choices:
- **Path 1:** Windows ARM64 / ARM64EC + Wine-style userland as the lightest technical path.
- **Path 2:** x64 Windows + Box64/FEX/QEMU-user style translation when JIT is available.
- **Path 3:** threaded-interpreter fallback for research, benchmarking, and “proof of life,” not for the main UX.

### Phase B — GameNative-style shell

After feasibility is proven:
- storefront authentication flows,
- library sync,
- downloads/install manifests,
- cloud saves,
- per-game configuration,
- richer overlay/input/runtime settings.

### Phase C — policy-safe variant

If App Store distribution remains a goal, consider a separate constrained SKU:
- import-only,
- maybe interpreter-only,
- no remote storefront download of Windows executables,
- no claim of broad compatibility until review outcomes are known.

## What is most reusable from prior art?

### Highest-value reusable patterns

- **Whisky:** bottle UX, prefix metadata, per-bottle environment composition, logs, Swift/SwiftUI shell ideas.
- **UTM:** iOS process model workarounds, debugger/JIT handling, memory-limit awareness, security-scoped file access, app-process embedded runtime architecture.
- **Proton:** prefix lifecycle, DLL injection/override strategy, compatibility-tool style per-title tuning.
- **Bottles:** runner/component/dependency orchestration and configuration catalogs.
- **Pluvia / GameNative:** end-user library UX, download coordination, cloud save plumbing, controller/touch profile management, service boundaries.

### What should *not* be assumed portable

- **Rosetta 2** assumptions from macOS.
- **Game Porting Toolkit** assumptions from macOS.
- Android-style filesystem assumptions like `MANAGE_EXTERNAL_STORAGE`.
- Multi-process runtime designs that depend on macOS/XPC-style helpers.

## Bottom-line verdict

If the goal is:

- **“Can an iPhone/iPad app run Windows games at all?”** → **Yes, plausibly.**
- **“Can we build a real research repo and start an MVP path now?”** → **Yes.**
- **“Can we just port Whisky/CrossOver and call it done?”** → **No.**
- **“Can we safely assume App Store approval for a full Steam/Epic/GOG/Amazon downloader + runner?”** → **No.**

The strongest path is to treat this as a **new iOS-native host app** with a **Swift/SwiftUI orchestration layer** and a **C/C++ runtime core**, informed by Whisky, UTM, Proton, Bottles, Pluvia, and GameNative — but not directly derived from any single one.
