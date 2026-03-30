#ifndef CELLARKIT_BRIDGE_H
#define CELLARKIT_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef int32_t cellarkit_bridge_event_kind;

enum {
    CELLARKIT_BRIDGE_EVENT_PREPARING = 0,
    CELLARKIT_BRIDGE_EVENT_STARTED = 1,
    CELLARKIT_BRIDGE_EVENT_LOG = 2,
    CELLARKIT_BRIDGE_EVENT_INTERACTIVE = 3,
    CELLARKIT_BRIDGE_EVENT_EXITED = 4,
    CELLARKIT_BRIDGE_EVENT_FAILED = 5
};

typedef struct {
    const char *title;
    const char *backend;
    const char *product_lane;
    const char *graphics_backend;
    const char *distribution_channel;
    const char *jit_mode;
    const char *content_mode;
    const char *content_path;
    const char *entry_executable_relative_path;
    const char *resolved_executable_path;
    /* Path to the Wine binary (or wine-stub placeholder) to posix_spawn.
       NULL / empty string → fall back to legacy simulated events. */
    const char *runtime_binary_path;

    /* 1 = runtime_binary_path points at a real Wine installation;
       use Wine-style argv: [wine64, exe_path].
       0 = wine-stub style: [stub, --exe, exe_path, --backend, ...]. */
    int32_t runtime_is_wine;

    /* WINEPREFIX directory (writable).  Passed as WINEPREFIX env var.
       NULL = Wine will fall back to ~/.wine (probably wrong inside sandbox). */
    const char *wineprefix_path;

    /* WINEDEBUG spec, e.g. "-all" to suppress noise.  NULL = Wine default. */
    const char *winedebug;

    int32_t memory_budget_mb;
    int32_t shader_cache_budget_mb;
    int32_t has_bookmark;
    int32_t exit_code;
    int32_t emit_failure;
} cellarkit_bridge_config;

typedef void (*cellarkit_bridge_callback)(
    void *context,
    cellarkit_bridge_event_kind kind,
    const char *message,
    int32_t value
);

void cellarkit_bridge_run(
    cellarkit_bridge_config config,
    void *context,
    cellarkit_bridge_callback callback
);

#ifdef __cplusplus
}
#endif

#endif
