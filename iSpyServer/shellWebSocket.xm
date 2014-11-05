#import "ShellWebSocket.h"
#include <spawn.h>
#include <sys/ioctl.h>
#include <termios.h>

#define BUFSIZE 65536
#define MAX_READ_FAILURES 3

#ifndef max
    static int max(const int x, const int y) {
        return (x > y) ? x : y;
    }
#endif

@implementation ShellWebSocket

// callback for CocoaHTTPServer WebSocket class
- (void)didOpen {
    [super didOpen];
    
    ispy_log_debug(LOG_HTTP, "Opened new Shell WebSocket connection. Launching %s", [[self cmdLine] UTF8String]);
    
    // launch the command. This handles PTY allocation, forking, execve(), etc.
    [self runShell];
}

// callback for CocoaHTTPServer WebSocket class
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
}

// callback for CocoaHTTPServer WebSocket class
-(void)didClose {
    ispy_log_debug(LOG_HTTP, "WebSocket Shell connection closed, waiting...");
    int info;

    // we need to stop the SSH client and user-specifiec program.
    kill([self sshPID], SIGQUIT); // ask nicely
    kill([self sshPID], SIGTERM); // be forceful
    kill([self sshPID], SIGKILL); // dick punch

    // let the duct settle
    sleep(1);
    
    // be a good netizen
    waitpid([self sshPID], &info, WNOHANG);

    ispy_log_debug(LOG_HTTP, "Zombies reaped. Closing...");
    
    // child process, PTY, websocket, etc are all gone. Session over.
    [super didClose];
}

-(void) runShell {
    // create PTY. This will fork(2) here.
    ispy_log_debug(LOG_HTTP, "Setting up PTY");
    if([self forkNewPTY] == -1 || self.sshPID == -1) {
        [self stop];
        return;
    }

    // child process will execve(ssh) on the new PTY
    if(self.sshPID == 0) {
        [self doexec];
        // never returns
    }

    // start a background thread to shovel data from the master PTY to the websocket
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self pipeDataToWebsocket];
    });

    return;
}

-(void) pipeDataToWebsocket {
    fd_set readSet;
    char buf[BUFSIZE];
    int numBytes, numFileDescriptors;
    static int failCount = 0;

    int fdMasterPTY = [self masterPTY];
    ispy_log_debug(LOG_HTTP, "pipeDataToWebsocket from master PTY %d", fdMasterPTY);

    // Loop forever.
    while(1) {
        // ensure things are sane each time around
        numFileDescriptors = 0;
        FD_ZERO(&readSet);
        FD_SET(fdMasterPTY, &readSet);
        numFileDescriptors = max(numFileDescriptors, fdMasterPTY);
        
        // wait for something interesting to happen on a socket, or abort in case of error
        if(select(numFileDescriptors + 1, &readSet, NULL, NULL, NULL) == -1) {
            ispy_log_debug(LOG_HTTP, "DISCONNECT by select");
            close([self masterPTY]);
            [self stop];
            return;
        }
        
        // Data ready to read from socket(s)
        if(FD_ISSET(fdMasterPTY, &readSet)) {
            // clear the read buffer
            memset(buf, 0, BUFSIZE);

            // read the contents of the slave PTY queue, or BUFSIZE-1, whichever is smaller
            if((numBytes = read(fdMasterPTY, buf, BUFSIZE-1)) < 1) {
                // Ok, crap. A read(2) error occured. 
                // Maybe the child process hasn't started yet.
                // Maybe the child process terminated.
                // Let's handle this a little gracefully.
                ispy_log_debug(LOG_HTTP, "READ failure (%d of %d)", ++failCount, MAX_READ_FAILURES);
                
                // retry the read(2) operation 3 times before giving up
                if(failCount == MAX_READ_FAILURES) {
                    ispy_log_debug(LOG_HTTP, "Three consecutive read(2) failures. Abandon ship.");
                    
                    // the master PTY needs to be closed.
                    close([self masterPTY]);

                    // if we haven't aready done so, shutdown this websocket
                    if(self->isStarted)
                        [self stop];

                    return;
                }

                sleep(1); // pause to let things settle before retrying
            // Ok, we got some data!
            } else {
                // reset the failure counter. 
                failCount=0; 

                // pass the data from the child process to the websocket, where it's passed to the browser.
                [self sendMessage:[NSString stringWithUTF8String:buf]];
                //ispy_log_debug(LOG_HTTP, "msg from shell: %s", buf);
            }
        }
    } 
}

-(int) forkNewPTY {
    // open a handle to a master PTY 
    if((self.masterPTY = open("/dev/ptmx", O_RDWR | O_NOCTTY | O_NONBLOCK)) == -1) {
        ispy_log_debug(LOG_HTTP, "ERROR could not open /dev/ptmx");
        return -1;
    }

    // establish proper ownership of PTY device
    if(grantpt(self.masterPTY) == -1) {
        ispy_log_debug(LOG_HTTP, "ERROR could not grantpt()");
        return -1;    
    }

    // unlock slave PTY device associated with master PTY device
    if(unlockpt(self.masterPTY) == -1) {
        ispy_log_debug(LOG_HTTP, "ERROR could not unlockpt()");
        return -1;
    }

    // child
    if((self.sshPID = fork()) == 0) {
        if((self.slavePTY = open(ptsname(self.masterPTY), O_RDWR | O_NOCTTY)) == -1) {
            ispy_log_debug(LOG_HTTP, "ERROR could not open ptsname(%s)", ptsname(self.masterPTY));
            return -1;
        }
        // setup PTY and redirect stdin, stdout, stderr to it
        setsid();
        ioctl(self.slavePTY, TIOCSCTTY, 0);
        dup2(self.slavePTY, 0);
        dup2(self.slavePTY, 1);
        dup2(self.slavePTY, 2);
        close(self.masterPTY);
        return 0;
    } 
    // parent
    else {
        return self.sshPID;
    }
}

-(void) doexec {
    // Setup the command and environment
    const char *prog[] = { "/usr/bin/cycript", "-r", "127.0.0.1:12345", NULL };
    const char *envp[] = { "TERM=xterm-256color", NULL };

    // replace current process with cycript
    execve((const char *)prog[0], (char **)prog, (char **)envp);
    
    // never returns
}

@end

