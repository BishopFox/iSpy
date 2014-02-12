#import "HTTPConnection.h"
#import "HTTPPrivate.h"
#import "HTTP.h"
#import "OnigRegexp.h"
#import <arpa/inet.h>

#define _ntohll(y) (((uint64_t)ntohl(y)) << 32 | ntohl(y>>32))

@implementation HTTPConnection

+ (HTTPConnection *)withMGConnection:(struct mg_connection *)aConn server:(HTTP *)aServer
{
    HTTPConnection *ret = [self new];
    ret.mgConnection = aConn;
    ret.mgRequest    = mg_get_request_info(aConn);
    ret.server       = aServer;
    return [ret autorelease];
}

- (id)init
{
    if(!(self = [super init]))
        return nil;
    _status             = 200;
    _reason             = @"OK";
    _isOpen             = YES;
    _isStreaming        = NO;
    _shouldWriteHeaders = YES;
    _wroteHeaders       = NO;
    if(_requestLength != -1) { // Only initialize if this is not a recycled object
        _requestLength   = -1;
        _responseData    = [NSMutableData new];
        _cookiesToWrite  = [NSMutableDictionary new];
        _responseHeaders = [NSMutableDictionary new];
    }
    [_responseHeaders setObject:@"text/html; charset=utf-8" forKey:@"Content-Type"];
    return self;
}

- (NSString *)_cookieHeader
{
    if(![_cookiesToWrite count])
        return nil;

    NSMutableString *header = [NSMutableString string];
    for(NSString *name in _cookiesToWrite) {
        NSDictionary *cookie = _cookiesToWrite[name];
        [header appendString:@"Set-Cookie: "];
        [header appendString:name];
        [header appendString:@"="];
        [header appendString:cookie[@"value"]];
        NSDictionary *attribs = cookie[@"attributes"];
        for(NSString *attrName in attribs) {
            [header appendString:@"; "];
            [header appendString:attrName];
            [header appendString:@"="];
            [header appendString:[attribs[attrName] description]];
        }
    }
    [header appendString:@"\r\n"];
    return header;
}


- (void)makeStreaming
{
    _isStreaming = YES;
}

- (NSInteger)flushData
{
    return [self _flushAndClose:!_isStreaming];
}

- (NSInteger)_flushAndClose:(BOOL)aShouldClose
{
    int bytesWritten = 0;
    if(!_wroteHeaders && _shouldWriteHeaders) {
        char date[80];
        time_t curtime = time(NULL);
        strftime(date, sizeof(date), "%a, %d %b %Y %H:%M:%S GMT", gmtime(&curtime));
        NSMutableString *headerStr;
        if(aShouldClose)
            headerStr = [NSMutableString stringWithFormat:
                         @"HTTP/1.1 %d %@\r\n"
                         @"Connection: keep-alive\r\n"
                         @"Content-Length: %ld\r\n"
                         @"Date: %s\r\n",
                         _status, _reason, (long)[_responseData length], date];
        else
            headerStr = [NSMutableString stringWithFormat:
                         @"HTTP/1.1 %d %@\r\n"
                         @"Connection: keep-alive\r\n"
                         @"Date: %s\r\n",
                         _status, _reason, date];
        
        for(NSString *header in _responseHeaders) {
            [headerStr appendString:header];
            [headerStr appendString:@": "];
            [headerStr appendString:_responseHeaders[header]];
            [headerStr appendString:@"\r\n"];
        }
        NSString *cookieStr = [self _cookieHeader];
        if(cookieStr)
            [headerStr appendString:cookieStr];
        [headerStr appendString:@"\r\n"];
        
        const char *bytes = [headerStr UTF8String];
        size_t byteLen = strlen(bytes);
        bytesWritten += mg_write(_mgConnection, bytes, byteLen);
        if(bytesWritten < byteLen)
            goto invalidConnection;
        
        _wroteHeaders = YES;
    }
    
    if([_responseData length] > 0) {
        NSUInteger responseLength = [_responseData length];
        int responseBytesWritten = mg_write(_mgConnection,
                                            [_responseData bytes],
                                            responseLength);
        [_responseData setLength:0];
        bytesWritten += responseBytesWritten;
        
        if(responseBytesWritten < responseLength)
            goto invalidConnection;
    }
    
    if(aShouldClose)
        [self close];
    
    return bytesWritten;

invalidConnection:
    [self close];
    return -1;
}


