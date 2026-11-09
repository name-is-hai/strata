/* SPDX-License-Identifier: MIT
 * Let pam_fprintd consume SIGINT through its signalfd and fall through to the
 * existing password stack. This module never authenticates a user itself.
 */
#include <security/pam_modules.h>
#include <security/pam_ext.h>
#include <pthread.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>

struct signal_state { sigset_t previous; };
static void restore_mask(pam_handle_t *pamh, void *data, int status) {
    (void)pamh; (void)status;
    struct signal_state *state = data;
    if (!sigismember(&state->previous, SIGINT)) {
        sigset_t signals;
        sigemptyset(&signals);
        sigaddset(&signals, SIGINT);
        struct timespec zero = {0};
        while (sigtimedwait(&signals, NULL, &zero) >= 0) {}
    }
    pthread_sigmask(SIG_SETMASK, &state->previous, NULL);
    free(state);
}

PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    (void)flags; (void)argc; (void)argv;
    const void *service = NULL, *existing = NULL;
    if (pam_get_item(pamh, PAM_SERVICE, &service) != PAM_SUCCESS || !service ||
        strcmp(service, "polkit-1") != 0) return PAM_IGNORE;
    if (pam_get_data(pamh, "strata-polkit-sigint", &existing) == PAM_SUCCESS) return PAM_IGNORE;
    struct signal_state *state = calloc(1, sizeof(*state));
    if (!state) return PAM_IGNORE;
    sigset_t signals;
    sigemptyset(&signals);
    sigaddset(&signals, SIGINT);
    if (pthread_sigmask(SIG_BLOCK, &signals, &state->previous) != 0) { free(state); return PAM_IGNORE; }
    if (pam_set_data(pamh, "strata-polkit-sigint", state, restore_mask) != PAM_SUCCESS)
        restore_mask(pamh, state, 0);
    return PAM_IGNORE;
}

PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    (void)pamh; (void)flags; (void)argc; (void)argv;
    return PAM_IGNORE;
}
