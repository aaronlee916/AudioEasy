


          
# AudioEasy

![GitHub Repo stars](https://img.shields.io/github/stars/aaronlee916/AudioEasy?style=social)
![GitHub last commit](https://img.shields.io/github/last-commit/aaronlee916/AudioEasy)

AudioEasy is an audio recording application developed based on the HarmonyOS operating system. This application allows users to record audio using the device's microphone and save the recorded audio as a WAV file.

## Project Structure
```plaintext
AudioEasy/
├── .arkui-x/
│   ├── android/
│   ├── arkui-x-config.json5
│   └── ios/
├── .gitignore
├── AppScope/
│   ├── app.json5
│   └── resources/
├── build-profile.json5
├── code-linter.json5
├── entry/
│   ├── .gitignore
│   ├── build-profile.json5
│   ├── hvigorfile.ts
│   ├── obfuscation-rules.txt
│   ├── oh-package.json5
│   └── src/
├── hvigor/
│   └── hvigor-config.json5
├── hvigorfile.ts
├── oh-package-lock.json5
└── oh-package.json5
```

## Main Features
- **Audio Recording**: Record audio using the device's microphone.
- **File Saving**: Save the recorded audio as a WAV file.
- **Permission Management**: Automatically request microphone permissions.

## Environment Requirements
- **Operating System**: HarmonyOS 5.0.5(17) or higher.
- **Development Tools**: IDE that supports HarmonyOS development.

## Installation and Running
### Clone the Repository
```bash
git clone https://github.com/aaronlee916/AudioEasy.git
cd AudioEasy
```

### Run the Project
1. Ensure that your development environment has an IDE that supports HarmonyOS development installed.
2. Open the project folder `AudioEasy`.
3. In `EntryAbility.ets`, the application will automatically request microphone permissions.
4. Build and run the project. Click "Start Recording" on the application interface to start audio recording, and click "Stop Recording" to stop recording.

## Code Structure
### Main Files
- `entry/src/main/ets/pages/Recording.ets`: The main implementation of the audio recording function.
- `entry/src/main/ets/entryability/EntryAbility.ets`: The implementation of the application's entry ability.

### Configuration Files
- `entry/src/main/module.json5`: Module configuration file that defines the basic information of the module, permission requests, and ability configurations.
- `build-profile.json5`: Build configuration file that includes the application's signature configuration, product configuration, and build mode configuration.

## Testing
The project includes some test cases located in the `entry/src/ohosTest` directory. You can use the HarmonyOS development tools to run these test cases to verify the functionality of the application.

## Contribution
If you want to contribute to this project, please follow these steps:
1. Fork this repository.
2. Create a new branch (`git checkout -b feature/your-feature`).
3. Commit your changes (`git commit -am 'Add some feature'`).
4. Push to the branch (`git push origin feature/your-feature`).
5. Open a Pull Request.

## License
This project is licensed under the [MIT License](LICENSE).

## Contact Information
If you have any questions or suggestions, please feel free to contact us.
- Email: your.email@example.com
- GitHub Repository: https://github.com/aaronlee916/AudioEasy

        
