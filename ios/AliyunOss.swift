import Foundation
import AliyunOSSiOS
import React

@objc(AliyunOss)
class AliyunOss: RCTEventEmitter {
    
    private var client: OSSClient?
    
    // 必须实现，声明模块支持的事件
    override func supportedEvents() -> [String]! {
        return ["AliyunOssProgress"]
    }
    
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    // 初始化 OSS
    @objc(initOSS:withAccessKeySecret:withSecurityToken:withEndpoint:withResolver:withRejecter:)
    func initOSS(accessKeyId: String,
                 accessKeySecret: String,
                 securityToken: String,
                 endpoint: String,
                 resolve: @escaping RCTPromiseResolveBlock,
                 reject: @escaping RCTPromiseRejectBlock) {
        do {
            let credentialProvider = OSSFederationCredentialProvider {
                let token = OSSFederationToken()
                token.tAccessKey = accessKeyId
                token.tSecretKey = accessKeySecret
                token.tToken = securityToken
                token.expirationTimeInGMTFormat = ""
                return token
            }
            
            let conf = OSSClientConfiguration()
            conf.maxRetryCount = 2
            conf.timeoutIntervalForRequest = 15
            conf.timeoutIntervalForResource = 15
            
            self.client = OSSClient(endpoint: endpoint, credentialProvider: credentialProvider, clientConfiguration: conf)
            resolve(true)
        } catch let error {
            reject("INIT_ERROR", "Failed to init OSS", error)
        }
    }
    
    // 异步上传（带进度）
    @objc(simpleUpload:withTargetPath:withLocalFilePath:withResolver:withRejecter:)
    func simpleUpload(bucket: String,
                      targetPath: String,
                      localFilePath: String,
                      resolve: @escaping RCTPromiseResolveBlock,
                      reject: @escaping RCTPromiseRejectBlock) {
        
        guard let client = self.client else {
            reject("UPLOAD_FAIL", "OSS not initialized", nil)
            return
        }
        
        let put = OSSPutObjectRequest()
        put.bucketName = bucket
        put.objectKey = targetPath
        
        // 处理本地文件路径
        let fileURL: URL
        if localFilePath.hasPrefix("file://") {
            guard let url = URL(string: localFilePath) else {
                reject("UPLOAD_FAIL", "Invalid file path", nil)
                return
            }
            fileURL = url
        } else {
            fileURL = URL(fileURLWithPath: localFilePath)
        }
        put.uploadingFileURL = fileURL
        
        // 上传进度回调
        put.uploadProgress = { bytesSent, totalBytesSent, totalBytesExpectedToSend in
            let event: [String: Any] = [
                "type": "progress",
                "current": totalBytesSent,
                "total": totalBytesExpectedToSend
            ]
            DispatchQueue.main.async {
                self.sendEvent(withName: "AliyunOssProgress", body: event)
            }
        }
        
        // 开始上传
        let task = client.putObject(put)
        task.continue({ t -> Any? in
            DispatchQueue.main.async {
                if let error = t.error {
                    reject("UPLOAD_EXCEPTION", "Upload failed", error)
                } else {
                    resolve("OK: done")
                }
            }
            return nil
        })
    }
    
    // 示例方法
    @objc(multiply:withB:withResolver:withRejecter:)
    func multiply(a: Float,
                  b: Float,
                  resolve: RCTPromiseResolveBlock,
                  reject: RCTPromiseRejectBlock) -> Void {
        resolve(a * b)
    }
}
