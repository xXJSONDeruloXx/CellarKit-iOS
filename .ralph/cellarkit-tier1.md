# CellarKit Tier 1 — three items

## Item 1: Per-container WINEPREFIX
- [ ] Update `resolveWinePrefix()` in RuntimeLaunchConfiguration.swift to accept `containerID: UUID`
- [ ] Call it with `container.id` from `makeConfiguration()`
- [ ] Path: `<Library>/CellarKit/Containers/<id.uuidString>/prefix`
- [ ] Create the parent `Containers/<id>/` dir before returning

## Item 2: Wine stderr noise filtering in the C bridge
- [ ] In `cellarkit_bridge.c`, after reading `[stderr]` tagged lines, parse content
- [ ] Drop `fixme:*` lines entirely (too noisy)
- [ ] Drop `wineserver: using server-side synchronization` (infrastructure noise)
- [ ] Demote `wine: created the configuration directory` to a quiet prefix-init log
- [ ] Keep `err:*` and `wine: failed` lines as elevated logs
- [ ] Update `run_process()` to interleave stdout/stderr with select() to avoid potential deadlock on longer-running processes

## Item 3: D3D11 console probe
- [ ] Write `Resources/TestPayloads/d3d11-probe.c` — calls `D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, ...)`, prints adapter description, exits
- [ ] Cross-compile to `hello-d3d11-probe.exe` with `x86_64-w64-mingw32-g++` + `-ld3d11 -ldxgi`
- [ ] Copy to `Resources/TestPayloads/hello-d3d11-probe.exe`
- [ ] Add build phase copy to `<Bundle>/Payloads/hello-d3d11-probe.exe` in project.yml
- [ ] Add `createD3D11ProbeContainer()` preset in HostShellViewModel
- [ ] Add `🔬 D3D11 Probe` button to UI with accessibilityID `createD3D11ProbeButton`
- [ ] Wine ships its own d3d11.dll (wined3d) — no DXVK needed for first test

## Item 4: Commit + push + update docs
- [ ] All unit tests pass (swift test)
- [ ] E2E tests pass
- [ ] Commit all with clear message
- [ ] Update roadmap and implementation queue
- [ ] Push
