# 🏋️ Workout Tracker

A simple, accessible Flutter app for tracking resistance band shoulder exercises.

## Features

- 🟡 **Yellow Band Exercises** - Track 5 shoulder exercises designed for the lightest resistance band
- 📊 **Rep Counter** - Easy +/- buttons to log your reps
- ⏱️ **Rest Timer** - Automatic 1-minute rest timer with audio notification
- 💾 **Save Progress** - Your workout data is saved locally on your device
- 📤 **Export Data** - Share or copy your workout history
- ♿ **Accessible** - Full screen reader support for VoiceOver and TalkBack
- 🔒 **Private** - No data collection, no internet required, 100% offline

## Screenshots

*Coming soon*

## Getting Started

### Prerequisites

- Flutter SDK 3.10.7 or higher
- Dart SDK

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/workout_app.git
   cd workout_app/workout_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Building for Release

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## Project Structure

```
workout_app/
├── lib/
│   └── main.dart              # Main application code
├── assets/
│   └── audio/
│       └── timer_beep.wav     # Rest timer notification sound
├── LICENSE                    # MIT License
├── THIRD_PARTY_LICENSES.md    # Third-party package licenses
└── pubspec.yaml               # Dependencies
```

## Privacy

- All data is stored locally on your device
- No data is collected, transmitted, or sold
- No internet connection required
- No analytics or tracking

See [Privacy Policy](../privacy-policy.md) for full details.

## Disclaimer

- This app is for informational and tracking purposes only
- Consult a healthcare professional before starting any exercise program
- Not intended to diagnose, treat, cure, or prevent any medical condition
- Use at your own risk

See [Disclaimer](../disclaimer.md) for full details.

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

### Third-Party Licenses

This app uses the following open source packages:
- **Flutter** - BSD 3-Clause
- **shared_preferences** - BSD 3-Clause
- **audioplayers** - MIT
- **share_plus** - BSD 3-Clause

See [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) for full details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Contact

- **Email:** allanchiangviolin@gmail.com

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Icons from [Material Design Icons](https://material.io/icons/)
