
/*
 ****************************************
 *** CoreFoundation function hooking. ***
 ****************************************

 Once a function is hooked, its original (unhooked) version is saved in the orig_* pointers.
 We can use these to call the original unhooked functions.

 The format for hooking C calls is:
 FUNCNAME        - the function we're hooking
 bf_FUNCNAME     - our new function. Overrides FUNCNAME. Define it below, along with the other bf_* functions.
 orig_FUNCNAME   - pointer to original FUNCNAME. We can call this :)

 The orig_FUNCNAME return types and argument lists must match the original EXACTLY.
 (unless you're a hardcore motherfucker and are deliberately munging data types for an epic hack. Caveat emptor.)
 Consult man pages and/or other documentation for copy pasta. I got most of these from man.
 */

//
// Declarations of replacement funcs
//
Boolean bf_CFReadStreamSetProperty(CFReadStreamRef stream, CFStringRef propertyName, CFTypeRef propertyValue);
Boolean bf_CFWriteStreamSetProperty(CFWriteStreamRef stream, CFStringRef propertyName, CFTypeRef propertyValue);
CFIndex bf_CFReadStreamRead(CFReadStreamRef stream, UInt8 *buffer, CFIndex bufferLength);
CFIndex bf_CFWriteStreamWrite(CFWriteStreamRef stream, const UInt8 *buffer, CFIndex bufferLength);
CFURLRef bf_CFURLCreateWithString(CFAllocatorRef allocator, CFStringRef URLString, CFURLRef baseURL);
Boolean bf_CFReadStreamOpen(CFReadStreamRef stream);
Boolean bf_CFWriteStreamOpen(CFWriteStreamRef stream);
void bf_CFStreamCreatePairWithSocketToHost(CFAllocatorRef alloc, CFStringRef host, UInt32 port, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream);
void bf_CFStreamCreatePairWithPeerSocketSignature(CFAllocatorRef alloc, const CFSocketSignature *signature, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream);
void bf_CFStreamCreatePairWithSocket(CFAllocatorRef alloc, CFSocketNativeHandle sock, CFReadStreamRef *readStream, CFWriteStreamRef *writeStream);
CFReadStreamRef bf_CFReadStreamCreateWithBytesNoCopy(CFAllocatorRef alloc, const UInt8 *bytes, CFIndex length, CFAllocatorRef bytesDeallocator);
SecCertificateRef bf_SecCertificateCreateWithData(CFAllocatorRef allocator, CFDataRef data);
CFDictionaryRef bf_CFNetworkCopySystemProxySettings(void);
CFHTTPMessageRef bf_CFHTTPMessageCreateRequest(CFAllocatorRef alloc, CFStringRef requestMethod, CFURLRef url, CFStringRef httpVersion);
CFReadStreamRef bf_CFReadStreamCreateForHTTPRequest(CFAllocatorRef alloc, CFHTTPMessageRef request);



