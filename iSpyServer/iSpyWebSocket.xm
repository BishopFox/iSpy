#import "iSpyWebSocket.h"

@implementation iSpyWebSocket

- (void)didOpen
{
    [super didOpen];
    [self sendMessage:@"Welcome to my WebSocket"];
}

- (void)didReceiveMessage:(NSString *)msg
{
    [self sendMessage:[NSString stringWithFormat:@"%@", [NSDate date]]];
}

- (void)didClose
{
    [super didClose];
}

@end
