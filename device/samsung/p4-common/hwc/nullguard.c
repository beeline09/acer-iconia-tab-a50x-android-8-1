#define _GNU_SOURCE
#include <string.h>
#include <stddef.h>
#include <dlfcn.h>

size_t __attribute__((overloadable)) strlen(const char* s) {
    static size_t (*real)(const char*);
    if (!real) real = dlsym(RTLD_NEXT, "strlen");
    if (!s) return 0;
    return real(s);
}
size_t __strlen_chk(const char* s, size_t n) {
    static size_t (*real)(const char*, size_t);
    if (!real) real = dlsym(RTLD_NEXT, "__strlen_chk");
    if (!s) return 0;
    return real ? real(s, n) : strlen(s);
}
int __attribute__((overloadable)) strcmp(const char* a, const char* b) {
    static int (*real)(const char*, const char*);
    if (!real) real = dlsym(RTLD_NEXT, "strcmp");
    if (!a || !b) return (a == b) ? 0 : (a ? 1 : -1);
    return real(a, b);
}
char* __attribute__((overloadable)) strcpy(char* d, const char* s) {
    static char* (*real)(char*, const char*);
    if (!real) real = dlsym(RTLD_NEXT, "strcpy");
    if (!d) return d;
    if (!s) { d[0] = 0; return d; }
    return real(d, s);
}
