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
#include <sys/select.h>
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

/* ── Wine environment builder ─────────────────────────────────────── */

static char **build_wine_envp(
    const char *wine_binary_path,
    const char *wineprefix,
    const char *winedebug_val)
{
    int n = 0;
    for (char **e = environ; *e; e++) n++;

    char **envp = calloc((size_t)(n + 10), sizeof(char *));
    int j = 0;

    /* Build a PATH that includes wine's own bin dir (so wineserver is found)
     * prepended to whatever the parent process has. */
    char wine_bin_dir[4096] = "";
    if (wine_binary_path) {
        strncpy(wine_bin_dir, wine_binary_path, sizeof(wine_bin_dir) - 1);
        char *slash = strrchr(wine_bin_dir, '/');
        if (slash) *slash = '\0';
    }
    const char *parent_path = getenv("PATH");
    char new_path[8192];
    if (wine_bin_dir[0] && parent_path) {
        snprintf(new_path, sizeof(new_path), "%s:%s", wine_bin_dir, parent_path);
    } else if (wine_bin_dir[0]) {
        snprintf(new_path, sizeof(new_path), "%s:/usr/bin:/bin", wine_bin_dir);
    } else {
        snprintf(new_path, sizeof(new_path), "%s",
                 parent_path ? parent_path : "/usr/bin:/bin");
    }

    /* Copy parent env, stripping vars we're about to override. */
    for (int i = 0; i < n; i++) {
        if (strncmp(environ[i], "WINEPREFIX=",      11) == 0) continue;
        if (strncmp(environ[i], "WINEDEBUG=",       10) == 0) continue;
        if (strncmp(environ[i], "WINEDLLOVERRIDES=",17) == 0) continue;
        if (strncmp(environ[i], "PATH=",             5) == 0) continue;
        envp[j++] = strdup(environ[i]);
    }

    /* Inject patched PATH */
    {
        char buf[8256];
        snprintf(buf, sizeof(buf), "PATH=%s", new_path);
        envp[j++] = strdup(buf);
    }

    /* Explicitly set WINESERVER so wine64 doesn’t have to resolve it from
     * argv[0] (which fails inside the iOS simulator’s process environment). */
    if (wine_bin_dir[0]) {
        char buf[4096];
        snprintf(buf, sizeof(buf), "WINESERVER=%s/wineserver", wine_bin_dir);
        envp[j++] = strdup(buf);
    }

    /* WINEPREFIX */
    if (wineprefix && wineprefix[0]) {
        char buf[4096];
        snprintf(buf, sizeof(buf), "WINEPREFIX=%s", wineprefix);
        envp[j++] = strdup(buf);
    }

    /* WINEDEBUG */
    {
        char buf[256];
        snprintf(buf, sizeof(buf), "WINEDEBUG=%s",
                 winedebug_val ? winedebug_val : "-all");
        envp[j++] = strdup(buf);
    }

    /* Suppress menu-builder and Mono/Gecko install dialogs. */
    envp[j++] = strdup("WINEDLLOVERRIDES="
                       "winemenubuilder.exe=d;mscoree,mshtml=");

    envp[j] = NULL;
    return envp;
}

static void free_envp(char **envp)
{
    if (!envp) return;
    for (int i = 0; envp[i]; i++) free(envp[i]);
    free(envp);
}

/*
 * Spawn `executable` with `argv` and optional `envp` (NULL → inherit
 * parent environ), feed its combined stdout+stderr back line-by-line
 * as LOG events.  Returns the process exit code, or -1 on spawn failure.
 */
