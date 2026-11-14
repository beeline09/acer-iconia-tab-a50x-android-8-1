// gltest2.c — допрос EGL/GLES: A (мета-слой), B (прямой tegra), C (почему хуки пустые)
// Запуск: gltest2b a | b | c1 | c2   (c1: без предзагрузки glv2, c2: с предзагрузкой до eglInitialize)
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dlfcn.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <bionic_tls.h>

typedef void* (*pfn_glGetString)(unsigned);
typedef void  (*pfn_glGetIntegerv)(unsigned, int*);

static void where(const char *tag, void *p) {
    Dl_info info;
    if (!p) { printf("  %s: NULL\n", tag); return; }
    if (dladdr(p, &info) && info.dli_fname) {
        const char *base = strrchr(info.dli_fname, '/');
        base = base ? base + 1 : info.dli_fname;
        printf("  %s: %p → %s", tag, p, base);
        if (info.dli_sname) printf(" [%s]", info.dli_sname);
        printf("\n");
    } else {
        printf("  %s: %p → (dladdr не знает)\n", tag, p);
    }
}

/* ---------- карты: показать маппинги glv ---------- */
static void dump_maps(const char *tag) {
    printf("[maps %s] строки с glv2tegra / libGLESv2_tegra / libGLESv1:\n", tag);
    FILE *f = fopen("/proc/self/maps", "r");
    if (!f) { printf("  /proc/self/maps не открыт\n"); return; }
    char line[512]; int n = 0;
    while (fgets(line, sizeof line, f)) {
        if (strstr(line, "glv2tegra") || strstr(line, "libGLESv2_tegra") || strstr(line, "libGLESv1_CM_tegra") || strstr(line, "glv1tegra")) {
            line[strcspn(line, "\n")] = 0;
            printf("  %s\n", line);
            n++;
        }
    }
    fclose(f);
    printf("  всего строк: %d\n", n);
}

/* ---------- гистограмма хуков ----------
 * sizeof(gl_hooks_t) из hooks.h дерева: 897 GL_ENTRY + MAX_NUMBER_OF_GL_EXTENSIONS(8) = 905 слов */
#define HOOK_WORDS 905
static void dump_hooks(const char *tag, void *h1, void *h2) {
    void **tls = (void**)__get_tls();
    void *hooks = tls[TLS_SLOT_OPENGL_API];
    printf("[hooks %s] TLS_SLOT_OPENGL_API(%d) = %p\n", tag, TLS_SLOT_OPENGL_API, hooks);
    if (!hooks) { printf("  хук-таблица NULL → стоял бы глюк «no context»\n"); return; }
    /* гистограмма по библиотекам */
    #define MAXB 24
    char *bn[MAXB]; int bc[MAXB]; int nb = 0;
    char *bn_null = 0; int bc_null = 0;
    for (int i = 0; i < HOOK_WORDS; i++) {
        void *p = ((void**)hooks)[i];
        Dl_info info;
        if (!p || !dladdr(p, &info) || !info.dli_fname) { bc_null++; continue; }
        const char *b = strrchr(info.dli_fname, '/');
        b = b ? b+1 : info.dli_fname;
        int k = -1;
        for (int j = 0; j < nb; j++) if (!strcmp(bn[j], b)) { k = j; break; }
        if (k < 0 && nb < MAXB) { bn[nb] = strdup(b); bc[nb] = 0; k = nb++; }
        if (k >= 0) bc[k]++;
        else bc_null++;
    }
    printf("  гистограмма первых %d слов хук-таблицы:\n", HOOK_WORDS);
    for (int j = 0; j < nb; j++) printf("    %-28s %3d указ.\n", bn[j], bc[j]);
    printf("    %-28s %3d указ.\n", "(NULL/не-resolv)", bc_null);
    /* три ключевых символа */
    struct { const char *name; } keys[] = { {"glGetString"},{"glGetIntegerv"},{"glClear"} };
    for (unsigned q = 0; q < 3; q++) {
        void *s1 = h1 ? dlsym(h1, keys[q].name) : 0;
        void *s2 = h2 ? dlsym(h2, keys[q].name) : 0;
        printf("  %s: dlsym(h1=egl/GLESv2_tegra)=%p dlsym(h2=glv2tegra)=%p %s\n",
               keys[q].name, s1, s2, (s1&&s2&&(s1!=s2))?"← РАЗНЫЕ!":((s1&&s2)?"равны":"-"));
        /* найден ли в таблице хуков */
        int idx = -1;
        for (int i = 0; i < HOOK_WORDS; i++)
            if (((void**)hooks)[i] && (((void**)hooks)[i]==s1 || ((void**)hooks)[i]==s2)) { idx = i; break; }
        printf("    в хук-таблице: %s\n", idx>=0 ? "ДА (индекс выше)" : "НЕТ");
    }
}

