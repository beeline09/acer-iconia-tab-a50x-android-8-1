#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <sys/user.h>
#include <sys/types.h>
#include <fcntl.h>
#include <signal.h>

int main(int argc, char** argv) {
    pid_t pid = fork();
    if (pid == 0) {
        ptrace(PTRACE_TRACEME, 0, 0, 0);
        execv(argv[1], &argv[1]);
        _exit(127);
    }
    int status;
    while (1) {
        waitpid(pid, &status, 0);
        if (WIFEXITED(status) || WIFSIGNALED(status)) {
            printf("child gone: %x\n", status);
            break;
        }
        int sig = WSTOPSIG(status);
        if (sig == SIGSEGV || sig == SIGFPE || sig == SIGILL || sig == SIGABRT || sig == SIGBUS) {
            sig = WSTOPSIG(status);
            struct user_regs regs;
            memset(&regs, 0, sizeof(regs));
            ptrace(PTRACE_GETREGS, pid, 0, &regs);
            printf("CRASH sig=%d\n", sig);
            printf("pc=%08lx lr=%08lx sp=%08lx ip=%08lx\n",
                (unsigned long)regs.uregs[15], (unsigned long)regs.uregs[14],
                (unsigned long)regs.uregs[13], (unsigned long)regs.uregs[12]);
            for (int i = 0; i < 10; i++)
                printf("r%d=%08lx ", i, (unsigned long)regs.uregs[i]);
            printf("\n");
            // карта модулей
            char path[64]; snprintf(path, sizeof(path), "/proc/%d/maps", pid);
            FILE* f = fopen(path, "r");
            if (f) {
                char line[512];
                printf("=== MAPS (исполняемые) ===\n");
                while (fgets(line, sizeof(line), f)) {
                    if (strstr(line, "r-xp"))
                        printf("%s", line);
                }
                fclose(f);
            }
            // стек: слова, попадающие в исполняемые сегменты (кандидаты backtrace)
            printf("=== STACK (первые 96 слов) ===\n");
            for (int i = 0; i < 96; i++) {
                errno = 0;
                long w = ptrace(PTRACE_PEEKDATA, pid, (void*)(regs.uregs[13] + i*4), 0);
                if (errno) break;
                if ((w & 0xffff0000) == 0xb6000000 || (w & 0xff000000) == 0x7f000000 || ((unsigned)w > 0xb6000000 && (unsigned)w < 0xf0000000))
                    printf("sp+%03d: %08lx\n", i*4, w);
            }
            kill(pid, 9);
            break;
        }
        ptrace(PTRACE_CONT, pid, 0, sig == SIGTRAP ? 0 : sig);
    }
    return 0;
}
