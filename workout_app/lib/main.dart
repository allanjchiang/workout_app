import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const WorkoutTrackerApp());
}

class WorkoutTrackerApp extends StatelessWidget {
  const WorkoutTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout Tracker',
      debugShowCheckedModeBanner: false,
      // Localization support
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // Large text for elderly users
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 22),
          bodyMedium: TextStyle(fontSize: 20),
          labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      home: const WorkoutHomePage(),
    );
  }
}

// Shoulder exercises for yellow (lightest) resistance band
class Exercise {
  final String nameKey;
  final String descriptionKey;
  final IconData icon;

  const Exercise({
    required this.nameKey,
    required this.descriptionKey,
    required this.icon,
  });

  String getName(AppLocalizations l10n) => l10n.get(nameKey);
  String getDescription(AppLocalizations l10n) => l10n.get(descriptionKey);
}

const List<Exercise> shoulderExercises = [
  Exercise(
    nameKey: 'shoulderPress',
    descriptionKey: 'shoulderPressDesc',
    icon: Icons.arrow_upward,
  ),
  Exercise(
    nameKey: 'lateralRaise',
    descriptionKey: 'lateralRaiseDesc',
    icon: Icons.open_with,
  ),
  Exercise(
    nameKey: 'frontRaise',
    descriptionKey: 'frontRaiseDesc',
    icon: Icons.arrow_forward,
  ),
  Exercise(
    nameKey: 'reverseFly',
    descriptionKey: 'reverseFlyDesc',
    icon: Icons.compare_arrows,
  ),
  Exercise(
    nameKey: 'shrugs',
    descriptionKey: 'shrugsDesc',
    icon: Icons.keyboard_double_arrow_up,
  ),
];

class WorkoutHomePage extends StatefulWidget {
  const WorkoutHomePage({super.key});

  @override
  State<WorkoutHomePage> createState() => _WorkoutHomePageState();
}

class _WorkoutHomePageState extends State<WorkoutHomePage> {
  Exercise? selectedExercise;
  int reps = 0;
  Map<String, int> savedWorkouts = {};

  // Timer state
  int timerSeconds = 60;
  Timer? restTimer;
  bool isTimerRunning = false;