/* ---------- шаги 1 (h1/h2 + dlsym) ---------- */
static void step_handles(void **h1p, void **h2p) {
    dlerror();
    void *h1 = dlopen("/system/lib/egl/libGLESv2_tegra.so", RTLD_NOW|RTLD_LOCAL);
    char *e1 = dlerror();
    dlerror();
    void *h2 = dlopen("/system/lib/glv2tegra.so", RTLD_NOW|RTLD_LOCAL);
    char *e2 = dlerror();
    printf("[handles] h1(egl/libGLESv2_tegra.so)=%p err=%s\n", h1, e1?e1:"-");
    printf("[handles] h2(glv2tegra.so)         =%p err=%s\n", h2, e2?e2:"-");
    printf("[handles] h1 == h2 ? %s\n", h1==h2 ? "ДА (один образ)" : "НЕТ (ДВА разных образа!)");
    const char *syms[] = {"glGetString","glGetIntegerv","glClear","glDrawArrays","glTexImage2D"};
    for (unsigned i = 0; i < 5; i++) {
        void *a = h1 ? dlsym(h1, syms[i]) : 0;
        void *b = h2 ? dlsym(h2, syms[i]) : 0;
        printf("  dlsym %-14s h1=%p h2=%p %s\n", syms[i], a, b, (a&&b&&a!=b)?"← РАЗНЫЕ":((a&&b)?"равны":((!a&&!b)?"оба NULL":"один NULL")));
    }
    *h1p = h1; *h2p = h2;
}

/* ---------- режим C: полный A-путь + диагностика ---------- */
static int mode_c(int preload) {
    printf("=== РЕЖИМ C%s ===\n", preload?"2 (с предзагрузкой glv2tegra.so до eglInitialize)":"1 (без предзагрузки)");
    void *pre = 0;
    if (preload) {
        pre = dlopen("/system/lib/glv2tegra.so", RTLD_NOW|RTLD_LOCAL);
        printf("предзагрузка glv2tegra.so = %p\n", pre);
    }
    /* A-путь как есть */
    EGLDisplay dpy = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    printf("eglGetDisplay=%p\n", (void*)dpy);
    EGLint ma=0,mi=0;
    if (!eglInitialize(dpy,&ma,&mi)) { printf("eglInitialize FAIL\n"); return 1; }
    printf("eglInitialize %d.%d\n", ma, mi);
    const EGLint cfg_attr[] = { EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
                                EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_NONE };
    EGLConfig cfgs[32]; EGLint n=0;
    eglChooseConfig(dpy,cfg_attr,cfgs,32,&n);
    const EGLint pb[] = { EGL_WIDTH,64,EGL_HEIGHT,64,EGL_NONE };
    EGLSurface s = eglCreatePbufferSurface(dpy,cfgs[0],pb);
    const EGLint ca[] = { EGL_CONTEXT_CLIENT_VERSION,2,EGL_NONE };
    EGLContext c = eglCreateContext(dpy,cfgs[0],EGL_NO_CONTEXT,ca);
    EGLBoolean ok = eglMakeCurrent(dpy,s,s,c);
    printf("makeCurrent=%d ctx=%p surf=%p\n", ok, (void*)c, (void*)s);
    dump_maps(preload?"C2":"C1");
    void *h1=0,*h2=0;
    step_handles(&h1,&h2);
    dump_hooks(preload?"C2":"C1", h1, h2);
    pfn_glGetString gs = (pfn_glGetString)dlsym(RTLD_DEFAULT, "glGetString");
    printf("контрольный вызов glGetString(GL_VENDOR) = %s\n",
           gs ? (const char*)gs(GL_VENDOR) : "(функция NULL)");
    return 0;
}

