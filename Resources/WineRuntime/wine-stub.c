/*
 * wine-stub — CellarKit Stage 1 runtime placeholder.
 *
 * This is a REAL compiled binary that gets posix_spawn()'d by the bridge.
 * It prints Wine-realistic output to stdout and exits cleanly.
 *
 * In Stage 2 this binary is replaced by real Wine (libwine + loader).
 * The bridge interface (argv layout, stdout line format) stays the same
 * so the rest of the stack needs no changes when Wine lands.
 *
 * Usage:
 *   wine-stub [--exe <path>] [--backend <name>] [--graphics <name>]
 *             [--memory <mb>] [--title <title>]
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

/* Print a log line and flush immediately so the parent sees it. */
#define LOG(fmt, ...) do { printf(fmt "\n", ##__VA_ARGS__); fflush(stdout); } while(0)
#define USEC(us)      usleep(us)

static const char *find_arg(int argc, char **argv, const char *flag, const char *fallback) {
    for (int i = 1; i < argc - 1; i++) {
        if (strcmp(argv[i], flag) == 0) return argv[i + 1];
    }
    return fallback;
}

int main(int argc, char **argv) {
    const char *exe      = find_arg(argc, argv, "--exe",      "unknown.exe");
    const char *backend  = find_arg(argc, argv, "--backend",  "wineX64Translator");
    const char *graphics = find_arg(argc, argv, "--graphics", "dxvkMoltenVK");
    const char *title    = find_arg(argc, argv, "--title",    "Windows Application");
    const char *memory   = find_arg(argc, argv, "--memory",   "2048");

    /* ── preloader ─────────────────────────────────────────── */
    LOG("[wine] wine-stub v0.1-cellarkit (stage-1 placeholder)");
    LOG("[wine] target exe : %s", exe);
    LOG("[wine] backend    : %s  graphics: %s  memory: %s MB", backend, graphics, memory);
    USEC(30000);

    LOG("[wine] preloader: setting up address space layout");
    USEC(20000);
    LOG("[wine] ntdll: initialising process heap (initial 64 KB)");
    USEC(15000);
    LOG("[wine] ntdll: loading %s", exe);
    USEC(25000);

    /* ── PE load ────────────────────────────────────────────── */
    LOG("[wine] loader: PE header   arch=x86_64  subsystem=Windows_GUI");
    USEC(10000);
    LOG("[wine] loader: import table  kernel32 user32 d3d11 dxgi");
    USEC(20000);
    LOG("[wine] loader: d3d11.dll → DXVK vk_icd");
    USEC(15000);
    LOG("[wine] loader: dxgi.dll  → DXVK swapchain");
    USEC(15000);

    /* ── DXVK/Vulkan init ───────────────────────────────────── */
    LOG("[dxvk] initialising DXVK (graphics=%s)", graphics);
    USEC(20000);
    LOG("[dxvk] D3D11CreateDevice: feature_level=11_0  adapter=Apple_M_series");
    USEC(30000);
    LOG("[dxvk] swap chain: 1080x1920 format=BGRA8_UNORM_SRGB mode=mailbox");
    USEC(15000);

    /* ── MoltenVK ───────────────────────────────────────────── */
    LOG("[mvk]  MoltenVK v1.2 — Metal backend");
    USEC(10000);
    LOG("[mvk]  vkCreateDevice → MTLDevice: Apple GPU");
    USEC(20000);
    LOG("[mvk]  VkSwapchainKHR created (CAMetalLayer)");
    USEC(15000);

    /* ── shader compilation ─────────────────────────────────── */
    if (strstr(exe, "Tutorial") || strstr(exe, "Cube") || strstr(exe, "cube")) {
        LOG("[dxvk] compiling shader pipeline for \"%s\"", title);
        USEC(20000);
        LOG("[dxvk] VS: SM4 bytecode → SPIR-V (12 instructions)");
        USEC(25000);
        LOG("[dxvk] PS: SM4 bytecode → SPIR-V (8 instructions)");
        USEC(25000);
        LOG("[mvk]  MTLRenderPipelineState compiled in 18 ms");
        USEC(20000);
    }

    /* ── WinMain / app startup ──────────────────────────────── */
    LOG("[wine] ntdll: calling WinMain for \"%s\"", title);
    USEC(30000);
    LOG("[wine] user32: CreateWindowExW \"%s\" 640x480", title);
    USEC(20000);
    LOG("[wine] user32: ShowWindow + UpdateWindow");
    USEC(10000);

    /* ── first frame ────────────────────────────────────────── */
    LOG("[dxvk] first present: 16.7 ms frame time (60 fps target)");
    USEC(15000);
    LOG("[mvk]  frame 1 presented to CAMetalLayer");
    USEC(10000);
    LOG("[wine] message loop running — stub will exit after 3 frames");
    USEC(50000);

    LOG("[dxvk] frame 2: vertex buffer updated (rotation matrix)");
    USEC(50000);
    LOG("[dxvk] frame 3: frame time 16.8 ms");
    USEC(50000);

    /* ── clean exit ─────────────────────────────────────────── */
    LOG("[wine] WM_QUIT received — shutting down");
    USEC(20000);
    LOG("[wine] process exited cleanly (exit_code=0)");

    return 0;
}
