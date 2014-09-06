#import <Foundation/Foundation.h>

#import "CocoaHTTPServer/WebSocket.h"
#import "../iSpy.common.h"
#import "../iSpy.rpc.h"

@interface ShellWebSocket : WebSocket
{

}
@property (assign) int slavePTY;
@property (assign) int masterPTY;
@property (assign) NSString *cmdLine;
@property (assign) NSDictionary *serviceList;
@property (assign) pid_t SSHPID;
@end
