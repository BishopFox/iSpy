
/*
 ***********************************
 *** C runtime function hooking. ***
 ***********************************

 Once a function is hooked, its original (unhooked) version is saved in the orig_* pointers.
 We can use these to call the original unhooked functions.

 The format for hooking C calls is:
 FUNCNAME        - the function we're hooking
 bf_FUNCNAME     - our new function. Overrides FUNCNAME. Define it below, along with the other bf_* functions.
 orig_FUNCNAME   - pointer to original FUNCNAME. We can call this :)

 The orig_FUNCNAME return types and argument lists must match the original EXACTLY.
 (unless you're a hardcore motherfucker and are deliberately munging data types for an epic hack. Caveat emptor.)
 Consult man pages and/or other documentation for copy pasta. I got most of these from man.
 */


//
// Declarations of replacement funcs
//
DIR *bf_opendir(const char *dirname);
struct dirent *bf_readdir(DIR *dirp);
int bf_readdir_r(DIR *dirp, struct dirent *entry, struct dirent **result);
int bf_memcmp(const void *s1, const void *s2, size_t n);
int bf_strcmp(const char *s1, const char *s2);
int bf_strncmp(const char *s1, const char *s2, int n);
int bf_open(const char *path, int oflag, ...);
pid_t bf_fork(void);
int bf_fstat(int fildes, struct stat *buf);
int bf_lstat(const char *path, struct stat *buf);
int bf_stat(const char *path, struct stat *buf);
int bf_access(const char *path, int amode);
int bf_statfs(const char *path, struct statfs *buf);
int bf_fstatfs(int fd, struct statfs *buf);
bool bf_dlopen_preflight(const char* path);
uint32_t bf_dyld_image_count(void);
const char* bf_dyld_get_image_name(uint32_t id);
int bf_bind(int socket, const struct sockaddr *address, socklen_t address_len);
int bf_accept(int socket, struct sockaddr *address, socklen_t *address_len);
ssize_t bf_recv(int socket, void *buffer, size_t length, int flags);
int bf_ioctl(int fildes, unsigned long request, ...);
int bf_sysctl(int *name, u_int namelen, void *old, size_t *oldlenp, void *_new, size_t newlen);
int bf_acct(const char *path);
int bf_adjtime(struct timeval *delta, struct timeval *olddelta);
int bf_chdir(const char * path);
int bf_chflags(char *path, int flags);
int bf_chmod(const char * path, mode_t mode);
int bf_chown(const char * path, uid_t uid, gid_t gid);
int bf_chroot(const char * path);
int bf_close(int fd);
int bf_dup(u_int fd);
int bf_dup2(u_int from, u_int to);
int bf_execve(char *fname, char **argp, char **envp);
int bf_fchdir(int fd);
int bf_fchflags(int fd, int flags);
int bf_fchmod(int fd, int mode);
int bf_fchown(int fd, uid_t uid, gid_t gid);
int bf_fcntl(int fd, int cmd, long arg);
int bf_flock(int fd, int how);
int bf_fpathconf(int fd, int name);
int bf_fsync(int fd);
int bf_ftruncate(int fd, off_t length);
int bf_futimes(int fd, struct timeval *tptr);
int bf_getdtablesize(void);
int bf_getegid(void);
int bf_geteuid(void);
int bf_getfh(char *fname, fhandle_t *fhp);
int bf_getfsstat(struct statfs * buf, int bufsize, int flags);
int bf_getgid(void);
int bf_getgroups(u_int gidsetsize, gid_t *gidset);
int bf_gethostuuid(unsigned char *uuid_buf, const struct timespec *timeoutp);
int bf_getitimer(u_int which, struct itimerval *itv);
int bf_getlogin(char *namebuf, u_int namelen);
int bf_getpeername(int fdes, struct sockaddr * asa, socklen_t *alen);
int bf_getpgid(pid_t pid);
int bf_getpgrp(void);
pid_t bf_getpid(void);
int bf_getppid(void);
int bf_getpriority(int which, id_t who);
int bf_getrlimit(u_int which, struct rlimit *rlp);
int bf_getrusage(int who, struct rusage *rusage);
int bf_getsockname(int fdes, struct sockaddr * asa, socklen_t *alen);
int bf_getsockopt(int s, int level, int name, struct sockaddr * val, socklen_t *avalsize);
int bf_gettimeofday(struct timeval *tp, struct timezone *tzp);
int bf_getuid(void);
int bf_kill(int pid, int signum, int posix);
int bf_link(const char * path, const char * link);
int bf_listen(int s, int backlog);
int bf_madvise(struct sockaddr * addr, size_t len, int behav);
int bf_mincore(const char * addr, user_size_t len, const char * vec);
int bf_mkdir(const char * path, int mode);
int bf_mkfifo(const char * path, int mode);
int bf_mknod(const char * path, int mode, int dev);
int bf_mlock(struct sockaddr * addr, size_t len);
int bf_mount(char *type, char *path, int flags, struct sockaddr * data);
int bf_mprotect(struct sockaddr * addr, size_t len, int prot);
int bf_msync(struct sockaddr * addr, size_t len, int flags);
int bf_munlock(struct sockaddr * addr, size_t len);
int bf_munmap(struct sockaddr * addr, size_t len);
int bf_nfssvc(int flag, struct sockaddr * argp);
int bf_pathconf(char *path, int name);
int bf_pipe(void);
int bf_ptrace(int req, pid_t pid, struct sockaddr * addr, int data);
int bf_quotactl(const char *path, int cmd, int uid, struct sockaddr * arg);
int bf_readlink(char *path, char *buf, int count);
int bf_reboot(int opt, char *command);
int bf_recvmsg(int s, struct msghdr *msg, int flags);
int bf_rename(char *from, char *to);
int bf_revoke(char *path);
int bf_rmdir(char *path);
int bf_select(int nd, u_int32_t *in, u_int32_t *ou, u_int32_t *ex, struct timeval *tv);
int bf_sendmsg(int s, struct sockaddr * msg, int flags);
int bf_sendto(int s, struct sockaddr * buf, size_t len, int flags, struct sockaddr * to, socklen_t tolen);
int bf_setegid(gid_t egid);
int bf_seteuid(uid_t euid);
int bf_setgid(gid_t gid);
int bf_setgroups(u_int gidsetsize, gid_t *gidset);
int bf_setitimer(u_int which, struct itimerval *itv, struct itimerval *oitv);
int bf_setlogin(char *namebuf);
int bf_setpgid(int pid, int pgid);
int bf_setpriority(int which, id_t who, int prio);
int bf_setregid(gid_t rgid, gid_t egid);
int bf_setreuid(uid_t ruid, uid_t euid);
int bf_setrlimit(u_int which, struct rlimit *rlp);
int bf_setsid(void);
int bf_setsockopt(int s, int level, int name, struct sockaddr * val, socklen_t valsize);
int bf_settimeofday(struct timeval *tv, struct timezone *tzp);
int bf_setuid(uid_t uid);
int bf_shutdown(int s, int how);
int bf_sigaction(int signum, struct __sigaction *nsa, struct sigaction *osa);
int bf_sigpending(struct sigvec *osv);
int bf_sigprocmask(int how, const char * mask, const char * omask);
int bf_sigsuspend(sigset_t mask);
int bf_socket(int domain, int type, int protocol);
int bf_socketpair(int domain, int type, int protocol, int *rsv);
int bf_swapon(void);
int bf_symlink(char *path, char *link);
void bf_sync(void);
int bf_truncate(char *path, off_t length);
int bf_umask(int newmask);
int bf_undelete(const char * path);
int bf_unlink(const char * path);
int bf_unmount(const char * path, int flags);
int bf_utimes(char *path, struct timeval *tptr);
int bf_vfork(void);
int bf_wait4(int pid, const char * status, int options, const char * rusage);
int bf_waitid(idtype_t idtype, id_t id, siginfo_t *infop, int options);
off_t bf_lseek(int fd, off_t offset, int whence);
void *bf_mmap(struct sockaddr * addr, size_t len, int prot, int flags, int fd, off_t pos);
user_ssize_t bf_pread(int fd, const char * buf, user_size_t nbyte, off_t offset);
user_ssize_t bf_pwrite(int fd, const char * buf, user_size_t nbyte, off_t offset);
user_ssize_t bf_read(int fd, const char * cbuf, user_size_t nbyte);
user_ssize_t bf_readv(int fd, struct iovec *iovp, u_int iovcnt);
user_ssize_t bf_write(int fd, const char * cbuf, user_size_t nbyte);
user_ssize_t bf_writev(int fd, struct iovec *iovp, u_int iovcnt);
void bf_exit(int rval);

int	ptrace(int _request, pid_t _pid, struct sockaddr * _addr, int _data);
int bf_system(const char *command);
