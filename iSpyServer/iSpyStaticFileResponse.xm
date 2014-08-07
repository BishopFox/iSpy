#import "iSpyStaticFileResponse.h"


@implementation iSpyStaticFileResponse

static NSDictionary *CONTENT_TYPES = @{
    @"js": @"text/javascript",
    @"css": @"text/css",
    @"png": @"image/png",
    @"jpg": @"image/jpeg",
    @"jpeg": @"image/jpeg",
    @"ico": @"image/ico",
    @"gif": @"image/gif",
    @"svg": @"image/svg+xml",
    @"tff": @"application/x-font-ttf",
    @"eot": @"application/vnd.ms-fontobject",
    @"woff": @"application/x-font-woff",
    @"otf": @"application/x-font-otf",
};

- (NSDictionary *) httpHeaders
{
    NSString *contentType = [CONTENT_TYPES valueForKey:[filePath pathExtension]];
    NSDictionary *headers = [[NSDictionary alloc] initWithObjectsAndKeys:
                                @"Content-type", contentType,
                                @"value2", @"key2",
                            nil];
    return headers;
}

@end
