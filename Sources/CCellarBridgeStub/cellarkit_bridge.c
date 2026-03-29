#include "cellarkit_bridge.h"
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static void emit(
    void *context,
    cellarkit_bridge_callback callback,
    cellarkit_bridge_event_kind kind,
    const char *message,
    int32_t value
) {
    if (callback != NULL) {
        callback(context, kind, message, value);
    }
}

void cellarkit_bridge_run(
    cellarkit_bridge_config config,
    void *context,
    cellarkit_bridge_callback callback
) {
    char line[512];

    snprintf(
        line,
        sizeof(line),
        "native stub preparing title=%s backend=%s lane=%s graphics=%s dist=%s jit=%s",
        config.title != NULL ? config.title : "unknown",
        config.backend != NULL ? config.backend : "unknown",
        config.product_lane != NULL ? config.product_lane : "unknown",
        config.graphics_backend != NULL ? config.graphics_backend : "unknown",
        config.distribution_channel != NULL ? config.distribution_channel : "unknown",
        config.jit_mode != NULL ? config.jit_mode : "unknown"
    );
    emit(context, callback, CELLARKIT_BRIDGE_EVENT_PREPARING, line, 0);
    usleep(20000);

    emit(context, callback, CELLARKIT_BRIDGE_EVENT_STARTED, "native stub started", 0);
    usleep(10000);

    snprintf(
        line,
        sizeof(line),
        "native backend=%s graphics=%s memory=%d shaderCache=%d",
        config.backend != NULL ? config.backend : "unknown",
        config.graphics_backend != NULL ? config.graphics_backend : "unknown",
        config.memory_budget_mb,
        config.shader_cache_budget_mb
    );
    emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG, line, 0);
    usleep(10000);

    snprintf(
        line,
        sizeof(line),
        "native contentMode=%s contentPath=%s bookmark=%s",
        config.content_mode != NULL ? config.content_mode : "none",
        config.content_path != NULL ? config.content_path : "none",
        config.has_bookmark ? "present" : "absent"
    );
    emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG, line, 0);
    usleep(10000);

    emit(context, callback, CELLARKIT_BRIDGE_EVENT_INTERACTIVE, "native stub interactive", 0);
    usleep(10000);

    if (config.emit_failure) {
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_FAILED, "native stub failure", config.exit_code);
    } else {
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_EXITED, "native stub exited", config.exit_code);
    }
}
