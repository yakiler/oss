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
export function simpleUpload(
  bucket: string,
  objectKey: string,
  filePath: string,
  onProgress?: (current: number, total: number) => void
): Promise<string> {
  return new Promise((resolve, reject) => {
    // 监听进度事件
    const subscription = AliyunOssEmitter.addListener(
      'AliyunOssProgress',
      (event) => {
        if (event?.type === 'progress' && onProgress) {
          onProgress(event.current, event.total);
        }
      }
    );

    // 调用原生上传
    AliyunOss.simpleUpload(bucket, objectKey, filePath)
      .then((res: string) => {
        subscription.remove(); // 上传完成，移除监听
        resolve(res);
      })
      .catch((err: any) => {
        subscription.remove(); // 出错也要移除监听
        reject(err);
      });
  });
}

// 断点续传上传
export function resumableUpload(
  bucket: string,
  objectKey: string,
  filePath: string,
  checkpointDir: string
): Promise<string> {
  return AliyunOss.resumableUpload(bucket, objectKey, filePath, checkpointDir);
}

// 分片上传
export function multipartUploadSync(
  bucket: string,
  objectKey: string,
  filePath: string,
  partSize: number
): Promise<string> {
  return AliyunOss.multipartUploadSync(bucket, objectKey, filePath, partSize);
}
