// Ugh, this is so sloppy
#include <stack>
#include <fcntl.h>
#include <stdio.h>
#include <dlfcn.h>
#include <stdarg.h>
#include <unistd.h>
#include <string.h>
#include <dirent.h>
#include <stdbool.h>
#include <pthread.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <objc/objc.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <mach-o/dyld.h>
#include <netinet/in.h>
#import  <Security/Security.h>
#import  <Security/SecCertificate.h>
#include <CFNetwork/CFNetwork.h>
#include <CFNetwork/CFProxySupport.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFStream.h>
#import <Foundation/NSJSONSerialization.h>
#include "iSpy.common.h"
#include "hooks_C_system_calls.h"
#include <dlfcn.h>
#include <mach-o/nlist.h>

static pthread_mutex_t mutex_mmap = PTHREAD_MUTEX_INITIALIZER;

//
// Pointers to original funcs
//
DIR * (*orig_opendir)(const char *dirname) = opendir;
struct dirent *(*orig_readdir)(DIR *dirp) = readdir;
int (*orig_readdir_r)(DIR *dirp, struct dirent *entry, struct dirent **result) = readdir_r;
ssize_t (*orig_recvfrom)(int socket, void *buffer, size_t length, int flags, struct sockaddr *address, socklen_t *address_len) = recvfrom;
ssize_t (*orig_recv)(int socket, void *buffer, size_t length, int flags) = recv;
int (*orig_ioctl)(int fildes, unsigned long request, ...) = ioctl;
int (*orig_open)(const char *fname, int oflag, ...) = open;
int (*orig_close)(int f) = close;
int (*orig_fstat)(int fildes, struct stat *buf) = fstat;
int (*orig_lstat)(const char *path, struct stat *buf) = lstat;
int (*orig_stat)(const char *path, struct stat *buf) = stat;
int (*orig_access)(const char *path, int amode) = access;
int (*orig_fork)(void) = fork;
int (*orig_statfs)(const char *path, struct statfs *buf) = statfs;
int (*orig_fstatfs)(int fd, struct statfs *buf) = fstatfs;
uint32_t (*orig_dyld_image_count)(void) = _dyld_image_count;
const char *(*orig_dyld_get_image_name)(uint32_t id) = _dyld_get_image_name;
int (*orig_connect)(int socket, const struct sockaddr *address, socklen_t address_len) = connect;
int (*orig_bind)(int socket, const struct sockaddr *address, socklen_t address_len) = bind;
int (*orig_accept)(int socket, struct sockaddr *address, socklen_t *address_len) = accept;
int (*orig_memcmp)(const void *s1, const void *s2, size_t n) = memcmp;
int (*orig_strcmp)(const char *s1, const char *s2) = strcmp;
int (*orig_strncmp)(const char *s1, const char *s2, size_t n) = strncmp;
int (*orig_sysctl)(int *name, u_int namelen, void *old, size_t *oldlenp, void *_new, size_t newlen);
int (*orig_acct)(const char *path) = acct;
int (*orig_adjtime)(struct timeval *delta, struct timeval *olddelta);
int (*orig_chdir)(const char * path) = chdir;
int (*orig_chflags)(const char *path, __uint32_t flags) = chflags;
int (*orig_chmod)(const char * path, mode_t mode) = chmod;
int (*orig_chown)(const char * path, uid_t uid, gid_t gid) = chown;
int (*orig_chroot)(const char * path) = chroot;
int (*orig_dup)(int fd) = dup;
int (*orig_dup2)(int from, int to) = dup2;
int (*orig_execve)(char *fname, char **argp, char **envp);
int (*orig_fchdir)(int fd) = fchdir;
int (*orig_fchflags)(int fd, int flags);
int (*orig_fchmod)(int fd, int mode);
int (*orig_fchown)(int fd, int uid, int gid);
int (*orig_fcntl)(int fd, int cmd, long arg);
int (*orig_fdatasync)(int fd);
int (*orig_flock)(int fd, int how) = flock;
int (*orig_fpathconf)(int fd, int name);
int (*orig_fsync)(int fd) = fsync;
int (*orig_ftruncate)(int fd, off_t length) = ftruncate;
int (*orig_futimes)(int fd, struct timeval *tptr);
int (*orig_getdirentries)(int fd, const char *buf, u_int count, long *basep);
int (*orig_getdtablesize)(void) = getdtablesize;
unsigned int (*orig_getegid)(void) = getegid;
unsigned int (*orig_geteuid)(void) = geteuid;
int (*orig_getfh)(const char *fname, fhandle_t *fhp) = getfh;
int (*orig_getfsstat)(struct statfs *buf, int bufsize, int flags);
unsigned int (*orig_getgid)(void) = getgid;
int (*orig_getgroups)(int gidsetsize, gid_t *gidset) = getgroups;
int (*orig_gethostuuid)(unsigned char *uuid_buf, const struct timespec *timeoutp) = gethostuuid;
int (*orig_getitimer)(u_int which, struct itimerval *itv);
int (*orig_getlogin)(const char *namebuf, u_int namelen);
int (*orig_getpeername)(int fdes, struct sockaddr * asa, socklen_t *alen) = getpeername;
int (*orig_getpgid)(pid_t pid) = getpgid;
int (*orig_getpgrp)(void) = getpgrp;
pid_t (*orig_getpid)(void) = getpid;
int (*orig_getppid)(void) = getppid;
int (*orig_getpriority)(int which, id_t who) = getpriority;
int (*orig_getrlimit)(int which, struct rlimit *rlp) = getrlimit;
int (*orig_getrusage)(int who, struct rusage *rusage) = getrusage;
int (*orig_getsockname)(int fdes, struct sockaddr * asa, socklen_t *alen) = getsockname;
int (*orig_getsockopt)(int s, int level, int name, struct sockaddr * val, socklen_t *avalsize);
int (*orig_gettimeofday)(struct timeval *tp, void *tzp) = gettimeofday;
unsigned int (*orig_getuid)(void) = getuid;
int (*orig_kill)(int pid, int signum, int posix);
int (*orig_link)(const char * path, const char * link) = link;
int (*orig_listen)(int s, int backlog) = listen;
int (*orig_madvise)(struct sockaddr * addr, size_t len, int behav);
int (*orig_mincore)(const char * addr, user_size_t len, const char * vec);
int (*orig_mkdir)(const char * path, int mode);
int (*orig_mkfifo)(const char * path, int mode);
int (*orig_mknod)(const char * path, int mode, int dev);
int (*orig_mlock)(struct sockaddr * addr, size_t len);
int (*orig_mount)(char *type, char *path, int flags, struct sockaddr * data);
int (*orig_mprotect)(struct sockaddr * addr, size_t len, int prot);
int (*orig_msync)(struct sockaddr * addr, size_t len, int flags);
int (*orig_munlock)(struct sockaddr * addr, size_t len);
int (*orig_munmap)(struct sockaddr * addr, size_t len);
int (*orig_nfssvc)(int flag, struct sockaddr * argp);
int (*orig_pathconf)(char *path, int name);
int (*orig_pipe)(void);
int (*orig_ptrace)(int req, pid_t pid, struct sockaddr * addr, int data);
int (*orig_quotactl)(const char *path, int cmd, int uid, struct sockaddr * arg);
int (*orig_readlink)(char *path, char *buf, int count);
int (*orig_reboot)(int opt, char *command);
int (*orig_recvmsg)(int s, struct msghdr *msg, int flags);
int (*orig_rename)(char *from, char *to);
int (*orig_revoke)(char *path);
int (*orig_rmdir)(char *path);
int (*orig_select)(int nd, u_int32_t *in, u_int32_t *ou, u_int32_t *ex, struct timeval *tv);
int (*orig_sendmsg)(int s, struct sockaddr * msg, int flags);
int (*orig_sendto)(int s, struct sockaddr * buf, size_t len, int flags, struct sockaddr * to, socklen_t tolen);
int (*orig_setegid)(gid_t egid);
int (*orig_seteuid)(uid_t euid);
int (*orig_setgid)(gid_t gid);
int (*orig_setgroups)(u_int gidsetsize, gid_t *gidset);
int (*orig_setitimer)(u_int which, struct itimerval *itv, struct itimerval *oitv);
int (*orig_setlogin)(char *namebuf);
int (*orig_setpgid)(int pid, int pgid);
int (*orig_setpriority)(int which, id_t who, int prio);
int (*orig_setprivexec)(int flag);
int (*orig_setregid)(gid_t rgid, gid_t egid);
int (*orig_setreuid)(uid_t ruid, uid_t euid);
int (*orig_setrlimit)(u_int which, struct rlimit *rlp);
int (*orig_setsid)(void);
int (*orig_setsockopt)(int s, int level, int name, struct sockaddr * val, socklen_t valsize);
int (*orig_settimeofday)(struct timeval *tv, struct timezone *tzp);
int (*orig_setuid)(uid_t uid);
int (*orig_shutdown)(int s, int how);
int (*orig_sigaction)(int signum, struct __sigaction *nsa, struct sigaction *osa);
int (*orig_sigpending)(struct sigvec *osv);
int (*orig_sigprocmask)(int how, const char * mask, const char * omask);
int (*orig_sigsuspend)(sigset_t mask);
int (*orig_socket)(int domain, int type, int protocol);
int (*orig_socketpair)(int domain, int type, int protocol, int *rsv);
int (*orig_swapon)(void);
int (*orig_symlink)(char *path, char *link);
void (*orig_sync)(void) = sync;
int (*orig_truncate)(char *path, off_t length);
int (*orig_umask)(int newmask);
int (*orig_undelete)(const char * path);
int (*orig_unlink)(const char * path);
int (*orig_unmount)(const char * path, int flags);
int (*orig_utimes)(char *path, struct timeval *tptr);
int (*orig_vfork)(void);
int (*orig_wait4)(int pid, const char * status, int options, const char * rusage);
int (*orig_waitid)(idtype_t idtype, id_t id, siginfo_t *infop, int options);
off_t (*orig_lseek)(int fd, off_t offset, int whence) = lseek;
void * (*orig_mmap)(struct sockaddr * addr, size_t len, int prot, int flags, int fd, off_t pos);
ssize_t (*orig_pread)(int fd, const char * buf, user_size_t nbyte, off_t offset);
ssize_t (*orig_pwrite)(int fd, const char * buf, user_size_t nbyte, off_t offset);
ssize_t (*orig_read)(int fd, const char * cbuf, user_size_t nbyte);
ssize_t (*orig_readv)(int fd, struct iovec *iovp, u_int iovcnt);
ssize_t (*orig_write)(int fd, const void * cbuf, size_t nbyte) = write;
ssize_t (*orig_writev)(int fd, struct iovec *iovp, u_int iovcnt);
void (*orig_exit)(int rval);

