// grtest2.c — тест fb_post: 2 буфера, чередуем, ищем зависание NvGrPost/NvGrLock
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <hardware/gralloc.h>
#include <hardware/fb.h>
#include <hardware/hardware.h>

static int iter = -1;
static void alarm_handler(int s) {
    printf("[ALARM] post #%d HANGS — дедлок воспроизведён в изоляции\n", iter);
    _exit(42);
}
static unsigned int bcount(buffer_handle_t h) {
    unsigned int st = ((unsigned int*)h)[0x80/4];
    if (st > 0x10000 && st != 0xFFFFFFFF) return ((unsigned int*)st)[0x3c/4];
    return 0xDEAD0000;
}
static int bfid(buffer_handle_t h) { return ((unsigned int*)h)[0x8/4]; }

int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
    const hw_module_t *mod;
    if (hw_get_module(GRALLOC_HARDWARE_MODULE_ID, &mod)) { printf("no gralloc\n"); return 1; }
    gralloc_module_t const *gr = (gralloc_module_t const *)mod;

    framebuffer_device_t *fb = NULL;
    int err = framebuffer_open(mod, &fb);
    printf("framebuffer_open=%d fb=%p %ux%u fps=%f fmt=%d\n", err, fb,
           fb?fb->width:0, fb?fb->height:0, fb?fb->fps:0, fb?fb->format:0);
    if (err || !fb) return 2;

    alloc_device_t *alloc = NULL;
    if (gralloc_open(mod, &alloc) || !alloc) { printf("gralloc_open fail\n"); return 3; }

    buffer_handle_t bufs[2] = {0,0};
    int stride = 0;
    int usage = GRALLOC_USAGE_HW_FB | GRALLOC_USAGE_HW_RENDER | GRALLOC_USAGE_HW_TEXTURE; // 0x1300
    for (int i = 0; i < 2; i++) {
        err = alloc->alloc(alloc, fb->width, fb->height, fb->format ? fb->format : HAL_PIXEL_FORMAT_RGBA_8888,
                           usage, &bufs[i], &stride);
        printf("alloc[%d]=%d id=0x%x stride=%d count=%d\n", i, err, bfid(bufs[i]), stride, bcount(bufs[i]));
        if (err) return 4;
        // залить цветом через SW lock
        void *v = NULL;
        int rc = gr->lock(gr, bufs[i], GRALLOC_USAGE_SW_WRITE_OFTEN, 0, 0, fb->width, fb->height, &v);
        if (rc == 0 && v) {
            memset(v, i ? 0xFF : 0x3C, (size_t)stride * fb->height * 4);
            gr->unlock(gr, bufs[i]);
            printf("fill[%d] ok count=%d\n", i, bcount(bufs[i]));
        } else printf("fill[%d] rc=%d v=%p\n", i, rc, v);
    }

    signal(SIGALRM, alarm_handler);
    for (iter = 0; iter < 20; iter++) {
        buffer_handle_t b = bufs[iter % 2];
        printf("post#%d buf=0x%x count_pre=%d ... ", iter, bfid(b), bcount(b));
        alarm(8);
        err = fb->post(fb, b);
        alarm(0);
        printf("ret=%d count_post=%d\n", err, bcount(b));
        if (err) { printf("post failed at %d\n", iter); break; }
        usleep(33000); // ~30fps как SF
    }
    printf(iter >= 20 ? "TEST2-DONE-OK (20 постов без зависания)\n" : "TEST2-STOPPED at %d\n", iter);
    return 0;
}