- (void)serveFileAtPath:(NSString *)aPath
{
    NSAssert(!_wroteHeaders, @"Tried to serve a file over a connection that already has data written to it!");
    mg_send_file(_mgConnection, [aPath fileSystemRepresentation]);
    [self close];
}

- (NSInteger)writeData:(NSData *)aData
{
    NSAssert(_isOpen, @"Tried to write data to a closed connection");
    [_responseData appendData:aData];
    if(_isStreaming)
        return [self flushData];
    else
        return [aData length];
}

- (NSInteger)writeString:(NSString *)aString
{
    return [self writeData:[aString dataUsingEncoding:NSUTF8StringEncoding]];
}
- (NSInteger)writeFormat:(NSString *)aFormat, ...
{
    va_list args;
    va_start(args, aFormat);
    NSString *str = [[NSString alloc] initWithFormat:aFormat arguments:args];
    va_end(args);
    return [self writeString:[str autorelease]];
}


#pragma mark -

- (NSString *)getCookie:(NSString *)aName
{
    const char *cookieHedader = mg_get_header(_mgConnection, "Cookie");
    char buf[1024];
    
    if(cookieHedader && mg_get_cookie(cookieHedader, [aName UTF8String], buf, 1024) > 0)
        return [NSString stringWithUTF8String:buf];
    return nil;
}

- (void)setCookie:(NSString *)aName
               to:(NSString *)aValue
{
    [self setCookie:aName to:aValue withAttributes:nil];
}

- (void)setCookie:(NSString *)aName
               to:(NSString *)aValue
   withAttributes:(NSDictionary *)aAttrs
{
    NSAssert(!_isWebSocket, @"WebSockets don't support cookies");
    NSParameterAssert(aName && aValue);
    _cookiesToWrite[aName] = @{ @"value": aValue, @"attributes": aAttrs ?: @{} };
}

- (void)setCookie:(NSString *)aName
               to:(NSString *)aValue
          expires:(NSDate *)aExpiryDate
{
    time_t time = [aExpiryDate timeIntervalSince1970];
    struct tm timeStruct;
    localtime_r(&time, &timeStruct);
    char buffer[80];
    
    strftime(buffer, 80, "%a, %d-%b-%Y %H:%M:%S GMT", &timeStruct);
    NSString *dateStr = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
    [self setCookie:aName to:aValue withAttributes:@{ @"Expires": dateStr } ];
}

- (long)requestLength
{
    if(_requestLength != -1)
        return _requestLength;
    const char *lenHeader = mg_get_header(_mgConnection, "Content-Length");
    if(lenHeader)
        _requestLength = atol(lenHeader);
    return _requestLength;
}

- (NSString *)queryString
{
    const char *str = _mgRequest->query_string;
    if(str)
        return [NSString stringWithUTF8String:str];
    return nil;
}

- (BOOL)requestIsMultipart
{
    const char *contentHeader = mg_get_header(_mgConnection, "Content-Type");
    if(contentHeader && strstr(contentHeader, "multipart/form-data") == contentHeader)
        return YES;
    return NO;
}