bool (*orig_dlopen_preflight)(const char* path);
int (*orig_system)(const char *command);

/***
 *** C function overrides. This is the iSpy reverse sandbox. Expand as required.
 ***/

DIR *bf_opendir(const char *dirname) {
    ispy_log_info(LOG_STRACE, "opendir(%s)", dirname);
    return orig_opendir(dirname);
}

struct dirent *bf_readdir(DIR *dirp) {
    ispy_log_info(LOG_STRACE, "readdir(%p)", dirp);
    return orig_readdir(dirp);
}

int bf_readdir_r(DIR *dirp, struct dirent *entry, struct dirent **result) {
    ispy_log_info(LOG_STRACE, "readdir_r(%p, %p, %p)", dirp, entry, result);
    return orig_readdir_r(dirp, entry, result);
}

int bf_memcmp(const void *s1, const void *s2, size_t n) {
    int result;

    result = (int) orig_memcmp(s1, s2, n);
    ispy_log_info(LOG_STRACE, "memcmp(%p, %p, %d) returned: %d", s1, s2, n, result);
    //ispy_log_debug(LOG_STRACE, "memcmp was called."); // less verbose version.

    return result;
}

int bf_strcmp(const char *s1, const char *s2) {
    ispy_log_info(LOG_STRACE, "strcmp('%s', '%s')", s1, s2);
    return orig_strcmp(s1, s2);
}

int bf_strncmp(const char *s1, const char *s2, size_t n) {
    ispy_log_info(LOG_STRACE, "strncmp('%s', '%s', %d)", s1, s2, n);
    return orig_strncmp(s1, s2, n);
}

int bf_open(const char *path, int oflag, ...) {
    int fd;
    va_list argp;
    mode_t mode;

    ispy_log_info(LOG_STRACE, "open: %s with mode %o", path, oflag);
    
    // check to see if we should block the app from seeing this file
    // You probably want this if you're breaking an app's JB detection.
    if (shouldBlockPath(path)) {
        ispy_log_info(LOG_STRACE, "open: Woooah, there. The app is looking for jailbreak files (%s)!", path);
        // We can pretend that this file simply does not exist...
        if (activelyBlock()) {
            ispy_log_info(LOG_STRACE, "open: o0o0o0o REJECTED!");
            errno = ENOENT;
            return -1; // these are not the droids you seek.
        }
    }

    // Ok, we can pass through to the original function.
    // Make sure to handle the case where "mode" is passed as a third parameter when the O_CREAT bit is set in oflag.
    if (oflag & O_CREAT) {
        va_start(argp, oflag);
        mode = (mode_t)
        va_arg(argp, int);
        va_end(argp);
        fd = orig_open(path, oflag, mode);
    } else {
        fd = orig_open(path, oflag);
    }

    ispy_log_info(LOG_STRACE, "open: returned fd=%d", fd);
    return fd;
}

// On jailbroken devices, fork() will work.
// On non-jailed devices, fork() will fail. The sandbox kicks in.
// To bypass this check we can make fork() fail by returning -1.
pid_t bf_fork(void) {
    ispy_log_info(LOG_STRACE, "fork()");
    if (activelyBlock()) {
        ispy_log_info(LOG_STRACE, "   fork: returning -1 for failure.");
        return -1;
    }
    pid_t pid;
    pid = orig_fork();
    ispy_log_info(LOG_STRACE, "   fork() returned %d.", pid);
    return pid;
}

// just calls the old func for now
int bf_fstat(int fildes, struct stat *buf) {
    
    int ret = orig_fstat(fildes, buf);
    ispy_log_info(LOG_STRACE, "fstat(%d, %p) returned %d", fildes, buf, ret);
    return ret;
}

/*
 A lot of JB checks rely on stat functions: stat, lstat, fstat (less common).
 We can intercept them to sneakily report that known-bad files don't exist...
 */
