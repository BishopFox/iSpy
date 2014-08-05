#import "iSpyWebSocket.h"
#import "../iSpy.common.h"

@implementation iSpyWebSocket

- (void)didOpen
{
    [super didOpen];
    [self sendMessage:@"Welcome to my WebSocket"];
}

- (void)didReceiveMessage:(NSString *)msg
{
    ispy_log_debug(LOG_HTTP, "WebSocket message: %s", [msg UTF8String]);
    [self sendMessage:[NSString stringWithFormat:@"%@", [NSDate date]]];
}

- (void)didClose
{
    [super didClose];
}

@end