  // Audio player
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadSavedWorkouts();
  }

  @override
  void dispose() {
    restTimer?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSavedWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? workoutsJson = prefs.getString('workouts');
    if (workoutsJson != null) {
      setState(() {
        savedWorkouts = Map<String, int>.from(jsonDecode(workoutsJson));
      });
    }
  }

  Future<void> _saveWorkout() async {
    if (selectedExercise == null || reps <= 0) return;

    final l10n = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    savedWorkouts[selectedExercise!.nameKey] = reps;
    await prefs.setString('workouts', jsonEncode(savedWorkouts));

    if (mounted) {
      final exerciseName = selectedExercise!.getName(l10n);
      // Announce to screen reader
      SemanticsService.announce(
        '${l10n.get('saved')} $exerciseName $reps ${l10n.reps}. ${l10n.get('restTimerStarted')}',
        TextDirection.ltr,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.get('saved')}: $exerciseName - $reps ${l10n.reps}',
            style: const TextStyle(fontSize: 18),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Start the 1-minute rest timer
      _startRestTimer();
    }
  }

  void _startRestTimer() {
    restTimer?.cancel();
    setState(() {
      timerSeconds = 60;
      isTimerRunning = true;
    });

    restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (timerSeconds > 0) {
          timerSeconds--;
          // Announce every 15 seconds for screen readers
          if (timerSeconds == 45 || timerSeconds == 30 || timerSeconds == 15) {
            SemanticsService.announce(
              '$timerSeconds seconds remaining',
              TextDirection.ltr,
            );
          }
          // Announce last 5 seconds
          if (timerSeconds <= 5 && timerSeconds > 0) {
            SemanticsService.announce('$timerSeconds', TextDirection.ltr);
          }
        } else {
          timer.cancel();
          isTimerRunning = false;
          _playTimerSound();
        }
      });
    });
  }

  void _stopTimer() {
    final l10n = AppLocalizations.of(context)!;
    restTimer?.cancel();
    setState(() {
      isTimerRunning = false;
      timerSeconds = 60;
    });
    SemanticsService.announce(l10n.get('timerStopped'), TextDirection.ltr);
  }

  Future<void> _playTimerSound() async {
    final l10n = AppLocalizations.of(context)!;
    // Announce to screen reader
    SemanticsService.announce(
      '${l10n.restTimeOver} ${l10n.timeForNextSet}',
      TextDirection.ltr,
    );

    try {
      // Play local beep sound (no internet permission needed)
      await audioPlayer.play(AssetSource('audio/timer_beep.wav'));

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Semantics(
              header: true,
              child: Text(
                l10n.restTimeOver,
                style: const TextStyle(fontSize: 28),
                textAlign: TextAlign.center,
              ),
            ),
            content: Text(
              l10n.timeForNextSet,
              style: const TextStyle(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.ok, style: const TextStyle(fontSize: 22)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // If sound fails, just show the dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Semantics(
              header: true,
              child: Text(
                l10n.restTimeOver,
                style: const TextStyle(fontSize: 28),
                textAlign: TextAlign.center,
              ),
            ),
            content: Text(
              l10n.timeForNextSet,
              style: const TextStyle(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.ok, style: const TextStyle(fontSize: 22)),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _exportData() async {
    final l10n = AppLocalizations.of(context)!;
    if (savedWorkouts.isEmpty) {
      if (mounted) {
        SemanticsService.announce(
          l10n.get('noDataToExport'),
          TextDirection.ltr,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.get('noDataToExport'),
              style: const TextStyle(fontSize: 18),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Create a readable text summary
    final buffer = StringBuffer();
    buffer.writeln('${l10n.appTitle} - Export');
    buffer.writeln('Date: ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('');
    buffer.writeln('${l10n.yellowBand} - ${l10n.shoulderWorkout}:');
    buffer.writeln('─' * 40);

    for (final entry in savedWorkouts.entries) {
      buffer.writeln('${entry.key}: ${entry.value} ${l10n.reps}');
    }

    buffer.writeln('');
    buffer.writeln('Keep up the great work!');

    final exportText = buffer.toString();

    try {
      await Share.share(exportText, subject: l10n.appTitle);
      SemanticsService.announce(l10n.get('sharingData'), TextDirection.ltr);
    } catch (e) {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: exportText));
      if (mounted) {
        SemanticsService.announce(
          l10n.get('copiedToClipboard'),
          TextDirection.ltr,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.get('copiedToClipboard'),
              style: const TextStyle(fontSize: 18),
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllData() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(
          header: true,
          child: Text(
            l10n.get('deleteAllData'),
            style: const TextStyle(fontSize: 24),
          ),
        ),
        content: Text(
          l10n.get('deleteWarning'),
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel, style: const TextStyle(fontSize: 20)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.deleteAll, style: const TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('workouts');

      setState(() {
        savedWorkouts.clear();
        selectedExercise = null;
        reps = 0;
      });

      if (mounted) {
        SemanticsService.announce(
          l10n.get('allDataDeleted'),
          TextDirection.ltr,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.get('allDataDeleted'),
              style: const TextStyle(fontSize: 18),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAboutAndDisclaimer() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(
          header: true,
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 32,
                color: Colors.amber,
                semanticLabel: 'Information',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.aboutAndDisclaimer,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.appTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.get('workoutTrackerDesc'),
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              Semantics(
                container: true,
                label: l10n.get('importantDisclaimers'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.get('importantDisclaimers'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• ${l10n.get('disclaimer1')}',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• ${l10n.get('disclaimer2')}',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• ${l10n.get('disclaimer3')}',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• ${l10n.get('disclaimer4')}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                container: true,
                label: l10n.get('yourPrivacy'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.get('yourPrivacy'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• ${l10n.get('privacy1')}',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• ${l10n.get('privacy2')}',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• ${l10n.get('privacy3')}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // License section
              Semantics(
                container: true,
                label: l10n.get('openSource'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.get('openSource'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• ${l10n.get('licensedUnderMIT')}',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• ${l10n.get('version')} 1.0.1',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      // View licenses button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            showLicensePage(
                              context: context,
                              applicationName: l10n.appTitle,
                              applicationVersion: '1.0.1',
                              applicationLegalese:
                                  '© 2026 Allan Chiang\n${l10n.get('licensedUnderMIT')}',
                            );
                          },
                          icon: const Icon(Icons.description_outlined),
                          label: Text(l10n.get('viewLicenses')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.get('contact'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Contact email: allanchiangviolin@gmail.com',
                child: const SelectableText(
                  'allanchiangviolin@gmail.com',
                  style: TextStyle(fontSize: 16, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close, style: const TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.amber.shade50,
      appBar: AppBar(
        backgroundColor: Colors.amber.shade300,
        title: Semantics(
          header: true,
          child: Text(
            l10n.shoulderWorkout,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        actions: [
          // Info/About button
          Semantics(
            button: true,
            label: l10n.get('aboutAndDisclaimerButton'),
            child: IconButton(
              onPressed: _showAboutAndDisclaimer,
              icon: const Icon(Icons.info_outline, size: 28),
              tooltip: l10n.aboutAndDisclaimer,
            ),
          ),
          // Export button
          Semantics(
            button: true,
            label: l10n.get('exportDataButton'),
            child: IconButton(
              onPressed: _exportData,
              icon: const Icon(Icons.share, size: 28),
              tooltip: l10n.get('exportDataButton'),
            ),
          ),
          // Delete button
          Semantics(
            button: true,
            label: l10n.get('deleteDataButton'),
            child: IconButton(
              onPressed: _deleteAllData,
              icon: const Icon(Icons.delete_forever, size: 28),
              tooltip: l10n.get('deleteAllData'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Band indicator
              Semantics(
                label: l10n.get('bandDescription'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade200,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.yellow.shade700, width: 3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Decorative icon - excluded from semantics
                      ExcludeSemantics(
                        child: Icon(
                          Icons.circle,
                          color: Colors.yellow.shade600,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.yellowBand,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Exercise selection header
              Semantics(
                header: true,
                child: Text(
                  l10n.selectExercise,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Exercise list
              ...shoulderExercises.map(
                (exercise) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExerciseButton(
                    exercise: exercise,
                    isSelected: selectedExercise?.nameKey == exercise.nameKey,
                    lastReps: savedWorkouts[exercise.nameKey],
                    l10n: l10n,
                    onTap: () {
                      setState(() {
                        selectedExercise = exercise;
                        reps = savedWorkouts[exercise.nameKey] ?? 0;
                      });
                      // Announce selection to screen reader
                      final lastRepsInfo =
                          savedWorkouts[exercise.nameKey] != null
                          ? ', ${l10n.get('lastRecorded')} ${savedWorkouts[exercise.nameKey]} ${l10n.reps}'
                          : '';
                      SemanticsService.announce(
                        '${l10n.get('selected')} ${exercise.getName(l10n)}. ${exercise.getDescription(l10n)}$lastRepsInfo',
                        TextDirection.ltr,
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Rep counter
              if (selectedExercise != null) ...[
                Semantics(
                  container: true,
                  label: 'Rep counter for ${selectedExercise!.getName(l10n)}',
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          selectedExercise!.getName(l10n),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedExercise!.getDescription(l10n),
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        Text(
                          l10n.howManyReps,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(height: 16),

                        // Rep counter buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _RoundButton(
                              icon: Icons.remove,
                              color: Colors.red.shade400,
                              semanticLabel: l10n.get('decreaseReps'),
                              onPressed: () {
                                if (reps > 0) {
                                  setState(() => reps--);
                                  SemanticsService.announce(
                                    '$reps ${l10n.reps}',
                                    TextDirection.ltr,
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 24),
                            Semantics(
                              label: '$reps ${l10n.reps}',
                              liveRegion: true,
                              child: Container(
                                width: 100,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.amber.shade400,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  '$reps',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            _RoundButton(
                              icon: Icons.add,
                              color: Colors.green.shade400,
                              semanticLabel: 'Increase reps',
                              onPressed: () {
                                setState(() => reps++);
                                SemanticsService.announce(
                                  '$reps reps',
                                  TextDirection.ltr,
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Save button
                        Semantics(
                          button: true,
                          enabled: reps > 0,
                          label: reps > 0
                              ? '${l10n.saveAndStartTimer} - $reps ${l10n.reps}'
                              : l10n.get('saveButtonDisabled'),
                          child: SizedBox(
                            width: double.infinity,
                            height: 70,
                            child: ElevatedButton.icon(
                              onPressed: reps > 0 ? _saveWorkout : null,
                              icon: const Icon(Icons.save, size: 30),
                              label: Text(
                                l10n.saveAndStartTimer,
                                style: const TextStyle(fontSize: 20),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],

              // Rest timer display
              if (isTimerRunning)
                Semantics(
                  container: true,
                  liveRegion: true,
                  label:
                      '${l10n.restTimer}: ${timerSeconds ~/ 60}:${(timerSeconds % 60).toString().padLeft(2, '0')} ${l10n.get('secondsRemaining')}',
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: timerSeconds <= 10
                          ? Colors.red.shade100
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: timerSeconds <= 10
                            ? Colors.red.shade400
                            : Colors.blue.shade400,
                        width: 3,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          l10n.restTimer,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${timerSeconds ~/ 60}:${(timerSeconds % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.bold,
                            color: timerSeconds <= 10
                                ? Colors.red.shade700
                                : Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          button: true,
                          label: l10n.stopTimer,
                          child: TextButton.icon(
                            onPressed: _stopTimer,
                            icon: const Icon(Icons.stop, size: 24),
                            label: Text(
                              l10n.stopTimer,
                              style: const TextStyle(fontSize: 18),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseButton extends StatelessWidget {
  final Exercise exercise;
  final bool isSelected;
  final int? lastReps;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  const _ExerciseButton({
    required this.exercise,
    required this.isSelected,
    required this.lastReps,
    required this.onTap,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final exerciseName = exercise.getName(l10n);
    final exerciseDesc = exercise.getDescription(l10n);
    final String lastRepsText = lastReps != null
        ? ', ${l10n.get('lastRecorded')} $lastReps ${l10n.reps}'
        : '';
    final String selectedText = isSelected
        ? ', ${l10n.get('currentlySelected')}'
        : '';

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$exerciseName. $exerciseDesc$lastRepsText$selectedText',
      child: Material(
        color: isSelected ? Colors.amber.shade200 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: isSelected ? 4 : 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.amber.shade600
                    : Colors.grey.shade300,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: Row(
              children: [
                // Decorative icon - excluded from semantics
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      exercise.icon,
                      size: 32,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exerciseName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (lastReps != null)
                        Text(
                          '${l10n.get('lastReps')} $lastReps ${l10n.reps}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  ExcludeSemantics(
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.amber.shade700,
                      size: 32,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String semanticLabel;

  const _RoundButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 70,
            height: 70,
            alignment: Alignment.center,
            child: ExcludeSemantics(
              child: Icon(icon, size: 40, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
