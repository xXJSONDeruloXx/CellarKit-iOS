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