int bf_lstat(const char *path, struct stat *buf) {
    // check to see if we should block the app from seeing this file
    if (shouldBlockPath(path)) {
        ispy_log_info(LOG_STRACE, "lstat: Woooah, there. The app is looking for jailbreak files (%s)!", path);
        if (activelyBlock()) {
            ispy_log_info(LOG_STRACE, "lstat: DENIED!");
            errno = ENOENT; // file not found
            return -1;
        }
    }
    
    int ret = orig_lstat(path, buf);
    // fool JB detection routines
    if(strcmp(path, "/Applications") == 0) {
        buf->st_mode &= ~S_IFLNK;
        buf->st_mode |= S_IFDIR;
    }
    // this can get really chatty and will spam your Console log
    ispy_log_info(LOG_STRACE, "lstat(%s, %p) returned %d", path, buf, ret);
    return ret;
}

// More stat goodness.
int bf_stat(const char *path, struct stat *buf) {
    if (shouldBlockPath(path)) {
        ispy_log_info(LOG_STRACE, "stat: Woooah, there. The app is looking for jailbreak files (%s)!", path);
        if (activelyBlock()) {
            ispy_log_info(LOG_STRACE, "stat: DENIED!");
            errno = ENOENT; // file not found
            return -1;
        }
    }
    int ret = orig_stat(path, buf);
    // fool JB detection
    if(strcmp(path, "/etc/fstab") == 0 )
        buf->st_size = 80;

    if(strstr(path, "/var/www/iSpy") == NULL)
        ispy_log_info(LOG_STRACE, "stat(%s, %p) returned %d", path, buf, ret);
    return ret;
}

// access() does the same thing, pretty much. 
int bf_access(const char *path, int amode) {
    if (shouldBlockPath(path)) {
        ispy_log_info(LOG_STRACE, "access: Woooah, there. The app is looking for jailbreak files!");
        if (activelyBlock()) {
            ispy_log_info(LOG_STRACE, "access: DENIED!");
            errno = ENOENT; // file not found
            return -1;
        }
    }
    int ret = orig_access(path, amode);
    ispy_log_info(LOG_STRACE, "access(%s, 0x%x) returned %d", path, amode, ret);
    return ret;
}

// More stat-like stuff
int bf_statfs(const char *path, struct statfs *buf) {
    if (shouldBlockPath(path)) {
        ispy_log_info(LOG_STRACE, "statfs: Woooah, there. The app is looking for jailbreak files!");
        if (activelyBlock()) {
            ispy_log_info(LOG_STRACE, "statfs: DENIED!");
            errno = ENOENT; // file not found
            return -1;
        }
    }
    int ret = orig_statfs(path, buf);
    ispy_log_info(LOG_STRACE, "statfs(%s, %p) returned %d", path, buf, ret);
    return ret;
}

// just calls the old func for now
int bf_fstatfs(int fd, struct statfs *buf) {
    int ret = orig_fstatfs(fd, buf);
    ispy_log_info(LOG_STRACE, "fstatfs(%d, %p) returned %d", fd, buf, ret);
    return ret;
}


bool bf_dlopen_preflight(const char* path) {
    //ispy_log_info(LOG_STRACE, "Blocking call to dlopen_preflight(%s)", path);
    return 0;
}

/*
 _dyld_image_count()

 This returns the number of dynamic libraries loaded at run-time by the app.
 Some apps check this number!
 */
uint32_t bf_dyld_image_count(void) {
    NSString* preferenceFilePath = @PREFERENCEFILE;
    NSMutableDictionary* plist = [[NSMutableDictionary alloc]initWithContentsOfFile:preferenceFilePath];
    int userCount = [[plist objectForKey:@"dyld_image_countValue"] intValue];

    uint32_t count;
    uint32_t realCount = orig_dyld_image_count();

    if (userCount > 0 && userCount < 31337) {
        count = (uint32_t) userCount;
    } else {
        count = realCount;
    }
    ispy_log_info(LOG_STRACE, "_dyld_image_count() actual return value was %d. We are returning %d.", realCount, count);
    [plist release];
    [preferenceFilePath release];
    return count;
}

/*
 _dyld_get_image_name()

 Given an index #, this returns the name of the dynamic library.
 eg. _dyld_get_image_name(0) will return the full path to the app.
 but _dyld_get_image_name(1) will return the full path to MobileSubstrate.
 
 If you want to hide jailbreak stuff, set ACTIVELY_BLOCK (in Settings app) and this 
 function will hide known-bad dylibs from the app.
 */
const char* bf_dyld_get_image_name(uint32_t id) {
    const char* realName = (const char *) orig_dyld_get_image_name(id);
    const char *fakeName = (const char *) orig_dyld_get_image_name(0); // returns the name of the app
    char *returnedName = (char *)realName;

    if (activelyBlock()) {
        if(shouldBlockPath(realName)) 
            returnedName = (char *)fakeName;
    }

    ispy_log_info(LOG_STRACE, "_dyld_get_image_name(%d) would normally return '%s'. Actually returning '%s'", realName, returnedName);
    return returnedName;
}

/*
 connect(2)

 Supports logging AF_SYSTEM, AF_INET(IPv4) and AF_INET6(IPv6) sockets.
 Other types (eg. UNIX domain) sockets are not (yet) supported. Please contribute!
 */
int bf_connect(int socket, const struct sockaddr *address, socklen_t address_len) {
    int port = -1;
    char host[1024];

    ispy_log_info(LOG_STRACE, "connect(%d, %p, %d)", socket, address, address_len);
    if (address->sa_family == AF_INET) {
        port = ntohs(((struct sockaddr_in *) address)->sin_port);
        strncpy(host, inet_ntoa(((struct sockaddr_in *) address)->sin_addr),
                sizeof(host));
        ispy_log_info(LOG_STRACE, "   IPv4 to %s:%d", host, port);
    } else if (address->sa_family == AF_INET6) {
        port = ntohs(((struct sockaddr_in6 *) address)->sin6_port);
        inet_ntop(address->sa_family,
                (void *) &(((struct sockaddr_in6 *) address)->sin6_addr), host, 128);
        ispy_log_info(LOG_STRACE, "   IPv6 to %s:%d", host, port);
    } else if (address->sa_family == AF_SYSTEM) {
        ispy_log_info(LOG_STRACE, "   AF_SYSTEM: ss_sysaddr=%d, sc_id=%d, sc_unit=%d",
                ((struct sockaddr_ctl *) address)->ss_sysaddr,
                ((struct sockaddr_ctl *) address)->sc_id,
                ((struct sockaddr_ctl *) address)->sc_unit);
    } else {
        ispy_log_info(LOG_STRACE, "   address family unknown: %d",
                address->sa_family);
    }

    int ret = orig_connect(socket, address, address_len);
    ispy_log_info(LOG_STRACE, "   returned %d", ret);
    return ret;
}

/*
 bind(2)

 Supports logging IPv4 and IPv6 sockets.
 Other types (eg. UNIX domain) sockets are not (yet) supported. Please contribute!
 */
int bf_bind(int socket, const struct sockaddr *address, socklen_t address_len) {
    int port = -1, ret;
    char host[256];

    if (address->sa_family == AF_INET) {
        port = ntohs(((struct sockaddr_in *) address)->sin_port);
        strncpy(host, inet_ntoa(((struct sockaddr_in *) address)->sin_addr), sizeof(host));
    } else if (address->sa_family == AF_INET6) {
        port = ntohs(((struct sockaddr_in6 *) address)->sin6_port);
        inet_ntop(address->sa_family,
                (void *) &(((struct sockaddr_in6 *) address)->sin6_addr), host, 256);
    }

    ret = orig_bind(socket, address, address_len);
    ispy_log_info(LOG_STRACE, "bind(%d, %p, %d) returned %d", socket, address, address_len, ret);
    ispy_log_info(LOG_STRACE, "   bind: %s:%d (%s [0x%x])", host, port,
            (address->sa_family == AF_INET6) ? "IPv6" :
            (address->sa_family == AF_INET) ? "IPv4" : "Unknown family",
            (unsigned int) address->sa_family);
    return ret;
}

