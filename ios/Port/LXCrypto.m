#import "LXCrypto.h"
#import <React/RCTBridgeModule.h>
#import <CommonCrypto/CommonCrypto.h>
#import <Security/Security.h>

static NSData *LXDecode(NSString *value) {
  return [[NSData alloc] initWithBase64EncodedString:value ?: @"" options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

NSString *LXDigest(NSData *data, BOOL sha1) {
  unsigned char digest[CC_SHA1_DIGEST_LENGTH];
  if (sha1) CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
  else CC_MD5(data.bytes, (CC_LONG)data.length, digest);
  NSMutableString *result = [NSMutableString string];
  for (NSUInteger i = 0; i < (sha1 ? CC_SHA1_DIGEST_LENGTH : CC_MD5_DIGEST_LENGTH); i++) [result appendFormat:@"%02x", digest[i]];
  return result;
}

NSString *LXAES(NSString *text, NSString *key, NSString *iv, NSString *mode, BOOL decrypt) {
  NSData *input = LXDecode(text), *keyData = LXDecode(key), *ivData = LXDecode(iv);
  if (!input || ![@[@16, @24, @32] containsObject:@(keyData.length)]) return nil;
  BOOL ecb = [mode isEqualToString:@"AES"] || [mode containsString:@"ECB"];
  CCOptions options = [mode containsString:@"NoPadding"] ? 0 : kCCOptionPKCS7Padding;
  if (ecb) options |= kCCOptionECBMode;
  unsigned char ivBytes[kCCBlockSizeAES128] = {0};
  if (ivData) memcpy(ivBytes, ivData.bytes, MIN(ivData.length, sizeof(ivBytes)));
  NSMutableData *output = [NSMutableData dataWithLength:input.length + kCCBlockSizeAES128];
  size_t written = 0;
  CCCryptorStatus status = CCCrypt(decrypt ? kCCDecrypt : kCCEncrypt, kCCAlgorithmAES,
    options, keyData.bytes, keyData.length, ecb ? NULL : ivBytes,
    input.bytes, input.length, output.mutableBytes, output.length, &written);
  if (status != kCCSuccess) return nil;
  output.length = written;
  return decrypt ? [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding] : [output base64EncodedStringWithOptions:0];
}

// Read a DER TLV without assuming a fixed key size or ASN.1 header length.
static NSData *LXDERValue(NSData *data, NSUInteger *offset, uint8_t *tag) {
  const uint8_t *bytes = data.bytes;
  if (*offset + 2 > data.length) return nil;
  *tag = bytes[(*offset)++];
  NSUInteger length = bytes[(*offset)++];
  if (length & 0x80) {
    NSUInteger count = length & 0x7f;
    if (!count || count > sizeof(NSUInteger) || *offset + count > data.length) return nil;
    length = 0;
    for (NSUInteger i = 0; i < count; i++) length = (length << 8) | bytes[(*offset)++];
  }
  if (length > data.length - *offset) return nil;
  NSData *value = [data subdataWithRange:NSMakeRange(*offset, length)];
  *offset += length;
  return value;
}

static NSData *LXUnwrapKey(NSData *data, BOOL privateKey) {
  NSUInteger offset = 0; uint8_t tag;
  NSData *sequence = LXDERValue(data, &offset, &tag);
  if (!sequence || tag != 0x30) return data;
  offset = 0;
  NSData *first = LXDERValue(sequence, &offset, &tag);
  if (!first) return data;
  if (!privateKey && tag == 0x30) {
    NSData *bits = LXDERValue(sequence, &offset, &tag);
    if (tag == 0x03 && bits.length > 1) return [bits subdataWithRange:NSMakeRange(1, bits.length - 1)];
  }
  if (privateKey && tag == 0x02) {
    LXDERValue(sequence, &offset, &tag);
    if (tag == 0x30) {
      NSData *octets = LXDERValue(sequence, &offset, &tag);
      if (tag == 0x04 && octets) return octets;
    }
  }
  return data;
}

static NSData *LXDER(uint8_t tag, NSData *value) {
  NSMutableData *result = [NSMutableData dataWithBytes:&tag length:1];
  NSUInteger length = value.length;
  if (length < 128) { uint8_t byte = length; [result appendBytes:&byte length:1]; }
  else {
    uint8_t encoded[sizeof(NSUInteger)]; NSUInteger count = 0;
    for (NSUInteger n = length; n; n >>= 8) encoded[sizeof(encoded) - ++count] = n & 0xff;
    uint8_t prefix = 0x80 | count;
    [result appendBytes:&prefix length:1];
    [result appendBytes:encoded + sizeof(encoded) - count length:count];
  }
  [result appendData:value];
  return result;
}

NSString *LXRSA(NSString *text, NSString *keyString, NSString *padding, BOOL decrypt) {
  NSData *keyData = LXDecode(keyString), *input = LXDecode(text);
  if (!keyData || !input) return nil;
  NSDictionary *attributes = @{(__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
    (__bridge id)kSecAttrKeyClass: (__bridge id)(decrypt ? kSecAttrKeyClassPrivate : kSecAttrKeyClassPublic)};
  SecKeyRef key = SecKeyCreateWithData((__bridge CFDataRef)LXUnwrapKey(keyData, decrypt), (__bridge CFDictionaryRef)attributes, NULL);
  if (!key) return nil;
  BOOL raw = [padding containsString:@"NoPadding"];
  SecKeyAlgorithm algorithm = raw ? kSecKeyAlgorithmRSAEncryptionRaw : kSecKeyAlgorithmRSAEncryptionOAEPSHA1;
  if (raw && !decrypt && input.length < SecKeyGetBlockSize(key)) {
    NSMutableData *padded = [NSMutableData dataWithLength:SecKeyGetBlockSize(key) - input.length];
    [padded appendData:input]; input = padded;
  }
  CFDataRef value = decrypt
    ? SecKeyCreateDecryptedData(key, algorithm, (__bridge CFDataRef)input, NULL)
    : SecKeyCreateEncryptedData(key, algorithm, (__bridge CFDataRef)input, NULL);
  CFRelease(key);
  NSData *output = CFBridgingRelease(value);
  if (!output) return nil;
  return decrypt ? [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding] : [output base64EncodedStringWithOptions:0];
}

@interface CryptoModule : NSObject <RCTBridgeModule>
@end
@implementation CryptoModule
RCT_EXPORT_MODULE();
+ (BOOL)requiresMainQueueSetup { return NO; }
RCT_EXPORT_METHOD(generateRsaKey:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)@{
    (__bridge id)kSecAttrKeyType:(__bridge id)kSecAttrKeyTypeRSA,
    (__bridge id)kSecAttrKeySizeInBits:@2048}, NULL);
  if (!privateKey) { reject(@"RSA_KEY", @"Unable to generate RSA key", nil); return; }
  SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
  NSData *priv = CFBridgingRelease(SecKeyCopyExternalRepresentation(privateKey, NULL));
  NSData *pub = CFBridgingRelease(SecKeyCopyExternalRepresentation(publicKey, NULL));
  CFRelease(privateKey); CFRelease(publicKey);
  const unsigned char algorithm[] = {0x30,0x0d,0x06,0x09,0x2a,0x86,0x48,0x86,0xf7,0x0d,0x01,0x01,0x01,0x05,0x00};
  NSData *alg = [NSData dataWithBytes:algorithm length:sizeof(algorithm)];
  uint8_t zero = 0;
  NSMutableData *bits = [NSMutableData dataWithBytes:&zero length:1]; [bits appendData:pub];
  NSMutableData *spki = [alg mutableCopy]; [spki appendData:LXDER(0x03, bits)];
  const unsigned char version[] = {0x02,0x01,0x00};
  NSMutableData *pkcs8 = [NSMutableData dataWithBytes:version length:sizeof(version)];
  [pkcs8 appendData:alg]; [pkcs8 appendData:LXDER(0x04, priv)];
  resolve(@{@"publicKey":[LXDER(0x30, spki) base64EncodedStringWithOptions:0], @"privateKey":[LXDER(0x30, pkcs8) base64EncodedStringWithOptions:0]});
}
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(aesEncryptSync:(NSString *)text key:(NSString *)key iv:(NSString *)iv mode:(NSString *)mode) { return LXAES(text, key, iv, mode, NO) ?: @""; }
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(aesDecryptSync:(NSString *)text key:(NSString *)key iv:(NSString *)iv mode:(NSString *)mode) { return LXAES(text, key, iv, mode, YES) ?: @""; }
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(rsaEncryptSync:(NSString *)text key:(NSString *)key padding:(NSString *)padding) { return LXRSA(text, key, padding, NO) ?: @""; }
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(rsaDecryptSync:(NSString *)text key:(NSString *)key padding:(NSString *)padding) { return LXRSA(text, key, padding, YES) ?: @""; }
RCT_EXPORT_METHOD(aesEncrypt:(NSString *)text key:(NSString *)key iv:(NSString *)iv mode:(NSString *)mode resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSString *value = LXAES(text,key,iv,mode,NO); if (value) resolve(value); else reject(@"AES",@"AES encryption failed",nil);
}
RCT_EXPORT_METHOD(aesDecrypt:(NSString *)text key:(NSString *)key iv:(NSString *)iv mode:(NSString *)mode resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSString *value = LXAES(text,key,iv,mode,YES); if (value) resolve(value); else reject(@"AES",@"AES decryption failed",nil);
}
RCT_EXPORT_METHOD(rsaEncrypt:(NSString *)text key:(NSString *)key padding:(NSString *)padding resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSString *value = LXRSA(text,key,padding,NO); if (value) resolve(value); else reject(@"RSA",@"RSA encryption failed",nil);
}
RCT_EXPORT_METHOD(rsaDecrypt:(NSString *)text key:(NSString *)key padding:(NSString *)padding resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSString *value = LXRSA(text,key,padding,YES); if (value) resolve(value); else reject(@"RSA",@"RSA decryption failed",nil);
}
RCT_EXPORT_METHOD(sha1:(NSString *)text resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  resolve(LXDigest([text dataUsingEncoding:NSUTF8StringEncoding], YES));
}
@end
