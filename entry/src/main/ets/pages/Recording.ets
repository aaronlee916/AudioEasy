
@Component
export default struct Recording {
  @State message: string = 'Hello World';

  build() {
    Column(){
      Button("开始录制").onClick(()=>this.startRecording)
    }
  }
  startRecording(){

  }
}