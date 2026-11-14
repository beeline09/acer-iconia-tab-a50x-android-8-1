// grtest.c — изолированный тест tegra gralloc: alloc -> register -> lock(0x100)
// Печатает private_handle поля: +0xc (fd), +0x80 (state ptr), state+0x3c (count)
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <hardware/gralloc.h>
#include <hardware/hardware.h>

static void alarm_handler(int s) {
    printf("[ALARM] lock() HANGS (>10s) — дедлок воспроизведён в изоляции\n");
    _exit(42);
}

static void dump_handle(const char *tag, buffer_handle_t h) {
    unsigned int *p = (unsigned int *)h;
    printf("%s: handle=%p\n", tag, h);
    for (int i = 0; i < 0x30; i++) {
        unsigned int v = p[i];
        if (v || i==3 || i==48 || i==50) {
            printf("  [+0x%02x] = 0x%08x (%d)\n", i*4, v, (int)v);
        }
    }
    unsigned int state = p[0x80/4];
    if (state > 0x1000 && state != 0xFFFFFFFF) {
        unsigned int *sp = (unsigned int *)state;
        printf("  state=%#x count([state+0x3c])=%d (0x%x), mutex@+0x40=%08x %08x %08x %08x\n",
               state, (int)sp[0x3c/4], sp[0x3c/4],
               sp[0x40/4], sp[0x44/4], sp[0x48/4], sp[0x4c/4]);
    } else {
        printf("  state=INVALID (0x%08x)\n", state);
    }
}

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IONBF, 0);
    int usage_alloc = GRALLOC_USAGE_HW_RENDER | GRALLOC_USAGE_HW_TEXTURE; // 0x300
    int usage_lock = GRALLOC_USAGE_HW_TEXTURE; // 0x100 — как SF
    if (argc > 1) usage_lock = strtol(argv[1], 0, 0);
    if (argc > 2) usage_alloc = strtol(argv[2], 0, 0);

    const hw_module_t *mod;
    int err = hw_get_module(GRALLOC_HARDWARE_MODULE_ID, &mod);
    printf("hw_get_module(%s) = %d, module=%p id=%s name=%s\n",
           GRALLOC_HARDWARE_MODULE_ID, err, mod,
           mod ? mod->id : "?", mod ? mod->name : "?");
    if (err) return 1;

    alloc_device_t *alloc = NULL;
    err = gralloc_open((const hw_module_t*)mod, &alloc);
    printf("gralloc_open = %d, alloc=%p\n", err, alloc);
    if (err || !alloc) return 2;

    buffer_handle_t h = NULL;
    int stride = 0;
    printf("alloc(1280x800, fmt=1(RGBA), usage=0x%x)...\n", usage_alloc);
    err = alloc->alloc(alloc, 1280, 800, HAL_PIXEL_FORMAT_RGBA_8888,
                       usage_alloc, &h, &stride);
    printf("alloc = %d, handle=%p stride=%d\n", err, h, stride);
    if (err || !h) return 3;
    dump_handle("AFTER-ALLOC", h);

    gralloc_module_t const *gr = (gralloc_module_t const *)mod;
    err = gr->registerBuffer(gr, h);
    printf("registerBuffer = %d\n", err);
    dump_handle("AFTER-REGISTER", h);

    void *vaddr = NULL;
    signal(SIGALRM, alarm_handler);
    printf("lock(usage=0x%x) с будильником 10с...\n", usage_lock);
    alarm(10);
    err = gr->lock(gr, h, usage_lock, 0, 0, 1280, 800, &vaddr);
    alarm(0);
    printf("lock = %d vaddr=%p\n", err, vaddr);
    dump_handle("AFTER-LOCK", h);

    err = gr->unlock(gr, h);
    printf("unlock = %d\n", err);
    dump_handle("AFTER-UNLOCK", h);

    // второй lock — как SF делает на каждом кадре
    alarm(10);
    err = gr->lock(gr, h, usage_lock, 0, 0, 1280, 800, &vaddr);
    alarm(0);
    printf("lock2 = %d vaddr=%p\n", err, vaddr);
    err = gr->unlock(gr, h);
    printf("unlock2 = %d\n", err);
    printf("TEST-DONE-OK\n");
    return 0;
}
