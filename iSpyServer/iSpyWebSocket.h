#import <Foundation/Foundation.h>

#import "CocoaHTTPServer/WebSocket.h"
#import "../iSpy.common.h"
#import "../iSpy.rpc.h"

@interface iSpyWebSocket : WebSocket
{

}

@property (assign) RPCHandler *rpcHandler;

-(NSDictionary *)dispatchRPCRequest:(NSString *) JSONString;

@end
