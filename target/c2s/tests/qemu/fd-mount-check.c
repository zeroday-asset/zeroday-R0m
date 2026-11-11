// SPDX-License-Identifier: GPL-2.0
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/vfs.h>

int main(int argc, char **argv)
{
    char path[128], line[4096];
    long id = -1, candidate;
    int found = 0;
    struct statfs info;
    if (argc != 2) return 2;
    int fd = open(argv[1], O_RDONLY);
    if (fd < 0 || fstatfs(fd, &info)) { perror("open/statfs"); return 1; }
    if (info.f_type != 0x01021994) { fprintf(stderr, "expected tmpfs\n"); return 1; }
    snprintf(path, sizeof(path), "/proc/self/fdinfo/%d", fd);
    FILE *fp = fopen(path, "r");
    if (!fp) return 1;
    while (fgets(line, sizeof(line), fp))
        if (sscanf(line, "mnt_id:\t%ld", &candidate) == 1) id = candidate;
    fclose(fp);
    fp = fopen("/proc/self/mountinfo", "r");
    if (!fp) return 1;
    while (fgets(line, sizeof(line), fp))
        if (sscanf(line, "%ld", &candidate) == 1 && candidate == id) found = 1;
    fclose(fp);
    close(fd);
    if (!found) { fprintf(stderr, "fd mount ID %ld missing from mountinfo\n", id); return 1; }
    printf("PASS: actual fdinfo/mountinfo/statfs consistency, mount ID %ld\n", id);
    return 0;
}
