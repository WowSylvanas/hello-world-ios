#import <React/RCTEventEmitter.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "LXCrypto.h"

@interface UserApiModule : RCTEventEmitter
@property(nonatomic, strong) JSContext *context;
@property(nonatomic, strong) dispatch_queue_t scriptQueue;
@property(nonatomic, copy) NSString *sessionKey;
@property(nonatomic) BOOL scriptInitialized;
@end

@implementation UserApiModule
RCT_EXPORT_MODULE();
+ (BOOL)requiresMainQueueSetup { return NO; }
- (instancetype)init {
  if ((self = [super init])) _scriptQueue = dispatch_queue_create("lx.user-api.ios", DISPATCH_QUEUE_SERIAL);
  return self;
}
- (dispatch_queue_t)methodQueue { return self.scriptQueue; }
- (NSArray<NSString *> *)supportedEvents { return @[@"api-action"]; }
- (void)emitAction:(NSString *)action data:(NSString *)data {
  if ([action isEqualToString:@"init"]) self.scriptInitialized = YES;
  [self sendEventWithName:@"api-action" body:@{@"action":action, @"data":data ?: @"null"}];
}
- (void)logError:(NSString *)message {
  [self sendEventWithName:@"api-action" body:@{@"action":@"log", @"type":@"error", @"log":message ?: @"JavaScript error"}];
  if (!self.scriptInitialized) {
    NSDictionary *data = @{@"status":@NO, @"info":[NSNull null], @"errorMessage":message ?: @"Unable to initialize script"};
    NSString *json = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:data options:0 error:nil] encoding:NSUTF8StringEncoding];
    [self emitAction:@"init" data:json];
  }
}
RCT_EXPORT_METHOD(loadScript:(NSDictionary *)info) {
  self.sessionKey = NSUUID.UUID.UUIDString;
  self.scriptInitialized = NO;
  self.context = [[JSContext alloc] initWithVirtualMachine:[JSVirtualMachine new]];
  __weak UserApiModule *weakSelf = self;
  self.context.exceptionHandler = ^(JSContext *context, JSValue *exception) {
    [weakSelf logError:[exception toString]];
  };
  self.context[@"__lx_native_call__"] = ^(NSString *key, NSString *action, NSString *data) {
    if ([key isEqualToString:weakSelf.sessionKey]) [weakSelf emitAction:action data:data];
  };
  self.context[@"__lx_native_call__utils_str2b64"] = ^NSString *(NSString *text) {
    return [[text dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
  };
  self.context[@"__lx_native_call__utils_b642buf"] = ^NSString *(NSString *text) {
    NSData *data = [[NSData alloc] initWithBase64EncodedString:text options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSMutableArray *bytes = [NSMutableArray arrayWithCapacity:data.length];
    const uint8_t *raw = data.bytes;
    for (NSUInteger i = 0; i < data.length; i++) [bytes addObject:@(raw[i])];
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:bytes options:0 error:nil] encoding:NSUTF8StringEncoding];
  };
  self.context[@"__lx_native_call__utils_str2md5"] = ^NSString *(NSString *text) {
    NSString *decoded = [[text stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByRemovingPercentEncoding] ?: text;
    return LXDigest([decoded dataUsingEncoding:NSUTF8StringEncoding], NO);
  };
  self.context[@"__lx_native_call__utils_aes_encrypt"] = ^NSString *(NSString *text, NSString *key, NSString *iv, NSString *mode) {
    return LXAES(text,key,iv,mode,NO) ?: @"";
  };
  self.context[@"__lx_native_call__utils_rsa_encrypt"] = ^NSString *(NSString *text, NSString *key, NSString *padding) {
    return LXRSA(text,key,padding,NO) ?: @"";
  };
  self.context[@"__lx_native_call__set_timeout"] = ^(NSNumber *timerID, NSNumber *delay) {
    NSString *session = weakSelf.sessionKey;
    dispatch_queue_t queue = weakSelf.scriptQueue;
    if (!queue) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(0, delay.doubleValue) * NSEC_PER_MSEC)), queue, ^{
      UserApiModule *owner = weakSelf;
      if (owner && [owner.sessionKey isEqualToString:session])
        [owner.context[@"__lx_native__"] callWithArguments:@[session, @"__set_timeout__", timerID.stringValue]];
    });
  };
  NSMutableDictionary *console = [NSMutableDictionary dictionary];
  for (NSString *type in @[@"log", @"info", @"warn", @"error", @"debug"]) {
    console[type] = ^{
      NSMutableArray *parts = [NSMutableArray array];
      for (JSValue *arg in JSContext.currentArguments) [parts addObject:[arg toString] ?: @""];
      [weakSelf sendEventWithName:@"api-action" body:@{@"action":@"log", @"type":type, @"log":[parts componentsJoinedByString:@" "]}];
    };
  }
  self.context[@"console"] = console;
  NSString *path = [NSBundle.mainBundle pathForResource:@"user-api-preload" ofType:@"js"];
  NSString *preload = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
  if (!preload) { [self logError:@"The iOS app is missing user-api-preload.js"]; return; }
  [self.context evaluateScript:preload];
  [self.context[@"lx_setup"] callWithArguments:@[self.sessionKey, info[@"id"] ?: @"", info[@"name"] ?: @"",
    info[@"description"] ?: @"", info[@"version"] ?: @"", info[@"author"] ?: @"", info[@"homepage"] ?: @"", info[@"script"] ?: @""]];
  [self.context evaluateScript:info[@"script"] ?: @"" withSourceURL:[NSURL URLWithString:@"lx-user-source.js"]];
  NSString *session = self.sessionKey;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), self.scriptQueue, ^{
    UserApiModule *owner = weakSelf;
    if (owner && [owner.sessionKey isEqualToString:session] && !owner.scriptInitialized)
      [owner logError:@"自定义源初始化超时，请检查源是否支持移动端。"];
  });
}
RCT_EXPORT_METHOD(sendAction:(NSString *)action info:(NSString *)info) {
  if (self.context) [self.context[@"__lx_native__"] callWithArguments:@[self.sessionKey, action, info ?: @"null"]];
}
RCT_EXPORT_METHOD(destroy) { self.context = nil; self.sessionKey = nil; self.scriptInitialized = NO; }
- (void)invalidate {
  dispatch_async(self.scriptQueue, ^{ self.context = nil; self.sessionKey = nil; });
  [super invalidate];
}
@end
