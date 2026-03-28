# Licensing and policy compatibility

This document answers two separate questions:

1. **What code can we safely study, copy, or link?**
2. **What product shapes are likely to collide with App Store policy?**

These are related, but not the same.

---

## 1. Repository and component license inventory

The table below focuses on the projects most relevant to an iOS Windows-game runtime.

| Project / component | License evidence | Practical implication |
|---|---|---|
| Whisky | GitHub license metadata: GPL-3.0 | Great reference. Copying app-shell code likely means the derivative shell must also be GPL-compatible. |
| Bottles | GitHub license metadata: GPL-3.0 | Same caution as Whisky. Study patterns freely; avoid copy/paste unless the whole project is intended to be GPL. |
| Pluvia | GitHub license metadata: GPL-3.0 | Same caution. |
| GameNative | local `LICENSE` is GPL-3.0 | Same caution, especially for Kotlin/Android shell code. |
| UTM (frontend) | GitHub license metadata: Apache-2.0 | The frontend is a strong reference source for architecture and some code patterns. |
| Wine | upstream `LICENSE` says LGPL-2.1 or later | Usually compatible with commercial/proprietary shells if obligations are met, especially when dynamically linked and modifications are published as required. |
| Proton top-level | `LICENSE.proton` is BSD-3-Clause style | Top-level orchestration ideas are relatively permissive, but each bundled subcomponent has its own license. |
| DXVK | GitHub metadata: Zlib | Very permissive. |
| DXVK-macOS | GitHub metadata: Zlib | Very permissive. |
| VKD3D-Proton | GitHub metadata: LGPL-2.1 | Usable with care; keep obligations clear. |
| MoltenVK | GitHub metadata: Apache-2.0 | Attractive Apple-platform graphics bridge from a licensing perspective. |
| wine-msync | GitHub metadata: LGPL-2.1 | Useful Apple/Wine reference; keep LGPL obligations in mind. |
| FAudio | upstream license text is zlib-style permissive | Low-friction from a licensing standpoint. |
| SDL | GitHub metadata: Zlib | Low-friction from a licensing standpoint. |
| Sparkle | upstream license text is MIT-style | Not directly relevant to iOS runtime, but permissive. |
| CrossOver | CodeWeavers says open-source core plus proprietary value-add | Use the public FOSS pieces and upstream projects; do not assume proprietary CrossOver behavior can be reused. |

### Source references

- Whisky: https://github.com/Whisky-App/Whisky
- Bottles: https://github.com/bottlesdevs/Bottles
- Pluvia: https://github.com/oxters168/Pluvia
- UTM: https://github.com/utmapp/UTM
- Wine: https://github.com/wine-mirror/wine
- Proton: https://github.com/ValveSoftware/Proton
- DXVK: https://github.com/doitsujin/dxvk
- DXVK-macOS: https://github.com/Gcenx/DXVK-macOS
- VKD3D-Proton: https://github.com/HansKristian-Work/vkd3d-proton
- MoltenVK: https://github.com/KhronosGroup/MoltenVK
- wine-msync: https://github.com/marzent/wine-msync
- CodeWeavers source page: https://www.codeweavers.com/crossover/source
- CodeWeavers open-source page: https://www.codeweavers.com/open-source

---

## 2. Safe reuse strategy

## Recommended rule of thumb

### Okay to do early

- read and cite code paths,
- mirror architecture ideas,
- recreate data models from first principles,
- design similar UX concepts,
- dynamically integrate permissive or LGPL components when obligations are understood.

### Avoid until license direction is chosen

- copy/pasting Whisky/Bottles/Pluvia/GameNative shell code,
- blending GPL shell code into a non-GPL app shell,
- assuming all CrossOver behavior is upstream/open.

### Strong recommendation

Keep the new repository’s **Swift shell and planning code original**.

That preserves future choice:
- permissive shell + LGPL runtime libs,
- GPL end-to-end distribution,
- dual-track open/core distribution,
- or private research before license selection.

---

## 3. App Store policy considerations

## Direct evidence: Apple guideline 2.5.2

Apple’s App Store Review Guidelines say:

> Apps should be self-contained in their bundles ... nor may they download, install, or execute code which introduces or changes features or functionality of the app ...

Source:
- https://developer.apple.com/app-store/review/guidelines/

## What this means here

### Lower policy risk

- local import of already-owned content,
- emulator shell or technical demonstrator,
- interpreter-only or constrained runtime variants,
- sideload-first products not intended for App Store review.

### Higher policy risk

- built-in Steam/Epic/GOG/Amazon authentication as a primary feature,
- downloading Windows binaries inside the app,
- advertising broad ability to execute downloaded Windows software.

### Important nuance

UTM SE shows that Apple may accept some forms of dynamic execution or emulation. But that does **not** automatically imply acceptance of a storefront-integrated Windows-game downloader.

So the policy posture should be:

- **evidence:** Apple has accepted at least some emulator/interpreter products.
- **inference:** a Windows storefront launcher is materially riskier than a general-purpose emulator shell.

---

## 4. Consequences for product shape

## Best near-term distribution plan

### Lane 1 — research / enthusiast build

- private GitHub repo or side-loaded distribution,
- debugger/JIT-assisted launch allowed,
- full technical ambition,
- may include store logins later.

### Lane 2 — policy-constrained public SKU

- import-first,
- maybe interpreter-first,
- likely no direct store download of Windows executables,
- reviewed as a separate product strategy, not assumed from Lane 1.

---

## 5. Proposed code provenance rules for this repo

1. **Do not copy GPL app-shell code verbatim** unless the repo intentionally becomes GPL.
2. **Prefer original Swift implementations** for:
   - container metadata,
   - runtime planning,
   - storefront abstractions,
   - overlay/input configuration UI.
3. **Use LGPL/permissive runtime components as isolated dependencies** rather than mixing their code into the shell without tracking obligations.
4. **Track every future imported runtime dependency in a machine-readable bill of materials.**
5. **Do not treat GPTK or CrossOver proprietary behavior as redistributable** without explicit license review.

---

## 6. Recommended licensing posture today

Because this repo currently contains:
- original notes,
- original architecture docs,
- original Swift planning code,
- and no copied GPL shell code,

it is best to **delay final project license selection** until the implementation path is clearer.

Why delay?
- If the shell later incorporates GPL code, the repo may need to become GPL.
- If the shell stays original and uses mostly permissive/LGPL runtime components, a permissive shell license remains viable.
- The wrong early license choice can create needless churn.

So the current rule is:

> keep code original, track provenance carefully, and choose the repo license after the first real runtime integration decision.

---

## Bottom line

- **Studying** Whisky, Bottles, Proton, UTM, Pluvia, and GameNative is safe and valuable.
- **Copying** GPL shell code is a strategic decision, not a casual convenience.
- **Linking/integrating** Wine/DXVK/VKD3D/MoltenVK style components is likely manageable, but only with careful compliance.
- **App Store approval** for a full Windows storefront runner should be treated as an open question with high risk, not a baseline assumption.
