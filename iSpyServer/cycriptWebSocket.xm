#import "cycriptWebSocket.h"
#include <spawn.h>
#include <sys/ioctl.h>
#include <termios.h>

#ifndef max
    int max(const int x, const int y) {
        return (x > y) ? x : y;
    }
#endif

@implementation CycriptWebSocket

- (void)didOpen {
    int cycriptFd;

    [super didOpen];
    ispy_log_debug(LOG_HTTP, "Opened new Cycript WebSocket connection");
    cycriptFd = [self runCycript];
    ispy_log_debug(LOG_HTTP, "Got SSH fd: %d", cycriptFd);
    [self setCycriptSocket:cycriptFd];
    
    // throw the shoveler ( [SSH PTY] --> [websocket] ) into a background thread
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        fd_set rd;
        char buf[65535];
        int r, nfds, fd1;
        
        fd1 = [self cycriptSocket];
        ispy_log_debug(LOG_HTTP, "Dispatcher. FD = %d", fd1);

        // Loop forever.
        while(1) {
            // ensure things are sane each time around
            nfds = 0;
            FD_ZERO(&rd);
            
            // setup the arrays for monitoring OOB, read, and write events on the 2 sockets
            FD_SET(fd1, &rd);
            nfds = max(nfds, fd1);
            
            // wait for something interesting to happen on a socket, or abort in case of error
            ispy_log_debug(LOG_HTTP, "calling select()");
            if(select(nfds + 1, &rd, NULL, NULL, NULL) == -1)
                return;
            
            // Data ready to read from socket(s)
            if(FD_ISSET(fd1, &rd)) {
                memset(buf, 0, 65535);
                if((r = read(fd1, buf, 65534)) < 1) {
                    return;
                } else {
                    [self sendMessage:[NSString stringWithUTF8String:buf]];
                    ispy_log_debug(LOG_HTTP, "msg from cycript: %s", buf);
                }
            }
        }
    });
    ispy_log_debug(LOG_HTTP, "didOpen finished");
}

- (void)didReceiveMessage:(NSString *)msg {
    ispy_log_debug(LOG_HTTP, "WebSocket Cycript message: %s", [msg UTF8String]);
    char *data = (char *) [msg UTF8String];
    
    // if we get an "S" message from term.js, it's data. Send to cycript.
    if(data[0] == 'S') {
        write([self cycriptSocket], &data[1], (size_t)[msg length]-1);
    } 
    // if we get an "R" message from term.js, it means the screen size changed. Adjust our master PTY accordingly.
    else if(data[0] == 'R') {
        struct winsize ws;
        sscanf(&data[1], "%hd,%hd", &ws.ws_col, &ws.ws_row);
        ispy_log_debug(LOG_HTTP, "R: rows: %hd, cols: %hd", ws.ws_row, ws.ws_col);

        ioctl([self cycriptSocket], TIOCSWINSZ, &ws);
    }
}

- (void)didClose {
    ispy_log_debug(LOG_HTTP, "WebSocket Cycript connection closed, waiting...");
    int info;
    wait(&info);
    ispy_log_debug(LOG_HTTP, "Zombies reaped. Closing...");
    [super didClose];
}

-(int) runCycript {
    pid_t realPID = getpid();
  
    // create PTY
    ispy_log_debug(LOG_HTTP, "Setting up PTY");
    int fdm = open("/dev/ptmx", O_RDWR);
    grantpt(fdm);
    unlockpt(fdm);
    int fds = open(ptsname(fdm), O_RDWR, 0666);

    // Launch cycript using SSH
    ispy_log_debug(LOG_HTTP, "Launching. fdm: %d // fds: %d", fdm, fds);
    doexec(fds, realPID);

    ispy_log_debug(LOG_HTTP, "Returning from runCycript");

    // we need a non-blocking file descriptor for big buffered reads in the select() loop
    int flags = fcntl(fdm, F_GETFL, 0);
    if(flags != -1) {
        flags |= O_NONBLOCK;
        fcntl(fdm, F_SETFL, flags);    
    }
    return fdm;
}

@end

static pid_t doexec(int sock, pid_t pid) {
    char buf[128];
    pid_t sshPID;
    
    // Setup the command and environment
    snprintf(buf, 128, "/usr/bin/cycript -p %d", pid);
    const char *prog[] = { "/usr/bin/ssh", "-t", "-t", "-p", "1337", "-i", "/var/mobile/.ssh/id_rsa", "-o", "StrictHostKeyChecking no", "mobile@127.0.0.1", buf, NULL };
    const char *envp[] =  { "TERM=xterm-256color", NULL };

    // redirect stdin, stdout and stderr to the slave end of our PTY
    int oldStdin = dup(0);
    int oldStdout = dup(1);
    int oldStderr = dup(2);
    dup2(sock, 0);
    dup2(0, 1);
    dup2(0, 2);
    
    // attach cycript to our process
    posix_spawn(&sshPID, prog[0], NULL, NULL, (char **)prog, (char **)envp);

    // reset our file descriptors
    dup2(oldStdin, 0);
    dup2(oldStdout, 1);
    dup2(oldStderr, 2);
    close(oldStderr);
    close(oldStdout);
    close(oldStdin);

    return sshPID;
}

