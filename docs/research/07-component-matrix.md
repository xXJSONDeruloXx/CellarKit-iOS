# CrossOver / upstream component matrix

This is a focused matrix of the components surfaced by CodeWeavers’ public CrossOver source page, plus closely related upstreams relevant to an iOS implementation.

## Purpose

- identify which pieces are likely useful on iPhone/iPad,
- separate permissive/LGPL building blocks from app-shell inspirations,
- avoid treating the CrossOver bundle as a single reusable artifact.

## Matrix

| Component | Evidence source | Likely role in this project | Notes |
|---|---|---|---|
| Wine | CodeWeavers source page, Wine upstream | core Windows API compatibility layer | foundational dependency candidate |
| VKD3D / vkd3d-proton | CodeWeavers source page, upstream repos | D3D12→Vulkan path | relevant if D3D12 titles are in scope |
| DXVK / DXVK-macOS | CodeWeavers source page, Whisky credits | D3D9/10/11→Vulkan path | likely needs Apple-specific adaptation story |
| MoltenVK | CodeWeavers source page, MoltenVK README | Vulkan→Metal on iOS | one of the strongest Apple-platform graphics candidates |
| FAudio | CodeWeavers source page | XAudio replacement | useful for Windows game audio compatibility |
| SDL | CodeWeavers source page | input/audio/windowing helper in some paths | may help tooling or helper programs |
| wine-mono | CodeWeavers source page | .NET compatibility in Wine environments | not first-MVP critical, but useful later |
| GnuTLS | CodeWeavers source page | TLS/crypto dependency | plumbing dependency, not product differentiator |
| cabextract | CodeWeavers source page | installer/package extraction | useful for redistributables and installers |
| Samba | CodeWeavers source page | Windows networking/file service support | probably low priority for first MVP |
| LLVM | CodeWeavers source page | shader/compiler/runtime toolchain support | indirect dependency in some graphics paths |
| Sparkle | CodeWeavers source page | macOS updater | not relevant for iOS runtime MVP |
| PyObjC / PyXDG / htmltextview.py / XML modules | CodeWeavers source page | desktop support tooling | mostly irrelevant for iOS MVP |
| MojoSetup | CodeWeavers source page | installer tooling | maybe useful later for complex game installers |
| FreeType / libjpeg / libxml2 / libxslt | CodeWeavers source page | support libraries | standard infrastructure, not the core challenge |
| UnRAR | CodeWeavers source page | archive extraction | potentially useful for import/install workflows |

## Recommended priority buckets

### Tier 1 — evaluate immediately

- Wine
- MoltenVK
- DXVK / Apple-adapted DXVK path
- VKD3D-Proton
- FAudio

### Tier 2 — useful once install workflows grow up

- wine-mono
- cabextract
- UnRAR
- MojoSetup

### Tier 3 — mostly background infrastructure

- GnuTLS
- LLVM
- FreeType / libjpeg / libxml / xslt

### Tier 4 — probably not relevant to the first iOS MVP

- Sparkle
- PyObjC
- PyXDG
- htmltextview.py
- various desktop XML/perl/python helpers

## Key takeaway

The iOS project should treat the compatibility stack as:
- a small set of high-value runtime components,
- plus a larger tail of support dependencies,
- not as a literal “port CrossOver wholesale” exercise.

## Sources

- CodeWeavers source page: https://www.codeweavers.com/crossover/source
- CodeWeavers open-source page: https://www.codeweavers.com/open-source
- Whisky credits: https://github.com/Whisky-App/Whisky
- MoltenVK: https://github.com/KhronosGroup/MoltenVK
- DXVK: https://github.com/doitsujin/dxvk
- DXVK-macOS: https://github.com/Gcenx/DXVK-macOS
- VKD3D-Proton: https://github.com/HansKristian-Work/vkd3d-proton
- Wine: https://github.com/wine-mirror/wine
