// Ugh, this is so sloppy
#include <stack>
#include <fcntl.h>
#include <stdio.h>
#include <dlfcn.h>
#include <stdarg.h>
#include <unistd.h>
#include <string.h>
#include <dirent.h>
#include <stdbool.h>
#include <pthread.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <objc/objc.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <mach-o/dyld.h>
#include <netinet/in.h>
#import  <Security/Security.h>
#import  <Security/SecCertificate.h>
#include <CFNetwork/CFNetwork.h>
#include <CFNetwork/CFProxySupport.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFStream.h>
#import <Foundation/NSJSONSerialization.h>
#include "iSpy.common.h"
#include "hooks_CoreFoundation.h"
#include <dlfcn.h>
#include <mach-o/nlist.h>

//
// Pointers to original funcs
//
Boolean (*orig_CFWriteStreamSetProperty)(CFWriteStreamRef stream, CFStringRef propertyName, CFTypeRef propertyValue);
Boolean (*orig_CFReadStreamSetProperty)(CFReadStreamRef stream, CFStringRef propertyName, CFTypeRef propertyValue);
CFIndex (*orig_CFReadStreamRead)(CFReadStreamRef stream, UInt8 *buffer, CFIndex bufferLength);
CFURLRef (*orig_CFURLCreateWithString)(CFAllocatorRef allocator, CFStringRef URLString, CFURLRef baseURL);
Boolean (*orig_CFReadStreamOpen)(CFReadStreamRef stream);
Boolean (*orig_CFWriteStreamOpen)(CFWriteStreamRef stream);
CFIndex (*orig_CFWriteStreamWrite)(CFWriteStreamRef stream, const UInt8 *buffer, CFIndex bufferLength);
CFHTTPMessageRef (*orig_CFHTTPMessageCreateRequest)(CFAllocatorRef alloc, CFStringRef requestMethod, CFURLRef url, CFStringRef httpVersion);
void (*orig_CFStreamCreatePairWithSocketToHost)(CFAllocatorRef alloc, CFStringRef host, UInt32 port, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream);
void (*orig_CFStreamCreatePairWithPeerSocketSignature)(CFAllocatorRef alloc, const CFSocketSignature *signature, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream);
void (*orig_CFStreamCreatePairWithSocket)(CFAllocatorRef alloc, CFSocketNativeHandle sock, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream);
CFReadStreamRef (*orig_CFReadStreamCreateWithBytesNoCopy)(CFAllocatorRef alloc, const UInt8 *bytes, CFIndex length, CFAllocatorRef bytesDeallocator);
CFReadStreamRef (*orig_CFReadStreamCreateForHTTPRequest)(CFAllocatorRef alloc, CFHTTPMessageRef request);
CFDictionaryRef (*orig_CFNetworkCopySystemProxySettings)(void);
SecCertificateRef (*orig_SecCertificateCreateWithData)(CFAllocatorRef allocator, CFDataRef data);

/*
 SSL Certificate Pinning - bypass

 Uncomment the stuff below (and make sure iSpy is configured to use these hooks) in order
 to disable SSL CA certificate checks. Maybe. Not really tested much. TBD.
 */
Boolean bf_CFReadStreamSetProperty(CFReadStreamRef stream,
        CFStringRef propertyName, CFTypeRef propertyValue) {
    // This, in theory, disables all SSL certificate checks on CF*Stream* calls.
    // But... it's somewhat.... untested.... caveat emptor.
    /*
     NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
     [NSNumber numberWithBool:NO], kCFStreamSSLAllowsExpiredCertificates,
     [NSNumber numberWithBool:NO], kCFStreamSSLAllowsAnyRoot,
     [NSNumber numberWithBool:YES], kCFStreamSSLValidatesCertificateChain,
     //kCFNull, kCFStreamSSLPeerName,
     nil];
     NSDictionary *foo;
     */
    Boolean retval;

    // Log event
    ispy_log_info(LOG_TCPIP, "[iSpy] CFReadStreamSetProperty was called.");
    retval = orig_CFReadStreamSetProperty(stream, propertyName, propertyValue);

    // You probably want this UNLESS you're testing SSL cert pinning. Maybe... untested.
    /*if(strcmp((char *)propertyName, (char *)kCFStreamPropertySSLSettings)==0) {
     // override SSL settings
     foo=(NSDictionary *)CFReadStreamCopyProperty(stream, kCFStreamPropertySSLSettings);
     ispy_log_info(LOG_TCPIP, "[iSpy] CFReadStreamSetProperty: hijacking SSL checks. Orig: %@", foo);
     orig_CFReadStreamSetProperty(stream, kCFStreamPropertySSLSettings, (CFTypeRef) settings);    
     } */

    return retval;
}

