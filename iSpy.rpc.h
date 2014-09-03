@interface RPCHandler : NSObject
-(NSDictionary *) setMsgSendLoggingState:(NSDictionary *) args;
-(NSDictionary *) testJSONRPC:(NSDictionary *)args;
-(NSDictionary *) ASLR:(NSDictionary *)args;
-(NSDictionary *) addMethodsToWhitelist:(NSDictionary *)args;
@end
