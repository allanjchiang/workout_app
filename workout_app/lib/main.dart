import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart'
    show CustomSemanticsAction, OrdinalSortKey;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';
import 'l10n/app_localizations.dart';
import 'dev_notes.dart';
import 'donations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  try {
    await AudioPlayer.global.setAudioContext(
      timerBeepMixWithOthersAudioContext(),
    );
  } catch (_) {
    // Beep audio context is re-applied per player before each sound.
  }
  runApp(const WorkoutTrackerApp());
}

// Theme notifier for app-wide theme management
class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeNotifier() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme_mode') ?? 'system';
    _themeMode = _themeModeFromString(themeString);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _themeStringFromMode(mode));
  }

  ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeStringFromMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }
}

// Global theme notifier instance
final themeNotifier = ThemeNotifier();

// Navy blue color scheme - easy to read for elderly
const Color kPrimaryBlue = Color(0xFF1E3A5F); // Navy blue
const Color kPrimaryBlueLight = Color(0xFF3D5A80); // Lighter navy
const Color kAccentBlue = Color(0xFF5C93C4); // Accent blue

class WorkoutTrackerApp extends StatefulWidget {
  const WorkoutTrackerApp({super.key});

  @override
  State<WorkoutTrackerApp> createState() => _WorkoutTrackerAppState();
}

class _WorkoutTrackerAppState extends State<WorkoutTrackerApp> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  // Large text theme for elderly users
  TextTheme get _largeTextTheme => const TextTheme(
    headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(fontSize: 22),
    bodyMedium: TextStyle(fontSize: 20),
    labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  );

  // Light theme - Navy blue with white background
  ThemeData get _lightTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimaryBlue,
      brightness: Brightness.light,
      primary: kPrimaryBlue,
      secondary: kAccentBlue,
    ),
    useMaterial3: true,
    textTheme: _largeTextTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: kPrimaryBlue,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryBlue,
        foregroundColor: Colors.white,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kPrimaryBlue,
      foregroundColor: Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: kAccentBlue.withValues(alpha: 0.3),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
  );

  // Dark theme - Navy blue with dark background
  ThemeData get _darkTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimaryBlue,
      brightness: Brightness.dark,
      primary: kAccentBlue,
      secondary: kPrimaryBlueLight,
    ),
    useMaterial3: true,
    textTheme: _largeTextTheme,
    scaffoldBackgroundColor: const Color(0xFF121820),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A2634),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccentBlue,
        foregroundColor: Colors.white,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kAccentBlue,
      foregroundColor: Colors.white,
    ),
    cardTheme: const CardThemeData(color: Color(0xFF1A2634)),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1A2634),
      indicatorColor: kAccentBlue.withValues(alpha: 0.3),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout Tracker',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeNotifier.themeMode,
      home: const MainNavigationPage(),
    );
  }
}

// ============== DURATION HELPERS (hold / plank / balance exercises) ==============

const int kDefaultTargetDurationSeconds = 60;

String formatDurationMmSs(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final m = s ~/ 60;
  final sec = s % 60;
  return '$m:${sec.toString().padLeft(2, '0')}';
}

/// Shared preferences key for timer / beep volume (0–100, default 85).
const String kPrefTimerBeepVolume = 'timer_beep_volume';

/// Audio context for timer beeps: mix over Audible/podcasts without pausing them.
AudioContext timerBeepMixWithOthersAudioContext() {
  return AudioContext(
    android: AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );
}

/// Template editor / add-exercise dialog: 0 = use workout default ([null]),
/// 1 = no rest (0 s), 2 = custom (clamped 0–600 s).
int? restAfterSetFromTemplateDialog(int restMode, int customSeconds) {
  switch (restMode) {
    case 0:
      return null;
    case 1:
      return 0;
    default:
      return customSeconds.clamp(0, 600);
  }
}

String _restHintForTemplateExercise(
  AppLocalizations l10n,
  TemplateExercise te,
  int workoutDefaultRestSeconds,
) {
  final r = te.restAfterSetSeconds;
  if (r == null) {
    return l10n
        .get('restHintDefault')
        .replaceAll('{time}', formatDurationMmSs(workoutDefaultRestSeconds));
  }
  if (r == 0) {
    return l10n.get('restHintNone');
  }
  return l10n.get('restHintCustom').replaceAll('{time}', formatDurationMmSs(r));
}

/// Parses:
/// - "m:ss" / "mm:ss" (e.g. "1:00", "0:30", "2:05")
/// - plain digits:
///   - 1-2 digits => seconds (e.g. "30" => 30s)
///   - 3+ digits => mmss (e.g. "130" => 1:30, "1000" => 10:00)
/// Returns null if invalid.
int? parseDurationInput(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final colon = t.indexOf(':');
  if (colon >= 0) {
    final a = t.substring(0, colon).trim();
    final b = t.substring(colon + 1).trim();
    final min = int.tryParse(a);
    final sec = int.tryParse(b);
    if (min == null || sec == null) return null;
    if (min < 0 || sec < 0 || sec > 59) return null;
    return min * 60 + sec;
  }
  final digits = t.replaceAll(RegExp(r'\s+'), '');
  final only = int.tryParse(digits);
  if (only == null || only < 0) return null;
  if (digits.length <= 2) {
    return only;
  }
  final min = only ~/ 100;
  final sec = only % 100;
  if (sec > 59) return null;
  return min * 60 + sec;
}

/// Elderly-friendly m:ss entry (e.g. 0:30, 1:00). Used from active workout and template editor.
void showDurationEntryDialog({
  required BuildContext context,
  required AppLocalizations l10n,
  required int currentSeconds,
  required Color accentColor,
  required ValueChanged<int> onSave,
}) {
  final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  final controller = TextEditingController(
    text: formatDurationMmSs(currentSeconds),
  );
  final isDark = Theme.of(context).brightness == Brightness.dark;
  var isFormattingDurationInput = false;

  String formatDurationInputLive(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.length <= 2) {
      final sec = int.parse(digits).clamp(0, 99);
      return '0:${sec.toString().padLeft(2, '0')}';
    }
    final minPart = digits.substring(0, digits.length - 2);
    final secPart = digits.substring(digits.length - 2);
    return '${int.parse(minPart)}:$secPart';
  }

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.text.isNotEmpty) {
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }
      });
      return AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2A3A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.get('holdTime'),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.get('durationHint'),
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: true,
              onChanged: (value) {
                if (isFormattingDurationInput) return;
                final formatted = formatDurationInputLive(value);
                if (formatted == value) return;
                isFormattingDurationInput = true;
                controller.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
                isFormattingDurationInput = false;
              },
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : accentColor,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark
                    ? accentColor.withValues(alpha: 0.2)
                    : accentColor.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: accentColor, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: accentColor.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: accentColor, width: 3),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    l10n.cancel,
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final parsed = parseDurationInput(controller.text);
                    if (parsed != null && parsed > 0 && parsed <= 24 * 3600) {
                      onSave(parsed);
                      Navigator.pop(dialogContext);
                    } else {
                      scaffoldMessenger?.showSnackBar(
                        SnackBar(content: Text(l10n.get('invalidDuration'))),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.get('save'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

// ============== DATA MODELS ==============

/// Individual exercise definition
class Exercise {
  final String id;
  final String name;
  final String? description;
  final String iconKey;

  const Exercise({
    required this.id,
    required this.name,
    this.description,
    this.iconKey = 'fitness_center',
  });

  IconData get icon => kExerciseIconMap[iconKey] ?? Icons.fitness_center;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'iconKey': iconKey,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    iconKey:
        (json['iconKey'] as String?) ??
        _iconKeyFromLegacy(json['iconCodePoint'] as int?),
  );

  Exercise copyWith({
    String? id,
    String? name,
    String? description,
    String? iconKey,
  }) => Exercise(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    iconKey: iconKey ?? this.iconKey,
  );
}

/// Exercise within a template with target reps/weight, or hold-by-time ([durationBased]).
class TemplateExercise {
  final Exercise exercise;
  final int targetReps;
  final double targetWeight;
  final int sets;
  final bool durationBased;

  /// When [durationBased] is true, also log weight each timed set (e.g. farmer's carry).
  final bool durationTracksWeight;

  /// Work duration for hold-by-time / duration-based exercises (seconds).
  /// If null, the active workout will fall back to history or a default.
  final int? targetDurationSeconds;

  /// null = use workout default rest; 0 = skip rest between sets; else seconds (e.g. stretches).
  final int? restAfterSetSeconds;

  /// Countdown (seconds) before the first hold starts when user taps Start (interval timer). null/0 = none.
  final int? warmupSeconds;

  const TemplateExercise({
    required this.exercise,
    this.targetReps = 10,
    this.targetWeight = 0,
    this.sets = 3,
    this.durationBased = false,
    this.durationTracksWeight = false,
    this.targetDurationSeconds,
    this.restAfterSetSeconds,
    this.warmupSeconds,
  });

  /// Strength exercises, or timed exercises that also record weight.
  bool get showsWeightInWorkout => !durationBased || durationTracksWeight;

  Map<String, dynamic> toJson() => {
    'exercise': exercise.toJson(),
    'targetReps': targetReps,
    'targetWeight': targetWeight,
    'sets': sets,
    'durationBased': durationBased,
    'durationTracksWeight': durationTracksWeight,
    if (targetDurationSeconds != null)
      'targetDurationSeconds': targetDurationSeconds,
    if (restAfterSetSeconds != null) 'restAfterSetSeconds': restAfterSetSeconds,
    if (warmupSeconds != null && warmupSeconds! > 0)
      'warmupSeconds': warmupSeconds,
  };

  factory TemplateExercise.fromJson(Map<String, dynamic> json) =>
      TemplateExercise(
        exercise: Exercise.fromJson(json['exercise'] as Map<String, dynamic>),
        targetReps: json['targetReps'] as int? ?? 10,
        targetWeight: (json['targetWeight'] as num?)?.toDouble() ?? 0,
        sets: json['sets'] as int? ?? 3,
        durationBased: json['durationBased'] as bool? ?? false,
        durationTracksWeight: json['durationTracksWeight'] as bool? ?? false,
        targetDurationSeconds: json['targetDurationSeconds'] as int?,
        restAfterSetSeconds: json['restAfterSetSeconds'] as int?,
        warmupSeconds: json['warmupSeconds'] as int?,
      );

  TemplateExercise copyWith({
    Exercise? exercise,
    int? targetReps,
    double? targetWeight,
    int? sets,
    bool? durationBased,
    bool? durationTracksWeight,
    int? targetDurationSeconds,
    int? restAfterSetSeconds,
    int? warmupSeconds,
    bool clearRestAfterSetSeconds = false,
    bool clearTargetDurationSeconds = false,
    bool clearWarmupSeconds = false,
  }) => TemplateExercise(
    exercise: exercise ?? this.exercise,
    targetReps: targetReps ?? this.targetReps,
    targetWeight: targetWeight ?? this.targetWeight,
    sets: sets ?? this.sets,
    durationBased: durationBased ?? this.durationBased,
    durationTracksWeight: durationTracksWeight ?? this.durationTracksWeight,
    targetDurationSeconds: clearTargetDurationSeconds
        ? null
        : (targetDurationSeconds ?? this.targetDurationSeconds),
    restAfterSetSeconds: clearRestAfterSetSeconds
        ? null
        : (restAfterSetSeconds ?? this.restAfterSetSeconds),
    warmupSeconds: clearWarmupSeconds
        ? null
        : (warmupSeconds ?? this.warmupSeconds),
  );
}

/// Workout template containing multiple exercises
class WorkoutTemplate {
  final String id;
  final String name;
  final String? description;
  final List<TemplateExercise> exercises;
  final DateTime createdAt;

  const WorkoutTemplate({
    required this.id,
    required this.name,
    this.description,
    required this.exercises,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) =>
      WorkoutTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        exercises: (json['exercises'] as List<dynamic>)
            .map((e) => TemplateExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  WorkoutTemplate copyWith({
    String? id,
    String? name,
    String? description,
    List<TemplateExercise>? exercises,
    DateTime? createdAt,
  }) => WorkoutTemplate(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    exercises: exercises ?? this.exercises,
    createdAt: createdAt ?? this.createdAt,
  );
}

/// Logged set during a workout. For hold exercises, [durationSeconds] is set and reps/weight are usually 0.
class ExerciseLog {
  final String exerciseId;
  final String exerciseName;
  final int setNumber;
  final int reps;
  final double weight;
  final DateTime timestamp;
  final int? durationSeconds;

  const ExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.setNumber,
    required this.reps,
    required this.weight,
    required this.timestamp,
    this.durationSeconds,
  });

  bool get isDurationSet => durationSeconds != null && durationSeconds! > 0;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'setNumber': setNumber,
    'reps': reps,
    'weight': weight,
    'timestamp': timestamp.toIso8601String(),
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
  };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
    exerciseId: json['exerciseId'] as String,
    exerciseName: json['exerciseName'] as String,
    setNumber: json['setNumber'] as int,
    reps: json['reps'] as int,
    weight: (json['weight'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
    durationSeconds: json['durationSeconds'] as int?,
  );

  ExerciseLog copyWith({
    String? exerciseId,
    String? exerciseName,
    int? setNumber,
    int? reps,
    double? weight,
    DateTime? timestamp,
    int? durationSeconds,
    bool clearDurationSeconds = false,
  }) => ExerciseLog(
    exerciseId: exerciseId ?? this.exerciseId,
    exerciseName: exerciseName ?? this.exerciseName,
    setNumber: setNumber ?? this.setNumber,
    reps: reps ?? this.reps,
    weight: weight ?? this.weight,
    timestamp: timestamp ?? this.timestamp,
    durationSeconds: clearDurationSeconds
        ? null
        : (durationSeconds ?? this.durationSeconds),
  );
}

/// Completed workout session
class WorkoutSession {
  final String id;
  final String templateId;
  final String templateName;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final List<ExerciseLog> logs;

  const WorkoutSession({
    required this.id,
    required this.templateId,
    required this.templateName,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.logs,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'templateId': templateId,
    'templateName': templateName,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'durationSeconds': durationSeconds,
    'logs': logs.map((l) => l.toJson()).toList(),
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    id: json['id'] as String,
    templateId: json['templateId'] as String,
    templateName: json['templateName'] as String,
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    durationSeconds: json['durationSeconds'] as int,
    logs: (json['logs'] as List<dynamic>)
        .map((l) => ExerciseLog.fromJson(l as Map<String, dynamic>))
        .toList(),
  );
}

/// In-progress workout persisted for crash / force-quit recovery.
const String kWorkoutDraftPrefsKey = 'workout_draft_v1';

class WorkoutDraft {
  static const int schemaVersion = 1;

  final WorkoutTemplate template;
  final DateTime startTime;
  final int elapsedSeconds;
  final int currentExerciseIndex;
  final int currentSet;
  final int currentReps;
  final double currentWeight;
  final int currentDurationSeconds;
  final List<ExerciseLog> logs;
  final bool isResting;
  final int restSeconds;
  final int defaultRestSeconds;
  final bool viewingPlanDuringRest;

  /// Not-yet-logged set row values, keyed by exercise id (strength exercises only).
  final Map<String, List<double>> pendingSetWeights;
  final Map<String, List<int>> pendingSetReps;
  final Map<String, List<bool>> pendingSetEdited;

  const WorkoutDraft({
    required this.template,
    required this.startTime,
    required this.elapsedSeconds,
    required this.currentExerciseIndex,
    required this.currentSet,
    required this.currentReps,
    required this.currentWeight,
    required this.currentDurationSeconds,
    required this.logs,
    required this.isResting,
    required this.restSeconds,
    required this.defaultRestSeconds,
    required this.viewingPlanDuringRest,
    this.pendingSetWeights = const {},
    this.pendingSetReps = const {},
    this.pendingSetEdited = const {},
  });

  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'template': template.toJson(),
    'startTime': startTime.toIso8601String(),
    'elapsedSeconds': elapsedSeconds,
    'currentExerciseIndex': currentExerciseIndex,
    'currentSet': currentSet,
    'currentReps': currentReps,
    'currentWeight': currentWeight,
    'currentDurationSeconds': currentDurationSeconds,
    'logs': logs.map((l) => l.toJson()).toList(),
    'isResting': isResting,
    'restSeconds': restSeconds,
    'defaultRestSeconds': defaultRestSeconds,
    'viewingPlanDuringRest': viewingPlanDuringRest,
    'pendingSetWeights': pendingSetWeights,
    'pendingSetReps': pendingSetReps,
    'pendingSetEdited': pendingSetEdited,
  };

  factory WorkoutDraft.fromJson(Map<String, dynamic> json) {
    final ver = json['version'] as int? ?? 1;
    if (ver != schemaVersion) {
      throw FormatException('Unsupported workout draft version: $ver');
    }
    return WorkoutDraft(
      template: WorkoutTemplate.fromJson(
        json['template'] as Map<String, dynamic>,
      ),
      startTime: DateTime.parse(json['startTime'] as String),
      elapsedSeconds: json['elapsedSeconds'] as int,
      currentExerciseIndex: json['currentExerciseIndex'] as int,
      currentSet: json['currentSet'] as int,
      currentReps: json['currentReps'] as int,
      currentWeight: (json['currentWeight'] as num).toDouble(),
      currentDurationSeconds: json['currentDurationSeconds'] as int? ?? 0,
      logs: (json['logs'] as List<dynamic>)
          .map((l) => ExerciseLog.fromJson(l as Map<String, dynamic>))
          .toList(),
      isResting: json['isResting'] as bool? ?? false,
      restSeconds: json['restSeconds'] as int? ?? 0,
      defaultRestSeconds: json['defaultRestSeconds'] as int? ?? 60,
      viewingPlanDuringRest: json['viewingPlanDuringRest'] as bool? ?? false,
      pendingSetWeights:
          (json['pendingSetWeights'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              (v as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
            ),
          ) ??
          const {},
      pendingSetReps:
          (json['pendingSetReps'] as Map<String, dynamic>?)?.map(
            (k, v) =>
                MapEntry(k, (v as List<dynamic>).map((e) => e as int).toList()),
          ) ??
          const {},
      pendingSetEdited:
          (json['pendingSetEdited'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              (v as List<dynamic>).map((e) => e as bool).toList(),
            ),
          ) ??
          const {},
    );
  }
}

Future<void> clearWorkoutDraftPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kWorkoutDraftPrefsKey);
}

Future<WorkoutDraft?> loadWorkoutDraft() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kWorkoutDraftPrefsKey);
    if (raw == null || raw.isEmpty) return null;
    return WorkoutDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    await clearWorkoutDraftPrefs();
    return null;
  }
}

// Available icons for exercises (const to allow tree shaking)
const Map<String, IconData> kExerciseIconMap = {
  'fitness_center': Icons.fitness_center,
  'sports_gymnastics': Icons.sports_gymnastics,
  'accessibility_new': Icons.accessibility_new,
  'directions_run': Icons.directions_run,
  'self_improvement': Icons.self_improvement,
  'sports': Icons.sports,
  'arrow_upward': Icons.arrow_upward,
  'open_with': Icons.open_with,
  'arrow_forward': Icons.arrow_forward,
  'compare_arrows': Icons.compare_arrows,
  'keyboard_double_arrow_up': Icons.keyboard_double_arrow_up,
  'pan_tool': Icons.pan_tool,
};

const List<String> kExerciseIconKeys = [
  'fitness_center',
  'sports_gymnastics',
  'accessibility_new',
  'directions_run',
  'self_improvement',
  'sports',
  'arrow_upward',
  'open_with',
  'arrow_forward',
  'compare_arrows',
  'keyboard_double_arrow_up',
  'pan_tool',
];

// ============== CONSISTENCY CALENDAR: DATA MODELS ==============

/// How often the Consistency Calendar's day grid repeats before scrolling to
/// the next range.
enum ConsistencyViewMode { week, fortnight, month }

/// What a [TrackedExercise] entry represents on the Consistency Calendar.
enum TrackedItemKind { exercise, template }

/// One item tracked inside a [ConsistencyExerciseList]: either a single
/// exercise or a whole workout template ([kind]). Identity is by
/// [exerciseName] (trimmed, matched case-insensitively) — for
/// [TrackedItemKind.exercise] against [ExerciseLog.exerciseName]. Exercises
/// have no stable cross-history id (see [Exercise.id]), so, like everywhere
/// else, matching is by name. The field keeps the name `exerciseName` for
/// both kinds to avoid touching every call site in this file — read it as
/// "matched name". For [TrackedItemKind.template], matching instead prefers
/// [templateId] against [WorkoutSession.templateId] when present — a
/// template's id is stable across renames, unlike its name, so this is what
/// keeps a renamed template's history (including sessions logged under its
/// old name) still matching. [exerciseName] is used as a name-based fallback
/// only for entries persisted before [templateId] existed.
class TrackedExercise {
  final String id;
  final String exerciseName;

  /// Index into [kConsistencyColorPalette].
  final int colorIndex;

  /// Whether this entry tracks a single exercise or a whole workout
  /// template. Defaults to [TrackedItemKind.exercise] when absent from
  /// persisted JSON (data saved before this field existed).
  final TrackedItemKind kind;

  /// Sets (kind=exercise) or completions (kind=template) expected per day
  /// it's done. 0 = no target (any activity logged that day counts as fully
  /// done).
  final int targetSetsPerDay;

  /// kind=template only: the underlying [WorkoutTemplate.id], used for
  /// rename-proof matching. Null for kind=exercise, and for template entries
  /// persisted before this field existed (until backfilled — see
  /// [_ConsistencyCalendarPageState._backfillTemplateIds]).
  final String? templateId;

  const TrackedExercise({
    required this.id,
    required this.exerciseName,
    required this.colorIndex,
    this.kind = TrackedItemKind.exercise,
    this.targetSetsPerDay = 1,
    this.templateId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseName': exerciseName,
    'colorIndex': colorIndex,
    'kind': kind.name,
    'targetSetsPerDay': targetSetsPerDay,
    if (templateId != null) 'templateId': templateId,
  };

  factory TrackedExercise.fromJson(Map<String, dynamic> json) =>
      TrackedExercise(
        id: json['id'] as String,
        exerciseName: json['exerciseName'] as String,
        colorIndex: ((json['colorIndex'] as int?) ?? 0).clamp(
          0,
          kConsistencyColorPalette.length - 1,
        ),
        kind: TrackedItemKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => TrackedItemKind.exercise,
        ),
        targetSetsPerDay: json['targetSetsPerDay'] as int? ?? 1,
        templateId: json['templateId'] as String?,
      );

  TrackedExercise copyWith({
    String? id,
    String? exerciseName,
    int? colorIndex,
    TrackedItemKind? kind,
    int? targetSetsPerDay,
    String? templateId,
  }) => TrackedExercise(
    id: id ?? this.id,
    exerciseName: exerciseName ?? this.exerciseName,
    colorIndex: colorIndex ?? this.colorIndex,
    kind: kind ?? this.kind,
    targetSetsPerDay: targetSetsPerDay ?? this.targetSetsPerDay,
    templateId: templateId ?? this.templateId,
  );
}

/// A named, ordered set of tracked exercises shown together on one
/// Consistency Calendar, plus that calendar's own view settings.
class ConsistencyExerciseList {
  /// One distinguishable color per exercise; [kConsistencyColorPalette] has
  /// exactly this many colors.
  static const int maxExercises = 14;

  final String id;
  final String name;
  final List<TrackedExercise> exercises;
  final ConsistencyViewMode viewMode;

  /// 1 (Monday) .. 7 (Sunday), matching [DateTime.weekday].
  final int startWeekday;
  final bool showSetCounts;

  const ConsistencyExerciseList({
    required this.id,
    required this.name,
    this.exercises = const [],
    this.viewMode = ConsistencyViewMode.week,
    this.startWeekday = DateTime.friday,
    this.showSetCounts = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'viewMode': viewMode.name,
    'startWeekday': startWeekday,
    'showSetCounts': showSetCounts,
  };

  factory ConsistencyExerciseList.fromJson(Map<String, dynamic> json) =>
      ConsistencyExerciseList(
        id: json['id'] as String,
        name: json['name'] as String,
        exercises: (json['exercises'] as List<dynamic>? ?? [])
            .map((e) => TrackedExercise.fromJson(e as Map<String, dynamic>))
            .take(ConsistencyExerciseList.maxExercises)
            .toList(),
        viewMode: ConsistencyViewMode.values.firstWhere(
          (v) => v.name == json['viewMode'],
          orElse: () => ConsistencyViewMode.week,
        ),
        startWeekday: ((json['startWeekday'] as int?) ?? DateTime.friday).clamp(
          1,
          7,
        ),
        showSetCounts: json['showSetCounts'] as bool? ?? false,
      );

  ConsistencyExerciseList copyWith({
    String? id,
    String? name,
    List<TrackedExercise>? exercises,
    ConsistencyViewMode? viewMode,
    int? startWeekday,
    bool? showSetCounts,
  }) => ConsistencyExerciseList(
    id: id ?? this.id,
    name: name ?? this.name,
    exercises: exercises ?? this.exercises,
    viewMode: viewMode ?? this.viewMode,
    startWeekday: startWeekday ?? this.startWeekday,
    showSetCounts: showSetCounts ?? this.showSetCounts,
  );
}

const String kConsistencyListsPrefsKey = 'consistency_lists_v1';
const String kConsistencySelectedListPrefsKey = 'consistency_selected_list_id';

/// 14 hues evenly spaced around the color wheel at fixed saturation/lightness
/// (HSL 62%/46%), so every tracked exercise in a list gets a clearly
/// differentiated color. One shared palette (not separate light/dark
/// variants) keeps "exercise N is always this swatch" consistent regardless
/// of theme; per-segment opacity/contrast is handled at render time instead
/// (see [segmentOpacity] / [segmentOverlayTextColor]).
const List<Color> kConsistencyColorPalette = [
  Color(0xFFBE2D2D),
  Color(0xFFBE6B2D),
  Color(0xFFBEA92D),
  Color(0xFF94BE2D),
  Color(0xFF56BE2D),
  Color(0xFF2DBE41),
  Color(0xFF2DBE80),
  Color(0xFF2DBEBE),
  Color(0xFF2D80BE),
  Color(0xFF2D41BE),
  Color(0xFF562DBE),
  Color(0xFF942DBE),
  Color(0xFFBE2DA9),
  Color(0xFFBE2D6B),
];

/// Lowest-index palette color not already used by another exercise in
/// [existing]; falls back to index 0 if somehow all colors are taken.
int nextAvailableConsistencyColorIndex(List<TrackedExercise> existing) {
  final used = existing.map((e) => e.colorIndex).toSet();
  for (var i = 0; i < kConsistencyColorPalette.length; i++) {
    if (!used.contains(i)) return i;
  }
  return 0;
}

// ---- Date-range engine (pure, no BuildContext) ----

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The most recent date on/before [reference] that falls on [startWeekday]
/// (1=Mon..7=Sun, matching [DateTime.weekday]).
DateTime _startOfWeekContaining(DateTime reference, int startWeekday) {
  final ref = _dateOnly(reference);
  final diff = (ref.weekday - startWeekday + 7) % 7;
  return ref.subtract(Duration(days: diff));
}

/// An inclusive, local-midnight date range.
class ConsistencyDateRange {
  final DateTime start;
  final DateTime end;
  const ConsistencyDateRange(this.start, this.end);

  int get dayCount => end.difference(start).inDays + 1;

