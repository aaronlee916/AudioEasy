import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { abilityAccessCtrl, PermissionRequestResult, Permissions } from '@kit.AbilityKit';

let min = 0;
let sec = 0;
let sampling_rate: number;
let audioInputDevice: audio.AudioDeviceDescriptor = (AppStorage.get('audioInputDevice') as audio.AudioDeviceDescriptor);
let recordingTime = `${min.toString().padStart(2, '0')}:${sec.toString().padStart(2, '0')}`;
let isRecording = false;
let total_sec = 0;
let timer: number;

const TAG = 'AudioCapturerDemo';

class Options {
  offset?: number;
  length?: number;
}

let bufferSize: number = 0;
let audioCapturer: audio.AudioCapturer | undefined = undefined;
let audioStreamInfo: audio.AudioStreamInfo = {
  samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_44100,
  channels: audio.AudioChannel.CHANNEL_2,
  sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
  encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
};
let audioCapturerInfo: audio.AudioCapturerInfo = {
  source: audio.SourceType.SOURCE_TYPE_MIC,
  capturerFlags: 0
};
let audioCapturerOptions: audio.AudioCapturerOptions = {
  streamInfo: audioStreamInfo,
  capturerInfo: audioCapturerInfo
};
let path = getContext().cacheDir;
let filePath = path + '/recording.pcm'; // Changed to a more generic filename
let file: fs.File | undefined = undefined;

let readDataCallback = (buffer: ArrayBuffer) => {
  if (!file) return;

  let options: Options = {
    offset: bufferSize,
    length: buffer.byteLength
  };
  fs.writeSync(file.fd, buffer, options);
  bufferSize += buffer.byteLength;
};

function init() {
  audio.createAudioCapturer(audioCapturerOptions, (err, capturer) => {
    if (err) {
      console.error(`Invoke createAudioCapturer failed, code is ${err.code}, message is ${err.message}`);
      return;
    }
    console.info(`${TAG}: create AudioCapturer success`);
    audioCapturer = capturer;
    if (audioCapturer !== undefined) {
      audioCapturer.on('readData', readDataCallback);
    }
  });
}

function start() {
  if (audioCapturer !== undefined) {
    let stateGroup = [audio.AudioState.STATE_PREPARED, audio.AudioState.STATE_PAUSED, audio.AudioState.STATE_STOPPED];
    if (stateGroup.indexOf(audioCapturer.state.valueOf()) === -1) {
      console.error(`${TAG}: start failed`);
      return;
    }

    // Open file when starting recording
    file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    bufferSize = 0; // Reset buffer size for new recording

    audioCapturer.start((err: BusinessError) => {
      if (err) {
        console.error('Capturer start failed.');
      } else {
        console.info('Capturer start success.');
      }
    });
  }
}

function stop() {
  if (audioCapturer !== undefined) {
    if (audioCapturer.state.valueOf() !== audio.AudioState.STATE_RUNNING &&
      audioCapturer.state.valueOf() !== audio.AudioState.STATE_PAUSED) {
      console.info('Capturer is not running or paused');
      return;
    }

    audioCapturer.stop((err: BusinessError) => {
      if (err) {
        console.error('Capturer stop failed.');
      } else {
        if (file) {
          fs.closeSync(file);
          file = undefined;
        }
        console.info('Capturer stop success.');
      }
    });
  }
}

function release() {
  if (audioCapturer !== undefined) {
    if (audioCapturer.state.valueOf() === audio.AudioState.STATE_RELEASED ||
      audioCapturer.state.valueOf() === audio.AudioState.STATE_NEW) {
      console.info('Capturer already released');
      return;
    }

    audioCapturer.release((err: BusinessError) => {
      if (err) {
        console.error('Capturer release failed.');
      } else {
        console.info('Capturer release success.');
      }
    });
  }
}

function startTimer() {
  timer = setInterval(() => {
    total_sec++;
    min = Math.floor(total_sec / 60);
    sec = total_sec % 60;
    recordingTime = `${min.toString().padStart(2, '0')}:${sec.toString().padStart(2, '0')}`;
  }, 1000);
}

function stopTimer() {
  clearInterval(timer);
  total_sec = 0;
  min = 0;
  sec = 0;
  recordingTime = `${min.toString().padStart(2, '0')}:${sec.toString().padStart(2, '0')}`;
}

init();

@Component
export default struct Recording {
  @State time: string = recordingTime;
  @State recording: boolean = isRecording;

  build() {
    Column() {
      Text(this.time)
        .fontSize(48)
      Button(this.recording ? "停止录制" : "开始录制")
        .onClick(() => {
          this.onClickHandler();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  onClickHandler() {
    if (!this.recording) {
      start();
      startTimer();
    } else {
      stop();
      stopTimer();
    }
    this.recording = !this.recording;
    this.time = recordingTime;
  }
}