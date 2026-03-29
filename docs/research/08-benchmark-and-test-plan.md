# Benchmark and test plan

This document defines how future agents should evaluate runtime experiments.

## Why this exists

A runtime like this can look promising in a single screenshot while still being unusable because of:
- startup time,
- thermals,
- memory pressure,
- input lag,
- suspend/resume failures,
- shader stutter.

So every serious backend experiment needs repeatable measurements.

## Test matrix dimensions

### Distribution / execution mode
- developer-signed + debugger attached
- side-load + JIT assist
- jailbreak
- constrained / no-JIT mode

### Backend
- Wine ARM64
- Wine ARM64EC
- Wine x64 translator
- threaded interpreter
- diagnostic VM fallback

### Content type
- synthetic sample workload
- tiny utility / launcher-like payload
- representative game menu path
- representative in-game path

## Metrics to capture

## Launch metrics
- cold app launch time
- container load time
- planning time
- runtime bootstrap time
- time to first visible frame or first confirmed process state

## Stability metrics
- number of successful launches out of N attempts
- crash frequency
- clean exit frequency
- relaunch success after failure

## Resource metrics
- peak memory estimate
- sustained memory estimate
- shader cache size
- code cache / translation cache size if applicable
- on-disk container size

## Runtime metrics
- FPS in menu
- FPS in representative gameplay
- frame pacing variance if measurable
- input latency observations
- audio dropout observations

## Device-state metrics
- thermal state changes over time
- battery drop over a fixed session window
- background / foreground survival
- screen lock / unlock recovery

## Required test scenarios

### Scenario 1 — cold import and first launch
- create new container
- import sample payload
- compute plan
- launch
- record time to first useful state

### Scenario 2 — second launch
- terminate app
- reopen app
- launch same container again
- compare startup delta

### Scenario 3 — sustained session
- run for 10 to 20 minutes
- observe thermals, stutter, memory warnings

### Scenario 4 — interruption handling
- background app
- return to app
- test controller disconnect/reconnect if available
- test audio route change if available

### Scenario 5 — failure recovery
- simulate failed launch or bad payload
- ensure logs are saved and the app remains usable

## Test artifact checklist

Each experiment should produce:
- device model
- OS version
- lane (`research` or `constrainedPublic`)
- backend chosen
- content description
- logs path
- metrics summary
- pass/fail judgement
- next recommendation

## Simple result template

```markdown
# Runtime experiment result

- Device:
- OS:
- Lane:
- Backend:
- Content:
- JIT mode:

## Results
- Cold launch:
- First visible frame / first live state:
- Peak memory:
- Sustained FPS:
- Thermal notes:
- Lifecycle notes:
- Input notes:
- Audio notes:

## Verdict
- pass / partial / fail

## Next step
-
```

## Pass criteria for backend advancement

A backend should move forward only if it can do all of the following on at least one real-device scenario:
- launch reliably,
- remain interactive,
- survive a short session without immediate thermal collapse,
- preserve logs and container state.

## Failure criteria

A backend should be deprioritized if it consistently:
- crashes at startup,
- triggers unrecoverable memory kills,
- never reaches an interactive state,
- or needs device-specific hacks with no plausible generalization.
