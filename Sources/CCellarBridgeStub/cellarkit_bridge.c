/*
 * cellarkit_bridge.c — real process-execution bridge (Stage 1).
 *
 * Replaces the previous fake-event stub with actual posix_spawn() +
 * pipe-based stdout/stderr capture.  When a runtime_binary_path is
 * supplied the bridge exec's that binary (wine-stub today, real Wine
 * once we have a build).  If no runtime_binary_path is set it falls
 * back to the legacy simulated events so existing tests keep passing.
 */

#include "cellarkit_bridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <spawn.h>
#include <sys/wait.h>

extern char **environ;

/* ── helpers ──────────────────────────────────────────────────────── */

static void emit(
    void *ctx, cellarkit_bridge_callback cb,
    cellarkit_bridge_event_kind kind, const char *msg, int32_t val)
{
    if (cb) cb(ctx, kind, msg ? msg : "", val);
}

/* Strip trailing \r\n in-place. */
static void chomp(char *s) {
    size_t n = strlen(s);
    while (n > 0 && (s[n-1] == '\n' || s[n-1] == '\r')) s[--n] = '\0';
}

/* ── real process runner ──────────────────────────────────────────── */

/*
 * Spawn `executable` with `argv`, feed its combined stdout+stderr back
 * line-by-line as LOG events.  Returns the process exit code, or -1 on
 * spawn failure.
 */
static int run_process(
    const char        *executable,
    char *const        argv[],
    void              *context,
    cellarkit_bridge_callback callback)
{
    /* Create one pipe for stdout and one for stderr. */
    int out_pipe[2], err_pipe[2];
    if (pipe(out_pipe) != 0 || pipe(err_pipe) != 0) {
        char msg[256];
        snprintf(msg, sizeof(msg), "bridge: pipe() failed: %s", strerror(errno));
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_FAILED, msg, errno);
        return -1;
    }

    /* Wire up child's stdout/stderr to our write-ends. */
    posix_spawn_file_actions_t fa;
    posix_spawn_file_actions_init(&fa);
    posix_spawn_file_actions_addclose(&fa, out_pipe[0]);
    posix_spawn_file_actions_addclose(&fa, err_pipe[0]);
    posix_spawn_file_actions_adddup2(&fa, out_pipe[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&fa, err_pipe[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&fa, out_pipe[1]);
    posix_spawn_file_actions_addclose(&fa, err_pipe[1]);

    pid_t pid = 0;
    int rc = posix_spawn(&pid, executable, &fa, NULL, argv, environ);
    posix_spawn_file_actions_destroy(&fa);

    /* Close write-ends in parent — child owns them now. */
    close(out_pipe[1]);
    close(err_pipe[1]);

    if (rc != 0) {
        close(out_pipe[0]);
        close(err_pipe[0]);
        char msg[512];
        snprintf(msg, sizeof(msg),
                 "bridge: posix_spawn(%s) failed: %s (errno %d)",
                 executable, strerror(rc), rc);
        /* Emit as LOG first so it shows up in the session log UI */
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG, msg, 0);
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_FAILED, msg, rc);
        return -1;
    }

    emit(context, callback, CELLARKIT_BRIDGE_EVENT_STARTED, "process started", 0);

    /*
     * Read stdout line-by-line, emit each as a LOG event.
     * We do a simple round-robin between stdout and stderr by opening
     * both as FILE* and reading stdout first (Wine sends everything to
     * stdout in our stub; real Wine also uses stdout for debug output).
     */
    FILE *fout = fdopen(out_pipe[0], "r");
    FILE *ferr = fdopen(err_pipe[0], "r");

    char line[4096];

    /* Drain stdout */
    if (fout) {
        while (fgets(line, sizeof(line), fout)) {
            chomp(line);
            if (line[0] != '\0')
                emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG, line, 0);
        }
        fclose(fout);
    } else {
        close(out_pipe[0]);
    }

    /* Drain stderr (tagged so the UI can distinguish it) */
    if (ferr) {
        while (fgets(line, sizeof(line), ferr)) {
            chomp(line);
            if (line[0] != '\0') {
                char tagged[4160];
                snprintf(tagged, sizeof(tagged), "[stderr] %s", line);
                emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG, tagged, 0);
            }
        }
        fclose(ferr);
    } else {
        close(err_pipe[0]);
    }

    int status = 0;
    waitpid(pid, &status, 0);

    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        char msg[128];
        snprintf(msg, sizeof(msg), "process killed by signal %d", WTERMSIG(status));
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_FAILED, msg, WTERMSIG(status));
        return -1;
    }
    return -1;
}

static int is_bundled_sample(const char *mode) {
    return mode != NULL && strcmp(mode, "bundledSample") == 0;
}

