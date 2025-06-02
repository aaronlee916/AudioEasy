import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';

const TAG: string = 'AudioRecorder';
const MAX_FILE_SIZE = 0xFFFFFFFF - 44; // Maximum WAV file size (4GB - header)

@Component
export default struct AudioRecorderComponent {
  // Audio capturer instance
  private audioCapturer: audio.AudioCapturer | null = null;
  private bufferSize: number = 0;
  private fileHandle: fs.File | null = null;
  private filePath: string = '';

  // UI state
  @State private recordingTime: number = 0;
  @State private isRecording: boolean = false;
  @State private isInitialized: boolean = false;
  @State private errorMessage: string = '';
  @State private timerId: number | null = null;

  // Audio configuration
  private readonly audioConfig: audio.AudioCapturerOptions = {
    streamInfo: {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_44100,
      channels: audio.AudioChannel.CHANNEL_2,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    },
    capturerInfo: {
      source: audio.SourceType.SOURCE_TYPE_MIC,
      capturerFlags: 0
    }
  };

  aboutToAppear(): void {
    this.initializeAudioCapturer();
  }

  private initializeAudioCapturer(): void {
    audio.createAudioCapturer(this.audioConfig, (err: BusinessError, capturer: audio.AudioCapturer) => {
      if (err) {
        this.handleError('Initialization failed', err);
        return;
      }

      this.audioCapturer = capturer;
      this.isInitialized = true;
      this.setupEventListeners();
      console.info(TAG, 'Audio capturer ready');
    });
  }

  private setupEventListeners(): void {
    this.audioCapturer?.on('readData', (buffer: ArrayBuffer) => {
      this.writeAudioData(buffer);
    });
  }

  private async startRecording(): Promise<void> {
    if (!this.isInitialized || !this.audioCapturer) {
      this.errorMessage = 'Audio system not ready';
      return;
    }

    try {
      await this.prepareOutputFile();

      await new Promise<void>((resolve, reject) => {
        this.audioCapturer?.start((err: BusinessError) => {
          if (err) reject(err);
          else resolve();
        });
      });

      this.isRecording = true;
      this.startTimer();
      console.info(TAG, 'Recording started');
    } catch (err) {
      this.handleError('Recording setup failed', err);
      this.forceCleanup();
    }
  }

