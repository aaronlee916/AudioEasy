import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { Context } from '@kit.AbilityKit';

const TAG: string = 'AudioCapturerDemo';

interface WriteOptions {
  offset: number;
  length: number;
}

@Component
export default struct RecordingPage {
  // Audio capturer state
  private audioCapturer: audio.AudioCapturer | null = null;
  private bufferSize: number = 0;
  private file: fs.File | null = null;
  private filePath: string = '';

  // UI state
  @State private totalSeconds: number = 0;
  @State private isRecording: boolean = false;
  @State private isInitialized: boolean = false;
  @State private errorMessage: string = '';
  private timerId: number | null = null;

  // Audio configuration
  private readonly audioStreamInfo: audio.AudioStreamInfo = {
    samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_44100,
    channels: audio.AudioChannel.CHANNEL_2,
    sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
    encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
  };

  private readonly audioCapturerOptions: audio.AudioCapturerOptions = {
    streamInfo: this.audioStreamInfo,
    capturerInfo: {
      source: audio.SourceType.SOURCE_TYPE_MIC,
      capturerFlags: 0
    }
  };

  aboutToAppear(): void {
    this.initializeAudioCapturer();
  }

  private initializeAudioCapturer(): void {
    audio.createAudioCapturer(this.audioCapturerOptions, (err: BusinessError, capturer: audio.AudioCapturer) => {
      if (err) {
        this.errorMessage = `Initialization failed: ${err.code}`;
        console.error(TAG, this.errorMessage);
        return;
      }

      this.audioCapturer = capturer;
      this.isInitialized = true;
      console.info(TAG, 'AudioCapturer initialized successfully');

      // Set up data callback
      this.audioCapturer.on('readData', (buffer: ArrayBuffer) => {
        this.handleAudioData(buffer);
      });
    });
  }

  private handleAudioData(buffer: ArrayBuffer): void {
    if (!this.file) return;

    try {
      const options: WriteOptions = {
        offset: this.bufferSize,
        length: buffer.byteLength
      };
      fs.writeSync(this.file.fd, buffer, options);
      this.bufferSize += buffer.byteLength;
    } catch (writeErr) {
      this.errorMessage = `Write failed: ${(writeErr as Error).message}`;
      console.error(TAG, this.errorMessage);
    }
  }

  private async startRecording(): Promise<void> {
    if (!this.audioCapturer || !this.isInitialized) {
      this.errorMessage = 'Audio capturer not ready';
      return;
    }

    try {
      // Ensure we have a valid file path
      await this.chooseFilePath();

      this.file = fs.openSync(this.filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      this.bufferSize = 0;

      this.audioCapturer.start((err: BusinessError) => {
        if (err) {
          this.errorMessage = `Start failed: ${err.code}`;
          console.error(TAG, this.errorMessage);
          return;
        }
        this.isRecording = true;
        this.startTimer();
        console.info(TAG, 'Recording started');
      });
    } catch (err) {
      this.errorMessage = `Recording setup failed: ${(err as Error).message}`;
      console.error(TAG, this.errorMessage);
    }
  }

  private stopRecording(): void {
    if (!this.audioCapturer || !this.isRecording) {
      return;
    }

    console.info(TAG, `Current state: ${this.audioCapturer.state}`);

    this.audioCapturer.stop((err: BusinessError) => {
      if (err) {
        this.errorMessage = `Stop failed: ${err.code}`;
        console.error(TAG, this.errorMessage);
        return;
      }

      try {
        this.cleanupAfterRecording();
        console.info(TAG, 'Recording stopped successfully');
      } catch (cleanupErr) {
        this.errorMessage = `Cleanup failed: ${(cleanupErr as Error).message}`;
        console.error(TAG, this.errorMessage);
      } finally {
        this.isRecording = false;
        this.stopTimer();
      }
    });
  }

  private cleanupAfterRecording(): void {
    if (this.file) {
      fs.closeSync(this.file);
      this.file = null;
    }
    if (this.filePath) {
      this.writeWavHeader();
    }
  }

  private writeWavHeader(): void {
    try {
      const file = fs.openSync(this.filePath, fs.OpenMode.READ_WRITE);
      const headerBuffer = new ArrayBuffer(44);
      const dataView = new DataView(headerBuffer);

      // RIFF header
      dataView.setUint32(0, 0x52494646, false); // "RIFF"
      dataView.setUint32(4, this.bufferSize + 36, true); // File size
      dataView.setUint32(8, 0x57415645, false); // "WAVE"

      // Format chunk
      dataView.setUint32(12, 0x666d7420, false); // "fmt "
      dataView.setUint32(16, 16, true); // Chunk size
      dataView.setUint16(20, 1, true); // PCM format
      dataView.setUint16(22, this.audioStreamInfo.channels, true);
      dataView.setUint32(24, this.audioStreamInfo.samplingRate, true);
      dataView.setUint32(28, this.audioStreamInfo.samplingRate * this.audioStreamInfo.channels * 2, true);
      dataView.setUint16(32, this.audioStreamInfo.channels * 2, true);
      dataView.setUint16(34, 16, true);

      // Data chunk
      dataView.setUint32(36, 0x64617461, false); // "data"
      dataView.setUint32(40, this.bufferSize, true);

      fs.writeSync(file.fd, headerBuffer, { offset: 0, length: 44 });
      fs.closeSync(file);
    } catch (err) {
      throw new Error(`WAV header creation failed: ${(err as Error).message}`);
    }
  }

  private async chooseFilePath(): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      const audioSaveOptions = new picker.AudioSaveOptions();
      audioSaveOptions.newFileNames = ['recording.wav'];

      new picker.AudioViewPicker().save(audioSaveOptions)
        .then((uris: Array<string>) => {
          this.filePath = uris[0];
          console.info(TAG, `File path selected: ${this.filePath}`);
          resolve();
        })
        .catch((err: BusinessError) => {
          this.errorMessage = `File selection failed: ${err.code}`;
          console.error(TAG, this.errorMessage);
          reject(err);
        });
    });
  }

  private startTimer(): void {
    this.totalSeconds = 0;
    this.timerId = setInterval(() => {
      this.totalSeconds += 1;
    }, 1000);
  }

  private stopTimer(): void {
    if (this.timerId) {
      clearInterval(this.timerId);
      this.timerId = null;
    }
  }

  private get formattedTime(): string {
    const minutes = Math.floor(this.totalSeconds / 60).toString().padStart(2, '0');
    const seconds = (this.totalSeconds % 60).toString().padStart(2, '0');
    return `${minutes}:${seconds}`;
  }

  private handleRecordClick(): void {
    if (this.isRecording) {
      this.stopRecording();
    } else {
      this.startRecording();
    }
  }

  build() {
    Column({ space: 20 }) {
      Text(this.formattedTime)
        .fontSize(48)
        .fontColor(Color.Black)

      Button(this.isRecording ? 'Stop Recording' : 'Start Recording')
        .onClick(() => this.handleRecordClick())
        .width(200)
        .height(50)
        .fontSize(20)
        .enabled(this.isInitialized)

      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(14)
          .fontColor(Color.Red)
          .margin({ top: 10 })
      }

      if (!this.isInitialized) {
        Text('Initializing audio system...')
          .fontSize(14)
          .fontColor(Color.Gray)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(20)
  }

  aboutToDisappear(): void {
    if (this.isRecording) {
      this.stopRecording();
    }
    if (this.timerId) {
      this.stopTimer();
    }
    if (this.file) {
      fs.closeSync(this.file);
    }
  }
}