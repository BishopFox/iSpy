#import "mongoose.h"
#import "HTTPConnection.h"
#import "HTTPWebSocketConnection.h"
#import "NSBlockUtilities.h"
#import "FABatching.h"

@interface HTTPConnection () {
    @protected
    struct mg_connection *_mgConnection;
    NSMutableData *_responseData;
    BOOL _wroteHeaders;
    
    NSData *_requestBodyData;
    long _requestLength;
    NSMutableDictionary *_cookiesToWrite, *_responseHeaders, *_requestMultipartSegments;
    FA_BATCH_IVARS
}
@property(readwrite, assign) struct mg_connection *mgConnection;
@property(readwrite, assign) struct mg_request_info *mgRequest;
@property(readwrite, strong, nonatomic) NSData *requestBodyData;
@property(readwrite, assign) BOOL isWebSocket, isOpen;
+ (instancetype)withMGConnection:(struct mg_connection *)aConn server:(HTTP *)aServer;
- (NSInteger)_flushAndClose:(BOOL)aShouldClose;
- (NSString *)_getVar:(NSString *)aName inBuffer:(const void *)aBuf length:(long)aLen;
@end

@interface HTTPWebSocketConnection ()
+ (instancetype)withMGWebSocketConnection:(struct mg_connection *)aConn
                                       server:(HTTP *)aServer
                                  messageBody:(NSData *)aMsg;
@end