  private async prepareOutputFile(): Promise<void> {
    try {
      this.filePath = await this.selectOutputFile();
      this.fileHandle = fs.openSync(this.filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      this.bufferSize = 0;
      // Reserve space for WAV header
      fs.writeSync(this.fileHandle.fd, new ArrayBuffer(44), { offset: 0, length: 44 });
    } catch (err) {
      throw new Error(`File preparation failed: ${(err as Error).message}`);
    }
  }

  private async selectOutputFile(): Promise<string> {
    return new Promise((resolve, reject) => {
      const options = new picker.AudioSaveOptions();
      options.newFileNames = [`recording_${new Date().getTime()}.wav`];

      new picker.AudioViewPicker().save(options)
        .then((uris: string[]) => resolve(uris[0]))
        .catch((err: BusinessError) => reject(err));
    });
  }

  private async stopRecording(): Promise<void> {
    if (!this.audioCapturer || !this.isRecording) {
      return;
    }

    try {
      await new Promise<void>((resolve, reject) => {
        this.audioCapturer?.stop((err: BusinessError) => {
          if (err) {
            if (err.code === 6800301) {
              this.errorMessage = 'Recording stop failed - system resource conflict';
              console.error(TAG, this.errorMessage);
            }
            reject(err);
          } else {
            resolve();
          }
        });
      });

      // Ensure these run after stop completes
      this.isRecording = false;
      this.stopTimer();
      await this.finalizeRecording();

    } catch (err) {
      this.isRecording = false;
      this.stopTimer();
      if (!(err as BusinessError).code || (err as BusinessError).code !== 6800301) {
        this.handleError('Stop failed', err);
      }
      this.forceCleanup();
    }
  }

  private async finalizeRecording(): Promise<void> {
    try {
      if (!this.fileHandle) {
        console.warn(TAG, 'No file handle to finalize');
        return;
      }

      this.writeWavHeader();
      fs.fsyncSync(this.fileHandle.fd);
      fs.closeSync(this.fileHandle);
      this.fileHandle = null;

      console.info(TAG, `Recording saved to ${this.filePath}`);
    } catch (err) {
      this.handleError('Finalization failed', err);
    }
  }

  private forceCleanup(): void {
    try {
      this.isRecording = false;
      this.stopTimer();
      this.finalizeRecording()

      if (this.fileHandle) {
        fs.closeSync(this.fileHandle);
        this.fileHandle = null;
      }

      console.info(TAG, 'Forced cleanup complete');
    } catch (err) {
      console.error(TAG, `Force cleanup error: ${(err as Error).message}`);
    }
  }

  private writeWavHeader(): void {
    if (!this.fileHandle || this.bufferSize === 0) return;

    const header = new ArrayBuffer(44);
    const view = new DataView(header);

    // RIFF header
    view.setUint32(0, 0x52494646, false); // "RIFF"
    view.setUint32(4, Math.min(this.bufferSize + 36, MAX_FILE_SIZE), true);
    view.setUint32(8, 0x57415645, false); // "WAVE"

    // Format chunk
    view.setUint32(12, 0x666d7420, false); // "fmt "
    view.setUint32(16, 16, true);
    view.setUint16(20, 1, true); // PCM
    view.setUint16(22, this.audioConfig.streamInfo.channels, true);
    view.setUint32(24, this.audioConfig.streamInfo.samplingRate, true);
    view.setUint32(28, this.audioConfig.streamInfo.samplingRate * this.audioConfig.streamInfo.channels * 2, true);
    view.setUint16(32, this.audioConfig.streamInfo.channels * 2, true);
    view.setUint16(34, 16, true);

    // Data chunk
    view.setUint32(36, 0x64617461, false); // "data"
    view.setUint32(40, this.bufferSize, true);

    fs.writeSync(this.fileHandle.fd, header, { offset: 0, length: 44 });
  }

  private writeAudioData(buffer: ArrayBuffer): void {
    if (!this.fileHandle || !this.isRecording) return;

    try {
      if (this.bufferSize + buffer.byteLength > MAX_FILE_SIZE) {
        throw new Error('Maximum file size reached');
      }

      fs.writeSync(this.fileHandle.fd, buffer, {
        offset: this.bufferSize + 44,
        length: buffer.byteLength
      });
      this.bufferSize += buffer.byteLength;
    } catch (err) {
      this.handleError('Write failed', err);
      this.stopRecording();
    }
  }

  private startTimer(): void {
    this.recordingTime = 0;
    this.timerId = setInterval(() => {
      this.recordingTime += 1;
    }, 1000);
  }

  private stopTimer(): void {
    if (typeof(this.timerId)==='number') {
      clearInterval(this.timerId);
      this.timerId = null;
    }
  }

  private formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60).toString().padStart(2, '0');
    const secs = (seconds % 60).toString().padStart(2, '0');
    return `${mins}:${secs}`;
  }

  private handleError(context: string, error: BusinessError | Error): void {
    const code = (error as BusinessError).code ? ` (code ${(error as BusinessError).code})` : '';
    this.errorMessage = `${context}: ${error.message}${code}`;
    console.error(TAG, this.errorMessage);
  }

  private async toggleRecording(): Promise<void> {
    if (this.isRecording) {
      await this.stopRecording();
    } else {
      await this.startRecording();
    }
  }

  aboutToDisappear(): void {
    if (this.isRecording) {
      this.stopRecording();
    }
    this.stopTimer();

    if (this.fileHandle) {
      fs.closeSync(this.fileHandle);
    }

    this.audioCapturer?.off('readData');
    this.audioCapturer?.release();
  }

  build() {
    Column({ space: 20 }) {
      Text(this.formatTime(this.recordingTime))
        .fontSize(48)
        .fontColor(Color.Black)

      Button(this.isRecording ? 'Stop Recording' : 'Start Recording')
        .onClick(() => this.toggleRecording())
        .width(200)
        .height(50)
        .fontSize(20)
        .enabled(this.isInitialized && !this.errorMessage)

      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(14)
          .fontColor(Color.Red)
          .margin({ top: 10 })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
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
}