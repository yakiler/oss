import { useState, useEffect } from 'react';
import { Text, View, StyleSheet, Button } from 'react-native';
import { multiply, initOSS, simpleUpload } from 'react-native-aliyun-oss';
import { launchImageLibrary } from 'react-native-image-picker';

const data = {
  key: '',
  secret: '',
  securityToken: '',
  endPoint: '',
  bucketName: '',
};
export default function App() {
  const [result, setResult] = useState<number | undefined>();
  const [progress, setProgress] = useState('进度：0%');

  const [selectedFile, setSelectedFile] = useState('');

  const handle = () => {
    launchImageLibrary(
      { mediaType: 'photo', selectionLimit: 3 },
      async (response) => {
        const uri =
          response.assets?.[0]?.originalPath || response.assets?.[0]?.uri;
        console.log('res', uri, response.assets?.[0]);
        setSelectedFile(uri ?? '');
      }
    );
  };

  useEffect(() => {
    multiply(4, 7).then(setResult);
    console.log(11, initOSS);
  }, []);

  const init = async () => {
    console.log('i');
    const r = await initOSS(
      data.key,
      data.secret,
      data.securityToken,
      data.endPoint
    );
    console.log('r', r);
  };

  const upload = async () => {
    console.log('uu', selectedFile);
    const res = await simpleUpload(
      data.bucketName,
      '/aaaaa.jpg',
      selectedFile,
      (current, total) => {
        setProgress(`上传进度: ${((current / total) * 100).toFixed(2)}%`);
      }
    ).catch((err) => {
      console.log('err', err);
    });
    console.log('upload', res);
  };

  return (
    <View style={styles.container}>
      <Text>Result: {result}</Text>
      <Text>{progress}</Text>
      <Button title="初始化" onPress={() => init()} />
      <Button title="选择文件" onPress={handle} />
      <Button title="上传" onPress={upload} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
  },
});
