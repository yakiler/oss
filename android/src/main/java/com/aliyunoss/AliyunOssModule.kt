package com.aliyunoss

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.Arguments
import com.facebook.react.modules.core.DeviceEventManagerModule

import java.io.FileInputStream
import java.io.InputStream

import com.alibaba.sdk.android.oss.*
import com.alibaba.sdk.android.oss.common.auth.*
import com.alibaba.sdk.android.oss.model.*
import com.alibaba.sdk.android.oss.callback.*

import android.util.Log

class AliyunOssModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  private var ossClient: OSSClient? = null

  override fun getName(): String {
    return NAME
  }

  @ReactMethod
  fun initOSS(accessKeyId: String, accessKeySecret: String, securityToken: String, endpoint: String, promise: Promise) {
      try {
          val credentialProvider = OSSStsTokenCredentialProvider(accessKeyId, accessKeySecret, securityToken)
          val conf = ClientConfiguration().apply {
              connectionTimeout = 15 * 1000 // 连接超时，默认15秒
              socketTimeout = 15 * 1000 // socket超时
              maxConcurrentRequest = 5 // 最大并发请求数
              maxErrorRetry = 2 // 失败后最大重试次数
          }
          ossClient = OSSClient(reactApplicationContext, endpoint, credentialProvider, conf)
          promise.resolve(true)
      } catch (e: Exception) {
          promise.reject("INIT_ERROR", e)
      }
  }

  /** 简单上传 同步 */
  @ReactMethod
  fun simpleUploadSync(bucket: String, targetPath: String, localFilePath: String, promise: Promise) {
    // 打印传入的所有参数 
    Log.d("UploadModule", "simpleUploadSync桶桶桶桶桶桶: $bucket")  // 使用Kotlin字符串模板简化拼接
    Log.d("UploadModule", "simpleUploadSync远程路径: $targetPath")  // 使用Kotlin字符串模板简化拼接
    Log.d("UploadModule", "simpleUploadSync路径路径路径路径路径路径: $localFilePath")

      try {
          val request = PutObjectRequest(bucket, targetPath, localFilePath)
          Log.d("UploadModule", "simpleUploadSync构造对象:$request")
          val result = ossClient?.putObject(request)
          Log.d("UploadModule", "simpleUploadSync结果结果:$result")
          if (result != null) promise.resolve("OK: ${result.serverCallbackReturnBody ?: "done"}")
          else promise.reject("UPLOAD_FAIL", "Result null")
      } catch (e: Exception) {
          Log.d("UploadModule", "simpleUploadSync报错了:$e")
          promise.reject("UPLOAD_EXCEPTION", e)
      }
  }

  /** 简单上传 异步 + 进度 + 回调 */
  @ReactMethod
  fun simpleUpload(bucket: String, targetPath: String, localFilePath: String, promise: Promise) {
      try {
          val request = PutObjectRequest(bucket, targetPath, localFilePath).apply {
              // 设置进度回调
              progressCallback = OSSProgressCallback<PutObjectRequest> { _, currentSize, totalSize ->
                  val params = Arguments.createMap().apply {
                      putString("type", "progress")
                      putDouble("current", currentSize.toDouble())
                      putDouble("total", totalSize.toDouble())
                  }
                  reactApplicationContext
                      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
                      .emit("AliyunOssProgress", params)
              }
          }

          // 异步上传
          ossClient?.asyncPutObject(
              request,
              object : OSSCompletedCallback<PutObjectRequest, PutObjectResult> {
                  override fun onSuccess(req: PutObjectRequest, result: PutObjectResult) {
                      promise.resolve(result.serverCallbackReturnBody ?: "done")
                  }

                  override fun onFailure(
                      req: PutObjectRequest,
                      clientEx: ClientException?,
                      serviceEx: ServiceException?
                  ) {
                      promise.reject("UPLOAD_FAIL", clientEx ?: serviceEx)
                  }
              }
          )
      } catch (e: Exception) {
          promise.reject("UPLOAD_EXCEPTION", e)
      }
  }


  // /** 断点续传（Resumable） */
  // @ReactMethod
  // fun resumableUpload(bucket: String, objectKey: String, localFilePath: String, checkpointDir: String, promise: Promise) {
  //     try {
  //         val task = ossClient?.resumableUpload(
  //             ResumableUploadRequest(bucket, objectKey, localFilePath).apply {
  //                 this.recordDir = checkpointDir
  //                 this.progressCallback = OSSProgressCallback { _, cur, total ->
  //                     val params = Arguments.createMap().apply {
  //                         putString("type", "resumableProgress")
  //                         putDouble("current", cur.toDouble())
  //                         putDouble("total", total.toDouble())
  //                     }
  //                     reactApplicationContext
  //                         .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
  //                         .emit("AliyunOssProgress", params)
  //                 }
  //             }
  //         )
  //         task?.waitUntilFinished()
  //         val result = task?.result
  //         if (result != null) promise.resolve("Resumable done")
  //         else promise.reject("RESUMABLE_FAIL", "Result null")
  //     } catch (e: Exception) {
  //         promise.reject("RESUMABLE_EXCEPTION", e)
  //     }
  // }

  // /** 分片上传流程示例 同步方式 */
  // @ReactMethod
  // fun multipartUploadSync(bucket: String, objectKey: String, localFilePath: String, partSize: Long, promise: Promise) {
  //     try {
  //         val file = File(localFilePath)
  //         val initRequest = InitiateMultipartUploadRequest(bucket, objectKey)
  //         val initResult = ossClient!!.initMultipartUpload(initRequest)
  //         val uploadId = initResult.uploadId

  //         val partETags = mutableListOf<PartETag>()
  //         val totalSize = file.length()
  //         val bufferCount = ((totalSize + partSize - 1) / partSize).toInt()

  //         for (i in 0 until bufferCount) {
  //             val offset = i * partSize
  //             val size = if (offset + partSize > totalSize) (totalSize - offset) else partSize
  //             val partRequest = UploadPartRequest(bucket, objectKey, uploadId, i + 1, localFilePath, offset, size)
  //             val partResult = ossClient!!.uploadPart(partRequest)
  //             partETags.add(PartETag(partResult.partNum, partResult.etag))
  //         }
  //         val completeRequest = CompleteMultipartUploadRequest(bucket, objectKey, uploadId, partETags)
  //         ossClient!!.completeMultipartUpload(completeRequest)
  //         promise.resolve("Multipart done")
  //     } catch (e: Exception) {
  //         promise.reject("MULTIPART_FAIL", e)
  //     }
  // }

  // Example method
  // See https://reactnative.dev/docs/native-modules-android
  @ReactMethod
  fun multiply(a: Double, b: Double, promise: Promise) {
    promise.resolve(a * b)
  }

  companion object {
    const val NAME = "AliyunOss"
  }
}
