#import "HTTPKit/HTTP.h"
/*
    Adds a nice "containsString" method to NSString
*/
@interface NSString (iSpy) {
}
-(BOOL) containsString:(NSString*)substring;
@end



/*
	Used for the REST server HTML5 GUI
*/
@interface iSpyServer : NSObject {
}
@property (assign) HTTP *http;         // Used for our HTTP server
@property (assign) HTTP *wsGeneral;    // Used for different web sockets
@property (assign) HTTP *wsStrace;
@property (assign) HTTP *wsMsgSend;
@property (assign) HTTP *wsNetwork;
@property (assign) HTTP *wsFile;
@property (assign) HTTP *wsInstance;
@property (assign) HTTP *wsISpy;
@property (assign) int straceReadLock;
@property (assign) int msgSendReadLock;
@property (assign) int generalReadLock;

-(NSString *)renderStaticTemplate:(NSString *)tpl;
-(NSDictionary *) getNetworkInfo;
-(void) configureWebServer;
-(BOOL) startWebServices;
@end


/*
	Functionality that's exposed to Cycript.
*/
@interface iSpy : NSObject {
	Class *classList;
}
@property (assign) iSpyServer *webServer;
@property (assign) NSString *globalStatusStr;
@property (assign) char *bundle;
@property (assign) NSString *bundleId;
@property (assign) BOOL isInstanceTrackingEnabled;
@property (assign) BOOL isMsgSendTrackingEnabled;
@property (assign) BOOL isStraceTrackingEnabled;
@property (assign) NSMutableDictionary *trackedInstances;

+(id)sharedInstance;
-(NSString *) instance_dumpAllInstancesWithPointers;
-(NSString *) instance_dumpAppInstancesWithPointers;
-(NSArray *) instance_dumpAppInstancesWithPointersArray;
-(int) instance_numberOfTrackedInstances;
-(void) instance_searchInstances:(NSString *)forName;
-(BOOL) instance_getTrackingState;
-(id)instance_atAddress:(NSString *)addr;
-(id)instance_dumpInstance:(id)instance;
-(id)instance_dumpInstanceAtAddress:(NSString *)addr;
-(void) msgSend_enableLogging;
-(void) msgSend_disableLogging;
-(BOOL) msgSend_getLoggingState;
-(void) strace_enableLogging;
-(void) strace_disableLogging;
-(BOOL) strace_getLoggingState;
-(void) instance_enableTracking;
-(void) instance_disableTracking;
-(void) log_setGeneralLogState:(BOOL)state;
-(void) log_setStraceLogState:(BOOL)state;
-(void) log_setHTTPLogState:(BOOL)state;
-(void) log_setTCPIPLogState:(BOOL)state;
-(void) log_setMsgSendLogState:(BOOL)state;
-(NSDictionary *) getSymbolTable;
-(unsigned int) getMachFlags;
-(NSDictionary *)keyChainItems;
-(unsigned int)ASLR;
-(NSDictionary *)infoForMethod:(SEL)selector inClass:(Class)cls;
-(NSDictionary *)infoForMethod:(SEL)selector inClass:(Class)cls isInstanceMethod:(BOOL)isInstance;
-(id)testMethodThing;
-(id)iVarsForClass:(NSString *)className;
-(id)propertiesForClass:(NSString *)className;
-(id)methodsForClass:(NSString *)className;
-(id)classes;
-(id)classesWithSuperClassAndProtocolInfo;
-(id)protocolsForClass:(NSString *)className;
-(id)propertiesForProtocol:(Protocol *)protocol;
-(id)methodsForProtocol:(Protocol *)protocol;
-(NSDictionary *)protocolDump;
-(NSDictionary *)classDump;
-(NSString *)SHA256HMACForAppBinary;
-(NSDictionary *)classDumpClass:(NSString *)className;
-(NSDictionary *) instance_dumpAppInstancesWithPointersDict;
//-(void) bounceWebServer;
@end

/*
	Helper functions. 
*/

NSString *SHA256HMAC(NSData *theData);
char *bf_get_type_from_signature(char *typeStr);
