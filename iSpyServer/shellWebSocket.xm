#import "shellWebSocket.h"
#include <spawn.h>
#include <sys/ioctl.h>
#include <termios.h>

#ifndef max
    static int max(const int x, const int y) {
        return (x > y) ? x : y;
    }
#endif

static void doexec(const char *command);
static int forkNewPTY(int *master, int *slave);

@implementation ShellWebSocket

- (void)didOpen {
    [super didOpen];
    ispy_log_debug(LOG_HTTP, "Opened new Shell WebSocket connection");
}

- (void)didReceiveMessage:(NSString *)msg {
    //ispy_log_debug(LOG_HTTP, "WebSocket Shell message: %s", [msg UTF8String]);
    char *data = (char *) [msg UTF8String];
    
    // if we get an "S" message from term.js, it's data. Send to shell.
    if(data[0] == 'S') {
        write([self masterPTY], &data[1], (size_t)[msg length]-1);
    } 
    // if we get an "R" message from term.js, it means the screen size changed. Adjust our master PTY accordingly.
    // Note: we can only do this in the small time window between allocating a PTY and spawning a new process.
    else if(data[0] == 'R') {
        struct winsize ws;

        sscanf(&data[1], "%hd,%hd", &ws.ws_col, &ws.ws_row);
        ispy_log_debug(LOG_HTTP, "Received resize request. rows: %hd, cols: %hd", ws.ws_row, ws.ws_col);

        ioctl([self masterPTY], TIOCSWINSZ, &ws);
    }
    // if we get an "E" message, it's a launch command
    else if(data[0] == 'E') {
        NSString *cmd = [NSString stringWithUTF8String:&data[1]];

        // handle templated variables:
        //  @@PID@@ = current PID
        cmd = [cmd stringByReplacingOccurrencesOfString:@"@@PID@@" withString:[NSString stringWithFormat:@"%d", getpid()]];
        [self setCmdLine:cmd];
        ispy_log_debug(LOG_HTTP, "WS: received E command: %s", [cmd UTF8String]);
        [self runShell];
    }
}

- (void)didClose {
    ispy_log_debug(LOG_HTTP, "WebSocket Shell connection closed, waiting...");
    int info;

    kill([self SSHPID], SIGQUIT); // ask nicely
    kill([self SSHPID], SIGTERM); // be forceful
    kill([self SSHPID], SIGKILL); // dick punch

    sleep(1);
    
    waitpid([self SSHPID], &info, WNOHANG);
    ispy_log_debug(LOG_HTTP, "Zombies reaped. Closing...");
    [super didClose];
}

-(pid_t) runShell {
    pid_t sshPID;
    int fdm, fds; 
  
    // create PTY
    ispy_log_debug(LOG_HTTP, "Setting up PTY");
    sshPID = forkNewPTY(&fdm, &fds);

    // did the PTY allocator barf?
    if(sshPID == -1) {
        [self stop];
        return -1;
    }

    // setup the data structures
    [self setSSHPID:sshPID];
    [self setMasterPTY:fdm];
    [self setSlavePTY:fds];

    // child / slave / exec'd process
    if(sshPID == 0) {
        doexec([[self cmdLine] UTF8String]);
        // never returns
    }

    // Ok, we're the master / parent / main app

    // throw the shoveler ( [SSH PTY] --> [websocket] ) into a background thread
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        fd_set rd;
        char buf[65535];
        int r, nfds, fd1;
        static int failCount = 0;

        fd1 = [self masterPTY];
        ispy_log_debug(LOG_HTTP, "Dispatcher. FD = %d", fd1);

        // Loop forever.
        while(1) {
            // ensure things are sane each time around
            nfds = 0;
            FD_ZERO(&rd);
            FD_SET(fd1, &rd);
            nfds = max(nfds, fd1);
            
            // wait for something interesting to happen on a socket, or abort in case of error
            if(select(nfds + 1, &rd, NULL, NULL, NULL) == -1) {
                ispy_log_debug(LOG_HTTP, "DISCONNECT by select");
                close([self masterPTY]);
                [self stop];
                return;
            }
            
            // Data ready to read from socket(s)
            if(FD_ISSET(fd1, &rd)) {
                memset(buf, 0, 65535);
                if((r = read(fd1, buf, 65534)) < 1) {
                    ispy_log_debug(LOG_HTTP, "READ failure", ++failCount);
                    // allow for startup delays
                    if(failCount == 3) {
                        ispy_log_debug(LOG_HTTP, "DISCONNECT by read");
                        close([self masterPTY]);
                        if(self->isStarted)
                            [self stop];
                        return;
                    }
                    sleep(1);
                } else {
                    if(r) { // only send messages with length > 0
                        failCount=0;
                        [self sendMessage:[NSString stringWithUTF8String:buf]];
                        //ispy_log_debug(LOG_HTTP, "msg from shell: %s", buf);
                    }
                }
            }
        }
    });

    return sshPID;
}

@end

static int forkNewPTY(int *master, int *slavefd) {
    pid_t childPID;
    int slave, fdm;
    
    // open a handle to a master PTY 
    if((fdm = open("/dev/ptmx", O_RDWR | O_NOCTTY | O_NONBLOCK)) == -1) {
        ispy_log_debug(LOG_HTTP, "ERROR could not open /dev/ptmx");
        return -1;
    }

    // establish proper ownership of PTY device
    if(grantpt(fdm) == -1) {
        ispy_log_debug(LOG_HTTP, "ERROR could not grantpt()");
        return -1;    
    }

    // unlock slave PTY device associated with master PTY device
    if(unlockpt(fdm) == -1) {
        ispy_log_debug(LOG_HTTP, "ERROR could not unlockpt()");
        return -1;
    }

    *master = fdm;

    // child
    if((childPID = fork()) == 0) {
        if((slave = open(ptsname(fdm), O_RDWR | O_NOCTTY)) == -1) {
            ispy_log_debug(LOG_HTTP, "ERROR could not open ptsname(%s)", ptsname(fdm));
            _exit(0);
        }
        // setup PTY and redirect stdin, stdout, stderr to it
        *slavefd = slave;
        setsid();
        ioctl(slave, TIOCSCTTY, 0);
        dup2(slave, 0);
        dup2(slave, 1);
        dup2(slave, 2);
        return 0;
    } 
    // parent
    else {
        return childPID;
    }
}

static void doexec(const char *command) {
    // Setup the command and environment
    const char *prog[] = { "/usr/bin/ssh", "-t", "-t", "-p", "1337", "-i", "/var/mobile/.ssh/id_rsa", "-o", "StrictHostKeyChecking no", "mobile@127.0.0.1", command, NULL };
    const char *envp[] =  { "TERM=xterm-256color", NULL };

    // attach shell to our process
    execve((const char *)prog[0], (char **)prog, (char **)envp);
    // never returns
}

