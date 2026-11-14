/* Прямая анимация в /dev/graphics/fb0 — цветные полосы + бегущая волна */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <linux/fb.h>

int main() {
    int fd = open("/dev/graphics/fb0", O_RDWR);
    if (fd < 0) { perror("open fb0"); return 1; }

    struct fb_var_screeninfo vinfo;
    struct fb_fix_screeninfo finfo;
    ioctl(fd, FBIOGET_VSCREENINFO, &vinfo);
    ioctl(fd, FBIOGET_FSCREENINFO, &finfo);

    int w = vinfo.xres, h = vinfo.yres, bpp = vinfo.bits_per_pixel / 8;
    printf("fb0: %dx%d %dbpp line=%d\n", w, h, bpp * 8, (int)finfo.line_length);
    if (bpp != 4) { fprintf(stderr, "expected 32bpp, got %d\n", bpp); return 1; }

    size_t size = finfo.line_length * vinfo.yres_virtual;
    unsigned int *fb = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (fb == MAP_FAILED) { perror("mmap"); return 1; }

    int frame = 0;
    while (1) {
        for (int y = 0; y < h; y++) {
            unsigned int *row = fb + (y * finfo.line_length / 4);
            for (int x = 0; x < w; x++) {
                unsigned char r, g, b;
                if (y < h / 6) { r = 255; g = 0; b = 0; }
                else if (y < h * 2 / 6) { r = 0; g = 255; b = 0; }
                else if (y < h * 3 / 6) { r = 0; g = 0; b = 255; }
                else if (y < h * 4 / 6) { r = 255; g = 255; b = 0; }
                else if (y < h * 5 / 6) { r = 0; g = 255; b = 255; }
                else { r = 255; g = 0; b = 255; }
                /* бегущая волна яркости */
                int wave = (x + frame * 5) % (w / 2);
                int bright = wave < w / 4 ? 255 : 128;
                r = r * bright / 255; g = g * bright / 255; b = b * bright / 255;
                row[x] = (255 << 24) | (r << 16) | (g << 8) | b;
            }
        }
        frame++;
        usleep(16667); /* ~60fps */
    }
    return 0;
}
