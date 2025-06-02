import { audio } from '@kit.AudioKit';  // 导入audio模块。
import DeviceCard from '../components/DeviceCard';

let audioManager = audio.getAudioManager();  // 需要先创建AudioManager实例。
let audioRoutingManager = audioManager.getRoutingManager();  // 再调用AudioManager的方法创建AudioRoutingManager实例。
let inputAudioDevices:audio.AudioDeviceDescriptors;
let outputAudioDevices:audio.AudioDeviceDescriptors;
async function getDevices(){
  inputAudioDevices = await audioRoutingManager.getDevices(audio.DeviceFlag.INPUT_DEVICES_FLAG).then((data: audio.AudioDeviceDescriptors) => data);
  outputAudioDevices=await audioRoutingManager.getDevices(audio.DeviceFlag.OUTPUT_DEVICES_FLAG)
}
getDevices()


function setInputDevice(device:audio.AudioDeviceDescriptor){
  AppStorage.set('audioInputDevice',device)
}

@Component
export default struct DeviceSelection {

  build() {
    Stack() {

      ForEach(inputAudioDevices,(item:audio.AudioDeviceDescriptor)=>{
        DeviceCard({deviceName:item.displayName})
          .onClick(()=>setInputDevice(item))

      })

      ForEach(outputAudioDevices,
        (item: audio.AudioDeviceDescriptor) => {
          DeviceCard({ deviceName: item.displayName })
            .onClick(() => AppStorage.set('audioOutputDevice', item))
        })

    }
    .height('100%')
    .width('100%')
  }
}

