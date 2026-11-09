/* Synthetic PAM conversations: no system PAM files, real credentials or reader. */
#define _GNU_SOURCE
#include <security/pam_appl.h>
#include <security/pam_ext.h>
#include <security/pam_modules.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <poll.h>
#include <sys/signalfd.h>
#include <sys/wait.h>

#ifdef TEST_PAM_MODULE
PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    (void)flags;
    if (argc != 1) return PAM_SYSTEM_ERR;
    if (strcmp(argv[0], "fingerprint") == 0) {
        sigset_t signals, current;
        sigemptyset(&signals); sigaddset(&signals, SIGINT);
        sigprocmask(SIG_BLOCK, NULL, &current);
        if (!sigismember(&current, SIGINT)) return PAM_SYSTEM_ERR;
        int fd = signalfd(-1, &signals, SFD_CLOEXEC);
        if (fd < 0) return PAM_SYSTEM_ERR;
        pam_info(pamh, "fingerprint");
        struct pollfd pollfd = {fd, POLLIN, 0};
        int result = poll(&pollfd, 1, 5000);
        struct signalfd_siginfo info;
        int received = result > 0 && read(fd, &info, sizeof(info)) == sizeof(info) && info.ssi_signo == SIGINT;
        close(fd);
        return received ? PAM_AUTHINFO_UNAVAIL : PAM_AUTH_ERR;
    }
    char *password = NULL;
    int result = pam_prompt(pamh, PAM_PROMPT_ECHO_OFF, &password, "Password:");
    int matched = result == PAM_SUCCESS && password && strcmp(password, "correct-fixture-password") == 0;
    free(password);
    return matched ? PAM_SUCCESS : PAM_AUTH_ERR;
}
PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    (void)pamh; (void)flags; (void)argc; (void)argv; return PAM_IGNORE;
}
#else
static const char *answer;
static int conversation(int count, const struct pam_message **messages, struct pam_response **responses, void *data) {
    (void)data;
    struct pam_response *result = calloc((size_t)count, sizeof(*result));
    if (!result) return PAM_BUF_ERR;
    for (int i = 0; i < count; i++) {
        if (messages[i]->msg_style == PAM_PROMPT_ECHO_OFF) {
            puts("password");
            result[i].resp = strdup(answer);
        } else if (messages[i]->msg_style == PAM_TEXT_INFO) {
            puts(messages[i]->msg);
        }
    }
    *responses = result;
    return PAM_SUCCESS;
}

static int worker(const char *directory, const char *password, int unblocked) {
    setvbuf(stdout, NULL, _IONBF, 0);
    if (unblocked) { puts("fingerprint"); for (;;) pause(); }
    answer = password;
    struct pam_conv conv = {conversation, NULL};
    pam_handle_t *pamh = NULL;
    int result = pam_start_confdir("polkit-1", "fixture-user", &conv, directory, &pamh);
    if (result != PAM_SUCCESS) return 10;
    result = pam_authenticate(pamh, 0);
    pam_end(pamh, result);
    sigset_t current;
    sigprocmask(SIG_BLOCK, NULL, &current);
    if (sigismember(&current, SIGINT)) return 11;
    return result == PAM_SUCCESS ? 0 : 12;
}

static pid_t start(const char *self, const char *directory, const char *password, int unblocked, int *output) {
    int pipefd[2];
    if (pipe(pipefd) < 0) exit(30);
    pid_t pid = fork();
    if (pid == 0) {
        dup2(pipefd[1], STDOUT_FILENO); close(pipefd[0]); close(pipefd[1]);
        execl(self, self, "worker", directory, password, unblocked ? "1" : "0", NULL);
        _exit(31);
    }
    close(pipefd[1]); *output = pipefd[0];
    struct pollfd ready = {*output, POLLIN, 0};
    char message[64] = {0};
    if (poll(&ready, 1, 5000) <= 0 || read(*output, message, sizeof(message)-1) <= 0 || strcmp(message, "fingerprint\n") != 0) {
        fprintf(stderr, "Worker did not reach fingerprint scan: %s\n", message); exit(32);
    }
    return pid;
}

static int finish(pid_t pid) {
    int status;
    if (waitpid(pid, &status, 0) != pid || !WIFEXITED(status)) return 99;
    return WEXITSTATUS(status);
}

static int interrupt(const char *helper, int wrong_parent) {
    pid_t pid = fork();
    if (pid == 0) {
        if (wrong_parent) _exit(interrupt(helper, 0));
        execl(helper, helper, NULL); _exit(33);
    }
    return finish(pid);
}

int main(int argc, char **argv) {
    if (argc == 5 && strcmp(argv[1], "worker") == 0) return worker(argv[2], argv[3], atoi(argv[4]));
    if (argc != 4) return 64;
    const char *self = argv[1], *directory = argv[2], *helper = argv[3];
    int output;
    pid_t pid = start(self, directory, "correct-fixture-password", 0, &output);
    if (interrupt(helper, 1) == 0) { fputs("Wrong parent accepted\n", stderr); return 1; }
    if (interrupt(helper, 0) != 0) return 2;
    char message[64] = {0};
    if (read(output, message, sizeof(message)-1) <= 0 || strcmp(message, "password\n") != 0) return 3;
    close(output);
    if (finish(pid) != 0) return 4;
    pid = start(self, directory, "wrong-fixture-password", 0, &output);
    if (interrupt(helper, 0) != 0 || finish(pid) != 12) return 5;
    close(output);
    pid = start(self, directory, "unused", 1, &output);
    if (interrupt(helper, 0) == 0) return 6;
    kill(pid, SIGTERM); waitpid(pid, NULL, 0); close(output);
    int output2;
    pid = start(self, directory, "unused", 0, &output);
    pid_t pid2 = start(self, directory, "unused", 0, &output2);
    if (interrupt(helper, 0) == 0) return 7;
    kill(pid, SIGTERM); kill(pid2, SIGTERM);
    waitpid(pid, NULL, 0); waitpid(pid2, NULL, 0); close(output); close(output2);
    puts("PASS: same PAM conversation reaches password, wrong password denied, signal mask restored; wrong parent, unblocked and ambiguous helpers rejected");
    return 0;
}
#endif