/*
 accept(2)

 Supports logging AF_SYSTEM, AF_INET(IPv4) and AF_INET6(IPv6) sockets.
 Other types (eg. UNIX domain) sockets are not (yet) supported. Please contribute!
 */
int bf_accept(int socket, struct sockaddr *address, socklen_t *address_len) {
    int port = -1;
    char host[128]; // overflow me, baby
    int retval;

    retval = orig_accept(socket, address, address_len);
    ispy_log_info(LOG_STRACE, "accept(%d, %p, %d) returned %d", socket, address, address_len, retval);
    if (address->sa_family == AF_INET) {
        port = ntohs(((struct sockaddr_in *) address)->sin_port);
        strncpy(host, inet_ntoa(((struct sockaddr_in *) address)->sin_addr), sizeof(host));
        ispy_log_info(LOG_STRACE, "   accept: IPv4 to %s: %d", host, port);
    } else if (address->sa_family == AF_INET6) {
        port = ntohs(((struct sockaddr_in6 *) address)->sin6_port);
        inet_ntop(address->sa_family,
                (void *) &(((struct sockaddr_in6 *) address)->sin6_addr), host, 128);
        ispy_log_info(LOG_STRACE, "   accept: IPv6 to %s: %d", host, port);
    } else if (address->sa_family == AF_SYSTEM) {
        ispy_log_info(LOG_STRACE, "   accept: AF_SYSTEM: ss_sysaddr= %d, sc_id=%d, sc_unit=%d",
                retval, ((struct sockaddr_ctl *) address)->ss_sysaddr,
                ((struct sockaddr_ctl *) address)->sc_id,
                ((struct sockaddr_ctl *) address)->sc_unit);
    } else {
        ispy_log_info(LOG_STRACE, "   accept: address family unknown: %d", address->sa_family);
    }
    return retval;
}

ssize_t bf_recv(int socket, void *buffer, size_t length, int flags) {
    size_t retval;

    retval = orig_recv(socket, buffer, length, flags);
    ispy_log_info(LOG_STRACE, "recv(%d, %p, %ld, 0x%x) returned %ld bytes", socket, buffer, length, flags, retval);

    return retval;
}

ssize_t bf_recvfrom(int socket, void *buffer, size_t length, int flags,
    struct sockaddr *address, socklen_t *address_len) {
    ssize_t retval;

    retval = orig_recvfrom(socket, buffer, length, flags, address, address_len);
    ispy_log_info(LOG_STRACE, "recvfrom(%d, %p, %ld, 0x%x, %p, %d) returned %ld bytes", socket, buffer, length, flags, address, address_len, retval);
    return retval;
}

/*
 Welcome to crazy town. We could borrow the same stack-preserving assembly code from replaced_objc_msgSend() to do 
 this a little (ok, a lot) more elegantly.
 */
int bf_ioctl(int fildes, unsigned long request, ...) {
    struct ctl_info *ctlinfo;
    void *foo, *params[16];
    va_list argp;
    int retval, i = 0;

    va_start(argp, request);
    while ((foo = (void *) va_arg(argp, void *))) {
        params[i++] = foo;
    }
    va_end(argp);

    ispy_log_info(LOG_STRACE, "ioctl(%d, 0x%x)", fildes, request);
    if (request == CTLIOCGINFO) {
        ispy_log_info(LOG_STRACE, "    ioctl: CTLIOCGINFO...");
        ctlinfo = (struct ctl_info *) params[0];
        retval = orig_ioctl(fildes, request, ctlinfo);
        ispy_log_info(LOG_STRACE, "    ioctl: CTLIOCGINFO: returned %d. fd=%d, '%s'",
                retval, fildes, ctlinfo->ctl_name);
    } else {
        ispy_log_info(LOG_STRACE, "    ioctl: passthru of %d args", i);
        if (i == 0)
            retval = orig_ioctl(fildes, request);
        if (i == 1)
            retval = orig_ioctl(fildes, request, params[0]);
        if (i == 2)
            retval = orig_ioctl(fildes, request, params[0], params[1]);
        if (i == 3)
            retval = orig_ioctl(fildes, request, params[0], params[1],
                    params[2]);
        if (i == 4)
            retval = orig_ioctl(fildes, request, params[0], params[1],
                    params[2], params[3]);
        if (i == 5)
            retval = orig_ioctl(fildes, request, params[0], params[1],
                    params[2], params[3], params[4]);
        if (i == 6)
            retval = orig_ioctl(fildes, request, params[0], params[1],
                    params[2], params[3], params[4], params[5]);
        if (i == 7)
            retval = orig_ioctl(fildes, request, params[0], params[1],
                    params[2], params[3], params[4], params[5], params[6]);
        if (i == 8)
            retval = orig_ioctl(fildes, request, params[0], params[1],
                    params[2], params[3], params[4], params[5], params[6],
                    params[7]);
        if (i == 9)
            retval = orig_ioctl(fildes, request, params[0], params[1],
                    params[2], params[3], params[4], params[5], params[6],
                    params[7], params[8]);
        if (i == 10)
            retval = orig_ioctl(fildes, request, params[0], params[1],
                    params[2], params[3], params[4], params[5], params[6],
                    params[7], params[8], params[9]);
        if (i == 11)
            retval = orig_ioctl(fildes, request, params[0], params[1],
                    params[2], params[3], params[4], params[5], params[6],
                    params[7], params[8], params[9], params[10]); //surely this is enough??
    }
    ispy_log_info(LOG_STRACE, "    ioctl: returned %d", retval);
    return retval;
}

int bf_sysctl(int *name, u_int namelen, void *old, size_t *oldlenp, void *_new, size_t newlen) {
    int ret = orig_sysctl(name, namelen, old, oldlenp, _new, newlen);
    ispy_log_info(LOG_STRACE, "sysctl(%p, %p, %p, %p, %p, %p) returned %d", name, namelen, old, oldlenp, _new, newlen, ret);
    return ret;
}

int bf_acct(const char *path) {
    int ret = orig_acct(path);
    ispy_log_info(LOG_STRACE, "acct(%p) returned %d", path, ret);
    return ret;
}
int bf_adjtime(struct timeval *delta, struct timeval *olddelta) {
    int ret = orig_adjtime(delta, olddelta);
    ispy_log_info(LOG_STRACE, "adjtime(%p, %p) returned %d", delta, olddelta, ret);
    return ret;
}
int bf_chdir(const char * path) {
    int ret = orig_chdir(path);
    ispy_log_info(LOG_STRACE, "chdir(%p) returned %d", path, ret);
    return ret;
}
int bf_chflags(char *path, int flags) {
    int ret = orig_chflags(path, flags);
    ispy_log_info(LOG_STRACE, "chflags(%p, %p) returned %d", path, flags, ret);
    return ret;
}
int bf_chmod(const char * path, mode_t mode) {
    int ret = orig_chmod(path, mode);
    ispy_log_info(LOG_STRACE, "chmod(%p, %p) returned %d", path, mode, ret);
    return ret;
}
int bf_chown(const char * path, uid_t uid, gid_t gid) {
    int ret = orig_chown(path, uid, gid);
    ispy_log_info(LOG_STRACE, "chown(%p, %p, %p) returned %d", path, uid, gid, ret);
    return ret;
}
int bf_chroot(const char * path) {
    int ret = orig_chroot(path);
    ispy_log_info(LOG_STRACE, "chroot(%p) returned %d", path, ret);
    return ret;
}
int bf_close(int fd) {
    int ret = orig_close(fd);
    ispy_log_info(LOG_STRACE, "close(%p) returned %d", fd, ret);
    return ret;
}

