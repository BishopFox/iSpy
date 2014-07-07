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
@property (assign) HTTP *jsonRpc;
@property (assign) NSMutableDictionary *plist;
-(NSDictionary *) getNetworkInfo;
-(void) configureWebServer;
-(BOOL) startWebServices;
-(int) getListenPortFor:(NSString *) key fallbackTo: (int) fallback;
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
@property (assign) NSMutableDictionary *trackedInstances;
@property (assign) NSMutableDictionary *msgSendWhitelist;

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
-(void) instance_enableTracking;
-(void) instance_disableTracking;
-(NSDictionary *) getSymbolTable;
-(NSDictionary *)keyChainItems;
-(unsigned int)ASLR;
-(NSDictionary *)infoForMethod:(SEL)selector inClass:(Class)cls;
-(NSDictionary *)infoForMethod:(SEL)selector inClass:(Class)cls isInstanceMethod:(BOOL)isInstance;
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
-(void) msgSend_enableLogging;
-(void) msgSend_disableLogging;
-(void) testJSONRPC:(NSDictionary *)args;
-(void) setMsgSendLoggingState:(NSDictionary *)args;
@end


/*
	Helper functions. 
*/

NSString *SHA256HMAC(NSData *theData);
char *bf_get_type_from_signature(char *typeStr);