  List<DateTime> get days =>
      List.generate(dayCount, (i) => start.add(Duration(days: i)));
}

/// The visible range for [mode], containing [anchor].
///
/// Week/fortnight are rolling windows anchored to [startWeekday] (so
/// prev/next is a flat ±7/±14 day shift). Month is anchored to the calendar
/// month containing [anchor] (not a rolling 30 days), so headers read like a
/// normal calendar ("August 2026") — [startWeekday] only affects grid
/// alignment for month view, via [computeConsistencyMonthGridDays].
ConsistencyDateRange computeConsistencyRange({
  required DateTime anchor,
  required ConsistencyViewMode mode,
  required int startWeekday,
}) {
  switch (mode) {
    case ConsistencyViewMode.week:
      final start = _startOfWeekContaining(anchor, startWeekday);
      return ConsistencyDateRange(start, start.add(const Duration(days: 6)));
    case ConsistencyViewMode.fortnight:
      final start = _startOfWeekContaining(anchor, startWeekday);
      return ConsistencyDateRange(start, start.add(const Duration(days: 13)));
    case ConsistencyViewMode.month:
      final first = DateTime(anchor.year, anchor.month, 1);
      final lastDay = DateTime(anchor.year, anchor.month + 1, 0).day;
      return ConsistencyDateRange(
        first,
        DateTime(anchor.year, anchor.month, lastDay),
      );
  }
}

/// The new anchor to use after stepping the range forward/backward one unit.
/// Callers re-derive the visible range via [computeConsistencyRange] using
/// the same `mode`/`startWeekday` and this new anchor.
DateTime nextConsistencyAnchor(
  DateTime anchor,
  ConsistencyViewMode mode, {
  required bool forward,
}) {
  switch (mode) {
    case ConsistencyViewMode.week:
      return anchor.add(Duration(days: forward ? 7 : -7));
    case ConsistencyViewMode.fortnight:
      return anchor.add(Duration(days: forward ? 14 : -14));
    case ConsistencyViewMode.month:
      return DateTime(anchor.year, anchor.month + (forward ? 1 : -1), 1);
  }
}

/// Month view only: the full 7-wide grid including leading/trailing days
/// from adjacent months so every row starts on [startWeekday]. Padding days
/// are still real dates (rendered dimmed by the caller) — a log on one of
/// them is real data regardless of which month's grid it's shown in.
List<DateTime> computeConsistencyMonthGridDays(
  DateTime anchor,
  int startWeekday,
) {
  final range = computeConsistencyRange(
    anchor: anchor,
    mode: ConsistencyViewMode.month,
    startWeekday: startWeekday,
  );
  final gridStart = _startOfWeekContaining(range.start, startWeekday);
  final lastRowStart = _startOfWeekContaining(range.end, startWeekday);
  final gridEnd = lastRowStart.add(const Duration(days: 6));
  return ConsistencyDateRange(gridStart, gridEnd).days;
}

// ---- Aggregation + opacity/contrast ----

/// Sets (kind=exercise) or completed sessions (kind=template) logged per
/// calendar day per tracked item, across all of [history]. Exercise entries
/// are grouped by each [ExerciseLog.timestamp] (not [WorkoutSession.startTime],
/// since a session can span midnight); one [ExerciseLog] row = one set.
/// Template entries are grouped by [WorkoutSession.startTime] — a session is
/// one atomic unit, so it contributes one completion to the day it started.
/// Both kinds are summed across sessions on the same day. Exercise matching
/// is case-insensitive/trimmed against [ExerciseLog.exerciseName]. Template
/// matching prefers [TrackedExercise.templateId] against
/// [WorkoutSession.templateId] (stable across renames, so a renamed
/// template's full history — including sessions logged under its old name —
/// still matches); entries without a stored id (pre-dating that field) fall
/// back to case-insensitive/trimmed name matching against
/// [WorkoutSession.templateName].
Map<DateTime, Map<String, int>> buildConsistencySetsByDay({
  required List<WorkoutSession> history,
  required List<TrackedExercise> trackedExercises,
}) {
  final wantedExercises = <String, String>{
    for (final te in trackedExercises)
      if (te.kind == TrackedItemKind.exercise)
        te.exerciseName.trim().toLowerCase(): te.exerciseName,
  };
  final wantedTemplatesById = <String, String>{
    for (final te in trackedExercises)
      if (te.kind == TrackedItemKind.template &&
          te.templateId != null &&
          te.templateId!.isNotEmpty)
        te.templateId!: te.exerciseName,
  };
  final wantedTemplatesByName = <String, String>{
    for (final te in trackedExercises)
      if (te.kind == TrackedItemKind.template &&
          (te.templateId == null || te.templateId!.isEmpty))
        te.exerciseName.trim().toLowerCase(): te.exerciseName,
  };
  final result = <DateTime, Map<String, int>>{};
  if (wantedExercises.isEmpty &&
      wantedTemplatesById.isEmpty &&
      wantedTemplatesByName.isEmpty) {
    return result;
  }
  for (final session in history) {
    if (wantedTemplatesById.isNotEmpty || wantedTemplatesByName.isNotEmpty) {
      final trackedTemplateName =
          wantedTemplatesById[session.templateId] ??
          wantedTemplatesByName[session.templateName.trim().toLowerCase()];
      if (trackedTemplateName != null) {
        final day = _dateOnly(session.startTime);
        final dayMap = result.putIfAbsent(day, () => <String, int>{});
        dayMap[trackedTemplateName] = (dayMap[trackedTemplateName] ?? 0) + 1;
      }
    }
    if (wantedExercises.isNotEmpty) {
      for (final log in session.logs) {
        final trackedName =
            wantedExercises[log.exerciseName.trim().toLowerCase()];
        if (trackedName == null) continue;
        final day = _dateOnly(log.timestamp);
        final dayMap = result.putIfAbsent(day, () => <String, int>{});
        dayMap[trackedName] = (dayMap[trackedName] ?? 0) + 1;
      }
    }
  }
  return result;
}

/// Opacity for a day's segment: ratio of sets done to target, clamped to a
/// max of 1.0 (fully met or exceeded = 100%; 1-of-2 = 50%; 1-of-3 = 33%).
/// No artificial floor. `targetSetsPerDay <= 0` means "no target" — any set
/// logged that day is treated as fully done.
double segmentOpacity({required int setsDone, required int targetSetsPerDay}) {
  if (setsDone <= 0) return 0.0;
  if (targetSetsPerDay <= 0) return 1.0;
  return (setsDone / targetSetsPerDay).clamp(0.0, 1.0);
}

/// A legible text color for a sets-done number overlaid on a segment,
/// computed against the color as it will actually render (the base color
/// blended at `opacity` over the page background) rather than the raw base
/// color, since a low-opacity segment reads much lighter than its base hue.
Color segmentOverlayTextColor({
  required Color base,
  required double opacity,
  required Color pageBackground,
}) {
  final blended = Color.alphaBlend(
    base.withValues(alpha: opacity.clamp(0.0, 1.0)),
    pageBackground,
  );
  return blended.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

/// Common gym exercise names for elderly-friendly autocomplete when adding exercises.
const List<String> kCommonExerciseNames = [
  'Abductor',
  'Adductor',
  'Ankle Eversion',
  'Assisted Pull-Up',
  'Balancing on One Leg',
  'Bench Press',
  'Bent-Over Row',
  'Bicep Curl',
  'Bicycle Crunch',
  'Bird Dog',
  'Calf Raise',
  'Cable Fly',
  'Chest Fly',
  'Chin-Up',
  'Chest Press',
  'Clamshell',
  'Crunch',
  'Dead Bug',
  'Deadlift',
  'Dumbbell Fly',
  'Face Pull',
  'Farmer\'s Carry',
  'Front Raise',
  'Goblet Squat',
  'Hack Squat',
  'Hammer Curl',
  'High Row',
  'Hip Thrust',
  'Incline Bench Press',
  'Lat Pulldown',
  'Lateral Raise',
  'Leg Curl',
  'Leg Extension',
  'Leg Press',
  'Leg Raise',
  'Lunge',
  'Lying Leg Curl',
  'Overhead Press',
  'Overhead Tricep Extension',
  'Pec Deck',
  'Plank',
  'Preacher Curl',
  'Pull-Up',
  'Push-Up',
  'Rear Delt Fly',
  'Reverse Fly',
  'Row',
  'Romanian Deadlift',
  'Seated Calf Raise',
  'Seated Row',
  'Side Plank',
  'Single-Arm Row',
  'Skullcrusher',
  'Squat',
  'T-Bar Row',
  'Tibialis Posterior',
  'Toe Curl',
  'Toe Raise',
  'Tricep Dip',
  'Tricep Pushdown',
  'Upright Row',
  'Walking Lunge',
];

/// Returns exercise names that match the query (case-insensitive substring), for autocomplete.
List<String> _filterExerciseSuggestions(String query, {int max = 8}) {
  if (query.trim().isEmpty) return [];
  final q = query.trim().toLowerCase();
  final matches = kCommonExerciseNames
      .where((name) => name.toLowerCase().contains(q))
      .take(max)
      .toList();
  return matches;
}

/// Exercise name that logs "minus weight" (weight taken off by the machine) plus reps.
const String kAssistedPullUpName = 'Assisted Pull-Up';

bool _isAssistedPullUp(String exerciseName) =>
    exerciseName == kAssistedPullUpName;

String _iconKeyFromLegacy(int? codePoint) {
  if (codePoint == null) return 'fitness_center';
  for (final entry in kExerciseIconMap.entries) {
    if (entry.value.codePoint == codePoint) {
      return entry.key;
    }
  }
  return 'fitness_center';
}

// ============== MAIN NAVIGATION ==============

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  List<WorkoutTemplate> templates = [];
  List<WorkoutSession> history = [];
  Map<String, int> _pendingOldWorkouts = {};
  bool _postFrameInitialized = false;
  bool _draftResumeOffered = false;
  String _weightUnit = 'kg';

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _ensureDefaultTemplateAndMigrate();
      if (mounted) await _offerWorkoutDraftResumeIfNeeded();
      if (mounted) await maybeShowDevNotesDialog(context);
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load templates
    final templatesJson = prefs.getString('workout_templates');
    if (templatesJson != null) {
      final List<dynamic> decoded = jsonDecode(templatesJson);
      setState(() {
        templates = decoded
            .map((e) => WorkoutTemplate.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    }

    // Load history
    final historyJson = prefs.getString('workout_history');
    if (historyJson != null) {
      final List<dynamic> decoded = jsonDecode(historyJson);
      setState(() {
        history = decoded
            .map((e) => WorkoutSession.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    }

    // MIGRATION: Check for old workout data from previous app version
    final oldWorkoutsJson = prefs.getString('workouts');
    if (oldWorkoutsJson != null) {
      _pendingOldWorkouts = Map<String, int>.from(jsonDecode(oldWorkoutsJson));
    }

    // Weight unit (kg or lbs), default kg
    final unit = prefs.getString('weight_unit');
    if (unit != null && (unit == 'kg' || unit == 'lbs')) {
      setState(() => _weightUnit = unit);
    }
  }

  Future<void> _ensureDefaultTemplateAndMigrate() async {
    if (_postFrameInitialized) return;
    _postFrameInitialized = true;

    final l10n = AppLocalizations.of(context)!;
    const upperId = 'default_beginner_upper_body';
    const legsId = 'default_beginner_legs_day';

    var changed = false;
    setState(() {
      final hadOldShoulder = templates.any(
        (t) => t.id == 'default_shoulder_workout',
      );
      if (hadOldShoulder) {
        templates.removeWhere((t) => t.id == 'default_shoulder_workout');
        changed = true;
      }
    });

    final needUpper = !templates.any((t) => t.id == upperId);
    final needLegs = !templates.any((t) => t.id == legsId);
    if (needUpper || needLegs) {
      setState(() {
        final toInsert = <WorkoutTemplate>[];
        if (needUpper) toInsert.add(_createBeginnerUpperBodyTemplate(l10n));
        if (needLegs) toInsert.add(_createBeginnerLegsDayTemplate(l10n));
        templates.insertAll(0, toInsert);
      });
      changed = true;
    }
    if (changed) {
      await _saveTemplates();
    }

    // If there's old workout data, create a history entry to preserve the rep counts
    if (_pendingOldWorkouts.isNotEmpty) {
      final migrationLogs = <ExerciseLog>[];
      final exerciseNames = {
        'shoulderPress': l10n.get('shoulderPress'),
        'lateralRaise': l10n.get('lateralRaise'),
        'frontRaise': l10n.get('frontRaise'),
        'reverseFly': l10n.get('reverseFly'),
        'shrugs': l10n.get('shrugs'),
      };

      for (final entry in _pendingOldWorkouts.entries) {
        final exerciseName = exerciseNames[entry.key] ?? entry.key;
        migrationLogs.add(
          ExerciseLog(
            exerciseId: entry.key,
            exerciseName: exerciseName,
            setNumber: 1,
            reps: entry.value,
            weight: 0,
            timestamp: DateTime.now(),
          ),
        );
      }

      if (migrationLogs.isNotEmpty) {
        final defaultTemplate = templates.isNotEmpty
            ? templates.firstWhere(
                (t) => t.id == upperId,
                orElse: () => templates.first,
              )
            : _createBeginnerUpperBodyTemplate(l10n);
        final migrationSession = WorkoutSession(
          id: 'migrated_${DateTime.now().millisecondsSinceEpoch}',
          templateId: defaultTemplate.id,
          templateName:
              '${l10n.get('shoulderWorkoutTemplate')} (${l10n.get('previousData')})',
          startTime: DateTime.now().subtract(const Duration(minutes: 30)),
          endTime: DateTime.now(),
          durationSeconds: 1800,
          logs: migrationLogs,
        );
        setState(() {
          history.insert(0, migrationSession);
        });
        await _saveHistory();
      }

      // Clear old data format after migration
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('workouts');
      _pendingOldWorkouts = {};
    }
  }

  WorkoutTemplate _createBeginnerUpperBodyTemplate(AppLocalizations l10n) {
    return WorkoutTemplate(
      id: 'default_beginner_upper_body',
      name: l10n.get('beginnerUpperBodyDay'),
      description: l10n.get('beginnerUpperBodyDayDesc'),
      exercises: [
        TemplateExercise(
          exercise: const Exercise(
            id: 'chest_press',
            name: 'Chest Press',
            iconKey: 'fitness_center',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: const Exercise(
            id: 'shoulder_press',
            name: 'Shoulder Press',
            iconKey: 'arrow_upward',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: const Exercise(
            id: 'row',
            name: 'Row',
            iconKey: 'compare_arrows',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: const Exercise(
            id: 'lat_pulldown',
            name: 'Lat Pulldown',
            iconKey: 'keyboard_double_arrow_up',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: const Exercise(
            id: 'bicep_curl',
            name: 'Bicep Curl',
            iconKey: 'open_with',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: const Exercise(
            id: 'tricep_pushdown',
            name: 'Tricep Pushdown',
            iconKey: 'arrow_forward',
          ),
          targetReps: 10,
          sets: 3,
        ),
      ],
      createdAt: DateTime.now(),
    );
  }

  WorkoutTemplate _createBeginnerLegsDayTemplate(AppLocalizations l10n) {
    return WorkoutTemplate(
      id: 'default_beginner_legs_day',
      name: l10n.get('beginnerLegsDay'),
      description: l10n.get('beginnerLegsDayDesc'),
      exercises: [
        TemplateExercise(
          exercise: const Exercise(
            id: 'leg_curl',
            name: 'Leg Curl',
            iconKey: 'self_improvement',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: const Exercise(
            id: 'leg_press',
            name: 'Leg Press',
            iconKey: 'sports',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: const Exercise(
            id: 'calf_raise',
            name: 'Calf Raise',
            iconKey: 'directions_run',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: const Exercise(
            id: 'leg_extension',
            name: 'Leg Extension',
            iconKey: 'accessibility_new',
          ),
          targetReps: 10,
          sets: 3,
        ),
      ],
      createdAt: DateTime.now(),
    );
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workout_templates',
      jsonEncode(templates.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workout_history',
      jsonEncode(history.map((h) => h.toJson()).toList()),
    );
  }

  void _addTemplate(WorkoutTemplate template) {
    setState(() {
      templates.add(template);
    });
    _saveTemplates();
  }

  void _updateTemplate(WorkoutTemplate template) {
    setState(() {
      final index = templates.indexWhere((t) => t.id == template.id);
      if (index != -1) {
        templates[index] = template;
      }
    });
    _saveTemplates();
  }

  void _deleteTemplate(String id) {
    setState(() {
      templates.removeWhere((t) => t.id == id);
    });
    _saveTemplates();
  }

  void _reorderTemplates(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final moved = templates.removeAt(oldIndex);
      templates.insert(newIndex, moved);
    });
    _saveTemplates();
  }

  void _addSession(WorkoutSession session) {
    setState(() {
      history.insert(0, session);
    });
    _saveHistory();
  }

  void _deleteSession(WorkoutSession session) {
    setState(() {
      history.removeWhere((h) => h.id == session.id);
    });
    _saveHistory();
  }

  void _pushActiveWorkout({
    required WorkoutTemplate template,
    WorkoutDraft? restoredDraft,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutPage(
          template: template,
          restoredDraft: restoredDraft,
          onComplete: _addSession,
          history: history,
          weightUnit: _weightUnit,
          onWeightUnitChanged: () async {
            final prefs = await SharedPreferences.getInstance();
            final unit = prefs.getString('weight_unit') ?? 'kg';
            if (mounted) setState(() => _weightUnit = unit);
          },
          onUpdateTemplate: _updateTemplate,
        ),
      ),
    );
  }

  Future<void> _onStartWorkout(WorkoutTemplate template) async {
    final existing = await loadWorkoutDraft();
    if (!mounted) return;
    if (existing != null) {
      final l10n = AppLocalizations.of(context)!;
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(
            l10n.get('draftConflictTitle'),
            style: const TextStyle(fontSize: 22),
          ),
          content: Text(
            l10n.get('draftConflictBody'),
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'resume'),
              child: Text(
                l10n.get('draftResume'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.primary,
                foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
              ),
              child: Text(
                l10n.get('draftDiscardAndStart'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      );
      if (!mounted || choice == null || choice == 'cancel') return;
      if (choice == 'resume') {
        _pushActiveWorkout(
          template: existing.template,
          restoredDraft: existing,
        );
        return;
      }
      await clearWorkoutDraftPrefs();
    }
    if (mounted) {
      _pushActiveWorkout(template: template);
    }
  }

  Future<void> _offerWorkoutDraftResumeIfNeeded() async {
    if (_draftResumeOffered || !mounted) return;
    final draft = await loadWorkoutDraft();
    if (draft == null || !mounted) return;
    _draftResumeOffered = true;
    final l10n = AppLocalizations.of(context)!;
    final timeStr = DateFormat('MMM d, y • h:mm a').format(draft.startTime);
    final body = l10n
        .get('draftResumeBody')
        .replaceAll(
          '{name}',
          l10n.localizeWorkoutTemplateName(draft.template.name),
        )
        .replaceAll('{time}', timeStr);
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.get('draftResumeTitle'),
          style: const TextStyle(fontSize: 22),
        ),
        content: Text(body, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(
              l10n.get('draftDiscard'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'resume'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.primary,
              foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
            ),
            child: Text(
              l10n.get('draftResume'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'resume') {
      _pushActiveWorkout(template: draft.template, restoredDraft: draft);
    } else if (action == 'discard') {
      await clearWorkoutDraftPrefs();
    } else {
      _draftResumeOffered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final pages = [
      TemplatesPage(
        templates: templates,
        onAddTemplate: _addTemplate,
        onUpdateTemplate: _updateTemplate,
        onDeleteTemplate: _deleteTemplate,
        onStartWorkout: _onStartWorkout,
        onReorderTemplates: _reorderTemplates,
      ),
      HistoryPage(
        history: history,
        weightUnit: _weightUnit,
        onDeleteSession: _deleteSession,
      ),
      StatisticsPage(
        history: history,
        weightUnit: _weightUnit,
        templates: templates,
        onUpdateTemplate: _updateTemplate,
      ),
      SettingsPage(
        weightUnit: _weightUnit,
        onWeightUnitChanged: () async {
          final prefs = await SharedPreferences.getInstance();
          final unit = prefs.getString('weight_unit') ?? 'kg';
          if (mounted) setState(() => _weightUnit = unit);
        },
      ),
    ];

    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 80,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.fitness_center, size: 28),
            selectedIcon: Icon(
              Icons.fitness_center,
              size: 28,
              color: primaryColor,
            ),
            label: l10n.get('workouts'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history, size: 28),
            selectedIcon: Icon(Icons.history, size: 28, color: primaryColor),
            label: l10n.get('history'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart, size: 28),
            selectedIcon: Icon(Icons.bar_chart, size: 28, color: primaryColor),
            label: l10n.get('statistics'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings, size: 28),
            selectedIcon: Icon(Icons.settings, size: 28, color: primaryColor),
            label: l10n.get('settings'),
          ),
        ],
      ),
    );
  }
}

// ============== TEMPLATES PAGE ==============

class TemplatesPage extends StatelessWidget {
  final List<WorkoutTemplate> templates;
  final Function(WorkoutTemplate) onAddTemplate;
  final Function(WorkoutTemplate) onUpdateTemplate;
  final Function(String) onDeleteTemplate;
  final Function(WorkoutTemplate) onStartWorkout;
  final void Function(int oldIndex, int newIndex) onReorderTemplates;

  const TemplatesPage({
    super.key,
    required this.templates,
    required this.onAddTemplate,
    required this.onUpdateTemplate,
    required this.onDeleteTemplate,
    required this.onStartWorkout,
    required this.onReorderTemplates,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : colorScheme.surface,
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(
            l10n.get('myWorkouts'),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _showAboutDialog(context, l10n),
            icon: const Icon(Icons.info_outline, size: 28),
            tooltip: l10n.aboutAndDisclaimer,
          ),
        ],
      ),
      body: SafeArea(
        child: templates.isEmpty
            ? _buildEmptyState(context, l10n)
            : _buildTemplateList(context, l10n),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTemplateDialog(context, l10n),
        icon: const Icon(Icons.add, size: 28),
        label: Text(
          l10n.get('newWorkout'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.get('noWorkoutsYet'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.get('tapToCreateFirst'),
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateList(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(
                  Icons.drag_indicator,
                  size: 20,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.get('longPressToReorder'),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            onReorder: onReorderTemplates,
            itemBuilder: (context, index) {
              final template = templates[index];
              return Padding(
                key: ValueKey(template.id),
                padding: const EdgeInsets.only(bottom: 16),
                child: _TemplateCard(
                  template: template,
                  onTap: () => onStartWorkout(template),
                  onEdit: () =>
                      _showEditTemplateDialog(context, l10n, template),
                  onDelete: () => _confirmDelete(context, l10n, template),
                  trailingAction: ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      Icons.drag_indicator,
                      size: 28,
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCreateTemplateDialog(BuildContext context, AppLocalizations l10n) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditorPage(onSave: onAddTemplate),
      ),
    );
  }

  void _showEditTemplateDialog(
    BuildContext context,
    AppLocalizations l10n,
    WorkoutTemplate template,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TemplateEditorPage(template: template, onSave: onUpdateTemplate),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
    WorkoutTemplate template,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.get('deleteWorkout'),
          style: const TextStyle(fontSize: 22),
        ),
        content: Text(
          '${l10n.get('deleteWorkoutConfirm')} "${l10n.localizeWorkoutTemplateName(template.name)}"?',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDeleteTemplate(template.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              l10n.get('delete'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A2634) : null,
        title: Row(
          children: [
            Icon(Icons.info_outline, size: 32, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.aboutAndDisclaimer,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : null,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.appTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.get('workoutTrackerDesc'),
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.orange.shade900.withValues(alpha: 0.3)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.orange.shade700
                        : Colors.orange.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.get('importantDisclaimers'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• ${l10n.get('disclaimer1')}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ${l10n.get('disclaimer2')}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ${l10n.get('disclaimer3')}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ${l10n.get('disclaimer4')}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.green.shade900.withValues(alpha: 0.3)
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.green.shade700
                        : Colors.green.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.get('yourPrivacy'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.green.shade300 : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• ${l10n.get('privacy1')}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ${l10n.get('privacy2')}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ${l10n.get('privacy3')}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                  ],
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
}

class _TemplateCard extends StatelessWidget {
  final WorkoutTemplate template;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget? trailingAction;

  const _TemplateCard({
    required this.template,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // No explicit label: the name and exercise-count Texts below already
    // provide it, and adding one made TalkBack read it twice.
    return Semantics(
      button: true,
      child: Material(
        color: isDark ? const Color(0xFF1A2634) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: isDark ? 0 : 3,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(
                          alpha: isDark ? 0.3 : 0.15,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.fitness_center,
                        size: 32,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.localizeWorkoutTemplateName(template.name),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${template.exercises.length} ${l10n.get('exercises')}',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      icon: Icon(
                        Icons.edit,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                      tooltip: l10n.get('edit'),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete,
                        color: Colors.red.shade600,
                        size: 28,
                      ),
                      tooltip: l10n.get('delete'),
                    ),
                    // ignore: use_null_aware_elements
                    if (trailingAction case final action?) action,
                  ],
                ),
                if (template.description != null &&
                    template.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    template.description!,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Start workout button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.play_arrow, size: 28),
                    label: Text(
                      l10n.get('startWorkout'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
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

// ============== TEMPLATE EDITOR PAGE ==============

class TemplateEditorPage extends StatefulWidget {
  final WorkoutTemplate? template;
  final Function(WorkoutTemplate) onSave;

  const TemplateEditorPage({super.key, this.template, required this.onSave});

  @override
  State<TemplateEditorPage> createState() => _TemplateEditorPageState();
}

class _TemplateEditorPageState extends State<TemplateEditorPage> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  List<TemplateExercise> exercises = [];

  /// Mirrors Settings → default rest; used to label "use workout default" in add/edit exercise.
  int _workoutDefaultRestSeconds = 60;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _descController = TextEditingController(
      text: widget.template?.description ?? '',
    );
    if (widget.template != null) {
      exercises = List.from(widget.template!.exercises);
    }
    unawaited(_loadWorkoutDefaultRest());
  }

  Future<void> _loadWorkoutDefaultRest() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt('default_rest_seconds') ?? 60;
    if (!mounted) return;
    setState(() => _workoutDefaultRestSeconds = v.clamp(30, 600));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _addExercise() => _openExerciseDialog();

  void _editExercise(int index) => _openExerciseDialog(replaceIndex: index);

  void _openExerciseDialog({int? replaceIndex}) {
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessengerContext = context;
    final initial = replaceIndex != null ? exercises[replaceIndex] : null;

    final nameController = TextEditingController(
      text: initial?.exercise.name ?? '',
    );
    final descController = TextEditingController(
      text: initial?.exercise.description ?? '',
    );
    var selectedIconIndex = 0;
    if (initial != null) {
      final ix = kExerciseIconKeys.indexOf(initial.exercise.iconKey);
      if (ix >= 0) selectedIconIndex = ix;
    }

    var targetReps = initial?.targetReps ?? 10;
    var sets = initial?.sets ?? 3;
    var targetWeight = initial?.targetWeight ?? 0;
    var durationBased = initial?.durationBased ?? false;
    var durationTracksWeight = initial?.durationTracksWeight ?? false;
    var targetDurationSeconds =
        (initial?.targetDurationSeconds ?? kDefaultTargetDurationSeconds).clamp(
          1,
          86400,
        );

    var restMode = 0;
    var customRestSec = 60;
    final rInit = initial?.restAfterSetSeconds;
    if (rInit == null) {
      restMode = 0;
      customRestSec = 60;
    } else if (rInit == 0) {
      restMode = 1;
      customRestSec = 60;
    } else {
      restMode = 2;
      customRestSec = rInit.clamp(0, 600);
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final primary = Theme.of(context).colorScheme.primary;

          Widget restTile({
            required bool selected,
            required String title,
            required String? subtitle,
            required VoidCallback onTap,
          }) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected
                    ? primary.withValues(alpha: isDark ? 0.28 : 0.14)
                    : (isDark ? const Color(0xFF232F3E) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          selected ? Icons.check_circle : Icons.circle_outlined,
                          size: 26,
                          color: selected ? primary : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (subtitle != null && subtitle.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            title: Text(
              replaceIndex == null
                  ? l10n.get('addExercise')
                  : l10n.get('editExercise'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                      labelText: l10n.get('exerciseName'),
                      hintText: l10n.get('exerciseNameHint'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  // Elderly-friendly autocomplete: large tap targets, clear text
                  Builder(
                    builder: (context) {
                      final suggestions = _filterExerciseSuggestions(
                        nameController.text,
                        max: 8,
                      );
                      if (suggestions.isEmpty) return const SizedBox.shrink();
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            l10n.get('suggestions'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...suggestions.map(
                            (name) => Material(
                              color: isDark
                                  ? const Color(0xFF232F3E)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () {
                                  nameController.text = name;
                                  setDialogState(() {});
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    l10n.localizeExerciseName(name),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: l10n.get('exerciseDescription'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.get('durationBasedExercise'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      l10n.get('durationBasedExerciseDesc'),
                      style: const TextStyle(fontSize: 14),
                    ),
                    value: durationBased,
                    onChanged: (v) => setDialogState(() {
                      durationBased = v;
                      if (!v) durationTracksWeight = false;
                    }),
                  ),
                  if (durationBased)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.get('durationTracksWeight'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        l10n.get('durationTracksWeightDesc'),
                        style: const TextStyle(fontSize: 14),
                      ),
                      value: durationTracksWeight,
                      onChanged: (v) =>
                          setDialogState(() => durationTracksWeight = v),
                    ),
                  const SizedBox(height: 8),
                  // Sets only for hold-by-time; Sets | target reps for rep-based
                  if (durationBased)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.get('sets'),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l10n.get('decreaseSets'),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  if (sets > 1) {
                                    setDialogState(() => sets--);
                                  }
                                },
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  '$sets',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.get('increaseSets'),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setDialogState(() => sets++),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.get('holdTime'),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: l10n.get('decreaseHoldTime'),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setDialogState(
                                () => targetDurationSeconds =
                                    (targetDurationSeconds - 5).clamp(1, 86400),
                              ),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Semantics(button: true, child: GestureDetector(
                              onTap: () => showDurationEntryDialog(
                                context: context,
                                l10n: l10n,
                                currentSeconds: targetDurationSeconds,
                                accentColor: primary,
                                onSave: (sec) => setDialogState(
                                  () => targetDurationSeconds = sec.clamp(
                                    1,
                                    86400,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(
                                      alpha: isDark ? 0.22 : 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: primary.withValues(alpha: 0.45),
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    formatDurationMmSs(targetDurationSeconds),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            )),
                            IconButton(
                              tooltip: l10n.get('increaseHoldTime'),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setDialogState(
                                () => targetDurationSeconds =
                                    (targetDurationSeconds + 5).clamp(1, 86400),
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final sec in [30, 45, 60, 90, 120])
                              OutlinedButton(
                                onPressed: () => setDialogState(
                                  () => targetDurationSeconds = sec,
                                ),
                                child: Text(formatDurationMmSs(sec)),
                              ),
                          ],
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.get('sets'),
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: l10n.get('decreaseSets'),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        if (sets > 1) {
                                          setDialogState(() => sets--);
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Text(
                                        '$sets',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: l10n.get('increaseSets'),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () =>
                                          setDialogState(() => sets++),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.get('targetReps'),
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: l10n.get('decreaseReps'),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        if (targetReps > 1) {
                                          setDialogState(() => targetReps--);
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Text(
                                        '$targetReps',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: l10n.get('increaseReps'),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () =>
                                          setDialogState(() => targetReps++),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.get('restBetweenSetsTitle'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.get('restBetweenSetsStretchHint'),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  restTile(
                    selected: restMode == 0,
                    title: l10n.get('restOptionDefault'),
                    subtitle: l10n
                        .get('restOptionDefaultSub')
                        .replaceAll(
                          '{time}',
                          formatDurationMmSs(_workoutDefaultRestSeconds),
                        ),
                    onTap: () => setDialogState(() => restMode = 0),
                  ),
                  restTile(
                    selected: restMode == 1,
                    title: l10n.get('restOptionNoRest'),
                    subtitle: l10n.get('restOptionNoRestSub'),
                    onTap: () => setDialogState(() => restMode = 1),
                  ),
                  restTile(
                    selected: restMode == 2,
                    title: l10n.get('restOptionCustom'),
                    subtitle: l10n.get('restOptionCustomSub'),
                    onTap: () => setDialogState(() => restMode = 2),
                  ),
                  if (restMode == 2) ...[
                    const SizedBox(height: 8),
                    FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l10n.get('decreaseRest'),
                            visualDensity: VisualDensity.compact,
                            onPressed: customRestSec <= 30
                                ? null
                                : () => setDialogState(
                                    () => customRestSec = (customRestSec - 30)
                                        .clamp(30, 600),
                                  ),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              formatDurationMmSs(customRestSec),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.get('increaseRest'),
                            visualDensity: VisualDensity.compact,
                            onPressed: customRestSec >= 600
                                ? null
                                : () => setDialogState(
                                    () => customRestSec = (customRestSec + 30)
                                        .clamp(30, 600),
                                  ),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Icon picker
                  Text(
                    l10n.get('chooseIcon'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(kExerciseIconKeys.length, (index) {
                      final isSelected = index == selectedIconIndex;
                      final iconKey = kExerciseIconKeys[index];
                      final iconData =
                          kExerciseIconMap[iconKey] ?? Icons.fitness_center;
                      final dialogColorScheme = Theme.of(context).colorScheme;
                      final dialogIsDark =
                          Theme.of(context).brightness == Brightness.dark;
                      return InkWell(
                        onTap: () =>
                            setDialogState(() => selectedIconIndex = index),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? dialogColorScheme.primary.withValues(
                                    alpha: dialogIsDark ? 0.3 : 0.2,
                                  )
                                : (dialogIsDark
                                      ? const Color(0xFF232F3E)
                                      : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? dialogColorScheme.primary
                                  : (dialogIsDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade300),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            iconData,
                            size: 24,
                            color: dialogColorScheme.primary,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(scaffoldMessengerContext).showSnackBar(
                      SnackBar(
                        content: Text(l10n.get('enterExerciseName')),
                        backgroundColor: const Color.fromRGBO(255, 152, 0, 1),
                      ),
                    );
                    return;
                  }
                  final exercise = Exercise(
                    id:
                        initial?.exercise.id ??
                        'ex_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameController.text.trim(),
                    description: descController.text.trim().isEmpty
                        ? null
                        : descController.text.trim(),
                    iconKey: kExerciseIconKeys[selectedIconIndex],
                  );
                  final te = TemplateExercise(
                    exercise: exercise,
                    targetReps: durationBased ? 0 : targetReps,
                    targetWeight: targetWeight,
                    sets: sets,
                    durationBased: durationBased,
                    durationTracksWeight: durationBased && durationTracksWeight,
                    targetDurationSeconds: durationBased
                        ? targetDurationSeconds
                        : null,
                    restAfterSetSeconds: restAfterSetFromTemplateDialog(
                      restMode,
                      customRestSec,
                    ),
                  );
                  setState(() {
                    if (replaceIndex != null) {
                      exercises[replaceIndex] = te;
                    } else {
                      exercises.add(te);
                    }
                  });
                  Navigator.pop(dialogContext);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  replaceIndex == null ? l10n.get('add') : l10n.get('save'),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _saveTemplate() {
    final l10n = AppLocalizations.of(context)!;

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.get('enterWorkoutName')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.get('addAtLeastOneExercise')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final template = WorkoutTemplate(
      id:
          widget.template?.id ??
          'template_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      exercises: exercises,
      createdAt: widget.template?.createdAt ?? DateTime.now(),
    );

    widget.onSave(template);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.template != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? l10n.get('editWorkout') : l10n.get('newWorkout'),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _saveTemplate,
            child: Text(
              l10n.get('save'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Template name
              TextField(
                controller: _nameController,
                style: TextStyle(
                  fontSize: 22,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: l10n.get('workoutName'),
                  hintText: l10n.get('workoutNameHint'),
                  labelStyle: TextStyle(
                    fontSize: 18,
                    color: isDark ? Colors.grey.shade400 : null,
                  ),
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade500 : null,
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(20),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1A2634) : Colors.white,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              // Description
              TextField(
                controller: _descController,
                style: TextStyle(
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: l10n.get('descriptionOptional'),
                  labelStyle: TextStyle(
                    fontSize: 18,
                    color: isDark ? Colors.grey.shade400 : null,
                  ),
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade500 : null,
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(20),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1A2634) : Colors.white,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              // Exercises header
              Text(
                l10n.get('exercises'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: Text(
                  l10n.get('longPressToReorder'),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Exercise list – reorderable, elderly-friendly (large drag handle)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: exercises.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = exercises.removeAt(oldIndex);
                    exercises.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final templateExercise = exercises[index];
                  return Padding(
                    key: ValueKey(templateExercise.exercise.id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ExerciseListItem(
                      templateExercise: templateExercise,
                      workoutDefaultRestSeconds: _workoutDefaultRestSeconds,
                      onEdit: () => _editExercise(index),
                      onDelete: () {
                        setState(() => exercises.removeAt(index));
                      },
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.drag_handle,
                            size: 28,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Add exercise button
              SizedBox(
                height: 60,
                child: OutlinedButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add, size: 28),
                  label: Text(
                    l10n.get('addExercise'),
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    side: BorderSide(color: Colors.green.shade400, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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

class _ExerciseListItem extends StatelessWidget {
  final TemplateExercise templateExercise;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final Widget? leading;

  /// Workout default from Settings (for rest hint when [TemplateExercise.restAfterSetSeconds] is null).
  final int workoutDefaultRestSeconds;

  const _ExerciseListItem({
    required this.templateExercise,
    required this.onDelete,
    required this.workoutDefaultRestSeconds,
    this.onEdit,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final exercise = templateExercise.exercise;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2634) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.3 : 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(exercise.icon, size: 28, color: colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.localizeExerciseName(exercise.name),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  templateExercise.durationBased
                      ? '${templateExercise.sets} ${l10n.get('sets')}'
                      : '${templateExercise.sets} ${l10n.get('sets')} × ${templateExercise.targetReps} ${l10n.reps}',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _restHintForTemplateExercise(
                    l10n,
                    templateExercise,
                    workoutDefaultRestSeconds,
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: Icon(
                Icons.edit_outlined,
                color: colorScheme.primary,
                size: 28,
              ),
              tooltip: l10n.get('editExercise'),
            ),
          IconButton(
            tooltip: l10n.get('deleteExercise'),
            onPressed: onDelete,
            icon: Icon(Icons.delete, color: Colors.red.shade600, size: 28),
          ),
        ],
      ),
    );
  }
}

// ============== ACTIVE WORKOUT PAGE ==============

class ActiveWorkoutPage extends StatefulWidget {
  final WorkoutTemplate template;
  final WorkoutDraft? restoredDraft;
  final Function(WorkoutSession) onComplete;
  final List<WorkoutSession> history;
  final String weightUnit;

  /// Called when user changes kg/lbs during a workout (also persisted locally).
  final VoidCallback? onWeightUnitChanged;

  /// Called when user adds an exercise and chooses "Add to workout template".
  final void Function(WorkoutTemplate updatedTemplate)? onUpdateTemplate;

  const ActiveWorkoutPage({
    super.key,
    required this.template,
    this.restoredDraft,
    required this.onComplete,
    required this.history,
    this.weightUnit = 'kg',
    this.onWeightUnitChanged,
    this.onUpdateTemplate,
  });

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage>
    with WidgetsBindingObserver {
  late DateTime startTime;
  Timer? workoutTimer;
  int elapsedSeconds = 0;
  int currentExerciseIndex = 0;
  int currentSet = 1;
  int currentReps = 0;
  double currentWeight = 0;
  int currentDurationSeconds = 0;
  List<ExerciseLog> logs = [];
  final AudioPlayer audioPlayer = AudioPlayer();
  Timer? _draftAutosaveTimer;
  bool _suppressDraftSave = false;

  // Rest timer
  Timer? restTimer;
  int restSeconds = 0;
  bool isResting = false;
  int _defaultRestSeconds = 60;

  /// When true, show workout plan during rest (timer keeps running); tap "Back to rest" to return.
  bool _viewingPlanDuringRest = false;

  /// Strength workouts: rest countdown paused while [isResting] (duration rest uses [_durationSessionRunning]).
  bool _restCountdownPaused = false;

  // Duration-based interval session (work ↔ rest ↔ auto-log)
  Timer? _durationWorkTimer;
  Timer? _warmupTimer;
  bool _durationSessionRunning = false;
  bool _durationSessionInWork = true;

  /// Countdown seconds before hold starts (interval "Start workout" only).
  int _warmupSecondsRemaining = 0;
  int _workSecondsRemaining = 0;

  /// Total seconds for the current work phase (countdown start value).
  int _workPhaseDurationSeconds = 0;

  /// Seconds held when work ended; used when logging after rest.
  int? _pendingDurationLogSeconds;

  /// Weight (kg) when work ended; used when logging after rest.
  double? _pendingDurationLogWeight;
  List<int> _restPresetSeconds = [5, 10, 15, 30, 60];

  // Previous best reps (or hold seconds) for each exercise name
  Map<String, int> previousBestReps = {};
  Map<String, int> previousBestDurationSeconds = {};

  /// Not-yet-logged set row values for strength exercises, keyed by exercise id.
  /// List length is the number of rows currently shown for that exercise (starts
  /// at [TemplateExercise.sets], can grow via "Add Set" or a raised target).
  final Map<String, List<double>> _pendingSetWeights = {};
  final Map<String, List<int>> _pendingSetReps = {};

  /// Styling only: whether the user has edited a row away from its placeholder.
  final Map<String, List<bool>> _pendingSetEdited = {};

  /// Mutable copy of template exercises so user can reorder during workout.
  late List<TemplateExercise> _orderedExercises;

  // Per-exercise notes (elderly-friendly). Persisted locally.
  static const String _exerciseNotesPrefsKey = 'exercise_notes_v1';
  Map<String, String> _exerciseNotesByExerciseId = {};

  /// Keeps weight/reps controls in view after rest, or scrolls to the plan row when target sets are done.
  final ScrollController _exerciseScrollController = ScrollController();
  final GlobalKey _repsSetsSectionKey = GlobalKey();
  final Map<String, GlobalKey> _planRowKeys = {};

  GlobalKey _globalKeyForPlanRow(String exerciseId) =>
      _planRowKeys.putIfAbsent(exerciseId, () => GlobalKey());

  late String _weightUnit;

  static const double _kgToLbs = 2.2046226218;
  static const double _kgStep = 0.5;
  static const double _lbsStep = 5.0;

  double get _weightStepKg =>
      _weightUnit == 'lbs' ? _lbsStep / _kgToLbs : _kgStep;

  double _kgToDisplay(double kg) => _weightUnit == 'lbs' ? kg * _kgToLbs : kg;

  double _displayToKg(double display) =>
      _weightUnit == 'lbs' ? display / _kgToLbs : display;

  String _formatWeightDisplay(double kg) {
    final v = _kgToDisplay(kg);
    return v == v.toInt() ? '${v.toInt()}' : v.toStringAsFixed(1);
  }

  Future<void> _setWeightUnit(String unit) async {
    if (unit != 'kg' && unit != 'lbs') return;
    if (_weightUnit == unit) return;
    setState(() => _weightUnit = unit);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('weight_unit', unit);
    } catch (_) {
      // Ignore persistence errors; in-memory unit still applies.
    }
    widget.onWeightUnitChanged?.call();
  }

  void _adjustCurrentWeight(double deltaKg) {
    setState(() => currentWeight = (currentWeight + deltaKg).clamp(0.0, 999.0));
  }

  int _elapsedWorkSecondsForCurrentPhase() {
    if (_workPhaseDurationSeconds > 0) {
      return (_workPhaseDurationSeconds - _workSecondsRemaining).clamp(
        1,
        86400,
      );
    }
    if (_orderedExercises.isEmpty) return 1;
    final current = _orderedExercises[currentExerciseIndex];
    return (current.targetDurationSeconds ?? currentDurationSeconds).clamp(
      1,
      86400,
    );
  }

  void _captureWorkPhaseDuration() {
    _pendingDurationLogSeconds = _elapsedWorkSecondsForCurrentPhase();
    final current = _orderedExercises[currentExerciseIndex];
    _pendingDurationLogWeight = _logWeightForExercise(current);
  }

  double _logWeightForExercise(TemplateExercise exercise) {
    if (!exercise.showsWeightInWorkout || currentWeight <= 0) return 0;
    return currentWeight;
  }

  double _pendingOrCurrentLogWeight(TemplateExercise exercise) {
    if (_pendingDurationLogWeight != null && _pendingDurationLogWeight! > 0) {
      return _pendingDurationLogWeight!;
    }
    return _logWeightForExercise(exercise);
  }

  /// Logs the finished hold set when rest begins so weight can be edited during rest.
  void _ensureDurationSetLoggedForCurrentSet() {
    if (_orderedExercises.isEmpty) return;
    final current = _orderedExercises[currentExerciseIndex];
    if (!current.durationBased) return;
    if (logs.any(
      (l) => l.exerciseId == current.exercise.id && l.setNumber == currentSet,
    )) {
      return;
    }
    final plannedDuration =
        (current.targetDurationSeconds ?? currentDurationSeconds).clamp(
          1,
          86400,
        );
    final workDuration = (_pendingDurationLogSeconds ?? plannedDuration).clamp(
      1,
      86400,
    );
    logs.add(
      ExerciseLog(
        exerciseId: current.exercise.id,
        exerciseName: current.exercise.name,
        setNumber: currentSet,
        reps: 0,
        weight: _pendingOrCurrentLogWeight(current),
        durationSeconds: workDuration,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _updateLogWeightAt(int logIndex, double newKg) {
    if (logIndex < 0 || logIndex >= logs.length) return;
    final clamped = newKg.clamp(0.0, 999.0);
    setState(() {
      logs[logIndex] = logs[logIndex].copyWith(weight: clamped);
      currentWeight = clamped;
    });
    unawaited(_persistWorkoutDraft());
  }

  void _updateLogRepsAt(int logIndex, int newReps) {
    if (logIndex < 0 || logIndex >= logs.length) return;
    final clamped = newReps.clamp(0, 999);
    setState(() {
      logs[logIndex] = logs[logIndex].copyWith(reps: clamped);
      currentReps = clamped;
    });
    unawaited(_persistWorkoutDraft());
  }

  void _editCompletedSetWeight(
    AppLocalizations l10n,
    ExerciseLog log,
    int logIndex,
  ) {
    _showNumberInputDialog(
      context: context,
      title: _weightUnit == 'lbs' ? l10n.get('weightLbs') : l10n.get('weight'),
      currentValue: _kgToDisplay(log.weight),
      isInteger: false,
      accentColor: Colors.orange,
      onSave: (displayValue) =>
          _updateLogWeightAt(logIndex, _displayToKg(displayValue)),
    );
  }

  void _editCompletedSetReps(
    AppLocalizations l10n,
    ExerciseLog log,
    int logIndex,
  ) {
    _showNumberInputDialog(
      context: context,
      title: l10n.reps,
      currentValue: log.reps.toDouble(),
      isInteger: true,
      accentColor: Theme.of(context).colorScheme.primary,
      onSave: (value) => _updateLogRepsAt(logIndex, value.toInt()),
    );
  }

  String _formatLogSetDetail(
    AppLocalizations l10n,
    ExerciseLog log, {
    required String exerciseName,
  }) {
    if (log.isDurationSet) {
      var detail = formatDurationMmSs(log.durationSeconds!);
      if (log.weight > 0) {
        detail +=
            ' × ${_formatWeightDisplay(log.weight)} ${_weightUnit == 'lbs' ? l10n.get('weightShortLbs') : l10n.get('weightShort')}';
      }
      return detail;
    }
    if (_isAssistedPullUp(exerciseName) && log.weight > 0) {
      return '${log.reps} ${l10n.reps}, ${_formatWeightDisplay(log.weight)} ${_weightUnit == 'lbs' ? l10n.get('weightShortLbs') : l10n.get('weightShort')} ${l10n.get('minusWeight')}';
    }
    return '${log.reps} ${l10n.reps}${log.weight > 0 ? ' ${_formatWeightDisplay(log.weight)} ${_weightUnit == 'lbs' ? l10n.get('weightShortLbs') : l10n.get('weightShort')}' : ''}';
  }

  /// Look up by exercise name so history is shared across templates (same exercise name).
  double? _getLastWeightForExercise(String exerciseName) {
    for (final session in widget.history) {
      for (final log in session.logs.reversed) {
        if (log.exerciseName == exerciseName && log.weight > 0) {
          return log.weight;
        }
      }
    }
    return null;
  }

  /// Last hold duration logged (seconds); null if none.
  int? _getLastDurationForExercise(String exerciseName) {
    for (final session in widget.history) {
      for (final log in session.logs.reversed) {
        if (log.exerciseName == exerciseName && log.isDurationSet) {
          return log.durationSeconds;
        }
      }
    }
    return null;
  }

  /// Placeholder weight/reps for one set row, from the most recent session that
  /// actually performed this exercise (skipping sessions where it was skipped).
  /// Prefers the log with the same [setNumber]; if that session did fewer sets
  /// than requested, falls back to its last logged set rather than the raw
  /// template target. Returns null if the exercise has never been logged.
  ({double weight, int reps})? _historicalSetPlaceholder(
    String exerciseName,
    int setNumber,
  ) {
    for (final session in widget.history) {
      final exLogs =
          session.logs
              .where((l) => l.exerciseName == exerciseName && !l.isDurationSet)
              .toList()
            ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
      if (exLogs.isEmpty) continue;
      final match = exLogs.where((l) => l.setNumber == setNumber);
      final log = match.isNotEmpty ? match.first : exLogs.last;
      return (weight: log.weight, reps: log.reps);
    }
    return null;
  }

  /// Lazily creates/grows (never shrinks or overwrites) the pending set-row
  /// caches for [ex] up to `ex.sets` rows, filling new rows from
  /// [_historicalSetPlaceholder] or the template's target reps/weight. Safe to
  /// call repeatedly (e.g. every time the user jumps to this exercise).
  void _ensureRowCache(TemplateExercise ex) {
    final id = ex.exercise.id;
    final weights = _pendingSetWeights.putIfAbsent(id, () => []);
    final reps = _pendingSetReps.putIfAbsent(id, () => []);
    final edited = _pendingSetEdited.putIfAbsent(id, () => []);
    while (weights.length < ex.sets) {
      final setNumber = weights.length + 1;
      final placeholder = _historicalSetPlaceholder(
        ex.exercise.name,
        setNumber,
      );
      weights.add(placeholder?.weight ?? ex.targetWeight);
      reps.add(placeholder?.reps ?? ex.targetReps);
      edited.add(false);
    }
  }

  /// Appends one more pending set row beyond the template's planned count.
  void _addExtraSetRow(TemplateExercise ex) {
    _ensureRowCache(ex);
    final id = ex.exercise.id;
    setState(() {
      final weights = _pendingSetWeights[id]!;
      final reps = _pendingSetReps[id]!;
      final edited = _pendingSetEdited[id]!;
      final setNumber = weights.length + 1;
      final placeholder = _historicalSetPlaceholder(
        ex.exercise.name,
        setNumber,
      );
      weights.add(
        placeholder?.weight ??
            (weights.isNotEmpty ? weights.last : ex.targetWeight),
      );
      reps.add(
        placeholder?.reps ?? (reps.isNotEmpty ? reps.last : ex.targetReps),
      );
      edited.add(false);
    });
    unawaited(_persistWorkoutDraft());
  }

  /// Logs a pending row's current weight/reps and starts rest — the per-row
  /// equivalent of the old single-set "Log Set" button.
  void _completeSetRow(TemplateExercise ex, int setNumber) {
    final id = ex.exercise.id;
    final idx = setNumber - 1;
    final weights = _pendingSetWeights[id];
    final reps = _pendingSetReps[id];
    if (weights == null || reps == null || idx < 0 || idx >= reps.length) {
      return;
    }
    final weight = weights[idx];
    final repCount = reps[idx];
    if (repCount <= 0) return;
    logs.add(
      ExerciseLog(
        exerciseId: id,
        exerciseName: ex.exercise.name,
        setNumber: setNumber,
        reps: repCount,
        weight: weight,
        timestamp: DateTime.now(),
      ),
    );
    setState(() {
      currentSet = setNumber + 1;
      currentReps = repCount;
      currentWeight = weight;
    });
    _startRestTimer();
    unawaited(_persistWorkoutDraft());
  }

  /// Past workout sessions that contain logs for this exercise (newest first). Matches by exercise name so history is shared across templates.
  List<MapEntry<WorkoutSession, List<ExerciseLog>>> _getPastSessionsForExercise(
    String exerciseName,
  ) {
    final list = <MapEntry<WorkoutSession, List<ExerciseLog>>>[];
    for (final session in widget.history) {
      final logs = session.logs
          .where((l) => l.exerciseName == exerciseName)
          .toList();
      if (logs.isNotEmpty) {
        list.add(MapEntry(session, logs));
      }
    }
    list.sort((a, b) => b.key.startTime.compareTo(a.key.startTime));
    return list;
  }

  void _showPastHistoryBottomSheet(BuildContext context, Exercise exercise) {
    final l10n = AppLocalizations.of(context)!;
    final past = _getPastSessionsForExercise(exercise.name);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM d, yyyy');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.25,
          maxChildSize: 0.85,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2A3A) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '${l10n.get('pastHistory')} – ${l10n.localizeExerciseName(exercise.name)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: past.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                l10n.get('noPastWorkoutsForExercise'),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: past.length,
                            itemBuilder: (_, index) {
                              final entry = past[index];
                              final session = entry.key;
                              final logs = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 18,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${l10n.get('workoutOn')} ${dateFormat.format(session.startTime)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...logs.map((log) {
                                      final weightPart = log.isDurationSet
                                          ? _formatLogSetDetail(
                                              l10n,
                                              log,
                                              exerciseName: exercise.name,
                                            )
                                          : log.weight > 0
                                          ? _isAssistedPullUp(exercise.name)
                                                ? '${log.reps} ${l10n.reps}, ${_formatWeightDisplay(log.weight)} ${_weightUnit == 'lbs' ? l10n.get('weightShortLbs') : l10n.get('weightShort')} ${l10n.get('minusWeight')}'
                                                : '${log.reps} ${l10n.reps} × ${_formatWeightDisplay(log.weight)} ${_weightUnit == 'lbs' ? l10n.get('weightShortLbs') : l10n.get('weightShort')}'
                                          : '${log.reps} ${l10n.reps}';
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          left: 26,
                                          top: 4,
                                        ),
                                        child: Text(
                                          '${l10n.get('set')} ${log.setNumber}: $weightPart',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: isDark
                                                ? Colors.grey.shade300
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _weightUnit = widget.weightUnit == 'lbs' || widget.weightUnit == 'kg'
        ? widget.weightUnit
        : 'kg';
    unawaited(_loadExerciseNotes());
    final restored = widget.restoredDraft;
    if (restored != null) {
      _orderedExercises = List.from(restored.template.exercises);
      startTime = restored.startTime;
      elapsedSeconds = restored.elapsedSeconds;
      final n = restored.template.exercises.length;
      currentExerciseIndex = n == 0
          ? 0
          : restored.currentExerciseIndex.clamp(0, n - 1);
      currentSet = restored.currentSet;
      currentReps = restored.currentReps;
      currentWeight = restored.currentWeight;
      currentDurationSeconds = restored.currentDurationSeconds;
      logs = List.from(restored.logs);
      isResting = restored.isResting;
      restSeconds = restored.restSeconds;
      _defaultRestSeconds = restored.defaultRestSeconds;
      _viewingPlanDuringRest = restored.viewingPlanDuringRest;
      restored.pendingSetWeights.forEach(
        (id, values) => _pendingSetWeights[id] = List<double>.from(values),
      );
      restored.pendingSetReps.forEach(
        (id, values) => _pendingSetReps[id] = List<int>.from(values),
      );
      restored.pendingSetEdited.forEach(
        (id, values) => _pendingSetEdited[id] = List<bool>.from(values),
      );
      if (isResting && restSeconds <= 0) {
        isResting = false;
        _viewingPlanDuringRest = false;
      }
      _loadPreviousBestsFromHistory();
      _restoreRestTimer();
    } else {
      _orderedExercises = List.from(widget.template.exercises);
      startTime = DateTime.now();
      _loadPreviousBestsFromHistory();
      _loadDefaultRestSeconds();
      _initializeCurrentExercise();
    }
    _startWorkoutTimer();
    _setBeepAudioContext();
    _draftAutosaveTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_suppressDraftSave && mounted) {
        unawaited(_persistWorkoutDraft());
      }
    });
  }

  Future<void> _loadExerciseNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_exerciseNotesPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final notes = <String, String>{};
      for (final entry in decoded.entries) {
        final v = entry.value;
        if (v is String) notes[entry.key] = v;
      }
      if (!mounted) return;
      setState(() => _exerciseNotesByExerciseId = notes);
    } catch (_) {
      // Ignore persistence errors
    }
  }

  Future<void> _persistExerciseNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _exerciseNotesPrefsKey,
        jsonEncode(_exerciseNotesByExerciseId),
      );
    } catch (_) {
      // Ignore persistence errors
    }
  }

  Future<void> _showExerciseNotesDialog(
    AppLocalizations l10n,
    TemplateExercise exercise,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final name = l10n.localizeExerciseName(exercise.exercise.name);
    final existing = _exerciseNotesByExerciseId[exercise.exercise.id] ?? '';
    final controller = TextEditingController(text: existing);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        final screenH = MediaQuery.sizeOf(context).height;
        final sheetHeight = (screenH * 0.75).clamp(320.0, 620.0);

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            top: false,
            child: Container(
              height: sheetHeight,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2A3A) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 6,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.get('notes'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLines: null,
                        expands: true,
                        style: TextStyle(
                          fontSize: 20,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.get('typeHere'),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                l10n.get('cancel'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: FilledButton(
                              onPressed: () {
                                final trimmed = controller.text.trim();
                                setState(() {
                                  if (trimmed.isEmpty) {
                                    _exerciseNotesByExerciseId.remove(
                                      exercise.exercise.id,
                                    );
                                  } else {
                                    _exerciseNotesByExerciseId[exercise
                                            .exercise
                                            .id] =
                                        trimmed;
                                  }
                                });
                                unawaited(_persistExerciseNotes());
                                Navigator.of(context).pop();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                l10n.get('save'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (!_suppressDraftSave) {
        unawaited(_persistWorkoutDraft());
      }
    }
    // After backgrounding, iOS/Android often deactivate the session or leave the
    // player in a bad state; re-apply before the next beep.
    if (state == AppLifecycleState.resumed) {
      _setBeepAudioContext();
    }
  }

  /// Configure beeps to mix with other audio (Audible, podcasts) without pausing.
  Future<void> _setBeepAudioContext() async {
    try {
      await audioPlayer.setAudioContext(timerBeepMixWithOthersAudioContext());
    } catch (e) {
      // Ignore; beep will still play, may interrupt other audio on some devices
    }
  }

  Future<void> _loadDefaultRestSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('default_rest_seconds');
    if (saved != null && mounted) {
      setState(() => _defaultRestSeconds = saved.clamp(30, 600));
    }
  }

  void _loadPreviousBestsFromHistory() {
    for (final session in widget.history) {
      for (final log in session.logs) {
        if (log.isDurationSet) {
          final d = log.durationSeconds!;
          final cur = previousBestDurationSeconds[log.exerciseName] ?? 0;
          if (d > cur) previousBestDurationSeconds[log.exerciseName] = d;
        } else {
          final currentBest = previousBestReps[log.exerciseName] ?? 0;
          if (log.reps > currentBest) {
            previousBestReps[log.exerciseName] = log.reps;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftAutosaveTimer?.cancel();
    if (!_suppressDraftSave) {
      unawaited(_persistWorkoutDraft());
    }
    workoutTimer?.cancel();
    _durationWorkTimer?.cancel();
    _warmupTimer?.cancel();
    restTimer?.cancel();
    _exerciseScrollController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  void _stopDurationSession({bool clearRest = false}) {
    _durationWorkTimer?.cancel();
    _durationWorkTimer = null;
    _warmupTimer?.cancel();
    _warmupTimer = null;
    _durationSessionRunning = false;
    _durationSessionInWork = true;
    _warmupSecondsRemaining = 0;
    _workSecondsRemaining = 0;
    _workPhaseDurationSeconds = 0;
    _pendingDurationLogSeconds = null;
    _pendingDurationLogWeight = null;
    if (clearRest) {
      restTimer?.cancel();
      isResting = false;
      restSeconds = 0;
      _viewingPlanDuringRest = false;
      _restCountdownPaused = false;
    }
  }

  int _effectiveRestSecondsForCurrentDurationExercise() {
    if (_orderedExercises.isEmpty) return _defaultRestSeconds.clamp(0, 600);
    final current = _orderedExercises[currentExerciseIndex];
    final override = current.restAfterSetSeconds;
    return (override ?? _defaultRestSeconds).clamp(0, 600);
  }

  void _startDurationSession() {
    if (_orderedExercises.isEmpty) return;
    final current = _orderedExercises[currentExerciseIndex];
    if (!current.durationBased) return;
    _stopDurationSession(clearRest: true);
    final workSeconds =
        (current.targetDurationSeconds ?? currentDurationSeconds).clamp(
          1,
          86400,
        );
    final warmup = (current.warmupSeconds ?? 0).clamp(0, 600);
    if (warmup > 0) {
      setState(() {
        _durationSessionRunning = true;
        _durationSessionInWork = false;
        _warmupSecondsRemaining = warmup;
        _workSecondsRemaining = workSeconds;
        isResting = false;
        restSeconds = 0;
        _viewingPlanDuringRest = false;
      });
      _warmupTimer = Timer.periodic(const Duration(seconds: 1), _onWarmupTick);
      if (warmup >= 2 && warmup <= 3) {
        unawaited(_playRestCountdownBeep(warmup));
      }
    } else {
      setState(() {
        _durationSessionRunning = true;
        _durationSessionInWork = true;
        _warmupSecondsRemaining = 0;
        _workSecondsRemaining = workSeconds;
        _workPhaseDurationSeconds = workSeconds;
        _pendingDurationLogSeconds = null;
        _pendingDurationLogWeight = null;
        isResting = false;
        restSeconds = 0;
        _viewingPlanDuringRest = false;
      });
      _durationWorkTimer = Timer.periodic(
        const Duration(seconds: 1),
        _onDurationWorkTick,
      );
      if (workSeconds >= 2 && workSeconds <= 3) {
        unawaited(_playWorkCountdownBeep(workSeconds));
      }
      _scrollRepsSetsSectionIntoView(alignment: 0.02);
    }
    unawaited(_persistWorkoutDraft());
    if (warmup > 0) {
      _scrollRepsSetsSectionIntoView(alignment: 0.02);
    }
  }

  void _beginWorkAfterWarmup() {
    if (!mounted) return;
    if (_orderedExercises.isEmpty) return;
    final current = _orderedExercises[currentExerciseIndex];
    if (!current.durationBased) return;
    final workSeconds =
        (current.targetDurationSeconds ?? currentDurationSeconds).clamp(
          1,
          86400,
        );
    setState(() {
      _warmupSecondsRemaining = 0;
      _durationSessionInWork = true;
      _workSecondsRemaining = workSeconds;
      _workPhaseDurationSeconds = workSeconds;
      _pendingDurationLogSeconds = null;
      _pendingDurationLogWeight = null;
    });
    _durationWorkTimer?.cancel();
    _durationWorkTimer = Timer.periodic(
      const Duration(seconds: 1),
      _onDurationWorkTick,
    );
    if (workSeconds >= 2 && workSeconds <= 3) {
      unawaited(_playWorkCountdownBeep(workSeconds));
    }
    unawaited(_persistWorkoutDraft());
    _scrollRepsSetsSectionIntoView(alignment: 0.02);
  }

  void _finishCurrentDurationWorkPhase() {
    if (!mounted || _orderedExercises.isEmpty) return;
    _durationWorkTimer?.cancel();
    _durationWorkTimer = null;
    _captureWorkPhaseDuration();
    _beginDurationRestPhase();
  }

  /// Logs the full planned hold time immediately, for when the user already
  /// did the hold/carry (e.g. a 15-minute run) before opening the app, so
  /// they don't have to wait for the timer to count down again.
  void _logDurationSetAlreadyCompleted() {
    if (!mounted || _orderedExercises.isEmpty) return;
    final current = _orderedExercises[currentExerciseIndex];
    if (!current.durationBased) return;
    if (_durationSessionRunning || _workSecondsRemaining > 0) return;
    final plannedSeconds =
        (current.targetDurationSeconds ?? currentDurationSeconds).clamp(
          1,
          86400,
        );
    setState(() {
      _durationSessionRunning = true;
      _durationSessionInWork = true;
    });
    _pendingDurationLogSeconds = plannedSeconds;
    _pendingDurationLogWeight = _logWeightForExercise(current);
    _beginDurationRestPhase();
  }

  void _onWarmupTick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    int? warmCountdownBeepAt;
    var warmupDone = false;
    setState(() {
      final before = _warmupSecondsRemaining;
      if (before <= 1) {
        if (before == 1) warmCountdownBeepAt = 1;
        _warmupSecondsRemaining = 0;
        warmupDone = true;
      } else {
        final after = before - 1;
        if (after >= 1 && after <= 3) warmCountdownBeepAt = after;
        _warmupSecondsRemaining--;
      }
    });
    if (warmCountdownBeepAt != null || warmupDone) {
      unawaited(_warmupTickSounds(warmCountdownBeepAt, warmupDone));
    }
    if (warmupDone) {
      timer.cancel();
      _warmupTimer = null;
      _beginWorkAfterWarmup();
    }
  }

  Future<void> _warmupTickSounds(int? countdownAt, bool finished) async {
    if (countdownAt != null) {
      await _playRestCountdownBeep(countdownAt);
      if (finished) {
        await Future<void>.delayed(const Duration(milliseconds: 110));
      }
    }
    if (finished) {
      await _playDoubleEndBeeps();
    }
  }

  void _pauseDurationSession() {
    _durationWorkTimer?.cancel();
    _warmupTimer?.cancel();
    restTimer?.cancel();
    restTimer = null;
    setState(() {
      _durationSessionRunning = false;
    });
    unawaited(_persistWorkoutDraft());
  }

  void _resumeDurationSession() {
    if (_orderedExercises.isEmpty) return;
    final current = _orderedExercises[currentExerciseIndex];
    if (!current.durationBased) return;
    if (_durationSessionRunning) return;
    setState(() {
      _durationSessionRunning = true;
      _restCountdownPaused = false;
    });
    if (_warmupSecondsRemaining > 0 && !isResting) {
      _warmupTimer?.cancel();
      _warmupTimer = Timer.periodic(const Duration(seconds: 1), _onWarmupTick);
    } else if (_durationSessionInWork) {
      _durationWorkTimer?.cancel();
      _durationWorkTimer = Timer.periodic(
        const Duration(seconds: 1),
        _onDurationWorkTick,
      );
    } else {
      _restoreRestTimer();
    }
    unawaited(_persistWorkoutDraft());
  }

  void _onDurationWorkTick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    int? workCountdownBeepAt;
    var workJustEnded = false;
    setState(() {
      final before = _workSecondsRemaining;
      if (before <= 1) {
        _workSecondsRemaining = 0;
        workJustEnded = true;
        timer.cancel();
      } else {
        if (_durationSessionRunning && _durationSessionInWork) {
          final after = before - 1;
          if (after >= 1 && after <= 3) {
            workCountdownBeepAt = after;
          }
        }
        _workSecondsRemaining--;
      }
    });
    if (workJustEnded) {
      unawaited(() async {
        if (mounted) {
          _finishCurrentDurationWorkPhase();
        }
      }());
    } else if (workCountdownBeepAt != null) {
      unawaited(_playWorkCountdownBeep(workCountdownBeepAt!));
    }
  }

  void _beginDurationRestPhase() {
    if (!mounted) return;
    _ensureDurationSetLoggedForCurrentSet();
    final rest = _effectiveRestSecondsForCurrentDurationExercise();
    setState(() {
      _durationSessionInWork = false;
      isResting = rest > 0;
      restSeconds = rest;
      _viewingPlanDuringRest = false;
    });
    unawaited(_playWorkEndBeep());
    _durationWorkTimer?.cancel();
    _durationWorkTimer = null;
    if (rest <= 0) {
      _onDurationRestFinished();
      return;
    }
    restTimer?.cancel();
    restTimer = Timer.periodic(const Duration(seconds: 1), _onRestTimerTick);
    unawaited(_persistWorkoutDraft());
  }

  void _onDurationRestFinished() {
    if (_orderedExercises.isEmpty) return;
    final current = _orderedExercises[currentExerciseIndex];
    if (!current.durationBased) return;

    _ensureDurationSetLoggedForCurrentSet();
    _pendingDurationLogSeconds = null;
    _pendingDurationLogWeight = null;

    final loggedCount = logs
        .where((l) => l.exerciseId == current.exercise.id)
        .length;
    final reachedTarget = loggedCount >= current.sets;

    setState(() {
      currentSet = loggedCount + 1;
      isResting = false;
      restSeconds = 0;
      _viewingPlanDuringRest = false;
    });

    if (reachedTarget) {
      _stopDurationSession(clearRest: true);
      if (currentExerciseIndex < _orderedExercises.length - 1) {
        setState(() {
          currentExerciseIndex++;
          final next = _orderedExercises[currentExerciseIndex];
          final loggedForExercise = logs
              .where((l) => l.exerciseId == next.exercise.id)
              .length;
          currentSet = loggedForExercise + 1;
          _initializeCurrentExercise();
        });
        // Don't use _scheduleScrollAfterRestEnds here: _applyScrollAfterRest would
        // run with the new [currentExerciseIndex] and scroll to the bottom (0 logs).
        final nextId = _orderedExercises[currentExerciseIndex].exercise.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _scrollToPlanRowForExercise(nextId);
        });
      } else {
        _scheduleScrollAfterRestEnds();
      }
      unawaited(_persistWorkoutDraft());
      return;
    }

    _scheduleScrollAfterRestEnds();

    final nextWorkSeconds =
        (current.targetDurationSeconds ?? currentDurationSeconds).clamp(
          1,
          86400,
        );
    setState(() {
      _durationSessionInWork = true;
      _workSecondsRemaining = nextWorkSeconds;
      _workPhaseDurationSeconds = nextWorkSeconds;
      _pendingDurationLogSeconds = null;
      _pendingDurationLogWeight = null;
    });
    if (_durationSessionRunning) {
      _durationWorkTimer?.cancel();
      _durationWorkTimer = Timer.periodic(
        const Duration(seconds: 1),
        _onDurationWorkTick,
      );
    }
    if (nextWorkSeconds >= 2 && nextWorkSeconds <= 3) {
      unawaited(_playWorkCountdownBeep(nextWorkSeconds));
    }
    unawaited(_persistWorkoutDraft());
    _scrollRepsSetsSectionIntoView(alignment: 0.02);
  }

  /// After rest ends: stay at bottom for the next set if template sets remain; otherwise scroll to this exercise in the plan.
  void _scheduleScrollAfterRestEnds() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyScrollAfterRest();
    });
  }

  void _applyScrollAfterRest() {
    if (!mounted || _orderedExercises.isEmpty) return;
    final current = _orderedExercises[currentExerciseIndex];
    final loggedCount = logs
        .where((l) => l.exerciseId == current.exercise.id)
        .length;
    // Exactly at template completion: show this exercise in the plan (checkmark).
    // Fewer sets remaining, or bonus sets beyond target: keep weight/reps at bottom.
    if (loggedCount == current.sets) {
      _scrollToPlanRowForExercise(current.exercise.id);
    } else {
      _scrollExerciseContentToBottom();
    }
  }

  void _scrollExerciseContentToBottom() {
    if (!_exerciseScrollController.hasClients) return;
    final position = _exerciseScrollController.position;
    position.animateTo(
      position.maxScrollExtent,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToPlanRowForExercise(String exerciseId) {
    final key = _planRowKeys[exerciseId];
    final targetContext = key?.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    } else {
      _scrollExerciseContentToBottom();
    }
  }

  /// After jumping to an exercise via the plan list, bring weight/reps (or hold) controls into view.
  /// [alignment] is passed to [Scrollable.ensureVisible] (0 = top of viewport, 0.5 = center).
  void _scrollRepsSetsSectionIntoView({double alignment = 0.05}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = _repsSetsSectionKey.currentContext;
      if (targetContext != null && _exerciseScrollController.hasClients) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: alignment,
        );
      }
    });
  }

  void _initializeCurrentExercise() {
    if (_orderedExercises.isEmpty) return;
    final current = _orderedExercises[currentExerciseIndex];
    if (current.durationBased) {
      final lastD = _getLastDurationForExercise(current.exercise.name);
      final target = current.targetDurationSeconds;
      currentDurationSeconds =
          (target ?? lastD ?? kDefaultTargetDurationSeconds).clamp(1, 86400);
      currentReps = 0;
      if (current.durationTracksWeight) {
        final lastWeight = _getLastWeightForExercise(current.exercise.name);
        currentWeight = lastWeight ?? current.targetWeight;
      } else {
        currentWeight = 0;
      }
    } else {
      _ensureRowCache(current);
      currentDurationSeconds = 0;
    }
  }

  WorkoutTemplate _draftTemplateSnapshot() {
    return WorkoutTemplate(
      id: widget.template.id,
      name: widget.template.name,
      description: widget.template.description,
      exercises: List.from(_orderedExercises),
      createdAt: widget.template.createdAt,
    );
  }

  Future<void> _persistExerciseOrderToTemplateStorage() async {
    try {
      final updatedTemplate = widget.template.copyWith(
        exercises: List<TemplateExercise>.from(_orderedExercises),
      );

      // Keep the in-memory templates list (parent) in sync, if provided.
      widget.onUpdateTemplate?.call(updatedTemplate);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('workout_templates');
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      final storedTemplates = decoded
          .map((e) => WorkoutTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
      final templateIndex = storedTemplates.indexWhere(
        (t) => t.id == widget.template.id,
      );
      if (templateIndex == -1) return;

      storedTemplates[templateIndex] = storedTemplates[templateIndex].copyWith(
        exercises: List<TemplateExercise>.from(_orderedExercises),
      );
      await prefs.setString(
        'workout_templates',
        jsonEncode(storedTemplates.map((t) => t.toJson()).toList()),
      );
    } catch (_) {
      // Ignore persistence errors; in-memory reorder still applies.
    }
  }

  Future<void> _persistWorkoutDraft() async {
    if (_suppressDraftSave || !mounted) return;
    try {
      final draft = WorkoutDraft(
        template: _draftTemplateSnapshot(),
        startTime: startTime,
        elapsedSeconds: elapsedSeconds,
        currentExerciseIndex: currentExerciseIndex,
        currentSet: currentSet,
        currentReps: currentReps,
        currentWeight: currentWeight,
        currentDurationSeconds: currentDurationSeconds,
        logs: List.from(logs),
        isResting: isResting,
        restSeconds: restSeconds,
        defaultRestSeconds: _defaultRestSeconds,
        viewingPlanDuringRest: _viewingPlanDuringRest,
        pendingSetWeights: _pendingSetWeights.map(
          (id, values) => MapEntry(id, List<double>.from(values)),
        ),
        pendingSetReps: _pendingSetReps.map(
          (id, values) => MapEntry(id, List<int>.from(values)),
        ),
        pendingSetEdited: _pendingSetEdited.map(
          (id, values) => MapEntry(id, List<bool>.from(values)),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kWorkoutDraftPrefsKey, jsonEncode(draft.toJson()));
    } catch (_) {
      // Ignore persistence errors
    }
  }

  void _startWorkoutTimer() {
    workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        elapsedSeconds++;
      });
    });
  }

  void _showNumberInputDialog({
    required BuildContext context,
    required String title,
    required double currentValue,
    required bool isInteger,
    required Color accentColor,
    required Function(double) onSave,
  }) {
    final controller = TextEditingController(
      text: isInteger
          ? currentValue.toInt().toString()
          : (currentValue == currentValue.toInt()
                ? currentValue.toInt().toString()
                : currentValue.toStringAsFixed(1)),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) {
        // Select all text when dialog opens so user can type immediately
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.text.isNotEmpty) {
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          }
        });
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2A3A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: !isInteger,
                  signed: false,
                ),
                textAlign: TextAlign.center,
                autofocus: true,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : accentColor,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark
                      ? accentColor.withValues(alpha: 0.2)
                      : accentColor.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: accentColor, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: accentColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: accentColor, width: 3),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      l10n!.cancel,
                      style: TextStyle(
                        fontSize: 18,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final text = controller.text.trim();
                      final value = double.tryParse(text);
                      if (value != null && value >= 0) {
                        onSave(value);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l10n.get('save'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _onRestTimerTick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    var finishedRest = false;
    int? countdownBeepAt;
    setState(() {
      final before = restSeconds;
      if (before <= 1) {
        if (before == 1) countdownBeepAt = 1;
        restSeconds = 0;
        isResting = false;
        _viewingPlanDuringRest = false;
        finishedRest = true;
        timer.cancel();
      } else {
        final after = before - 1;
        if (after >= 1 && after <= 3) {
          countdownBeepAt = after;
        }
        restSeconds--;
      }
    });
    if (countdownBeepAt != null || finishedRest) {
      unawaited(_restTickAudio(countdownBeepAt, finishedRest));
    }
    if (finishedRest) {
      if (_durationSessionRunning && !_durationSessionInWork) {
        _onDurationRestFinished();
      } else {
        _scheduleScrollAfterRestEnds();
      }
    }
  }

  Future<void> _restTickAudio(int? countdownAt, bool finished) async {
    if (countdownAt != null) {
      await _playRestCountdownBeep(countdownAt);
      if (finished) {
        await Future<void>.delayed(const Duration(milliseconds: 110));
      }
    }
    if (finished) {
      await _playDoubleEndBeeps();
      await _vibrateRestEnd();
    }
  }

  void _startRestTimer() {
    if (_orderedExercises.isEmpty) return;
    final current = _orderedExercises[currentExerciseIndex];
    final override = current.restAfterSetSeconds;
    final effective = (override ?? _defaultRestSeconds).clamp(0, 600);
    if (effective <= 0) {
      // No rest configured: leave the screen exactly where the user is
      // looking rather than auto-scrolling right after they tap the tick.
      unawaited(_persistWorkoutDraft());
      return;
    }
    setState(() {
      isResting = true;
      restSeconds = effective;
      _restCountdownPaused = false;
    });
    restTimer?.cancel();
    restTimer = Timer.periodic(const Duration(seconds: 1), _onRestTimerTick);
    if (effective >= 2 && effective <= 3) {
      unawaited(_playRestCountdownBeep(effective));
    }
  }

  void _restoreRestTimer() {
    restTimer?.cancel();
    if (!isResting || restSeconds <= 0 || _restCountdownPaused) return;
    restTimer = Timer.periodic(const Duration(seconds: 1), _onRestTimerTick);
  }

  void _pauseRestCountdown() {
    if (!isResting || restSeconds <= 0) return;
    restTimer?.cancel();
    restTimer = null;
    setState(() => _restCountdownPaused = true);
    unawaited(_persistWorkoutDraft());
  }

  void _resumeRestCountdown() {
    if (!isResting || restSeconds <= 0 || !_restCountdownPaused) return;
    setState(() => _restCountdownPaused = false);
    restTimer = Timer.periodic(const Duration(seconds: 1), _onRestTimerTick);
    unawaited(_persistWorkoutDraft());
  }

  void _addRestSeconds(int delta) {
    setState(() => restSeconds = (restSeconds + delta).clamp(0, 600));
  }

  void _subtractRestSeconds(int delta) {
    setState(() => restSeconds = (restSeconds - delta).clamp(0, 600));
  }

  void _skipRest() {
    restTimer?.cancel();
    setState(() {
      isResting = false;
      restSeconds = 0;
      _viewingPlanDuringRest = false;
      _restCountdownPaused = false;
    });
    if (_durationSessionRunning && !_durationSessionInWork) {
      _onDurationRestFinished();
    } else {
      _scheduleScrollAfterRestEnds();
    }
    unawaited(_persistWorkoutDraft());
  }

  /// [volumeScale] multiplies the user’s timer volume (e.g. softer tier-2 ticks).
  Future<void> _playBeep({
    String asset = 'audio/timer_beep.wav',
    double volumeScale = 1.0,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final volPct = prefs.getInt(kPrefTimerBeepVolume);
      final vol = ((volPct ?? 85).clamp(0, 100)) / 100.0;
      if (vol <= 0) return;
      final scaled = (vol * volumeScale.clamp(0.05, 1.5)).clamp(0.0, 1.0);
      if (scaled <= 0) return;
      await _setBeepAudioContext();
      await audioPlayer.setVolume(scaled);
      await audioPlayer.stop();
      await audioPlayer.play(AssetSource(asset));
    } catch (e) {
      // Ignore audio errors
    }
  }

  // Interval-timer beeps (WAVs under assets/audio/)
  static const String _kBeepNormal = 'audio/timer_beep.wav';
  static const String _kBeepWorkEnd = 'audio/work_end_beep.wav';
  static const String _kBeepRest1 = 'audio/rest_1_beep.wav';
  static const String _kBeepWork1 = 'audio/work_1_beep.wav';

  /// Hold finished (0s): work_1 chime.
  Future<void> _playWorkEndBeep() async {
    try {
      await _playBeep(asset: _kBeepWork1);
    } catch (_) {
      try {
        await _playBeep(asset: _kBeepWorkEnd);
      } catch (_) {
        await _playBeep(asset: _kBeepNormal);
      }
    }
  }

  /// Rest / warm-up: same 1s chime at 3s, 2s, and 1s.
  Future<void> _playRestCountdownBeep(int secondsRemaining) async {
    try {
      switch (secondsRemaining) {
        case 3:
        case 2:
        case 1:
          await _playBeep(asset: _kBeepRest1);
        default:
          await _playBeep(asset: _kBeepNormal);
      }
    } catch (_) {
      await _playBeep(asset: _kBeepNormal);
    }
  }

  /// Hold countdown: rest_1 at 3s, 2s, and 1s (same as rest/warm-up tier chime).
  Future<void> _playWorkCountdownBeep(int secondsRemaining) async {
    try {
      switch (secondsRemaining) {
        case 3:
        case 2:
        case 1:
          await _playBeep(asset: _kBeepRest1);
        default:
          await _playBeep(asset: _kBeepNormal);
      }
    } catch (_) {
      await _playBeep(asset: _kBeepNormal);
    }
  }

  /// Rest / warm-up finished: two slightly spaced longer tones.
  Future<void> _playDoubleEndBeeps() async {
    try {
      await _playBeep(asset: _kBeepWorkEnd);
      await Future<void>.delayed(const Duration(milliseconds: 420));
      await _playBeep(asset: _kBeepWorkEnd);
    } catch (_) {
      await _playBeep(asset: _kBeepNormal);
    }
  }

  /// Vibrates when rest timer ends. Uses a double-pulse pattern that is
  /// easy to notice for elderly users without being harsh.
  Future<void> _vibrateRestEnd() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(pattern: [0, 500, 200, 500]);
      }
    } catch (_) {
      // Ignore vibration errors (e.g. unsupported platform)
    }
  }

  Future<void> _showDurationExerciseSettingsDialog() async {
    if (_orderedExercises.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final current = _orderedExercises[currentExerciseIndex];
    if (!current.durationBased) return;

    final loggedCount = logs
        .where((l) => l.exerciseId == current.exercise.id)
        .length;

    var sets = current.sets;
    final currentStateDuration = currentDurationSeconds > 0
        ? currentDurationSeconds
        : null;
    var targetDurationSeconds =
        (current.targetDurationSeconds ??
                currentStateDuration ??
                kDefaultTargetDurationSeconds)
            .clamp(1, 86400);

    var warmupSeconds = ((current.warmupSeconds ?? 0).clamp(0, 600));

    var durationTracksWeight = current.durationTracksWeight;

    var restMode = 0;
    var customRestSec = 60;
    final rInit = current.restAfterSetSeconds;
    if (rInit == null) {
      restMode = 0;
      customRestSec = 60;
    } else if (rInit == 0) {
      restMode = 1;
      customRestSec = 60;
    } else {
      restMode = 2;
      customRestSec = rInit.clamp(0, 600);
    }

    // Rest presets (seconds) editable here.
    var presetSeconds = List<int>.from(_restPresetSeconds);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Widget restTileEl({
            required bool selected,
            required String title,
            required String? subtitle,
            required VoidCallback onTap,
          }) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: selected
                    ? primary.withValues(alpha: isDark ? 0.28 : 0.14)
                    : (isDark ? const Color(0xFF232F3E) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          selected ? Icons.check_circle : Icons.circle_outlined,
                          size: 32,
                          color: selected ? primary : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (subtitle != null && subtitle.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E2A3A) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              l10n.get('settings'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.localizeExerciseName(current.exercise.name),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.get('durationTracksWeight'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      l10n.get('durationTracksWeightDesc'),
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                    ),
                    value: durationTracksWeight,
                    onChanged: (v) =>
                        setDialogState(() => durationTracksWeight = v),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.get('holdTime'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: l10n.get('decreaseHoldTime'),
                        onPressed: () => setDialogState(
                          () => targetDurationSeconds =
                              (targetDurationSeconds - 5).clamp(1, 86400),
                        ),
                        icon: const Icon(Icons.remove_circle_outline),
                        iconSize: 36,
                      ),
                      Semantics(button: true, child: GestureDetector(
                        onTap: () => showDurationEntryDialog(
                          context: ctx,
                          l10n: l10n,
                          currentSeconds: targetDurationSeconds,
                          accentColor: primary,
                          onSave: (sec) => setDialogState(
                            () => targetDurationSeconds = sec.clamp(1, 86400),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(
                              alpha: isDark ? 0.22 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primary.withValues(alpha: 0.45),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            formatDurationMmSs(targetDurationSeconds),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      )),
                      IconButton(
                        tooltip: l10n.get('increaseHoldTime'),
                        onPressed: () => setDialogState(
                          () => targetDurationSeconds =
                              (targetDurationSeconds + 5).clamp(1, 86400),
                        ),
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 36,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final sec in [30, 45, 60, 90, 120])
                        OutlinedButton(
                          onPressed: () =>
                              setDialogState(() => targetDurationSeconds = sec),
                          child: Text(formatDurationMmSs(sec)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.get('warmupBeforeHold'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.get('warmupBeforeHoldSubtitle'),
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: l10n.get('decreaseWarmup'),
                        onPressed: () => setDialogState(
                          () =>
                              warmupSeconds = (warmupSeconds - 5).clamp(0, 600),
                        ),
                        icon: const Icon(Icons.remove_circle_outline),
                        iconSize: 36,
                      ),
                      Semantics(button: true, child: GestureDetector(
                        onTap: () => showDurationEntryDialog(
                          context: ctx,
                          l10n: l10n,
                          currentSeconds: warmupSeconds,
                          accentColor: primary,
                          onSave: (sec) => setDialogState(
                            () => warmupSeconds = sec.clamp(0, 600),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            warmupSeconds <= 0
                                ? l10n.get('warmupOff')
                                : formatDurationMmSs(warmupSeconds),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )),
                      IconButton(
                        tooltip: l10n.get('increaseWarmup'),
                        onPressed: () => setDialogState(
                          () =>
                              warmupSeconds = (warmupSeconds + 5).clamp(0, 600),
                        ),
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 36,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final sec in [0, 10, 15, 20, 30, 45])
                        OutlinedButton(
                          onPressed: () =>
                              setDialogState(() => warmupSeconds = sec),
                          child: Text(
                            sec == 0 ? l10n.get('warmupOff') : '${sec}s',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.get('sets'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: l10n.get('decreaseSets'),
                        onPressed: () {
                          if (sets > 1) {
                            setDialogState(() => sets--);
                          }
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                        iconSize: 36,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '$sets',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.get('increaseSets'),
                        onPressed: () => setDialogState(() => sets++),
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 36,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.get('restBetweenSetsTitle'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  restTileEl(
                    selected: restMode == 0,
                    title: l10n.get('restOptionDefault'),
                    subtitle: l10n
                        .get('restOptionDefaultSub')
                        .replaceAll(
                          '{time}',
                          formatDurationMmSs(_defaultRestSeconds),
                        ),
                    onTap: () => setDialogState(() => restMode = 0),
                  ),
                  restTileEl(
                    selected: restMode == 1,
                    title: l10n.get('restOptionNoRest'),
                    subtitle: l10n.get('restOptionNoRestSub'),
                    onTap: () => setDialogState(() => restMode = 1),
                  ),
                  restTileEl(
                    selected: restMode == 2,
                    title: l10n.get('restOptionCustom'),
                    subtitle: l10n.get('restOptionCustomSub'),
                    onTap: () => setDialogState(() => restMode = 2),
                  ),
                  if (restMode == 2) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: l10n.get('decreaseRest'),
                          onPressed: customRestSec <= 0
                              ? null
                              : () => setDialogState(
                                  () => customRestSec = (customRestSec - 5)
                                      .clamp(0, 600),
                                ),
                          icon: const Icon(Icons.remove_circle_outline),
                          iconSize: 36,
                        ),
                        Semantics(button: true, child: GestureDetector(
                          onTap: () => showDurationEntryDialog(
                            context: ctx,
                            l10n: l10n,
                            currentSeconds: customRestSec,
                            accentColor: primary,
                            onSave: (sec) => setDialogState(
                              () => customRestSec = sec.clamp(0, 600),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              formatDurationMmSs(customRestSec),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        )),
                        IconButton(
                          tooltip: l10n.get('increaseRest'),
                          onPressed: customRestSec >= 600
                              ? null
                              : () => setDialogState(
                                  () => customRestSec = (customRestSec + 5)
                                      .clamp(0, 600),
                                ),
                          icon: const Icon(Icons.add_circle_outline),
                          iconSize: 36,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    l10n.get('rest'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.get('tapToEdit'),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(presetSeconds.length, (i) {
                      final sec = presetSeconds[i];
                      return Semantics(
 customSemanticsActions: {
 CustomSemanticsAction(label: l10n.get('edit')): () => showDurationEntryDialog(
                          context: ctx,
                          l10n: l10n,
                          currentSeconds: sec,
                          accentColor: primary,
                          onSave: (newSec) => setDialogState(
                            () => presetSeconds[i] = newSec.clamp(1, 600),
                          ),
                        ),
 },
 child: GestureDetector(
                        onLongPress: () => showDurationEntryDialog(
                          context: ctx,
                          l10n: l10n,
                          currentSeconds: sec,
                          accentColor: primary,
                          onSave: (newSec) => setDialogState(
                            () => presetSeconds[i] = newSec.clamp(1, 600),
                          ),
                        ),
                        child: OutlinedButton(
                          onPressed: () => setDialogState(() {
                            restMode = 2;
                            customRestSec = sec.clamp(0, 600);
                          }),
                          child: Text(formatDurationMmSs(sec)),
                        ),
                      ));
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel, style: const TextStyle(fontSize: 20)),
              ),
              ElevatedButton(
                onPressed: () {
                  final safeSets = math.max(sets, math.max(1, loggedCount));
                  final int? restAfterSetSeconds = switch (restMode) {
                    0 => null,
                    1 => 0,
                    _ => customRestSec.clamp(0, 600),
                  };
                  final updatedExercise = current.copyWith(
                    sets: safeSets,
                    durationTracksWeight: durationTracksWeight,
                    targetDurationSeconds: targetDurationSeconds,
                    restAfterSetSeconds: restAfterSetSeconds,
                    clearRestAfterSetSeconds: restMode == 0,
                    warmupSeconds: warmupSeconds > 0 ? warmupSeconds : null,
                    clearWarmupSeconds: warmupSeconds == 0,
                  );
                  setState(() {
                    _orderedExercises[currentExerciseIndex] = updatedExercise;
                    currentDurationSeconds = targetDurationSeconds;
                    if (durationTracksWeight) {
                      final lastW = _getLastWeightForExercise(
                        current.exercise.name,
                      );
                      if (lastW != null) {
                        currentWeight = lastW;
                      } else if (currentWeight <= 0) {
                        currentWeight = updatedExercise.targetWeight;
                      }
                    } else {
                      currentWeight = 0;
                    }
                    _restPresetSeconds = List<int>.from(presetSeconds);
                  });
                  _persistExerciseToTemplate(updatedExercise);
                  unawaited(_persistExerciseToTemplateStorage(updatedExercise));
                  unawaited(_persistWorkoutDraft());
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  l10n.get('save'),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _finishWorkout() async {
    _suppressDraftSave = true;
    _draftAutosaveTimer?.cancel();
    await clearWorkoutDraftPrefs();
    workoutTimer?.cancel();
    restTimer?.cancel();

    final session = WorkoutSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      templateId: widget.template.id,
      templateName: widget.template.name,
      startTime: startTime,
      endTime: DateTime.now(),
      durationSeconds: elapsedSeconds,
      logs: logs,
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    widget.onComplete(session);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.get('workoutComplete'),
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _confirmExit() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.get('endWorkout'),
          style: const TextStyle(fontSize: 22),
        ),
        content: Text(
          l10n.get('endWorkoutConfirm'),
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (logs.isNotEmpty) {
                await _finishWorkout();
              } else {
                _suppressDraftSave = true;
                _draftAutosaveTimer?.cancel();
                await clearWorkoutDraftPrefs();
                workoutTimer?.cancel();
                restTimer?.cancel();
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              l10n.get('endNow'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  /// Elderly-friendly: large text and tap targets (min 56dp).
  void _showAddExerciseDuringWorkout() {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const double largeFont = 22;
    const double titleFont = 26;
    const double minTap = 56;

    final nameController = TextEditingController();
    int sets = 3;
    int targetReps = 10;
    double targetWeight = 0;
    bool durationBased = false;
    bool durationTracksWeight = false;
    int targetDurationSeconds = kDefaultTargetDurationSeconds;
    var restMode = 0;
    var customRestSec = 60;
    final scaffoldMessengerContext = context;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final primary = Theme.of(ctx).colorScheme.primary;

          Widget restTileEl({
            required bool selected,
            required String title,
            required String? subtitle,
            required VoidCallback onTap,
          }) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: selected
                    ? primary.withValues(alpha: isDark ? 0.28 : 0.14)
                    : (isDark ? const Color(0xFF232F3E) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          selected ? Icons.check_circle : Icons.circle_outlined,
                          size: 32,
                          color: selected ? primary : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: largeFont,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (subtitle != null && subtitle.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            title: Text(
              l10n.get('addExerciseToWorkout'),
              style: TextStyle(
                fontSize: titleFont,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top padding so floating "Exercise Name" label is not clipped when focused
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    style: TextStyle(fontSize: largeFont),
                    decoration: InputDecoration(
                      labelText: l10n.get('exerciseName'),
                      hintText: l10n.get('exerciseNameHint'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  // Elderly-friendly autocomplete (same as template editor)
                  Builder(
                    builder: (context) {
                      final suggestions = _filterExerciseSuggestions(
                        nameController.text,
                        max: 8,
                      );
                      if (suggestions.isEmpty) return const SizedBox.shrink();
                      final dialogIsDark =
                          Theme.of(context).brightness == Brightness.dark;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            l10n.get('suggestions'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: dialogIsDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...suggestions.map(
                            (name) => Material(
                              color: dialogIsDark
                                  ? const Color(0xFF232F3E)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () {
                                  nameController.text = name;
                                  setDialogState(() {});
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    l10n.localizeExerciseName(name),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                      color: dialogIsDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Sets – full-width row to avoid overflow and keep large tap targets
                  Text(
                    l10n.get('sets'),
                    style: TextStyle(
                      fontSize: largeFont,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: l10n.get('decreaseSets'),
                        onPressed: () {
                          if (sets > 1) {
                            setDialogState(() => sets--);
                          }
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                        iconSize: 36,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(minTap, minTap),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '$sets',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.get('increaseSets'),
                        onPressed: () => setDialogState(() => sets++),
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 36,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(minTap, minTap),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.get('durationBasedExercise'),
                      style: TextStyle(
                        fontSize: largeFont,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      l10n.get('durationBasedExerciseDesc'),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    value: durationBased,
                    onChanged: (v) => setDialogState(() {
                      durationBased = v;
                      if (!v) durationTracksWeight = false;
                    }),
                  ),
                  if (durationBased) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.get('durationTracksWeight'),
                        style: TextStyle(
                          fontSize: largeFont,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        l10n.get('durationTracksWeightDesc'),
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      value: durationTracksWeight,
                      onChanged: (v) =>
                          setDialogState(() => durationTracksWeight = v),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.get('holdTime'),
                      style: TextStyle(
                        fontSize: largeFont,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: l10n.get('decreaseHoldTime'),
                          onPressed: () => setDialogState(
                            () => targetDurationSeconds =
                                (targetDurationSeconds - 5).clamp(1, 86400),
                          ),
                          icon: const Icon(Icons.remove_circle_outline),
                          iconSize: 36,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(minTap, minTap),
                          ),
                        ),
                        Semantics(button: true, child: GestureDetector(
                          onTap: () => showDurationEntryDialog(
                            context: ctx,
                            l10n: l10n,
                            currentSeconds: targetDurationSeconds,
                            accentColor: primary,
                            onSave: (sec) => setDialogState(
                              () => targetDurationSeconds = sec.clamp(1, 86400),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withValues(
                                alpha: isDark ? 0.22 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: primary.withValues(alpha: 0.45),
                                width: 2,
                              ),
                            ),
                            child: Text(
                              formatDurationMmSs(targetDurationSeconds),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        )),
                        IconButton(
                          tooltip: l10n.get('increaseHoldTime'),
                          onPressed: () => setDialogState(
                            () => targetDurationSeconds =
                                (targetDurationSeconds + 5).clamp(1, 86400),
                          ),
                          icon: const Icon(Icons.add_circle_outline),
                          iconSize: 36,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(minTap, minTap),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final sec in [30, 45, 60, 90])
                          OutlinedButton(
                            onPressed: () => setDialogState(
                              () => targetDurationSeconds = sec,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              formatDurationMmSs(sec),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (!durationBased) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.get('targetReps'),
                      style: TextStyle(
                        fontSize: largeFont,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: l10n.get('decreaseReps'),
                          onPressed: () {
                            if (targetReps > 1) {
                              setDialogState(() => targetReps--);
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                          iconSize: 36,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(minTap, minTap),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '$targetReps',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.get('increaseReps'),
                          onPressed: () => setDialogState(() => targetReps++),
                          icon: const Icon(Icons.add_circle_outline),
                          iconSize: 36,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(minTap, minTap),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    l10n.get('restBetweenSetsTitle'),
                    style: TextStyle(
                      fontSize: largeFont,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.get('restBetweenSetsStretchHint'),
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  restTileEl(
                    selected: restMode == 0,
                    title: l10n.get('restOptionDefault'),
                    subtitle: l10n
                        .get('restOptionDefaultSub')
                        .replaceAll(
                          '{time}',
                          formatDurationMmSs(_defaultRestSeconds),
                        ),
                    onTap: () => setDialogState(() => restMode = 0),
                  ),
                  restTileEl(
                    selected: restMode == 1,
                    title: l10n.get('restOptionNoRest'),
                    subtitle: l10n.get('restOptionNoRestSub'),
                    onTap: () => setDialogState(() => restMode = 1),
                  ),
                  restTileEl(
                    selected: restMode == 2,
                    title: l10n.get('restOptionCustom'),
                    subtitle: l10n.get('restOptionCustomSub'),
                    onTap: () => setDialogState(() => restMode = 2),
                  ),
                  if (restMode == 2) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: l10n.get('decreaseRest'),
                          onPressed: customRestSec <= 30
                              ? null
                              : () => setDialogState(
                                  () => customRestSec = (customRestSec - 30)
                                      .clamp(30, 600),
                                ),
                          icon: const Icon(Icons.remove_circle_outline),
                          iconSize: 36,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(minTap, minTap),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            formatDurationMmSs(customRestSec),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.get('increaseRest'),
                          onPressed: customRestSec >= 600
                              ? null
                              : () => setDialogState(
                                  () => customRestSec = (customRestSec + 30)
                                      .clamp(30, 600),
                                ),
                          icon: const Icon(Icons.add_circle_outline),
                          iconSize: 36,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(minTap, minTap),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  l10n.cancel,
                  style: const TextStyle(fontSize: largeFont),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(scaffoldMessengerContext).showSnackBar(
                      SnackBar(
                        content: Text(l10n.get('enterExerciseName')),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  final exercise = Exercise(
                    id: 'ex_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameController.text.trim(),
                    description: null,
                    iconKey: kExerciseIconKeys.first,
                  );
                  final newTe = TemplateExercise(
                    exercise: exercise,
                    targetReps: durationBased ? 0 : targetReps,
                    targetWeight: targetWeight,
                    sets: sets,
                    durationBased: durationBased,
                    durationTracksWeight: durationBased && durationTracksWeight,
                    targetDurationSeconds: durationBased
                        ? targetDurationSeconds
                        : null,
                    restAfterSetSeconds: restAfterSetFromTemplateDialog(
                      restMode,
                      customRestSec,
                    ),
                  );
                  Navigator.pop(ctx);

                  _showWhereToAddExercise(newTe, l10n, isDark);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
                child: Text(
                  l10n.get('save'),
                  style: const TextStyle(fontSize: largeFont),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showWhereToAddExercise(
    TemplateExercise newTe,
    AppLocalizations l10n,
    bool isDark,
  ) {
    const double largeFont = 22;
    const double minTap = 56;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.get('whereToAddExercise'),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: minTap + 8,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _orderedExercises.add(newTe);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                ),
                child: Center(
                  child: Text(
                    l10n.get('addToThisWorkoutOnly'),
                    style: const TextStyle(
                      fontSize: largeFont,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 96,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _orderedExercises.add(newTe);
                  });
                  widget.onUpdateTemplate?.call(
                    widget.template.copyWith(
                      exercises: [...widget.template.exercises, newTe],
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  side: BorderSide(color: Colors.orange.shade600, width: 2),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                ),
                child: Center(
                  child: Text(
                    l10n.get('addToWorkoutTemplate'),
                    style: const TextStyle(
                      fontSize: largeFont,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    softWrap: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Persist exercise interval-setting changes from this workout back to
  /// template storage so the next workout starts with these values.
  void _persistExerciseToTemplate(TemplateExercise updatedExercise) {
    final onUpdate = widget.onUpdateTemplate;
    if (onUpdate == null) return;
    final updatedTemplateExercises = widget.template.exercises
        .map(
          (te) => te.exercise.id == updatedExercise.exercise.id
              ? updatedExercise
              : te,
        )
        .toList();
    onUpdate(widget.template.copyWith(exercises: updatedTemplateExercises));
  }

  Future<void> _persistExerciseToTemplateStorage(
    TemplateExercise updatedExercise,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('workout_templates');
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      final storedTemplates = decoded
          .map((e) => WorkoutTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
      final templateIndex = storedTemplates.indexWhere(
        (t) => t.id == widget.template.id,
      );
      if (templateIndex == -1) return;

      final storedTemplate = storedTemplates[templateIndex];
      final patchedExercises = storedTemplate.exercises
          .map(
            (te) => te.exercise.id == updatedExercise.exercise.id
                ? updatedExercise
                : te,
          )
          .toList();

      storedTemplates[templateIndex] = storedTemplate.copyWith(
        exercises: patchedExercises,
      );
      await prefs.setString(
        'workout_templates',
        jsonEncode(storedTemplates.map((t) => t.toJson()).toList()),
      );
    } catch (_) {
      // Ignore persistence errors; in-memory callback update still applies.
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = _orderedExercises[currentExerciseIndex];
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmExit();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            (_orderedExercises.isNotEmpty &&
                    currentExerciseIndex >= 0 &&
                    currentExerciseIndex < _orderedExercises.length)
                ? l10n.localizeExerciseName(
                    _orderedExercises[currentExerciseIndex].exercise.name,
                  )
                : l10n.localizeWorkoutTemplateName(widget.template.name),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            onPressed: _confirmExit,
            icon: const Icon(Icons.close, size: 28),
            tooltip: l10n.get('endWorkoutButton'),
          ),
          actions: [
            // Workout duration timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.primary.withValues(alpha: 0.3)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer,
                    size: 24,
                    color: isDark ? Colors.white : colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(elapsedSeconds),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: isResting
              ? (_viewingPlanDuringRest
                    ? _buildPlanViewDuringRest(l10n, current)
                    : _buildRestScreen(l10n, current))
              : _buildExerciseScreen(l10n, current),
        ),
      ),
    );
  }

  /// Planned timed sets still to finish (uses logged count; set is logged when rest begins).
  int _durationPlannedSetsRemaining(TemplateExercise current) {
    if (!current.durationBased) return 0;
    final logged = logs
        .where((l) => l.exerciseId == current.exercise.id)
        .length;
    return (current.sets - logged).clamp(0, 9999);
  }

  /// Compact bar shown at top when viewing workout plan during rest; timer keeps running.
  Widget _buildRestBar(AppLocalizations l10n, TemplateExercise current) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final showSetsInline =
        current.durationBased && !_durationSessionInWork && isResting;
    final setsN = _durationPlannedSetsRemaining(current);
    return Material(
      elevation: 2,
      child: Container(
        color: isDark ? const Color(0xFF1A2634) : Colors.white,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 28,
                  color: restSeconds <= 10 ? Colors.red : colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Semantics(button: true, child: GestureDetector(
                  onTap: () => showDurationEntryDialog(
                    context: context,
                    l10n: l10n,
                    currentSeconds: restSeconds,
                    accentColor: colorScheme.primary,
                    onSave: (sec) =>
                        setState(() => restSeconds = sec.clamp(0, 600)),
                  ),
                  child: Text(
                    formatDurationMmSs(restSeconds),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: restSeconds <= 10
                          ? Colors.red
                          : colorScheme.primary,
                    ),
                  ),
                )),
                if (showSetsInline) ...[
                  const SizedBox(width: 12),
                  Text(
                    '$setsN',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : colorScheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                const Spacer(),
                FilledButton.icon(
                  onPressed: () =>
                      setState(() => _viewingPlanDuringRest = false),
                  icon: const Icon(Icons.timer, size: 20),
                  label: Text(l10n.get('backToRestTimer')),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanViewDuringRest(
    AppLocalizations l10n,
    TemplateExercise current,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRestBar(l10n, current),
        Expanded(
          child: _buildExerciseScreen(
            l10n,
            current,
            allowTapToJumpDuringRest: true,
          ),
        ),
      ],
    );
  }

  Widget _buildRestScreen(AppLocalizations l10n, TemplateExercise current) {
    // Elderly-friendly: large text, large touch targets (min 56–64dp)
    const double largeFontSize = 28;
    const double timerFontSize = 96;
    const double buttonFontSize = 22;
    const double minTapHeight = 64;

    final showSetsInline =
        current.durationBased && !_durationSessionInWork && isResting;
    final setsN = _durationPlannedSetsRemaining(current);
    final restCountdownActive =
        isResting && restSeconds > 0 && (restTimer?.isActive ?? false);
    final restCountdownPausedUi =
        isResting &&
        restSeconds > 0 &&
        ((current.durationBased && !_durationSessionRunning) ||
            (!current.durationBased && _restCountdownPaused));
    final mqSize = MediaQuery.sizeOf(context);
    final setsRemainingFontSize = (mqSize.shortestSide * 0.16).clamp(
      72.0,
      108.0,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.get('rest'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: largeFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (showSetsInline) ...[
                        const SizedBox(height: 20),
                        Text(
                          '$setsN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: setsRemainingFontSize,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            color: isDark ? Colors.white : colorScheme.primary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.get(
                            setsN == 1
                                ? 'setRemainingLabelSingular'
                                : 'setsRemainingLabel',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Semantics(button: true, child: GestureDetector(
                        onTap: () => showDurationEntryDialog(
                          context: context,
                          l10n: l10n,
                          currentSeconds: restSeconds,
                          accentColor: Colors.blue,
                          onSave: (sec) =>
                              setState(() => restSeconds = sec.clamp(0, 600)),
                        ),
                        child: Center(
                          child: Text(
                            formatDurationMmSs(restSeconds),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: timerFontSize,
                              fontWeight: FontWeight.bold,
                              // Original rest timer colors: blue, turns red at 10s.
                              color: restSeconds <= 10
                                  ? Colors.red
                                  : Colors.blue,
                            ),
                          ),
                        ),
                      )),
                      if (restCountdownActive || restCountdownPausedUi) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: FilledButton(
                              onPressed: () {
                                if (restCountdownActive) {
                                  if (current.durationBased) {
                                    _pauseDurationSession();
                                  } else {
                                    _pauseRestCountdown();
                                  }
                                } else {
                                  if (current.durationBased) {
                                    _resumeDurationSession();
                                  } else {
                                    _resumeRestCountdown();
                                  }
                                }
                              },
                              style: FilledButton.styleFrom(
                                shape: const CircleBorder(),
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.18,
                                ),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                              ),
                              child: Icon(
                                restCountdownActive
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                size: 34,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                      // +30 / −30 sec row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 140,
                            height: minTapHeight,
                            child: ElevatedButton(
                              onPressed: () => _subtractRestSeconds(30),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                l10n.get('subtract30Seconds'),
                                style: const TextStyle(
                                  fontSize: buttonFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 140,
                            height: minTapHeight,
                            child: ElevatedButton(
                              onPressed: () => _addRestSeconds(30),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                l10n.get('add30Seconds'),
                                style: const TextStyle(
                                  fontSize: buttonFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: 260,
                        height: minTapHeight,
                        child: ElevatedButton(
                          onPressed: _skipRest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            l10n.get('skipRest'),
                            style: const TextStyle(
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 260,
                        height: minTapHeight,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _viewingPlanDuringRest = true),
                          icon: const Icon(Icons.list, size: 24),
                          label: Text(
                            l10n.get('viewWorkoutPlan'),
                            style: const TextStyle(
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                            side: BorderSide(
                              color: Colors.blue.shade700,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Finish workout – always available during rest, elderly-friendly
                      SizedBox(
                        width: 260,
                        height: minTapHeight,
                        child: OutlinedButton.icon(
                          onPressed: () => unawaited(_finishWorkout()),
                          icon: const Icon(Icons.flag, size: 26),
                          label: Text(
                            l10n.get('finishWorkout'),
                            style: const TextStyle(
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade700,
                            side: BorderSide(
                              color: Colors.orange.shade600,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseScreen(
    AppLocalizations l10n,
    TemplateExercise current, {
    bool allowTapToJumpDuringRest = false,
  }) {
    final completedExerciseIds = <String>{};
    for (final exercise in _orderedExercises) {
      final loggedSetsCount = logs
          .where((log) => log.exerciseId == exercise.exercise.id)
          .length;
      if (loggedSetsCount >= exercise.sets) {
        completedExerciseIds.add(exercise.exercise.id);
      }
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inDurationWarmup =
        current.durationBased && _warmupSecondsRemaining > 0 && !isResting;
    final inActiveWorkHold =
        current.durationBased &&
        !inDurationWarmup &&
        _durationSessionInWork &&
        _workSecondsRemaining > 0;
    final inLargeDurationCountdown = inDurationWarmup || inActiveWorkHold;
    final mqSize = MediaQuery.sizeOf(context);
    final largeDurationCountdownFontSize = (mqSize.shortestSide * 0.29).clamp(
      104.0,
      172.0,
    );

    return SingleChildScrollView(
      controller: _exerciseScrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            explicitChildNodes: true,
            sortKey: const OrdinalSortKey(0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.primary.withValues(alpha: 0.3)
                        : colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${l10n.get('exercise')} ${currentExerciseIndex + 1}/${_orderedExercises.length}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        current.durationBased
                            ? (currentSet <= current.sets
                                  ? '${l10n.get('set')} $currentSet/${current.sets}'
                                  : '${l10n.get('set')} $currentSet')
                            : '${l10n.get('set')} ${logs.where((l) => l.exerciseId == current.exercise.id).length}/${_pendingSetWeights[current.exercise.id]?.length ?? current.sets}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Current exercise
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A2634) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.grey.shade300,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        current.exercise.icon,
                        size: 60,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              l10n.localizeExerciseName(current.exercise.name),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: l10n.get('pastHistory'),
                            child: Material(
                              color: (isDark ? Colors.white : Colors.black87)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(24),
                              child: InkWell(
                                onTap: () => _showPastHistoryBottomSheet(
                                  context,
                                  current.exercise,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.history,
                                    size: 24,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Show previous best (reps or hold time) if available
                      if (!current.durationBased &&
                          previousBestReps.containsKey(
                            current.exercise.name,
                          )) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.green.shade900
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history,
                                size: 20,
                                color: isDark
                                    ? Colors.green.shade300
                                    : Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${l10n.get('previousBest')}: ${previousBestReps[current.exercise.name]} ${l10n.reps}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.green.shade300
                                      : Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (current.durationBased &&
                          previousBestDurationSeconds.containsKey(
                            current.exercise.name,
                          )) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.green.shade900
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history,
                                size: 20,
                                color: isDark
                                    ? Colors.green.shade300
                                    : Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${l10n.get('previousBestDuration')}: ${formatDurationMmSs(previousBestDurationSeconds[current.exercise.name]!)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.green.shade300
                                      : Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (current.exercise.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          current.exercise.description!,
                          style: TextStyle(
                            fontSize: 18,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            container: true,
            explicitChildNodes: true,
            sortKey: const OrdinalSortKey(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Workout plan overview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A2634) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.get('workoutPlan'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ExcludeSemantics(
                        child: Text(
                          l10n.get('tapToJump'),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      ExcludeSemantics(
                        child: Text(
                          l10n.get('longPressToReorder'),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Add exercise during workout – elderly-friendly (large tap target)
                      if (!isResting)
                        SizedBox(
                          height: 64,
                          child: OutlinedButton.icon(
                            onPressed: _showAddExerciseDuringWorkout,
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 28,
                            ),
                            label: Text(
                              l10n.get('addExerciseToWorkout'),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                              side: BorderSide(
                                color: colorScheme.primary,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      if (!isResting) const SizedBox(height: 12),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _orderedExercises.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _orderedExercises.removeAt(oldIndex);
                            _orderedExercises.insert(newIndex, item);
                            if (currentExerciseIndex == oldIndex) {
                              currentExerciseIndex = newIndex;
                            } else if (oldIndex < currentExerciseIndex) {
                              if (newIndex > currentExerciseIndex - 1) {
                                currentExerciseIndex--;
                              }
                            } else if (newIndex <= currentExerciseIndex) {
                              currentExerciseIndex++;
                            }
                          });
                          unawaited(_persistExerciseOrderToTemplateStorage());
                        },
                        itemBuilder: (context, index) {
                          final exercise = _orderedExercises[index];
                          final isCurrent =
                              exercise.exercise.id == current.exercise.id;
                          final isCompleted = completedExerciseIds.contains(
                            exercise.exercise.id,
                          );
                          final isAvailable =
                              !isResting || allowTapToJumpDuringRest;
                          final loggedSetsCount = logs
                              .where(
                                (l) => l.exerciseId == exercise.exercise.id,
                              )
                              .length;
                          final displayedSets = loggedSetsCount > exercise.sets
                              ? loggedSetsCount
                              : exercise.sets;
                          return Padding(
                            key: ValueKey(exercise.exercise.id),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: KeyedSubtree(
                              key: _globalKeyForPlanRow(exercise.exercise.id),
                              child: Semantics(
                                button: true,
                                selected: isCurrent,
                                label:
                                    '${l10n.localizeExerciseName(exercise.exercise.name)}, $displayedSets ${l10n.get('sets')}${exercise.durationBased ? '' : ' × ${exercise.targetReps} ${l10n.reps}'}'
                                    '${isCurrent ? ', ${l10n.get('current')}' : ''}'
                                    '${isCompleted ? ', ${l10n.get('completedSets')}' : ''}',
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: isAvailable
                                        ? () {
                                            final wasResting = isResting;
                                            setState(() {
                                              currentExerciseIndex = index;
                                              final exercise =
                                                  _orderedExercises[index];
                                              // If user is browsing the plan during an active rest,
                                              // keep the rest countdown running.
                                              _stopDurationSession(
                                                clearRest: !wasResting,
                                              );
                                              final loggedForExercise = logs
                                                  .where(
                                                    (l) =>
                                                        l.exerciseId ==
                                                        exercise.exercise.id,
                                                  )
                                                  .length;
                                              currentSet =
                                                  loggedForExercise + 1;
                                              _initializeCurrentExercise();
                                            });
                                            if (!wasResting) {
                                              _scrollRepsSetsSectionIntoView();
                                            }
                                          }
                                        : null,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isCurrent
                                            ? (isDark
                                                  ? colorScheme.primary
                                                        .withValues(alpha: 0.3)
                                                  : colorScheme.primary
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ))
                                            : (isDark
                                                  ? const Color(0xFF232F3E)
                                                  : Colors.grey.shade100),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isCurrent
                                              ? colorScheme.primary
                                              : (isDark
                                                    ? Colors.grey.shade700
                                                    : Colors.grey.shade300),
                                          width: isCurrent ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.drag_handle,
                                            color: isDark
                                                ? Colors.grey.shade500
                                                : Colors.grey.shade600,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            isCompleted
                                                ? Icons.check_circle
                                                : Icons.radio_button_unchecked,
                                            color: isCompleted
                                                ? Colors.green.shade600
                                                : (isDark
                                                      ? Colors.grey.shade400
                                                      : Colors.grey.shade500),
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  l10n.localizeExerciseName(
                                                    exercise.exercise.name,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                ),
                                                Text(
                                                  exercise.durationBased
                                                      ? (exercise.durationTracksWeight &&
                                                                exercise.targetWeight >
                                                                    0
                                                            ? '$displayedSets ${l10n.get('sets')} · ${_formatWeightDisplay(exercise.targetWeight)} ${_weightUnit == 'lbs' ? l10n.get('weightShortLbs') : l10n.get('weightShort')}'
                                                            : '$displayedSets ${l10n.get('sets')}')
                                                      : '$displayedSets ${l10n.get('sets')} × ${exercise.targetReps} ${l10n.reps}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: isDark
                                                        ? Colors.grey.shade400
                                                        : Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => unawaited(
                                              _showExerciseNotesDialog(
                                                l10n,
                                                exercise,
                                              ),
                                            ),
                                            icon: Icon(
                                              (_exerciseNotesByExerciseId[exercise
                                                              .exercise
                                                              .id] ??
                                                          '')
                                                      .trim()
                                                      .isEmpty
                                                  ? Icons.note_alt_outlined
                                                  : Icons.note_alt,
                                              color: isDark
                                                  ? Colors.grey.shade200
                                                  : Colors.grey.shade700,
                                              size: 26,
                                            ),
                                            tooltip: l10n.get('notes'),
                                          ),
                                          if (isCurrent)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: colorScheme.primary,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                l10n.get('current'),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            container: true,
            explicitChildNodes: true,
            sortKey: const OrdinalSortKey(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                KeyedSubtree(
                  key: _repsSetsSectionKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (current.durationBased &&
                          current.showsWeightInWorkout) ...[
                        // Weight (timed + weight e.g. farmer's carry). Plain strength
                        // exercises get weight inline in _buildSetRowsSection instead.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1A2634)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              _LargeRoundButton(
                                label: l10n.get('decreaseWeight'),
                                icon: Icons.remove,
                                color: Colors.orange.shade400,
                                onPressed: currentWeight > 0
                                    ? () => _adjustCurrentWeight(-_weightStepKg)
                                    : null,
                              ),
                              Expanded(
                                child: Semantics(button: true, child: GestureDetector(
                                  onTap: () => _showNumberInputDialog(
                                    context: context,
                                    title:
                                        _isAssistedPullUp(current.exercise.name)
                                        ? (_weightUnit == 'lbs'
                                              ? l10n.get('minusWeightLbs')
                                              : l10n.get('minusWeightKg'))
                                        : (_weightUnit == 'lbs'
                                              ? l10n.get('weightLbs')
                                              : l10n.get('weight')),
                                    currentValue: _kgToDisplay(currentWeight),
                                    isInteger: false,
                                    accentColor: Colors.orange,
                                    onSave: (value) => setState(
                                      () => currentWeight = _displayToKg(value),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        _isAssistedPullUp(current.exercise.name)
                                            ? (_weightUnit == 'lbs'
                                                  ? l10n.get('minusWeightLbs')
                                                  : l10n.get('minusWeightKg'))
                                            : (_weightUnit == 'lbs'
                                                  ? l10n.get('weightLbs')
                                                  : l10n.get('weight')),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.orange.withValues(
                                                  alpha: 0.2,
                                                )
                                              : Colors.orange.withValues(
                                                  alpha: 0.1,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: Colors.orange.withValues(
                                              alpha: 0.5,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                        child: Text(
                                          _formatWeightDisplay(currentWeight),
                                          style: TextStyle(
                                            fontSize: 42,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _WeightUnitSegmentedToggle(
                                        selectedUnit: _weightUnit,
                                        kgLabel: l10n.get('weightShort'),
                                        lbsLabel: l10n.get('weightShortLbs'),
                                        onUnitSelected: (unit) =>
                                            unawaited(_setWeightUnit(unit)),
                                        isDark: isDark,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n.get('tapToEdit'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.grey.shade500
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ),
                              _LargeRoundButton(
                                label: l10n.get('increaseWeight'),
                                icon: Icons.add,
                                color: Colors.green.shade400,
                                onPressed: () =>
                                    _adjustCurrentWeight(_weightStepKg),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!current.durationBased) ...[
                        const SizedBox(height: 12),
                        _buildSetRowsSection(l10n, current),
                      ],
                      if (current.durationBased) ...[
                        if (current.durationTracksWeight)
                          const SizedBox(height: 12),
                        // Hold / carry time (elderly-friendly: large timer, presets, tap to type m:ss)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(
                            horizontal: inLargeDurationCountdown ? 12 : 16,
                            vertical: inLargeDurationCountdown ? 22 : 16,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1A2634)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: inLargeDurationCountdown
                                ? Border.all(
                                    color: inDurationWarmup
                                        ? Colors.amber.withValues(alpha: 0.65)
                                        : colorScheme.primary.withValues(
                                            alpha: 0.55,
                                          ),
                                    width: 3,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: inLargeDurationCountdown
                                    ? (inDurationWarmup
                                          ? Colors.amber.withValues(alpha: 0.12)
                                          : colorScheme.primary.withValues(
                                              alpha: 0.12,
                                            ))
                                    : Colors.black.withValues(alpha: 0.05),
                                blurRadius: inLargeDurationCountdown ? 18 : 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      inDurationWarmup
                                          ? l10n.get('warmup')
                                          : l10n.get('holdTime'),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: inLargeDurationCountdown
                                            ? 22
                                            : 18,
                                        fontWeight: FontWeight.w700,
                                        color: inDurationWarmup
                                            ? (isDark
                                                  ? Colors.amber.shade200
                                                  : Colors.amber.shade900)
                                            : inActiveWorkHold
                                            ? colorScheme.primary
                                            : (isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: l10n.get('settings'),
                                    onPressed: isResting || inDurationWarmup
                                        ? null
                                        : _showDurationExerciseSettingsDialog,
                                    icon: Icon(
                                      Icons.settings,
                                      size: 26,
                                      color: (isResting || inDurationWarmup)
                                          ? (isDark
                                                ? Colors.grey.shade600
                                                : Colors.grey.shade400)
                                          : colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Semantics(button: true, child: GestureDetector(
                                onTap: _durationSessionRunning
                                    ? null
                                    : () => showDurationEntryDialog(
                                        context: context,
                                        l10n: l10n,
                                        currentSeconds: currentDurationSeconds,
                                        accentColor: colorScheme.primary,
                                        onSave: (sec) {
                                          setState(() {
                                            currentDurationSeconds = sec;
                                            final cur =
                                                _orderedExercises[currentExerciseIndex];
                                            _orderedExercises[currentExerciseIndex] =
                                                cur.copyWith(
                                                  targetDurationSeconds:
                                                      currentDurationSeconds,
                                                );
                                          });
                                          unawaited(_persistWorkoutDraft());
                                        },
                                      ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 320,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: inLargeDurationCountdown
                                            ? 4
                                            : 16,
                                        vertical: inLargeDurationCountdown
                                            ? 22
                                            : 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: inDurationWarmup
                                            ? (isDark
                                                  ? Colors.amber.withValues(
                                                      alpha: 0.16,
                                                    )
                                                  : Colors.amber.withValues(
                                                      alpha: 0.1,
                                                    ))
                                            : inActiveWorkHold
                                            ? (isDark
                                                  ? colorScheme.primary
                                                        .withValues(alpha: 0.28)
                                                  : colorScheme.primary
                                                        .withValues(
                                                          alpha: 0.14,
                                                        ))
                                            : (isDark
                                                  ? colorScheme.primary
                                                        .withValues(alpha: 0.2)
                                                  : colorScheme.primary
                                                        .withValues(
                                                          alpha: 0.1,
                                                        )),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: inDurationWarmup
                                              ? Colors.amber.withValues(
                                                  alpha: 0.65,
                                                )
                                              : inActiveWorkHold &&
                                                    _workSecondsRemaining <= 3
                                              ? Colors.deepOrange.withValues(
                                                  alpha: 0.85,
                                                )
                                              : colorScheme.primary.withValues(
                                                  alpha: 0.5,
                                                ),
                                          width: inLargeDurationCountdown
                                              ? 3
                                              : 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.center,
                                          child: AnimatedDefaultTextStyle(
                                            duration: const Duration(
                                              milliseconds: 280,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            style: TextStyle(
                                              fontSize: inLargeDurationCountdown
                                                  ? largeDurationCountdownFontSize
                                                  : 42,
                                              fontWeight: FontWeight.w800,
                                              height: 1.05,
                                              letterSpacing:
                                                  inLargeDurationCountdown
                                                  ? 1.5
                                                  : 0,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                              color: inDurationWarmup
                                                  ? (isDark
                                                        ? Colors.amber.shade100
                                                        : Colors.amber.shade900)
                                                  : inActiveWorkHold &&
                                                        _workSecondsRemaining <=
                                                            3
                                                  ? (isDark
                                                        ? Colors
                                                              .deepOrange
                                                              .shade200
                                                        : Colors
                                                              .deepOrange
                                                              .shade800)
                                                  : (isDark
                                                        ? Colors.white
                                                        : colorScheme.primary),
                                            ),
                                            child: Text(
                                              formatDurationMmSs(
                                                inDurationWarmup
                                                    ? _warmupSecondsRemaining
                                                    : (_durationSessionInWork &&
                                                              _workSecondsRemaining >
                                                                  0
                                                          ? _workSecondsRemaining
                                                          : currentDurationSeconds),
                                              ),
                                              maxLines: 1,
                                              softWrap: false,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: inLargeDurationCountdown ? 10 : 4,
                                    ),
                                    Text(
                                      inDurationWarmup
                                          ? l10n.get('warmupSubtitle')
                                          : inActiveWorkHold
                                          ? l10n.get('holdTimeRemaining')
                                          : l10n.get('tapToEdit'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: inLargeDurationCountdown
                                            ? 15
                                            : 12,
                                        fontWeight: inLargeDurationCountdown
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: inDurationWarmup
                                            ? (isDark
                                                  ? Colors.amber.shade300
                                                  : Colors.amber.shade800)
                                            : inActiveWorkHold
                                            ? (isDark
                                                  ? Colors.grey.shade300
                                                  : Colors.grey.shade700)
                                            : (isDark
                                                  ? Colors.grey.shade500
                                                  : Colors.grey.shade500),
                                      ),
                                    ),
                                    if (inActiveWorkHold &&
                                        !inDurationWarmup &&
                                        current.durationBased)
                                      Builder(
                                        builder: (context) {
                                          final durationSetsRemaining =
                                              _durationPlannedSetsRemaining(
                                                current,
                                              );
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 16,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.baseline,
                                              textBaseline:
                                                  TextBaseline.alphabetic,
                                              children: [
                                                Text(
                                                  '$durationSetsRemaining',
                                                  style: TextStyle(
                                                    fontSize:
                                                        (mqSize.shortestSide *
                                                                0.11)
                                                            .clamp(42.0, 58.0),
                                                    fontWeight: FontWeight.w800,
                                                    height: 1.05,
                                                    color: Colors.white,
                                                    fontFeatures: const [
                                                      FontFeature.tabularFigures(),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  l10n.get(
                                                    durationSetsRemaining == 1
                                                        ? 'setRemainingLabelSingular'
                                                        : 'setsRemainingLabel',
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.92,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Primary action button (duration-based sessions only; strength sets
                // are logged per-row via the ticks in _buildSetRowsSection)
                if (current.durationBased)
                  SizedBox(
                    height: 70,
                    child: ElevatedButton.icon(
                      onPressed: currentDurationSeconds > 0
                          ? () {
                              if (_durationSessionRunning) {
                                _pauseDurationSession();
                              } else if (_workSecondsRemaining > 0 ||
                                  restSeconds > 0 ||
                                  _warmupSecondsRemaining > 0) {
                                _resumeDurationSession();
                              } else {
                                _startDurationSession();
                              }
                            }
                          : null,
                      icon: Icon(
                        _durationSessionRunning
                            ? Icons.pause
                            : Icons.play_arrow,
                        size: 30,
                      ),
                      label: Text(
                        _durationSessionRunning
                            ? l10n.get('pause')
                            : (_workSecondsRemaining > 0 ||
                                      restSeconds > 0 ||
                                      _warmupSecondsRemaining > 0
                                  ? l10n.get('resumeWorkout')
                                  : l10n.get('startWorkout')),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
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
                if (current.durationBased &&
                    !_durationSessionRunning &&
                    _workSecondsRemaining == 0 &&
                    restSeconds == 0 &&
                    _warmupSecondsRemaining == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: currentDurationSeconds > 0
                            ? _logDurationSetAlreadyCompleted
                            : null,
                        icon: const Icon(Icons.check_circle_outline, size: 24),
                        label: Text(
                          l10n.get('alreadyCompleted'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.teal.shade200
                              : Colors.teal.shade700,
                          side: BorderSide(
                            color: isDark
                                ? Colors.teal.shade300
                                : Colors.teal.shade400,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (current.durationBased &&
                    (_durationSessionRunning ||
                        _workSecondsRemaining > 0 ||
                        restSeconds > 0 ||
                        _warmupSecondsRemaining > 0))
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          if (_durationSessionInWork &&
                              (_workSecondsRemaining > 0 ||
                                  _workPhaseDurationSeconds > 0)) {
                            _finishCurrentDurationWorkPhase();
                            return;
                          }
                          if (isResting && _pendingDurationLogSeconds != null) {
                            restTimer?.cancel();
                            restTimer = null;
                            _onDurationRestFinished();
                            return;
                          }
                          setState(() {
                            _stopDurationSession(clearRest: true);
                          });
                          unawaited(_persistWorkoutDraft());
                        },
                        icon: const Icon(Icons.stop_circle_outlined, size: 26),
                        label: Text(
                          (_durationSessionInWork &&
                                  (_workSecondsRemaining > 0 ||
                                      _workPhaseDurationSeconds > 0))
                              ? l10n.get('endSetEarly')
                              : l10n.get('endNow'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                // Next exercise – move on when done (or after extra sets); elderly-friendly
                if (currentExerciseIndex < _orderedExercises.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      height: 64,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _stopDurationSession(clearRest: true);
                            currentExerciseIndex++;
                            final exercise =
                                _orderedExercises[currentExerciseIndex];
                            final loggedForExercise = logs
                                .where(
                                  (l) => l.exerciseId == exercise.exercise.id,
                                )
                                .length;
                            currentSet = loggedForExercise + 1;
                            _initializeCurrentExercise();
                          });
                        },
                        icon: const Icon(Icons.skip_next, size: 28),
                        label: Text(
                          l10n.get('nextExercise'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          side: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Finish workout – always visible, elderly-friendly (large tap target)
                SizedBox(
                  height: 64,
                  child: OutlinedButton.icon(
                    onPressed: () => unawaited(_finishWorkout()),
                    icon: const Icon(Icons.flag, size: 28),
                    label: Text(
                      l10n.get('finishWorkout'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? Colors.orange.shade300
                          : Colors.orange.shade700,
                      side: BorderSide(
                        color: isDark
                            ? Colors.orange.shade400
                            : Colors.orange.shade600,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Logged sets for this exercise (duration-based only; strength sets
                // show their completed state inline in _buildSetRowsSection)
                if (current.durationBased &&
                    logs
                        .where((l) => l.exerciseId == current.exercise.id)
                        .isNotEmpty) ...[
                  Text(
                    l10n.get('completedSets'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (current.durationTracksWeight)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.get('tapToEditWeight'),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  for (
                    var logIndex = 0;
                    logIndex < logs.length;
                    logIndex++
                  ) ...[
                    if (logs[logIndex].exerciseId == current.exercise.id) ...[
                      Builder(
                        builder: (context) {
                          final log = logs[logIndex];
                          final setDetail = _formatLogSetDetail(
                            l10n,
                            log,
                            exerciseName: current.exercise.name,
                          );
                          final canEditWeight = current.durationTracksWeight;
                          final row = Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: isDark
                                    ? Colors.green.shade400
                                    : Colors.green.shade600,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${l10n.localizeExerciseName(current.exercise.name)} ${l10n.get('set')} ${log.setNumber}: $setDetail',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              if (canEditWeight)
                                Icon(
                                  Icons.edit_outlined,
                                  size: 22,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                ),
                            ],
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: isDark
                                  ? Colors.green.shade900.withValues(alpha: 0.4)
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: canEditWeight
                                    ? () => _editCompletedSetWeight(
                                        l10n,
                                        log,
                                        logIndex,
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.green.shade700
                                          : Colors.green.shade300,
                                      width: canEditWeight ? 2 : 1,
                                    ),
                                  ),
                                  child: row,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// All set rows for a strength (non-duration-based) exercise: one row per
  /// planned set, pre-filled from history, plus an "Add Set" affordance.
  Widget _buildSetRowsSection(AppLocalizations l10n, TemplateExercise current) {
    _ensureRowCache(current);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final id = current.exercise.id;
    final weights = _pendingSetWeights[id]!;
    final reps = _pendingSetReps[id]!;
    final edited = _pendingSetEdited[id]!;
    final rowCount = weights.length;
    final loggedBySetNumber = <int, ExerciseLog>{
      for (final log in logs.where((l) => l.exerciseId == id))
        log.setNumber: log,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _WeightUnitSegmentedToggle(
            selectedUnit: _weightUnit,
            kgLabel: l10n.get('weightShort'),
            lbsLabel: l10n.get('weightShortLbs'),
            onUnitSelected: (unit) => unawaited(_setWeightUnit(unit)),
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 14),
        for (var setNumber = 1; setNumber <= rowCount; setNumber++) ...[
          _buildSetRow(
            l10n,
            current,
            setNumber: setNumber,
            loggedEntry: loggedBySetNumber[setNumber],
            pendingWeight: weights[setNumber - 1],
            pendingReps: reps[setNumber - 1],
            isEdited: edited[setNumber - 1],
            isDark: isDark,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => _addExtraSetRow(current),
            icon: const Icon(Icons.add, size: 22),
            label: Text(
              l10n.get('addSet'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// One set row: weight + reps (tap either to edit), and a tick on the right
  /// that logs the row's current values and starts rest. Once logged, the row
  /// switches to a completed look (matching the app's existing green-tinted
  /// completed-set style) and its values/tick reflect the actual logged set.
  Widget _buildSetRow(
    AppLocalizations l10n,
    TemplateExercise current, {
    required int setNumber,
    required ExerciseLog? loggedEntry,
    required double pendingWeight,
    required int pendingReps,
    required bool isEdited,
    required bool isDark,
    required ColorScheme colorScheme,
  }) {
    final id = current.exercise.id;
    final log = loggedEntry;
    final isCompleted = log != null;
    final displayWeight = log?.weight ?? pendingWeight;
    final displayReps = log?.reps ?? pendingReps;
    final weightLabel = _isAssistedPullUp(current.exercise.name)
        ? (_weightUnit == 'lbs'
              ? l10n.get('minusWeightLbs')
              : l10n.get('minusWeightKg'))
        : (_weightUnit == 'lbs' ? l10n.get('weightLbs') : l10n.get('weight'));

    Color valueColor() {
      if (isCompleted) return isDark ? Colors.white : Colors.green.shade800;
      if (isEdited) return isDark ? Colors.white : Colors.black87;
      return isDark ? Colors.grey.shade500 : Colors.grey.shade500;
    }

    Widget valueBox({
      required String label,
      required String valueText,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: Semantics(
          button: true,
          excludeSemantics: true,
          label: '$label, $valueText',
          hint: l10n.get('tapToEdit'),
          onTap: onTap,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.transparent
                        : (isDark
                              ? Colors.black.withValues(alpha: 0.18)
                              : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: isCompleted
                        ? null
                        : Border.all(
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                  ),
                  child: Text(
                    valueText,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: valueColor(),
                      fontStyle: (!isCompleted && !isEdited)
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    void editWeight() {
      if (isCompleted) {
        final logIndex = logs.indexWhere(
          (l) => l.exerciseId == id && l.setNumber == setNumber,
        );
        if (logIndex != -1) {
          _editCompletedSetWeight(l10n, logs[logIndex], logIndex);
        }
        return;
      }
      _showNumberInputDialog(
        context: context,
        title: weightLabel,
        currentValue: _kgToDisplay(pendingWeight),
        isInteger: false,
        accentColor: Colors.orange,
        onSave: (value) => setState(() {
          _pendingSetWeights[id]![setNumber - 1] = _displayToKg(value);
          _pendingSetEdited[id]![setNumber - 1] = true;
        }),
      );
    }

    void editReps() {
      if (isCompleted) {
        final logIndex = logs.indexWhere(
          (l) => l.exerciseId == id && l.setNumber == setNumber,
        );
        if (logIndex != -1) {
          _editCompletedSetReps(l10n, logs[logIndex], logIndex);
        }
        return;
      }
      _showNumberInputDialog(
        context: context,
        title: l10n.reps,
        currentValue: pendingReps.toDouble(),
        isInteger: true,
        accentColor: colorScheme.primary,
        onSave: (value) => setState(() {
          _pendingSetReps[id]![setNumber - 1] = value.toInt();
          _pendingSetEdited[id]![setNumber - 1] = true;
        }),
      );
    }

    final row = Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCompleted
                ? (isDark ? Colors.green.shade700 : Colors.green.shade600)
                : colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$setNumber',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isCompleted
                  ? Colors.white
                  : (isDark ? Colors.white : colorScheme.primary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        valueBox(
          label: weightLabel,
          valueText: _formatWeightDisplay(displayWeight),
          onTap: editWeight,
        ),
        const SizedBox(width: 10),
        valueBox(label: l10n.reps, valueText: '$displayReps', onTap: editReps),
        const SizedBox(width: 12),
        if (isCompleted)
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? Colors.green.shade600 : Colors.green.shade500,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 28),
          )
        else
          Semantics(
            button: true,
            excludeSemantics: true,
            enabled: displayReps > 0,
            label: l10n.get('logSet'),
            onTap: displayReps > 0
                ? () => _completeSetRow(current, setNumber)
                : null,
            child: Tooltip(
              message: l10n.get('logSet'),
              child: Material(
                color: Colors.green.withValues(alpha: 0.35),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: displayReps > 0
                      ? () => _completeSetRow(current, setNumber)
                      : null,
                  child: const SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(Icons.check, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return Semantics(
      explicitChildNodes: true,
      label:
          '${l10n.get('set')} $setNumber, ${_formatWeightDisplay(displayWeight)} ${_weightUnit == 'lbs' ? l10n.get('weightShortLbs') : l10n.get('weightShort')}, $displayReps ${l10n.reps}'
          '${isCompleted ? ', ${l10n.get('completedSets')}' : ''}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isCompleted
              ? (isDark
                    ? Colors.green.shade900.withValues(alpha: 0.4)
                    : Colors.green.shade50)
              : (isDark ? const Color(0xFF1A2634) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: isCompleted
              ? Border.all(
                  color: isDark ? Colors.green.shade700 : Colors.green.shade300,
                  width: 1.5,
                )
              : null,
          boxShadow: isCompleted
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: row,
      ),
    );
  }
}

// ============== HISTORY PAGE ==============

class HistoryPage extends StatelessWidget {
  final List<WorkoutSession> history;
  final String weightUnit;
  final void Function(WorkoutSession session) onDeleteSession;

  const HistoryPage({
    super.key,
    required this.history,
    required this.onDeleteSession,
    this.weightUnit = 'kg',
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(
            l10n.get('workoutHistory'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: history.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 88,
                        color: colorScheme.primary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        l10n.get('noHistoryYet'),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.get('completeWorkoutToSee'),
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final session = history[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _HistoryCard(
                      session: session,
                      weightUnit: weightUnit,
                      l10n: l10n,
                      onDelete: () => onDeleteSession(session),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final WorkoutSession session;
  final String weightUnit;
  final AppLocalizations l10n;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.session,
    required this.weightUnit,
    required this.l10n,
    required this.onDelete,
  });

  static const double _kgToLbs = 2.2046226218;

  String _formatWeightDisplay(double kg) {
    final v = weightUnit == 'lbs' ? kg * _kgToLbs : kg;
    return v == v.toInt() ? '${v.toInt()}' : v.toStringAsFixed(1);
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDate = DateTime(date.year, date.month, date.day);
    final timeStr = DateFormat.jm().format(date);

    if (sessionDate == today) {
      return 'Today, $timeStr';
    } else if (sessionDate == yesterday) {
      return 'Yesterday, $timeStr';
    } else {
      return '${date.day}/${date.month}/${date.year}, $timeStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalReps = session.logs.fold<int>(0, (sum, log) => sum + log.reps);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2634) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.green.shade900 : Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 32,
                  color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.localizeWorkoutTemplateName(session.templateName),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      _formatDate(session.startTime),
                      style: TextStyle(
                        fontSize: 18,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: Icons.timer,
                value: _formatDuration(session.durationSeconds),
                label: l10n.get('duration'),
              ),
              _StatItem(
                icon: Icons.fitness_center,
                value: '${session.logs.length}',
                label: l10n.get('sets'),
              ),
              _StatItem(
                icon: Icons.repeat,
                value: '$totalReps',
                label: l10n.reps,
              ),
              if (_getMaxWeight() > 0)
                _StatItem(
                  icon: Icons.fitness_center,
                  value: _formatWeightDisplay(_getMaxWeight()),
                  label: weightUnit == 'lbs'
                      ? l10n.get('weightShortLbs')
                      : l10n.get('weightShort'),
                ),
            ],
          ),
          if (session.logs.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              l10n.get('exercises'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ..._groupLogsByExercise(session.logs).map((entry) {
              final exerciseName = entry.key;
              final logs = entry.value;
              logs.sort((a, b) => a.setNumber.compareTo(b.setNumber));
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              l10n.localizeExerciseName(exerciseName),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat.jm().format(logs.first.timestamp),
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...logs.map((log) {
                        final String line;
                        if (log.isDurationSet) {
                          var detail = formatDurationMmSs(log.durationSeconds!);
                          if (log.weight > 0) {
                            detail +=
                                ' × ${_formatWeightDisplay(log.weight)} ${weightUnit == 'lbs' ? l10n.get('weightShortLbs') : l10n.get('weightShort')}';
                          }
                          line = '${l10n.get('set')} ${log.setNumber}: $detail';
                        } else {
                          final isAssisted =
                              _isAssistedPullUp(exerciseName) && log.weight > 0;
                          line = isAssisted
                              ? '${l10n.get('set')} ${log.setNumber}: ${log.reps} ${l10n.reps}, ${_formatWeightDisplay(log.weight)} ${weightUnit == 'lbs' ? l10n.get('weightShortLbs') : l10n.get('weightShort')} ${l10n.get('minusWeight')}'
                              : '${l10n.get('set')} ${log.setNumber}: ${log.reps} ${l10n.reps}${log.weight > 0 ? ' ${_formatWeightDisplay(log.weight)} ${weightUnit == 'lbs' ? l10n.get('weightShortLbs') : l10n.get('weightShort')}' : ''}';
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            line,
                            style: TextStyle(
                              fontSize: 18,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.black87,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 16),
          // Elderly-friendly: large delete button, min height 56
          SizedBox(
            height: 56,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmDelete(context),
              icon: Icon(
                Icons.delete_outline,
                size: 24,
                color: Colors.red.shade700,
              ),
              label: Text(
                l10n.get('deleteFromHistory'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade400, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A2634) : null,
        title: Text(
          l10n.get('deleteFromHistory'),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : null,
          ),
        ),
        content: Text(
          l10n.get('deleteWorkoutFromHistoryConfirm'),
          style: TextStyle(
            fontSize: 20,
            height: 1.4,
            color: isDark ? Colors.grey.shade300 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                l10n.get('cancel'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            child: Text(
              l10n.get('remove'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxWeight() {
    if (session.logs.isEmpty) return 0;
    return session.logs.map((l) => l.weight).reduce((a, b) => a > b ? a : b);
  }

  /// Group logs by exercise (preserve order of first occurrence); each value is list of sets for that exercise.
  List<MapEntry<String, List<ExerciseLog>>> _groupLogsByExercise(
    List<ExerciseLog> logs,
  ) {
    if (logs.isEmpty) return [];
    final byId = <String, List<ExerciseLog>>{};
    for (final log in logs) {
      byId.putIfAbsent(log.exerciseId, () => []).add(log);
    }
    final order = <String>[];
    for (final log in logs) {
      if (!order.contains(log.exerciseId)) order.add(log.exerciseId);
    }
    return order
        .map((id) => MapEntry(byId[id]!.first.exerciseName, byId[id]!))
        .toList();
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Icon(icon, size: 28, color: colorScheme.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// ============== STATISTICS PAGE ==============

class StatisticsPage extends StatelessWidget {
  final List<WorkoutSession> history;
  final String weightUnit;
  final List<WorkoutTemplate> templates;
  final ValueChanged<WorkoutTemplate>? onUpdateTemplate;

  const StatisticsPage({
    super.key,
    required this.history,
    this.weightUnit = 'kg',
    this.templates = const [],
    this.onUpdateTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(
            l10n.get('statistics'),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ConsistencyCalendarEntryCard(
                history: history,
                templates: templates,
                onUpdateTemplate: onUpdateTemplate,
              ),
              const SizedBox(height: 24),
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.bar_chart,
                        size: 80,
                        color: colorScheme.primary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.get('noStatsYet'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.get('completeWorkoutToSee'),
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                // Progress Chart Section
                _ProgressChartSection(history: history, weightUnit: weightUnit),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry point card on the Statistics tab that opens the Consistency
/// Calendar. Shown regardless of whether [history] is empty — a user should
/// be able to set up tracked-exercise lists before logging any workouts.
class _ConsistencyCalendarEntryCard extends StatelessWidget {
  final List<WorkoutSession> history;
  final List<WorkoutTemplate> templates;
  final ValueChanged<WorkoutTemplate>? onUpdateTemplate;

  const _ConsistencyCalendarEntryCard({
    required this.history,
    this.templates = const [],
    this.onUpdateTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isDark ? const Color(0xFF1A2634) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: isDark ? 0 : 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConsistencyCalendarPage(
              history: history,
              templates: templates,
              onUpdateTemplate: onUpdateTemplate,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_month,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.get('consistencyCalendar'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.get('consistencyCalendarSubtitle'),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 26,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============== PROGRESS CHART SECTION ==============

enum ChartViewMode { weight, reps, oneRepMax }

enum ProgressTimeRange { week, month, year, all }

class _ProgressChartSection extends StatefulWidget {
  final List<WorkoutSession> history;
  final String weightUnit;

  const _ProgressChartSection({required this.history, this.weightUnit = 'kg'});

  @override
  State<_ProgressChartSection> createState() => _ProgressChartSectionState();
}

class _ProgressChartSectionState extends State<_ProgressChartSection> {
  String? selectedExerciseName;
  ChartViewMode viewMode = ChartViewMode.weight;
  ProgressTimeRange timeRange = ProgressTimeRange.all;

  DateTime? get _timeRangeStart {
    if (timeRange == ProgressTimeRange.all) return null;
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    switch (timeRange) {
      case ProgressTimeRange.week:
        return startOfToday.subtract(const Duration(days: 7));
      case ProgressTimeRange.month:
        return startOfToday.subtract(const Duration(days: 30));
      case ProgressTimeRange.year:
        return startOfToday.subtract(const Duration(days: 365));
      case ProgressTimeRange.all:
        return null;
    }
  }

  /// Unique exercise names in history (same name = one entry), matching past-history / stats aggregation.
  List<String> get uniqueExerciseNames {
    final names = <String>{};
    for (final session in widget.history) {
      for (final log in session.logs) {
        names.add(log.exerciseName);
      }
    }
    final list = names.toList()..sort();
    return list;
  }

  // Get chart data points for selected exercise (weight + estimated 1RM only)
  List<_ChartDataPoint> get chartData {
    if (selectedExerciseName == null) return [];

    final dataPoints = <_ChartDataPoint>[];

    for (final session in widget.history) {
      final logsForExercise = session.logs
          .where((log) => log.exerciseName == selectedExerciseName)
          .toList();

      if (logsForExercise.isEmpty) continue;

      // Max reps or hold seconds in session (for reps-over-time chart)
      final maxReps = logsForExercise
          .map((l) => l.isDurationSet ? l.durationSeconds! : l.reps)
          .reduce(math.max);

      // Max weight in session and reps from that set
      final logWithMaxWeight = logsForExercise.reduce(
        (a, b) => a.weight >= b.weight ? a : b,
      );
      final maxWeight = logWithMaxWeight.weight;
      final repsAtMaxWeight = logWithMaxWeight.reps;

      // Estimated 1RM (Epley: weight * (1 + reps/30)), and the set that produced it
      double max1RM = 0;
      double weightFor1RM = 0;
      int repsFor1RM = 0;
      for (final log in logsForExercise) {
        if (log.weight <= 0) continue;
        final oneRM = log.reps >= 1
            ? log.weight * (1 + log.reps / 30)
            : log.weight;
        if (oneRM > max1RM) {
          max1RM = oneRM;
          weightFor1RM = log.weight;
          repsFor1RM = log.reps;
        }
      }

      dataPoints.add(
        _ChartDataPoint(
          date: session.startTime,
          weight: maxWeight,
          maxReps: maxReps,
          repsAtMaxWeight: repsAtMaxWeight,
          estimated1RM: max1RM,
          weightFor1RM: weightFor1RM,
          repsFor1RM: repsFor1RM,
        ),
      );
    }

    // Sort by date (oldest first)
    dataPoints.sort((a, b) => a.date.compareTo(b.date));
    final rangeStart = _timeRangeStart;
    if (rangeStart == null) return dataPoints;
    return dataPoints.where((p) => !p.date.isBefore(rangeStart)).toList();
  }

  bool get _hasDataOutsideTimeRange {
    if (selectedExerciseName == null || timeRange == ProgressTimeRange.all) {
      return false;
    }
    final rangeStart = _timeRangeStart;
    if (rangeStart == null) return false;
    for (final session in widget.history) {
      if (session.startTime.isBefore(rangeStart)) {
        final hasExercise = session.logs.any(
          (log) => log.exerciseName == selectedExerciseName,
        );
        if (hasExercise) return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final names = uniqueExerciseNames;
    if (names.isNotEmpty) {
      selectedExerciseName = names.first;
    }
  }

  @override
  void didUpdateWidget(_ProgressChartSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final names = uniqueExerciseNames;
    if (selectedExerciseName != null && !names.contains(selectedExerciseName)) {
      setState(() {
        selectedExerciseName = names.isNotEmpty ? names.first : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exercises = uniqueExerciseNames;

    if (exercises.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.get('progressChart'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),

        // Exercise Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2634) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedExerciseName,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down,
                color: colorScheme.primary,
                size: 32,
              ),
              style: TextStyle(
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black87,
              ),
              dropdownColor: isDark ? const Color(0xFF1A2634) : Colors.white,
              items: exercises.map((name) {
                return DropdownMenuItem<String>(
                  value: name,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.localizeExerciseName(name),
                      style: TextStyle(
                        fontSize: 18,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedExerciseName = value;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        // View Mode Toggle (Weight / Reps / 1RM)
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2634) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: _ToggleButton(
                  label: l10n.get('weightOverTime'),
                  isSelected: viewMode == ChartViewMode.weight,
                  onTap: () => setState(() => viewMode = ChartViewMode.weight),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _ToggleButton(
                  label: l10n.get('repsOverTime'),
                  isSelected: viewMode == ChartViewMode.reps,
                  onTap: () => setState(() => viewMode = ChartViewMode.reps),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _ToggleButton(
                  label: l10n.get('estimated1RM'),
                  isSelected: viewMode == ChartViewMode.oneRepMax,
                  onTap: () =>
                      setState(() => viewMode = ChartViewMode.oneRepMax),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Chart
        _buildChart(l10n, colorScheme, isDark),
        const SizedBox(height: 20),

        // Time range (elderly-friendly 2×2 large buttons)
        Text(
          l10n.get('progressTimeRange'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2634) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ToggleButton(
                      label: l10n.get('progressOneWeek'),
                      isSelected: timeRange == ProgressTimeRange.week,
                      onTap: () =>
                          setState(() => timeRange = ProgressTimeRange.week),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ToggleButton(
                      label: l10n.get('progressOneMonth'),
                      isSelected: timeRange == ProgressTimeRange.month,
                      onTap: () =>
                          setState(() => timeRange = ProgressTimeRange.month),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _ToggleButton(
                      label: l10n.get('progressOneYear'),
                      isSelected: timeRange == ProgressTimeRange.year,
                      onTap: () =>
                          setState(() => timeRange = ProgressTimeRange.year),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ToggleButton(
                      label: l10n.get('progressAllTime'),
                      isSelected: timeRange == ProgressTimeRange.all,
                      onTap: () =>
                          setState(() => timeRange = ProgressTimeRange.all),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChart(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final data = chartData;

    if (data.isEmpty) {
      final emptyMessage = _hasDataOutsideTimeRange
          ? l10n.get('noDataForTimeRange')
          : l10n.get('noDataForExercise');
      return Container(
        height: 200,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2634) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            emptyMessage,
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Calculate min/max values for Y-axis (weight or 1RM only)
    final weightValues = data.map((d) => d.weight).toList();
    final maxWeightKg = weightValues.reduce(math.max);
    final isLbs = widget.weightUnit == 'lbs';
    const double kgToLbs = 2.2046226218;
    final maxWeightDisplay = isLbs ? maxWeightKg * kgToLbs : maxWeightKg;

    // Create line chart data (weight / reps / 1RM in display unit)
    final weightSpots = <FlSpot>[];
    final repsSpots = <FlSpot>[];
    final oneRMSpots = <FlSpot>[];

    for (int i = 0; i < data.length; i++) {
      final w = data[i].weight;
      weightSpots.add(
        FlSpot(
          i.toDouble(),
          viewMode == ChartViewMode.weight && isLbs ? w * kgToLbs : w,
        ),
      );
      repsSpots.add(FlSpot(i.toDouble(), data[i].maxReps.toDouble()));
      final oneRM = data[i].estimated1RM;
      oneRMSpots.add(FlSpot(i.toDouble(), isLbs ? oneRM * kgToLbs : oneRM));
    }

    final lineBarsData = <LineChartBarData>[];

    // Weight line (green)
    if (viewMode == ChartViewMode.weight) {
      lineBarsData.add(
        LineChartBarData(
          spots: weightSpots,
          isCurved: true,
          color: Colors.green,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 5,
                color: Colors.green,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.green.withValues(alpha: 0.1),
          ),
        ),
      );
    }

    // Reps line (blue)
    if (viewMode == ChartViewMode.reps) {
      lineBarsData.add(
        LineChartBarData(
          spots: repsSpots,
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 5,
                color: Colors.blue,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.blue.withValues(alpha: 0.1),
          ),
        ),
      );
    }

    // Estimated 1RM line (orange)
    if (viewMode == ChartViewMode.oneRepMax) {
      lineBarsData.add(
        LineChartBarData(
          spots: oneRMSpots,
          isCurved: true,
          color: Colors.orange,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 5,
                color: Colors.orange,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.orange.withValues(alpha: 0.1),
          ),
        ),
      );
    }

    // Determine Y-axis max (weight / reps / 1RM)
    final maxReps = data.isEmpty
        ? 0
        : data.map((d) => d.maxReps).reduce(math.max);
    final max1RMDisplay = data.isEmpty
        ? 0.0
        : (data.map((d) => d.estimated1RM).reduce(math.max)) *
              (isLbs ? kgToLbs : 1);
    final double yMax = viewMode == ChartViewMode.weight
        ? maxWeightDisplay + (isLbs ? 10 : 5)
        : viewMode == ChartViewMode.reps
        ? (maxReps + 2).toDouble()
        : max1RMDisplay + (isLbs ? 10 : 5);

    return Container(
      height: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2634) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Legend
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Center(
              child: _LegendItem(
                color: viewMode == ChartViewMode.weight
                    ? Colors.green
                    : viewMode == ChartViewMode.reps
                    ? Colors.blue
                    : Colors.orange,
                label: viewMode == ChartViewMode.weight
                    ? l10n.get('weightOverTime')
                    : viewMode == ChartViewMode.reps
                    ? l10n.get('repsOverTime')
                    : l10n.get('estimated1RM'),
              ),
            ),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                lineBarsData: lineBarsData,
                minY: 0,
                maxY: yMax,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        final label = viewMode == ChartViewMode.reps
                            ? value.toInt().toString()
                            : (value == value.toInt()
                                  ? value.toInt().toString()
                                  : value.toStringAsFixed(1));
                        return Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: data.length > 7
                          ? (data.length / 5).ceil().toDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) {
                          return const SizedBox.shrink();
                        }
                        final date = data[index].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${date.day}/${date.month}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yMax / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) =>
                        isDark ? const Color(0xFF2A3A4A) : Colors.grey.shade800,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        if (index < 0 || index >= data.length) {
                          return LineTooltipItem(
                            '',
                            const TextStyle(color: Colors.white, fontSize: 14),
                          );
                        }
                        final dataPoint = data[index];
                        final isLbs = widget.weightUnit == 'lbs';
                        const kgToLbs = 2.2046226218;

                        if (viewMode == ChartViewMode.weight) {
                          final weightDisplay = isLbs
                              ? dataPoint.weight * kgToLbs
                              : dataPoint.weight;
                          final weightStr =
                              weightDisplay == weightDisplay.toInt()
                              ? '${weightDisplay.toInt()}'
                              : weightDisplay.toStringAsFixed(1);
                          final unitLabel = isLbs
                              ? l10n.get('weightShortLbs')
                              : l10n.get('weightShort');
                          return LineTooltipItem(
                            '$weightStr $unitLabel · ${dataPoint.repsAtMaxWeight} ${l10n.reps}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          );
                        } else if (viewMode == ChartViewMode.reps) {
                          return LineTooltipItem(
                            '${dataPoint.maxReps} ${l10n.reps}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          );
                        } else {
                          final oneRMDisplay = isLbs
                              ? dataPoint.estimated1RM * kgToLbs
                              : dataPoint.estimated1RM;
                          final oneRMStr = oneRMDisplay == oneRMDisplay.toInt()
                              ? '${oneRMDisplay.toInt()}'
                              : oneRMDisplay.toStringAsFixed(1);
                          final oneRMUnit = isLbs
                              ? l10n.get('weightShortLbs')
                              : l10n.get('weightShort');
                          final fromW = isLbs
                              ? dataPoint.weightFor1RM * kgToLbs
                              : dataPoint.weightFor1RM;
                          final fromWStr = fromW == fromW.toInt()
                              ? '${fromW.toInt()}'
                              : fromW.toStringAsFixed(1);
                          final fromPart = dataPoint.repsFor1RM > 0
                              ? ' (${l10n.get('fromSet')}: $fromWStr $oneRMUnit × ${dataPoint.repsFor1RM} ${l10n.reps})'
                              : '';
                          return LineTooltipItem(
                            '${l10n.get('estimated1RM')}: $oneRMStr $oneRMUnit$fromPart',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartDataPoint {
  final DateTime date;
  final double weight;
  final int maxReps;
  final int repsAtMaxWeight;
  final double estimated1RM;
  final double weightFor1RM;
  final int repsFor1RM;

  _ChartDataPoint({
    required this.date,
    required this.weight,
    required this.maxReps,
    required this.repsAtMaxWeight,
    this.estimated1RM = 0,
    this.weightFor1RM = 0,
    this.repsFor1RM = 0,
  });
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double fontSize;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isSelected ? colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

// ============== REUSABLE WIDGETS ==============

/// Large kg / lbs toggle for the active workout weight card.
class _WeightUnitSegmentedToggle extends StatelessWidget {
  final String selectedUnit;
  final String kgLabel;
  final String lbsLabel;
  final ValueChanged<String> onUnitSelected;
  final bool isDark;

  const _WeightUnitSegmentedToggle({
    required this.selectedUnit,
    required this.kgLabel,
    required this.lbsLabel,
    required this.onUnitSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const labelStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

    return SizedBox(
      width: 240,
      child: SegmentedButton<String>(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(0, 52)),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primary;
            }
            return isDark ? const Color(0xFF232F3E) : Colors.grey.shade200;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return isDark ? Colors.white : Colors.black87;
          }),
        ),
        segments: [
          ButtonSegment(
            value: 'kg',
            label: Text(kgLabel, style: labelStyle),
          ),
          ButtonSegment(
            value: 'lbs',
            label: Text(lbsLabel, style: labelStyle),
          ),
        ],
        selected: {selectedUnit},
        onSelectionChanged: (selected) {
          if (selected.isNotEmpty) onUnitSelected(selected.first);
        },
        showSelectedIcon: false,
      ),
    );
  }
}

class _LargeRoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final String label;

  const _LargeRoundButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            child: Icon(icon, size: 36, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ============== SETTINGS PAGE ==============

class SettingsPage extends StatefulWidget {
  final String weightUnit;
  final VoidCallback? onWeightUnitChanged;

  const SettingsPage({
    super.key,
    this.weightUnit = 'kg',
    this.onWeightUnitChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _defaultRestSeconds = 60;
  double _timerBeepVolumePct = 85;

  @override
  void initState() {
    super.initState();
    _loadDefaultRestSeconds();
    _loadTimerBeepVolume();
  }

  Future<void> _loadTimerBeepVolume() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(kPrefTimerBeepVolume);
    if (mounted) {
      setState(() => _timerBeepVolumePct = (v ?? 85).clamp(0, 100).toDouble());
    }
  }

  Future<void> _setTimerBeepVolume(double pct) async {
    final clamped = pct.clamp(0, 100).toDouble();
    setState(() => _timerBeepVolumePct = clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kPrefTimerBeepVolume, clamped.round().clamp(0, 100));
  }

  Future<void> _previewTimerBeep() async {
    final p = AudioPlayer();
    try {
      await p.setAudioContext(timerBeepMixWithOthersAudioContext());
      await p.setVolume(_timerBeepVolumePct / 100.0);
      if (_timerBeepVolumePct <= 0) return;
      await p.play(AssetSource('audio/timer_beep.wav'));
      await Future<void>.delayed(const Duration(milliseconds: 700));
    } catch (_) {
      // Ignore preview errors
    } finally {
      await p.dispose();
    }
  }

  Future<void> _loadDefaultRestSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('default_rest_seconds');
    if (saved != null && mounted) {
      setState(() => _defaultRestSeconds = saved.clamp(30, 600));
    }
  }

  Future<void> _setDefaultRestSeconds(int seconds) async {
    final clamped = seconds.clamp(30, 600);
    setState(() => _defaultRestSeconds = clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_rest_seconds', clamped);
  }

  String _formatRestDuration(int seconds) {
    if (seconds >= 60) {
      final min = seconds ~/ 60;
      return min == 1 ? '1 min' : '$min min';
    }
    return '$seconds sec';
  }

  Future<void> _setWeightUnit(String unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weight_unit', unit);
    widget.onWeightUnitChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Elderly-friendly: larger section titles and tap targets
    const double sectionTitleFontSize = 22;
    const double settingMinHeight = 64;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.get('settings'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Appearance section
            Text(
              l10n.get('appearance'),
              style: TextStyle(
                fontSize: sectionTitleFontSize,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2634) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                children: [
                  _ThemeOptionTile(
                    title: l10n.get('systemDefault'),
                    subtitle: l10n.get('themeDescription'),
                    icon: Icons.brightness_auto,
                    isSelected: themeNotifier.themeMode == ThemeMode.system,
                    onTap: () => themeNotifier.setThemeMode(ThemeMode.system),
                  ),
                  Divider(height: 1, color: Colors.grey.shade300),
                  _ThemeOptionTile(
                    title: l10n.get('lightMode'),
                    icon: Icons.light_mode,
                    isSelected: themeNotifier.themeMode == ThemeMode.light,
                    onTap: () => themeNotifier.setThemeMode(ThemeMode.light),
                  ),
                  Divider(height: 1, color: Colors.grey.shade300),
                  _ThemeOptionTile(
                    title: l10n.get('darkMode'),
                    icon: Icons.dark_mode,
                    isSelected: themeNotifier.themeMode == ThemeMode.dark,
                    onTap: () => themeNotifier.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            // Workout / Default rest timer section
            Text(
              l10n.get('restTimerWorkout'),
              style: TextStyle(
                fontSize: sectionTitleFontSize,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2634) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.get('defaultRestTimer'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.get('defaultRestTimerDesc'),
                    style: TextStyle(
                      fontSize: 17,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _formatRestDuration(_defaultRestSeconds),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      SizedBox(
                        height: settingMinHeight,
                        child: ElevatedButton.icon(
                          onPressed: _defaultRestSeconds <= 30
                              ? null
                              : () => _setDefaultRestSeconds(
                                  _defaultRestSeconds - 30,
                                ),
                          icon: const Icon(Icons.remove, size: 28),
                          label: Text(
                            l10n.get('subtract30Seconds'),
                            style: const TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: settingMinHeight,
                        child: ElevatedButton.icon(
                          onPressed: _defaultRestSeconds >= 600
                              ? null
                              : () => _setDefaultRestSeconds(
                                  _defaultRestSeconds + 30,
                                ),
                          icon: const Icon(Icons.add, size: 28),
                          label: Text(
                            l10n.get('add30Seconds'),
                            style: const TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Weight unit (kg / lbs)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2634) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.get('weightUnit'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.get('weightUnitDesc'),
                    style: TextStyle(
                      fontSize: 17,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Full-width options so "kg" / "lbs" stay horizontal; elderly-friendly min height
                  _WeightUnitOption(
                    unit: 'kg',
                    label: l10n.get('weightShort'),
                    isSelected: widget.weightUnit == 'kg',
                    onTap: () => _setWeightUnit('kg'),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _WeightUnitOption(
                    unit: 'lbs',
                    label: l10n.get('weightShortLbs'),
                    isSelected: widget.weightUnit == 'lbs',
                    onTap: () => _setWeightUnit('lbs'),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            Text(
              l10n.get('timerBeepVolume'),
              style: TextStyle(
                fontSize: sectionTitleFontSize,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2634) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.get('timerBeepVolumeDesc'),
                    style: TextStyle(
                      fontSize: 17,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.volume_down, size: 28),
                      Expanded(
                        child: Slider(
                          value: _timerBeepVolumePct,
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: '${_timerBeepVolumePct.round()}%',
                          onChanged: (v) => _setTimerBeepVolume(v),
                        ),
                      ),
                      const Icon(Icons.volume_up, size: 28),
                    ],
                  ),
                  Center(
                    child: Text(
                      '${_timerBeepVolumePct.round()}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: settingMinHeight,
                    child: OutlinedButton.icon(
                      onPressed: _previewTimerBeep,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: Text(
                        l10n.get('previewTimerBeep'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            // Data Backup section
            Text(
              l10n.get('dataBackup'),
              style: TextStyle(
                fontSize: sectionTitleFontSize,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            // Export Button
            _BackupButton(
              icon: Icons.upload_file,
              title: l10n.get('exportData'),
              subtitle: l10n.get('exportDataDesc'),
              color: Colors.blue,
              onTap: () => _exportData(context, l10n),
            ),
            const SizedBox(height: 14),
            // Import Button
            _BackupButton(
              icon: Icons.download,
              title: l10n.get('importData'),
              subtitle: l10n.get('importDataDesc'),
              color: Colors.orange,
              onTap: () => _importData(context, l10n),
            ),
            const SizedBox(height: 36),
            // About section
            Text(
              l10n.get('about'),
              style: TextStyle(
                fontSize: sectionTitleFontSize,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2634) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                minVerticalPadding: 20,
                leading: Icon(
                  Icons.info_outline,
                  size: 32,
                  color: colorScheme.primary,
                ),
                title: Text(
                  l10n.aboutAndDisclaimer,
                  style: const TextStyle(fontSize: 20),
                ),
                trailing: const Icon(Icons.chevron_right, size: 32),
                onTap: () => _showAboutDialog(context, l10n),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2634) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                minVerticalPadding: 20,
                leading: Icon(
                  Icons.favorite_outline,
                  size: 32,
                  color: colorScheme.primary,
                ),
                title: Text(
                  l10n.get('supportDeveloper'),
                  style: const TextStyle(fontSize: 20),
                ),
                subtitle: Text(l10n.get('supportDeveloperSubtitle')),
                trailing: const Icon(Icons.chevron_right, size: 32),
                onTap: () => showDonationSheet(context),
              ),
            ),
            const SizedBox(height: 24),
            // Version info
            Center(
              child: Text(
                '${l10n.get('version')} 1.0.0',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '© 2026 Logicphile Limited',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A2634) : null,
        title: Row(
          children: [
            Icon(Icons.info_outline, size: 32, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.aboutAndDisclaimer,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : null,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.appTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.get('workoutTrackerDesc'),
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.orange.shade900.withValues(alpha: 0.4)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.orange.shade700
                        : Colors.orange.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.get('importantDisclaimers'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• ${l10n.get('disclaimer1')}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ${l10n.get('disclaimer2')}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ${l10n.get('disclaimer3')}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ${l10n.get('disclaimer4')}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.green.shade900.withValues(alpha: 0.4)
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.green.shade700
                        : Colors.green.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.get('yourPrivacy'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.green.shade300 : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• ${l10n.get('privacy1')}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ${l10n.get('privacy2')}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ${l10n.get('privacy3')}',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                  ],
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

  Future<void> _exportData(BuildContext context, AppLocalizations l10n) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Gather all data
      final templatesJson = prefs.getString('workout_templates');
      final historyJson = prefs.getString('workout_history');
      final consistencyListsJson = prefs.getString(kConsistencyListsPrefsKey);
      final consistencySelectedListId = prefs.getString(
        kConsistencySelectedListPrefsKey,
      );

      if ((templatesJson == null || templatesJson.isEmpty) &&
          (historyJson == null || historyJson.isEmpty)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.get('noDataToExport'),
                style: const TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Create backup data
      final backupData = {
        'version': 1,
        'exportDate': DateTime.now().toIso8601String(),
        'templates': templatesJson != null ? jsonDecode(templatesJson) : [],
        'history': historyJson != null ? jsonDecode(historyJson) : [],
        'defaultRestSeconds': prefs.getInt('default_rest_seconds') ?? 60,
        'consistencyLists':
            (consistencyListsJson != null && consistencyListsJson.isNotEmpty)
            ? jsonDecode(consistencyListsJson)
            : [],
        'consistencySelectedListId': ?consistencySelectedListId,
      };

      // Create temporary file
      final directory = await getTemporaryDirectory();
      final fileName =
          'workout_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonEncode(backupData));

      // Share the file
      if (context.mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: l10n.get('backupFileShared'),
          ),
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.get('exportSuccess'),
                style: const TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.get('exportFailed'),
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context, AppLocalizations l10n) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A2634) : null,
        title: Row(
          children: [
            Icon(Icons.warning_amber, size: 32, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.get('importData'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : null,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.get('importWarning'),
          style: TextStyle(
            fontSize: 18,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(
              l10n.get('confirmImport'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Pick file - use FileType.any for better compatibility across platforms
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true, // Load file data directly for better iOS compatibility
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final pickedFile = result.files.single;

      // Try to read content - prefer bytes (works on all platforms) over path
      String content;
      if (pickedFile.bytes != null) {
        content = String.fromCharCodes(pickedFile.bytes!);
      } else if (pickedFile.path != null) {
        final file = File(pickedFile.path!);
        content = await file.readAsString();
      } else {
        throw Exception('Could not read file');
      }

      final backupData = jsonDecode(content) as Map<String, dynamic>;

      // Validate backup file
      if (!backupData.containsKey('templates') ||
          !backupData.containsKey('history')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.get('invalidBackupFile'),
                style: const TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Import data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'workout_templates',
        jsonEncode(backupData['templates']),
      );
      await prefs.setString(
        'workout_history',
        jsonEncode(backupData['history']),
      );
      // Restore rest timer setting if present in backup (e.g. 30 seconds)
      final importedRest = backupData['defaultRestSeconds'];
      if (importedRest is int) {
        await prefs.setInt('default_rest_seconds', importedRest.clamp(30, 600));
      }
      // Restore Consistency Calendar lists if present in backup
      final importedConsistencyLists = backupData['consistencyLists'];
      if (importedConsistencyLists is List) {
        await prefs.setString(
          kConsistencyListsPrefsKey,
          jsonEncode(importedConsistencyLists),
        );
      }
      final importedSelectedListId = backupData['consistencySelectedListId'];
      if (importedSelectedListId is String) {
        await prefs.setString(
          kConsistencySelectedListPrefsKey,
          importedSelectedListId,
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.get('importSuccess'),
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Show restart message
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1A2634) : null,
            title: Text(
              l10n.get('importSuccess'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : null,
              ),
            ),
            content: Text(
              'Please restart the app to see your imported data.',
              style: TextStyle(
                fontSize: 18,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.get('importFailed'),
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _BackupButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _BackupButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Elderly-friendly: larger padding, fonts, and tap target (min 64dp)
    const double minHeight = 64;

    return Material(
      color: isDark ? const Color(0xFF1A2634) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: isDark ? 0 : 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.3 : 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: color),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 32,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width weight unit option so "kg" / "lbs" always display horizontally.
class _WeightUnitOption extends StatelessWidget {
  final String unit;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _WeightUnitOption({
    required this.unit,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const double minHeight = 72;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.straighten, size: 32, color: colorScheme.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: 0.5,
                      ),
                      softWrap: false,
                      overflow: TextOverflow.visible,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 18,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, size: 32, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Elderly-friendly: larger tap target and fonts
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      minVerticalPadding: 20,
      leading: Icon(icon, size: 32, color: colorScheme.primary),
      title: Text(title, style: const TextStyle(fontSize: 20)),
      subtitle: subtitle != null
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle!,
                style: TextStyle(fontSize: 17, color: Colors.grey.shade600),
              ),
            )
          : null,
      trailing: isSelected
          ? Icon(Icons.check_circle, size: 32, color: colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

// ============== CONSISTENCY CALENDAR ==============

class ConsistencyCalendarPage extends StatefulWidget {
  final List<WorkoutSession> history;
  final List<WorkoutTemplate> templates;
  final ValueChanged<WorkoutTemplate>? onUpdateTemplate;

  const ConsistencyCalendarPage({
    super.key,
    required this.history,
    this.templates = const [],
    this.onUpdateTemplate,
  });

  @override
  State<ConsistencyCalendarPage> createState() =>
      _ConsistencyCalendarPageState();
}

class _ConsistencyCalendarPageState extends State<ConsistencyCalendarPage> {
  List<ConsistencyExerciseList> _lists = [];
  String? _selectedListId;
  DateTime _anchor = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    var lists = <ConsistencyExerciseList>[];
    final raw = prefs.getString(kConsistencyListsPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        lists = decoded
            .map(
              (e) =>
                  ConsistencyExerciseList.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      } catch (_) {
        lists = [];
      }
    }
    if (_backfillTemplateIds(lists)) {
      await prefs.setString(
        kConsistencyListsPrefsKey,
        jsonEncode(lists.map((l) => l.toJson()).toList()),
      );
    }
    final storedSelectedId = prefs.getString(kConsistencySelectedListPrefsKey);
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _selectedListId = lists.any((l) => l.id == storedSelectedId)
          ? storedSelectedId
          : (lists.isNotEmpty ? lists.first.id : null);
      _loading = false;
    });
  }

  /// One-time migration for template-kind entries tracked before
  /// [TrackedExercise.templateId] existed: backfills it by matching the
  /// entry's current name against [widget.templates]. Needed so matching
  /// (which now prefers the stable id — see [buildConsistencySetsByDay])
  /// keeps working for lists set up before this field was added, including
  /// across a subsequent rename. Mutates [lists] in place; returns whether
  /// anything changed.
  bool _backfillTemplateIds(List<ConsistencyExerciseList> lists) {
    if (widget.templates.isEmpty) return false;
    final idByName = <String, String>{
      for (final t in widget.templates) t.name.trim().toLowerCase(): t.id,
    };
    var changed = false;
    for (var i = 0; i < lists.length; i++) {
      var listChanged = false;
      final updated = <TrackedExercise>[];
      for (final te in lists[i].exercises) {
        final needsId =
            te.kind == TrackedItemKind.template &&
            (te.templateId == null || te.templateId!.isEmpty);
        final foundId = needsId
            ? idByName[te.exerciseName.trim().toLowerCase()]
            : null;
        if (foundId != null) {
          updated.add(te.copyWith(templateId: foundId));
          listChanged = true;
        } else {
          updated.add(te);
        }
      }
      if (listChanged) {
        lists[i] = lists[i].copyWith(exercises: updated);
        changed = true;
      }
    }
    return changed;
  }

  Future<void> _saveLists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kConsistencyListsPrefsKey,
      jsonEncode(_lists.map((l) => l.toJson()).toList()),
    );
  }

  Future<void> _saveSelectedListId() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedListId == null) {
      await prefs.remove(kConsistencySelectedListPrefsKey);
    } else {
      await prefs.setString(kConsistencySelectedListPrefsKey, _selectedListId!);
    }
  }

  ConsistencyExerciseList? get _selectedList {
    for (final l in _lists) {
      if (l.id == _selectedListId) return l;
    }
    return null;
  }

  void _selectList(String id) {
    setState(() {
      _selectedListId = id;
      _anchor = DateTime.now();
    });
    unawaited(_saveSelectedListId());
  }

  void _updateSelectedList(ConsistencyExerciseList updated) {
    setState(() {
      final index = _lists.indexWhere((l) => l.id == updated.id);
      if (index != -1) _lists[index] = updated;
    });
    unawaited(_saveLists());
  }

  Future<void> _createList(String name) async {
    final list = ConsistencyExerciseList(
      id: 'cl_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
    );
    setState(() {
      _lists.add(list);
      _selectedListId = list.id;
      _anchor = DateTime.now();
    });
    await _saveLists();
    await _saveSelectedListId();
  }

  Future<void> _renameList(String id, String name) async {
    setState(() {
      final index = _lists.indexWhere((l) => l.id == id);
      if (index != -1) _lists[index] = _lists[index].copyWith(name: name);
    });
    await _saveLists();
  }

  Future<void> _deleteList(String id) async {
    setState(() {
      _lists.removeWhere((l) => l.id == id);
      if (_selectedListId == id) {
        _selectedListId = _lists.isNotEmpty ? _lists.first.id : null;
      }
    });
    await _saveLists();
    await _saveSelectedListId();
  }

  Future<void> _showListNameDialog({
    String? existingName,
    required ValueChanged<String> onSave,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: existingName ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2A3A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          existingName == null ? l10n.get('newList') : l10n.get('renameList'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            labelText: l10n.get('listName'),
            hintText: l10n.get('listNameHint'),
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) {
            final name = controller.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            onSave(name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              onSave(name);
            },
            child: Text(
              l10n.get('save'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteList(ConsistencyExerciseList list) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2A3A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.get('deleteList'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          '${l10n.get('deleteWorkoutConfirm')} "${list.name}"?\n\n${l10n.get('deleteListWarning')}',
          style: TextStyle(
            fontSize: 18,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              l10n.get('deleteList'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteList(list.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(
            l10n.get('consistencyCalendar'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _lists.isEmpty
            ? _buildEmptyState(l10n, colorScheme)
            : _buildContent(l10n, isDark, colorScheme),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month,
              size: 80,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.get('noListsYet'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.get('createFirstListHint'),
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _showListNameDialog(onSave: _createList),
                icon: const Icon(Icons.add, size: 26),
                label: Text(
                  l10n.get('newList'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    AppLocalizations l10n,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    final list = _selectedList!;
    final range = computeConsistencyRange(
      anchor: _anchor,
      mode: list.viewMode,
      startWeekday: list.startWeekday,
    );
    final gridDays = list.viewMode == ConsistencyViewMode.month
        ? computeConsistencyMonthGridDays(_anchor, list.startWeekday)
        : range.days;
    final setsByDay = buildConsistencySetsByDay(
      history: widget.history,
      trackedExercises: list.exercises,
    );
    final cellHeight = list.viewMode == ConsistencyViewMode.month ? 64.0 : 96.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildListSelectorRow(l10n, isDark, colorScheme, list),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => _ManageExercisesSheet(
                  list: list,
                  history: widget.history,
                  templates: widget.templates,
                  onChanged: _updateSelectedList,
                  onUpdateTemplate: widget.onUpdateTemplate,
                ),
              ),
              icon: Icon(Icons.edit_note, size: 22, color: colorScheme.primary),
              label: Text(
                l10n.get('manageExercises'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ConsistencyViewModeToggle(
            selected: list.viewMode,
            onChanged: (mode) {
              setState(() => _anchor = DateTime.now());
              _updateSelectedList(list.copyWith(viewMode: mode));
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickWeekStartDay(list),
                  icon: const Icon(Icons.event_repeat, size: 18),
                  label: Text(
                    '${l10n.get('weekStartsOn')}: ${_consistencyWeekdayName(list.startWeekday)}',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: list.showSetCounts,
            onChanged: (v) =>
                _updateSelectedList(list.copyWith(showSetCounts: v)),
            title: Text(
              l10n.get('showSetCounts'),
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: l10n.get('previousPeriod'),
                onPressed: () => _stepRange(list, forward: false),
                icon: const Icon(Icons.chevron_left, size: 30),
              ),
              Expanded(
                child: Text(
                  _rangeHeaderText(list, range),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.get('nextPeriod'),
                onPressed: () => _stepRange(list, forward: true),
                icon: const Icon(Icons.chevron_right, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (list.exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l10n.get('noExercisesInList'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            )
          else ...[
            _ConsistencyCalendarGrid(
              days: gridDays,
              rangeStart: range.start,
              rangeEnd: range.end,
              exercises: list.exercises,
              setsByDay: setsByDay,
              showSetCounts: list.showSetCounts,
              cellHeight: cellHeight,
              startWeekday: list.startWeekday,
              onSegmentTap: (day, exercise) =>
                  _openExerciseDetail(exercise, list),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.get('legend'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            for (final exercise in list.exercises)
              _LegendRow(
                exercise: exercise,
                onTap: () => _openExerciseDetail(exercise, list),
              ),
          ],
        ],
      ),
    );
  }

  void _stepRange(ConsistencyExerciseList list, {required bool forward}) {
    setState(() {
      _anchor = nextConsistencyAnchor(_anchor, list.viewMode, forward: forward);
    });
  }

  String _rangeHeaderText(
    ConsistencyExerciseList list,
    ConsistencyDateRange range,
  ) {
    if (list.viewMode == ConsistencyViewMode.month) {
      return DateFormat('MMMM yyyy').format(_anchor);
    }
    return '${DateFormat('MMM d').format(range.start)} – '
        '${DateFormat('MMM d, yyyy').format(range.end)}';
  }

  Future<void> _pickWeekStartDay(ConsistencyExerciseList list) async {
    final chosen = await showConsistencyWeekStartPicker(
      context,
      list.startWeekday,
    );
    if (chosen != null) {
      setState(() => _anchor = DateTime.now());
      _updateSelectedList(list.copyWith(startWeekday: chosen));
    }
  }

  void _openExerciseDetail(
    TrackedExercise exercise,
    ConsistencyExerciseList list,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ExerciseDetailPage(
          exercise: exercise,
          history: widget.history,
          defaultViewMode: list.viewMode,
          defaultStartWeekday: list.startWeekday,
          defaultShowSetCounts: list.showSetCounts,
        ),
      ),
    );
  }

  Widget _buildListSelectorRow(
    AppLocalizations l10n,
    bool isDark,
    ColorScheme colorScheme,
    ConsistencyExerciseList selected,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final l in _lists) ...[
                  ChoiceChip(
                    label: Text(
                      l.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: l.id == selected.id
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    selected: l.id == selected.id,
                    selectedColor: colorScheme.primary,
                    backgroundColor: isDark
                        ? const Color(0xFF232F3E)
                        : Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    onSelected: (_) => _selectList(l.id),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.get('newList'),
          onPressed: () => _showListNameDialog(onSave: _createList),
          icon: Icon(
            Icons.add_circle_outline,
            size: 28,
            color: colorScheme.primary,
          ),
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            size: 26,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onSelected: (action) {
            if (action == 'rename') {
              _showListNameDialog(
                existingName: selected.name,
                onSave: (name) => _renameList(selected.id, name),
              );
            } else if (action == 'delete') {
              _confirmDeleteList(selected);
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'rename',
              child: Text(
                l10n.get('renameList'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                l10n.get('deleteList'),
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Localized full weekday name for weekday 1 (Monday) .. 7 (Sunday), matching
/// [DateTime.weekday]. Uses a fixed reference week (Jan 1, 2024 was a Monday)
/// so it works for any weekday number without a real date in hand.
String _consistencyWeekdayName(int weekday) =>
    DateFormat('EEEE').format(DateTime(2024, 1, weekday));

/// Localized short weekday name (e.g. "Mon"), same convention as
/// [_consistencyWeekdayName].
String _consistencyWeekdayShortName(int weekday) =>
    DateFormat('E').format(DateTime(2024, 1, weekday));

/// Renders a 7-column grid of [days] (a multiple of 7 — one row per week) as
/// a weekday header plus one [_ConsistencyDayCell] per day. Used both for a
/// list's full multi-exercise calendar and (with a single-item [exercises])
/// an individual exercise's detail calendar.
class _ConsistencyCalendarGrid extends StatelessWidget {
  final List<DateTime> days;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final List<TrackedExercise> exercises;
  final Map<DateTime, Map<String, int>> setsByDay;
  final bool showSetCounts;
  final double cellHeight;
  final int startWeekday;
  final void Function(DateTime day, TrackedExercise exercise)? onSegmentTap;

  const _ConsistencyCalendarGrid({
    required this.days,
    required this.rangeStart,
    required this.rangeEnd,
    required this.exercises,
    required this.setsByDay,
    required this.showSetCounts,
    required this.cellHeight,
    required this.startWeekday,
    this.onSegmentTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBackground = Theme.of(context).scaffoldBackgroundColor;
    final weekRows = <Widget>[];
    for (var i = 0; i < days.length; i += 7) {
      final weekDays = days.sublist(i, (i + 7).clamp(0, days.length));
      weekRows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              for (final day in weekDays)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _ConsistencyDayCell(
                      day: day,
                      height: cellHeight,
                      dimmed: day.isBefore(rangeStart) || day.isAfter(rangeEnd),
                      exercises: exercises,
                      setsForDay: setsByDay[_dateOnly(day)] ?? const {},
                      showSetCounts: showSetCounts,
                      pageBackground: pageBackground,
                      onSegmentTap: onSegmentTap == null
                          ? null
                          : (ex) => onSegmentTap!(day, ex),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    _consistencyWeekdayShortName(
                      ((startWeekday - 1 + i) % 7) + 1,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ...weekRows,
      ],
    );
  }
}

/// One day's cell: a day-number label plus a row of equal-width colored
/// segments, one per tracked exercise done that day (in list order), each
/// tappable on its own. Segment opacity reflects sets-done vs target
/// ([segmentOpacity]); an optional sets-done number overlay uses a
/// contrast-safe color ([segmentOverlayTextColor]). Exercises with 0 sets
/// that day contribute no segment at all.
class _ConsistencyDayCell extends StatelessWidget {
  final DateTime day;
  final double height;
  final bool dimmed;
  final List<TrackedExercise> exercises;
  final Map<String, int> setsForDay;
  final bool showSetCounts;
  final Color pageBackground;
  final void Function(TrackedExercise exercise)? onSegmentTap;

  const _ConsistencyDayCell({
    required this.day,
    required this.height,
    required this.dimmed,
    required this.exercises,
    required this.setsForDay,
    required this.showSetCounts,
    required this.pageBackground,
    this.onSegmentTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = exercises
        .where((e) => (setsForDay[e.exerciseName] ?? 0) > 0)
        .toList();
    final emptyColor = isDark ? const Color(0xFF232F3E) : Colors.grey.shade100;

    return Opacity(
      opacity: dimmed ? 0.35 : 1.0,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
            Expanded(
              child: active.isEmpty
                  ? Container(color: emptyColor)
                  : Row(
                      children: [
                        for (final exercise in active)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onSegmentTap == null
                                  ? null
                                  : () => onSegmentTap!(exercise),
                              child: Builder(
                                builder: (context) {
                                  final setsDone =
                                      setsForDay[exercise.exerciseName] ?? 0;
                                  final base =
                                      kConsistencyColorPalette[exercise
                                          .colorIndex];
                                  final opacity = segmentOpacity(
                                    setsDone: setsDone,
                                    targetSetsPerDay: exercise.targetSetsPerDay,
                                  );
                                  return Container(
                                    color: base.withValues(alpha: opacity),
                                    alignment: Alignment.center,
                                    child: showSetCounts
                                        ? Text(
                                            '$setsDone',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: segmentOverlayTextColor(
                                                base: base,
                                                opacity: opacity,
                                                pageBackground: pageBackground,
                                              ),
                                            ),
                                          )
                                        : null,
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for adding/reordering/removing tracked exercises in a
/// [ConsistencyExerciseList], and jumping into color/target-sets editing for
/// each. Calls [onChanged] with the updated list after every mutation so the
/// caller can persist it immediately (mirrors ActiveWorkoutPage's
/// persist-after-every-change convention rather than a single final save).
class _ManageExercisesSheet extends StatefulWidget {
  final ConsistencyExerciseList list;
  final List<WorkoutSession> history;
  final List<WorkoutTemplate> templates;
  final ValueChanged<ConsistencyExerciseList> onChanged;
  final ValueChanged<WorkoutTemplate>? onUpdateTemplate;

  const _ManageExercisesSheet({
    required this.list,
    required this.history,
    this.templates = const [],
    required this.onChanged,
    this.onUpdateTemplate,
  });

  @override
  State<_ManageExercisesSheet> createState() => _ManageExercisesSheetState();
}

class _ManageExercisesSheetState extends State<_ManageExercisesSheet> {
  late List<TrackedExercise> _exercises;
  final TextEditingController _nameController = TextEditingController();
  TrackedItemKind _addMode = TrackedItemKind.exercise;

  @override
  void initState() {
    super.initState();
    _exercises = List.of(widget.list.exercises);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _commit() {
    widget.onChanged(widget.list.copyWith(exercises: List.of(_exercises)));
  }

  List<String> _historyExerciseNames() {
    final names = <String>{};
    for (final session in widget.history) {
      for (final log in session.logs) {
        names.add(log.exerciseName);
      }
    }
    return names.toList()..sort();
  }

  List<String> _suggestions(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    final already = _exercises
        .map((e) => e.exerciseName.trim().toLowerCase())
        .toSet();
    final all = <String>{...kCommonExerciseNames, ..._historyExerciseNames()};
    final matches =
        all
            .where(
              (name) =>
                  name.toLowerCase().contains(q) &&
                  !already.contains(name.trim().toLowerCase()),
            )
            .toList()
          ..sort();
    return matches.take(8).toList();
  }

  void _addExercise(String name) {
    if (_exercises.length >= ConsistencyExerciseList.maxExercises) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final alreadyTracked = _exercises.any(
      (e) => e.exerciseName.trim().toLowerCase() == trimmed.toLowerCase(),
    );
    if (alreadyTracked) return;
    setState(() {
      _exercises.add(
        TrackedExercise(
          id: 'te_${DateTime.now().millisecondsSinceEpoch}',
          exerciseName: trimmed,
          colorIndex: nextAvailableConsistencyColorIndex(_exercises),
        ),
      );
      _nameController.clear();
    });
    _commit();
  }

  /// Workout templates not yet tracked in this list (matched by name,
  /// same convention as [TrackedExercise.exerciseName] dedupe).
  List<WorkoutTemplate> _availableTemplates() {
    final already = _exercises
        .map((e) => e.exerciseName.trim().toLowerCase())
        .toSet();
    return widget.templates
        .where((t) => !already.contains(t.name.trim().toLowerCase()))
        .toList();
  }

  void _addTemplate(WorkoutTemplate template) {
    if (_exercises.length >= ConsistencyExerciseList.maxExercises) return;
    final trimmed = template.name.trim();
    if (trimmed.isEmpty) return;
    final alreadyTracked = _exercises.any(
      (e) => e.exerciseName.trim().toLowerCase() == trimmed.toLowerCase(),
    );
    if (alreadyTracked) return;
    setState(() {
      _exercises.add(
        TrackedExercise(
          id: 'te_${DateTime.now().millisecondsSinceEpoch}',
          exerciseName: trimmed,
          colorIndex: nextAvailableConsistencyColorIndex(_exercises),
          kind: TrackedItemKind.template,
          templateId: template.id,
        ),
      );
    });
    _commit();
  }

  void _removeExercise(int index) {
    setState(() => _exercises.removeAt(index));
    _commit();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
    });
    _commit();
  }

  Future<void> _pickColor(int index) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExerciseColorPickerSheet(
        selectedIndex: _exercises[index].colorIndex,
      ),
    );
    if (chosen == null || !mounted) return;
    setState(
      () => _exercises[index] = _exercises[index].copyWith(colorIndex: chosen),
    );
    _commit();
  }

  Future<void> _editTargetSets(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(
      text: '${_exercises[index].targetSetsPerDay}',
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2A3A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _exercises[index].kind == TrackedItemKind.template
              ? l10n.get('targetTimesPerDay')
              : l10n.get('targetSetsPerDay'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 0) return;
              Navigator.pop(ctx);
              setState(
                () => _exercises[index] = _exercises[index].copyWith(
                  targetSetsPerDay: value,
                ),
              );
              _commit();
            },
            child: Text(
              l10n.get('save'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// The current [WorkoutTemplate] this tracked entry matches — by
  /// [TrackedExercise.templateId] when present, else by name (for entries
  /// that predate that field) — or null if it's since been deleted from My
  /// Workouts.
  WorkoutTemplate? _matchingTemplate(TrackedExercise trackedItem) {
    if (trackedItem.templateId != null && trackedItem.templateId!.isNotEmpty) {
      for (final t in widget.templates) {
        if (t.id == trackedItem.templateId) return t;
      }
    }
    final key = trackedItem.exerciseName.trim().toLowerCase();
    for (final t in widget.templates) {
      if (t.name.trim().toLowerCase() == key) return t;
    }
    return null;
  }

  /// Renames the actual [WorkoutTemplate] (so My Workouts and future logged
  /// sessions use the new name too, via [ValueChanged<WorkoutTemplate>]
  /// onUpdateTemplate) and updates this tracked entry's matched name to
  /// match. If the underlying template was deleted elsewhere, falls back to
  /// renaming just this tracked entry.
  Future<void> _renameTemplate(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(
      text: _exercises[index].exerciseName,
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2A3A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.get('renameWorkoutTemplate'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            labelText: l10n.get('workoutTemplate'),
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => Navigator.pop(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.clear();
              Navigator.pop(ctx);
            },
            child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.get('save'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ).then((_) {
      final trimmed = controller.text.trim();
      if (trimmed.isEmpty) return;
      final current = _exercises[index];
      if (trimmed.toLowerCase() == current.exerciseName.trim().toLowerCase()) {
        return;
      }
      final collides = _exercises.asMap().entries.any(
        (e) =>
            e.key != index &&
            e.value.exerciseName.trim().toLowerCase() == trimmed.toLowerCase(),
      );
      if (collides) return;

      final matched = _matchingTemplate(current);
      if (matched != null) {
        widget.onUpdateTemplate?.call(matched.copyWith(name: trimmed));
      }
      setState(
        () => _exercises[index] = current.copyWith(
          exerciseName: trimmed,
          templateId: matched?.id ?? current.templateId,
        ),
      );
      _commit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2A3A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  l10n.get('manageExercises'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    if (_exercises.length <
                        ConsistencyExerciseList.maxExercises) ...[
                      SegmentedButton<TrackedItemKind>(
                        style: ButtonStyle(
                          minimumSize: WidgetStateProperty.all(
                            const Size(0, 48),
                          ),
                          backgroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return colorScheme.primary;
                            }
                            return isDark
                                ? const Color(0xFF232F3E)
                                : Colors.grey.shade200;
                          }),
                          foregroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.white;
                            }
                            return isDark ? Colors.white : Colors.black87;
                          }),
                        ),
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: TrackedItemKind.exercise,
                            label: Text(l10n.get('exercise')),
                            icon: const Icon(Icons.fitness_center, size: 18),
                          ),
                          ButtonSegment(
                            value: TrackedItemKind.template,
                            label: Text(l10n.get('workoutTemplate')),
                            icon: const Icon(Icons.list_alt, size: 18),
                          ),
                        ],
                        selected: {_addMode},
                        onSelectionChanged: (selection) =>
                            setState(() => _addMode = selection.first),
                      ),
                      const SizedBox(height: 12),
                      if (_addMode == TrackedItemKind.exercise) ...[
                        TextField(
                          controller: _nameController,
                          style: TextStyle(
                            fontSize: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.get('addToList'),
                            hintText: l10n.get('exerciseNameHint'),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: l10n.get('add'),
                              icon: const Icon(Icons.add),
                              onPressed: () =>
                                  _addExercise(_nameController.text),
                            ),
                          ),
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: _addExercise,
                        ),
                        Builder(
                          builder: (context) {
                            final suggestions = _suggestions(
                              _nameController.text,
                            );
                            if (suggestions.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 8),
                                ...suggestions.map(
                                  (name) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Material(
                                      color: isDark
                                          ? const Color(0xFF232F3E)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        onTap: () => _addExercise(name),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          child: Text(
                                            l10n.localizeExerciseName(name),
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ] else ...[
                        Text(
                          l10n.get('chooseTemplateToTrack'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            if (widget.templates.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  l10n.get('noTemplatesToTrackHint'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              );
                            }
                            final available = _availableTemplates();
                            if (available.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  l10n.get('allTemplatesTracked'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final template in available)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Material(
                                      color: isDark
                                          ? const Color(0xFF232F3E)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        onTap: () => _addTemplate(template),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.list_alt,
                                                size: 20,
                                                color: colorScheme.primary,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  l10n.localizeWorkoutTemplateName(
                                                    template.name,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              const Icon(Icons.add, size: 20),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ] else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          l10n.get('maxExercisesReached'),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_exercises.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          l10n.get('noExercisesInList'),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _exercises.length,
                        onReorder: _reorder,
                        itemBuilder: (context, index) {
                          final te = _exercises[index];
                          final color = kConsistencyColorPalette[te.colorIndex];
                          return Padding(
                            key: ValueKey(te.id),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: isDark
                                  ? const Color(0xFF232F3E)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Semantics(
 button: true,
 label: l10n.get('changeColor'),
 excludeSemantics: true,
 child: GestureDetector(
                                      onTap: () => _pickColor(index),
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white24
                                                : Colors.black12,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    )),
                                    const SizedBox(width: 12),
                                    Icon(
                                      te.kind == TrackedItemKind.template
                                          ? Icons.list_alt
                                          : Icons.fitness_center,
                                      size: 16,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        te.kind == TrackedItemKind.template
                                            ? l10n.localizeWorkoutTemplateName(
                                                te.exerciseName,
                                              )
                                            : l10n.localizeExerciseName(
                                                te.exerciseName,
                                              ),
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (te.kind == TrackedItemKind.template)
                                      IconButton(
                                        onPressed: () => _renameTemplate(index),
                                        icon: Icon(
                                          Icons.edit,
                                          size: 20,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                        tooltip: l10n.get(
                                          'renameWorkoutTemplate',
                                        ),
                                      ),
                                    Semantics(button: true, child: GestureDetector(
                                      onTap: () => _editTargetSets(index),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '${te.targetSetsPerDay}/${l10n.get('day')}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    )),
                                    IconButton(
                                      tooltip: l10n.get('remove'),
                                      onPressed: () => _removeExercise(index),
                                      icon: Icon(
                                        Icons.close,
                                        size: 22,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Icon(
                                        Icons.drag_handle,
                                        size: 24,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bottom sheet: pick one of the 14 [kConsistencyColorPalette] swatches.
/// Pops with the chosen index, or null if dismissed.
class _ExerciseColorPickerSheet extends StatelessWidget {
  final int selectedIndex;

  const _ExerciseColorPickerSheet({required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2A3A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.get('chooseColor'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < kConsistencyColorPalette.length; i++)
                Semantics(
 button: true,
 selected: i == selectedIndex,
 label: '${l10n.get('colorLabel')} ${i + 1}',
 excludeSemantics: true,
 child: GestureDetector(
                  onTap: () => Navigator.pop(context, i),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: kConsistencyColorPalette[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == selectedIndex
                            ? (isDark ? Colors.white : Colors.black87)
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: i == selectedIndex
                        ? const Icon(Icons.check, color: Colors.white, size: 28)
                        : null,
                  ),
                )),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Week / fortnight / month selector, shared by the list calendar and the
/// single-exercise detail calendar so both browse the same way.
class _ConsistencyViewModeToggle extends StatelessWidget {
  final ConsistencyViewMode selected;
  final ValueChanged<ConsistencyViewMode> onChanged;

  const _ConsistencyViewModeToggle({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    const labelStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);
    return SegmentedButton<ConsistencyViewMode>(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size(0, 48)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return isDark ? const Color(0xFF232F3E) : Colors.grey.shade200;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? Colors.white : Colors.black87;
        }),
      ),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: ConsistencyViewMode.week,
          label: Text(l10n.get('viewWeek'), style: labelStyle),
        ),
        ButtonSegment(
          value: ConsistencyViewMode.fortnight,
          label: Text(l10n.get('viewFortnight'), style: labelStyle),
        ),
        ButtonSegment(
          value: ConsistencyViewMode.month,
          label: Text(l10n.get('viewMonth'), style: labelStyle),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// Bottom sheet listing the 7 weekdays; pops with the chosen weekday
/// (1=Mon..7=Sun) or null if dismissed. Shared by the list calendar's and the
/// exercise detail calendar's week-start setting.
Future<int?> showConsistencyWeekStartPicker(BuildContext context, int current) {
  final l10n = AppLocalizations.of(context)!;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final colorScheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(ctx).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2A3A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                l10n.get('weekStartsOn'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var weekday = 1; weekday <= 7; weekday++)
                      ListTile(
                        title: Text(
                          _consistencyWeekdayName(weekday),
                          style: TextStyle(
                            fontSize: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        trailing: weekday == current
                            ? Icon(Icons.check, color: colorScheme.primary)
                            : null,
                        onTap: () => Navigator.pop(ctx, weekday),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}

/// One legend row: color swatch + exercise name, tappable to open the
/// exercise's detail page (mirrors tapping the exercise's segment on the
/// calendar itself).
class _LegendRow extends StatelessWidget {
  final TrackedExercise exercise;
  final VoidCallback onTap;

  const _LegendRow({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = kConsistencyColorPalette[exercise.colorIndex];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                exercise.kind == TrackedItemKind.template
                    ? l10n.localizeWorkoutTemplateName(exercise.exerciseName)
                    : l10n.localizeExerciseName(exercise.exerciseName),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

/// One calendar day's logged sets for a single exercise, across every
/// session on that day.
class _ExerciseDetailEntry {
  final DateTime day;
  final List<ExerciseLog> logs;

  const _ExerciseDetailEntry({required this.day, required this.logs});

  int get setsDone => logs.length;

  DateTime get earliestTimestamp =>
      logs.map((l) => l.timestamp).reduce((a, b) => a.isBefore(b) ? a : b);
}

/// Every day (across all of [history], not just the visible range) that
/// [exerciseName] was logged, newest first. Matching is case-insensitive and
/// trimmed, same convention as [buildConsistencySetsByDay].
List<_ExerciseDetailEntry> _buildExerciseDetailHistory(
  List<WorkoutSession> history,
  String exerciseName,
) {
  final matchKey = exerciseName.trim().toLowerCase();
  final byDay = <DateTime, List<ExerciseLog>>{};
  for (final session in history) {
    for (final log in session.logs) {
      if (log.exerciseName.trim().toLowerCase() != matchKey) continue;
      final day = _dateOnly(log.timestamp);
      byDay.putIfAbsent(day, () => []).add(log);
    }
  }
  final entries =
      byDay.entries
          .map((e) => _ExerciseDetailEntry(day: e.key, logs: e.value))
          .toList()
        ..sort((a, b) => b.day.compareTo(a.day));
  return entries;
}

/// One calendar day's completed sessions for a single tracked workout
/// template, across every session on that day.
class _TemplateDetailEntry {
  final DateTime day;
  final List<WorkoutSession> sessions;

  const _TemplateDetailEntry({required this.day, required this.sessions});

  int get timesDone => sessions.length;

  int get totalDurationSeconds =>
      sessions.fold(0, (sum, s) => sum + s.durationSeconds);

  DateTime get earliestTimestamp =>
      sessions.map((s) => s.startTime).reduce((a, b) => a.isBefore(b) ? a : b);
}

/// Every day (across all of [history], not just the visible range)
/// [trackedItem] was completed, newest first. Matching follows the same
/// id-first-then-name convention as [buildConsistencySetsByDay], bucketed by
/// [WorkoutSession.startTime] (a session is one atomic unit).
List<_TemplateDetailEntry> _buildTemplateDetailHistory(
  List<WorkoutSession> history,
  TrackedExercise trackedItem,
) {
  final hasId =
      trackedItem.templateId != null && trackedItem.templateId!.isNotEmpty;
  final matchKey = trackedItem.exerciseName.trim().toLowerCase();
  final byDay = <DateTime, List<WorkoutSession>>{};
  for (final session in history) {
    final matches = hasId
        ? session.templateId == trackedItem.templateId
        : session.templateName.trim().toLowerCase() == matchKey;
    if (!matches) continue;
    final day = _dateOnly(session.startTime);
    byDay.putIfAbsent(day, () => []).add(session);
  }
  final entries =
      byDay.entries
          .map((e) => _TemplateDetailEntry(day: e.key, sessions: e.value))
          .toList()
        ..sort((a, b) => b.day.compareTo(a.day));
  return entries;
}

/// Full-screen drill-down for one tracked exercise: its own single-exercise
/// calendar (independent view-mode/week-start/show-counts state, defaulted
/// from the parent list but browsable on its own), summary totals, and a
/// complete chronological list of every day it was logged with per-day
/// set/rep (or duration) detail.
class _ExerciseDetailPage extends StatefulWidget {
  final TrackedExercise exercise;
  final List<WorkoutSession> history;
  final ConsistencyViewMode defaultViewMode;
  final int defaultStartWeekday;
  final bool defaultShowSetCounts;

  const _ExerciseDetailPage({
    required this.exercise,
    required this.history,
    required this.defaultViewMode,
    required this.defaultStartWeekday,
    required this.defaultShowSetCounts,
  });

  @override
  State<_ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<_ExerciseDetailPage> {
  late DateTime _anchor;
  late ConsistencyViewMode _viewMode;
  late int _startWeekday;
  late bool _showSetCounts;

  @override
  void initState() {
    super.initState();
    _anchor = DateTime.now();
    _viewMode = widget.defaultViewMode;
    _startWeekday = widget.defaultStartWeekday;
    _showSetCounts = widget.defaultShowSetCounts;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = kConsistencyColorPalette[widget.exercise.colorIndex];

    final range = computeConsistencyRange(
      anchor: _anchor,
      mode: _viewMode,
      startWeekday: _startWeekday,
    );
    final gridDays = _viewMode == ConsistencyViewMode.month
        ? computeConsistencyMonthGridDays(_anchor, _startWeekday)
        : range.days;
    final setsByDay = buildConsistencySetsByDay(
      history: widget.history,
      trackedExercises: [widget.exercise],
    );
    final cellHeight = _viewMode == ConsistencyViewMode.month ? 56.0 : 80.0;

    final isTemplateKind = widget.exercise.kind == TrackedItemKind.template;
    final exerciseEntries = isTemplateKind
        ? const <_ExerciseDetailEntry>[]
        : _buildExerciseDetailHistory(
            widget.history,
            widget.exercise.exerciseName,
          );
    final templateEntries = isTemplateKind
        ? _buildTemplateDetailHistory(widget.history, widget.exercise)
        : const <_TemplateDetailEntry>[];
    final totalTimesDone = isTemplateKind
        ? templateEntries.length
        : exerciseEntries.length;
    final totalSets = exerciseEntries.fold<int>(
      0,
      (sum, e) => sum + e.setsDone,
    );
    final allLogs = exerciseEntries.expand((e) => e.logs).toList();
    final totalReps = allLogs
        .where((l) => !l.isDurationSet)
        .fold<int>(0, (sum, l) => sum + l.reps);
    final totalDurationSeconds = isTemplateKind
        ? templateEntries.fold<int>(0, (sum, e) => sum + e.totalDurationSeconds)
        : allLogs
              .where((l) => l.isDurationSet)
              .fold<int>(0, (sum, l) => sum + (l.durationSeconds ?? 0));

    final displayEntries = isTemplateKind
        ? templateEntries
              .map(
                (e) => (
                  day: e.day,
                  time: e.earliestTimestamp,
                  summary: _formatTemplateDetailEntrySummary(e),
                ),
              )
              .toList()
        : exerciseEntries
              .map(
                (e) => (
                  day: e.day,
                  time: e.earliestTimestamp,
                  summary: _formatDetailEntrySummary(e, l10n),
                ),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                isTemplateKind
                    ? l10n.localizeWorkoutTemplateName(
                        widget.exercise.exerciseName,
                      )
                    : l10n.localizeExerciseName(widget.exercise.exerciseName),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (isTemplateKind) ...[
              Row(
                children: [
                  Expanded(
                    child: _DetailStatTile(
                      label: l10n.get('timesDone'),
                      value: '$totalTimesDone',
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DetailStatTile(
                      label: l10n.get('totalDuration'),
                      value: formatDurationMmSs(totalDurationSeconds),
                      color: color,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _DetailStatTile(
                      label: l10n.get('timesDone'),
                      value: '$totalTimesDone',
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DetailStatTile(
                      label: l10n.get('totalSets'),
                      value: '$totalSets',
                      color: color,
                    ),
                  ),
                ],
              ),
              if (totalDurationSeconds > 0) ...[
                const SizedBox(height: 12),
                _DetailStatTile(
                  label: l10n.get('totalDuration'),
                  value: formatDurationMmSs(totalDurationSeconds),
                  color: color,
                ),
              ] else ...[
                const SizedBox(height: 12),
                _DetailStatTile(
                  label: l10n.get('totalReps'),
                  value: '$totalReps',
                  color: color,
                ),
              ],
            ],
            const SizedBox(height: 20),
            _ConsistencyViewModeToggle(
              selected: _viewMode,
              onChanged: (mode) => setState(() {
                _viewMode = mode;
                _anchor = DateTime.now();
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final chosen = await showConsistencyWeekStartPicker(
                        context,
                        _startWeekday,
                      );
                      if (chosen != null) {
                        setState(() {
                          _startWeekday = chosen;
                          _anchor = DateTime.now();
                        });
                      }
                    },
                    icon: const Icon(Icons.event_repeat, size: 18),
                    label: Text(
                      '${l10n.get('weekStartsOn')}: ${_consistencyWeekdayName(_startWeekday)}',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _showSetCounts,
              onChanged: (v) => setState(() => _showSetCounts = v),
              title: Text(
                l10n.get('showSetCounts'),
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: l10n.get('previousPeriod'),
                  onPressed: () => setState(() {
                    _anchor = nextConsistencyAnchor(
                      _anchor,
                      _viewMode,
                      forward: false,
                    );
                  }),
                  icon: const Icon(Icons.chevron_left, size: 30),
                ),
                Expanded(
                  child: Text(
                    _viewMode == ConsistencyViewMode.month
                        ? DateFormat('MMMM yyyy').format(_anchor)
                        : '${DateFormat('MMM d').format(range.start)} – '
                              '${DateFormat('MMM d, yyyy').format(range.end)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.get('nextPeriod'),
                  onPressed: () => setState(() {
                    _anchor = nextConsistencyAnchor(
                      _anchor,
                      _viewMode,
                      forward: true,
                    );
                  }),
                  icon: const Icon(Icons.chevron_right, size: 30),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ConsistencyCalendarGrid(
              days: gridDays,
              rangeStart: range.start,
              rangeEnd: range.end,
              exercises: [widget.exercise],
              setsByDay: setsByDay,
              showSetCounts: _showSetCounts,
              cellHeight: cellHeight,
              startWeekday: _startWeekday,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.get('pastHistory'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            if (displayEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l10n.get(
                    isTemplateKind
                        ? 'noHistoryForTemplate'
                        : 'noHistoryForExercise',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              )
            else
              for (final entry in displayEntries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isDark
                        ? const Color(0xFF1A2634)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  DateFormat('MMM d, yyyy').format(entry.day),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat.jm().format(entry.time),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            entry.summary,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _formatDetailEntrySummary(
    _ExerciseDetailEntry entry,
    AppLocalizations l10n,
  ) {
    final sorted = List<ExerciseLog>.from(entry.logs)
      ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
    if (sorted.any((l) => l.isDurationSet)) {
      final durations = sorted
          .map((l) => formatDurationMmSs(l.durationSeconds ?? 0))
          .join(', ');
      return durations;
    }
    final reps = sorted.map((l) => '${l.reps}').join(', ');
    return '$reps ${l10n.reps}';
  }

  /// Comma-joined session durations for a template detail entry, mirroring
  /// [_formatDetailEntrySummary]'s duration-set formatting.
  String _formatTemplateDetailEntrySummary(_TemplateDetailEntry entry) {
    final sorted = List<WorkoutSession>.from(entry.sessions)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return sorted.map((s) => formatDurationMmSs(s.durationSeconds)).join(', ');
  }
}

/// Small stat card for the exercise detail page's summary totals.
class _DetailStatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailStatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