int bf_dup(u_int fd) {
    int newfd = orig_dup(fd);
    ispy_log_info(LOG_STRACE, "dup(%d) returned %d\n", fd, newfd, newfd);
    return newfd;
}
int bf_dup2(u_int from, u_int to) {
    int ret = orig_dup2(from, to);
    ispy_log_info(LOG_STRACE, "dup2(%p, %p) returned %d", from, to, ret);
    return ret;
}
int bf_execve(char *fname, char **argp, char **envp) {
    int ret = orig_execve(fname, argp, envp);
    ispy_log_info(LOG_STRACE, "execve(%p, %p, %p) returned %d", fname, argp, envp, ret);
    return ret;
}
int bf_fchdir(int fd) {
    int ret = orig_fchdir(fd);
    ispy_log_info(LOG_STRACE, "fchdir(%p) returned %d", fd, ret);
    return ret;
}
int bf_fchflags(int fd, int flags) {
    int ret = orig_fchflags(fd, flags);
    ispy_log_info(LOG_STRACE, "fchflags(%p, %p) returned %d", fd, flags, ret);
    return ret;
}
int bf_fchmod(int fd, int mode) {
    int ret = orig_fchmod(fd, mode);
    ispy_log_info(LOG_STRACE, "fchmod(%p, %p) returned %d", fd, mode, ret);
    return ret;
}
int bf_fchown(int fd, uid_t uid, gid_t gid) {
    int ret = orig_fchown(fd, uid, gid);
    ispy_log_info(LOG_STRACE, "fchown(%p, %p, %p) returned %d", fd, uid, gid, ret);
    return ret;
}
int bf_fcntl(int fd, int cmd, long arg) {
    int ret = orig_fcntl(fd, cmd, arg);
    ispy_log_info(LOG_STRACE, "fcntl(%p, %p, %p) returned %d", fd, cmd, arg, ret);
    return ret;
}
int bf_fdatasync(int fd) {
    int ret = orig_fdatasync(fd);
    ispy_log_info(LOG_STRACE, "fdatasync(%p) returned %d", fd, ret);
    return ret;
}
int bf_flock(int fd, int how) {
    int ret = orig_flock(fd, how);
    ispy_log_info(LOG_STRACE, "flock(%p, %p) returned %d", fd, how, ret);
    return ret;
}
int bf_fpathconf(int fd, int name) {
    int ret = orig_fpathconf(fd, name);
    ispy_log_info(LOG_STRACE, "fpathconf(%p, %p) returned %d", fd, name, ret);
    return ret;
}

int bf_fsync(int fd) {
    int ret = orig_fsync(fd);
    ispy_log_info(LOG_STRACE, "fsync(%p) returned %d", fd, ret);
    return ret;
}
int bf_ftruncate(int fd, off_t length) {
    int ret = orig_ftruncate(fd, length);
    ispy_log_info(LOG_STRACE, "ftruncate(%p, %p) returned %d", fd, length, ret);
    return ret;
}
int bf_futimes(int fd, struct timeval *tptr) {
    int ret = orig_futimes(fd, tptr);
    ispy_log_info(LOG_STRACE, "futimes(%p, %p) returned %d", fd, tptr, ret);
    return ret;
}
int bf_getdtablesize(void) {
    int ret = orig_getdtablesize();
    ispy_log_info(LOG_STRACE, "getdtablesize() returned %d", ret);
    return ret;
}
int bf_getegid(void) {
    int ret = orig_getegid();
    ispy_log_info(LOG_STRACE, "getegid() returned %d", ret);
    return ret;
}
int bf_geteuid(void) {
    int ret = orig_geteuid();
    ispy_log_info(LOG_STRACE, "geteuid() returned %d", ret);
    return ret;
}
int bf_getfh(char *fname, fhandle_t *fhp) {
    int ret = orig_getfh(fname, fhp);
    ispy_log_info(LOG_STRACE, "getfh(%p, %p) returned %d", fname, fhp, ret);
    return ret;
}
int bf_getfsstat(struct statfs * buf, int bufsize, int flags) {
    int ret = orig_getfsstat(buf, bufsize, flags);
    ispy_log_info(LOG_STRACE, "getfsstat(%p, %p, %p) returned %d", buf, bufsize, flags, ret);
    return ret;
}
int bf_getgid(void) {
    int ret = orig_getgid();
    ispy_log_info(LOG_STRACE, "getgid() returned %d", ret);
    return ret;
}
int bf_getgroups(u_int gidsetsize, gid_t *gidset) {
    int ret = orig_getgroups(gidsetsize, gidset);
    ispy_log_info(LOG_STRACE, "getgroups(%p, %p) returned %d", gidsetsize, gidset, ret);
    return ret;
}
int bf_gethostuuid(unsigned char *uuid_buf, const struct timespec *timeoutp) {
    int ret = orig_gethostuuid(uuid_buf, timeoutp);
    ispy_log_info(LOG_STRACE, "gethostuuid(%p, %p) returned %d", uuid_buf, timeoutp, ret);
    return ret;
}
int bf_getitimer(u_int which, struct itimerval *itv) {
    int ret = orig_getitimer(which, itv);
    ispy_log_info(LOG_STRACE, "getitimer(%p, %p) returned %d", which, itv, ret);
    return ret;
}
int bf_getlogin(char *namebuf, u_int namelen) {
    int ret = orig_getlogin(namebuf, namelen);
    ispy_log_info(LOG_STRACE, "getlogin(%p, %p) returned %d", namebuf, namelen, ret);
    return ret;
}
int bf_getpeername(int fdes, struct sockaddr * asa, socklen_t *alen) {
    int ret = orig_getpeername(fdes, asa, alen);
    ispy_log_info(LOG_STRACE, "getpeername(%p, %p, %p) returned %d", fdes, asa, alen, ret);
    return ret;
}
int bf_getpgid(pid_t pid) {
    int ret = orig_getpgid(pid);
    ispy_log_info(LOG_STRACE, "getpgid(%p) returned %d", pid, ret);
    return ret;
}
int bf_getpgrp(void) {
    int ret = orig_getpgrp();
    ispy_log_info(LOG_STRACE, "getpgrp() returned %d", ret);
    return ret;
}
pid_t bf_getpid(void) {
    pid_t pid;

    ispy_log_info(LOG_STRACE, "Calling old getpid()");
    pid=orig_getpid();
    ispy_log_info(LOG_STRACE, "getpid() returned %d", pid);;
    return  pid;
}
int bf_getppid(void) {
    int ret = orig_getppid();
    ispy_log_info(LOG_STRACE, "getppid() returned %d", ret);
    return ret;
}
int bf_getpriority(int which, id_t who) {
    int ret = orig_getpriority(which, who);
    ispy_log_info(LOG_STRACE, "getpriority(%p, %p) returned %d", which, who, ret);
    return ret;
}
int bf_getrlimit(u_int which, struct rlimit *rlp) {
    int ret = orig_getrlimit(which, rlp);
    ispy_log_info(LOG_STRACE, "getrlimit(%p, %p) returned %d", which, rlp, ret);
    return ret;
}
int bf_getrusage(int who, struct rusage *rusage) {
    int ret = orig_getrusage(who, rusage);
    ispy_log_info(LOG_STRACE, "getrusage(%p, %p) returned %d", who, rusage, ret);
    return ret;
}
int bf_getsockname(int fdes, struct sockaddr * asa, socklen_t *alen) {
    int ret = orig_getsockname(fdes, asa, alen);
    ispy_log_info(LOG_STRACE, "getsockname(%p, %p, %p) returned %d", fdes, asa, alen, ret);
    return ret;
}
int bf_getsockopt(int s, int level, int name, struct sockaddr * val, socklen_t *avalsize) {
    int ret = orig_getsockopt(s, level, name, val, avalsize);
    ispy_log_info(LOG_STRACE, "getsockopt(%p, %p, %p, %p, %p) returned %d", s, level, name, val, avalsize, ret);
    return ret;
}
int bf_gettimeofday(struct timeval *tp, struct timezone *tzp) {
    int ret = orig_gettimeofday(tp, tzp);
    ispy_log_info(LOG_STRACE, "gettimeofday(%p, %p) returned %d", tp, tzp, ret);
    return ret;
}
int bf_getuid(void) {
    int ret = orig_getuid();
    ispy_log_info(LOG_STRACE, "getuid() returned %d", ret);
    return ret;
}
int bf_kill(int pid, int signum, int posix) {
    int ret = orig_kill(pid, signum, posix);
    ispy_log_info(LOG_STRACE, "kill(%p, %p, %p) returned %d", pid, signum, posix, ret);
    return ret;
}
int bf_link(const char * path, const char * link) {
    int ret = orig_link(path, link);
    ispy_log_info(LOG_STRACE, "link(%p, %p) returned %d", path, link, ret);
    return ret;
}
int bf_listen(int s, int backlog) {
    int ret = orig_listen(s, backlog);
    ispy_log_info(LOG_STRACE, "listen(%p, %p) returned %d", s, backlog, ret);
    return ret;
}

