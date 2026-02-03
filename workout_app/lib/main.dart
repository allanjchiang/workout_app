import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'l10n/app_localizations.dart';

void main() {
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

/// Exercise within a template with target reps/weight
class TemplateExercise {
  final Exercise exercise;
  final int targetReps;
  final double targetWeight;
  final int sets;

  const TemplateExercise({
    required this.exercise,
    this.targetReps = 10,
    this.targetWeight = 0,
    this.sets = 3,
  });

  Map<String, dynamic> toJson() => {
    'exercise': exercise.toJson(),
    'targetReps': targetReps,
    'targetWeight': targetWeight,
    'sets': sets,
  };

  factory TemplateExercise.fromJson(Map<String, dynamic> json) =>
      TemplateExercise(
        exercise: Exercise.fromJson(json['exercise'] as Map<String, dynamic>),
        targetReps: json['targetReps'] as int? ?? 10,
        targetWeight: (json['targetWeight'] as num?)?.toDouble() ?? 0,
        sets: json['sets'] as int? ?? 3,
      );

  TemplateExercise copyWith({
    Exercise? exercise,
    int? targetReps,
    double? targetWeight,
    int? sets,
  }) => TemplateExercise(
    exercise: exercise ?? this.exercise,
    targetReps: targetReps ?? this.targetReps,
    targetWeight: targetWeight ?? this.targetWeight,
    sets: sets ?? this.sets,
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

/// Logged set during a workout
class ExerciseLog {
  final String exerciseId;
  final String exerciseName;
  final int setNumber;
  final int reps;
  final double weight;
  final DateTime timestamp;

  const ExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.setNumber,
    required this.reps,
    required this.weight,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'setNumber': setNumber,
    'reps': reps,
    'weight': weight,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
    exerciseId: json['exerciseId'] as String,
    exerciseName: json['exerciseName'] as String,
    setNumber: json['setNumber'] as int,
    reps: json['reps'] as int,
    weight: (json['weight'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
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
  String _weightUnit = 'kg';

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensureDefaultTemplateAndMigrate();
      }
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
    const defaultTemplateId = 'default_shoulder_workout';

    final hasDefault = templates.any((t) => t.id == defaultTemplateId);
    if (!hasDefault) {
      final shoulderTemplate = _createDefaultShoulderTemplate(l10n);
      setState(() {
        templates.insert(0, shoulderTemplate);
      });
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
        final defaultTemplate = templates.firstWhere(
          (t) => t.id == defaultTemplateId,
          orElse: () => _createDefaultShoulderTemplate(l10n),
        );
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

  /// Creates the default Shoulder Workout template with the 5 original exercises
  WorkoutTemplate _createDefaultShoulderTemplate(AppLocalizations l10n) {
    return WorkoutTemplate(
      id: 'default_shoulder_workout',
      name: l10n.get('shoulderWorkoutTemplate'),
      description: l10n.get('shoulderWorkoutTemplateDesc'),
      exercises: [
        TemplateExercise(
          exercise: Exercise(
            id: 'shoulderPress',
            name: l10n.get('shoulderPress'),
            description: l10n.get('shoulderPressDesc'),
            iconKey: 'arrow_upward',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: Exercise(
            id: 'lateralRaise',
            name: l10n.get('lateralRaise'),
            description: l10n.get('lateralRaiseDesc'),
            iconKey: 'open_with',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: Exercise(
            id: 'frontRaise',
            name: l10n.get('frontRaise'),
            description: l10n.get('frontRaiseDesc'),
            iconKey: 'arrow_forward',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: Exercise(
            id: 'reverseFly',
            name: l10n.get('reverseFly'),
            description: l10n.get('reverseFlyDesc'),
            iconKey: 'compare_arrows',
          ),
          targetReps: 10,
          sets: 3,
        ),
        TemplateExercise(
          exercise: Exercise(
            id: 'shrugs',
            name: l10n.get('shrugs'),
            description: l10n.get('shrugsDesc'),
            iconKey: 'keyboard_double_arrow_up',
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

  void _addSession(WorkoutSession session) {
    setState(() {
      history.insert(0, session);
    });
    _saveHistory();
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
        onStartWorkout: (template) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveWorkoutPage(
                template: template,
                onComplete: _addSession,
                history: history,
                weightUnit: _weightUnit,
              ),
            ),
          );
        },
      ),
      HistoryPage(history: history, weightUnit: _weightUnit),
      StatisticsPage(history: history, weightUnit: _weightUnit),
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

  const TemplatesPage({
    super.key,
    required this.templates,
    required this.onAddTemplate,
    required this.onUpdateTemplate,
    required this.onDeleteTemplate,
    required this.onStartWorkout,
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _TemplateCard(
            template: template,
            onTap: () => onStartWorkout(template),
            onEdit: () => _showEditTemplateDialog(context, l10n, template),
            onDelete: () => _confirmDelete(context, l10n, template),
          ),
        );
      },
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
          '${l10n.get('deleteWorkoutConfirm')} "${template.name}"?',
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

  const _TemplateCard({
    required this.template,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label:
          '${template.name}, ${template.exercises.length} ${l10n.get('exercises')}',
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
                            template.name,
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _addExercise() {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final descController = TextEditingController();
    int selectedIconIndex = 0;
    int targetReps = 10;
    int sets = 3;
    double targetWeight = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            l10n.get('addExercise'),
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
                const SizedBox(height: 16),
                // Target sets and reps
                Row(
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
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  if (sets > 1) {
                                    setDialogState(() => sets--);
                                  }
                                },
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text(
                                '$sets',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: () => setDialogState(() => sets++),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
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
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  if (targetReps > 1) {
                                    setDialogState(() => targetReps--);
                                  }
                                },
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text(
                                '$targetReps',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    setDialogState(() => targetReps++),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
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
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  iconKey: kExerciseIconKeys[selectedIconIndex],
                );
                setState(() {
                  exercises.add(
                    TemplateExercise(
                      exercise: exercise,
                      targetReps: targetReps,
                      targetWeight: targetWeight,
                      sets: sets,
                    ),
                  );
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(
                l10n.get('add'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
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
              const SizedBox(height: 12),
              // Exercise list
              ...exercises.asMap().entries.map((entry) {
                final index = entry.key;
                final templateExercise = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExerciseListItem(
                    templateExercise: templateExercise,
                    onDelete: () {
                      setState(() {
                        exercises.removeAt(index);
                      });
                    },
                  ),
                );
              }),
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

  const _ExerciseListItem({
    required this.templateExercise,
    required this.onDelete,
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
                  exercise.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '${templateExercise.sets} ${l10n.get('sets')} × ${templateExercise.targetReps} ${l10n.reps}',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
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
  final Function(WorkoutSession) onComplete;
  final List<WorkoutSession> history;
  final String weightUnit;

  const ActiveWorkoutPage({
    super.key,
    required this.template,
    required this.onComplete,
    required this.history,
    this.weightUnit = 'kg',
  });

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  late DateTime startTime;
  Timer? workoutTimer;
  int elapsedSeconds = 0;
  int currentExerciseIndex = 0;
  int currentSet = 1;
  int currentReps = 0;
  double currentWeight = 0;
  List<ExerciseLog> logs = [];
  final AudioPlayer audioPlayer = AudioPlayer();

  // Rest timer
  Timer? restTimer;
  int restSeconds = 0;
  bool isResting = false;
  int _defaultRestSeconds = 60;

  // Previous best reps for each exercise
  Map<String, int> previousBestReps = {};

  String get _weightUnit => widget.weightUnit;

  static const double _kgToLbs = 2.2046226218;

  double _kgToDisplay(double kg) => _weightUnit == 'lbs' ? kg * _kgToLbs : kg;

  double _displayToKg(double display) =>
      _weightUnit == 'lbs' ? display / _kgToLbs : display;

  String _formatWeightDisplay(double kg) {
    final v = _kgToDisplay(kg);
    return v == v.toInt() ? '${v.toInt()}' : v.toStringAsFixed(1);
  }

  double? _getLastWeightForExercise(String exerciseId) {
    for (final session in widget.history) {
      for (final log in session.logs.reversed) {
        if (log.exerciseId == exerciseId && log.weight > 0) {
          return log.weight;
        }
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    startTime = DateTime.now();
    _loadPreviousBestReps();
    _loadDefaultRestSeconds();
    _startWorkoutTimer();
    _initializeCurrentExercise();
  }

  Future<void> _loadDefaultRestSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('default_rest_seconds');
    if (saved != null && mounted) {
      setState(() => _defaultRestSeconds = saved.clamp(30, 600));
    }
  }

  void _loadPreviousBestReps() {
    // Find the best (highest) reps for each exercise from history
    for (final session in widget.history) {
      for (final log in session.logs) {
        final currentBest = previousBestReps[log.exerciseId] ?? 0;
        if (log.reps > currentBest) {
          previousBestReps[log.exerciseId] = log.reps;
        }
      }
    }
  }

  @override
  void dispose() {
    workoutTimer?.cancel();
    restTimer?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }

  void _initializeCurrentExercise() {
    if (widget.template.exercises.isNotEmpty) {
      final current = widget.template.exercises[currentExerciseIndex];
      currentReps = current.targetReps;
      // Use last logged weight for this exercise, else template target
      final lastWeight = _getLastWeightForExercise(current.exercise.id);
      currentWeight = lastWeight ?? current.targetWeight;
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
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2A3A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      ),
    );
  }

  void _logSet() {
    final current = widget.template.exercises[currentExerciseIndex];
    final log = ExerciseLog(
      exerciseId: current.exercise.id,
      exerciseName: current.exercise.name,
      setNumber: currentSet,
      reps: currentReps,
      weight: currentWeight,
      timestamp: DateTime.now(),
    );
    logs.add(log);

    // Move to next set or exercise
    if (currentSet < current.sets) {
      setState(() {
        currentSet++;
      });
      _startRestTimer();
    } else if (currentExerciseIndex < widget.template.exercises.length - 1) {
      setState(() {
        currentExerciseIndex++;
        currentSet = 1;
        _initializeCurrentExercise();
      });
      _startRestTimer();
    } else {
      _finishWorkout();
    }
  }

  void _startRestTimer() {
    setState(() {
      isResting = true;
      restSeconds = _defaultRestSeconds;
    });

    restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (restSeconds > 0) {
          restSeconds--;
        } else {
          timer.cancel();
          isResting = false;
          _playBeep();
        }
      });
    });
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
    });
  }

  Future<void> _playBeep() async {
    try {
      await audioPlayer.play(AssetSource('audio/timer_beep.wav'));
    } catch (e) {
      // Ignore audio errors
    }
  }

  void _finishWorkout() {
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

    widget.onComplete(session);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Workout completed!', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _confirmExit() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: const TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (logs.isNotEmpty) {
                _finishWorkout();
              } else {
                workoutTimer?.cancel();
                restTimer?.cancel();
                Navigator.pop(context);
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
    final current = widget.template.exercises[currentExerciseIndex];
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
            widget.template.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            onPressed: _confirmExit,
            icon: const Icon(Icons.close, size: 28),
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
              ? _buildRestScreen(l10n)
              : _buildExerciseScreen(l10n, current),
        ),
      ),
    );
  }

  Widget _buildRestScreen(AppLocalizations l10n) {
    // Elderly-friendly: large text, large touch targets (min 56–64dp)
    const double largeFontSize = 28;
    const double timerFontSize = 96;
    const double buttonFontSize = 22;
    const double minTapHeight = 64;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.get('rest'),
              style: const TextStyle(
                fontSize: largeFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _formatDuration(restSeconds),
              style: TextStyle(
                fontSize: timerFontSize,
                fontWeight: FontWeight.bold,
                color: restSeconds <= 10 ? Colors.red : Colors.blue,
              ),
            ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseScreen(AppLocalizations l10n, TemplateExercise current) {
    final completedExerciseIds = <String>{};
    for (final exercise in widget.template.exercises) {
      final completedSets = logs
          .where((log) => log.exerciseId == exercise.exercise.id)
          .map((log) => log.setNumber)
          .toSet()
          .length;
      if (completedSets >= exercise.sets) {
        completedExerciseIds.add(exercise.exercise.id);
      }
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  '${l10n.get('exercise')} ${currentExerciseIndex + 1}/${widget.template.exercises.length}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${l10n.get('set')} $currentSet/${current.sets}',
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
                Text(
                  current.exercise.name,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                // Show previous best reps if available
                if (previousBestReps.containsKey(current.exercise.id)) ...[
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
                          '${l10n.get('previousBest')}: ${previousBestReps[current.exercise.id]} ${l10n.reps}',
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
          const SizedBox(height: 20),
          // Workout plan overview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2634) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.get('workoutPlan'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.get('tapToJump'),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                ...widget.template.exercises.map((exercise) {
                  final isCurrent = exercise.exercise.id == current.exercise.id;
                  final isCompleted = completedExerciseIds.contains(
                    exercise.exercise.id,
                  );
                  final isAvailable = !isResting;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      button: true,
                      label:
                          '${exercise.exercise.name}, ${exercise.sets} ${l10n.get('sets')} × ${exercise.targetReps} ${l10n.reps}',
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: isAvailable
                              ? () {
                                  final newIndex = widget.template.exercises
                                      .indexOf(exercise);
                                  setState(() {
                                    currentExerciseIndex = newIndex;
                                    currentSet = 1;
                                    _initializeCurrentExercise();
                                  });
                                }
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? (isDark
                                        ? colorScheme.primary.withValues(
                                            alpha: 0.3,
                                          )
                                        : colorScheme.primary.withValues(
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
                                        exercise.exercise.name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        '${exercise.sets} ${l10n.get('sets')} × ${exercise.targetReps} ${l10n.reps}',
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
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(12),
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
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Weight counter (above reps) – vertical layout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2634) : Colors.white,
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
                // Minus button
                _LargeRoundButton(
                  icon: Icons.remove,
                  color: Colors.orange.shade400,
                  onPressed: () {
                    if (currentWeight > 0) {
                      setState(
                        () =>
                            currentWeight = (currentWeight - 0.5).clamp(0, 999),
                      );
                    }
                  },
                ),
                // Weight display (tappable)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showNumberInputDialog(
                      context: context,
                      title: _weightUnit == 'lbs'
                          ? l10n.get('weightLbs')
                          : l10n.get('weight'),
                      currentValue: _kgToDisplay(currentWeight),
                      isInteger: false,
                      accentColor: Colors.orange,
                      onSave: (value) =>
                          setState(() => currentWeight = _displayToKg(value)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _weightUnit == 'lbs'
                              ? l10n.get('weightLbs')
                              : l10n.get('weight'),
                          style: TextStyle(
                            fontSize: 16,
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
                                ? Colors.orange.withValues(alpha: 0.2)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.5),
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
                  ),
                ),
                // Plus button
                _LargeRoundButton(
                  icon: Icons.add,
                  color: Colors.green.shade400,
                  onPressed: () => setState(() => currentWeight += 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Reps counter (vertical layout)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2634) : Colors.white,
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
                // Minus button
                _LargeRoundButton(
                  icon: Icons.remove,
                  color: Colors.red.shade400,
                  onPressed: () {
                    if (currentReps > 0) {
                      setState(() => currentReps--);
                    }
                  },
                ),
                // Reps display (tappable)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showNumberInputDialog(
                      context: context,
                      title: l10n.reps,
                      currentValue: currentReps.toDouble(),
                      isInteger: true,
                      accentColor: colorScheme.primary,
                      onSave: (value) =>
                          setState(() => currentReps = value.toInt()),
                    ),
                    child: Column(
                      children: [
                        Text(
                          l10n.reps,
                          style: TextStyle(
                            fontSize: 16,
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
                                ? colorScheme.primary.withValues(alpha: 0.2)
                                : colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '$currentReps',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : colorScheme.primary,
                            ),
                          ),
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
                  ),
                ),
                // Plus button
                _LargeRoundButton(
                  icon: Icons.add,
                  color: Colors.green.shade400,
                  onPressed: () => setState(() => currentReps++),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Log set button
          SizedBox(
            height: 70,
            child: ElevatedButton.icon(
              onPressed: currentReps > 0 ? _logSet : null,
              icon: const Icon(Icons.check, size: 30),
              label: Text(
                currentExerciseIndex == widget.template.exercises.length - 1 &&
                        currentSet == current.sets
                    ? l10n.get('finishWorkout')
                    : l10n.get('logSet'),
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
          const SizedBox(height: 16),
          // Logged sets for this exercise
          if (logs
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
            ...logs
                .where((l) => l.exerciseId == current.exercise.id)
                .map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
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
                      child: Row(
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
                              '${l10n.get('set')} ${log.setNumber}: ${log.reps} ${l10n.reps}',
                              style: TextStyle(
                                fontSize: 18,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (log.weight > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.orange.shade900.withValues(
                                        alpha: 0.5,
                                      )
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_formatWeightDisplay(log.weight)} ${_weightUnit == 'lbs' ? l10n.get('weightShortLbs') : l10n.get('weightShort')}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.orange.shade300
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

// ============== HISTORY PAGE ==============

class HistoryPage extends StatelessWidget {
  final List<WorkoutSession> history;
  final String weightUnit;

  const HistoryPage({super.key, required this.history, this.weightUnit = 'kg'});

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
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
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
                        size: 80,
                        color: colorScheme.primary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.get('noHistoryYet'),
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
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final session = history[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _HistoryCard(
                      session: session,
                      weightUnit: weightUnit,
                      l10n: l10n,
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

  const _HistoryCard({
    required this.session,
    required this.weightUnit,
    required this.l10n,
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

    if (sessionDate == today) {
      return 'Today';
    } else if (sessionDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalReps = session.logs.fold<int>(0, (sum, log) => sum + log.reps);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.green.shade900 : Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 28,
                  color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.templateName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      _formatDate(session.startTime),
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
            ],
          ),
          const SizedBox(height: 16),
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
        ],
      ),
    );
  }

  double _getMaxWeight() {
    if (session.logs.isEmpty) return 0;
    return session.logs.map((l) => l.weight).reduce((a, b) => a > b ? a : b);
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
        Icon(icon, size: 24, color: colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
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

  const StatisticsPage({
    super.key,
    required this.history,
    this.weightUnit = 'kg',
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Calculate statistics
    final totalWorkouts = history.length;
    final totalDuration = history.fold<int>(
      0,
      (sum, s) => sum + s.durationSeconds,
    );
    final totalReps = history.fold<int>(
      0,
      (sum, s) => sum + s.logs.fold<int>(0, (s2, l) => s2 + l.reps),
    );

    // Workouts this week
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final workoutsThisWeek = history
        .where((s) => s.startTime.isAfter(weekStart))
        .length;

    // Most common exercises
    final exerciseCounts = <String, int>{};
    for (final session in history) {
      for (final log in session.logs) {
        exerciseCounts[log.exerciseName] =
            (exerciseCounts[log.exerciseName] ?? 0) + log.reps;
      }
    }
    final topExercises = exerciseCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        child: history.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Overview stats
                    Text(
                      l10n.get('overview'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.fitness_center,
                            value: '$totalWorkouts',
                            label: l10n.get('totalWorkouts'),
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.calendar_today,
                            value: '$workoutsThisWeek',
                            label: l10n.get('thisWeek'),
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.timer,
                            value: '${(totalDuration / 60).round()}',
                            label: l10n.get('totalMinutes'),
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.repeat,
                            value: '$totalReps',
                            label: l10n.get('totalReps'),
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Top exercises
                    if (topExercises.isNotEmpty) ...[
                      Text(
                        l10n.get('topExercises'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...topExercises
                          .take(5)
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1A2634)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.fitness_center,
                                      color: colorScheme.primary,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${entry.value} ${l10n.reps}',
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
                            ),
                          ),
                    ],
                    const SizedBox(height: 32),
                    // Progress Chart Section
                    _ProgressChartSection(
                      history: history,
                      weightUnit: weightUnit,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ============== PROGRESS CHART SECTION ==============

enum ChartViewMode { reps, weight, both }

class _ProgressChartSection extends StatefulWidget {
  final List<WorkoutSession> history;
  final String weightUnit;

  const _ProgressChartSection({required this.history, this.weightUnit = 'kg'});

  @override
  State<_ProgressChartSection> createState() => _ProgressChartSectionState();
}

class _ProgressChartSectionState extends State<_ProgressChartSection> {
  String? selectedExerciseId;
  ChartViewMode viewMode = ChartViewMode.reps;

  // Get all unique exercises from history
  List<MapEntry<String, String>> get uniqueExercises {
    final exercises = <String, String>{};
    for (final session in widget.history) {
      for (final log in session.logs) {
        exercises[log.exerciseId] = log.exerciseName;
      }
    }
    return exercises.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
  }

  // Get chart data points for selected exercise
  List<_ChartDataPoint> get chartData {
    if (selectedExerciseId == null) return [];

    final dataPoints = <_ChartDataPoint>[];

    for (final session in widget.history) {
      final logsForExercise = session.logs
          .where((log) => log.exerciseId == selectedExerciseId)
          .toList();

      if (logsForExercise.isNotEmpty) {
        // Get the best (max) reps and weight for this session
        final maxReps = logsForExercise.map((l) => l.reps).reduce(math.max);
        final maxWeight = logsForExercise.map((l) => l.weight).reduce(math.max);

        dataPoints.add(
          _ChartDataPoint(
            date: session.startTime,
            reps: maxReps,
            weight: maxWeight,
          ),
        );
      }
    }

    // Sort by date (oldest first)
    dataPoints.sort((a, b) => a.date.compareTo(b.date));
    return dataPoints;
  }

  @override
  void initState() {
    super.initState();
    // Auto-select first exercise if available
    if (uniqueExercises.isNotEmpty) {
      selectedExerciseId = uniqueExercises.first.key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exercises = uniqueExercises;

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
              value: selectedExerciseId,
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
              items: exercises.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      entry.value,
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
                  selectedExerciseId = value;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // View Mode Toggle (Reps / Weight / Both)
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
                  label: l10n.get('repsOverTime'),
                  isSelected: viewMode == ChartViewMode.reps,
                  onTap: () => setState(() => viewMode = ChartViewMode.reps),
                ),
              ),
              const SizedBox(width: 4),
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
                  label: l10n.get('bothOverTime'),
                  isSelected: viewMode == ChartViewMode.both,
                  onTap: () => setState(() => viewMode = ChartViewMode.both),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Chart
        _buildChart(l10n, colorScheme, isDark),
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
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2634) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            l10n.get('noDataForExercise'),
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    // Calculate min/max values for axes
    final repsValues = data.map((d) => d.reps.toDouble()).toList();
    final weightValues = data.map((d) => d.weight).toList();

    final maxReps = repsValues.reduce(math.max);
    final maxWeightKg = weightValues.reduce(math.max);
    final isLbs = widget.weightUnit == 'lbs';
    const double kgToLbs = 2.2046226218;
    final maxWeightDisplay = isLbs ? maxWeightKg * kgToLbs : maxWeightKg;

    // Create line chart data (weight in display unit when weight-only view so Y-axis matches)
    final repsSpots = <FlSpot>[];
    final weightSpots = <FlSpot>[];

    for (int i = 0; i < data.length; i++) {
      repsSpots.add(FlSpot(i.toDouble(), data[i].reps.toDouble()));
      final w = data[i].weight;
      weightSpots.add(
        FlSpot(
          i.toDouble(),
          viewMode == ChartViewMode.weight && isLbs ? w * kgToLbs : w,
        ),
      );
    }

    final lineBarsData = <LineChartBarData>[];

    // Reps line (blue)
    if (viewMode == ChartViewMode.reps || viewMode == ChartViewMode.both) {
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

    // Weight line (green)
    if (viewMode == ChartViewMode.weight || viewMode == ChartViewMode.both) {
      // Normalize weight to reps scale if showing both
      final normalizedWeightSpots =
          viewMode == ChartViewMode.both && maxWeightKg > 0 && maxReps > 0
          ? weightSpots
                .map((spot) => FlSpot(spot.x, spot.y * (maxReps / maxWeightKg)))
                .toList()
          : weightSpots;

      lineBarsData.add(
        LineChartBarData(
          spots: normalizedWeightSpots,
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

    // Determine Y-axis max (weight axis in display unit when lbs)
    double yMax;
    if (viewMode == ChartViewMode.reps) {
      yMax = maxReps + 2;
    } else if (viewMode == ChartViewMode.weight) {
      yMax = maxWeightDisplay + (isLbs ? 10 : 5);
    } else {
      yMax = maxReps + 2; // Use reps scale for "both" mode
    }

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
          if (viewMode == ChartViewMode.both)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendItem(
                    color: Colors.blue,
                    label: l10n.get('repsOverTime'),
                  ),
                  const SizedBox(width: 24),
                  _LegendItem(
                    color: Colors.green,
                    label: l10n.get('weightOverTime'),
                  ),
                ],
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
                        final String label;
                        if (viewMode == ChartViewMode.weight) {
                          label = value == value.toInt()
                              ? value.toInt().toString()
                              : value.toStringAsFixed(1);
                        } else {
                          label = value.toInt().toString();
                        }
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
                        final dataPoint = data[index];

                        final weightDisplay = widget.weightUnit == 'lbs'
                            ? (dataPoint.weight * 2.2046226218)
                            : dataPoint.weight;
                        final weightStr = weightDisplay == weightDisplay.toInt()
                            ? '${weightDisplay.toInt()}'
                            : weightDisplay.toStringAsFixed(1);
                        final unitLabel = widget.weightUnit == 'lbs'
                            ? l10n.get('weightShortLbs')
                            : l10n.get('weightShort');
                        String label;
                        if (viewMode == ChartViewMode.both) {
                          label = spot.barIndex == 0
                              ? '${l10n.get('repsOverTime')}: ${dataPoint.reps}'
                              : '${l10n.get('weightOverTime')}: $weightStr $unitLabel';
                        } else if (viewMode == ChartViewMode.reps) {
                          label = '${dataPoint.reps} ${l10n.reps}';
                        } else {
                          label = '$weightStr $unitLabel';
                        }

                        return LineTooltipItem(
                          label,
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        );
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
  final int reps;
  final double weight;

  _ChartDataPoint({
    required this.date,
    required this.reps,
    required this.weight,
  });
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final MaterialColor color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          Icon(icon, size: 36, color: isDark ? color.shade300 : color.shade600),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isDark ? color.shade300 : color.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============== REUSABLE WIDGETS ==============

class _LargeRoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _LargeRoundButton({
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
          width: 64,
          height: 64,
          alignment: Alignment.center,
          child: Icon(icon, size: 36, color: Colors.white),
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

  @override
  void initState() {
    super.initState();
    _loadDefaultRestSeconds();
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
