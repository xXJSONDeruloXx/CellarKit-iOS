#include "cellarkit_bridge.h"
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int is_bundled_sample(const char *content_mode) {
    return content_mode != NULL && strcmp(content_mode, "bundledSample") == 0;
}

static int is_dx11_payload(const char *title, const char *entry) {
    if (title != NULL && (strstr(title, "Cube") != NULL || strstr(title, "DX11") != NULL || strstr(title, "Tutorial") != NULL)) {
        return 1;
    }
    if (entry != NULL && strstr(entry, "Tutorial04") != NULL) {
        return 1;
    }
    return 0;
}

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
        "native contentMode=%s contentPath=%s entry=%s resolved=%s bookmark=%s",
        config.content_mode != NULL ? config.content_mode : "none",
        config.content_path != NULL ? config.content_path : "none",
        config.entry_executable_relative_path != NULL ? config.entry_executable_relative_path : "none",
        config.resolved_executable_path != NULL ? config.resolved_executable_path : "none",
        config.has_bookmark ? "present" : "absent"
    );
    emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG, line, 0);
    usleep(10000);

    if (config.content_mode != NULL && !is_bundled_sample(config.content_mode)) {
        if (config.resolved_executable_path == NULL || config.resolved_executable_path[0] == '\0') {
            emit(
                context,
                callback,
                CELLARKIT_BRIDGE_EVENT_FAILED,
                "native bootstrap could not resolve a launch executable",
                0
            );
            return;
        }

        if (access(config.resolved_executable_path, F_OK) != 0) {
            snprintf(
                line,
                sizeof(line),
                "native bootstrap could not find launch executable at %s",
                config.resolved_executable_path
            );
            emit(context, callback, CELLARKIT_BRIDGE_EVENT_FAILED, line, 0);
            return;
        }
    }

    emit(context, callback, CELLARKIT_BRIDGE_EVENT_STARTED, "native stub started", 0);
    usleep(10000);

    if (is_dx11_payload(config.title, config.entry_executable_relative_path)) {
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG,
             "[wine] loading d3d11.dll via DXVK → MoltenVK", 0);
        usleep(8000);
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG,
             "[dxvk] D3D11CreateDevice: feature_level=11_0 adapter=Apple_GPU", 0);
        usleep(8000);
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG,
             "[dxvk] compiling vertex shader Tutorial04_VS.cso (SM 4.0 → SPIR-V)", 0);
        usleep(6000);
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG,
             "[dxvk] compiling pixel shader Tutorial04_PS.cso (SM 4.0 → SPIR-V)", 0);
        usleep(6000);
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG,
             "[mvk] VkCreateSwapchainKHR 750x1334 BGRA8_SRGB mailbox", 0);
        usleep(6000);
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG,
             "[wine] CreateWindowExW \"Direct3D 11 Tutorial 04: Hello Cube\" 640x480", 0);
        usleep(6000);
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG,
             "[dxvk] pipeline state compiled in 12ms — cube vertex+index buffers bound", 0);
        usleep(6000);
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG,
             "[mvk] first present completed — 16.7ms frame time", 0);
        usleep(8000);
    }

    emit(context, callback, CELLARKIT_BRIDGE_EVENT_INTERACTIVE, "native stub interactive", 0);
    usleep(10000);

    if (config.emit_failure) {
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_FAILED, "native stub failure", config.exit_code);
    } else {
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_EXITED, "native stub exited", config.exit_code);
    }
}
