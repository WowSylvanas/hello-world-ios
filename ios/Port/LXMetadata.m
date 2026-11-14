#import <React/RCTBridgeModule.h>
#import <AVFoundation/AVFoundation.h>

@interface LocalMediaMetadata : NSObject <RCTBridgeModule>
@end
@implementation LocalMediaMetadata
RCT_EXPORT_MODULE();
+ (BOOL)requiresMainQueueSetup { return NO; }
- (NSString *)path:(NSString *)path { return [path hasPrefix:@"file://"] ? [NSURL URLWithString:path].path : path; }
- (NSString *)metadata:(AVAsset *)asset key:(NSString *)key {
  for (AVMetadataItem *item in asset.commonMetadata) if ([item.commonKey isEqualToString:key]) return item.stringValue ?: @"";
  return @"";
}
RCT_EXPORT_METHOD(readMetadata:(NSString *)path resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSString *file = [self path:path];
  if (![NSFileManager.defaultManager fileExistsAtPath:file]) { reject(@"FILE_NOT_FOUND",@"Audio file not found",nil); return; }
  AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:file] options:nil];
  NSTimeInterval seconds = CMTimeGetSeconds(asset.duration);
  if (!isfinite(seconds) || seconds < 0) seconds = 0;
  NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:file error:nil];
  unsigned long long size = attributes.fileSize;
  NSString *name = [self metadata:asset key:AVMetadataCommonKeyTitle];
  NSString *ext = file.pathExtension.lowercaseString;
  resolve(@{@"name":name.length ? name : file.lastPathComponent.stringByDeletingPathExtension,
    @"singer":[self metadata:asset key:AVMetadataCommonKeyArtist], @"albumName":[self metadata:asset key:AVMetadataCommonKeyAlbumName],
    @"interval":@(seconds).stringValue, @"size":@(size), @"bitrate":@(seconds > 0 ? size * 8 / seconds / 1000 : 0).stringValue,
    @"ext":ext, @"type":ext});
}
RCT_EXPORT_METHOD(readPic:(NSString *)path directory:(NSString *)directory resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:[self path:path]] options:nil];
  for (AVMetadataItem *item in asset.commonMetadata) {
    if ([item.commonKey isEqualToString:AVMetadataCommonKeyArtwork] && item.dataValue) {
      [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
      NSString *file = [directory stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".jpg"]];
      NSError *error = nil;
      [item.dataValue writeToFile:file options:NSDataWritingAtomic error:&error];
      if (error) reject(@"ARTWORK",error.localizedDescription,error); else resolve(file);
      return;
    }
  }
  resolve(@"");
}
RCT_EXPORT_METHOD(readLyric:(NSString *)path sidecar:(BOOL)sidecar resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSString *file = [[[self path:path] stringByDeletingPathExtension] stringByAppendingPathExtension:@"lrc"];
  resolve([NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] ?: @"");
}
RCT_EXPORT_METHOD(writeLyric:(NSString *)path lyric:(NSString *)lyric sidecar:(BOOL)sidecar resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  NSString *file = [[[self path:path] stringByDeletingPathExtension] stringByAppendingPathExtension:@"lrc"];
  NSError *error = nil;
  [lyric writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:&error];
  if (error) reject(@"LYRIC",error.localizedDescription,error); else resolve(nil);
}
RCT_EXPORT_METHOD(writeMetadata:(NSString *)path metadata:(NSDictionary *)metadata overwrite:(BOOL)overwrite resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  reject(@"IOS_UNSUPPORTED",@"此 iOS 移植版暂不支持修改音频文件内嵌标签。",nil);
}
RCT_EXPORT_METHOD(writePic:(NSString *)path picture:(NSString *)picture resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  reject(@"IOS_UNSUPPORTED",@"此 iOS 移植版暂不支持修改音频文件内嵌封面。",nil);
}
@end
