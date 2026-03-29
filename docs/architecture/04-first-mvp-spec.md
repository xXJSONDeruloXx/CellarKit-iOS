# First MVP specification

This document defines the **smallest serious build** that would count as a real milestone rather than just more research.

## MVP goal

Run a locally imported Windows game payload or sample workload inside a persistent container on iPhone/iPad, with:
- a deterministic backend choice,
- visible rendering or at least a confirmed launch surface,
- usable input,
- durable metadata and logs.

## Explicit non-goals

The first MVP does **not** need:
- Steam/Epic/GOG/Amazon login,
- cloud-save sync,
- broad game compatibility claims,
- App Store submission,
- perfect graphics performance,
- a polished overlay editor.

## Required user flow

1. Launch app.
2. Create or import a game container.
3. Choose a local payload or sample.
4. Persist container metadata.
5. Compute runtime plan.
6. Launch using the selected backend.
7. Surface logs/state during and after launch.
8. Re-open the app and see the same container intact.

## Required technical features

## 1. Capability detection

Must report:
- distribution channel class,
- execution mode / JIT class,
- debugger attachment signal if available,
- whether the build is in `research` or `constrainedPublic` lane.

## 2. Container persistence

Must support:
- save container metadata to disk,
- load all containers,
- delete containers,
- record imported content mode,
- record last successful launch timestamp.

## 3. Planning logic

Must support:
- ARM64, ARM64EC, x64, x86 guest architecture inputs,
- lane-aware backend selection,
- lane-aware policy risk grading,
- interpreter fallback,
- diagnostic fallback.

## 4. Import model

Must support at least:
- managed copy,
- bundled sample,
- future slot for security-scoped reference.

## 5. Launch bridge

The first launch bridge can be minimal, but it must:
- accept a selected container,
- produce start/stop events,
- capture logs,
- distinguish clean termination from failure.

## 6. Input

At minimum, one of these must work:
- touch overlay stub with basic virtual controls,
- or physical controller path.

If neither is usable, it is not a real MVP.

## 7. Lifecycle and logging

Must handle:
- app relaunch with previous containers preserved,
- logs saved per container or per launch,
- clear display of last error or last exit status.

## Success criteria

A build counts as MVP only if all are true:

- a container can be created,
- the container survives relaunch,
- the planner chooses a backend deterministically,
- a sample workload launches through the bridge,
- logs are persisted,
- input is usable enough to interact or confirm liveness,
- there is a repeatable test path for another agent to reproduce the result.

## Suggested milestone order inside the MVP

### Milestone A
- pure Swift planning + persistence complete

### Milestone B
- minimal iOS host app displays containers and plans

### Milestone C
- launch bridge spike wired into the host app

### Milestone D
- first interactive sample path

### Milestone E
- basic input and logging polish

## What comes right after MVP

Once the MVP exists, next priorities are:
- better import UX,
- graphics/performance measurement,
- security-scoped bookmarks,
- storefront abstraction scaffolding,
- save-path discovery.
