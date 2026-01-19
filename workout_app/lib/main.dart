import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';

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
  final String name;
  final String description;
  final IconData icon;

  const Exercise({
    required this.name,
    required this.description,
    required this.icon,
  });
}

const List<Exercise> shoulderExercises = [
  Exercise(
    name: 'Shoulder Press',
    description: 'Stand on band, press handles overhead',
    icon: Icons.arrow_upward,
  ),
  Exercise(
    name: 'Lateral Raise',
    description: 'Stand on band, raise arms to sides',
    icon: Icons.open_with,
  ),
  Exercise(
    name: 'Front Raise',
    description: 'Stand on band, raise arms forward',
    icon: Icons.arrow_forward,
  ),
  Exercise(
    name: 'Reverse Fly',
    description: 'Bend forward, pull band apart',
    icon: Icons.compare_arrows,
  ),
  Exercise(
    name: 'Shrugs',
    description: 'Stand on band, lift shoulders up',
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

    final prefs = await SharedPreferences.getInstance();
    savedWorkouts[selectedExercise!.name] = reps;
    await prefs.setString('workouts', jsonEncode(savedWorkouts));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Saved: ${selectedExercise!.name} - $reps reps',
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
        } else {
          timer.cancel();
          isTimerRunning = false;
          _playTimerSound();
        }
      });
    });
  }

  void _stopTimer() {
    restTimer?.cancel();
    setState(() {
      isTimerRunning = false;
      timerSeconds = 60;
    });
  }

  Future<void> _playTimerSound() async {
    try {
      // Play local beep sound (no internet permission needed)
      await audioPlayer.play(AssetSource('audio/timer_beep.wav'));

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              '⏰ Rest Time Over!',
              style: TextStyle(fontSize: 28),
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'Time to do your next set!',
              style: TextStyle(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontSize: 22)),
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
            title: const Text(
              '⏰ Rest Time Over!',
              style: TextStyle(fontSize: 28),
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'Time to do your next set!',
              style: TextStyle(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontSize: 22)),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _exportData() async {
    if (savedWorkouts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No workout data to export yet!',
              style: TextStyle(fontSize: 18),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Create a readable text summary
    final buffer = StringBuffer();
    buffer.writeln('🏋️ Workout Tracker - Export');
    buffer.writeln('📅 ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('');
    buffer.writeln('Yellow Band (Lightest) - Shoulder Exercises:');
    buffer.writeln('─' * 40);

    for (final entry in savedWorkouts.entries) {
      buffer.writeln('• ${entry.key}: ${entry.value} reps');
    }

    buffer.writeln('');
    buffer.writeln('Keep up the great work! 💪');

    final exportText = buffer.toString();

    try {
      await Share.share(exportText, subject: 'My Workout Data');
    } catch (e) {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: exportText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '📋 Copied to clipboard!',
              style: TextStyle(fontSize: 18),
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '🗑️ Delete All Data?',
          style: TextStyle(fontSize: 24),
        ),
        content: const Text(
          'This will delete all your saved workout data.\n\nThis cannot be undone!',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 20)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All', style: TextStyle(fontSize: 20)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ All data deleted', style: TextStyle(fontSize: 18)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAboutAndDisclaimer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, size: 32, color: Colors.amber),
            SizedBox(width: 12),
            Text(
              'About & Disclaimer',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Workout Tracker',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'A simple app to track your resistance band exercises.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ Important Disclaimers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '• This app is for informational and tracking purposes only.',
                      style: TextStyle(fontSize: 15),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Consult a healthcare professional before starting any exercise program.',
                      style: TextStyle(fontSize: 15),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Not intended to diagnose, treat, cure, or prevent any medical condition.',
                      style: TextStyle(fontSize: 15),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Use at your own risk.',
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔒 Your Privacy',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '• All data is stored locally on your device',
                      style: TextStyle(fontSize: 15),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• We do not collect, transmit, or sell your data',
                      style: TextStyle(fontSize: 15),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• You can export or delete your data anytime',
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '📧 Contact',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const SelectableText(
                'allanchiangviolin@gmail.com',
                style: TextStyle(fontSize: 16, color: Colors.blue),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber.shade50,
      appBar: AppBar(
        backgroundColor: Colors.amber.shade300,
        title: const Text(
          '💪 Shoulder Workout',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // Info/About button
          IconButton(
            onPressed: _showAboutAndDisclaimer,
            icon: const Icon(Icons.info_outline, size: 28),
            tooltip: 'About & Disclaimer',
          ),
          // Export button
          IconButton(
            onPressed: _exportData,
            icon: const Icon(Icons.share, size: 28),
            tooltip: 'Export Data',
          ),
          // Delete button
          IconButton(
            onPressed: _deleteAllData,
            icon: const Icon(Icons.delete_forever, size: 28),
            tooltip: 'Delete All Data',
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade200,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.yellow.shade700, width: 3),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.circle, color: Colors.yellow, size: 30),
                    SizedBox(width: 12),
                    Text(
                      'Yellow Band (Lightest)',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Exercise selection
              const Text(
                'Select Exercise:',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              ...shoulderExercises.map(
                (exercise) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExerciseButton(
                    exercise: exercise,
                    isSelected: selectedExercise?.name == exercise.name,
                    lastReps: savedWorkouts[exercise.name],
                    onTap: () {
                      setState(() {
                        selectedExercise = exercise;
                        reps = savedWorkouts[exercise.name] ?? 0;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Rep counter
              if (selectedExercise != null) ...[
                Container(
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
                        selectedExercise!.name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedExercise!.description,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'How many reps?',
                        style: TextStyle(fontSize: 22),
                      ),
                      const SizedBox(height: 16),

                      // Rep counter buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _RoundButton(
                            icon: Icons.remove,
                            color: Colors.red.shade400,
                            onPressed: () {
                              if (reps > 0) {
                                setState(() => reps--);
                              }
                            },
                          ),
                          const SizedBox(width: 24),
                          Container(
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
                          const SizedBox(width: 24),
                          _RoundButton(
                            icon: Icons.add,
                            color: Colors.green.shade400,
                            onPressed: () {
                              setState(() => reps++);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 70,
                        child: ElevatedButton.icon(
                          onPressed: reps > 0 ? _saveWorkout : null,
                          icon: const Icon(Icons.save, size: 30),
                          label: const Text(
                            'Save & Start Rest Timer',
                            style: TextStyle(fontSize: 20),
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
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],

              // Rest timer display
              if (isTimerRunning)
                Container(
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
                      const Text(
                        '⏱️ Rest Timer',
                        style: TextStyle(
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
                      TextButton.icon(
                        onPressed: _stopTimer,
                        icon: const Icon(Icons.stop, size: 24),
                        label: const Text(
                          'Stop Timer',
                          style: TextStyle(fontSize: 18),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                        ),
                      ),
                    ],
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

  const _ExerciseButton({
    required this.exercise,
    required this.isSelected,
    required this.lastReps,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
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
              color: isSelected ? Colors.amber.shade600 : Colors.grey.shade300,
              width: isSelected ? 3 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (lastReps != null)
                      Text(
                        'Last: $lastReps reps',
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
                Icon(
                  Icons.check_circle,
                  color: Colors.amber.shade700,
                  size: 32,
                ),
            ],
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

  const _RoundButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
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
          child: Icon(icon, size: 40, color: Colors.white),
        ),
      ),
    );
  }
}
