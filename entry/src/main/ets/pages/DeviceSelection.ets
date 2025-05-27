import { audio } from '@kit.AudioKit';  // 导入audio模块。
import DeviceCard from '../components/DeviceCard';

let audioManager = audio.getAudioManager();  // 需要先创建AudioManager实例。
let audioRoutingManager = audioManager.getRoutingManager();  // 再调用AudioManager的方法创建AudioRoutingManager实例。
let audioDevices:audio.AudioDeviceDescriptors;
async function getDevices(){
  audioDevices = await audioRoutingManager.getDevices(audio.DeviceFlag.INPUT_DEVICES_FLAG).then((data: audio.AudioDeviceDescriptors) => data);
}
getDevices()

@Component
export default struct DeviceSelection {

  build() {
    RelativeContainer() {
      ForEach(audioDevices,(item:audio.AudioDeviceDescriptor)=>{
        DeviceCard({deviceName:item.displayName})
      })
    }
    .height('100%')
    .width('100%')
  }
}

