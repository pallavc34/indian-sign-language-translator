# Indian Sign Language Translator

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=000)](https://buymeacoffee.com/pallavc34)
[![Android build](https://github.com/pallavc34/indian-sign-language-translator/actions/workflows/android-build.yml/badge.svg?branch=main&event=push)](https://github.com/pallavc34/indian-sign-language-translator/actions/workflows/android-build.yml)

A Flutter app for Android and iOS that turns spoken or typed words into Indian Sign Language (ISL) fingerspelling. Saniya, a 3D avatar, signs each letter. The image keyboard lets users compose text from the ISL alphabet and play it aloud.

[Get it on Google Play](https://play.google.com/store/apps/details?id=com.andrdoc.signlanguage) · [Watch Saniya fingerspell HELLO](docs/phaseplan/hello-simulator.mp4)

The features below describe the source in this repository. Google Play may offer an earlier version.

## Features

| Mode | What you can do |
| --- | --- |
| **Speech to Signs** | Tap the microphone and speak, enter text manually, or select a quick phrase. Saniya fingerspells each word in sequence, then returns to her welcome pose. |
| **Signs to Speech** | Tap A–Z handshape images and Space to build a message. Use Backspace or Clear to edit it, and tap **Speak** to hear it through the device’s text-to-speech engine. Long-press a handshape to enlarge it. |

Use the switch at the top of the app to change modes. The current release of the avatar focuses on **A–Z fingerspelling**. The same English word is spelled letter by letter, so “hello” becomes **H–E–L–L–O**. The app’s ISL coverage is limited to this alphabet and does not include vocabulary or sentence grammar. The image keyboard uses manual selection.

## How it works

1. The microphone uses the platform speech recognizer. A final transcript, typed text, or a quick phrase enters the same playback flow. Speech recognition availability and network requirements depend on the device, language, and recognizer.
2. Flutter groups A–Z letters into words. The bundled Three.js viewer loads Saniya’s rigged GLB and blends between letter poses fitted to the alphabet reference images. The typed-text signing path uses local avatar and pose assets.
3. The image keyboard builds a text string and sends it to the device’s text-to-speech engine when the user taps **Speak**.

| Path | Contents |
| --- | --- |
| `lib/` | Flutter UI, speech recognition, and text-to-speech flow |
| `images/` | ISL alphabet reference images and app graphics |
| `assets/saniya/` and `avatar/likeness/` | Bundled viewer, welcome image, and rigged avatar |
| `tool/saniya/` | Pose data, pose-building tools, and Three.js playback source |
| [`docs/phaseplan/`](docs/phaseplan/README.md) | Implementation plan, alphabet comparison, and demo |

## Run locally

Use Flutter **3.50.1 or newer** with Dart **3.14** or newer. For Android, install the Android SDK and a JDK compatible with the project's Gradle wrapper. For iOS, use macOS with Xcode and CocoaPods. Use a mobile device or simulator with WebGL 2 support for the avatar.

```sh
git clone https://github.com/pallavc34/indian-sign-language-translator.git
cd indian-sign-language-translator
flutter doctor
flutter pub get
```

Android debug builds use Android’s debug signing. To enable Firebase and Crashlytics, register an Android app with package ID `com.andrdoc.signlanguage` in your own Firebase project and put its `google-services.json` in `android/app/`. Keep your Firebase configuration and release-signing files outside contributions.

For iOS, open `ios/Runner.xcworkspace` and select your own signing team and bundle identifier if you run on a physical device. To enable Firebase there, register that bundle ID in your Firebase project and add its `GoogleService-Info.plist` to the Runner target. The app can start with crash reporting unavailable on iOS.

```sh
flutter devices
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with the ID from `flutter devices`. Allow microphone and speech recognition access when testing voice input. If the simulator has no speech recognition service, try typed input or use a physical device for the microphone check.

### Checks

The Android build badge shows the latest build on `main`. GitHub Actions runs static analysis, widget tests, and a debug APK build on pushes to `main` and on pull requests.

```sh
flutter analyze
flutter test test
flutter test integration_test/saniya_test.dart -d DEVICE_ID
```

The integration test supplies a transcript at the speech plugin boundary. Test live microphone capture separately on a device. For changes to the Three.js viewer, rebuild the bundled asset from `tool/saniya/` with `npm ci` and `npm run build`.

## Contributing

Pull requests are welcome. Fork the repository, create a branch for your change, test it on mobile, and open a pull request against `main`. Feature PRs should include three things.

1. **Feature name** — use it in the PR title and the feature name field.
2. **Feature description** — explain what changed and how a reviewer can try it.
3. **Mobile screenshot** — attach one screenshot showing the feature working on **Android or iOS**. Either platform is enough.

[Open the pull request template](.github/pull_request_template.md) · [Report a bug or suggest a feature](https://github.com/pallavc34/indian-sign-language-translator/issues)

## Support the project

[![Buy Me a Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/pallavc34)

## License

Project source code and documentation are available under the [MIT License](LICENSE). Third-party dependencies and assets retain their applicable licenses. The bundled viewer includes [Three.js](https://threejs.org/) and its [license notice](assets/saniya/THREE-LICENSE.txt).
