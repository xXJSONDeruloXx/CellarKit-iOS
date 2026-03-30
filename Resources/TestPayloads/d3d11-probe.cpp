/*
 * d3d11-probe.cpp — CellarKit Stage-3 D3D11 capability probe.
 *
 * Creates a D3D11 device, queries adapter name / feature level, exits.
 * Driver priority:
 *   1. HARDWARE  — requires DXVK or working wined3d VK backend
 *   2. WARP      — wined3d software rasterizer (always works via Wine)
 *
 * Build:
 *   x86_64-w64-mingw32-g++ -o hello-d3d11-probe.exe d3d11-probe.cpp \
 *       -ld3d11 -ldxgi -luuid -static -O2 -mconsole
 */
#define WIN32_LEAN_AND_MEAN
#define UNICODE
#include <windows.h>
#include <dxgi.h>
#include <d3d11.h>
#include <stdio.h>

static const char *fl_str(D3D_FEATURE_LEVEL fl)
{
    switch (fl) {
    case D3D_FEATURE_LEVEL_11_1: return "11_1";
    case D3D_FEATURE_LEVEL_11_0: return "11_0";
    case D3D_FEATURE_LEVEL_10_1: return "10_1";
    case D3D_FEATURE_LEVEL_10_0: return "10_0";
    case D3D_FEATURE_LEVEL_9_3:  return "9_3";
    case D3D_FEATURE_LEVEL_9_2:  return "9_2";
    case D3D_FEATURE_LEVEL_9_1:  return "9_1";
    default:                     return "unknown";
    }
}

static const char *driver_str(D3D_DRIVER_TYPE t)
{
    switch (t) {
    case D3D_DRIVER_TYPE_HARDWARE: return "HARDWARE";
    case D3D_DRIVER_TYPE_WARP:     return "WARP";
    case D3D_DRIVER_TYPE_NULL:     return "NULL";
    default:                       return "unknown";
    }
}

int main()
{
    printf("[d3d11-probe] CellarKit D3D11 capability probe starting\n");
    fflush(stdout);

    /* ── Query DXGI adapter ──────────────────────────────────────────── */
    IDXGIFactory *factory = nullptr;
    if (SUCCEEDED(CreateDXGIFactory(IID_IDXGIFactory, (void **)&factory)) && factory) {
        IDXGIAdapter *adapter = nullptr;
        if (SUCCEEDED(factory->EnumAdapters(0, &adapter)) && adapter) {
            DXGI_ADAPTER_DESC desc = {};
            adapter->GetDesc(&desc);
            char narrow[128] = {};
            WideCharToMultiByte(CP_UTF8, 0, desc.Description, -1,
                                narrow, (int)sizeof(narrow)-1, nullptr, nullptr);
            printf("[d3d11-probe] DXGI adapter  : %s\n", narrow);
            printf("[d3d11-probe] Dedicated VRAM: %u MB\n",
                   (unsigned)(desc.DedicatedVideoMemory >> 20));
            adapter->Release();
        }
        factory->Release();
    }

    /* ── Create D3D11 device — try hardware first, fall back to WARP ─── */
    static const D3D_FEATURE_LEVEL levels[] = {
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_1,
        D3D_FEATURE_LEVEL_10_0,
        D3D_FEATURE_LEVEL_9_3,
    };

    static const D3D_DRIVER_TYPE try_order[] = {
        D3D_DRIVER_TYPE_HARDWARE,
        D3D_DRIVER_TYPE_WARP,
    };

    ID3D11Device        *device    = nullptr;
    ID3D11DeviceContext *ctx       = nullptr;
    D3D_FEATURE_LEVEL    got_fl    = (D3D_FEATURE_LEVEL)0;
    D3D_DRIVER_TYPE      used_type = (D3D_DRIVER_TYPE)0;

    for (auto driver_type : try_order) {
        HRESULT hr = D3D11CreateDevice(
            nullptr, driver_type, nullptr, 0,
            levels, ARRAYSIZE(levels),
            D3D11_SDK_VERSION,
            &device, &got_fl, &ctx
        );
        if (SUCCEEDED(hr)) { used_type = driver_type; break; }
        printf("[d3d11-probe] %s driver failed hr=0x%08lx, trying next\n",
               driver_str(driver_type), (unsigned long)hr);
        fflush(stdout);
    }

    if (!device) {
        printf("[d3d11-probe] All drivers failed\n");
        printf("[d3d11-probe] RESULT: FAIL\n");
        fflush(stdout);
        return 1;
    }

    printf("[d3d11-probe] D3D11 device created OK\n");
    printf("[d3d11-probe] Driver type   : %s\n", driver_str(used_type));
    printf("[d3d11-probe] Feature level : D3D_FEATURE_LEVEL_%s\n", fl_str(got_fl));

    D3D11_FEATURE_DATA_THREADING t = {};
    if (SUCCEEDED(device->CheckFeatureSupport(
            D3D11_FEATURE_THREADING, &t, sizeof(t)))) {
        printf("[d3d11-probe] ConcurrentResources : %s\n",
               t.DriverConcurrentCreates ? "YES" : "NO");
        printf("[d3d11-probe] CommandLists         : %s\n",
               t.DriverCommandLists ? "YES" : "NO");
    }

    ctx->Release();
    device->Release();

    printf("[d3d11-probe] RESULT: PASS\n");
    fflush(stdout);
    return 0;
}
