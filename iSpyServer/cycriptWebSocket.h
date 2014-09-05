#import <Foundation/Foundation.h>

#import "CocoaHTTPServer/WebSocket.h"
#import "../iSpy.common.h"
#import "../iSpy.rpc.h"

@interface CycriptWebSocket : WebSocket
{

}
@property (assign) int cycriptSocket;

@end

static pid_t doexec(int sock, pid_t pid);