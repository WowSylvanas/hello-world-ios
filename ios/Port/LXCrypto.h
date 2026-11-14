#import <Foundation/Foundation.h>

NSString *LXAES(NSString *text, NSString *key, NSString *iv, NSString *mode, BOOL decrypt);
NSString *LXRSA(NSString *text, NSString *key, NSString *padding, BOOL decrypt);
NSString *LXDigest(NSData *data, BOOL sha1);
