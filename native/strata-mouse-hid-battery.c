// Query-only HID provider for Viper V3 Pro wired/wireless interfaces.
// Protocol reference: OpenRazer charge_level/charge_status and report layout.
// No configuration commands or kernel-driver changes are performed.
#define _DEFAULT_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/hidraw.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/file.h>
#include <sys/ioctl.h>
#include <unistd.h>

static int query(int fd, uint8_t command) {
  for (int attempt = 0; attempt < 3; attempt++) {
    uint8_t request[91] = {0};
    request[2] = 0x1f;
    request[6] = 2;
    request[7] = 7;
    request[8] = command;
    for (int i = 3; i <= 88; i++) request[89] ^= request[i];
    if (ioctl(fd, HIDIOCSFEATURE(sizeof request), request) < 0) return -1;
    usleep(30000);
    uint8_t response[91] = {0};
    if (ioctl(fd, HIDIOCGFEATURE(sizeof response), response) < 0) return -1;
    uint8_t checksum = 0;
    for (int i = 3; i <= 88; i++) checksum ^= response[i];
    if (response[1] == 2 && response[7] == 7 && response[8] == command &&
        checksum == response[89]) return response[10];
    usleep(30000);
  }
  return -1;
}

int main(int argc, char **argv) {
  if (argc != 2 || strncmp(argv[1], "/dev/hidraw", 11) != 0) return 2;
  alarm(3);
  int fd = open(argv[1], O_RDWR | O_CLOEXEC | O_NOFOLLOW);
  if (fd < 0) { perror("mouse battery"); return 1; }
  struct hidraw_devinfo info = {0};
  if (ioctl(fd, HIDIOCGRAWINFO, &info) < 0 || info.vendor != 0x1532 ||
      (info.product != 0x00c0 && info.product != 0x00c1)) {
    close(fd); return 2;
  }
  if (flock(fd, LOCK_EX | LOCK_NB) < 0) { close(fd); return 1; }
  int level = query(fd, 0x80);
  int charging = level < 0 ? -1 : query(fd, 0x84);
  close(fd);
  if (level < 0) return 1;
  printf("{\"percentage\":%d,\"charging\":%s}\n", (level * 100 + 127) / 255,
         charging < 0 ? "null" : charging ? "true" : "false");
  return 0;
}