static int run_process(
    const char        *executable,
    char *const        argv[],
    char *const        envp[],
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
    int rc = posix_spawn(&pid, executable, &fa, NULL, argv,
                          envp ? (char *const *)envp : environ);
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
     * Drain stdout first (blocking until EOF), then stderr.
     * Both streams are line-buffered; stderr lines go through a noise filter.
     * Note: this sequential approach is safe because Wine's useful output
     * fits in the kernel pipe buffer (64 KB), and wineserver writes to its
     * OWN stderr descriptor which was dup'd from our pipe write end, so we
     * drain it cleanly after wine64 exits.
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

    /* Drain stderr with noise filter */
    if (ferr) {
        while (fgets(line, sizeof(line), ferr)) {
            chomp(line);
            if (!line[0]) continue;

            /* ── stderr noise filter ─────────────────────────────── */
            /* Drop fixme: lines (extremely noisy in Wine) */
            if (strncmp(line, "fixme:", 6) == 0) continue;
            /* Drop wineserver infrastructure chatter */
            if (strncmp(line, "wineserver: using ", 18) == 0) continue;
            if (strncmp(line, "wineserver: starting", 20) == 0) continue;
            /* Drop MoltenVK verbose listing */
            if (strncmp(line, "[mvk-",  5) == 0) continue;
            if (line[0] == '\t' && line[1] == '\t') continue;
            /* Prefix-creation notice — emit as quiet info log */
            if (strncmp(line, "wine: created the configuration", 31) == 0) {
                emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG,
                     "[wine] initialising new Wine prefix", 0);
                continue;
            }
            if (strncmp(line, "wine: configuration in", 22) == 0) continue;

            /* Keep errors and failures visibly tagged */
            char tagged[4200];
            if (strncmp(line, "err:",   4) == 0 ||
                strncmp(line, "wine: failed", 12) == 0 ||
                strncmp(line, "wine: cannot", 12) == 0) {
                snprintf(tagged, sizeof(tagged), "[wine-err] %s", line);
            } else {
                snprintf(tagged, sizeof(tagged), "[stderr] %s", line);
            }
            emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG, tagged, 0);
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

        const char *exe_arg = config.resolved_executable_path
                               ? config.resolved_executable_path : "";

        char **wine_envp = NULL;
        int    exit_code = -1;

        if (config.runtime_is_wine) {
            /* ── Real Wine: argv = [wine64, exe_path] ─────────────────── */
            /* Emit diagnostics so the log surface shows the paths used. */
            {
                char diag[2048];
                snprintf(diag, sizeof(diag),
                    "[bridge] wine64=%s exe=%s prefix=%s home=%s tmpdir=%s uid=%d",
                    config.runtime_binary_path ? config.runtime_binary_path : "<nil>",
                    exe_arg,
                    config.wineprefix_path ? config.wineprefix_path : "<nil>",
                    getenv("HOME") ? getenv("HOME") : "<nil>",
                    getenv("TMPDIR") ? getenv("TMPDIR") : "<nil>",
                    (int)getuid());
                emit(context, callback, CELLARKIT_BRIDGE_EVENT_LOG, diag, 0);
            }
            char *argv[] = {
                (char *)config.runtime_binary_path,
                (char *)exe_arg,
                NULL
            };
            wine_envp = build_wine_envp(config.runtime_binary_path,
                                        config.wineprefix_path,
                                        config.winedebug);
            exit_code = run_process(config.runtime_binary_path, argv,
                                    (char *const *)wine_envp,
                                    context, callback);
        } else {
            /* ── wine-stub: argv = [stub, --exe, path, --backend, ...] ─ */
            const char *back_arg  = config.backend
                                      ? config.backend : "";
            const char *gfx_arg   = config.graphics_backend
                                      ? config.graphics_backend : "";
            const char *title_arg = config.title ? config.title : "";
            char mem_str[32];
            snprintf(mem_str, sizeof(mem_str), "%d", config.memory_budget_mb);

            char *argv[] = {
                (char *)config.runtime_binary_path,
                "--exe",      (char *)exe_arg,
                "--backend",  (char *)back_arg,
                "--graphics", (char *)gfx_arg,
                "--memory",   mem_str,
                "--title",    (char *)title_arg,
                NULL
            };
            exit_code = run_process(config.runtime_binary_path, argv,
                                    NULL,
                                    context, callback);
        }

        free_envp(wine_envp);

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
            emit(context, callback, CELLARKIT_BRIDGE_EVENT_EXITED,
                 "process exited cleanly (code 0)", 0);
        }
        return;
    }

    /* ── Path B: legacy simulated events (no Wine binary yet) ── */
    emit_legacy_events(config, context, callback);
}
