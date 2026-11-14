// setfcaps file — выставить security.capability v2 (permitted_lo из argv[2])
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/xattr.h>
int main(int argc, char **argv) {
    if (argc < 3) { printf("usage: setfcaps FILE PERM_HEX(e.g. 3000)\n"); return 1; }
    unsigned perm = strtoul(argv[2], 0, 16);
    unsigned char v[16];
    memset(v, 0, sizeof v);
    unsigned magic = 0x02000002 | 1; /* VFS_CAP_REVISION_2 | VFS_CAP_FLAGS_EFFECTIVE */
    memcpy(v, &magic, 4);
    memcpy(v + 4, &perm, 4);     /* permitted low */
    /* inheritable остаются 0 → effective = permitted при exec */
    int rc = setxattr(argv[1], "security.capability", v, sizeof v, 0);
    printf("setxattr(%s) = %d\n", argv[1], rc);
    if (rc) perror("setxattr");
    return rc ? 2 : 0;
}
