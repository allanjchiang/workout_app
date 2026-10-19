# 🏋️ Workout Tracker

A simple, easy-to-read Flutter app for logging strength training, resistance band, stretching and home workouts. Build your own workout plans, log every set, and track your progress over time.

## Features

- 📋 **Custom Workout Plans** - Build templates from built-in exercises (chest, back, shoulders, arms, legs, core) or your own custom exercises, and drag to reorder
- 📊 **Set Logging** - Log sets, reps and weight (kg/lbs), including assisted weight
- ⏲️ **Timed Exercises** - Track holds and carries (e.g. plank, farmer's walk) with an optional warm-up countdown
- 🔁 **Last Session** - See what you did last time for each exercise
- 💾 **Draft Resume** - Unfinished workouts are saved automatically so you can pick up where you left off
- ⏱️ **Rest Timer** - Starts automatically after each set, configurable per exercise, skippable, with adjustable beep volume and optional ducking of other audio. Keeps running in the background or when the phone is locked, with notifications
- 📈 **Progress Charts** - Reps, weight and estimated 1RM over time, by exercise (1 week, 1 month, 1 year, all time)
- 📉 **Statistics** - Total workouts, this week, total minutes and total reps
- 🗓️ **Tracking Calendar** - Track exercises or whole templates in week, fortnight or month views, with daily set or rep targets
- 📤 **Backup** - Export your data, import it to restore, or delete everything
- 🌏 **Languages** - English, Traditional Chinese, Simplified Chinese
- 🔒 **Private** - All data stays on your device. No account, no data collection, no internet required

## Screenshots

*Coming soon*

## Getting Started

### Prerequisites

- Flutter SDK 3.10.7 or higher
- Dart SDK

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/allanjchiang/workout_app.git
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
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## Project Structure

```
workout_app/
├── lib/
│   ├── main.dart                 # Main application code
│   ├── timer_notifications.dart  # Background timer notifications
│   ├── donations.dart            # Optional in-app tips
│   ├── dev_notes.dart            # In-app release notes
│   └── l10n/
│       └── app_localizations.dart  # English and Chinese strings
├── assets/
│   ├── audio/                    # Timer beep sounds
│   └── icon/                     # App icon
├── LICENSE                       # MIT License
├── THIRD_PARTY_LICENSES.md       # Third-party package licenses
└── pubspec.yaml                  # Dependencies
```

## Privacy

- All data is stored locally on your device
- No data is collected, transmitted, or sold
- No account or internet connection required (optional tips use the app store's in-app purchase)
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

Third-party package licenses are listed in [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Contact

- **Email:** allan@logicphile.com
- **Support:** https://logicphile.com/support

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Icons from [Material Design Icons](https://material.io/icons/)
