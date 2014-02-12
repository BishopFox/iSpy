#import <Foundation/NSObject.h>

// Defines fallback methods for calling blocks that take and return only objects
// For libraries that want to play well with tranquil, but also be usable in apps that
// do not link to libtranquil

@interface NSBlock : NSObject
@end

@interface NSBlock (TranquilCompatibility)
- (id)call;
- (id)call:(id)a0 ;
- (id)call:(id)a0 :(id)a1 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 :(id)a17 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 :(id)a17 :(id)a18 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 :(id)a17 :(id)a18 :(id)a19 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 :(id)a17 :(id)a18 :(id)a19 :(id)a20 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 :(id)a17 :(id)a18 :(id)a19 :(id)a20 :(id)a21 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 :(id)a17 :(id)a18 :(id)a19 :(id)a20 :(id)a21 :(id)a22 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 :(id)a17 :(id)a18 :(id)a19 :(id)a20 :(id)a21 :(id)a22 :(id)a23 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 :(id)a17 :(id)a18 :(id)a19 :(id)a20 :(id)a21 :(id)a22 :(id)a23 :(id)a24 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 :(id)a17 :(id)a18 :(id)a19 :(id)a20 :(id)a21 :(id)a22 :(id)a23 :(id)a24 :(id)a25 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 :(id)a17 :(id)a18 :(id)a19 :(id)a20 :(id)a21 :(id)a22 :(id)a23 :(id)a24 :(id)a25 :(id)a26 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 :(id)a17 :(id)a18 :(id)a19 :(id)a20 :(id)a21 :(id)a22 :(id)a23 :(id)a24 :(id)a25 :(id)a26 :(id)a27 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 :(id)a17 :(id)a18 :(id)a19 :(id)a20 :(id)a21 :(id)a22 :(id)a23 :(id)a24 :(id)a25 :(id)a26 :(id)a27 :(id)a28 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 :(id)a17 :(id)a18 :(id)a19 :(id)a20 :(id)a21 :(id)a22 :(id)a23 :(id)a24 :(id)a25 :(id)a26 :(id)a27 :(id)a28 :(id)a29 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 :(id)a17 :(id)a18 :(id)a19 :(id)a20 :(id)a21 :(id)a22 :(id)a23 :(id)a24 :(id)a25 :(id)a26 :(id)a27 :(id)a28 :(id)a29 :(id)a30 ;
- (id)call:(id)a0 :(id)a1 :(id)a2 :(id)a3 :(id)a4 :(id)a5 :(id)a6 :(id)a7 :(id)a8 :(id)a9 :(id)a10 :(id)a11 :(id)a12 :(id)a13 :(id)a14 :(id)a15 :(id)a16 :(id)a17 :(id)a18 :(id)a19 :(id)a20 :(id)a21 :(id)a22 :(id)a23 :(id)a24 :(id)a25 :(id)a26 :(id)a27 :(id)a28 :(id)a29 :(id)a30 :(id)a31 ;
- (id)callWithArguments:(NSArray *)aArguments;
@end
