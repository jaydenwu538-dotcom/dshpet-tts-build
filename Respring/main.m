// dshpet-respring —— 由 deb 的 postinst 安装为 setuid 二进制，
// 这样安装器 App（以 mobile 身份运行）也能重启 SpringBoard。
#import <Foundation/Foundation.h>
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>

extern char **environ;

static int run(const char *path, char *const argv[]) {
    if (access(path, X_OK) != 0) return -1;
    pid_t pid = 0;
    int rc = posix_spawn(&pid, path, NULL, NULL, argv, environ);
    if (rc != 0) return rc;
    int status = 0;
    waitpid(pid, &status, 0);
    return status;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);

        char *sbreload_jb[] = { (char *)"/var/jb/usr/bin/sbreload", NULL };
        char *sbreload_sys[] = { (char *)"/usr/bin/sbreload", NULL };
        char *kill_jb[] = { (char *)"/var/jb/usr/bin/killall", (char *)"-9", (char *)"SpringBoard", NULL };
        char *kill_sys[] = { (char *)"/usr/bin/killall", (char *)"-9", (char *)"SpringBoard", NULL };

        if (access("/var/jb/usr/bin/sbreload", X_OK) == 0) {
            printf("using /var/jb/usr/bin/sbreload\n");
            run(sbreload_jb[0], sbreload_jb);
            return 0;
        }
        if (access("/usr/bin/sbreload", X_OK) == 0) {
            printf("using /usr/bin/sbreload\n");
            run(sbreload_sys[0], sbreload_sys);
            return 0;
        }
        if (access("/var/jb/usr/bin/killall", X_OK) == 0) {
            printf("using /var/jb/usr/bin/killall\n");
            run(kill_jb[0], kill_jb);
            return 0;
        }
        if (access("/usr/bin/killall", X_OK) == 0) {
            printf("using /usr/bin/killall\n");
            run(kill_sys[0], kill_sys);
            return 0;
        }
        fprintf(stderr, "no respring tool found\n");
        return 1;
    }
}
