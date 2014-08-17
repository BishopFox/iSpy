#import "iSpyWebSocket.h"

@implementation iSpyWebSocket

- (void)didOpen
{
    [super didOpen];
    [self setRpcHandler:[[RPCHandler alloc] init]];
    ispy_log_debug(LOG_HTTP, "Opened new WebSocket connection");
}

- (void)didReceiveMessage:(NSString *)msg
{
    ispy_log_debug(LOG_HTTP, "WebSocket message: %s", [msg UTF8String]);
    NSDictionary *response = [self dispatchRPCRequest: msg];
    if (response != nil)
    {
        ispy_log_info(LOG_HTTP, "RPC response is not nil!");
    }
}

- (void)didClose
{
    ispy_log_debug(LOG_HTTP, "WebSocket connection closed");
    [super didClose];
}

// Pass this an NSString containing a JSON-RPC request.
// It will do sanity/security checks, then dispatch the method, then return an NSDictionary as a return value.
-(NSDictionary *)dispatchRPCRequest:(NSString *) JSONString {
    NSData *RPCRequest = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
    if ( ! RPCRequest)
    {
        ispy_log_error(LOG_HTTP, "Could not convert websocket payload into NSData");
        return nil;
    }

    // create a dictionary from the JSON request
    NSDictionary *RPCDictionary = [NSJSONSerialization JSONObjectWithData:RPCRequest options:kNilOptions error:nil];
    if ( ! RPCDictionary)
    {
        ispy_log_error(LOG_HTTP, "invalid RPC request, couldn't deserialze the JSON data.");
        return nil;
    }

    // is this a valid request? (does it contain both "messageType" and "messageData" entries?)
    if ( ! [RPCDictionary objectForKey:@"messageType"] || ! [RPCDictionary objectForKey:@"messageData"])
    {
        ispy_log_error(LOG_HTTP, "Invalid RPC request; must have messageType and messageData.");
        return nil;
    }

    // Verify that the iSpy RPC handler class can execute the requested selector
    NSString *selectorString = [RPCDictionary objectForKey:@"messageType"];
    SEL selectorName = sel_registerName([[NSString stringWithFormat:@"%@:", selectorString] UTF8String]);
    if ( ! selectorName)
    {
        ispy_log_error(LOG_HTTP, "selectorName was null.");
        return nil;
    }
    if ( ! [[self rpcHandler] respondsToSelector:selectorName] )
    {
        ispy_log_error(LOG_HTTP, "doesn't respond to selector");
        return nil;
    }

    // Do it!
    ispy_log_debug(LOG_HTTP, "Dispatching request for: %s", [selectorString UTF8String]);
    NSMutableDictionary *responseDict = [[self rpcHandler] performSelector:selectorName withObject:[RPCDictionary objectForKey:@"messageData"]];
    return responseDict;
}

@end
