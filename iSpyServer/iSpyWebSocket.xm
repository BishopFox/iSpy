#import "iSpyWebSocket.h"
#import "../iSpy.common.h"
#import "../iSpy.class.h"


@implementation iSpyWebSocket

- (void)didOpen
{
    [super didOpen];
    ispy_log_debug(LOG_HTTP, "Opened new WebSocket connection");
}

- (void)didReceiveMessage:(NSString *)msg
{
    ispy_log_debug(LOG_HTTP, "WebSocket message: %s", [msg UTF8String]);

    /*
     * We don't block on RPC requests over the websocket, JSON responses are sent to all
     * open sockets to keep all the views in sync with each other.
     *
     * TODO: We should broadcast to all sockets if the RPC request was a non-fetch()
     */
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSDictionary *response = [[[iSpy sharedInstance] webServer] dispatchRPCRequest: msg];
        if (response != nil)
        {
            ispy_log_info(LOG_HTTP, "RPC response is not nil for: %s", [msg UTF8String]);
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
            NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

            /* If the RPC request only resulted in a read, then don't broadcast the data */
            if ([response objectForKey:@"operation"] != nil && [[response objectForKey:@"operation"] isEqualToString:@"read"])
            {
                [self sendMessage: json];
            }
            else
            {
                [[[[iSpy sharedInstance] webServer] httpServer] ispySocketBroadcast: json];
            }
        }
    });
}

- (void)didClose
{
    ispy_log_debug(LOG_HTTP, "WebSocket connection closed");
    [super didClose];
}

@end
