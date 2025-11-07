import Foundation
import AliyunOSSiOS
import React

@objc(AliyunOss)
class AliyunOss: RCTEventEmitter {
    
    // MARK: - Static Shared Client (保持生命周期全局有效)
    private static var sharedClient: OSSClient?
    
    // 上传任务集合（线程安全）
    private let tasksLock = NSLock()
    private var tasks: [String: OSSPutObjectRequest] = [:]
    
    // MARK: - React Native Module Setup
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    override func supportedEvents() -> [String]! {
        return ["AliyunOssProgress"]
    }
    
    override init() {
        super.init()
        // 监听 App 生命周期（防止后台 session 被系统终止）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        print("AliyunOss module deinitialized")
    }
    
    @objc private func appWillResignActive() {
        // 防止系统强制终止会话时出错，可在后台时取消未完成的任务
        tasksLock.lock()
        defer { tasksLock.unlock() }
        for (_, req) in tasks {
            req.cancel()
        }
        tasks.removeAll()
    }
    
    // MARK: - 初始化 OSS Client
    @objc(initOSS:withAccessKeySecret:withSecurityToken:withEndpoint:withResolver:withRejecter:)
    func initOSS(accessKeyId: String,
                 accessKeySecret: String,
                 securityToken: String,
                 endpoint: String,
                 resolve: @escaping RCTPromiseResolveBlock,
                 reject: @escaping RCTPromiseRejectBlock) {
        
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
        conf.timeoutIntervalForRequest = 60 * 30
        conf.timeoutIntervalForResource = 60
        conf.isAllowUACarrySystemInfo = true
        conf.isHttpdnsEnable = true
        
        AliyunOss.sharedClient = OSSClient(
            endpoint: endpoint,
            credentialProvider: credentialProvider,
            clientConfiguration: conf
        )
        
        resolve(true)
    }
    
    // MARK: - 上传文件（带进度回调）
    @objc(simpleUpload:withTargetPath:withLocalFilePath:withUploadId:withResolver:withRejecter:)
    func simpleUpload(bucket: String,
                      targetPath: String,
                      localFilePath: String,
                      uploadId: String,
                      resolve: @escaping RCTPromiseResolveBlock,
                      reject: @escaping RCTPromiseRejectBlock) {
        
        guard let client = AliyunOss.sharedClient else {
            reject("UPLOAD_FAIL", "OSS not initialized", nil)
            return
        }
        
        // 构建上传请求
        let put = OSSPutObjectRequest()
        put.bucketName = bucket
        put.objectKey = targetPath
        
        // 文件路径处理
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
        
        // 进度回调
        put.uploadProgress = { [weak self] bytesSent, totalBytesSent, totalBytesExpectedToSend in
            guard let self = self else { return }
            let event: [String: Any] = [
                "uploadId": uploadId,
                "type": "progress",
                "current": totalBytesSent,
                "total": totalBytesExpectedToSend
            ]
            DispatchQueue.main.async {
                self.sendEvent(withName: "AliyunOssProgress", body: event)
            }
        }
        
        // 保存请求对象以支持 cancel
        tasksLock.lock()
        tasks[uploadId] = put
        tasksLock.unlock()
        
        // 执行上传（后台线程，防止阻塞 UI）
        DispatchQueue.global(qos: .userInitiated).async {
            let task = client.putObject(put)
            task.continue({ [weak self] t -> Any? in
                guard let self = self else { return nil }
                
                DispatchQueue.main.async {
                    if let error = t.error {
                        let event: [String: Any] = [
                            "uploadId": uploadId,
                            "type": "failed",
                            "error": error.localizedDescription
                        ]
                        self.sendEvent(withName: "AliyunOssProgress", body: event)
                        reject("UPLOAD_EXCEPTION", "Upload failed", error)
                    } else if t.isCancelled {
                        let event: [String: Any] = [
                            "uploadId": uploadId,
                            "type": "cancelled"
                        ]
                        self.sendEvent(withName: "AliyunOssProgress", body: event)
                        reject("UPLOAD_CANCELLED", "Upload was cancelled", nil)
                    } else {
                        resolve("OK: done")
                    }
                    
                    // 上传结束后清理任务
                    self.tasksLock.lock()
                    self.tasks.removeValue(forKey: uploadId)
                    self.tasksLock.unlock()
                }
                return nil
            })
        }
    }
    
    // MARK: - 取消上传任务
    @objc func cancelUpload(_ uploadId: String) {
        tasksLock.lock()
        defer { tasksLock.unlock() }
        
        if let request = tasks[uploadId] {
            DispatchQueue.global(qos: .utility).async {
                request.cancel()
            }
            tasks.removeValue(forKey: uploadId)
        }
    }
}