/*
 SSL Certificate Pinning - bypass

 Uncomment the stuff below (and make sure iSpy is configured to use these hooks) in order
 to disable SSL CA certificate checks. Maybe.
 */
Boolean bf_CFWriteStreamSetProperty(CFWriteStreamRef stream,
        CFStringRef propertyName, CFTypeRef propertyValue) {
    // This might disable SSL certificate checks on CF*Stream* calls. Needs testing.
    /*NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
     [NSNumber numberWithBool:NO], kCFStreamSSLAllowsExpiredCertificates,
     [NSNumber numberWithBool:NO], kCFStreamSSLAllowsAnyRoot,
     [NSNumber numberWithBool:YES], kCFStreamSSLValidatesCertificateChain,
     //kCFNull, kCFStreamSSLPeerName,
     nil];
     NSDictionary *foo;*/
    Boolean retval;

    // Log event
    ispy_log_info(LOG_TCPIP, "[iSpy] CFWriteStreamSetProperty was called.");
    retval = orig_CFWriteStreamSetProperty(stream, propertyName, propertyValue);

    // You probably want this UNLESS you're testing SSL cert pinning. Or not. Pls test.
    /*if(strcmp((char *)propertyName, (char *)kCFStreamPropertySSLSettings)==0) {
     // override SSL settings
     foo=(NSDictionary *)CFWriteStreamCopyProperty(stream, kCFStreamPropertySSLSettings);
     ispy_log_info(LOG_TCPIP, "[iSpy] CFWriteStreamSetProperty: hijacking SSL checks. Orig: %@", foo);
     orig_CFWriteStreamSetProperty(stream, kCFStreamPropertySSLSettings, (CFTypeRef) settings);
     }*/
    return retval;
}

CFIndex bf_CFReadStreamRead(CFReadStreamRef stream, UInt8 *buffer, CFIndex bufferLength) {
    CFIndex retval;

    // call original
    retval = orig_CFReadStreamRead(stream, buffer, bufferLength);

    // Log event and the data read from the stream
    // ispy_log_info(LOG_TCPIP, "[iSpy] CFReadStreamRead(%@): Buf(%ld)", stream, bufferLength);
    return retval;
}

CFIndex bf_CFWriteStreamWrite(CFWriteStreamRef stream, const UInt8 *buffer,
        CFIndex bufferLength) {
    CFIndex retval;

    // call original
    retval = orig_CFWriteStreamWrite(stream, buffer, bufferLength);

    return retval;
}

CFURLRef bf_CFURLCreateWithString(CFAllocatorRef allocator,
        CFStringRef URLString, CFURLRef baseURL) {
    ispy_log_info(LOG_TCPIP, "[iSpy] CFURLCreateWithString: %@", URLString);
    return orig_CFURLCreateWithString(allocator, URLString, baseURL);
}

Boolean bf_CFReadStreamOpen(CFReadStreamRef stream) {
    ispy_log_info(LOG_TCPIP, "[iSpy] CFReadStreamOpen: %@", stream);
    return orig_CFReadStreamOpen(stream);
}

Boolean bf_CFWriteStreamOpen(CFWriteStreamRef stream) {
    ispy_log_info(LOG_TCPIP, "[iSpy] CFWriteStreamOpen: %@", stream);
    return orig_CFWriteStreamOpen(stream);
}

