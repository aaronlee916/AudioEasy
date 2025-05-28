import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';

const TAG: string = 'AudioCapturerDemo';

// Audio configuration types
interface WriteOptions {
  offset: number;
  length: number;
}

// Audio capturer state
let bufferSize: number = 0;
let audioCapturer: audio.AudioCapturer | null = null;
const audioStreamInfo: audio.AudioStreamInfo = {
  samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_44100,
  channels: audio.AudioChannel.CHANNEL_2,
  sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
  encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
};

const audioCapturerInfo: audio.AudioCapturerInfo = {
  source: audio.SourceType.SOURCE_TYPE_MIC,
  capturerFlags: 0
};

const audioCapturerOptions: audio.AudioCapturerOptions = {
  streamInfo: audioStreamInfo,
  capturerInfo: audioCapturerInfo
};

// File handling
const context: Context = getContext() as Context;
const audioSaveOptions = new picker.AudioSaveOptions();
const path: string = context.cacheDir;
let filePath:string;
let file: fs.File | null = null;
let uri: string = '';
// 请确保 getContext(this) 返回结果为 UIAbilityContext
const audioViewPicker = new picker.AudioViewPicker(context);


// Initialize audio capturer with proper typing
function initAudioCapturer(): void {
  audio.createAudioCapturer(audioCapturerOptions, (err: BusinessError, capturer: audio.AudioCapturer) => {
    if (err) {
      console.error(`AudioCapturer creation failed: ${err.code}, ${err.message}`);
      return;
    }
    console.info(`${TAG}: AudioCapturer created successfully`);
    audioCapturer = capturer;

    if (audioCapturer) {
      audioCapturer.on('readData', (buffer: ArrayBuffer) => {
        if (!file) return;

        const options: WriteOptions = {
          offset: bufferSize,
          length: buffer.byteLength
        };

        try {
          fs.writeSync(file.fd, buffer, options);
          bufferSize += buffer.byteLength;
        } catch (writeErr) {
          console.error(`Write failed: ${(writeErr as Error).message}`);
        }
      });
    }
  });
}

// Start recording with state checks
function startRecording(): void {
  if (!audioCapturer) {
    console.error('AudioCapturer not initialized');
    return;
  }

  const validStates: audio.AudioState[] = [
    audio.AudioState.STATE_PREPARED,
    audio.AudioState.STATE_PAUSED,
    audio.AudioState.STATE_STOPPED
  ];

  if (!validStates.includes(audioCapturer.state.valueOf())) {
    console.error(`${TAG}: Cannot start in current state`);
    return;
  }

  try {
    file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    bufferSize = 0;

    audioCapturer.start((err: BusinessError) => {
      if (err) {
        console.error(`Recording start failed: ${err.code}`);
      } else {
        console.info('Recording started successfully');
      }
    });
  } catch (openErr) {
    console.error(`File open failed: ${(openErr as Error).message}`);
  }
}

// Stop recording with proper cleanup
// 写入 WAV 文件头
function writeWavHeader(filePath: string, bufferSize: number, audioStreamInfo: audio.AudioStreamInfo) {
  try {
    const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE);
    const headerBuffer = new ArrayBuffer(44);
    const dataView = new DataView(headerBuffer);

    // RIFF 块
    dataView.setUint32(0, 0x52494646, false); // 'RIFF'
    dataView.setUint32(4, bufferSize + 36, true); // 文件总长度减去 8 字节
    dataView.setUint32(8, 0x57415645, false); // 'WAVE'

    // fmt 子块
    dataView.setUint32(12, 0x666d7420, false); // 'fmt '
    dataView.setUint32(16, 16, true); // 子块长度
    dataView.setUint16(20, 1, true); // 音频格式（PCM）
    dataView.setUint16(22, audioStreamInfo.channels, true); // 声道数
    dataView.setUint32(24, audioStreamInfo.samplingRate, true); // 采样率
    dataView.setUint32(28, audioStreamInfo.samplingRate * audioStreamInfo.channels * 2, true); // 字节率
    dataView.setUint16(32, audioStreamInfo.channels * 2, true); // 块对齐
    dataView.setUint16(34, 16, true); // 采样位数

    // data 子块
    dataView.setUint32(36, 0x64617461, false); // 'data'
    dataView.setUint32(40, bufferSize, true); // 数据长度

    fs.writeSync(file.fd, headerBuffer, { offset: 0, length: 44 });
    fs.closeSync(file);
  } catch (err) {
    console.error(`Write WAV header failed: ${(err as Error).message}`);
  }
}

// 修改 stopRecording 函数
function stopRecording(): void {
  if (!audioCapturer) {
    console.error('AudioCapturer not initialized');
    return;
  }

  const validStopStates: audio.AudioState[] = [
    audio.AudioState.STATE_RUNNING,
    audio.AudioState.STATE_PAUSED
  ];

  if (!validStopStates.includes(audioCapturer.state.valueOf())) {
    console.info('Not in a stoppable state');
    return;
  }

  audioCapturer.stop((err: BusinessError) => {
    if (err) {
      console.error(`Recording stop failed: ${err.code}`);
    } else {
      try {
        if (file) {
          fs.closeSync(file);
          file = null;
        }
        // 写入 WAV 文件头
        if (filePath) {
          writeWavHeader(filePath, bufferSize, audioStreamInfo);
        }
        console.info('Recording stopped successfully');
      } catch (closeErr) {
        console.error(`File close failed: ${(closeErr as Error).message}`);
      }
    }
  });
}
function chooseFilePath(){
  audioSaveOptions.newFileNames = ['音频01.mp3'];
  audioViewPicker.save(audioSaveOptions).then((audioSelectResult: Array<string>) => {
    filePath = audioSelectResult[0];
    console.info('audioViewPicker.save to file succeed and uri is:' + uri);
  }).catch((err: BusinessError) => {
    console.error(`Invoke audioViewPicker.save failed, code is ${err.code}, message is ${err.message}`);
  })
}
// Initialize the audio capturer
initAudioCapturer();

@Component
export default struct RecordingPage {
  @State private totalSeconds: number = 0;
  @State private isRecording: boolean = false;
  private timerId: number | null = null;

  // Format time as MM:SS
  private get formattedTime(): string {
    const minutes: number = Math.floor(this.totalSeconds / 60);
    const seconds: number = this.totalSeconds % 60;
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  // Start timer with type-safe interval
  private startTimer(): void {
    this.timerId = setInterval(() => {
      this.totalSeconds += 1;
    }, 1000);
  }


  // Stop timer with null check
  private stopTimer(): void {
    if (this.timerId !== null) {
      clearInterval(this.timerId);
      this.timerId = null;
    }
  }

  // Handle record button click
  private handleRecordClick(): void {
    if (this.isRecording) {
      stopRecording();
      this.stopTimer();
    } else {
      chooseFilePath()
      startRecording();
      this.startTimer();
    }
    this.isRecording = !this.isRecording;
  }

  build() {
    Column({ space: 20 }) {
      Text(this.formattedTime)
        .fontSize(48)
        .fontColor(Color.Black)
        .margin({ bottom: 30 })

      Button(this.isRecording ? "停止录制" : "开始录制")
        .onClick(() => this.handleRecordClick())
        .width(200)
        .height(50)
        .fontSize(20)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Color.White)
  }

  aboutToDisappear(): void {
    this.stopTimer();
    if (this.isRecording) {
      stopRecording();
    }
  }
}