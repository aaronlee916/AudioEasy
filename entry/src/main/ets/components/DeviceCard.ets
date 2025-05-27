@Component
export default struct DeviceCard{
  @Prop deviceName:string;
  build() {
    Stack(){
      Text(this.deviceName)
        .align(Alignment.Center)
    }
    .width('80%')
    .height('10%')
    .backgroundColor('#636AE8FF')
    .borderRadius('20')

  }
}