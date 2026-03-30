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
| Stage 1 real bridge: posix_spawn + pipe capture | `c877994` |
| wine-stub placeholder binary (Xcode build phase) | `c877994` |
| Binary executable-bit workaround (copy to tmp, chmod) | `c877994` |
| Docs update post Stage-1 | `f087602` |
| **Stage 2: real wine64 + Windows PE exe executing** | **pending commit** |
| Wine env builder (WINEPREFIX, WINESERVER, PATH) | pending commit |
| hello-win32.exe test fixture (mingw-w64 compiled) | pending commit |
| `CellarWine2Test` E2E test (auto-skips without wine64) | pending commit |
| `allowSystemWine` flag for env-independent unit tests | pending commit |

---

## Tier 1 — Active next work

### 1. WINEPREFIX lifecycle and per-container prefixes  ← **START HERE**

**Goal**: each container gets its own Wine prefix for isolation. Currently all containers share `CellarKit/WinePrefix`.

**Steps**:
1. Change `resolveWinePrefix()` to return `<Library>/CellarKit/Containers/<containerID>/prefix/` instead of a shared path.
2. Pass `containerID` through to the configuration factory (it already has the container descriptor).
3. Surface prefix creation status in the launch surface (`wine: created the configuration directory` from stderr is currently discarded as a noise log).
4. Add a "Reset Wine Prefix" button per container (deletes `prefix/` directory).
5. Handle the `wine: chdir failed` error gracefully if the parent directory doesn’t exist.

### 2. Parse Wine stderr into structured log tiers

**Goal**: distinguish useful output from noise in the 15 log lines Wine produces.

**Steps**:
1. In `build_wine_envp()`, keep `WINEDEBUG=-all` to suppress most noise.
2. In `cellarkit_bridge.c`, parse `[stderr]` lines:
   - `[stderr] wine: created the configuration directory` → `PREPARING` event (not a LOG)
   - `[stderr] fixme:*` → suppress entirely (too noisy)
   - `[stderr] err:*` → keep as LOG with elevated tier flag
   - `[stderr] wine: failed to open` → `FAILED` event
3. Add a `cellarkit_bridge_event_kind` for `CELLARKIT_BRIDGE_EVENT_LOG_ERROR = 6`.

### 3. Real D3D/graphics path — DXVK for console apps

**Goal**: run a Windows program that uses D3D11. The simplest starting point is a D3D11 device-creation probe (no window, no render loop).

**Steps**:
1. Cross-compile a minimal D3D11 probe: `D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_NULL, ...)` — no window needed.
2. Bundle DXVK (d3d11.dll, dxgi.dll) in `Payloads/dxvk/`.
3. Set `WINEDLLOVERRIDES=d3d11=n,b` and `DXVK_CONFIG_FILE=...` in the Wine env.
4. Verify the probe runs and produces DXVK log output.
5. Then try Tutorial04.exe (Hello Cube) which needs a window/MoltenVK — deferred.

---

## Tier 2 — high value, after Wine is stable

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