/* ---------- ранее: режим A ---------- */
static int mode_a(void) {
    printf("=== РЕЖИМ A: мета-слой ===\n");
    EGLDisplay dpy = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    printf("eglGetDisplay(DEFAULT) = %p, eglGetError=0x%x\n", (void*)dpy, eglGetError());
    if (!dpy) return 1;
    EGLint ma=0, mi=0;
    EGLBoolean ok = eglInitialize(dpy, &ma, &mi);
    printf("eglInitialize = %d (%d.%d), err=0x%x\n", ok, ma, mi, eglGetError());
    const EGLint cfg_attr[] = { EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
                                EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_NONE };
    EGLConfig cfgs[32]; EGLint n=0;
    ok = eglChooseConfig(dpy, cfg_attr, cfgs, 32, &n);
    printf("eglChooseConfig = %d, count=%d, err=0x%x\n", ok, n, eglGetError());
    if (!ok || n < 1) return 2;
    const EGLint pb_attr[] = { EGL_WIDTH, 64, EGL_HEIGHT, 64, EGL_NONE };
    EGLSurface surf = eglCreatePbufferSurface(dpy, cfgs[0], pb_attr);
    printf("eglCreatePbufferSurface(64x64) = ДЕСКРИПТОР %p, err=0x%x\n", (void*)surf, eglGetError());
    const EGLint ctx_attr[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
    EGLContext ctx = eglCreateContext(dpy, cfgs[0], EGL_NO_CONTEXT, ctx_attr);
    printf("eglCreateContext = ДЕСКРИПТОР %p, err=0x%x\n", (void*)ctx, eglGetError());
    if (!ctx) return 3;
    ok = eglMakeCurrent(dpy, surf, surf, ctx);
    printf("eglMakeCurrent = %d, err=0x%x\n", ok, eglGetError());
    printf("eglGetCurrentContext = %p\n", (void*)eglGetCurrentContext());
    where("glGetString (символ бинаря)", (void*)glGetString);
    where("glGetIntegerv(символ бинаря)", (void*)glGetIntegerv);
    printf("GL_VENDOR=%s GL_RENDERER=%s\n",(const char*)glGetString(GL_VENDOR),(const char*)glGetString(GL_RENDERER));
    return 0;
}

/* ---------- ранее: режим B ---------- */
typedef EGLBoolean (*pf_initialize)(EGLDisplay, EGLint*, EGLint*);
typedef EGLBoolean (*pf_chooseConfig)(EGLDisplay, const EGLint*, EGLConfig*, EGLint, EGLint*);
typedef EGLSurface (*pf_createPbuffer)(EGLDisplay, EGLConfig, const EGLint*);
typedef EGLContext (*pf_createContext)(EGLDisplay, EGLConfig, EGLContext, const EGLint*);
typedef EGLBoolean (*pf_makeCurrent)(EGLDisplay, EGLSurface, EGLSurface, EGLContext);
typedef void*     (*pf_getProcAddress)(const char*);

static int mode_b(void) {
    printf("=== РЕЖИМ B: dlopen tegra-EGL напрямую ===\n");
    void *drv = dlopen("/system/lib/egl/libEGL_tegra.so", RTLD_NOW | RTLD_LOCAL);
    printf("dlopen(libEGL_tegra.so) = %p\n", drv);
    if (!drv) return 1;
    EGLDisplay (*f_getDisplay)(void*) = (EGLDisplay(*)(void*))dlsym(drv,"eglGetDisplay");
    pf_initialize f_init = (pf_initialize)dlsym(drv,"eglInitialize");
    pf_chooseConfig f_choose = (pf_chooseConfig)dlsym(drv,"eglChooseConfig");
    pf_createPbuffer f_pb = (pf_createPbuffer)dlsym(drv,"eglCreatePbufferSurface");
    pf_createContext f_ctx = (pf_createContext)dlsym(drv,"eglCreateContext");
    pf_makeCurrent f_mc = (pf_makeCurrent)dlsym(drv,"eglMakeCurrent");
    pf_getProcAddress f_gpa = (pf_getProcAddress)dlsym(drv,"eglGetProcAddress");
    EGLDisplay dpy = f_getDisplay((void*)EGL_DEFAULT_DISPLAY);
    EGLint ma=0,mi=0;
    f_init(dpy,&ma,&mi);
    printf("tegra init %d.%d\n", ma, mi);
    const EGLint cfg_attr[] = { EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
                                EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_NONE };
    EGLConfig cfgs[32]; EGLint n=0;
    f_choose(dpy,cfg_attr,cfgs,32,&n);
    const EGLint pb[] = { EGL_WIDTH,64,EGL_HEIGHT,64,EGL_NONE };
    EGLSurface s = f_pb(dpy,cfgs[0],pb);
    const EGLint ca[] = { EGL_CONTEXT_CLIENT_VERSION,2,EGL_NONE };
    EGLContext c = f_ctx(dpy,cfgs[0],EGL_NO_CONTEXT,ca);
    printf("tegra: surf=%p ctx=%p\n",(void*)s,(void*)c);
    f_mc(dpy,s,s,c);
    printf("tegra makeCurrent=%d\n", f_mc(dpy,s,s,c));
    void *glv2 = dlopen("/system/lib/glv2tegra.so", RTLD_NOW|RTLD_LOCAL);
    pfn_glGetString g2 = (pfn_glGetString)dlsym(glv2,"glGetString");
    printf("GL_VENDOR(через glv2)=%s\n",(const char*)g2(GL_VENDOR));
    printf("gpa(glGetString)=%p\n", f_gpa?(void*)f_gpa("glGetString"):0);
    return 0;
}

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IONBF, 0);
    const char *m = argc > 1 ? argv[1] : "a";
    if (!strcmp(m,"a")) return mode_a();
    if (!strcmp(m,"b")) return mode_b();
    if (!strcmp(m,"c1")) return mode_c(0);
    if (!strcmp(m,"c2")) return mode_c(1);
    printf("использование: %s a|b|c1|c2\n", argv[0]);
    return 64;
}