int bf_madvise(struct sockaddr * addr, size_t len, int behav) {
    int ret = orig_madvise(addr, len, behav);
    ispy_log_info(LOG_STRACE, "madvise(%p, %p, %p) returned %d", addr, len, behav, ret);
    return ret;
}
int bf_mincore(const char * addr, user_size_t len, const char * vec) {
    int ret = orig_mincore(addr, len, vec);
    ispy_log_info(LOG_STRACE, "mincore(%p, %p, %p) returned %d", addr, len, vec, ret);
    return ret;
}
int bf_mkdir(const char * path, int mode) {
    int ret = orig_mkdir(path, mode);
    ispy_log_info(LOG_STRACE, "mkdir(%p, %p) returned %d", path, mode, ret);
    return ret;
}
int bf_mkfifo(const char * path, int mode) {
    int ret = orig_mkfifo(path, mode);
    ispy_log_info(LOG_STRACE, "mkfifo(%p, %p) returned %d", path, mode, ret);
    return ret;
}
int bf_mknod(const char * path, int mode, int dev) {
    int ret = orig_mknod(path, mode, dev);
    ispy_log_info(LOG_STRACE, "mknod(%p, %p, %p) returned %d", path, mode, dev, ret);
    return ret;
}
int bf_mlock(struct sockaddr * addr, size_t len) {
    int ret = orig_mlock(addr, len);
    ispy_log_info(LOG_STRACE, "mlock(%p, %p) returned %d", addr, len, ret);
    return ret;
}
int bf_mount(char *type, char *path, int flags, struct sockaddr * data) {
    int ret = orig_mount(type, path, flags, data);
    ispy_log_info(LOG_STRACE, "mount(%p, %p, %p, %p) returned %d", type, path, flags, data, ret);
    return ret;
}
int bf_mprotect(struct sockaddr * addr, size_t len, int prot) {
    int ret = orig_mprotect(addr, len, prot);
    ispy_log_info(LOG_STRACE, "mprotect(%p, %p, %p) returned %d", addr, len, prot, ret);
    return ret;
}
int bf_msync(struct sockaddr * addr, size_t len, int flags) {
    int ret = orig_msync(addr, len, flags);
    ispy_log_info(LOG_STRACE, "msync(%p, %p, %p) returned %d", addr, len, flags, ret);
    return ret;
}
int bf_munlock(struct sockaddr * addr, size_t len) {
    int ret = orig_munlock(addr, len);
    ispy_log_info(LOG_STRACE, "munlock(%p, %p) returned %d", addr, len, ret);
    return ret;
}
int bf_munmap(struct sockaddr * addr, size_t len) {
    int ret = orig_munmap(addr, len);
    ispy_log_info(LOG_STRACE, "munmap(%p, %p) returned %d", addr, len, ret);
    return ret;
}
int bf_nfssvc(int flag, struct sockaddr * argp) {
    int ret = orig_nfssvc(flag, argp);
    ispy_log_info(LOG_STRACE, "nfssvc(%p, %p) returned %d", flag, argp, ret);
    return ret;
}
int bf_pathconf(char *path, int name) {
    int ret = orig_pathconf(path, name);
    ispy_log_info(LOG_STRACE, "pathconf(%p, %p) returned %d", path, name, ret);
    return ret;
}
int bf_pipe(void) {
    int ret = orig_pipe();
    ispy_log_info(LOG_STRACE, "pipe() returned %d", ret);
    return ret;
}
int bf_ptrace(int req, pid_t pid, struct sockaddr * addr, int data) {
    int ret = orig_ptrace(req, pid, addr, data);
    ispy_log_info(LOG_STRACE, "ptrace(%p, %p, %p, %p) returned %d", req, pid, addr, data, ret);
    return ret;
}

int ptrace(int req, pid_t pid, struct sockaddr * addr, int data) {
    int ret = orig_ptrace(req, pid, addr, data);
    ispy_log_info(LOG_STRACE, "ptrace(%p, %p, %p, %p) returned %d", req, pid, addr, data, ret);
    return ret;
}
int bf_quotactl(const char *path, int cmd, int uid, struct sockaddr * arg) {
    int ret = orig_quotactl(path, cmd, uid, arg);
    ispy_log_info(LOG_STRACE, "quotactl(%p, %p, %p, %p) returned %d", path, cmd, uid, arg, ret);
    return ret;
}
int bf_readlink(char *path, char *buf, int count) {
    int ret = orig_readlink(path, buf, count);
    ispy_log_info(LOG_STRACE, "readlink(%p, %p, %p) returned %d", path, buf, count, ret);
    return ret;
}
int bf_reboot(int opt, char *command) {
    int ret = orig_reboot(opt, command);
    ispy_log_info(LOG_STRACE, "reboot(%p, %p) returned %d", opt, command, ret);
    return ret;
}

