# Next implementation queue

Last updated: 2026-03-30 (post Stage-1 bridge, commit `c877994`)

---

## Already shipped — no longer the priority

| Item | Commit / notes |
|------|---------------|
| iOS app target scaffold | early sessions |
| SwiftUI host shell | early sessions |
| Container + session + benchmark persistence | early sessions |
| Managed-copy and bookmark import flows | early sessions |
| Simulator UI smoke tests (6 E2E, 35 unit) | `a355b12` |
| URL percent-encoding bug in ContainerStore | `6c77640` |
| **Stage 1 real bridge: posix_spawn + pipe capture** | **`c877994`** |
| wine-stub placeholder binary (Xcode build phase) | `c877994` |
| Binary executable-bit workaround (copy to tmp, chmod) | `c877994` |

---

## Tier 1 — Active next work

### 1. Stage 2: real Wine binary for simulator  ← **START HERE**

**Goal**: replace `wine-stub` with a real `wine64` build so Windows PE binaries execute.

**Steps**:
1. Obtain a macOS ARM64 `wine64` binary:
   - Option A: `brew install --build-from-source wine-stable` (takes 30-60 min)
   - Option B: Download a pre-built bottle or Kegworks bundle — extract `wine64` + dylibs
   - Option C: Use `wine-crossover` from the CrossOver SDK if available
2. Confirm it runs on the machine: `wine64 --version`
3. Bundle `wine64` + required dylibs into `CellarApp.app/Binaries/wine64/` via the build phase.
4. Update `RuntimeLaunchConfiguration.resolveRuntimeBinaryPath()` to look for `wine64` binary.
5. Update `cellarkit_bridge.c` argv: `[wine64_path, exe_path]` replacing `[stub_path, --exe, exe_path, ...]`.
6. Bundle a simple Windows console `.exe` as a test payload (Hello World, no GUI, no D3D).
   - `Tests/Fixtures/hello-win32.exe` — can cross-compile from C with `x86_64-w64-mingw32-gcc`.
7. Create a container pointing at the console exe, launch it, verify stdout appears in the log surface.

**Success criteria**: runtime log surface shows `Hello from Windows!` (or similar CRT output) from a real Wine process executing a PE binary.

**Blockers to watch**:
- Wine needs `WINEPREFIX` to exist — pre-create or let Wine initialize it on first run.
- `posix_spawn` env must pass `WINEPREFIX`, `HOME`, `PATH` — update `build_spawn_envp()` in `cellarkit_bridge.c`.
- On the simulator, Wine runs as a macOS process and should work out of the box without JIT entitlements.
- On a real device, Wine needs JIT (`MAP_JIT`, `pthread_jit_write_protect_np`) — separate stage.

---

### 2. Stage 2b: console exe test fixture

**Goal**: have a tiny pre-compiled Windows exe checked in as a test fixture.

**Steps**:
1. Cross-compile with `x86_64-w64-mingw32-gcc` (install via `brew install mingw-w64`):
   ```c
   // hello-win32.c
   #include <stdio.h>
   int main() {
       printf("Hello from Windows!\n");
       fflush(stdout);
       return 0;
   }
   ```
   ```sh
   x86_64-w64-mingw32-gcc -o Tests/Fixtures/hello-win32.exe hello-win32.c
   ```
2. Add a `BundledSample` container preset for `hello-win32.exe` alongside the Hello Cube preset.
3. Smoke test: create container → launch → see "Hello from Windows!" in log surface.

---

## Tier 2 — high value, after Wine boots

### 3. WINEPREFIX initialization and lifecycle

- Pre-create a minimal `WINEPREFIX` in the app's Library directory.
- Store per-container prefixes at `<CellarKit root>/Containers/<UUID>/prefix/`.
- Surface prefix creation progress in the launch surface (takes 3-5 seconds first run).
- Handle `WINEPREFIX` upgrade on Wine version change.

### 4. Wine stdout/stderr parsing for richer events

Currently every stdout line becomes a flat `.log` event.  Parse Wine's known patterns:
- `wine: could not load ...` → `.failed`
- `fixme:` lines → deprioritized log tier
- `err:` lines → elevated log tier
- Process exit via signal (e.g. SIGSEGV) → `.failed(message: "crash: ...")`

### 5. Harden security-scoped bookmark lifecycle

The external-link path exists but needs:
- stale bookmark detection and re-resolution after relaunch,
- start/stop access windows,
- permission-loss recovery UX.

### 6. Real-device capability detection

Replace heuristics:
- simulator vs device (reliable),
- debugger attachment,
- JIT availability (`MAP_JIT` probe),
- memory limit detection.

---

## Tier 3 — after Wine is stable

### 7. Graphics stack scaffolding

- Investigate DXVK for ARM64 (Asahi Linux port or custom build).
- Route Wine's Vulkan output through MoltenVK to a `CAMetalLayer`.
- Hook `LaunchSurfaceView` up to the Metal layer instead of the spinning cube placeholder.

### 8. Input / control scaffolding

- Touch overlay stub.
- Controller presence detection.
- Session quick-menu entry point.

### 9. Benchmark capture expansion

- Device identity, OS version, thermal state, memory pressure signals.
- Per-launch artifact bundle path.

---

## Explicitly deferred

- Multi-store auth implementation
- Cloud-save sync
- Full controller editor
- App Store submission
- Broad compatibility claims
- Polished storefront/library UX
