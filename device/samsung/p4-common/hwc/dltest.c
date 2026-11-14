/* dltest2 — решающий дискриминатор GL-инстансов:
 * 1) EGL init через фреймворк-путь (как реальное приложение)
 * 2) dlopen flat glv2tegra.so (path) -> dlsym glGetString -> ЗОВЁМ
 * 3) dlopen egl-blob (cad9cea8 soname=glv2tegra) по ДРУГОМУ пути -> тот же handle?
 * 4) tegra eglGetProcAddress("glGetString") -> что возвращает
 */
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

typedef void *EGLDisplay;
typedef void *EGLSurface;
typedef void *EGLContext;
typedef void *EGLConfig;
typedef void *EGLNativeDisplayType;

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);

    /* 1. фреймворк EGL (как приложение) */
    void *egl = dlopen("libEGL.so", RTLD_NOW);
    printf("libEGL.so: %p\n", egl);
    if (!egl) { printf("  err: %s\n", dlerror()); return 1; }
    EGLDisplay (*pGetDisplay)(void *) = dlsym(egl, "eglGetDisplay");
    unsigned (*pInitialize)(void *, int *, int *) = dlsym(egl, "eglInitialize");
    void *(*pGPA)(const char *) = dlsym(egl, "eglGetProcAddress");
    if (!pGetDisplay || !pInitialize) { printf("no egl syms\n"); return 1; }
    EGLDisplay d = pGetDisplay((void *)0);
    int ma = 0, mi = 0;
    unsigned ok = pInitialize(d, &ma, &mi);
    printf("eglInitialize: %u (%d.%d)\n", ok, ma, mi);

    /* 2. flat-экземпляр: вооружён? */
    void *flat = dlopen("/system/lib/glv2tegra.so", RTLD_NOW | RTLD_LOCAL);
    printf("flat glv2tegra.so: %p\n", flat);
    if (!flat) { printf("  err: %s\n", dlerror()); return 1; }
    const unsigned char *(*fgs)(unsigned) = dlsym(flat, "glGetString");
    printf("flat glGetString: %p -> '%s'\n", fgs, fgs ? (const char *)fgs(1 /*GL_VENDOR*/) : "(null)");

    /* 3. path-dlopen другого файла с soname glv2tegra.so: дедуп? */
    void *b = dlopen("/system/lib/egl/libGLESv2_tegra.so.va1bak", RTLD_NOW | RTLD_LOCAL);
    printf("egl-blob (soname glv2tegra): %p %s\n", b, (b == flat) ? "== flat (PATH-DEDUP by soname!)" : "!= flat (отдельный экземпляр)");
    if (b && b != flat) {
        const unsigned char *(*bgs)(unsigned) = dlsym(b, "glGetString");
        printf("egl-blob glGetString -> '%s'\n", bgs ? (const char *)bgs(1) : "(null)");
    }

    /* 4. tegra gpa на core-функцию */
    void *tegl = dlopen("/system/lib/egl/libEGL_tegra.so", RTLD_NOW | RTLD_LOCAL);
    printf("tegra EGL: %p%s\n", tegl, (tegl && egl && tegl == *(void **)&egl) ? "" : "");
    if (tegl) {
        void *(*tgpa)(const char *) = dlsym(tegl, "eglGetProcAddress");
        void *p = tgpa ? tgpa("glGetString") : NULL;
        printf("tegra eglGetProcAddress(glGetString): %p\n", p);
        if (p) {
            const unsigned char *(*pg)(unsigned) = p;
            printf("  -> '%s'\n", pg(1));
        }
    }

    /* 5. NvGl2Init в flat: звался/чем отвечает? */
    int (*n2)(unsigned long, unsigned long, unsigned long, unsigned long) = dlsym(flat, "NvGl2Init");
    printf("flat NvGl2Init: %p\n", (void *)n2);

    printf("DLTEST2-DONE\n");
    return 0;
}
