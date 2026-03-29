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
    char line[256];

    snprintf(
        line,
        sizeof(line),
        "native stub preparing title=%s backend=%s lane=%s",
        config.title != NULL ? config.title : "unknown",
        config.backend != NULL ? config.backend : "unknown",
        config.product_lane != NULL ? config.product_lane : "unknown"
    );
    emit(context, callback, CELLARKIT_BRIDGE_EVENT_PREPARING, line, 0);
    usleep(20000);

    emit(context, callback, CELLARKIT_BRIDGE_EVENT_STARTED, "native stub started", 0);
    usleep(10000);

    snprintf(
        line,
        sizeof(line),
        "native backend=%s",
        config.backend != NULL ? config.backend : "unknown"
    );
    emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG, line, 0);
    usleep(10000);

    snprintf(
        line,
        sizeof(line),
        "native lane=%s",
        config.product_lane != NULL ? config.product_lane : "unknown"
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
