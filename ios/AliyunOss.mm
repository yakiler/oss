#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(AliyunOss, NSObject)

RCT_EXTERN_METHOD(initOSS:(NSString *)accessKeyId
                  withAccessKeySecret:(NSString *)accessKeySecret
                  withSecurityToken:(NSString *)securityToken
                  withEndpoint:(NSString *)endpoint
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(simpleUpload:(NSString *)bucket
                  withTargetPath:(NSString *)targetPath
                  withLocalFilePath:(NSString *)localFilePath
                  withUploadId:(NSString *)uploadId
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(multiply:(float)a
                  withB:(float)b
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

// cancelUpload 方法
RCT_EXTERN_METHOD(cancelUpload:(NSString *)uploadId)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end
