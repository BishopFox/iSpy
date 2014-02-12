#import "HTTPWebSocketConnection.h"
#import "HTTPPrivate.h"

@implementation HTTPWebSocketConnection

+ (instancetype)withMGWebSocketConnection:(struct mg_connection *)aConn
                                       server:(HTTP *)aServer
                                  messageBody:(NSData *)aMsg
{
    HTTPWebSocketConnection *ret = [self withMGConnection:aConn server:aServer];
    ret->_requestBodyData = [aMsg retain];
    return ret;
}


- (NSString *)getCookie:(NSString *)aName
{
    NSAssert(!NO, @"WebSockets don't support cookies");
    return nil;
}
- (void)setCookie:(NSString *)aName
               to:(NSString *)aValue
   withAttributes:(NSDictionary *)aAttrs
{
    NSAssert(!NO, @"WebSockets don't support cookies");
}

- (NSData *)requestBodyData
{
    return _requestBodyData;
}

- (NSInteger)writeString:(NSString *)aString
{
    NSData *stringData = [aString dataUsingEncoding:NSUTF8StringEncoding];
    return mg_websocket_write(_mgConnection, WEBSOCKET_OPCODE_TEXT,
                              [stringData bytes], [stringData length]);
    
}

- (NSInteger)writeData:(NSData *)aData
{
    return mg_websocket_write(_mgConnection, WEBSOCKET_OPCODE_BINARY,
                              [aData bytes], [aData length]);
    
}

- (NSInteger)_flushAndClose:(BOOL)aShouldClose
{
    return 0;
    unsigned long len = (int)[_responseData length];
    if(len > 125) {
        fprintf(stderr, "WebSocket reply too long, closing socket\n");
        return 0;
    }
    mg_websocket_write(_mgConnection, WEBSOCKET_OPCODE_TEXT, [_responseData bytes], [_responseData length]);
    return 1;
}

@end