/* ── legacy simulated events (fallback when no runtime binary) ────── */

static void emit_legacy_events(
    cellarkit_bridge_config config,
    void *context,
    cellarkit_bridge_callback callback)
{
    char line[512];

    snprintf(line, sizeof(line),
             "[stub] no runtime_binary_path — using legacy simulated events");
    emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG, line, 0);

    snprintf(line, sizeof(line),
             "[stub] title=%s backend=%s graphics=%s",
             config.title   ? config.title   : "?",
             config.backend ? config.backend : "?",
             config.graphics_backend ? config.graphics_backend : "?");
    emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG, line, 0);

    /* Validate executable for explicitly imported (non-bundled) payloads. */
    if (config.content_mode != NULL && !is_bundled_sample(config.content_mode)) {
        if (config.resolved_executable_path == NULL ||
                config.resolved_executable_path[0] == '\0') {
            emit(context, callback, CELLARKIT_BRIDGE_EVENT_FAILED,
                 "native bootstrap could not resolve a launch executable", 0);
            return;
        }
        if (access(config.resolved_executable_path, F_OK) != 0) {
            snprintf(line, sizeof(line),
                     "native bootstrap could not find launch executable at %s",
                     config.resolved_executable_path);
            emit(context, callback, CELLARKIT_BRIDGE_EVENT_FAILED, line, 0);
            return;
        }
    }

    emit(context, callback, CELLARKIT_BRIDGE_EVENT_STARTED,
         "legacy stub started", 0);
    emit(context, callback, CELLARKIT_BRIDGE_EVENT_INTERACTIVE,
         "legacy stub interactive", 0);

    if (config.emit_failure) {
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_FAILED,
             "legacy stub failure", config.exit_code);
    } else {
        emit(context, callback, CELLARKIT_BRIDGE_EVENT_EXITED,
             "legacy stub exited", config.exit_code);
    }
}

/* ── public entry point ──────────────────────────────────────────── */

void cellarkit_bridge_run(
    cellarkit_bridge_config config,
    void *context,
    cellarkit_bridge_callback callback)
{
    /* Announce what we received. */
    char prep[512];
    snprintf(prep, sizeof(prep),
             "bridge: title=%s backend=%s graphics=%s runtime=%s",
             config.title  ? config.title  : "?",
             config.backend ? config.backend : "?",
             config.graphics_backend ? config.graphics_backend : "?",
             config.runtime_binary_path ? config.runtime_binary_path : "(none)");
    emit(context, callback, CELLARKIT_BRIDGE_EVENT_PREPARING, prep, 0);
    emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG, prep, 0);  /* mirror to log */

    /* ── Path A: real process execution ───────────────────── */
    if (config.runtime_binary_path && config.runtime_binary_path[0] != '\0') {

        /* Build argv for the runtime binary.
         *
         * wine-stub (and eventually real Wine) uses:
         *   wine-stub --exe <path> --backend <b> --graphics <g>
         *             --memory <mb> --title <title>
         */
        const char *exe_arg   = config.resolved_executable_path
                                  ? config.resolved_executable_path : "";
        const char *title_arg = config.title ? config.title : "";
        const char *back_arg  = config.backend ? config.backend : "";
        const char *gfx_arg   = config.graphics_backend
                                  ? config.graphics_backend : "";
        char mem_str[32];
        snprintf(mem_str, sizeof(mem_str), "%d", config.memory_budget_mb);

        /* argv must be char*const[], not const char*[]. */
        char *argv[] = {
            (char *)config.runtime_binary_path,
            "--exe",      (char *)exe_arg,
            "--backend",  (char *)back_arg,
            "--graphics", (char *)gfx_arg,
            "--memory",   mem_str,
            "--title",    (char *)title_arg,
            NULL
        };

        int exit_code = run_process(config.runtime_binary_path, argv,
                                    context, callback);

        if (exit_code < 0) {
            /* run_process already emitted FAILED */
            return;
        }

        emit(context, callback, CELLARKIT_BRIDGE_EVENT_INTERACTIVE,
             "process interactive", 0);

        if (exit_code != 0 || config.emit_failure) {
            char msg[128];
            snprintf(msg, sizeof(msg), "process exited with code %d", exit_code);
            emit(context, callback, CELLARKIT_BRIDGE_EVENT_FAILED, msg, exit_code);
        } else {
            char msg[64];
            snprintf(msg, sizeof(msg), "process exited cleanly (code 0)");
            emit(context, callback, CELLARKIT_BRIDGE_EVENT_EXITED, msg, 0);
        }
        return;
    }

    /* ── Path B: legacy simulated events (no Wine binary yet) ── */
    emit_legacy_events(config, context, callback);
}
