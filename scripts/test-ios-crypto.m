#import <Foundation/Foundation.h>
#import "LXCrypto.h"

static void Check(NSString *actual, NSString *expected, NSString *label) {
  if (![actual isEqualToString:expected]) {
    NSLog(@"FAIL: %@", label);
    exit(1);
  }
  NSLog(@"PASS: %@", label);
}
int main(void) {
  @autoreleasepool {
    NSData *data = [NSData dataWithContentsOfFile:@"build/crypto-vectors.json"];
    NSDictionary *v = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (!v) return 1;
    Check(LXAES(v[@"input"],v[@"key"],v[@"iv"],@"AES/CBC/PKCS7Padding",NO),v[@"cbc"],@"AES-CBC matches Node crypto");
    Check(LXAES(v[@"cbc"],v[@"key"],v[@"iv"],@"AES/CBC/PKCS7Padding",YES),v[@"plain"],@"AES-CBC Unicode decrypt");
    Check(LXAES(v[@"input"],v[@"key"],@"",@"AES",NO),v[@"ecb"],@"AES default matches Java ECB/PKCS7");
    Check(LXAES(v[@"rawInput"],v[@"key"],@"",@"AES/ECB/NoPadding",NO),v[@"ecbRaw"],@"AES-ECB explicit NoPadding");
    Check(LXRSA(v[@"rsa"],v[@"privateKey"],@"RSA/ECB/OAEPWithSHA1AndMGF1Padding",YES),v[@"plain"],@"RSA PKCS8 OAEP interoperability");
    Check(LXRSA(v[@"input"],v[@"publicKey"],@"RSA/ECB/NoPadding",NO),v[@"rsaRaw"],@"RSA SPKI raw interoperability");
    NSData *plain = [v[@"plain"] dataUsingEncoding:NSUTF8StringEncoding];
    Check(LXDigest(plain,NO),v[@"md5"],@"MD5 Unicode");
    Check(LXDigest(plain,YES),v[@"sha1"],@"SHA1 Unicode");
  }
  return 0;
}