int bf_recvmsg(int s, struct msghdr *msg, int flags) {
    int ret = orig_recvmsg(s, msg, flags);
    ispy_log_info(LOG_STRACE, "recvmsg(%p, %p, %p) returned %d", s, msg, flags, ret);
    return ret;
}
int bf_rename(char *from, char *to) {
    int ret = orig_rename(from, to);
    ispy_log_info(LOG_STRACE, "rename(%p, %p) returned %d", from, to, ret);
    return ret;
}
int bf_revoke(char *path) {
    int ret = orig_revoke(path);
    ispy_log_info(LOG_STRACE, "revoke(%p) returned %d", path, ret);
    return ret;
}
int bf_rmdir(char *path) {
    int ret = orig_rmdir(path);
    ispy_log_info(LOG_STRACE, "rmdir(%p) returned %d", path, ret);
    return ret;
}
int bf_select(int nd, u_int32_t *in, u_int32_t *ou, u_int32_t *ex, struct timeval *tv) {
    int ret = orig_select(nd, in, ou, ex, tv);
    ispy_log_info(LOG_STRACE, "select(%p, %p, %p, %p, %p) returned %d", nd, in, ou, ex, tv, ret);
    return ret;
}
int bf_sendmsg(int s, struct sockaddr * msg, int flags) {
    int ret = orig_sendmsg(s, msg, flags);
    ispy_log_info(LOG_STRACE, "sendmsg(%p, %p, %p) returned %d", s, msg, flags, ret);
    return ret;
}
int bf_sendto(int s, struct sockaddr * buf, size_t len, int flags, struct sockaddr * to, socklen_t tolen) {
    int ret = orig_sendto(s, buf, len, flags, to, tolen);
    ispy_log_info(LOG_STRACE, "sendto(%p, %p, %p, %p, %p, %p) returned %d", s, buf, len, flags, to, tolen, ret);
    return ret;
}
int bf_setegid(gid_t egid) {
    int ret = orig_setegid(egid);
    ispy_log_info(LOG_STRACE, "setegid(%p) returned %d", egid, ret);
    return ret;
}
int bf_seteuid(uid_t euid) {
    int ret = orig_seteuid(euid);
    ispy_log_info(LOG_STRACE, "seteuid(%p) returned %d", euid, ret);
    return ret;
}
int bf_setgid(gid_t gid) {
    int ret = orig_setgid(gid);
    ispy_log_info(LOG_STRACE, "setgid(%p) returned %d", gid, ret);
    return ret;
}
int bf_setgroups(u_int gidsetsize, gid_t *gidset) {
    int ret = orig_setgroups(gidsetsize, gidset);
    ispy_log_info(LOG_STRACE, "setgroups(%p, %p) returned %d", gidsetsize, gidset, ret);
    return ret;
}
int bf_setitimer(u_int which, struct itimerval *itv, struct itimerval *oitv) {
    int ret = orig_setitimer(which, itv, oitv);
    ispy_log_info(LOG_STRACE, "setitimer(%p, %p, %p) returned %d", which, itv, oitv, ret);
    return ret;
}
int bf_setlogin(char *namebuf) {
    int ret = orig_setlogin(namebuf);
    ispy_log_info(LOG_STRACE, "setlogin(%p) returned %d", namebuf, ret);
    return ret;
}
int bf_setpgid(int pid, int pgid) {
    int ret = orig_setpgid(pid, pgid);
    ispy_log_info(LOG_STRACE, "setpgid(%p, %p) returned %d", pid, pgid, ret);
    return ret;
}
int bf_setpriority(int which, id_t who, int prio) {
    int ret = orig_setpriority(which, who, prio);
    ispy_log_info(LOG_STRACE, "setpriority(%p, %p, %p) returned %d", which, who, prio, ret);
    return ret;
}
int bf_setregid(gid_t rgid, gid_t egid) {
    int ret = orig_setregid(rgid, egid);
    ispy_log_info(LOG_STRACE, "setregid(%p, %p) returned %d", rgid, egid, ret);
    return ret;
}
int bf_setreuid(uid_t ruid, uid_t euid) {
    int ret = orig_setreuid(ruid, euid);
    ispy_log_info(LOG_STRACE, "setreuid(%p, %p) returned %d", ruid, euid, ret);
    return ret;
}
int bf_setrlimit(u_int which, struct rlimit *rlp) {
    int ret = orig_setrlimit(which, rlp);
    ispy_log_info(LOG_STRACE, "setrlimit(%p, %p) returned %d", which, rlp, ret);
    return ret;
}
int bf_setsid(void) {
    int ret = orig_setsid();
    ispy_log_info(LOG_STRACE, "setsid() returned %d", ret);
    return ret;
}
int bf_setsockopt(int s, int level, int name, struct sockaddr * val, socklen_t valsize) {
    int ret = orig_setsockopt(s, level, name, val, valsize);
    ispy_log_info(LOG_STRACE, "setsockopt(%p, %p, %p, %p, %p) returned %d", s, level, name, val, valsize, ret);
    return ret;
}
int bf_settimeofday(struct timeval *tv, struct timezone *tzp) {
    int ret = orig_settimeofday(tv, tzp);
    ispy_log_info(LOG_STRACE, "settimeofday(%p, %p) returned %d", tv, tzp, ret);
    return ret;
}
int bf_setuid(uid_t uid) {
    int ret = orig_setuid(uid);
    ispy_log_info(LOG_STRACE, "setuid(%p) returned %d", uid, ret);
    return ret;
}
int bf_shutdown(int s, int how) {
    int ret = orig_shutdown(s, how);
    ispy_log_info(LOG_STRACE, "shutdown(%p, %p) returned %d", s, how, ret);
    return ret;
}
int bf_sigaction(int signum, struct __sigaction *nsa, struct sigaction *osa) {
    int ret = orig_sigaction(signum, nsa, osa);
    ispy_log_info(LOG_STRACE, "sigaction(%p, %p, %p) returned %d", signum, nsa, osa, ret);
    return ret;
}
int bf_sigpending(struct sigvec *osv) {
    int ret = orig_sigpending(osv);
    ispy_log_info(LOG_STRACE, "sigpending(%p) returned %d", osv, ret);
    return ret;
}
int bf_sigprocmask(int how, const char * mask, const char * omask) {
    int ret = orig_sigprocmask(how, mask, omask);
    ispy_log_info(LOG_STRACE, "sigprocmask(%p, %p, %p) returned %d", how, mask, omask, ret);
    return ret;
}
int bf_sigsuspend(sigset_t mask) {
    int ret = orig_sigsuspend(mask);
    ispy_log_info(LOG_STRACE, "sigsuspend(%p) returned %d", mask, ret);
    return ret;
}
int bf_socket(int domain, int type, int protocol) {
    int ret = orig_socket(domain, type, protocol);
    ispy_log_info(LOG_STRACE, "socket(%p, %p, %p) returned %d", domain, type, protocol, ret);
    return ret;
}
int bf_socketpair(int domain, int type, int protocol, int *rsv) {
    int ret = orig_socketpair(domain, type, protocol, rsv);
    ispy_log_info(LOG_STRACE, "socketpair(%p, %p, %p, %p) returned %d", domain, type, protocol, rsv, ret);
    return ret;
}

