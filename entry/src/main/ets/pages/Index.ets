import DeviceSelection from './DeviceSelection';
import Recording from './Recording';

@Entry
@Component
struct Index {
  @State message: string = 'Hello World';

  build() {
    Tabs({barPosition:BarPosition.End}){
      TabContent() {
        Recording()
      }.tabBar("录音")
      TabContent() {
        DeviceSelection()
      }.tabBar("设备管理")
    }
  }
}