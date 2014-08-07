#import "iSpyWebSocket.h"
#import "../iSpy.common.h"

@implementation iSpyWebSocket

- (void)didOpen
{
    [super didOpen];
    ispy_log_info(LOG_HTTP, "Opened new WebSocket connection");
    [self sendMessage:@"{'opcode': 'hello'}"];
}

- (void)didReceiveMessage:(NSString *)msg
{
    ispy_log_debug(LOG_HTTP, "WebSocket message: %s", [msg UTF8String]);
    [self sendMessage:[NSString stringWithFormat:@"%@", [NSDate date]]];
}

- (void)didClose
{
    ispy_log_info(LOG_HTTP, "WebSocket connection closed");
    [super didClose];
}

@end