int bf_swapon(void) {
    int ret = orig_swapon();
    ispy_log_info(LOG_STRACE, "swapon() returned %d", ret);
    return ret;
}
int bf_symlink(char *path, char *link) {
    int ret = orig_symlink(path, link);
    ispy_log_info(LOG_STRACE, "symlink(%p, %p) returned %d", path, link, ret);
    return ret;
}
void bf_sync(void) {
    orig_sync();
    ispy_log_info(LOG_STRACE, "sync() was called");
    return;
}
int bf_truncate(char *path, off_t length) {
    int ret = orig_truncate(path, length);
    ispy_log_info(LOG_STRACE, "truncate(%p, %p) returned %d", path, length, ret);
    return ret;
}
int bf_umask(int newmask) {
    int ret = orig_umask(newmask);
    ispy_log_info(LOG_STRACE, "umask(%p) returned %d", newmask, ret);
    return ret;
}
int bf_undelete(const char * path) {
    int ret = orig_undelete(path);
    ispy_log_info(LOG_STRACE, "undelete(%p) returned %d", path, ret);
    return ret;
}
int bf_unlink(const char * path) {
    int ret = orig_unlink(path);
    ispy_log_info(LOG_STRACE, "unlink(%p) returned %d", path, ret);
    return ret;
}
int bf_unmount(const char * path, int flags) {
    int ret = orig_unmount(path, flags);
    ispy_log_info(LOG_STRACE, "unmount(%p, %p) returned %d", path, flags, ret);
    return ret;
}
int bf_utimes(char *path, struct timeval *tptr) {
    int ret = orig_utimes(path, tptr);
    ispy_log_info(LOG_STRACE, "utimes(%p, %p) returned %d", path, tptr, ret);
    return ret;
}
int bf_vfork(void) {
    int ret = orig_vfork();
    ispy_log_info(LOG_STRACE, "vfork() returned %d", ret);
    return ret;
}
int bf_wait4(int pid, const char * status, int options, const char * rusage) {
    int ret = orig_wait4(pid, status, options, rusage);
    ispy_log_info(LOG_STRACE, "wait4(%p, %p, %p, %p) returned %d", pid, status, options, rusage, ret);
    return ret;
}
int bf_waitid(idtype_t idtype, id_t id, siginfo_t *infop, int options) {
    int ret = orig_waitid(idtype, id, infop, options);
    ispy_log_info(LOG_STRACE, "waitid(%p, %p, %p, %p) returned %d", idtype, id, infop, options, ret);
    return ret;
}
off_t bf_lseek(int fd, off_t offset, int whence) {
    int ret = orig_lseek(fd, offset, whence);
    ispy_log_info(LOG_STRACE, "lseek(%p, %p, %p) returned %d", fd, offset, whence, ret);
    return ret;
}
void * bf_mmap(struct sockaddr * addr, size_t len, int prot, int flags, int fd, off_t pos) {
    pthread_mutex_lock(&mutex_mmap);
    void *ret = orig_mmap(addr, len, prot, flags, fd, pos);
    pthread_mutex_unlock(&mutex_mmap);
    ispy_log_info(LOG_STRACE, "mmap(%p, %p, %p, %p, %p, %p) returned %p", addr, len, prot, flags, fd, pos, ret);
    return ret;
}
user_ssize_t bf_pread(int fd, const char * buf, user_size_t nbyte, off_t offset) {
    int ret = orig_pread(fd, buf, nbyte, offset);
    ispy_log_info(LOG_STRACE, "pread(%p, %p, %p, %p) returned %d", fd, buf, nbyte, offset, ret);
    return ret;
}
user_ssize_t bf_pwrite(int fd, const char * buf, user_size_t nbyte, off_t offset) {
    int ret = orig_pwrite(fd, buf, nbyte, offset);
    ispy_log_info(LOG_STRACE, "pwrite(%p, %p, %p, %p) returned %d", fd, buf, nbyte, offset, ret);
    return ret;
}
user_ssize_t bf_read(int fd, const char * cbuf, user_size_t nbyte) {
    int ret = orig_read(fd, cbuf, nbyte);
    ispy_log_info(LOG_STRACE, "read(%p, %p, %p) returned %d", fd, cbuf, nbyte, ret);
    return ret;
}
user_ssize_t bf_readv(int fd, struct iovec *iovp, u_int iovcnt) {
    int ret = orig_readv(fd, iovp, iovcnt);
    ispy_log_info(LOG_STRACE, "readv(%p, %p, %p) returned %d", fd, iovp, iovcnt, ret);
    return ret;
}
user_ssize_t bf_write(int fd, const char * cbuf, user_size_t nbyte) {
    int ret = orig_write(fd, cbuf, nbyte);
    ispy_log_info(LOG_STRACE, "write(%p, %p, %p) returned %d", fd, cbuf, nbyte, ret);
    return ret;
}
user_ssize_t bf_writev(int fd, struct iovec *iovp, u_int iovcnt) {
    int ret = orig_writev(fd, iovp, iovcnt);
    ispy_log_info(LOG_STRACE, "writev(%p, %p, %p) returned %d", fd, iovp, iovcnt, ret);
    return ret;
}
void bf_exit(int rval) {
    ispy_log_info(LOG_STRACE, "exit(%p)", rval);
    orig_exit(rval);
}

int bf_system(const char *command) {
    ispy_log_info(LOG_STRACE, "Got system(%p), blocking!", command);
    return 0;
}

/*
 This is going away... or changing... or something. Soon.

 Anti-jail break detection

 Block checks for known jailbreak detection techniques. 
 60% of the time it works 100% of the time.
 
 Disabled by default.
 */
BOOL activelyBlock() {
    NSString *preferenceFilePath = @PREFERENCEFILE;
    NSMutableDictionary *plist = [[NSMutableDictionary alloc]initWithContentsOfFile:preferenceFilePath];
    BOOL block = [[plist objectForKey:@"settings_ActivelyBlock"] boolValue];
    [preferenceFilePath release];
    [plist release];
    return block;
}

/*
 This list is used by check_path().

 These paths are common checks when doing JB detection.
 All of these are regular expressions, matching is not case sensitive.

 This list is far from exhaustive. Add as you see fit.
 TODO: Add ability to extend via Settings

 Call this whenever you want to see if *path contains a jailbreak check string (denyPatterns).

 Returns YES/NO if a JB string was found in *path
 */
BOOL shouldBlockPath(const char *fpath) {
    NSString *path = [[NSString stringWithCString:fpath encoding:NSASCIIStringEncoding] lowercaseString];
    NSArray *denyPatterns = [[NSArray alloc] initWithObjects:
        @"Cydia",
        @"/apt/",
        @"/var/lib/apt",
        @"/var/tmp/cydia.log",
        @"/etc/apt/",
        @"/var/cache/apt",
        @"/bin/bash",
        @"/bin/sh",
        @"/Applications/Cydia.app",
        @"MobileSubstrate",
        @"/stash",
        @"evasi0n",
        @"blackra1n",
        @"l1mera1n",
        @"dpkg",
        @"libhide",
        @"xCon",
        @"libactivator",
        @"libsubstrate",
        @"PreferenceLoader",
        @"sshd",
        @"ssh-key",
        @"/etc/apt",
        @"cydia",
        @"cache/apt",
        @"syslog",
        @"/etc/ssh",
        @"/var/mobile/temp.txt",
        nil];
    BOOL matched = NO;
    for (NSString *regex in denyPatterns) {
        NSRange range = [path rangeOfString:regex options:NSRegularExpressionSearch|NSCaseInsensitiveSearch];
        if (range.location != NSNotFound) {
            ispy_log_info(LOG_GENERAL, "[iSpy] shouldBlockPath: Found match %s with %s", fpath, [regex UTF8String]);
            matched = YES;
            break;
        }
    }
    return matched;
}