CFHTTPMessageRef bf_CFHTTPMessageCreateRequest(CFAllocatorRef alloc,
        CFStringRef requestMethod, CFURLRef url, CFStringRef httpVersion) {
    ispy_log_info(LOG_TCPIP, "[iSpy] CFHTTPMessageCreateRequest: %@ %@ %@", requestMethod,
            url, httpVersion);
    return orig_CFHTTPMessageCreateRequest(alloc, requestMethod, url,
            httpVersion);
}

CFReadStreamRef CFReadStreamCreateForHTTPRequest(CFAllocatorRef alloc,
        CFHTTPMessageRef request) {
    ispy_log_info(LOG_TCPIP, "[iSpy] CFReadStreamCreateForHTTPRequest: %@",
            (CFHTTPMessageRef) request);
    return orig_CFReadStreamCreateForHTTPRequest(alloc, request);
}

void bf_CFStreamCreatePairWithSocketToHost( CFAllocatorRef alloc,
                                            CFStringRef host, UInt32 port, CFReadStreamRef *readStream,
                                            CFWriteStreamRef *writeStream) {
    ispy_log_info(LOG_TCPIP, "[iSpy] CFStreamCreatePairWithSocketToHost: %s:%d", (char *)host, (unsigned int)port);
    orig_CFStreamCreatePairWithSocketToHost(alloc, host, port, readStream, writeStream);
}

CFReadStreamRef bf_CFReadStreamCreateForHTTPRequest(CFAllocatorRef alloc, CFHTTPMessageRef request) {
    ispy_log_info(LOG_TCPIP, "[iSpy] CFReadStreamCreateForHTTPRequest(%@)", request);
    return orig_CFReadStreamCreateForHTTPRequest(alloc, request);
}

void bf_CFStreamCreatePairWithPeerSocketSignature(  CFAllocatorRef alloc,
                                                    const CFSocketSignature *signature, CFReadStreamRef *readStream,
                                                    CFWriteStreamRef *writeStream) {
    ispy_log_info(LOG_TCPIP, "[iSpy] CFStreamCreatePairWithPeerSocketSignature");
    orig_CFStreamCreatePairWithPeerSocketSignature(alloc, signature, readStream, writeStream);
}

void bf_CFStreamCreatePairWithSocket(   CFAllocatorRef alloc,
                                        CFSocketNativeHandle sock, CFReadStreamRef *readStream,
                                        CFWriteStreamRef *writeStream) {
    ispy_log_info(LOG_TCPIP, "[iSpy] CFStreamCreatePairWithSocket: %d", (int) sock);
    orig_CFStreamCreatePairWithSocket(alloc, sock, readStream, writeStream);
}

CFReadStreamRef bf_CFReadStreamCreateWithBytesNoCopy(   CFAllocatorRef alloc,
                                                        const UInt8 *bytes, CFIndex length, CFAllocatorRef bytesDeallocator) {
    ispy_log_info(LOG_TCPIP, "[iSpy] CFReadStreamCreateWithBytesNoCopy: 0x%x", (unsigned int)bytes);
    return orig_CFReadStreamCreateWithBytesNoCopy(alloc, bytes, length, bytesDeallocator);
}

SecCertificateRef bf_SecCertificateCreateWithData(CFAllocatorRef allocator, CFDataRef data) {
    ispy_log_info(LOG_TCPIP, "[iSpy] SecCertificateCreateWithData: called!");
    return orig_SecCertificateCreateWithData(allocator, data);
}

CFDictionaryRef bf_CFNetworkCopySystemProxySettings(void) {
    static CFMutableDictionaryRef proxySettings = (CFMutableDictionaryRef) orig_CFNetworkCopySystemProxySettings();
    ispy_log_info(LOG_TCPIP, "[iSpy] CFNetworkCopySystemProxySettings: Got dict: %@", proxySettings);
    return proxySettings;
}
