import { NativeModules, Platform, NativeEventEmitter } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-aliyun-oss' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const AliyunOss = NativeModules.AliyunOss
  ? NativeModules.AliyunOss
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export function multiply(a: number, b: number): Promise<number> {
  return AliyunOss.multiply(a, b);
}

/** =======================
 * 事件监听：进度条
 * ======================= */
export const AliyunOssEmitter = new NativeEventEmitter(AliyunOss);

/** =======================
 * JS API 封装
 * ======================= */

// 初始化 OSS
export function initOSS(
  accessKeyId: string,
  accessKeySecret: string,
  securityToken: string,
  endpoint: string
): Promise<boolean> {
  return AliyunOss.initOSS(
    accessKeyId,
    accessKeySecret,
    securityToken,
    endpoint
  );
}

// 简单上传（异步，带进度）
// simpleUpload 支持多个任务
export function simpleUpload(
  bucket: string,
  targetPath: string,
  filePath: string,
  onProgress?: (current: number, total: number, taskId: string) => void,
  onCancel?: () => void,
  onFailed?: (error: any) => void
): Promise<{ result: string; uploadId: string }> {
  return new Promise((resolve, reject) => {
    const uploadId = `${bucket}:${targetPath}:${Date.now()}`;

    const progressSub = AliyunOssEmitter.addListener(
      'AliyunOssProgress',
      (event) => {
        if (event?.uploadId !== uploadId) return; // 只处理当前任务

        if (event?.type === 'progress' && onProgress) {
          onProgress(event.current, event.total, event.uploadId);
        } else if (event?.type === 'cancelled') {
          progressSub.remove();
          onCancel?.();
          reject(new Error('Upload cancelled'));
        } else if (event?.type === 'failed') {
          progressSub.remove();
          onFailed?.(event.error);
          reject(new Error(event.error?.message || 'Upload failed'));
        }
      }
    );

    AliyunOss.simpleUpload(bucket, targetPath, filePath, uploadId)
      .then((res: string) => {
        progressSub.remove();
        resolve({ result: res, uploadId });
      })
      .catch((err: any) => {
        progressSub.remove();
        onFailed?.(err);
        reject(err);
      });
  });
}

// 取消指定任务
export function cancelUpload(uploadId: string) {
  AliyunOss.cancelUpload(uploadId);
}

// 断点续传上传
export function resumableUpload(
  bucket: string,
  targetPath: string,
  filePath: string,
  checkpointDir: string
): Promise<string> {
  return AliyunOss.resumableUpload(bucket, targetPath, filePath, checkpointDir);
}

// 分片上传
export function multipartUploadSync(
  bucket: string,
  targetPath: string,
  filePath: string,
  partSize: number
): Promise<string> {
  return AliyunOss.multipartUploadSync(bucket, targetPath, filePath, partSize);
}
