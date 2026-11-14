#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <sys/user.h>

static void log_open(pid_t pid, struct user_regs* r, long ret) {
    char path[256]; size_t i = 0;
    for (; i < 250; i += 4) {
        errno = 0;
        long w = ptrace(PTRACE_PEEKDATA, pid, (void*)(r->uregs[0] + i), 0);
        if (errno) break;
        memcpy(path + i, &w, 4);
        if (!memchr(path + i, 0, 4)) continue;
        break;
    }
    path[i + 3 < 250 ? i + 3 : 250] = 0;
    printf("open(\"%s\") = %ld flags=%#lx\n", path, ret, r->uregs[1]);
}

int main(int argc, char** argv) {
    pid_t pid = fork();
    if (pid == 0) { ptrace(PTRACE_TRACEME,0,0,0); execv(argv[1], &argv[1]); _exit(127); }
    int inSys = 0; struct user_regs r; unsigned long nr = 0; int count = 0;
    int first = 1;
    while (1) {
        int st; waitpid(pid, &st, 0);
        if (WIFEXITED(st) || WIFSIGNALED(st)) { printf("=== gone status=%x syscalls=%d\n", st, count); break; }
        int sig = WSTOPSIG(st);
        if (first) { first = 0; ptrace(PTRACE_SETOPTIONS, pid, 0, PTRACE_O_TRACESYSGOOD); ptrace(PTRACE_SYSCALL, pid, 0, 0); continue; }
        if (sig == (SIGTRAP | 0x80)) {
            if (ptrace(PTRACE_GETREGS, pid, 0, &r) == 0) {
                if (!inSys) { nr = r.uregs[7]; inSys = 1; }
                else {
                    long ret = r.uregs[0];
                    if (nr == 5 || nr == 322) { // open / openat
                        if (nr == 322) { r.uregs[0] = r.uregs[1]; }
                        struct user_regs rr = r; log_open(pid, &rr, ret);
                    } else if (nr == 54) { // ioctl
                        printf("ioctl(fd=%ld, req=%#lx, arg=%#lx) = %ld\n",
                            (long)r.uregs[0], (unsigned long)r.uregs[1],
                            (unsigned long)r.uregs[2], ret);
                    } else if (ret < 0 && ret > -4096 && (nr == 192 || nr == 0 || nr == 1)) {
                        printf("syscall(%lu) = %ld\n", nr, ret);
                    }
                    inSys = 0; count++;
                }
            }
            ptrace(PTRACE_SYSCALL, pid, 0, 0);
            continue;
        }
        if (sig == SIGSEGV || sig == SIGFPE || sig == SIGILL || sig == SIGABRT || sig == SIGBUS) {
            ptrace(PTRACE_GETREGS, pid, 0, &r);
            printf("=== CRASH sig=%d pc=%08lx lr=%08lx\n", sig,
                (unsigned long)r.uregs[15], (unsigned long)r.uregs[14]);
            kill(pid, 9); break;
        }
        ptrace(PTRACE_SYSCALL, pid, 0, sig == SIGTRAP ? 0 : sig);
    }
    return 0;
}
