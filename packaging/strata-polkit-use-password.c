/* SPDX-License-Identifier: MIT
 * Unprivileged: interrupt only our parent's own Polkit helper, and only when
 * SIGINT is blocked for pam_fprintd's signalfd. pidfds prevent PID reuse races.
 */
#define _GNU_SOURCE
#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <unistd.h>

#ifndef STRATA_POLKIT_HELPER
#define STRATA_POLKIT_HELPER "/usr/lib/polkit-1/polkit-agent-helper-1"
#endif

static bool eligible(pid_t pid, pid_t parent, uid_t owner) {
    char path[64], line[512];
    snprintf(path, sizeof(path), "/proc/%ld/status", (long)pid);
    FILE *file = fopen(path, "re");
    if (!file) return false;
    long ppid = -1;
    unsigned long uid = ULONG_MAX;
    unsigned long long blocked = 0;
    while (fgets(line, sizeof(line), file)) {
        if (strncmp(line, "PPid:", 5) == 0) (void)sscanf(line + 5, "%ld", &ppid);
        if (strncmp(line, "Uid:", 4) == 0) (void)sscanf(line + 4, "%lu", &uid);
        if (strncmp(line, "SigBlk:", 7) == 0) (void)sscanf(line + 7, "%llx", &blocked);
    }
    fclose(file);
    if (ppid != parent || uid != owner || !(blocked & (1ULL << (SIGINT - 1)))) return false;
    snprintf(path, sizeof(path), "/proc/%ld/cmdline", (long)pid);
    file = fopen(path, "re");
    if (!file) return false;
    char executable[PATH_MAX + 1];
    size_t size = fread(executable, 1, sizeof(executable) - 1, file);
    fclose(file);
    executable[size] = '\0';
    return size > strlen(STRATA_POLKIT_HELPER) && strcmp(executable, STRATA_POLKIT_HELPER) == 0;
}

int main(int argc, char **argv) {
    (void)argv;
    if (argc != 1) { fputs("This helper takes no arguments.\n", stderr); return 64; }
    const pid_t parent = getppid();
    const uid_t owner = getuid();
    if (parent <= 1) return 1;
    DIR *directory = opendir("/proc");
    if (!directory) return 1;
    int selected = -1;
    bool ambiguous = false;
    struct dirent *entry;
    while ((entry = readdir(directory))) {
        if (!isdigit((unsigned char)entry->d_name[0])) continue;
        char *end;
        long value = strtol(entry->d_name, &end, 10);
        if (*end || value <= 1 || value > INT_MAX) continue;
        int fd = (int)syscall(SYS_pidfd_open, (pid_t)value, 0);
        if (fd < 0) continue;
        if (!eligible((pid_t)value, parent, owner)) { close(fd); continue; }
        if (selected >= 0) { close(fd); ambiguous = true; break; }
        selected = fd;
    }
    closedir(directory);
    if (selected < 0 || ambiguous) {
        if (selected >= 0) close(selected);
        fputs("No unique interruptible Polkit fingerprint session was found.\n", stderr);
        return 1;
    }
    int result = (int)syscall(SYS_pidfd_send_signal, selected, SIGINT, NULL, 0);
    close(selected);
    if (result < 0) { perror("Could not stop fingerprint scan"); return 1; }
    return 0;
}
