@Component
export default struct DeviceCard{
  @Prop deviceName:string;
  build() {
    RelativeContainer(){
      Text(this.deviceName)
    }
  }
}