- (NSString *)requestBody
{
    NSData *body = self.requestBodyData;
    if([body length])
        return [[[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] autorelease];
    return nil;
}

- (NSData *)requestBodyData
{
    if(!_requestBodyData) {
        if(self.requestIsMultipart)
            return nil;
        else if(!_isWebSocket) {
            long len = self.requestLength;
            if(len == 0)
                return nil;
            else if(len > 0) {
                NSMutableData *data = [NSMutableData dataWithLength:len];
                mg_read(_mgConnection, [data mutableBytes], [data length]);
                self.requestBodyData = data;
            } else {
                NSMutableData *data = [NSMutableData data];
                void *buf = malloc(1024);
                int bytesRead;
                while((bytesRead = mg_read(_mgConnection, buf, 1024))) {
                    [data appendBytes:buf length:bytesRead];
                }
                free(buf);
                if([data length])
                    self.requestBodyData = data;
            }
        }
    }
    return _requestBodyData;
}

- (NSDictionary *)requestMultipartSegments
{
    return nil;
// TODO
//    if(_requestMultipartSegments)
//        return _requestMultipartSegments;
//    if(![self requestIsMultipart])
//        return nil;
//    _requestMultipartSegments = [NSMutableDictionary new];
//    
//    // We need to deal with the different parts
//    const char *contentHeader = mg_get_header(_mgConnection, "Content-Type");
//    char boundary[100] = {0};
//    int found = sscanf(contentHeader, "multipart/form-data; boundary=%99s", boundary);
//    if(!found)
//        [NSException raise:NSInternalInconsistencyException
//                    format:@"Invalid request: no multipart boundary"];
//
//    size_t boundaryLen = strlen(boundary);
//    const int bufSize = 10*1024;
//    char *buf = malloc(bufSize);
//    mg_read(_mgConnection, buf, 2); // \r\n
//    FILE *handle;
//    NSMutableDictionary *currSeg = nil;
//    char scanBuf[1024], nameFieldBuf[11];
//    int bytesRead, ofs, startOfs;
//    while((bytesRead = mg_read(_mgConnection, buf, bufSize))) {
//        ofs = 0;
//        if(!currSeg) {
//        newSegment:
//            ofs += boundaryLen + 2; // Skip over the boundary & \r\n
//
//            // Create a temp file to write to
//            handle = tmpfile();
//            assert(handle);
//            currSeg = [@{
//                @"handle": [[[NSFileHandle alloc] initWithFileDescriptor:fileno(handle)
//                                                          closeOnDealloc:YES] autorelease]
//            } mutableCopy];
//
//            // Read name/filename from content-disposition header
//            nameFieldBuf[0] = '\0';
//            sscanf(buf+ofs, "Content-Disposition: form-data; %10[^=]=\"%1023[^\"]",
//                   nameFieldBuf, scanBuf);
//            if(strcmp(nameFieldBuf, "name") == 0)
//                currSeg[@"name"] = [NSString stringWithUTF8String:scanBuf];
//            else if(strcmp(nameFieldBuf, "filename") == 0)
//                currSeg[@"filename"] = [NSString stringWithUTF8String:scanBuf];
//            else
//                [NSException raise:NSInternalInconsistencyException
//                            format:@"Invalid content disposition"];
//            ofs += 35 + strlen(nameFieldBuf) + strlen(scanBuf);
//
//            nameFieldBuf[0] = '\0';
//            sscanf(buf+ofs, "; %10[^=]=\"%1023[^\"]", nameFieldBuf, scanBuf);
//            if(strcmp(nameFieldBuf, "name") == 0)
//                currSeg[@"name"] = [NSString stringWithUTF8String:scanBuf];
//            else if(strcmp(nameFieldBuf, "filename") == 0)
//                currSeg[@"filename"] = [NSString stringWithUTF8String:scanBuf];
//            if(strlen(nameFieldBuf) > 0)
//                ofs += 5 + strlen(nameFieldBuf) + strlen(scanBuf);
//            ofs += 2; // \r\n
//
//            NSAssert(currSeg[@"name"], @"Malformed request");
//            _requestMultipartSegments[currSeg[@"name"]] = currSeg;
//            [currSeg release];
//
//            // Read Content-Type header
//            scanBuf[0] = '\0';
//            sscanf(buf+ofs, "Content-Type: %1023s", scanBuf);
//            if(strlen(scanBuf))
//                currSeg[@"contentType"] = [NSString stringWithUTF8String:scanBuf];
//
//            // Seek past any other headers (\r\n\r\n)
//            do {
//                ofs += 1;
//            } while(ofs < (bytesRead-4) && strncmp(buf+ofs, "\r\n\r\n", 4));
//            if(ofs >= bufSize-4)
//                [NSException raise:NSInternalInconsistencyException
//                            format:@"Malformed request"];
//            ofs += 4;
//        }
//        startOfs = ofs;
//
//        // Read segment contents
//        // We read the file, looking for --; when encountered,
//        // we compare the following data with the boundary
//        char *p0, *p1;
//        while(ofs < bytesRead) {
//            p0 = buf+ofs;
//            p1 = buf+ofs+1;
//
//            if((*p0 == '-' && *p1 == '-')
//               && (ofs < bytesRead - boundaryLen)
//               && (strncmp(buf+ofs+2, boundary, boundaryLen) == 0)) {
//                fwrite(buf+startOfs, sizeof(char), ofs-startOfs-2, handle);
//                ofs += 2; // Skip over the '--', boundary is handled in the next iteration
//                rewind(handle);
//                if(!currSeg[@"filename"]) {
//                    // If it's not a file, we just load the string value to make things easy
//                    NSData *strData = [currSeg[@"handle"] readDataToEndOfFile];
//                    rewind(handle);
//                    NSString *strVal = [[NSString alloc] initWithData:strData
//                                                             encoding:NSUTF8StringEncoding];
//                    currSeg[@"value"] = strVal ?: @"invalid encoding";
//                    [strVal release];
//                }
//                if(strncmp(buf+ofs+boundaryLen, "--", 2) != 0)
//                    goto newSegment;
//                else
//                    goto doneProcessingSegments;
//            } else
//                ++ofs;
//        }
//        fwrite(buf+startOfs, sizeof(char), ofs-startOfs, handle);
//    }
//doneProcessingSegments:
//    free(buf);
//    return _requestMultipartSegments;
}

- (NSString *)_getVar:(NSString *)aName inBuffer:(const void *)aBuf length:(long)aLen
{
    if(!aBuf || !aLen)
        return nil;
    char *buf = malloc(aLen);
    int bytesRead = mg_get_var(aBuf, aLen, [aName UTF8String], buf, aLen);
    if(!bytesRead)
        return nil;
    return [[[NSString alloc] initWithBytesNoCopy:buf
                                           length:bytesRead
                                         encoding:NSUTF8StringEncoding
                                     freeWhenDone:YES] autorelease];
}

- (NSString *)requestBodyVar:(NSString *)aName
{
    NSData *body = self.requestBodyData;
    return [self _getVar:aName inBuffer:[body bytes] length:[body length]];
}

- (NSString *)requestQueryVar:(NSString *)aName
{
    const char *str = _mgRequest->query_string;
    if(str)
        return [self _getVar:aName inBuffer:str length:strlen(str)];
    return nil;
}

#pragma mark -

- (void)setResponseHeader:(NSString *)aHeader to:(NSString *)aValue
{
    NSParameterAssert(aHeader);
    if(aValue)
        _responseHeaders[aHeader] = aValue;
    else
        [_responseHeaders removeObjectForKey:aHeader];
}

- (NSDictionary *)allRequestHeaders
{
    struct mg_request_info *info = mg_get_request_info(_mgConnection);
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    for(int i = 0; i < info->num_headers; ++i) {
        struct mg_header header = info->http_headers[i];
        headers[@(header.name)] = @(header.value);
    }
    return headers;
}

- (NSString *)requestHeader:(NSString *)aName
{
    const char *h;
    if((h = mg_get_header(_mgConnection, [aName UTF8String])))
        return [NSString stringWithUTF8String:h];
    return nil;
}

- (void)close
{
    _isOpen = NO;
}

- (NSString *)httpAuthUser
{
    if(_mgRequest->remote_user)
        return [NSString stringWithUTF8String:_mgRequest->remote_user];
    return nil;
}
- (NSURL *)url
{
    if(_mgRequest->uri) {
        NSString *str = [NSString stringWithUTF8String:_mgRequest->uri];
        return str ? [NSURL URLWithString:str] : nil;
    }
    return nil;
}
- (long)remoteIp
{
    return _mgRequest->remote_ip;
}
- (long)remotePort
{
    return _mgRequest->remote_port;
}
- (BOOL)isSSL
{
    return _mgRequest->is_ssl;
}

//FA_BATCH_IMPL(HTTPConnection)
- (void)dealloc
{
    [_requestBodyData release];
    _requestBodyData = nil;
    _responseData.length = 0;
    _requestLength = -1;
    [_cookiesToWrite removeAllObjects];
    [_responseHeaders removeAllObjects];
    [_requestMultipartSegments removeAllObjects];
//    FA_BATCH_DEALLOC
    [super dealloc];
}

- (struct mg_connection *)connectionPtr {
	return [self mgConnection];
}
@end
