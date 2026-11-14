// gltest.c — прямой допрос EGL/GLES драйвера: строки + glGetIntegerv
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <dlfcn.h>

int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
    printf("=== gltest ===\n");
    EGLDisplay dpy = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    printf("display=%p\n", dpy);
    EGLint maj=0, min=0;
    if (!eglInitialize(dpy, &maj, &min)) { printf("eglInitialize FAIL 0x%x\n", eglGetError()); return 1; }
    printf("eglInitialize %d.%d\n", maj, min);
    printf("vendor: %s\n", eglQueryString(dpy, EGL_VENDOR));
    printf("version: %s\n", eglQueryString(dpy, EGL_VERSION));
    printf("extensions: %.120s...\n", eglQueryString(dpy, EGL_EXTENSIONS));

    const EGLint cfg_attr[] = {
        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 0,
        EGL_NONE };
    EGLConfig cfg[16]; EGLint n=0;
    if (!eglChooseConfig(dpy, cfg_attr, cfg, 16, &n) || n==0) { printf("eglChooseConfig ES2 FAIL n=%d err=0x%x\n", n, eglGetError()); return 2; }
    printf("configs=%d (первый id=%d)\n", n, 0);
    // печатаем ключевые атрибуты первой конфигурации
    EGLint val=0;
    eglGetConfigAttrib(dpy, cfg[0], EGL_CONFIG_ID, &val); printf("  cfg id=%d\n", val);
    eglGetConfigAttrib(dpy, cfg[0], EGL_NATIVE_VISUAL_ID, &val); printf("  native_visual_id=%d\n", val);

    const EGLint ctx_attr[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
    EGLContext ctx = eglCreateContext(dpy, cfg[0], EGL_NO_CONTEXT, ctx_attr);
    printf("ctx=%p err=0x%x\n", ctx, eglGetError());
    if (ctx == EGL_NO_CONTEXT) return 3;

    const EGLint pb_attr[] = { EGL_WIDTH, 32, EGL_HEIGHT, 32, EGL_NONE };
    EGLSurface surf = eglCreatePbufferSurface(dpy, cfg[0], pb_attr);
    printf("pbuf=%p err=0x%x\n", surf, eglGetError());
    if (!eglMakeCurrent(dpy, surf, surf, ctx)) { printf("makeCurrent FAIL 0x%x\n", eglGetError()); return 4; }

    printf("--- GL strings ---\n");
    printf("GL_VENDOR: %s\n", (const char*)glGetString(GL_VENDOR));
    printf("GL_RENDERER: %s\n", (const char*)glGetString(GL_RENDERER));
    printf("GL_VERSION: %s\n", (const char*)glGetString(GL_VERSION));
    printf("GL_SL_VERSION: %s\n", (const char*)glGetString(GL_SHADING_LANGUAGE_VERSION));
    printf("GL_ERROR after strings: 0x%x\n", glGetError());

    printf("--- GL ints ---\n");
    GLint v = -1;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &v);          printf("GL_MAX_TEXTURE_SIZE = %d (err 0x%x)\n", v, glGetError()); v=-1;
    glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, &v);   printf("GL_MAX_TEXTURE_IMAGE_UNITS = %d (err 0x%x)\n", v, glGetError()); v=-1;
    glGetIntegerv(GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS, &v); printf("GL_MAX_COMBINED_TEX_UNITS = %d (err 0x%x)\n", v, glGetError()); v=-1;
    glGetIntegerv(GL_MAX_VERTEX_ATTRIBS, &v);        printf("GL_MAX_VERTEX_ATTRIBS = %d (err 0x%x)\n", v, glGetError()); v=-1;
    GLint vp[4] = {-1,-1,-1,-1};
    glGetIntegerv(GL_MAX_VIEWPORT_DIMS, vp);         printf("GL_MAX_VIEWPORT_DIMS = %d x %d\n", vp[0], vp[1]);

    // маленький живой тест: создать текстуру
    GLuint tex = 0;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    unsigned char px[4] = {255, 0, 0, 255};
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, px);
    printf("texture create: id=%u err=0x%x\n", tex, glGetError());
    printf("=== GLTEST-DONE ===\n");
    return 0;
}
